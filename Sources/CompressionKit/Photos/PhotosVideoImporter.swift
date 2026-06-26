import Photos
import PhotosUI
import SwiftUI
import Foundation

public struct PhotosVideoImporter: Sendable {
    private let logger: VideoCompressionLogging?
    
    public init(logger: VideoCompressionLogging? = OSLogVideoCompressionLogger()) {
        self.logger = logger
    }
    
    /// Imports the original video resource using the Photos asset's unique identifier.
    public func importOriginalVideo(
        from itemIdentifier: String,
        onStatusChanged: (@Sendable (String) -> Void)? = nil
    ) async throws -> URL {
        try await PhotoAssetOriginalResourceImporter.importOriginalResource(
            for: itemIdentifier,
            logger: logger,
            onStatusChanged: onStatusChanged
        )
    }
    
    #if os(iOS)
    /// Imports the original video resource directly from a PhotosPickerItem, with fallback options.
    public func importOriginalVideo(
        from item: PhotosPickerItem,
        onStatusChanged: (@Sendable (String) -> Void)? = nil
    ) async throws -> URL {
        if let localIdentifier = item.itemIdentifier {
            do {
                return try await importOriginalVideo(from: localIdentifier, onStatusChanged: onStatusChanged)
            } catch {
                // If PHAsset strategy fails, fallback to Transferable representation load
                let pkgLogger = PackageLogger(clientLogger: logger, category: "PhotoImporter")
                pkgLogger.warning("PHAsset original resource load failed, attempting transferable load fallback...")
            }
        }
        
        onStatusChanged?("Downloading original from iCloud if needed...")
        guard let pickedVideo = try await item.loadTransferable(type: PickedVideoFile.self) else {
            throw VideoCompressionError.photosAssetFetchFailed
        }
        return pickedVideo.url
    }
    #endif
}
