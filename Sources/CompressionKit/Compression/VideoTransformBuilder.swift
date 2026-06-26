import Foundation
import CoreGraphics

struct VideoTransformBuilder: Sendable {
    /// Builds the final transform matrix used to scale, rotate, and center frames within the composition bounds.
    static func buildTransform(for geometry: VideoGeometry) -> CGAffineTransform {
        let scale = min(
            geometry.targetDisplaySize.width / geometry.displaySize.width,
            geometry.targetDisplaySize.height / geometry.displaySize.height
        )
        let scaledTransform = geometry.preferredTransform.concatenating(
            CGAffineTransform(scaleX: scale, y: scale)
        )
        let transformedRect = CGRect(origin: .zero, size: geometry.naturalSize)
            .applying(scaledTransform)
        let translation = CGAffineTransform(
            translationX: -transformedRect.minX + (geometry.targetDisplaySize.width - transformedRect.width) / 2,
            y: -transformedRect.minY + (geometry.targetDisplaySize.height - transformedRect.height) / 2
        )
        return scaledTransform.concatenating(translation)
    }
}
