import Foundation

public enum CompressionMode: Equatable, Sendable, Hashable, Identifiable {
    case highQuality
    case balanced
    case socialOptimized
    case smallerSize
    case extremeWatchable
    case customTargetSizeMB(Double)
    
    public var id: String {
        switch self {
        case .highQuality: return "highQuality"
        case .balanced: return "balanced"
        case .socialOptimized: return "socialOptimized"
        case .smallerSize: return "smallerSize"
        case .extremeWatchable: return "extremeWatchable"
        case .customTargetSizeMB(let size): return "customTargetSizeMB_\(size)"
        }
    }
    
    public var title: String {
        switch self {
        case .highQuality: return "High Quality"
        case .balanced: return "Balanced"
        case .socialOptimized: return "Social Optimized"
        case .smallerSize: return "Smaller Size"
        case .extremeWatchable: return "Extreme Watchable"
        case .customTargetSizeMB: return "Custom Target Size"
        }
    }
    
    public var description: String {
        switch self {
        case .highQuality: return "Best visual quality, larger file size."
        case .balanced: return "Good quality with reasonable file size."
        case .socialOptimized: return "Targets 40–60 MB for large videos. Best for sharing."
        case .smallerSize: return "More compression with acceptable mobile quality."
        case .extremeWatchable: return "Maximum saving while keeping video usable."
        case .customTargetSizeMB(let size): return "Compresses video targeting \(String(format: "%.1f MB", size))."
        }
    }
    
    public static var allCases: [CompressionMode] {
        return [.highQuality, .balanced, .socialOptimized, .smallerSize, .extremeWatchable]
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .highQuality: hasher.combine(0)
        case .balanced: hasher.combine(1)
        case .socialOptimized: hasher.combine(2)
        case .smallerSize: hasher.combine(3)
        case .extremeWatchable: hasher.combine(4)
        case .customTargetSizeMB(let size):
            hasher.combine(5)
            hasher.combine(size)
        }
    }
}
