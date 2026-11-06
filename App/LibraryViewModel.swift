import Foundation
import Photos
import SwiftUI

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var busy = false
    @Published var progress = ""
    @Published var errorMessage: String?
    @Published var permissionState: PHAuthorizationStatus = .notDetermined

    let store = CatalogStore()
    private let photos = PhotoLibraryService.shared

    init() { permissionState = photos.permission() }

    func authorize() async {
        permissionState = await photos.requestPermission()
        if photos.canRead() { await scan(limit: 100) }
    }

    func onActive() async {
        permissionState = photos.permission()
        guard photos.canRead(), !busy else { return }
        await importInbox()
        if store.autoScan { await scan(limit: 100) }
    }

    func scan(limit: Int) async {
        guard photos.canRead(), !busy else { return }
        busy = true
        defer { busy = false; progress = "" }
        let assets = photos.newestAssets(limit: limit)
        let pending = assets.filter { store.records[$0.localIdentifier] == nil }
        var failures = 0
        for (index, asset) in pending.enumerated() {
            if Task.isCancelled { break }
            progress = "Analisando \(index + 1) de \(pending.count)"
            do {
                let cgImage = try await photos.image(for: asset)
                let weights = store.learned
                let screenshot = asset.mediaSubtypes.contains(.photoScreenshot)
                let result = try await Task.detached(priority: .utility) {
                    try RecognitionService().analyze(image: cgImage,
                                                     isScreenshot: screenshot,
                                                     learned: weights)
                }.value
                let record = PhotoRecord(id: asset.localIdentifier, classification: result,
                                         selectedCategory: result.category, appliedCategory: nil,
                                         reviewed: false, createdAt: asset.creationDate ?? Date())
                store.insert(record)
                if store.autoApply && result.confidence >= AppConfig.confidenceThreshold {
                    try await photos.apply(assetID: record.id, category: record.selectedCategory, oldCategory: nil)
                    store.markApplied(id: record.id, category: record.selectedCategory)
                }
            } catch { failures += 1 }
        }
        if failures > 0 { errorMessage = "\(failures) imagem(ns) não puderam ser analisadas ou organizadas. Verifique o iCloud e as permissões." }
    }

    func importInbox() async {
        guard photos.canRead(), !busy else { return }
        busy = true
        defer { busy = false; progress = "" }
        do {
            let files = try InboxFileStore.pending()
            for (index, file) in files.enumerated() {
                progress = "Importando \(index + 1) de \(files.count)"
                do {
                    let asset = try await photos.addImageFileToPhotos(file)
                    // After a successful import, classify on the next scan.
                    try InboxFileStore.remove(file)
                    _ = asset
                } catch {
                    errorMessage = "Falha na importação: \(error.localizedDescription)"
                    break // Keep failed files for retry, never discard them.
                }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func applySuggested() async {
        guard !busy else { return }
        busy = true
        defer { busy = false; progress = "" }
        let items = store.readyToApply
        var failures = 0
        for (index, item) in items.enumerated() {
            progress = "Organizando \(index + 1) de \(items.count)"
            do {
                try await photos.apply(assetID: item.id, category: item.selectedCategory, oldCategory: item.appliedCategory)
                store.markApplied(id: item.id, category: item.selectedCategory)
            } catch { failures += 1 }
        }
        if failures > 0 { errorMessage = "Não foi possível atualizar \(failures) foto(s)." }
    }

    func correct(id: String, to category: PhotoCategory) {
        store.updateCategory(id: id, category: category)
    }
}
