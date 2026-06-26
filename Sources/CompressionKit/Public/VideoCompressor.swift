import Foundation

public struct VideoCompressorConfiguration: Sendable {
    public let logger: VideoCompressionLogging?
    public let deleteOriginal: Bool
    
    public static var `default`: VideoCompressorConfiguration {
        VideoCompressorConfiguration(logger: OSLogVideoCompressionLogger(), deleteOriginal: false)
    }
    
    public init(logger: VideoCompressionLogging? = OSLogVideoCompressionLogger(), deleteOriginal: Bool = false) {
        self.logger = logger
        self.deleteOriginal = deleteOriginal
    }
}

public final class VideoCompressor: Sendable {
    public typealias Configuration = VideoCompressorConfiguration
    
    public let configuration: VideoCompressorConfiguration
    private let engine: VideoCompressionEngine
    
    public init(configuration: VideoCompressorConfiguration = .default) {
        self.configuration = configuration
        self.engine = VideoCompressionEngine(logger: configuration.logger)
    }
    
    /// Synchronously wait for compression to complete and return the final CompressionResult.
    public func compress(
        inputURL: URL,
        mode: CompressionMode
    ) async throws -> CompressionResult {
        let stream = compressWithProgress(inputURL: inputURL, mode: mode)
        var lastResult: CompressionResult? = nil
        
        for try await progress in stream {
            if case .completed(let result) = progress {
                lastResult = result
            }
        }
        
        guard let finalResult = lastResult else {
            throw VideoCompressionError.encodingFailed("Compression completed but no result returned.")
        }
        
        return finalResult
    }
    
    /// Returns a stream of progressive updates during the video compression process.
    public func compressWithProgress(
        inputURL: URL,
        mode: CompressionMode
    ) -> AsyncThrowingStream<CompressionProgress, Error> {
        let outputURL = VideoFileManager.getOutputURL(for: inputURL, logger: configuration.logger)
        let config = CompressionConfig(mode: mode, deleteOriginal: configuration.deleteOriginal)
        
        let streamFuture = Task {
            try await engine.compress(
                inputURL: inputURL,
                outputURL: outputURL,
                config: config
            )
        }
        
        return AsyncThrowingStream { continuation in
            let outerTask = Task {
                do {
                    let innerStream = try await streamFuture.value
                    for try await progress in innerStream {
                        if Task.isCancelled {
                            continuation.finish(throwing: VideoCompressionError.encodingFailed("Cancelled."))
                            return
                        }
                        
                        continuation.yield(progress)
                        
                        if case .completed = progress {
                            if configuration.deleteOriginal {
                                VideoFileManager.cleanup(url: inputURL, logger: configuration.logger)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    VideoFileManager.cleanup(url: outputURL, logger: configuration.logger)
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable status in
                outerTask.cancel()
                streamFuture.cancel()
                Task { [weak self] in
                    guard let self = self else { return }
                    await self.engine.cancelActiveCompression()
                }
            }
        }
    }
    
    /// Cancels any active compression processes managed by this compressor instance.
    public func cancel() {
        Task {
            await engine.cancelActiveCompression()
        }
    }
}
