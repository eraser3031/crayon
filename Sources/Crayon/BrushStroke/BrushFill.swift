import SwiftUI

extension Shape {
    /// Fills this shape with the prepared brush's grain (not a simulation of paint strokes).
    /// Strength 0 is solid; 1 preserves the grain's full transparent gaps.
    /// Grain scale is in points, independent of the shape's bounds.
    @MainActor
    public func brushFill(_ tip: BrushTip, color: Color = .primary,
                   textureStrength: Double = 0.8, grainScale: CGFloat = 240,
                   style: FillStyle = FillStyle()) -> some View {
        let strength = textureStrength.isFinite ? min(max(textureStrength, 0), 1) : 0.8
        let scale = grainScale.isFinite ? min(max(grainScale, 16), 2048) : 240
        return BrushFill(shape: self, tip: tip, color: color, strength: strength, scale: scale, style: style)
    }
}

private struct BrushFill<S: Shape>: View {
    let shape: S
    let tip: BrushTip
    let color: Color
    let strength: Double
    let scale: CGFloat
    let style: FillStyle
    @Environment(\.self) private var environment

    var body: some View {
        GeometryReader { geometry in
            let path = shape.path(in: CGRect(origin: .zero, size: geometry.size))
            let resolved = color.resolve(in: environment)
            let key = BrushRasterKey(path: path, shape: ObjectIdentifier(tip.shape),
                                     grain: ObjectIdentifier(tip.grain), color: resolved,
                                     parameters: [strength, Double(scale), style.isEOFilled ? 1 : 0,
                                                  style.isAntialiased ? 1 : 0])
            CachedBrushCanvas(key: key) { rasterContent(path: path, color: Color(resolved)) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func rasterContent(path: Path, color: Color) -> some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            guard size.width > 0, size.height > 0 else { return }
            context.clip(to: path, style: style)
            if strength > 0 {
                let grain = context.resolve(Image(decorative: tip.grain, scale: 1))
                context.clipToLayer { mask in
                    // Alpha = (1 - strength) + strength * grain. Add in a mask,
                    // then color once so translucent input colors retain their opacity.
                    mask.opacity = 1 - strength
                    mask.fill(Path(bounds), with: .color(.white))
                    mask.opacity = strength
                    mask.blendMode = .plusLighter
                    for y in stride(from: CGFloat.zero, to: size.height, by: scale) {
                        for x in stride(from: CGFloat.zero, to: size.width, by: scale) {
                            mask.draw(grain, in: CGRect(x: x, y: y, width: scale, height: scale))
                        }
                    }
                }
            }
            context.fill(Path(bounds), with: .color(color))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
