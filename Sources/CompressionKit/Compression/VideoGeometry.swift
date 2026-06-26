import Foundation
import CoreGraphics
import AVFoundation

struct VideoGeometry: Sendable {
    let naturalSize: CGSize
    let preferredTransform: CGAffineTransform
    let displaySize: CGSize
    let isPortrait: Bool
    let targetDisplaySize: CGSize
    let renderSize: CGSize
    
    init(naturalSize: CGSize, preferredTransform: CGAffineTransform, target: TargetResolution) {
        self.naturalSize = naturalSize
        self.preferredTransform = preferredTransform
        
        // Calculate display size from original track transform
        let rect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let displayWidth = abs(rect.width)
        let displayHeight = abs(rect.height)
        self.displaySize = CGSize(width: displayWidth, height: displayHeight)
        
        // Determine portrait orientation based on display size aspect ratio
        self.isPortrait = displaySize.width < displaySize.height
        
        // Determine target display size
        self.targetDisplaySize = Self.resolveTargetDimensions(
            displaySize: displaySize,
            target: target
        )
        
        // Under Strategy A (bake orientation into pixels), the target display size
        // is exactly the final pixel buffer size (renderSize).
        self.renderSize = self.targetDisplaySize
    }
    
    private static func resolveTargetDimensions(displaySize: CGSize, target: TargetResolution) -> CGSize {
        guard target != .original, displaySize.width > 0, displaySize.height > 0 else {
            return displaySize
        }
        
        let targetMax: CGFloat
        switch target {
        case .original: return displaySize
        case .r1080p: targetMax = 1920
        case .r720p: targetMax = 1280
        case .r540p: targetMax = 960
        }
        
        let currentWidth = displaySize.width
        let currentHeight = displaySize.height
        
        let targetWidth: CGFloat
        let targetHeight: CGFloat
        
        if currentWidth > currentHeight {
            // Landscape
            let scale = targetMax / currentWidth
            targetWidth = targetMax
            targetHeight = (currentHeight * scale).rounded()
        } else {
            // Portrait or Square
            let scale = targetMax / currentHeight
            targetHeight = targetMax
            targetWidth = (currentWidth * scale).rounded()
        }
        
        // Enforce even dimensions
        return CGSize(
            width: CGFloat(Int(targetWidth) & ~1),
            height: CGFloat(Int(targetHeight) & ~1)
        )
    }
}
