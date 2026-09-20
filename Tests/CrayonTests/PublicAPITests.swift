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
}
