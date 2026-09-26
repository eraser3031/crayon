import SwiftUI

/// Coverage mask for a soft, irregular wax fill. The caller applies color once.
enum CrayonMarks {
    static func draw(in context: inout GraphicsContext, path: Path, size: CGSize,
                     strength: Double, grainSize: CGFloat, seed: UInt32) {
        let bounds = CGRect(origin: .zero, size: size)
        context.opacity = 1 - 0.26 * strength
        context.fill(Path(bounds), with: .color(.white))

        // A few broad, broken passes soften the base without creating a regular hatch.
        let columns = Int(ceil(size.width / (24 * grainSize))) + 3
        let rows = Int(ceil(size.height / (13 * grainSize))) + 5
        let markDensity = min(1, 4_000 / (Double(columns) * Double(rows)))
        for row in -3..<rows {
            for column in -1..<columns {
                let index = hash(row, column, seed)
                guard random(index, 8) < markDensity else { continue }
                let x = (CGFloat(column) * 24 + CGFloat(random(index, 0)) * 23) * grainSize
                let y = (CGFloat(row) * 13 + CGFloat(random(index, 1)) * 12) * grainSize
                let length = (15 + CGFloat(random(index, 2)) * 50) * grainSize
                var mark = context
                mark.opacity = strength * (0.08 + random(index, 3) * 0.24)
                stroke(in: &mark, from: CGPoint(x: x, y: y), length: length,
                       slope: 0.25 + CGFloat(random(index, 4)) * 0.4,
                       width: (2 + CGFloat(random(index, 5)) * 5) * grainSize)
            }
        }

        // Thin scratches and small flecks expose paper at uneven intervals.
        let scratchColumns = Int(ceil(size.width / (17 * grainSize))) + 3
        let scratchRows = Int(ceil(size.height / (9 * grainSize))) + 5
        let scratchDensity = min(1, 8_000 / (Double(scratchColumns) * Double(scratchRows)))
        for row in -3..<scratchRows {
            for column in -1..<scratchColumns {
                let index = hash(row, column, seed &+ 0xA511E9B3)
                guard random(index, 8) < scratchDensity else { continue }
                let x = (CGFloat(column) * 17 + CGFloat(random(index, 0)) * 17) * grainSize
                let y = (CGFloat(row) * 9 + CGFloat(random(index, 1)) * 9) * grainSize
                var scratch = context
                scratch.blendMode = .destinationOut
                scratch.opacity = strength * (0.12 + random(index, 2) * 0.55)
                stroke(in: &scratch, from: CGPoint(x: x, y: y),
                       length: (3 + CGFloat(random(index, 3)) * 19) * grainSize,
                       slope: 0.20 + CGFloat(random(index, 4)) * 0.55,
                       width: (0.25 + CGFloat(random(index, 5)) * 0.9) * grainSize)
                if random(index, 6) > 0.96 {
                    let diameter = (0.8 + CGFloat(random(index, 7)) * 2) * grainSize
                    scratch.fill(Path(ellipseIn: CGRect(x: x, y: y,
                                                        width: diameter, height: diameter)),
                                 with: .color(.white))
                }
            }
        }

        let speckleColumns = Int(ceil(size.width / (5 * grainSize))) + 1
        let speckleRows = Int(ceil(size.height / (5 * grainSize))) + 1
        let speckleDensity = min(0.22, 10_000 / (Double(speckleColumns) * Double(speckleRows)))
        for row in 0..<speckleRows {
            for column in 0..<speckleColumns {
                let index = hash(row, column, seed &+ 0xC2B2AE35)
                guard random(index, 0) < speckleDensity else { continue }
                let x = (CGFloat(column) * 5 + CGFloat(random(index, 1)) * 5) * grainSize
                let y = (CGFloat(row) * 5 + CGFloat(random(index, 2)) * 5) * grainSize
                let diameter = (0.2 + CGFloat(random(index, 3)) * 0.8) * grainSize
                var fleck = context
                fleck.blendMode = .destinationOut
                fleck.opacity = strength * (0.08 + random(index, 4) * 0.28)
                fleck.fill(Path(ellipseIn: CGRect(x: x, y: y,
                                                 width: diameter, height: diameter)),
                           with: .color(.white))
            }
        }

        let edgePoints = PathSampler.points(on: path.cgPath, spacing: max(1, 2.5 * grainSize))
        for (index, point) in edgePoints.enumerated() {
            let bits = UInt64(index) &+ UInt64(seed) &* 0x9E3779B97F4A7C15
            guard random(bits, 0) > 0.25 else { continue }
            let diameter = (0.7 + CGFloat(random(bits, 1)) * 2.2) * grainSize
            var edge = context
            edge.blendMode = .destinationOut
            edge.opacity = strength * (0.16 + random(bits, 2) * 0.55)
            edge.fill(Path(ellipseIn: CGRect(x: point.x - diameter / 2,
                                            y: point.y - diameter / 2,
                                            width: diameter, height: diameter)),
                      with: .color(.white))
        }
    }

    private static func stroke(in context: inout GraphicsContext, from start: CGPoint,
                               length: CGFloat, slope: CGFloat, width: CGFloat) {
        var line = Path()
        line.move(to: start)
        line.addLine(to: CGPoint(x: start.x + length, y: start.y - length * slope))
        context.stroke(line, with: .color(.white),
                       style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private static func hash(_ row: Int, _ column: Int, _ seed: UInt32) -> UInt64 {
        UInt64(bitPattern: Int64(row)) &* 0x9E3779B97F4A7C15
            &+ UInt64(bitPattern: Int64(column)) &* 0xBF58476D1CE4E5B9
            &+ UInt64(seed)
    }

    private static func random(_ index: UInt64, _ stream: UInt64) -> Double {
        var bits = index &+ stream &* 0x94D049BB133111EB
        bits = (bits ^ (bits >> 30)) &* 0xBF58476D1CE4E5B9
        bits = (bits ^ (bits >> 27)) &* 0x94D049BB133111EB
        return Double((bits ^ (bits >> 31)) >> 11) / Double(1 << 53)
    }
}
