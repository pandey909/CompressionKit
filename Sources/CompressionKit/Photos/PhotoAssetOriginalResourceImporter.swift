import Photos
import PhotosUI
import Foundation

public struct PhotoAssetOriginalResourceImporter: Sendable {
    public static func importOriginalResource(
        for itemIdentifier: String,
        logger: VideoCompressionLogging? = OSLogVideoCompressionLogger(),
        onStatusChanged: (@Sendable (String) -> Void)? = nil
    ) async throws -> URL {
        let pkgLogger = PackageLogger(clientLogger: logger, category: "PhotoImporter")
        pkgLogger.info("PHAsset fallback started for localIdentifier: \(itemIdentifier)")
        
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [itemIdentifier], options: nil)
        guard let asset = result.firstObject else {
            pkgLogger.error("PHAsset fetch failed. localIdentifier did not match any assets.")
            throw VideoCompressionError.photosAssetFetchFailed
        }
        
        pkgLogger.info("PHAsset fetched successfully. Duration: \(asset.duration)s")
        
        let resources = PHAssetResource.assetResources(for: asset)
        pkgLogger.info("PHAsset resource count: \(resources.count)")
        
        guard let selectedResource = resources.first(where: { $0.type == .fullSizeVideo }) ?? resources.first(where: { $0.type == .video }) else {
            pkgLogger.error("PHAsset original resource missing.")
            throw VideoCompressionError.photosOriginalResourceMissing
        }
        
        onStatusChanged?("Downloading original from iCloud if needed...")
        
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let importedDirectory = cachesDirectory.appendingPathComponent("ImportedVideos", isDirectory: true)
        
        if !fileManager.fileExists(atPath: importedDirectory.path) {
            try fileManager.createDirectory(at: importedDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        let ext = URL(fileURLWithPath: selectedResource.originalFilename).pathExtension
        let uniqueName = "\(UUID().uuidString).\(ext.isEmpty ? "mov" : ext)"
        let destinationURL = importedDirectory.appendingPathComponent(uniqueName)
        
        pkgLogger.info("Original resource export started. Destination: \(destinationURL.lastPathComponent)")
        
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        
        let lastProgressLogBox = UnsafeMutableTransferer(0)
        
        options.progressHandler = { progress in
            let pct = Int(progress * 100)
            if pct >= lastProgressLogBox.value + 5 || pct == 100 {
                lastProgressLogBox.value = pct
                pkgLogger.info("Original resource download/write progress: \(pct)%")
                onStatusChanged?("Downloading from iCloud... \(pct)%")
            }
        }
        
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHAssetResourceManager.default().writeData(for: selectedResource, toFile: destinationURL, options: options) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } catch {
            pkgLogger.error("PHAssetResourceManager export failed: \(error.localizedDescription)")
            throw VideoCompressionError.photosOriginalResourceExportFailed(error.localizedDescription)
        }
        
        pkgLogger.info("Original resource write completed.")
        
        let destDiag = VideoFileManager.diagnostics(for: destinationURL)
        
        guard destDiag.exists else {
            pkgLogger.error("Original resource copied file missing.")
            throw VideoCompressionError.outputFileMissing
        }
        
        guard destDiag.readable else {
            pkgLogger.error("Original resource copied file is not readable.")
            throw VideoCompressionError.inputFileNotReadable
        }
        
        guard (destDiag.fileSize ?? 0) > 0 else {
            pkgLogger.error("Original resource copied file is empty.")
            throw VideoCompressionError.photosOriginalResourceMissing
        }
        
        pkgLogger.info("Using PHAsset original resource as source video.")
        return destinationURL
    }
}

private final class UnsafeMutableTransferer<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}
