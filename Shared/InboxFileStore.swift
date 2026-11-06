import Foundation
import UniformTypeIdentifiers

enum InboxError: LocalizedError {
    case appGroupUnavailable
    case unsupportedType
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable: return "Configure o App Group nas duas extensões."
        case .unsupportedType: return "Formato de imagem não suportado."
        case .fileTooLarge: return "Arquivo acima do limite de 100 MB."
        }
    }
}

enum InboxFileStore {
    static let maximumBytes = 100 * 1024 * 1024
    static let allowedExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "webp", "gif", "tif", "tiff", "bmp"]

    static func directory() throws -> URL {
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.groupID) else {
            throw InboxError.appGroupUnavailable
        }
        let folder = base.appendingPathComponent("Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @discardableResult
    static func enqueue(fileAt url: URL, suggestedExtension: String? = nil) throws -> URL {
        let ext = (suggestedExtension ?? url.pathExtension).lowercased()
        guard allowedExtensions.contains(ext) else { throw InboxError.unsupportedType }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maximumBytes else { throw InboxError.fileTooLarge }
        let dest = try directory().appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
    }

    static func pending() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory(), includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
            .filter { allowedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func remove(_ file: URL) throws {
        // Never accept arbitrary caller-provided paths for deletion.
        guard file.deletingLastPathComponent().standardizedFileURL == (try directory()).standardizedFileURL else { return }
        try FileManager.default.removeItem(at: file)
    }
}

extension InboxFileStore {
    @discardableResult
    static func enqueue(data: Data, fileExtension: String) throws -> URL {
        let ext = fileExtension.lowercased()
        guard allowedExtensions.contains(ext) else { throw InboxError.unsupportedType }
        guard data.count <= maximumBytes else { throw InboxError.fileTooLarge }
        let destination = try directory().appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try data.write(to: destination, options: .atomic)
        return destination
    }
}
