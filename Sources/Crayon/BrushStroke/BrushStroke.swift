import SwiftUI

extension Path {
    /// Stamps a prepared brush along this path in local point coordinates.
    /// Width is the nominal visible stroke thickness in points, excluding tip margins.
    /// Subpixel/small strokes smoothly use continuous coverage to remain legible.
    @MainActor
    public func brushStroke(_ tip: BrushTip, color: Color = .primary,
                     width: CGFloat = 64, spacing: CGFloat? = nil,
                     flow: Double? = nil, grainScale: CGFloat = 240) -> some View {
        BrushStroke(path: self, tip: tip, color: color, width: width,
                    spacing: spacing ?? tip.defaultSpacing, flow: flow ?? tip.defaultFlow, grainScale: grainScale)
    }
}

extension Shape {
    /// Uses the shape's actual path, including continuous corners and custom Shapes.
    /// Like stroke(), the brush is centered on the boundary; layout size is unchanged.
    /// Ancestor clipping can still trim the outer half of the stroke.
    @MainActor
    public func brushStroke(_ tip: BrushTip, color: Color = .primary,
                     width: CGFloat = 64, spacing: CGFloat? = nil,
                     flow: Double? = nil, grainScale: CGFloat = 240) -> some View {
        let width = BrushStrokeMetrics.width(width)
        // A rotated square tip can extend beyond half its width.
        let outset = ceil(width / sqrt(2)) + 1
        return GeometryReader { geometry in
            let bounds = CGRect(origin: .zero, size: geometry.size)
            let translated = path(in: bounds).applying(CGAffineTransform(translationX: outset, y: outset))
            BrushStroke(path: translated, tip: tip, color: color, width: width,
                        spacing: spacing ?? tip.defaultSpacing, flow: flow ?? tip.defaultFlow, grainScale: grainScale)
                .frame(width: geometry.size.width + 2 * outset,
                       height: geometry.size.height + 2 * outset)
                .offset(x: -outset, y: -outset)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct BrushStroke: View {
    @Environment(\.displayScale) private var displayScale
    @Environment(\.self) private var environment
    let path: Path
    let tip: BrushTip
    let color: Color
    let width: CGFloat
    let flow: Double
    let grainScale: CGFloat
    let spacing: CGFloat

    init(path: Path, tip: BrushTip, color: Color, width: CGFloat,
         spacing: CGFloat, flow: Double, grainScale: CGFloat) {
        self.path = path
        self.tip = tip
        self.color = color
        self.width = BrushStrokeMetrics.width(width)
        self.flow = flow.isFinite ? min(max(flow, 0), 1) : 0.3
        self.grainScale = grainScale.isFinite ? min(max(grainScale, 16), 2048) : 240
        self.spacing = spacing.isFinite ? min(max(spacing, 0.02), 1) : 0.08
    }

    var body: some View {
        let resolved = color.resolve(in: environment)
        let key = BrushRasterKey(path: path, shape: ObjectIdentifier(tip.shape),
                                 grain: ObjectIdentifier(tip.grain), color: resolved,
                                 parameters: [Double(width), flow, Double(grainScale), Double(spacing),
                                              tip.rotation, Double(tip.positionJitter), Double(displayScale)])
        return CachedBrushCanvas(key: key) { rasterContent(color: Color(resolved)) }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func rasterContent(color: Color) -> some View {
        let thinWeight = BrushStrokeMetrics.thinWeight(width: width, displayScale: displayScale)
        // Continuous coverage only needs the location of a degenerate path (a dab).
        // Keep sampling outside the Canvas callback, including during shader updates.
        let points: [CGPoint]
        if width <= 0 || flow <= 0 {
            points = []
        } else if thinWeight == 1 {
            let bounds = path.cgPath.boundingBoxOfPath
            points = !bounds.isNull && bounds.size == .zero ? [bounds.origin] : []
        } else {
            points = PathSampler.points(on: path.cgPath, spacing: width * spacing)
        }
        return Canvas { context, size in
            guard width > 0, flow > 0 else { return }
            let shape = context.resolve(Image(decorative: tip.shape, scale: 1))
            var grain = context.resolve(Image(decorative: tip.grain, scale: 1))
            grain.shading = .color(color)
            context.clipToLayer { mask in
                if thinWeight > 0 {
                    var continuous = mask
                    continuous.opacity = thinWeight * BrushStrokeMetrics.accumulatedFlow(flow)
                    continuous.stroke(path, with: .color(.white),
                                      style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                    // A zero-length segment is a dab; stroke() doesn't reliably draw it.
                    if points.count == 1, let point = points.first {
                        continuous.fill(Path(ellipseIn: CGRect(x: point.x - width / 2, y: point.y - width / 2,
                                                               width: width, height: width)), with: .color(.white))
                    }
                }
                mask.opacity = flow * (1 - thinWeight)
                let longestSide = CGFloat(max(tip.shape.width, tip.shape.height))
                let stampWidth = width * (1 - 2 * tip.positionJitter) * CGFloat(tip.shape.width) / longestSide
                let stampHeight = width * (1 - 2 * tip.positionJitter) * CGFloat(tip.shape.height) / longestSide
                if thinWeight < 1 {
                    for (index, point) in points.enumerated() {
                        var stamp = mask
                        // Fixed per-stamp offsets; never generate new randomness on redraw.
                        let jitter = width * tip.positionJitter * (1 - thinWeight)
                        let offset = jitter > 0 ? BrushStampNoise.offset(index: index) : .zero
                        stamp.translateBy(x: point.x + offset.x * jitter,
                                          y: point.y + offset.y * jitter)
                        stamp.rotate(by: .radians(tip.rotation))
                        stamp.draw(shape, in: CGRect(x: -stampWidth / 2, y: -stampHeight / 2, width: stampWidth, height: stampHeight))
                    }
                }
            }
            // A coverage floor prevents a 1pt line from disappearing into grain holes.
            // Fade this out at larger sizes so broad strokes retain the full texture.
            if thinWeight > 0 {
                var base = context
                base.opacity = thinWeight * 0.8
                base.fill(Path(CGRect(origin: .zero, size: size)), with: .color(color))
            }
            // Grain is anchored to the canvas so overlapping stamps don't erase its gaps.
            for y in stride(from: CGFloat.zero, to: size.height, by: grainScale) {
                for x in stride(from: CGFloat.zero, to: size.width, by: grainScale) {
                    context.draw(grain, in: CGRect(x: x, y: y, width: grainScale, height: grainScale))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
