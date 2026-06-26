import Foundation

struct CompressionQualityValidator: Sendable {
    /// Validates the compressed output video against the original source video properties.
    /// - Returns: A quality warning string, or `nil` if there are no warnings.
    /// - Throws: `VideoCompressionError.qualityValidationFailed` if a validation rule is violated.
    static func validate(
        inputMetadata: VideoMetadata,
        outputMetadata: VideoMetadata
    ) throws -> String? {
        let inputWidth = inputMetadata.displayWidth
        let inputHeight = inputMetadata.displayHeight
        let outputWidth = outputMetadata.displayWidth
        let outputHeight = outputMetadata.displayHeight
        
        let inputIsPortrait = inputMetadata.isPortrait
        let outputIsPortrait = outputMetadata.isPortrait
        let orientationPreserved = inputIsPortrait == outputIsPortrait
        
        guard orientationPreserved else {
            throw VideoCompressionError.qualityValidationFailed(
                "Orientation changed from \(inputIsPortrait ? "portrait" : "landscape") to \(outputIsPortrait ? "portrait" : "landscape")"
            )
        }
        
        let inputIsLargePortrait = inputWidth >= 540 && inputHeight >= 960
        let inputIsLargeLandscape = inputWidth >= 960 && inputHeight >= 540
        if inputIsLargePortrait || inputIsLargeLandscape {
            if outputWidth < 480 || outputHeight < 480 {
                throw VideoCompressionError.qualityValidationFailed(
                    "Output resolution too low (\(outputWidth)x\(outputHeight)) for high resolution source video"
                )
            }
        }
        
        if outputWidth < 540 || outputHeight < 540 {
            return "Output is only \(outputWidth)x\(outputHeight). This is quite degraded for a high resolution source video."
        }
        
        return nil
    }
}
