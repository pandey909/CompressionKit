import Foundation

public protocol VideoCompressionLogging: Sendable {
    func log(_ event: CompressionLogEvent)
}

// Internal logging helper to bridge the protocol inside the package
struct PackageLogger: Sendable {
    let clientLogger: VideoCompressionLogging?
    let category: String
    
    func debug(_ message: String) {
        clientLogger?.log(CompressionLogEvent(level: .debug, category: category, message: message))
    }
    
    func info(_ message: String) {
        clientLogger?.log(CompressionLogEvent(level: .info, category: category, message: message))
    }
    
    func notice(_ message: String) {
        clientLogger?.log(CompressionLogEvent(level: .notice, category: category, message: message))
    }
    
    func warning(_ message: String) {
        clientLogger?.log(CompressionLogEvent(level: .warning, category: category, message: message))
    }
    
    func error(_ message: String) {
        clientLogger?.log(CompressionLogEvent(level: .error, category: category, message: message))
    }
    
    func fault(_ message: String) {
        clientLogger?.log(CompressionLogEvent(level: .fault, category: category, message: message))
    }
}
