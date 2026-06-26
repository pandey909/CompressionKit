import Foundation

public enum VideoCompressionError: Error, Sendable {
    case inputFileMissing
    case inputFileNotReadable
    case unsupportedVideo
    case metadataReadFailed(String)
    case insufficientDiskSpace
    case readerCreationFailed(String)
    case writerCreationFailed(String)
    case encodingFailed(String)
    case outputFileMissing
    case qualityValidationFailed(String)
    case photoPermissionDenied
    case photosAssetFetchFailed
    case photosOriginalResourceMissing
    case photosOriginalResourceExportFailed(String)
    
    public var userMessage: String {
        switch self {
        case .inputFileMissing:
            return "The source video file could not be found."
        case .inputFileNotReadable:
            return "The source video file is not readable."
        case .unsupportedVideo:
            return "This video format is not supported."
        case .metadataReadFailed:
            return "Failed to read the video's details."
        case .insufficientDiskSpace:
            return "Not enough storage space available to perform compression."
        case .readerCreationFailed, .writerCreationFailed:
            return "Unable to initialize the compression engine."
        case .encodingFailed:
            return "The video encoding process failed."
        case .outputFileMissing:
            return "The compressed output file could not be found."
        case .qualityValidationFailed(let reason):
            return "Quality validation failed: \(reason)."
        case .photoPermissionDenied:
            return "Access to Photo Library was denied. Please check your system Settings."
        case .photosAssetFetchFailed:
            return "Failed to locate the selected video in the Photo Library."
        case .photosOriginalResourceMissing:
            return "The original video resource is missing from this Photo Library item."
        case .photosOriginalResourceExportFailed:
            return "Failed to download the original video resource from iCloud."
        }
    }
    
    public var technicalMessage: String {
        switch self {
        case .inputFileMissing:
            return "Input file does not exist at local path."
        case .inputFileNotReadable:
            return "Input file exists but isNotReadableFile."
        case .unsupportedVideo:
            return "Missing video track or format descriptions."
        case .metadataReadFailed(let details):
            return "Metadata read failed: \(details)"
        case .insufficientDiskSpace:
            return "Available filesystem systemFreeSize is insufficient for required bytes and safety margin."
        case .readerCreationFailed(let details):
            return "AVAssetReader initialization failed: \(details)"
        case .writerCreationFailed(let details):
            return "AVAssetWriter initialization failed: \(details)"
        case .encodingFailed(let details):
            return "Encoding session failed during frame writing: \(details)"
        case .outputFileMissing:
            return "AVAssetWriter completed successfully but destination file does not exist."
        case .qualityValidationFailed(let details):
            return "Quality validation failed: \(details)"
        case .photoPermissionDenied:
            return "PHPhotoLibrary authorization status is restricted or denied."
        case .photosAssetFetchFailed:
            return "PHAsset fetchAssets returned empty results."
        case .photosOriginalResourceMissing:
            return "No asset resources of type .video or .fullSizeVideo."
        case .photosOriginalResourceExportFailed(let details):
            return "PHAssetResourceManager writeData failed with error: \(details)"
        }
    }
    
    public var recoverySuggestion: String {
        switch self {
        case .inputFileMissing, .inputFileNotReadable:
            return "Check if the video is located in a sandbox directory and startAccessingSecurityScopedResource() has been called."
        case .unsupportedVideo:
            return "Ensure the input video is a valid QuickTime movie (.mov) or MPEG-4 (.mp4) file."
        case .metadataReadFailed:
            return "Ensure the file has not been corrupted or modified during copy."
        case .insufficientDiskSpace:
            return "Free up space on the device by deleting unused files or cache and try again."
        case .readerCreationFailed, .writerCreationFailed, .encodingFailed:
            return "Restart the compression process. Ensure no other applications are using the encoder hardware concurrently."
        case .outputFileMissing:
            return "Ensure the output path is in a writable temporary directory and target filesystem exists."
        case .qualityValidationFailed:
            return "Try a different quality configuration or higher bitrate preset."
        case .photoPermissionDenied:
            return "Prompt the user to navigate to iOS Settings -> Privacy -> Photos and enable Read/Write permissions."
        case .photosAssetFetchFailed, .photosOriginalResourceMissing:
            return "Check if the asset has been deleted from Photos."
        case .photosOriginalResourceExportFailed:
            return "Check the internet connection. The original video may need to download from iCloud."
        }
    }
}

extension VideoCompressionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .metadataReadFailed(let details):
            return "metadataReadFailed: \(details) (\(technicalMessage))"
        case .readerCreationFailed(let details):
            return "readerCreationFailed: \(details) (\(technicalMessage))"
        case .writerCreationFailed(let details):
            return "writerCreationFailed: \(details) (\(technicalMessage))"
        case .encodingFailed(let details):
            return "encodingFailed: \(details) (\(technicalMessage))"
        case .photosOriginalResourceExportFailed(let details):
            return "photosOriginalResourceExportFailed: \(details) (\(technicalMessage))"
        case .qualityValidationFailed(let details):
            return "qualityValidationFailed: \(details) (\(technicalMessage))"
        default:
            return "\(userMessage) (\(technicalMessage))"
        }
    }
}
