import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

public struct PickedVideoFile: Transferable {
    public let url: URL
    
    public init(url: URL) {
        self.url = url
    }

    public static var transferRepresentation: some TransferRepresentation {
        // 1. Prefer QuickTime Movie first to get the original MOV format directly
        FileRepresentation(contentType: .quickTimeMovie) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            try PickedVideoFile.importReceivedFile(received.file, preferredExtension: "mov")
        }

        // 2. Generic Movie representation fallback
        FileRepresentation(contentType: .movie) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            try PickedVideoFile.importReceivedFile(received.file, preferredExtension: "mov")
        }

        // 3. MPEG-4 video format fallback
        FileRepresentation(contentType: .mpeg4Movie) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            try PickedVideoFile.importReceivedFile(received.file, preferredExtension: "mp4")
        }
    }
    
    private static func importReceivedFile(_ sourceURL: URL, preferredExtension: String) throws -> PickedVideoFile {
        let logger = OSLogVideoCompressionLogger()
        let pkgLogger = PackageLogger(clientLogger: logger, category: "FileAccess")
        
        pkgLogger.info("Transferable import started.")
        pkgLogger.info("Transferable temporary URL received: \(sourceURL.path)")
        
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: sourceURL.path)
        let readable = fileManager.isReadableFile(atPath: sourceURL.path)
        pkgLogger.info("Temporary URL file exists check: \(exists)")
        pkgLogger.info("Temporary URL readable check: \(readable)")
        
        var fileSize: Int64? = nil
        if let attrs = try? fileManager.attributesOfItem(atPath: sourceURL.path),
           let size = attrs[.size] as? Int64 {
            fileSize = size
        }
        pkgLogger.info("Temporary URL file size check: \(fileSize ?? -1)")
        
        if !exists {
            pkgLogger.error("Temporary file does not exist.")
            throw VideoCompressionError.inputFileMissing
        }
        
        let copiedURL = try VideoFileManager.copyPickedVideoToSandbox(
            from: sourceURL,
            suggestedFileName: sourceURL.lastPathComponent,
            logger: logger
        )
        
        pkgLogger.info("Transferable video load completed. Sandbox URL: \(copiedURL.path)")
        return PickedVideoFile(url: copiedURL)
    }
}
