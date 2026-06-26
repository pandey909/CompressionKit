import XCTest
import CoreGraphics
@testable import CompressionKit

final class CompressionQualityValidatorTests: XCTestCase {
    func testValidatorPassed() {
        let inputMeta = VideoMetadata(
            fileName: "input.mp4",
            fileSizeBytes: 1_000_000_000,
            duration: 60.0,
            naturalWidth: 3840,
            naturalHeight: 2160,
            displayWidth: 2160,
            displayHeight: 3840,
            isPortrait: true,
            bitrate: 138_000_000.0,
            fps: 120.0,
            codec: "HEVC",
            colorSpace: "HDR",
            preferredTransform: .identity,
            naturalResolution: CGSize(width: 3840, height: 2160),
            displayResolution: CGSize(width: 2160, height: 3840)
        )
        
        let outputMeta = VideoMetadata(
            fileName: "output.mp4",
            fileSizeBytes: 50_000_000,
            duration: 60.0,
            naturalWidth: 720,
            naturalHeight: 1280,
            displayWidth: 720,
            displayHeight: 1280,
            isPortrait: true,
            bitrate: 6_000_000.0,
            fps: 30.0,
            codec: "HEVC",
            colorSpace: "SDR",
            preferredTransform: .identity,
            naturalResolution: CGSize(width: 720, height: 1280),
            displayResolution: CGSize(width: 720, height: 1280)
        )
        
        XCTAssertNoThrow(try CompressionQualityValidator.validate(inputMetadata: inputMeta, outputMetadata: outputMeta))
    }
    
    func testValidatorOrientationMismatch() {
        let inputMeta = VideoMetadata(
            fileName: "input.mp4",
            fileSizeBytes: 1_000_000_000,
            duration: 60.0,
            naturalWidth: 3840,
            naturalHeight: 2160,
            displayWidth: 2160,
            displayHeight: 3840,
            isPortrait: true,
            bitrate: 138_000_000.0,
            fps: 120.0,
            codec: "HEVC",
            colorSpace: "HDR",
            preferredTransform: .identity,
            naturalResolution: CGSize(width: 3840, height: 2160),
            displayResolution: CGSize(width: 2160, height: 3840)
        )
        
        // Output claims to be landscape (width = 1280, height = 720, isPortrait = false)
        let outputMeta = VideoMetadata(
            fileName: "output.mp4",
            fileSizeBytes: 50_000_000,
            duration: 60.0,
            naturalWidth: 1280,
            naturalHeight: 720,
            displayWidth: 1280,
            displayHeight: 720,
            isPortrait: false,
            bitrate: 6_000_000.0,
            fps: 30.0,
            codec: "HEVC",
            colorSpace: "SDR",
            preferredTransform: .identity,
            naturalResolution: CGSize(width: 1280, height: 720),
            displayResolution: CGSize(width: 1280, height: 720)
        )
        
        XCTAssertThrowsError(try CompressionQualityValidator.validate(inputMetadata: inputMeta, outputMetadata: outputMeta)) { error in
            guard case VideoCompressionError.qualityValidationFailed = error else {
                XCTFail("Wrong error thrown: \(error)")
                return
            }
        }
    }
}
