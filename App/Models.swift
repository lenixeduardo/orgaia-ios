import Foundation

enum PhotoCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case pessoal, projetos, documentos, pokemon, compras, capturas, outros

    var id: String { rawValue }
    var title: String {
        switch self {
        case .pessoal: return "Fotos pessoais"
        case .projetos: return "Projetos"
        case .documentos: return "Documentos"
        case .pokemon: return "Pokémon TCG"
        case .compras: return "Compras"
        case .capturas: return "Capturas de tela"
        case .outros: return "Outros"
        }
    }
    var symbol: String {
        switch self {
        case .pessoal: return "person.crop.rectangle"
        case .projetos: return "hammer"
        case .documentos: return "doc.text"
        case .pokemon: return "square.stack.3d.up"
        case .compras: return "bag"
        case .capturas: return "iphone.gen3"
        case .outros: return "tray"
        }
    }
    var albumName: String { AppConfig.albumPrefix + title }
}

struct Classification: Codable {
    let category: PhotoCategory
    let confidence: Double
    let evidence: [String]
    let learningTokens: [String]
}

struct PhotoRecord: Codable, Identifiable {
    var id: String // PHAsset localIdentifier
    var classification: Classification
    var selectedCategory: PhotoCategory
    var appliedCategory: PhotoCategory?
    var reviewed: Bool
    var createdAt: Date

    var needsReview: Bool { !reviewed && classification.confidence < AppConfig.confidenceThreshold }
}

enum OrgaError: LocalizedError {
    case noPhotoPermission
    case imageUnavailable
    case photoCreationFailed
    case albumCreationFailed
    case assetNotFound

    var errorDescription: String? {
        switch self {
        case .noPhotoPermission: return "Autorize acesso completo ou às fotos selecionadas em Ajustes."
        case .imageUnavailable: return "Imagem indisponível neste dispositivo. Baixe-a do iCloud e tente novamente."
        case .photoCreationFailed: return "Falha ao adicionar a imagem ao Fotos."
        case .albumCreationFailed: return "Falha ao criar o álbum no Fotos."
        case .assetNotFound: return "A foto não foi encontrada na biblioteca."
        }
    }
}
