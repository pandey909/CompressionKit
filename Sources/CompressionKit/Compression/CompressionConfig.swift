import Foundation
import AVFoundation

public enum TargetResolution: String, CaseIterable, Sendable, Codable {
    case original = "Original"
    case r1080p = "1080p"
    case r720p = "720p"
    case r540p = "540p"
}

public struct CompressionConfig: Sendable, Equatable {
    public let mode: CompressionMode
    public let targetSizeMB: Double?
    public let targetResolution: TargetResolution
    public let targetFPS: Double?
    public let targetVideoBitrate: Int?
    public let targetAudioBitrate: Int
    public let codec: AVVideoCodecType
    public let preserveHDR: Bool
    public let allowSecondPass: Bool
    public let deleteOriginal: Bool
    
    public static func == (lhs: CompressionConfig, rhs: CompressionConfig) -> Bool {
        return lhs.mode == rhs.mode &&
            lhs.targetSizeMB == rhs.targetSizeMB &&
            lhs.targetResolution == rhs.targetResolution &&
            lhs.targetFPS == rhs.targetFPS &&
            lhs.targetVideoBitrate == rhs.targetVideoBitrate &&
            lhs.targetAudioBitrate == rhs.targetAudioBitrate &&
            lhs.codec == rhs.codec &&
            lhs.preserveHDR == rhs.preserveHDR &&
            lhs.allowSecondPass == rhs.allowSecondPass &&
            lhs.deleteOriginal == rhs.deleteOriginal
    }
    
    public init(mode: CompressionMode, targetSizeMB: Double? = nil, deleteOriginal: Bool = false) {
        self.mode = mode
        self.deleteOriginal = deleteOriginal
        
        switch mode {
        case .highQuality:
            self.targetSizeMB = nil
            self.targetResolution = .original
            self.targetFPS = nil // Keep original
            self.targetVideoBitrate = nil // Dynamic high
            self.targetAudioBitrate = 128000 // 128 kbps
            self.codec = .hevc
            self.preserveHDR = true
            self.allowSecondPass = false
            
        case .balanced:
            self.targetSizeMB = nil
            self.targetResolution = .r1080p
            self.targetFPS = 60.0 // Cap at 60
            self.targetVideoBitrate = nil // Dynamic medium
            self.targetAudioBitrate = 128000 // 128 kbps
            self.codec = .hevc
            self.preserveHDR = true
            self.allowSecondPass = false
            
        case .socialOptimized:
            self.targetSizeMB = targetSizeMB ?? 50.0
            self.targetResolution = .r720p // Optimal for social sharing
            self.targetFPS = 30.0 // Standard social FPS
            self.targetVideoBitrate = nil // Calculated from targetSizeMB
            self.targetAudioBitrate = 128000 // 128 kbps
            self.codec = .hevc
            self.preserveHDR = false // SDR conversion allowed for smaller size
            self.allowSecondPass = false // Fast one-pass by default for social sharing
            
        case .smallerSize:
            self.targetSizeMB = nil
            self.targetResolution = .r720p
            self.targetFPS = 30.0
            self.targetVideoBitrate = nil // Dynamic smaller
            self.targetAudioBitrate = 96000 // 96 kbps
            self.codec = .hevc
            self.preserveHDR = false
            self.allowSecondPass = false
            
        case .extremeWatchable:
            self.targetSizeMB = nil
            self.targetResolution = .r540p
            self.targetFPS = 30.0
            self.targetVideoBitrate = 2_500_000 // Min video bitrate
            self.targetAudioBitrate = 64000 // 64 kbps (downsampled)
            self.codec = .hevc
            self.preserveHDR = false
            self.allowSecondPass = false
            
        case .customTargetSizeMB(let customMB):
            self.targetSizeMB = customMB
            self.targetResolution = customMB < 30 ? .r540p : .r720p
            self.targetFPS = 30.0
            self.targetVideoBitrate = nil // Calculated from targetSizeMB
            self.targetAudioBitrate = 96000
            self.codec = .hevc
            self.preserveHDR = false
            self.allowSecondPass = true
        }
    }
}
