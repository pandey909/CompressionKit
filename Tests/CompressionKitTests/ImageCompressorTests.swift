import XCTest

#if canImport(UIKit)
import UIKit
@testable import CompressionKit

final class ImageCompressorTests: XCTestCase {
    func testSingleImageCompressionReturnsFeedJPEG() async throws {
        let image = makeImage(size: CGSize(width: 1600, height: 1200), color: .systemBlue)
        let compressor = CompressionKit.ImageCompressor(options: .post)
        
        let result = try await compressor.compressImage(image)
        
        XCTAssertEqual(result.mimeType, "image/jpeg")
        XCTAssertEqual(result.fileExtension, "jpg")
        XCTAssertLessThanOrEqual(result.mainData.count, 2 * 1024 * 1024)
        XCTAssertLessThanOrEqual(result.thumbnailData?.count ?? Int.max, 350 * 1024)
        XCTAssertLessThanOrEqual(result.previewThumbnailData?.count ?? Int.max, 150 * 1024)
        XCTAssertLessThanOrEqual(max(result.mainPixelSize.width, result.mainPixelSize.height), 2048)
        XCTAssertLessThanOrEqual(max(result.thumbnailPixelSize?.width ?? 0, result.thumbnailPixelSize?.height ?? 0), 720)
        XCTAssertLessThanOrEqual(max(result.previewThumbnailPixelSize?.width ?? 0, result.previewThumbnailPixelSize?.height ?? 0), 360)
        
        let thumbnailCount = try XCTUnwrap(result.thumbnailData?.count)
        let previewThumbnailCount = try XCTUnwrap(result.previewThumbnailData?.count)
        XCTAssertLessThanOrEqual(previewThumbnailCount, thumbnailCount)
    }
    
    func testMultipleImageCompressionPreservesOrder() async {
        let compressor = CompressionKit.ImageCompressor(maxConcurrentTasks: 2)
        let images = [
            makeImage(size: CGSize(width: 900, height: 600), color: .red),
            makeImage(size: CGSize(width: 1200, height: 800), color: .green),
            makeImage(size: CGSize(width: 1500, height: 1000), color: .blue)
        ]
        
        let results = await compressor.compressImages(images)
        
        XCTAssertEqual(results.count, images.count)
        
        for (index, result) in results.enumerated() {
            guard case .success(let compressionResult) = result else {
                XCTFail("Expected success at index \(index)")
                continue
            }
            
            XCTAssertLessThanOrEqual(compressionResult.mainPixelSize.width, images[index].size.width)
            XCTAssertLessThanOrEqual(compressionResult.mainPixelSize.height, images[index].size.height)
        }
    }
    
    func testMultipleImageCompressionAcceptsSingleTaskLimit() async {
        let compressor = CompressionKit.ImageCompressor(maxConcurrentTasks: 1)
        let images = [
            makeImage(size: CGSize(width: 640, height: 480), color: .yellow),
            makeImage(size: CGSize(width: 800, height: 600), color: .purple)
        ]
        
        let results = await compressor.compressImages(images)
        
        XCTAssertEqual(results.count, images.count)
        XCTAssertTrue(results.allSatisfy { result in
            if case .success = result {
                return true
            }
            
            return false
        })
    }
    
    func testArrayAPIAcceptsOneImage() async throws {
        let compressor = CompressionKit.ImageCompressor()
        let image = makeImage(size: CGSize(width: 1024, height: 768), color: .orange)
        
        let results = await compressor.compressImages([image])
        
        XCTAssertEqual(results.count, 1)
        guard case .success(let result) = results[0] else {
            XCTFail("Expected one compressed image")
            return
        }
        
        XCTAssertEqual(result.mimeType, "image/jpeg")
    }
    
    func testPreviewThumbnailCanBeDisabled() async throws {
        let options = ImageCompressionOptions(
            mainMaxBytes: 2 * 1024 * 1024,
            thumbnailMaxBytes: 350 * 1024,
            mainPolicy: [ImageCompressionAttempt(maxLongEdge: 2048, quality: 0.85)],
            thumbnailPolicy: [ImageCompressionAttempt(maxLongEdge: 720, quality: 0.75)],
            format: "jpg",
            mimeType: "image/jpeg",
            fileExtension: "jpg"
        )
        let compressor = CompressionKit.ImageCompressor(options: options)
        let image = makeImage(size: CGSize(width: 1024, height: 768), color: .orange)
        
        let result = try await compressor.compressImage(image)
        
        XCTAssertNotNil(result.thumbnailData)
        XCTAssertNil(result.previewThumbnailData)
        XCTAssertNil(result.previewThumbnailPixelSize)
        XCTAssertNil(result.previewThumbnailQuality)
        XCTAssertEqual(result.previewThumbnailAttempts, 0)
    }
    
    func testConcurrencyClampingLimits() {
        let compressorDefault = CompressionKit.ImageCompressor()
        XCTAssertEqual(compressorDefault.maxConcurrentTasks, 2)
        
        let compressorHigh = CompressionKit.ImageCompressor(maxConcurrentTasks: 5)
        XCTAssertEqual(compressorHigh.maxConcurrentTasks, 3)
        
        let compressorLow = CompressionKit.ImageCompressor(maxConcurrentTasks: 0)
        XCTAssertEqual(compressorLow.maxConcurrentTasks, 1)
    }
    
    private func makeImage(size: CGSize, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
#endif
