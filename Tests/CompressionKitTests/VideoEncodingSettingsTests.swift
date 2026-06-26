import XCTest
import AVFoundation
@testable import CompressionKit

final class VideoEncodingSettingsTests: XCTestCase {
    
    func testCreateVideoSettingsH264() {
        let settings = VideoEncodingSettings.createVideoSettings(
            codec: .h264,
            width: 720,
            height: 1280,
            bitrate: 5000000,
            fps: 30.0,
            preserveHDR: false
        )
        
        XCTAssertEqual(settings[AVVideoCodecKey] as? AVVideoCodecType, .h264)
        XCTAssertEqual(settings[AVVideoWidthKey] as? Int, 720)
        XCTAssertEqual(settings[AVVideoHeightKey] as? Int, 1280)
        
        let props = settings[AVVideoCompressionPropertiesKey] as? [String: Any]
        XCTAssertNotNil(props)
        XCTAssertEqual(props?[AVVideoAverageBitRateKey] as? Int, 5000000)
        XCTAssertEqual(props?[AVVideoExpectedSourceFrameRateKey] as? Double, 30.0)
        XCTAssertEqual(props?[AVVideoProfileLevelKey] as? String, AVVideoProfileLevelH264HighAutoLevel)
        
        let colorProps = settings[AVVideoColorPropertiesKey] as? [String: Any]
        XCTAssertNotNil(colorProps)
        XCTAssertEqual(colorProps?[AVVideoColorPrimariesKey] as? String, AVVideoColorPrimaries_ITU_R_709_2)
    }
    
    func testCreateVideoSettingsHEVCWithHDR() {
        let settings = VideoEncodingSettings.createVideoSettings(
            codec: .hevc,
            width: 1080,
            height: 1920,
            bitrate: 8000000,
            fps: 60.0,
            preserveHDR: true
        )
        
        XCTAssertEqual(settings[AVVideoCodecKey] as? AVVideoCodecType, .hevc)
        XCTAssertEqual(settings[AVVideoWidthKey] as? Int, 1080)
        XCTAssertEqual(settings[AVVideoHeightKey] as? Int, 1920)
        
        let props = settings[AVVideoCompressionPropertiesKey] as? [String: Any]
        XCTAssertNotNil(props)
        XCTAssertEqual(props?[AVVideoAverageBitRateKey] as? Int, 8000000)
        XCTAssertEqual(props?[AVVideoProfileLevelKey] as? String, "HEVC_Main_AutoLevel")
        
        XCTAssertNil(settings[AVVideoColorPropertiesKey])
    }
    
    func testCreateAudioSettings() {
        let settings = VideoEncodingSettings.createAudioSettings(
            bitrateBps: 128000,
            channels: 2,
            sampleRate: 48000.0
        )
        
        XCTAssertEqual(settings[AVFormatIDKey] as? AudioFormatID, kAudioFormatMPEG4AAC)
        XCTAssertEqual(settings[AVNumberOfChannelsKey] as? Int, 2)
        XCTAssertEqual(settings[AVSampleRateKey] as? Double, 48000.0)
        XCTAssertEqual(settings[AVEncoderBitRateKey] as? Int, 128000)
    }
}
