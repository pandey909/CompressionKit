import Foundation
import OSLog

public struct OSLogVideoCompressionLogger: VideoCompressionLogging {
    private let logger = Logger(subsystem: CompressionKitConstants.logSubsystem, category: "Compression")
    
    public init() {}
    
    public func log(_ event: CompressionLogEvent) {
        let osLogMessage = "[\(event.category)] \(event.message)"
        switch event.level {
        case .debug:
            logger.debug("\(osLogMessage, privacy: .public)")
        case .info:
            logger.info("\(osLogMessage, privacy: .public)")
        case .notice:
            logger.notice("\(osLogMessage, privacy: .public)")
        case .warning:
            logger.warning("\(osLogMessage, privacy: .public)")
        case .error:
            logger.error("\(osLogMessage, privacy: .public)")
        case .fault:
            logger.fault("\(osLogMessage, privacy: .public)")
        }
    }
}
