import Foundation

public enum CompressionProgress: Sendable {
    case preparing
    case readingMetadata
    case calculatingSettings
    case encoding(percentage: Double, elapsedTime: TimeInterval, estimatedRemainingTime: TimeInterval?)
    case finalizing
    case validating
    case completed(CompressionResult)
    
    // Compatibility properties to support existing app UI without breaking changes
    public var percentage: Double {
        switch self {
        case .preparing, .readingMetadata, .calculatingSettings:
            return 0.0
        case .encoding(let pct, _, _):
            return pct
        case .finalizing, .validating:
            return 0.99
        case .completed:
            return 1.0
        }
    }
    
    public var statusMessage: String {
        switch self {
        case .preparing:
            return "Preparing video..."
        case .readingMetadata:
            return "Reading video details..."
        case .calculatingSettings:
            return "Calculating compression settings..."
        case .encoding(let pct, _, _):
            return "Encoding video (\(Int(pct * 100))%)..."
        case .finalizing:
            return "Finalizing output file..."
        case .validating:
            return "Validating output quality..."
        case .completed:
            return "Done"
        }
    }
    
    public var currentSize: Int64? {
        return nil
    }
    
    public var elapsedTime: TimeInterval {
        switch self {
        case .preparing, .readingMetadata, .calculatingSettings:
            return 0.0
        case .encoding(_, let elapsed, _):
            return elapsed
        case .finalizing, .validating:
            return 0.0
        case .completed(let result):
            return result.duration
        }
    }
}
