import AVFoundation
import Foundation
import VideoToolbox

final class CompressionStateBox: @unchecked Sendable {
    var lastVideoPTS: CMTime = .invalid
    var lastLoggedProgress: Int = -5
    var lastTimeLoggedDetails: Date = .distantPast
    var framesProcessed: Int = 0
    var audioSamplesCount: Int = 0
    var isFirstVideoSample: Bool = true
    var isFirstAudioSample: Bool = true
}

final class SendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) {
        self.value = value
    }
}

actor VideoWriterCompressionEngine {
    private var reader: AVAssetReader?
    private var writer: AVAssetWriter?

    func cancel() {
        reader?.cancelReading()
        writer?.cancelWriting()
    }

    func compress(
        inputURL: URL,
        outputURL: URL,
        config: CompressionConfig,
        logger: VideoCompressionLogging?,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws {
        let pkgLogger = PackageLogger(clientLogger: logger, category: "WriterEngine")
        pkgLogger.notice("Compression phase: Preparing asset")

        let asset = AVURLAsset(url: inputURL)
        let duration: Double
        do {
            duration = try await asset.load(.duration).seconds
        } catch {
            pkgLogger.error("Failed to load asset duration.")
            throw VideoCompressionError.metadataReadFailed("Failed to load duration: \(error.localizedDescription)")
        }

        guard duration > 0 else {
            throw VideoCompressionError.unsupportedVideo
        }

        pkgLogger.notice("Compression phase: Reading geometry")
        let tracks: [AVAssetTrack]
        do {
            tracks = try await asset.load(.tracks)
        } catch {
            pkgLogger.error("Failed to load tracks.")
            throw VideoCompressionError.metadataReadFailed("Failed to load tracks: \(error.localizedDescription)")
        }

        guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
            throw VideoCompressionError.unsupportedVideo
        }

        let audioTrack = tracks.first(where: { $0.mediaType == .audio })

        let inputWidth: Int
        let inputHeight: Int
        if let size = try? await videoTrack.load(.naturalSize) {
            inputWidth = Int(size.width)
            inputHeight = Int(size.height)
        } else {
            inputWidth = 0
            inputHeight = 0
        }

        let originalFPS = Double((try? await videoTrack.load(.nominalFrameRate)) ?? 30.0)
        let originalTransform = (try? await videoTrack.load(.preferredTransform)) ?? .identity

        let geometry = VideoGeometry(
            naturalSize: CGSize(width: inputWidth, height: inputHeight),
            preferredTransform: originalTransform,
            target: config.targetResolution
        )

        pkgLogger.info("""
        Video geometry calculated:
        Input natural size: \(inputWidth)x\(inputHeight)
        Input preferred transform: \(originalTransform)
        Input display size: \(geometry.displaySize.width)x\(geometry.displaySize.height)
        Input orientation: \(geometry.isPortrait ? "portrait" : "landscape")
        Target display size: \(geometry.targetDisplaySize.width)x\(geometry.targetDisplaySize.height)
        Writer width: \(Int(geometry.renderSize.width))
        Writer height: \(Int(geometry.renderSize.height))
        Will bake transform into pixels: true
        Output writer transform: identity
        """)

        pkgLogger.notice("Compression phase: Calculating target bitrate")
        let targetFPS = config.targetFPS ?? originalFPS
        let audioBitrateBps = config.targetAudioBitrate

        let calculatedVideoBitrate = TargetBitrateCalculator.calculateVideoBitrate(
            mode: config.mode,
            duration: duration,
            renderWidth: Int(geometry.renderSize.width),
            audioBitrateBps: audioBitrateBps
        )

        pkgLogger.notice("""
        Compression mode selected: \(config.mode.title)
        Target output size: \(config.targetSizeMB.map { String(format: "%.1f MB", $0) } ?? "Dynamic")
        Input duration: \(String(format: "%.1fs", duration))
        Calculated video bitrate: \(calculatedVideoBitrate / 1000) kbps
        Target audio bitrate: \(audioBitrateBps / 1000) kbps
        Hardware HEVC available: \(VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC))
        Using codec: \(config.codec == AVVideoCodecType.hevc ? "HEVC" : "H.264")
        Target FPS: \(targetFPS)
        Target resolution: \(Int(geometry.renderSize.width))x\(Int(geometry.renderSize.height))
        Estimated output size: \(VideoWriterCompressionEngine.formatBytes(Int64((Double(calculatedVideoBitrate + audioBitrateBps) * duration) / 8.0)))
        """)

        var currentVideoBitrate = calculatedVideoBitrate
        var passesLeft = config.allowSecondPass ? 2 : 1

        // If calculated bitrate is at or below the quality guardrail floor (2.5 Mbps),
        // a second pass cannot lower the bitrate further. Skip it.
        if calculatedVideoBitrate <= 2_500_000 {
            passesLeft = 1
        }

        var finalSuccess = false

        while passesLeft > 0 {
            if Task.isCancelled {
                throw VideoCompressionError.encodingFailed("Encoding cancelled by task.")
            }

            let passNumber = config.allowSecondPass ? (3 - passesLeft) : 1
            pkgLogger.info("Executing compression pass \(passNumber) with video bitrate \(currentVideoBitrate / 1000) kbps...")

            try? FileManager.default.removeItem(at: outputURL)

            do {
                try await runSinglePass(
                    asset: asset,
                    videoTrack: videoTrack,
                    audioTrack: audioTrack,
                    geometry: geometry,
                    outputURL: outputURL,
                    targetFPS: targetFPS,
                    videoBitrate: currentVideoBitrate,
                    audioBitrateBps: audioBitrateBps,
                    preserveHDR: config.preserveHDR,
                    codec: config.codec,
                    duration: duration,
                    passNumber: passNumber,
                    logger: logger,
                    onProgress: onProgress
                )

                let outputSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
                pkgLogger.info("Pass \(passNumber) completed. Output size: \(outputSize) bytes.")

                if let targetMB = config.targetSizeMB, config.allowSecondPass, passesLeft > 1 {
                    let targetSizeBytes = Int64(targetMB * 1024 * 1024)
                    if outputSize > Int64(Double(targetSizeBytes) * 1.25) {
                        pkgLogger.notice("Output size (\(outputSize) bytes) overshot target (\(targetSizeBytes) bytes) by 1.25x+. Retrying second pass with 20% lower bitrate.")
                        currentVideoBitrate = Int(Double(currentVideoBitrate) * 0.80)
                        passesLeft -= 1
                        continue
                    }
                }

                finalSuccess = true
                break
            } catch {
                pkgLogger.error("Pass \(passNumber) failed with error: \(error.localizedDescription)")
                if passesLeft > 1 && !Task.isCancelled {
                    pkgLogger.notice("First pass failed. Retrying second pass with standard fallback settings...")
                    currentVideoBitrate = Int(Double(currentVideoBitrate) * 0.85)
                    passesLeft -= 1
                    continue
                } else {
                    throw error
                }
            }
        }

        guard finalSuccess else {
            throw VideoCompressionError.encodingFailed("All passes failed.")
        }
    }

    private func runSinglePass(
        asset: AVAsset,
        videoTrack: AVAssetTrack,
        audioTrack: AVAssetTrack?,
        geometry: VideoGeometry,
        outputURL: URL,
        targetFPS: Double,
        videoBitrate: Int,
        audioBitrateBps: Int,
        preserveHDR: Bool,
        codec: AVVideoCodecType,
        duration: Double,
        passNumber: Int,
        logger: VideoCompressionLogging?,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws {
        let pkgLogger = PackageLogger(clientLogger: logger, category: "WriterEnginePass")

        pkgLogger.info("Selected audio strategy: \(audioTrack == nil ? "no audio" : "first track only")")

        pkgLogger.notice("Compression phase: Configuring video composition")

        let composition = AVMutableVideoComposition()
        composition.renderSize = geometry.renderSize
        composition.frameDuration = CMTime(value: 1, timescale: Int32(targetFPS))

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

        let finalTransform = VideoTransformBuilder.buildTransform(for: geometry)
        layerInstruction.setTransform(finalTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]

        pkgLogger.notice("Compression phase: Configuring reader")
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            pkgLogger.error("Reader creation failed: \(error.localizedDescription)")
            throw VideoCompressionError.readerCreationFailed(error.localizedDescription)
        }

        let videoOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: [videoTrack],
            videoSettings: videoOutputSettings
        )
        // This output does the heavy per-frame work for high-FPS 4K HDR sources:
        // decode, orientation transform, scaling, color conversion, and pixel buffer generation.
        // Do not bypass it for portrait videos; it preserves orientation and social upload compatibility.
        videoOutput.videoComposition = composition
        videoOutput.alwaysCopiesSampleData = false
        reader.add(videoOutput)

        var audioOutput: AVAssetReaderTrackOutput? = nil
        if let audioTrack = audioTrack {
            let audioOutputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100.0,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false
            ]
            let out = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioOutputSettings)
            out.alwaysCopiesSampleData = false
            reader.add(out)
            audioOutput = out
        }

        pkgLogger.notice("Compression phase: Configuring writer")
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            pkgLogger.error("Writer creation failed: \(error.localizedDescription)")
            throw VideoCompressionError.writerCreationFailed(error.localizedDescription)
        }

        self.reader = reader
        self.writer = writer

        defer {
            self.reader = nil
            self.writer = nil
        }

        let videoWriterSettings = VideoEncodingSettings.createVideoSettings(
            codec: codec,
            width: Int(geometry.renderSize.width),
            height: Int(geometry.renderSize.height),
            bitrate: videoBitrate,
            fps: targetFPS,
            preserveHDR: preserveHDR
        )

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoWriterSettings)
        videoInput.expectsMediaDataInRealTime = false
        videoInput.transform = .identity // Baked into pixels

        let canAddVideo = writer.canAdd(videoInput)
        if canAddVideo {
            writer.add(videoInput)
        }

        var audioInput: AVAssetWriterInput? = nil
        if audioOutput != nil {
            let audioWriterSettings = VideoEncodingSettings.createAudioSettings(bitrateBps: audioBitrateBps)
            let inp = AVAssetWriterInput(mediaType: .audio, outputSettings: audioWriterSettings)
            inp.expectsMediaDataInRealTime = false

            let canAddAudio = writer.canAdd(inp)
            if canAddAudio {
                writer.add(inp)
                audioInput = inp
            }
        }

        let startReadingResult = reader.startReading()
        if !startReadingResult {
            pkgLogger.error("Reader start failed: \(String(describing: reader.error))")
            throw reader.error.map { VideoCompressionError.readerCreationFailed($0.localizedDescription) }
                ?? VideoCompressionError.readerCreationFailed("Unknown error")
        }

        let startWritingResult = writer.startWriting()
        if !startWritingResult {
            pkgLogger.error("Writer start failed: \(String(describing: writer.error))")
            throw writer.error.map { VideoCompressionError.writerCreationFailed($0.localizedDescription) }
                ?? VideoCompressionError.writerCreationFailed("Unknown error")
        }

        writer.startSession(atSourceTime: .zero)

        pkgLogger.notice("Compression phase: Encoding")
        let group = DispatchGroup()
        let videoQueue = DispatchQueue(label: "com.compressionkit.videoQueue")
        let audioQueue = DispatchQueue(label: "com.compressionkit.audioQueue")

        let stateBox = CompressionStateBox()
        let videoInputBox = SendableBox(videoInput)
        let videoOutputBox = SendableBox(videoOutput)

        let startTime = Date()

        let readerBox = SendableBox(reader)
        let writerBox = SendableBox(writer)

        group.enter()
        videoInputBox.value.requestMediaDataWhenReady(on: videoQueue) {
            autoreleasepool {
                while videoInputBox.value.isReadyForMoreMediaData {
                    if Task.isCancelled {
                        videoInputBox.value.markAsFinished()
                        group.leave()
                        return
                    }

                    guard let sampleBuffer = videoOutputBox.value.copyNextSampleBuffer() else {
                        videoInputBox.value.markAsFinished()
                        group.leave()
                        return
                    }

                    if stateBox.isFirstVideoSample {
                        stateBox.isFirstVideoSample = false
                    }

                    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                    if stateBox.lastVideoPTS.isValid && targetFPS > 0 {
                        let delta = pts - stateBox.lastVideoPTS
                        let limit = 1.0 / targetFPS
                        if delta.seconds < (limit - 0.002) {
                            continue
                        }
                    }
                    stateBox.lastVideoPTS = pts
                    stateBox.framesProcessed += 1

                    let success = videoInputBox.value.append(sampleBuffer)
                    if !success {
                        pkgLogger.error("Video append failed at frame \(stateBox.framesProcessed). Reader status: \(readerBox.value.status.rawValue), writer status: \(writerBox.value.status.rawValue).")
                        videoInputBox.value.markAsFinished()
                        group.leave()
                        return
                    }

                    let progressPercent = min(1.0, max(0.0, pts.seconds / duration))
                    let pctInt = Int(progressPercent * 100)

                    if pctInt >= stateBox.lastLoggedProgress + 5 || progressPercent == 1.0 {
                        stateBox.lastLoggedProgress = pctInt
                        pkgLogger.info("Progress: \(pctInt)%")
                        onProgress(progressPercent)
                    }

                    let now = Date()
                    if now.timeIntervalSince(stateBox.lastTimeLoggedDetails) >= 5.0 {
                        stateBox.lastTimeLoggedDetails = now
                        let elapsed = now.timeIntervalSince(startTime)
                        let remaining = progressPercent > 0.01 ? (elapsed / progressPercent) - elapsed : 0.0
                        pkgLogger.info("""
                        Encoding Status:
                        Frames processed: \(stateBox.framesProcessed)
                        Samples processed: \(stateBox.framesProcessed + stateBox.audioSamplesCount)
                        Current pass: \(passNumber)
                        Elapsed time: \(String(format: "%.1fs", elapsed))
                        Estimated remaining time: \(String(format: "%.1fs", remaining))
                        """)
                    }
                }
            }
        }

        if let audioInput = audioInput, let audioOutput = audioOutput {
            let audioInputBox = SendableBox(audioInput)
            let audioOutputBox = SendableBox(audioOutput)

            group.enter()
            audioInputBox.value.requestMediaDataWhenReady(on: audioQueue) {
                autoreleasepool {
                    while audioInputBox.value.isReadyForMoreMediaData {
                        if Task.isCancelled {
                            audioInputBox.value.markAsFinished()
                            group.leave()
                            return
                        }

                        guard let sampleBuffer = audioOutputBox.value.copyNextSampleBuffer() else {
                            audioInputBox.value.markAsFinished()
                            group.leave()
                            return
                        }

                        if stateBox.isFirstAudioSample {
                            stateBox.isFirstAudioSample = false
                        }

                        stateBox.audioSamplesCount += 1

                        let success = audioInputBox.value.append(sampleBuffer)
                        if !success {
                            pkgLogger.error("Audio append failed at sample \(stateBox.audioSamplesCount). Reader status: \(readerBox.value.status.rawValue), writer status: \(writerBox.value.status.rawValue).")
                            audioInputBox.value.markAsFinished()
                            group.leave()
                            return
                        }
                    }
                }
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            group.notify(queue: .main) {
                if readerBox.value.status == .failed {
                    continuation.resume(throwing: readerBox.value.error.map { VideoCompressionError.encodingFailed($0.localizedDescription) }
                        ?? VideoCompressionError.encodingFailed("Reader failed"))
                } else if writerBox.value.status == .failed {
                    continuation.resume(throwing: writerBox.value.error.map { VideoCompressionError.encodingFailed($0.localizedDescription) }
                        ?? VideoCompressionError.encodingFailed("Writer failed"))
                } else {
                    continuation.resume()
                }
            }
        }

        pkgLogger.notice("Compression phase: Finalizing file")
        await writer.finishWriting()

        if writer.status == .failed {
            throw writer.error.map { VideoCompressionError.encodingFailed($0.localizedDescription) }
                ?? VideoCompressionError.encodingFailed("Writer finish failed")
        }

        pkgLogger.info("Encoding pass completed successfully. Frames: \(stateBox.framesProcessed), Audio samples: \(stateBox.audioSamplesCount).")
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
