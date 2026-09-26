import XCTest
import SwiftUI
import Crayon

final class PublicAPITests: XCTestCase {
    @MainActor
    func testPublicDrawingComposition() {
        let tip = BrushTip.monoline
        let pattern = TexturingPattern(grainSize: 0.6, coarseSize: 3, roughness: 0.4, seed: 42)
        let shape = TexturingShape.roundedRectangle(cornerRadius: 12)
        // Ordinary import verifies every demo API is available outside the module.
        _ = shape.brushStroke(tip, color: .blue, width: 2).boiling()
        _ = shape.brushFill(tip, color: .red)
        _ = shape.brushFill(color: .yellow, textureStrength: 0.9,
                            fillStyle: .crayon(grainSize: 1.2, seed: 42))
        _ = Path(CGRect(x: 0, y: 0, width: 40, height: 40)).brushStroke(tip)
        _ = Color.blue.texturing(in: shape, pattern: pattern)
        XCTAssertFalse(shape.path(in: CGRect(x: 0, y: 0, width: 40, height: 40)).isEmpty)
        XCTAssertEqual(tip.defaultFlow, 1)
    }

    func testPatternSanitizesInputs() {
        let pattern = TexturingPattern(grainSize: .nan, coarseSize: .infinity, roughness: -1, seed: .max)
        XCTAssertEqual(pattern.grainSize, TexturingPattern.default.grainSize)
        XCTAssertEqual(pattern.coarseSize, TexturingPattern.default.coarseSize)
        XCTAssertEqual(pattern.roughness, 0)
        XCTAssertEqual(pattern.seed, UInt32.max)
        XCTAssertEqual(TexturingPattern(grainSize: -1, coarseSize: 100, roughness: 2).grainSize, 0.1)
        XCTAssertEqual(TexturingPattern(coarseSize: 100).coarseSize, 64)
        XCTAssertEqual(TexturingPattern(roughness: 2).roughness, 1)
    }

    func testInvalidBrushImageThrows() {
        let missing = URL(fileURLWithPath: "/nonexistent-crayon-brush.png")
        XCTAssertThrowsError(try BrushTip(shapeURL: missing, grainURL: missing)) { error in
            guard case BrushTip.LoadError.invalidImage = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    @MainActor
    func testCrayonBrushFillLeavesPaperGaps() {
        let renderer = ImageRenderer(content: Rectangle()
            .brushFill(color: .yellow, textureStrength: 1,
                        fillStyle: .crayon(seed: 7))
            .frame(width: 80, height: 80))
        renderer.scale = 1
        guard let image = renderer.cgImage else { return XCTFail("Crayon fill did not render") }
        var pixels = [UInt8](repeating: 0, count: 80 * 80 * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 80, height: 80,
                                          bitsPerComponent: 8, bytesPerRow: 80 * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 80, height: 80))
            return true
        }
        XCTAssertTrue(drawn)
        let alphas = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        XCTAssertGreaterThan(alphas.max() ?? 0, alphas.min() ?? 255)
        XCTAssertGreaterThan(alphas.min() ?? 0, 0)
    }
}
