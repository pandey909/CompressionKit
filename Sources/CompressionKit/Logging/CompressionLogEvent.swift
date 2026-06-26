import Foundation

public enum CompressionLogLevel: String, Sendable {
    case debug
    case info
    case notice
    case warning
    case error
    case fault
}

public struct CompressionLogEvent: Sendable {
    public let level: CompressionLogLevel
    public let category: String
    public let message: String
    public let date: Date
    
    public init(level: CompressionLogLevel, category: String, message: String, date: Date = Date()) {
        self.level = level
        self.category = category
        self.message = message
        self.date = date
    }
}
