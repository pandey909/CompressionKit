#if canImport(UIKit)
import Foundation
import CoreGraphics
import ImageIO
@preconcurrency import UIKit

public struct ImageCompressionAttempt: Sendable, Equatable {
    public let maxLongEdge: CGFloat
    public let quality: CGFloat
    
    public init(maxLongEdge: CGFloat, quality: CGFloat) {
        self.maxLongEdge = maxLongEdge
        self.quality = quality
    }
}

public struct ImageCompressionOptions: Sendable, Equatable {
    public let mainMaxBytes: Int
    public let thumbnailMaxBytes: Int?
    public let mainPolicy: [ImageCompressionAttempt]
    public let thumbnailPolicy: [ImageCompressionAttempt]
    public let previewThumbnailOptions: ImageThumbnailOptions?
    public let format: String
    public let mimeType: String
    public let fileExtension: String
    
    public init(
        mainMaxBytes: Int,
        thumbnailMaxBytes: Int? = nil,
        mainPolicy: [ImageCompressionAttempt],
        thumbnailPolicy: [ImageCompressionAttempt] = [],
        previewThumbnailOptions: ImageThumbnailOptions? = nil,
        format: String,
        mimeType: String,
        fileExtension: String
    ) {
        self.mainMaxBytes = mainMaxBytes
        self.thumbnailMaxBytes = thumbnailMaxBytes
        self.mainPolicy = mainPolicy
        self.thumbnailPolicy = thumbnailPolicy
        self.previewThumbnailOptions = previewThumbnailOptions
        self.format = format
        self.mimeType = mimeType
        self.fileExtension = fileExtension
    }
    
    // Feed photos use JPEG because it keeps visual quality high while producing much smaller upload data than PNG.
    public static let post = ImageCompressionOptions(
        mainMaxBytes: 2 * 1024 * 1024,
        thumbnailMaxBytes: 350 * 1024,
        mainPolicy: [
            ImageCompressionAttempt(maxLongEdge: 2048, quality: 0.85),
            ImageCompressionAttempt(maxLongEdge: 2048, quality: 0.82),
            ImageCompressionAttempt(maxLongEdge: 2048, quality: 0.80),
            ImageCompressionAttempt(maxLongEdge: 1920, quality: 0.82),
            ImageCompressionAttempt(maxLongEdge: 1920, quality: 0.76),
            ImageCompressionAttempt(maxLongEdge: 1920, quality: 0.72)
        ],
        thumbnailPolicy: [
            ImageCompressionAttempt(maxLongEdge: 720, quality: 0.75),
            ImageCompressionAttempt(maxLongEdge: 720, quality: 0.70),
            ImageCompressionAttempt(maxLongEdge: 640, quality: 0.72),
            ImageCompressionAttempt(maxLongEdge: 640, quality: 0.65)
        ],
        previewThumbnailOptions: ImageThumbnailOptions(
            maxBytes: 150 * 1024,
            policy: [
                ImageCompressionAttempt(maxLongEdge: 360, quality: 0.70),
                ImageCompressionAttempt(maxLongEdge: 360, quality: 0.65),
                ImageCompressionAttempt(maxLongEdge: 320, quality: 0.65),
                ImageCompressionAttempt(maxLongEdge: 320, quality: 0.60)
            ]
        ),
        format: "jpg",
        mimeType: "image/jpeg",
        fileExtension: "jpg"
    )
    
    public static let feedPost = post
}

public struct ImageThumbnailOptions: Sendable, Equatable {
    public let maxBytes: Int
    public let policy: [ImageCompressionAttempt]
    
    public init(maxBytes: Int, policy: [ImageCompressionAttempt]) {
        self.maxBytes = maxBytes
        self.policy = policy
    }
}

public struct ImageCompressionResult: Sendable {
    public let mainData: Data
    public let thumbnailData: Data?
    public let previewThumbnailData: Data?
    public let mainPixelSize: CGSize
    public let thumbnailPixelSize: CGSize?
    public let previewThumbnailPixelSize: CGSize?
    public let mainQuality: CGFloat
    public let thumbnailQuality: CGFloat?
    public let previewThumbnailQuality: CGFloat?
    public let mainAttempts: Int
    public let thumbnailAttempts: Int
    public let previewThumbnailAttempts: Int
    public let format: String
    public let mimeType: String
    public let fileExtension: String
    public let alphaDetected: Bool
    public let flattened: Bool
    public let compressionDurationMs: Int
    
    public init(
        mainData: Data,
        thumbnailData: Data?,
        previewThumbnailData: Data? = nil,
        mainPixelSize: CGSize,
        thumbnailPixelSize: CGSize?,
        previewThumbnailPixelSize: CGSize? = nil,
        mainQuality: CGFloat,
        thumbnailQuality: CGFloat?,
        previewThumbnailQuality: CGFloat? = nil,
        mainAttempts: Int,
        thumbnailAttempts: Int,
        previewThumbnailAttempts: Int = 0,
        format: String,
        mimeType: String,
        fileExtension: String,
        alphaDetected: Bool,
        flattened: Bool,
        compressionDurationMs: Int
    ) {
        self.mainData = mainData
        self.thumbnailData = thumbnailData
        self.previewThumbnailData = previewThumbnailData
        self.mainPixelSize = mainPixelSize
        self.thumbnailPixelSize = thumbnailPixelSize
        self.previewThumbnailPixelSize = previewThumbnailPixelSize
        self.mainQuality = mainQuality
        self.thumbnailQuality = thumbnailQuality
        self.previewThumbnailQuality = previewThumbnailQuality
        self.mainAttempts = mainAttempts
        self.thumbnailAttempts = thumbnailAttempts
        self.previewThumbnailAttempts = previewThumbnailAttempts
        self.format = format
        self.mimeType = mimeType
        self.fileExtension = fileExtension
        self.alphaDetected = alphaDetected
        self.flattened = flattened
        self.compressionDurationMs = compressionDurationMs
    }
}

public enum ImageCompressionError: Error, Sendable {
    case emptyPolicy
    case renderFailed
    case encodingFailed
    case sizeLimitExceeded(maxBytes: Int, actualBytes: Int)
}

extension ImageCompressionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyPolicy:
            return "Image compression policy cannot be empty."
        case .renderFailed:
            return "Image rendering failed."
        case .encodingFailed:
            return "JPEG encoding failed."
        case .sizeLimitExceeded(let maxBytes, let actualBytes):
            return "Compressed image is \(actualBytes) bytes, above the \(maxBytes) byte limit."
        }
    }
}

public struct ImageCompressor: Sendable {
    public let options: ImageCompressionOptions
    public let maxConcurrentTasks: Int
    
    public init(
        options: ImageCompressionOptions = .post,
        maxConcurrentTasks: Int = 2
    ) {
        self.options = options
        self.maxConcurrentTasks = min(3, max(1, maxConcurrentTasks))
    }
    
    public func compressImage(_ image: UIImage) async throws -> ImageCompressionResult {
        try await Self.compressImage(image, options: options)
    }
    
    public func compressImageData(_ data: Data) async throws -> ImageCompressionResult {
        try await Self.compressImageData(data, options: options)
    }
    
    public func compressImages(_ images: [UIImage]) async -> [Result<ImageCompressionResult, Error>] {
        await Self.compressImages(
            images,
            options: options,
            maxConcurrentTasks: maxConcurrentTasks
        )
    }
    
    public func compressImageData(_ imageData: [Data]) async -> [Result<ImageCompressionResult, Error>] {
        await Self.compressImageData(
            imageData,
            options: options,
            maxConcurrentTasks: maxConcurrentTasks
        )
    }
    
    public static func compressImage(
        _ image: UIImage,
        options: ImageCompressionOptions
    ) async throws -> ImageCompressionResult {
        // Use the UIImage path when the caller already decoded the image.
        // Re-decoding from Data adds extra work and can be slower in UI/demo flows.
        try await Task.detached(priority: .userInitiated) {
            try compressImageSync(image, options: options, debugLabel: nil)
        }.value
    }
    
    public static func compressImageData(
        _ data: Data,
        options: ImageCompressionOptions
    ) async throws -> ImageCompressionResult {
        // Use the Data path when raw file bytes are available and the app has not already created a UIImage.
        try await Task.detached(priority: .userInitiated) {
            try compressImageDataSync(data, options: options, debugLabel: nil)
        }.value
    }
    
    public static func compressImages(
        _ images: [UIImage],
        options: ImageCompressionOptions,
        maxConcurrentTasks: Int = 2
    ) async -> [Result<ImageCompressionResult, Error>] {
        guard !images.isEmpty else { return [] }
        
        let concurrency = min(3, max(1, maxConcurrentTasks))
        var results = Array<Result<ImageCompressionResult, Error>?>(repeating: nil, count: images.count)
        
        await withTaskGroup(of: (Int, Result<ImageCompressionResult, Error>).self) { group in
            var nextIndex = 0
            
            // Spawn initial batch
            while nextIndex < min(concurrency, images.count) {
                let index = nextIndex
                let image = images[index]
                group.addTask {
                    return (index, compressImageResult(image, options: options, debugLabel: "index=\(index)"))
                }
                nextIndex += 1
            }
            
            // Bounded queue: spawn next task as soon as one completes
            while let (index, result) = await group.next() {
                results[index] = result
                if nextIndex < images.count {
                    let index = nextIndex
                    let image = images[index]
                    group.addTask {
                        return (index, compressImageResult(image, options: options, debugLabel: "index=\(index)"))
                    }
                    nextIndex += 1
                }
            }
        }
        
        return results.map { result in
            result ?? .failure(ImageCompressionError.encodingFailed)
        }
    }
    
    public static func compressImageData(
        _ imageData: [Data],
        options: ImageCompressionOptions,
        maxConcurrentTasks: Int = 2
    ) async -> [Result<ImageCompressionResult, Error>] {
        guard !imageData.isEmpty else { return [] }
        
        let concurrency = min(3, max(1, maxConcurrentTasks))
        var results = Array<Result<ImageCompressionResult, Error>?>(repeating: nil, count: imageData.count)
        
        await withTaskGroup(of: (Int, Result<ImageCompressionResult, Error>).self) { group in
            var nextIndex = 0
            
            while nextIndex < min(concurrency, imageData.count) {
                let index = nextIndex
                let data = imageData[index]
                group.addTask {
                    return (index, compressImageDataResult(data, options: options, debugLabel: "index=\(index)"))
                }
                nextIndex += 1
            }
            
            while let (index, result) = await group.next() {
                results[index] = result
                if nextIndex < imageData.count {
                    let index = nextIndex
                    let data = imageData[index]
                    group.addTask {
                        return (index, compressImageDataResult(data, options: options, debugLabel: "index=\(index)"))
                    }
                    nextIndex += 1
                }
            }
        }
        
        return results.map { result in
            result ?? .failure(ImageCompressionError.encodingFailed)
        }
    }
    
    private static func compressImageResult(
        _ image: UIImage,
        options: ImageCompressionOptions,
        debugLabel: String?
    ) -> Result<ImageCompressionResult, Error> {
        do {
            return .success(try compressImageSync(image, options: options, debugLabel: debugLabel))
        } catch {
            return .failure(error)
        }
    }
    
    private static func compressImageDataResult(
        _ data: Data,
        options: ImageCompressionOptions,
        debugLabel: String?
    ) -> Result<ImageCompressionResult, Error> {
        do {
            return .success(try compressImageDataSync(data, options: options, debugLabel: debugLabel))
        } catch {
            return .failure(error)
        }
    }
    
    private static func compressImageDataSync(
        _ data: Data,
        options: ImageCompressionOptions,
        debugLabel: String?
    ) throws -> ImageCompressionResult {
        let start = CFAbsoluteTimeGetCurrent()
        var timing = ImageCompressionTiming()
        
        guard let source = CGImageSourceCreateWithData(data as CFData, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary) else {
            throw ImageCompressionError.renderFailed
        }
        
        let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        
        let main = try compressImageSourceJPEG(
            source,
            maxBytes: options.mainMaxBytes,
            policy: options.mainPolicy,
            renderTimingKeyPath: \.mainRenderMs,
            encodeTimingKeyPath: \.mainEncodeMs,
            timing: &timing
        )
        let alphaDetected = (sourceProperties?[kCGImagePropertyHasAlpha] as? Bool) ?? main.rendered.image.hasAlphaChannel
        
        let thumbnail: JPEGOutput?
        if let thumbnailMaxBytes = options.thumbnailMaxBytes {
            let thumbnailResult = try compressJPEG(
                main.rendered.image,
                maxBytes: thumbnailMaxBytes,
                policy: options.thumbnailPolicy,
                renderTimingKeyPath: \.thumbRenderMs,
                encodeTimingKeyPath: \.thumbEncodeMs,
                timing: &timing
            )
            thumbnail = thumbnailResult.output
        } else {
            thumbnail = nil
        }
        
        let previewThumbnail: JPEGOutput?
        if let previewThumbnailOptions = options.previewThumbnailOptions {
            let previewResult = try compressJPEG(
                main.rendered.image,
                maxBytes: previewThumbnailOptions.maxBytes,
                policy: previewThumbnailOptions.policy,
                renderTimingKeyPath: \.previewThumbnailRenderMs,
                encodeTimingKeyPath: \.previewThumbnailEncodeMs,
                timing: &timing
            )
            previewThumbnail = previewResult.output
        } else {
            previewThumbnail = nil
        }
        
        let totalMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        timing.totalMs = totalMs
        #if DEBUG
        let label = debugLabel.map { "\($0) " } ?? ""
        print("[CompressionKit][ImageTiming] \(label)mainRender=\(timing.mainRenderMs)ms mainEncode=\(timing.mainEncodeMs)ms thumbRender=\(timing.thumbRenderMs)ms thumbEncode=\(timing.thumbEncodeMs)ms previewThumbnailRender=\(timing.previewThumbnailRenderMs)ms previewThumbnailEncode=\(timing.previewThumbnailEncodeMs)ms total=\(timing.totalMs)ms source=data")
        #endif
        
        return ImageCompressionResult(
            mainData: main.output.data,
            thumbnailData: thumbnail?.data,
            previewThumbnailData: previewThumbnail?.data,
            mainPixelSize: main.output.pixelSize,
            thumbnailPixelSize: thumbnail?.pixelSize,
            previewThumbnailPixelSize: previewThumbnail?.pixelSize,
            mainQuality: main.output.quality,
            thumbnailQuality: thumbnail?.quality,
            previewThumbnailQuality: previewThumbnail?.quality,
            mainAttempts: main.output.attempts,
            thumbnailAttempts: thumbnail?.attempts ?? 0,
            previewThumbnailAttempts: previewThumbnail?.attempts ?? 0,
            format: options.format,
            mimeType: options.mimeType,
            fileExtension: options.fileExtension,
            alphaDetected: alphaDetected,
            flattened: alphaDetected,
            compressionDurationMs: totalMs
        )
    }
    
    private static func compressImageSync(
        _ image: UIImage,
        options: ImageCompressionOptions,
        debugLabel: String?
    ) throws -> ImageCompressionResult {
        let start = CFAbsoluteTimeGetCurrent()
        let alphaDetected = image.hasAlphaChannel
        var timing = ImageCompressionTiming()
        
        let main = try compressJPEG(
            image,
            maxBytes: options.mainMaxBytes,
            policy: options.mainPolicy,
            renderTimingKeyPath: \.mainRenderMs,
            encodeTimingKeyPath: \.mainEncodeMs,
            timing: &timing
        )
        
        let thumbnail: JPEGOutput?
        if let thumbnailMaxBytes = options.thumbnailMaxBytes {
            // Thumbnail is derived from the main render so we avoid a second full-resolution image draw.
            let thumbnailSource = main.rendered.image
            let thumbnailResult = try compressJPEG(
                thumbnailSource,
                maxBytes: thumbnailMaxBytes,
                policy: options.thumbnailPolicy,
                renderTimingKeyPath: \.thumbRenderMs,
                encodeTimingKeyPath: \.thumbEncodeMs,
                timing: &timing
            )
            thumbnail = thumbnailResult.output
        } else {
            thumbnail = nil
        }
        
        let previewThumbnail: JPEGOutput?
        if let previewThumbnailOptions = options.previewThumbnailOptions {
            let previewResult = try compressJPEG(
                main.rendered.image,
                maxBytes: previewThumbnailOptions.maxBytes,
                policy: previewThumbnailOptions.policy,
                renderTimingKeyPath: \.previewThumbnailRenderMs,
                encodeTimingKeyPath: \.previewThumbnailEncodeMs,
                timing: &timing
            )
            previewThumbnail = previewResult.output
        } else {
            previewThumbnail = nil
        }
        
        let totalMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        timing.totalMs = totalMs
        #if DEBUG
        let label = debugLabel.map { "\($0) " } ?? ""
        print("[CompressionKit][ImageTiming] \(label)mainRender=\(timing.mainRenderMs)ms mainEncode=\(timing.mainEncodeMs)ms thumbRender=\(timing.thumbRenderMs)ms thumbEncode=\(timing.thumbEncodeMs)ms previewThumbnailRender=\(timing.previewThumbnailRenderMs)ms previewThumbnailEncode=\(timing.previewThumbnailEncodeMs)ms total=\(timing.totalMs)ms source=uiimage")
        #endif
        
        return ImageCompressionResult(
            mainData: main.output.data,
            thumbnailData: thumbnail?.data,
            previewThumbnailData: previewThumbnail?.data,
            mainPixelSize: main.output.pixelSize,
            thumbnailPixelSize: thumbnail?.pixelSize,
            previewThumbnailPixelSize: previewThumbnail?.pixelSize,
            mainQuality: main.output.quality,
            thumbnailQuality: thumbnail?.quality,
            previewThumbnailQuality: previewThumbnail?.quality,
            mainAttempts: main.output.attempts,
            thumbnailAttempts: thumbnail?.attempts ?? 0,
            previewThumbnailAttempts: previewThumbnail?.attempts ?? 0,
            format: options.format,
            mimeType: options.mimeType,
            fileExtension: options.fileExtension,
            alphaDetected: alphaDetected,
            flattened: alphaDetected,
            compressionDurationMs: totalMs
        )
    }
    
    private static func compressJPEG(
        _ image: UIImage,
        maxBytes: Int,
        policy: [ImageCompressionAttempt],
        renderTimingKeyPath: WritableKeyPath<ImageCompressionTiming, Int>,
        encodeTimingKeyPath: WritableKeyPath<ImageCompressionTiming, Int>,
        timing: inout ImageCompressionTiming
    ) throws -> (output: JPEGOutput, rendered: RenderedImage) {
        guard !policy.isEmpty else { throw ImageCompressionError.emptyPolicy }
        
        var rendered: RenderedImage?
        var renderedLongEdge: CGFloat = 0
        var fallback: (output: JPEGOutput, rendered: RenderedImage)?
        
        // Gradual quality fallback protects faces, text, and gradients from aggressive compression artifacts.
        for (index, attempt) in policy.enumerated() {
            if rendered == nil || renderedLongEdge != attempt.maxLongEdge {
                #if DEBUG
                let renderStart = CFAbsoluteTimeGetCurrent()
                #endif
                rendered = try image.flattenedResizedImage(maxLongEdge: attempt.maxLongEdge)
                renderedLongEdge = attempt.maxLongEdge
                #if DEBUG
                timing[keyPath: renderTimingKeyPath] += Int((CFAbsoluteTimeGetCurrent() - renderStart) * 1000)
                #endif
            }
            
            guard let renderedImage = rendered else {
                throw ImageCompressionError.renderFailed
            }
            
            #if DEBUG
            let encodeStart = CFAbsoluteTimeGetCurrent()
            #endif
            let dataOpt = autoreleasepool {
                renderedImage.image.jpegData(compressionQuality: attempt.quality)
            }
            #if DEBUG
            timing[keyPath: encodeTimingKeyPath] += Int((CFAbsoluteTimeGetCurrent() - encodeStart) * 1000)
            #endif
            
            guard let data = dataOpt else {
                throw ImageCompressionError.encodingFailed
            }
            
            let output = JPEGOutput(
                data: data,
                pixelSize: renderedImage.pixelSize,
                quality: attempt.quality,
                attempts: index + 1
            )
            fallback = (output, renderedImage)
            
            if data.count <= maxBytes {
                return (output, renderedImage)
            }
        }
        
        guard let fallback else { throw ImageCompressionError.encodingFailed }
        throw ImageCompressionError.sizeLimitExceeded(maxBytes: maxBytes, actualBytes: fallback.output.data.count)
    }
    
    private static func compressImageSourceJPEG(
        _ source: CGImageSource,
        maxBytes: Int,
        policy: [ImageCompressionAttempt],
        renderTimingKeyPath: WritableKeyPath<ImageCompressionTiming, Int>,
        encodeTimingKeyPath: WritableKeyPath<ImageCompressionTiming, Int>,
        timing: inout ImageCompressionTiming
    ) throws -> (output: JPEGOutput, rendered: RenderedImage) {
        guard !policy.isEmpty else { throw ImageCompressionError.emptyPolicy }
        
        var rendered: RenderedImage?
        var renderedLongEdge: CGFloat = 0
        var fallback: (output: JPEGOutput, rendered: RenderedImage)?
        
        for (index, attempt) in policy.enumerated() {
            if rendered == nil || renderedLongEdge != attempt.maxLongEdge {
                #if DEBUG
                let renderStart = CFAbsoluteTimeGetCurrent()
                #endif
                rendered = try source.renderedThumbnail(maxLongEdge: attempt.maxLongEdge)
                renderedLongEdge = attempt.maxLongEdge
                #if DEBUG
                timing[keyPath: renderTimingKeyPath] += Int((CFAbsoluteTimeGetCurrent() - renderStart) * 1000)
                #endif
            }
            
            guard let renderedImage = rendered else {
                throw ImageCompressionError.renderFailed
            }
            
            #if DEBUG
            let encodeStart = CFAbsoluteTimeGetCurrent()
            #endif
            let dataOpt = autoreleasepool {
                renderedImage.image.jpegData(compressionQuality: attempt.quality)
            }
            #if DEBUG
            timing[keyPath: encodeTimingKeyPath] += Int((CFAbsoluteTimeGetCurrent() - encodeStart) * 1000)
            #endif
            
            guard let data = dataOpt else {
                throw ImageCompressionError.encodingFailed
            }
            
            let output = JPEGOutput(
                data: data,
                pixelSize: renderedImage.pixelSize,
                quality: attempt.quality,
                attempts: index + 1
            )
            fallback = (output, renderedImage)
            
            if data.count <= maxBytes {
                return (output, renderedImage)
            }
        }
        
        guard let fallback else { throw ImageCompressionError.encodingFailed }
        throw ImageCompressionError.sizeLimitExceeded(maxBytes: maxBytes, actualBytes: fallback.output.data.count)
    }
}

private struct ImageCompressionTiming {
    var mainRenderMs = 0
    var mainEncodeMs = 0
    var thumbRenderMs = 0
    var thumbEncodeMs = 0
    var previewThumbnailRenderMs = 0
    var previewThumbnailEncodeMs = 0
    var totalMs = 0
}

private struct JPEGOutput {
    let data: Data
    let pixelSize: CGSize
    let quality: CGFloat
    let attempts: Int
}

private struct RenderedImage {
    let image: UIImage
    let pixelSize: CGSize
}

private extension UIImage {
    func flattenedResizedImage(maxLongEdge: CGFloat) throws -> RenderedImage {
        try flattenedResizedImage(targetSize: resizedPixelSize(maxLongEdge: maxLongEdge))
    }
    
    func flattenedResizedImage(targetSize: CGSize) throws -> RenderedImage {
        try autoreleasepool {
            guard targetSize.width > 0, targetSize.height > 0 else {
                throw ImageCompressionError.renderFailed
            }
            
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            
            let originalPixelSize = pixelSize
            let alphaDetected = hasAlphaChannel
            let useDirectCGImageDraw = !alphaDetected && imageOrientation == .up && cgImage != nil
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            // mainRender is the compression hot path. Keep this render simple, opaque, scale=1,
            // and avoid extra image conversions because large PNGs spend most time here.
            let outputImage = renderer.image { context in
                let rect = CGRect(origin: .zero, size: targetSize)
                let cgContext = context.cgContext
                
                if useDirectCGImageDraw, let cgImage {
                    cgContext.interpolationQuality = .high
                    cgContext.saveGState()
                    cgContext.translateBy(x: 0, y: targetSize.height)
                    cgContext.scaleBy(x: 1, y: -1)
                    cgContext.draw(cgImage, in: rect)
                    cgContext.restoreGState()
                } else {
                    cgContext.setFillColor(UIColor.white.cgColor)
                    cgContext.fill(rect)
                    draw(in: rect)
                }
            }
            
            #if DEBUG
            let renderPath = useDirectCGImageDraw ? "cgImage" : "uiImageDraw"
            print("[CompressionKit][RenderDebug] source=uiimage path=\(renderPath) original=\(Int(originalPixelSize.width))x\(Int(originalPixelSize.height)) target=\(Int(targetSize.width))x\(Int(targetSize.height)) alpha=\(alphaDetected) opaque=true scale=1")
            #endif
            
            return RenderedImage(image: outputImage, pixelSize: targetSize)
        }
    }
    
    func resizedPixelSize(maxLongEdge: CGFloat) -> CGSize {
        let pixelWidth = max(pixelSize.width, 1)
        let pixelHeight = max(pixelSize.height, 1)
        let longEdge = max(pixelWidth, pixelHeight)
        
        guard longEdge > maxLongEdge else {
            return CGSize(width: round(pixelWidth), height: round(pixelHeight))
        }
        
        // 2048px keeps feed quality high on modern devices without uploading full camera-size images.
        let ratio = maxLongEdge / longEdge
        return CGSize(width: round(pixelWidth * ratio), height: round(pixelHeight * ratio))
    }
    
    var pixelSize: CGSize {
        if let cgImage {
            switch imageOrientation {
            case .left, .leftMirrored, .right, .rightMirrored:
                return CGSize(width: cgImage.height, height: cgImage.width)
            default:
                return CGSize(width: cgImage.width, height: cgImage.height)
            }
        }
        
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
    
    var hasAlphaChannel: Bool {
        guard let alphaInfo = cgImage?.alphaInfo else { return false }
        
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }
}

private extension CGImageSource {
    func renderedThumbnail(maxLongEdge: CGFloat) throws -> RenderedImage {
        try autoreleasepool {
            let options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCache: false,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(maxLongEdge.rounded())
            ] as CFDictionary
            
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(self, 0, options) else {
                throw ImageCompressionError.renderFailed
            }
            
            let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            
            let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
            let image = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: pixelSize))
                UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: pixelSize))
            }
            
            return RenderedImage(image: image, pixelSize: pixelSize)
        }
    }
}

#endif
