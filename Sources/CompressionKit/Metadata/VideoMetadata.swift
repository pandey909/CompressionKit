import Foundation
import CoreGraphics
import AVFoundation

public struct VideoMetadata: Sendable, Equatable {
    public let fileName: String
    public let fileSizeBytes: Int64
    public let duration: TimeInterval
    public let naturalWidth: Int
    public let naturalHeight: Int
    public let displayWidth: Int
    public let displayHeight: Int
    public let isPortrait: Bool
    public let bitrate: Double // in bps
    public let fps: Double
    public let codec: String
    public let colorSpace: String
    public let preferredTransform: CGAffineTransform
    public let naturalResolution: CGSize
    public let displayResolution: CGSize
    
    // Backward compatibility helpers for the host app
    public var resolution: String {
        "\(displayWidth)x\(displayHeight)"
    }
    
    public var hdrInfo: String? {
        colorSpace
    }
    
    // Compatibility getters for app ViewModel
    public var width: Int {
        displayWidth
    }
    
    public var height: Int {
        displayHeight
    }
    
    public var fileSize: Int64 {
        fileSizeBytes
    }
    
    public init(
        fileName: String,
        fileSizeBytes: Int64,
        duration: TimeInterval,
        naturalWidth: Int,
        naturalHeight: Int,
        displayWidth: Int,
        displayHeight: Int,
        isPortrait: Bool,
        bitrate: Double,
        fps: Double,
        codec: String,
        colorSpace: String,
        preferredTransform: CGAffineTransform,
        naturalResolution: CGSize,
        displayResolution: CGSize
    ) {
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.duration = duration
        self.naturalWidth = naturalWidth
        self.naturalHeight = naturalHeight
        self.displayWidth = displayWidth
        self.displayHeight = displayHeight
        self.isPortrait = isPortrait
        self.bitrate = bitrate
        self.fps = fps
        self.codec = codec
        self.colorSpace = colorSpace
        self.preferredTransform = preferredTransform
        self.naturalResolution = naturalResolution
        self.displayResolution = displayResolution
    }
}
