import Foundation

actor VideoCompressionEngine {
    private var activeWriterEngine: VideoWriterCompressionEngine?
    private let logger: VideoCompressionLogging?

    init(logger: VideoCompressionLogging?) {
        self.logger = logger
    }

    func cancelActiveCompression() async {
        await activeWriterEngine?.cancel()
        activeWriterEngine = nil
    }

    func compress(
        inputURL: URL,
        outputURL: URL,
        config: CompressionConfig
    ) async throws -> AsyncThrowingStream<CompressionProgress, Error> {
        let writerEngine = VideoWriterCompressionEngine()
        self.activeWriterEngine = writerEngine

        return AsyncThrowingStream { continuation in
            let startTime = Date()

            let compressionTask = Task {
                do {
                    continuation.yield(.preparing)

                    guard FileManager.default.fileExists(atPath: inputURL.path) else {
                        throw VideoCompressionError.inputFileMissing
                    }

                    let attr = try? FileManager.default.attributesOfItem(atPath: inputURL.path)
                    let fileSize = attr?[.size] as? Int64 ?? 0

                    guard VideoFileManager.hasDiskSpace(requiredBytes: fileSize, logger: logger) else {
                        throw VideoCompressionError.insufficientDiskSpace
                    }

                    continuation.yield(.readingMetadata)
                    let inputMetadata = try await VideoMetadataReader.readMetadata(for: inputURL, logger: logger)

                    continuation.yield(.calculatingSettings)

                    continuation.yield(.encoding(percentage: 0.0, elapsedTime: 0.0, estimatedRemainingTime: nil))

                    try await writerEngine.compress(
                        inputURL: inputURL,
                        outputURL: outputURL,
                        config: config,
                        logger: logger
                    ) { progress in
                        let elapsedTime = Date().timeIntervalSince(startTime)
                        let remainingTime = progress > 0.01 ? (elapsedTime / progress) - elapsedTime : nil
                        continuation.yield(.encoding(
                            percentage: progress,
                            elapsedTime: elapsedTime,
                            estimatedRemainingTime: remainingTime
                        ))
                    }

                    continuation.yield(.finalizing)

                    continuation.yield(.validating)
                    let outputMetadata = try await VideoMetadataReader.readMetadata(for: outputURL, logger: logger)

                    let warning = try CompressionQualityValidator.validate(
                        inputMetadata: inputMetadata,
                        outputMetadata: outputMetadata
                    )

                    let originalSize = inputMetadata.fileSizeBytes
                    let compressedSize = outputMetadata.fileSizeBytes
                    let savedBytes = max(0, originalSize - compressedSize)
                    let savedPercentage = originalSize > 0 ? (Double(savedBytes) / Double(originalSize)) : 0.0
                    let compressionRatio = compressedSize > 0 ? (Double(originalSize) / Double(compressedSize)) : 1.0

                    let result = CompressionResult(
                        inputURL: inputURL,
                        outputURL: outputURL,
                        inputMetadata: inputMetadata,
                        outputMetadata: outputMetadata,
                        originalSizeBytes: originalSize,
                        compressedSizeBytes: compressedSize,
                        savedPercentage: savedPercentage,
                        compressionRatio: compressionRatio,
                        duration: outputMetadata.duration,
                        qualityWarning: warning
                    )

                    continuation.yield(.completed(result))
                    continuation.finish()
                } catch {
                    let finalError: Error
                    if Task.isCancelled {
                        finalError = VideoCompressionError.encodingFailed("Task was cancelled.")
                    } else {
                        finalError = error
                    }
                    continuation.finish(throwing: finalError)
                }
            }

            continuation.onTermination = { @Sendable status in
                compressionTask.cancel()
                Task { [weak self] in
                    guard let self = self else { return }
                    await self.cancelActiveCompression()
                }
            }
        }
    }
}
