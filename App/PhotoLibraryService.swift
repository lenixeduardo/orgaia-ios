import Photos
import UIKit
import CoreGraphics

final class PhotoLibraryService {
    static let shared = PhotoLibraryService()
    private init() {}

    func permission() -> PHAuthorizationStatus { PHPhotoLibrary.authorizationStatus(for: .readWrite) }

    func requestPermission() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func canRead() -> Bool {
        let status = permission()
        return status == .authorized || status == .limited
    }

    func newestAssets(limit: Int) -> [PHAsset] {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = limit
        opts.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let results = PHAsset.fetchAssets(with: opts)
        var assets: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    func asset(id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    func image(for asset: PHAsset) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1280, height: 1280),
                                                   contentMode: .aspectFit, options: options) { image, info in
                let error = info?[PHImageErrorKey] as? Error
                if let error { continuation.resume(throwing: error); return }
                if let cgImage = image?.cgImage { continuation.resume(returning: cgImage) }
                else { continuation.resume(throwing: OrgaError.imageUnavailable) }
            }
        }
    }

    private func album(named title: String) -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", title)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options).firstObject
    }

    func ensureAlbum(for category: PhotoCategory) async throws -> PHAssetCollection {
        let name = category.albumName
        if let existing = album(named: name) { return existing }
        try await changes {
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
        }
        guard let result = album(named: name) else { throw OrgaError.albumCreationFailed }
        return result
    }

    func apply(assetID: String, category: PhotoCategory, oldCategory: PhotoCategory?) async throws {
        guard canRead() else { throw OrgaError.noPhotoPermission }
        guard let asset = asset(id: assetID) else { throw OrgaError.assetNotFound }
        let newAlbum = try await ensureAlbum(for: category)
        let oldAlbum: PHAssetCollection? = oldCategory != category ? oldCategory.flatMap { album(named: $0.albumName) } : nil
        try await changes {
            PHAssetCollectionChangeRequest(for: newAlbum)?.addAssets([asset] as NSArray)
            if let oldAlbum {
                PHAssetCollectionChangeRequest(for: oldAlbum)?.removeAssets([asset] as NSArray)
            }
        }
    }

    func addImageFileToPhotos(_ source: URL) async throws -> PHAsset {
        guard canRead() else { throw OrgaError.noPhotoPermission }
        var createdID: String?
        try await changes {
            let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: source)
            createdID = request?.placeholderForCreatedAsset?.localIdentifier
        }
        guard let id = createdID, let asset = asset(id: id) else { throw OrgaError.photoCreationFailed }
        return asset
    }

    private func changes(_ block: @escaping () -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges(block) { success, error in
                if success { continuation.resume(returning: ()) }
                else { continuation.resume(throwing: error ?? OrgaError.albumCreationFailed) }
            }
        }
    }
}
