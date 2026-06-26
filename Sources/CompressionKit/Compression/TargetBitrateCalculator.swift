import Foundation

struct TargetBitrateCalculator: Sendable {
    static func calculateVideoBitrate(
        mode: CompressionMode,
        duration: Double,
        renderWidth: Int,
        audioBitrateBps: Int
    ) -> Int {
        guard duration > 0 else { return 5_000_000 }
        
        switch mode {
        case .highQuality:
            return renderWidth >= 1920 ? 15_000_000 : 8_000_000
        case .balanced:
            return 6_000_000
        case .socialOptimized:
            let targetBytes = 50.0 * 1024.0 * 1024.0 // 50 MB target
            let totalBitrate = Int((targetBytes * 8.0) / duration)
            return max(2_500_000, min(8_000_000, totalBitrate - audioBitrateBps))
        case .smallerSize:
            return 4_000_000
        case .extremeWatchable:
            return 2_500_000
        case .customTargetSizeMB(let targetMB):
            let targetBytes = targetMB * 1024.0 * 1024.0
            let totalBitrate = Int((targetBytes * 8.0) / duration)
            return max(2_500_000, min(8_000_000, totalBitrate - audioBitrateBps))
        }
    }
}
