import Foundation

@MainActor
final class CatalogStore: ObservableObject {
    @Published private(set) var records: [String: PhotoRecord] = [:]
    @Published private(set) var learned: [String: [String: Int]] = [:]
    @Published var autoApply: Bool { didSet { defaults.set(autoApply, forKey: "autoApply") } }
    @Published var autoScan: Bool { didSet { defaults.set(autoScan, forKey: "autoScan") } }

    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: AppConfig.groupID) ?? .standard
        if let data = defaults.data(forKey: "records-v1"), let decoded = try? JSONDecoder().decode([String: PhotoRecord].self, from: data) {
            records = decoded
        }
        if let data = defaults.data(forKey: "learned-v1"), let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
            learned = decoded
        }
        autoApply = defaults.object(forKey: "autoApply") as? Bool ?? false
        autoScan = defaults.object(forKey: "autoScan") as? Bool ?? true
    }

    var ordered: [PhotoRecord] { records.values.sorted { $0.createdAt > $1.createdAt } }
    var reviewItems: [PhotoRecord] { ordered.filter(\.needsReview) }
    var readyToApply: [PhotoRecord] {
        ordered.filter { ($0.reviewed || $0.classification.confidence >= AppConfig.confidenceThreshold) && $0.appliedCategory != $0.selectedCategory }
    }

    func insert(_ item: PhotoRecord) {
        records[item.id] = item
        persist()
    }
    func updateCategory(id: String, category: PhotoCategory) {
        guard var record = records[id] else { return }
        record.selectedCategory = category
        record.reviewed = true
        records[id] = record
        for token in record.classification.learningTokens.prefix(25) where token.count >= 4 {
            learned[token, default: [:]][category.rawValue, default: 0] = min(10, (learned[token]?[category.rawValue] ?? 0) + 1)
        }
        persist()
    }
    func markApplied(id: String, category: PhotoCategory) {
        guard var record = records[id] else { return }
        record.appliedCategory = category
        records[id] = record
        persist()
    }
    func addRule(word: String, category: PhotoCategory) {
        for token in RuleEngine.tokens(from: word).prefix(1) {
            learned[token, default: [:]][category.rawValue] = 5
        }
        persist()
    }
    func resetLearnedRules() {
        learned = [:]
        persist()
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(records) { defaults.set(data, forKey: "records-v1") }
        if let data = try? JSONEncoder().encode(learned) { defaults.set(data, forKey: "learned-v1") }
    }
}
