import XCTest
import SwiftUI
@testable import Crayon

final class CrayonCoverageTests: XCTestCase {
    func testLightPressureKeepsEvenCoverageAndPaperGrain() throws {
        let path = Path(CGRect(x: 8, y: 8, width: 96, height: 96))
        func alphas(_ strength: Double, seed: UInt32) throws -> [UInt8] {
            let image = try XCTUnwrap(CrayonMarks.image(
                path: path, size: CGSize(width: 112, height: 112), displayScale: 1,
                strength: strength, grainSize: 1, seed: seed, edgeRoughness: 0.8,
                style: FillStyle(), outset: 8))
            let data = try XCTUnwrap(image.dataProvider?.data)
            let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
            return (16..<96).flatMap { y in (16..<96).map { bytes[(y * 112 + $0) * 4 + 3] } }
        }
        for seed: UInt32 in [0, 7, 42] {
            let baseline = try alphas(1, seed: seed)
            var previous = baseline
            for strength in [2.0, 3.0, 4.0] {
                let current = try alphas(strength, seed: seed)
                XCTAssertTrue(zip(previous, current).allSatisfy { $1 <= $0 })
                XCTAssertLessThan(current.map(Int.init).reduce(0, +), previous.map(Int.init).reduce(0, +))
                previous = current
            }
            XCTAssertLessThan(previous.max() ?? 255, 150, "Even the densest marks should become lighter")
            // Every interior tile should retain a light layer of wax. This catches
            // erased bands and coarse holes even when whole-image averages look right.
            var texturedTiles = 0
            for y in stride(from: 0, to: 80, by: 8) {
                for x in stride(from: 0, to: 80, by: 8) {
                    let indices = (y..<y + 8).flatMap { row in (x..<x + 8).map { row * 80 + $0 } }
                    let original = indices.reduce(0.0) { $0 + Double(baseline[$1]) }
                    let light = indices.reduce(0.0) { $0 + Double(previous[$1]) }
                    XCTAssertGreaterThan(light / original, 0.2, "No erased strips or bare patches")
                    XCTAssertLessThan(light / original, 0.55, "Lightness must apply across the whole fill")
                    let values = indices.map { previous[$0] }
                    if Int(values.max()!) - Int(values.min()!) > 8 { texturedTiles += 1 }
                }
            }
            XCTAssertGreaterThan(texturedTiles, 80, "Most tiles should retain grain; dense wax patches may be smooth")
        }
    }
    func testDirectionalityAddsDirectionalContinuityWithoutMovingEdges() throws {
        func render(_ direction: Double, strength: Double = 1, edge: Double = 0) throws -> [Double] {
            let image = try XCTUnwrap(CrayonMarks.image(
                path: Path(CGRect(x: 8, y: 8, width: 112, height: 112)),
                size: CGSize(width: 128, height: 128), displayScale: 1,
                strength: strength, grainSize: 1, seed: 7, edgeRoughness: edge,
                directionality: direction, style: FillStyle(), outset: 8))
            let data = try XCTUnwrap(image.dataProvider?.data)
            let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
            return (0..<128 * 128).map { Double(bytes[$0 * 4 + 3]) }
        }
        let plain = try render(0)
        let directional = try render(1)
        let mixed = try render(0.5)
        func directionalContrast(_ pixels: [Double]) -> Double {
            // Average out sub-point paper tooth to measure the hand marks,
            // rather than demanding that individual grain specks align.
            func localMean(_ x: Int, _ y: Int) -> Double {
                var sum = 0.0
                for dy in -1...1 {
                    for dx in -1...1 { sum += pixels[(y + dy) * 128 + x + dx] }
                }
                return sum / 9
            }
            var along = 0.0, across = 0.0
            for y in 16..<108 {
                for x in 16..<108 {
                    let value = localMean(x, y)
                    along += abs(value - localMean(x + 3, y - 2))
                    across += abs(value - localMean(x + 2, y + 3))
                }
            }
            return across / along
        }
        XCTAssertGreaterThan(directionalContrast(directional), directionalContrast(plain) * 1.2,
                             "Rubs should have stronger continuity along the drawing direction")
        for index in plain.indices {
            XCTAssertEqual(mixed[index], (plain[index] + directional[index]) / 2, accuracy: 1)
        }
        let originalMean = plain.reduce(0, +) / Double(plain.count)
        let directionalMean = directional.reduce(0, +) / Double(directional.count)
        XCTAssertEqual(originalMean, directionalMean, accuracy: originalMean * 0.15,
                       "Directionality should not act as another fill-strength control")
        let roughSolid = try render(0, strength: 0, edge: 1)
        XCTAssertEqual(roughSolid, try render(1, strength: 0, edge: 1),
                       "Directionality must not move the rough silhouette")
        let rough = try render(1, edge: 1)
        for y in 16..<112 {
            for x in 16..<112 {
                XCTAssertEqual(rough[y * 128 + x], directional[y * 128 + x])
            }
        }
    }

    func testDirectionalitySanitizesInvalidInputs() {
        XCTAssertEqual(BrushFillStyle.crayon(directionality: .nan).sanitized, .crayon(directionality: 0))
        XCTAssertEqual(BrushFillStyle.crayon(directionality: -1).sanitized, .crayon(directionality: 0))
        XCTAssertEqual(BrushFillStyle.crayon(directionality: 2).sanitized, .crayon(directionality: 1))
    }

}
