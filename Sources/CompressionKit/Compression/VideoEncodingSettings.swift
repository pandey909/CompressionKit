import Foundation
import AVFoundation
import VideoToolbox

struct VideoEncodingSettings: Sendable {
    static func createVideoSettings(
        codec: AVVideoCodecType,
        width: Int,
        height: Int,
        bitrate: Int,
        fps: Double,
        preserveHDR: Bool
    ) -> [String: Any] {
        var compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoExpectedSourceFrameRateKey: fps,
            AVVideoMaxKeyFrameIntervalKey: Int(fps * 2.0)
        ]
        
        if codec == .hevc {
            compressionProperties[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main_AutoLevel
        } else {
            compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        }
        
        var videoWriterSettings: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: compressionProperties
        ]
        
        if !preserveHDR {
            videoWriterSettings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        }
        
        return videoWriterSettings
    }
    
    static func createAudioSettings(
        bitrateBps: Int,
        channels: Int = 2,
        sampleRate: Double = 44100.0
    ) -> [String: Any] {
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: channels,
            AVSampleRateKey: sampleRate,
            AVEncoderBitRateKey: bitrateBps
        ]
    }
}
