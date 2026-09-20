import XCTest
import CoreGraphics
@testable import Crayon

final class BrushTests: XCTestCase {
    func testLineSpacingAndDisconnectedContours() {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 10, y: 0))
        path.move(to: CGPoint(x: 100, y: 0))
        path.addLine(to: CGPoint(x: 104, y: 0))
        XCTAssertEqual(PathSampler.points(on: path, spacing: 2).map(\.x), [0, 2, 4, 6, 8, 10, 100, 102, 104])
    }

    func testDabAndClosedContour() {
        let dab = CGMutablePath()
        dab.move(to: .zero)
        dab.addLine(to: .zero)
        XCTAssertEqual(PathSampler.points(on: dab, spacing: 2), [.zero])
        let rect = CGMutablePath()
        rect.addRect(CGRect(x: 0, y: 0, width: 10, height: 10))
        let points = PathSampler.points(on: rect, spacing: 2)
        XCTAssertEqual(points.count, 20)
        XCTAssertNotEqual(points.first, points.last)
    }

    func testCurveSpacing() {
        let curve = CGMutablePath()
        curve.move(to: .zero)
        curve.addCurve(to: CGPoint(x: 100, y: 0), control1: CGPoint(x: 0, y: 100), control2: CGPoint(x: 100, y: 100))
        let points = PathSampler.points(on: curve, spacing: 2)
        XCTAssertTrue((91..<110).contains(points.count))
        for (a, b) in zip(points, points.dropFirst()).dropLast() {
            XCTAssertEqual(hypot(b.x - a.x, b.y - a.y), 2, accuracy: 0.1)
        }
    }

    func testThinStrokeTransition() {
        XCTAssertEqual(BrushStrokeMetrics.width(-1), 0)
        XCTAssertEqual(BrushStrokeMetrics.width(.nan), 64)
        for scale: CGFloat in [1, 2, 3] {
            XCTAssertEqual(BrushStrokeMetrics.thinWeight(width: 1, displayScale: scale), 1)
            XCTAssertEqual(BrushStrokeMetrics.thinWeight(width: 12, displayScale: scale), 0)
            var previous = 1.0
            for width in stride(from: CGFloat(0.5), through: 16, by: 0.1) {
                let weight = BrushStrokeMetrics.thinWeight(width: width, displayScale: scale)
                XCTAssertTrue(weight <= previous && weight >= 0)
                previous = weight
            }
        }
        XCTAssertEqual(BrushStrokeMetrics.accumulatedFlow(0), 0)
        XCTAssertGreaterThan(BrushStrokeMetrics.accumulatedFlow(0.3), 0.9)
    }

    func testMonolineAndRepeatableNoise() {
        let tip = BrushTip.monoline
        let data = tip.shape.dataProvider!.data! as Data
        XCTAssertEqual(data[64 * tip.shape.bytesPerRow + 64 * 4 + 3], 255)
        XCTAssertEqual(data[3], 0)
        let grain = tip.grain.dataProvider!.data! as Data
        XCTAssertEqual(grain[3], 255)
        let offsets = (0..<1024).map { BrushStampNoise.offset(index: $0) }
        XCTAssertEqual(offsets, (0..<1024).map { BrushStampNoise.offset(index: $0) })
        XCTAssertTrue(offsets.allSatisfy { abs($0.x) <= 1 && abs($0.y) <= 1 })
        XCTAssertTrue(zip(offsets, offsets.dropFirst()).allSatisfy { $0 != $1 })
        XCTAssertTrue(offsets.allSatisfy { $0.x != $0.y })
        for period in 1...64 {
            XCTAssertFalse((0..<64).allSatisfy { offsets[$0] == offsets[$0 + period] })
        }
    }
}
