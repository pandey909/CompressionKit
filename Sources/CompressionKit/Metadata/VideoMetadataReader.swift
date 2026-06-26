import AVFoundation
import Foundation

public struct VideoMetadataReader: Sendable {
    public static func readMetadata(
        for url: URL,
        logger: VideoCompressionLogging? = OSLogVideoCompressionLogger()
    ) async throws -> VideoMetadata {
        let pkgLogger = PackageLogger(clientLogger: logger, category: "MetadataReader")
        pkgLogger.info("Metadata loading started for \(url.lastPathComponent).")
        
        let asset = AVURLAsset(url: url)
        
        let duration: TimeInterval
        do {
            duration = try await asset.load(.duration).seconds
            pkgLogger.info("Duration loaded successfully: \(duration) seconds.")
        } catch {
            pkgLogger.error("Metadata failed to load: \(error.localizedDescription)")
            throw VideoCompressionError.metadataReadFailed("Duration load failed: \(error.localizedDescription)")
        }
        
        var resolution = "Unknown"
        var bitrate: Double = 0.0
        var fps: Double = 0.0
        var codec = "Unknown"
        var colorSpace = "SDR"
        
        var naturalSize = CGSize.zero
        var displayWidth: CGFloat = 0
        var displayHeight: CGFloat = 0
        var isPortrait = false
        var transform = CGAffineTransform.identity
        
        do {
            let tracks = try await asset.load(.tracks)
            if let videoTrack = tracks.first(where: { $0.mediaType == .video }) {
                let size = try await videoTrack.load(.naturalSize)
                let transformLoaded = try await videoTrack.load(.preferredTransform)
                naturalSize = size
                transform = transformLoaded
                
                pkgLogger.info("Track natural size: \(size.width)x\(size.height)")
                pkgLogger.info("Preferred transform: \(transform)")
                
                let swapsDimensions = abs(transform.b) > 0.5 && abs(transform.c) > 0.5
                
                displayWidth = swapsDimensions ? size.height : size.width
                displayHeight = swapsDimensions ? size.width : size.height
                isPortrait = displayWidth < displayHeight
                pkgLogger.info("Swaps dimensions: \(swapsDimensions), Is portrait display: \(isPortrait)")
                
                resolution = "\(Int(displayWidth))x\(Int(displayHeight))"
                pkgLogger.info("Video resolution determined: \(resolution).")
                
                let estimatedBitrate = try await videoTrack.load(.estimatedDataRate)
                if estimatedBitrate > 0 {
                    bitrate = Double(estimatedBitrate)
                    pkgLogger.info("Estimated bitrate determined: \(bitrate) bps.")
                }
                
                let frameRate = try await videoTrack.load(.nominalFrameRate)
                fps = Double(frameRate)
                pkgLogger.info("Nominal frame rate: \(frameRate) fps.")
                
                let formats = try await videoTrack.load(.formatDescriptions)
                if let formatDesc = formats.first {
                    let subType = CMFormatDescriptionGetMediaSubType(formatDesc)
                    pkgLogger.info("Format description media subtype FourCC: \(subType)")
                    
                    if subType == kCMVideoCodecType_HEVC {
                        codec = "HEVC"
                    } else if subType == kCMVideoCodecType_H264 {
                        codec = "H.264"
                    } else if subType == kCMVideoCodecType_AppleProRes422 {
                        codec = "ProRes 422"
                    } else {
                        codec = subType.toString()
                    }
                    pkgLogger.info("Codec: \(codec)")
                    
                    let mediaCharacteristics = try await videoTrack.load(.mediaCharacteristics)
                    let isHDR = mediaCharacteristics.contains(.containsHDRVideo)
                    colorSpace = isHDR ? "HDR (Dolby Vision/HDR10)" : "SDR"
                    pkgLogger.info("HDR / color space: \(colorSpace)")
                }
            }
        } catch {
            pkgLogger.warning("Optional track details failed to load: \(error.localizedDescription)")
        }
        
        // Fetch file size on disk
        var fileSize: Int64 = 0
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = attributes[.size] as? Int64 ?? 0
            pkgLogger.info("Video file size loaded from disk attributes: \(fileSize) bytes.")
        } catch {
            pkgLogger.warning("Disk attributes check failed. Trying resource value check.")
            if let resources = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let size = resources.fileSize {
                fileSize = Int64(size)
            }
        }
        
        let meta = VideoMetadata(
            fileName: url.lastPathComponent,
            fileSizeBytes: fileSize,
            duration: duration,
            naturalWidth: Int(naturalSize.width),
            naturalHeight: Int(naturalSize.height),
            displayWidth: Int(displayWidth),
            displayHeight: Int(displayHeight),
            isPortrait: isPortrait,
            bitrate: bitrate,
            fps: fps,
            codec: codec,
            colorSpace: colorSpace,
            preferredTransform: transform,
            naturalResolution: naturalSize,
            displayResolution: CGSize(width: displayWidth, height: displayHeight)
        )
        
        pkgLogger.info("Metadata loading completed. Name: \(meta.fileName), Size: \(meta.fileSizeBytes) bytes, Resolution: \(meta.resolution)")
        return meta
    }
}

extension FourCharCode {
    func toString() -> String {
        let bytes: [UInt8] = [
            UInt8((self >> 24) & 0xff),
            UInt8((self >> 16) & 0xff),
            UInt8((self >> 8) & 0xff),
            UInt8(self & 0xff)
        ]
        var result = ""
        for byte in bytes {
            if byte >= 32 && byte <= 126 { // printable ASCII characters
                result.append(Character(UnicodeScalar(byte)))
            } else {
                result.append("?")
            }
        }
        return result
    }
}
