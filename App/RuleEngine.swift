import Foundation

struct RuleEngine {
    /// Domain-specific words are deliberate: the generic Vision model doesn't know a user's projects.
    static let keywords: [PhotoCategory: Set<String>] = [
        .pokemon: ["pokemon", "pokémon", "pikachu", "charizard", "charmander", "bulbasaur", "squirtle", "mewtwo", "jigglypuff", "tcg", "pokeball", "pokéball", "booster", "foil", "psa", "cardpulse", "gemmastore"],
        .projetos: ["github", "gitlab", "vercel", "supabase", "typescript", "javascript", "swiftui", "python", "docker", "deploy", "localhost", "nextjs", "react", "figma", "terminal", "vscode", "database"],
        .documentos: ["comprovante", "recibo", "contrato", "nota", "fiscal", "invoice", "boleto", "documento", "cpf", "cnpj", "passaporte", "certidao", "certidão", "identidade"],
        .compras: ["shopee", "mercadolivre", "mercado", "amazon", "pedido", "entrega", "carrinho", "purchase", "checkout", "frete", "comprar", "desconto", "promocao", "promoção"],
        .pessoal: ["portrait", "selfie", "person", "people", "family", "face", "wedding", "baby"],
        .capturas: ["screenshot", "screen", "capture"]
    ]

    static func tokens(from text: String) -> [String] {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
        return Array(Set(folded.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && $0.count < 35 })).sorted()
    }

    static func suggest(labels: [(String, Double)], ocr: String, isScreenshot: Bool,
                        learned: [String: [String: Int]]) -> Classification {
        let ocrTokens = Set(tokens(from: ocr))
        let labelTokens = Set(tokens(from: labels.map { $0.0 }.joined(separator: " ")))
        let allTokens = ocrTokens.union(labelTokens)
        var scores = Dictionary(uniqueKeysWithValues: PhotoCategory.allCases.map { ($0, 0.0) })
        var evidence: [PhotoCategory: [String]] = [:]

        for category in PhotoCategory.allCases where category != .outros {
            let words = Set((keywords[category] ?? []).map { tokens(from: $0).first ?? $0 })
            for token in allTokens.intersection(words) {
                // OCR is more meaningful for project names, documents and TCG cards.
                let weight = ocrTokens.contains(token) ? 5.0 : 3.0
                scores[category, default: 0] += weight
                evidence[category, default: []].append(token)
            }
        }
        for token in allTokens {
            for (categoryID, count) in learned[token] ?? [:] {
                guard let category = PhotoCategory(rawValue: categoryID) else { continue }
                scores[category, default: 0] += min(Double(count) * 1.5, 6.0)
            }
        }
        // Generic visual labels have modest weight, avoiding false confidence.
        for (label, probability) in labels.prefix(4) where probability >= 0.3 {
            let lower = label.lowercased()
            if lower.contains("person") || lower.contains("portrait") {
                scores[.pessoal, default: 0] += probability * 3
                evidence[.pessoal, default: []].append("pessoa detectada")
            }
        }
        if isScreenshot {
            scores[.capturas, default: 0] += 4.0
            evidence[.capturas, default: []].append("captura de tela")
        }
        let best = scores.filter { $0.key != .outros }
            .sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }
            .first
        guard let winner = best, winner.value > 0 else {
            return Classification(category: .outros, confidence: 0.35,
                                  evidence: ["Sem correspondência segura"], learningTokens: Array(allTokens.prefix(30)))
        }
        let runnerUp = scores.filter { $0.key != winner.key }.values.max() ?? 0
        let advantage = max(0, winner.value - runnerUp)
        let confidence = min(0.97, 0.48 + winner.value * 0.065 + advantage * 0.025)
        return Classification(category: winner.key, confidence: confidence,
                              evidence: Array((evidence[winner.key] ?? []).prefix(5)),
                              learningTokens: Array(allTokens.prefix(30)))
    }
}
