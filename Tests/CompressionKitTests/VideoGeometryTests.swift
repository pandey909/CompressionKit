import XCTest
import CoreGraphics
@testable import CompressionKit

final class VideoGeometryTests: XCTestCase {
    func testGeometryCalculations() {
        // Landscape input
        let naturalSize = CGSize(width: 3840, height: 2160)
        let transform = CGAffineTransform.identity
        
        let geometry = VideoGeometry(
            naturalSize: naturalSize,
            preferredTransform: transform,
            target: .r720p
        )
        
        XCTAssertEqual(geometry.displaySize, naturalSize)
        XCTAssertFalse(geometry.isPortrait)
        XCTAssertEqual(geometry.targetDisplaySize, CGSize(width: 1280, height: 720))
        
        // Portrait input with 90-degree track rotation transform
        let rotationTransform = CGAffineTransform(a: 0.0, b: 1.0, c: -1.0, d: 0.0, tx: 2160.0, ty: 0.0)
        let geometryPortrait = VideoGeometry(
            naturalSize: naturalSize,
            preferredTransform: rotationTransform,
            target: .r720p
        )
        
        XCTAssertEqual(geometryPortrait.displaySize, CGSize(width: 2160, height: 3840))
        XCTAssertTrue(geometryPortrait.isPortrait)
        XCTAssertEqual(geometryPortrait.targetDisplaySize, CGSize(width: 720, height: 1280))
    }
}
