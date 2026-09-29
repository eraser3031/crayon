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
                        fillStyle: .crayon(seed: 7), renderingMode: .synchronous)
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
        let alphas = (10..<70).flatMap { y in (10..<70).map { x in pixels[(y * 80 + x) * 4 + 3] } }
        XCTAssertGreaterThan(alphas.max() ?? 0, alphas.min() ?? 255)
        XCTAssertGreaterThan(alphas.max() ?? 0, 230)
        XCTAssertLessThan(alphas.min() ?? 255, 100)
    }

    @MainActor
    func testCrayonBoundaryAndShapeOrientation() {
        let triangle = Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: 80, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 80))
            path.closeSubpath()
        }
        let renderer = ImageRenderer(content: triangle
            .brushFill(color: .red.opacity(0.5), textureStrength: 1,
                       fillStyle: .crayon(seed: 7), renderingMode: .synchronous)
            .frame(width: 80, height: 80).padding(10))
        guard let image = renderer.cgImage else { return XCTFail("Crayon did not render") }
        var pixels = [UInt8](repeating: 0, count: 100 * 100 * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 100, height: 100,
                                          bitsPerComponent: 8, bytesPerRow: 400,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 100, height: 100))
            return true
        }
        XCTAssertTrue(drawn)
        func alpha(_ x: Int, _ y: Int) -> UInt8 { pixels[(y * 100 + x) * 4 + 3] }
        XCTAssertGreaterThan(alpha(25, 25), 80, "The upper-left interior must keep its orientation")
        XCTAssertGreaterThan(alpha(60, 20), 80, "The top edge must remain at the top")
        XCTAssertEqual(alpha(40, 80), 0, "The silhouette must not flip vertically")
        XCTAssertEqual(alpha(75, 75), 0, "The opposite corner must remain empty")
        let outside = (20..<60).flatMap { x in (6..<10).map { y in alpha(x, y) } }
        XCTAssertGreaterThan(outside.max() ?? 0, 0, "Rough pigment must extend beyond the original edge")
        let alphas = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        XCTAssertLessThanOrEqual(alphas.max() ?? 255, 128, "Passes must preserve the tint's opacity")
    }

    @MainActor
    func testCrayonFillAndEdgeStrengthsAreIndependent() throws {
        func render(strength: Double, roughness: Double) throws -> [UInt8] {
            let renderer = ImageRenderer(content: Rectangle()
                .brushFill(color: .red, textureStrength: strength,
                           fillStyle: .crayon(seed: 7, edgeRoughness: roughness),
                           renderingMode: .synchronous)
                .frame(width: 60, height: 60).padding(10))
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.cgImage)
            var pixels = [UInt8](repeating: 0, count: 80 * 80 * 4)
            try pixels.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(CGContext(
                    data: buffer.baseAddress, width: 80, height: 80,
                    bitsPerComponent: 8, bytesPerRow: 320,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: 80, height: 80))
            }
            return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        }
        let solidClean = try render(strength: 0, roughness: 0)
        let solidRough = try render(strength: 0, roughness: 1)
        let texturedClean = try render(strength: 0.8, roughness: 0)
        let texturedRough = try render(strength: 0.8, roughness: 1)
        let interior = (20..<60).flatMap { y in (20..<60).map { y * 80 + $0 } }
        XCTAssertTrue(interior.allSatisfy { solidClean[$0] == 255 && solidRough[$0] == 255 })
        XCTAssertEqual(interior.map { texturedClean[$0] }, interior.map { texturedRough[$0] },
                       "Changing the edge must not change the interior paper pattern")
        XCTAssertTrue(interior.contains { texturedClean[$0] < 150 })
        let outside = (0..<80).flatMap { y in
            (0..<80).filter { x in x < 10 || x >= 70 || y < 10 || y >= 70 }
                .map { y * 80 + $0 }
        }
        XCTAssertTrue(outside.allSatisfy { solidClean[$0] == 0 && texturedClean[$0] == 0 })
        XCTAssertTrue(outside.contains { solidRough[$0] > 0 },
                      "Rough edges must render even with a fully solid interior")
        // At strength 0.8, coverage retains a 20% floor. Ignore sub-byte
        // antialiasing values that can round to zero after that attenuation.
        XCTAssertTrue(outside.filter { solidRough[$0] >= 3 }.allSatisfy { texturedRough[$0] > 0 },
                      "Changing fill strength must preserve the displaced boundary")
        XCTAssertTrue(outside.filter { solidRough[$0] == 0 }.allSatisfy { texturedRough[$0] == 0 },
                      "Fill strength must not move pigment beyond the existing boundary")
    }

}
