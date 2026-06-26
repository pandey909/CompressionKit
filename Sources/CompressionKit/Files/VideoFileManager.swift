import Foundation

public struct VideoFileManager: Sendable {
    public static func copyToSandbox(
        sourceURL: URL,
        logger: VideoCompressionLogging? = OSLogVideoCompressionLogger()
    ) throws -> URL {
        let pkgLogger = PackageLogger(clientLogger: logger, category: "FileManager")
        pkgLogger.info("Copy to sandbox started. Source: \(sourceURL.lastPathComponent)")
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let uniqueName = UUID().uuidString
        let destinationURL = tempDirectory.appendingPathComponent(uniqueName).appendingPathExtension(sourceURL.pathExtension)
        
        let accessGranted = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            let attrs = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let fileSize = attrs[.size] as? Int64 ?? 0
            pkgLogger.info("Copy to sandbox completed. Size: \(fileSize) bytes.")
            return destinationURL
        } catch {
            pkgLogger.error("File copy to sandbox failed: \(error.localizedDescription)")
            throw VideoCompressionError.inputFileNotReadable
        }
    }
    
    public static func getOutputURL(
        for inputURL: URL,
        logger: VideoCompressionLogging? = OSLogVideoCompressionLogger()
    ) -> URL {
        let pkgLogger = PackageLogger(clientLogger: logger, category: "FileManager")
        let tempDirectory = FileManager.default.temporaryDirectory
        let uniqueName = UUID().uuidString
        let outputURL = tempDirectory.appendingPathComponent("\(uniqueName)_compressed.mp4")
        pkgLogger.info("Output URL generated: \(outputURL.lastPathComponent)")
        return outputURL
    }
    
    public static func cleanup(
        url: URL,
        logger: VideoCompressionLogging? = OSLogVideoCompressionLogger()
    ) {
        let pkgLogger = PackageLogger(clientLogger: logger, category: "FileManager")
        let path = url.path
        if FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.removeItem(at: url)
                pkgLogger.info("Cleaned up temporary file: \(url.lastPathComponent)")
            } catch {
                pkgLogger.error("Failed to delete file: \(error.localizedDescription)")
            }
        }
    }
    
    public static func hasDiskSpace(
        requiredBytes: Int64,
        logger: VideoCompressionLogging? = OSLogVideoCompressionLogger()
    ) -> Bool {
        let pkgLogger = PackageLogger(clientLogger: logger, category: "FileManager")
        pkgLogger.info("Disk space check started for \(requiredBytes) bytes.")
        let fileManager = FileManager.default
        let path = NSTemporaryDirectory()
        do {
            let values = try fileManager.attributesOfFileSystem(forPath: path)
            if let freeSpace = values[.systemFreeSize] as? Int64 {
                let safetyMargin: Int64 = 200 * 1024 * 1024 // 200MB margin
                let passed = freeSpace > (requiredBytes + safetyMargin)
                pkgLogger.info("Free space: \(freeSpace). Safety margin: \(safetyMargin). Passed: \(passed)")
                return passed
            }
        } catch {
            pkgLogger.error("Failed to query system space: \(error.localizedDescription)")
        }
        return true
    }
    
    public static func copyPickedVideoToSandbox(
        from sourceURL: URL,
        suggestedFileName: String?,
        logger: VideoCompressionLogging? = OSLogVideoCompressionLogger(),
        onStatusChanged: (@Sendable (String) -> Void)? = nil
    ) throws -> URL {
        let pkgLogger = PackageLogger(clientLogger: logger, category: "FileManager")
        pkgLogger.info("Sandbox copy requested. Source: \(sourceURL.lastPathComponent)")
        
        let sourceDiagnostics = diagnostics(for: sourceURL)
        pkgLogger.info("Source diagnostics: exists=\(sourceDiagnostics.exists), readable=\(sourceDiagnostics.readable), size=\(sourceDiagnostics.fileSize ?? -1)")
        
        guard sourceDiagnostics.exists else {
            throw VideoCompressionError.inputFileMissing
        }
        
        onStatusChanged?("Copying video into app storage...")
        
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let importedDirectory = cachesDirectory.appendingPathComponent("ImportedVideos", isDirectory: true)
        
        if !fileManager.fileExists(atPath: importedDirectory.path) {
            try fileManager.createDirectory(at: importedDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let uniqueName = "\(UUID().uuidString).\(ext)"
        let destinationURL = importedDirectory.appendingPathComponent(uniqueName)
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            pkgLogger.error("Sandbox copy failed: \(error.localizedDescription)")
            throw VideoCompressionError.inputFileNotReadable
        }
        
        let destDiagnostics = diagnostics(for: destinationURL)
        guard destDiagnostics.exists else {
            throw VideoCompressionError.outputFileMissing
        }
        guard destDiagnostics.readable else {
            throw VideoCompressionError.inputFileNotReadable
        }
        
        return destinationURL
    }
    
    public static func diagnostics(for url: URL) -> FileDiagnostics {
        let fileManager = FileManager.default
        let path = url.path
        
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: path, isDirectory: &isDir)
        let readable = fileManager.isReadableFile(atPath: path)
        let isDirectory = isDir.boolValue
        
        var size: Int64? = nil
        if exists && !isDirectory {
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let fileSize = attrs[.size] as? Int64 {
                size = fileSize
            }
        }
        
        return FileDiagnostics(
            url: url,
            exists: exists,
            readable: readable,
            isDirectory: isDirectory,
            fileSize: size,
            pathExtension: url.pathExtension,
            standardizedPath: url.standardized.path
        )
    }
}

public struct FileDiagnostics: Sendable {
    public let url: URL
    public let exists: Bool
    public let readable: Bool
    public let isDirectory: Bool
    public let fileSize: Int64?
    public let pathExtension: String
    public let standardizedPath: String
}
