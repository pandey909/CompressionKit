import Foundation

public struct CompressionResult: Sendable {
    public let inputURL: URL
    public let outputURL: URL
    public let inputMetadata: VideoMetadata
    public let outputMetadata: VideoMetadata
    public let originalSizeBytes: Int64
    public let compressedSizeBytes: Int64
    public let savedPercentage: Double
    public let compressionRatio: Double
    public let duration: TimeInterval
    public let qualityWarning: String?
    
    // Compatibility helpers to support host app properties
    public var originalURL: URL { inputURL }
    public var compressedURL: URL { outputURL }
    public var originalMetadata: VideoMetadata { inputMetadata }
    public var compressedMetadata: VideoMetadata { outputMetadata }
    public var originalSize: Int64 { originalSizeBytes }
    public var compressedSize: Int64 { compressedSizeBytes }
    public var savedBytes: Int64 { max(0, originalSizeBytes - compressedSizeBytes) }
    
    public init(
        inputURL: URL,
        outputURL: URL,
        inputMetadata: VideoMetadata,
        outputMetadata: VideoMetadata,
        originalSizeBytes: Int64,
        compressedSizeBytes: Int64,
        savedPercentage: Double,
        compressionRatio: Double,
        duration: TimeInterval,
        qualityWarning: String?
    ) {
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.inputMetadata = inputMetadata
        self.outputMetadata = outputMetadata
        self.originalSizeBytes = originalSizeBytes
        self.compressedSizeBytes = compressedSizeBytes
        self.savedPercentage = savedPercentage
        self.compressionRatio = compressionRatio
        self.duration = duration
        self.qualityWarning = qualityWarning
    }
}
