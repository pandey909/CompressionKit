import Photos
import Foundation

public struct PhotoPermissionManager: Sendable {
    public static func checkAndRequestPermission(
        logger: VideoCompressionLogging? = OSLogVideoCompressionLogger()
    ) async -> PHAuthorizationStatus {
        let pkgLogger = PackageLogger(clientLogger: logger, category: "PhotoPermission")
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        pkgLogger.info("Photo library authorization status: \(statusName(for: currentStatus))")
        
        if currentStatus == .notDetermined {
            pkgLogger.info("Photo library authorization request started")
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            pkgLogger.info("Photo library authorization result: \(statusName(for: newStatus))")
            return newStatus
        }
        
        return currentStatus
    }
    
    private static func statusName(for status: PHAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .limited: return "limited"
        @unknown default: return "unknown"
        }
    }
}
