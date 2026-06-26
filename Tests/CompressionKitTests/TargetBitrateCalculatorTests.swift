import XCTest
@testable import CompressionKit

final class TargetBitrateCalculatorTests: XCTestCase {
    func testCalculateBitrates() {
        let duration = 60.0
        let audioBps = 128_000
        
        // High quality (for 1080p width, should return 8 Mbps)
        let highBitrate = TargetBitrateCalculator.calculateVideoBitrate(
            mode: .highQuality,
            duration: duration,
            renderWidth: 1080,
            audioBitrateBps: audioBps
        )
        XCTAssertEqual(highBitrate, 8_000_000)
        
        // Social optimized (targets 50 MB total)
        // (50 MB * 1024 * 1024 * 8) / 60.0 = 6,990,506 bps total bitrate.
        // minus 128k audio = 6,862,506 bps video bitrate.
        let socialBitrate = TargetBitrateCalculator.calculateVideoBitrate(
            mode: .socialOptimized,
            duration: duration,
            renderWidth: 720,
            audioBitrateBps: audioBps
        )
        XCTAssertEqual(socialBitrate, 6_862_506)
        
        // Extreme watchable (should return 2.5 Mbps minimum limit)
        let extremeBitrate = TargetBitrateCalculator.calculateVideoBitrate(
            mode: .extremeWatchable,
            duration: duration,
            renderWidth: 540,
            audioBitrateBps: audioBps
        )
        XCTAssertEqual(extremeBitrate, 2_500_000)
    }
}
