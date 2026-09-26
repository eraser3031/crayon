import SwiftUI

extension Shape {
    /// Fills the shape with overlapping diagonal crayon marks and small paper gaps.
    /// The texture is fixed in point space, so resizing does not stretch its grain.
    @MainActor
    public func crayonFill(_ color: Color = .primary,
                           textureStrength: Double = 0.8,
                           grainSize: CGFloat = 1,
                           seed: UInt32 = 0,
                           style: FillStyle = FillStyle()) -> some View {
        CrayonFill(shape: self, color: color,
                   strength: textureStrength.isFinite ? min(max(textureStrength, 0), 1) : 0.8,
                   grainSize: grainSize.isFinite ? min(max(grainSize, 0.25), 4) : 1,
                   seed: seed, style: style)
    }
}

private struct CrayonFill<S: Shape>: View {
    let shape: S
    let color: Color
    let strength: Double
    let grainSize: CGFloat
    let seed: UInt32
    let style: FillStyle
    @Environment(\.self) private var environment

    var body: some View {
        GeometryReader { geometry in
            let path = shape.path(in: CGRect(origin: .zero, size: geometry.size))
            let resolved = color.resolve(in: environment)
            let key = CrayonFillKey(path: path, color: resolved, strength: strength,
                                    grainSize: grainSize, seed: seed,
                                    evenOdd: style.isEOFilled, antialiased: style.isAntialiased)
            CachedBrushCanvas(key: key) {
                Canvas { context, size in
                    guard size.width > 0, size.height > 0 else { return }
                    context.clip(to: path, style: style)
                    if strength > 0 {
                        context.clipToLayer { mask in
                            CrayonMarks.draw(in: &mask, size: size, strength: strength,
                                             grainSize: grainSize, seed: seed)
                        }
                    }
                    context.fill(Path(CGRect(origin: .zero, size: size)),
                                 with: .color(Color(resolved)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CrayonFillKey: Equatable {
    let path: Path
    let color: Color.Resolved
    let strength: Double
    let grainSize: CGFloat
    let seed: UInt32
    let evenOdd: Bool
    let antialiased: Bool
}

/// Draws coverage into a mask; the requested color is applied only once afterward.
/// This preserves the alpha of translucent colors even where marks overlap.
private enum CrayonMarks {
    static func draw(in context: inout GraphicsContext, size: CGSize,
                     strength: Double, grainSize: CGFloat, seed: UInt32) {
        let bounds = CGRect(origin: .zero, size: size)
        context.opacity = 1 - 0.50 * strength
        context.fill(Path(bounds), with: .color(.white))

        let stepX = 13 * grainSize
        let stepY = 4 * grainSize
        let columns = Int(ceil(size.width / stepX)) + 3
        let rows = Int(ceil(size.height / stepY)) + 7
        for row in -4..<rows {
            for column in -1..<columns {
                let index = UInt64(bitPattern: Int64(row)) &* 0x9E3779B97F4A7C15
                    &+ UInt64(bitPattern: Int64(column)) &* 0xBF58476D1CE4E5B9
                    &+ UInt64(seed)
                let x = (CGFloat(column) * 13 + CGFloat(random(index, 0)) * 8) * grainSize
                let y = (CGFloat(row) * 4 + CGFloat(random(index, 1)) * 5) * grainSize
                let length = (11 + CGFloat(random(index, 2)) * 24) * grainSize
                let rise = length * (0.34 + CGFloat(random(index, 3)) * 0.16)
                let width = (0.5 + CGFloat(random(index, 4)) * 1.6) * grainSize
                var mark = context
                mark.opacity = strength * (0.16 + random(index, 5) * 0.48)
                var line = Path()
                line.move(to: CGPoint(x: x, y: y))
                line.addLine(to: CGPoint(x: x + length, y: y - rise))
                mark.stroke(line, with: .color(.white),
                            style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
        }
    }

    private static func random(_ index: UInt64, _ stream: UInt64) -> Double {
        var bits = index &+ stream &* 0x94D049BB133111EB
        bits = (bits ^ (bits >> 30)) &* 0xBF58476D1CE4E5B9
        bits = (bits ^ (bits >> 27)) &* 0x94D049BB133111EB
        return Double((bits ^ (bits >> 31)) >> 11) / Double(1 << 53)
    }
}
