import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Crayon

final class BrushImageTests: XCTestCase {
    func testImageLoadingCropsShapeAndRetainsGrainSize() throws {
        // Original fixture generated in the test; no demo assets or turtle checkout required.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("mask.png")
        let context = try XCTUnwrap(CGContext(data: nil, width: 16, height: 16,
            bitsPerComponent: 8, bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 4, y: 4, width: 8, height: 8))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL,
            UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let tip = try BrushTip(shapeURL: url, grainURL: url)
        XCTAssertEqual(tip.shape.width, 8)
        XCTAssertEqual(tip.shape.height, 8)
        XCTAssertEqual(tip.grain.width, 16)
        XCTAssertEqual(tip.grain.height, 16)
        let grain = try XCTUnwrap(tip.grain.dataProvider?.data) as Data
        XCTAssertEqual(grain[3], 0)
        XCTAssertEqual(grain[8 * tip.grain.bytesPerRow + 8 * 4 + 3], 255)
        XCTAssertEqual(tip.defaultSpacing, 0.08)
        XCTAssertEqual(tip.defaultFlow, 0.3)
    }
}
