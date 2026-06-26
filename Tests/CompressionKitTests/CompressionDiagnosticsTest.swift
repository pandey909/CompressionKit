import XCTest
@testable import CompressionKit

final class CompressionDiagnosticsTest: XCTestCase {
    func testManualVideoCompressionDiagnostic() async throws {
        guard let inputPath = ProcessInfo.processInfo.environment["COMPRESSION_KIT_DIAGNOSTIC_VIDEO"] else {
            throw XCTSkip("Set COMPRESSION_KIT_DIAGNOSTIC_VIDEO to run manual compression diagnostics.")
        }

        let inputURL = URL(fileURLWithPath: inputPath)
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw XCTSkip("Manual diagnostic video not found at COMPRESSION_KIT_DIAGNOSTIC_VIDEO.")
        }

        let compressor = VideoCompressor()
        _ = try await compressor.compress(inputURL: inputURL, mode: .socialOptimized)
    }
}
