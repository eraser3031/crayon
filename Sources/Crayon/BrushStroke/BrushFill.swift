import SwiftUI

/// The texture used inside a shape. `grain` uses the prepared brush tip;
/// `crayon` creates wax marks and paper gaps without an image resource.
public enum BrushFillStyle: Equatable, Sendable {
    case grain
    case crayon(grainSize: CGFloat = 1, seed: UInt32 = 0)

    var sanitized: Self {
        switch self {
        case .grain:
            return .grain
        case let .crayon(grainSize, seed):
            return .crayon(grainSize: grainSize.isFinite ? min(max(grainSize, 0.5), 4) : 1,
                           seed: seed)
        }
    }

    var cacheParameters: [Double] {
        switch self {
        case .grain: [0, 0, 0]
        case let .crayon(grainSize, seed): [1, Double(grainSize), Double(seed)]
        }
    }
}

extension Shape {
    /// Fills this shape with either the prepared tip's grain or a crayon texture.
    /// Strength 0 is solid; 1 shows the selected texture's full paper gaps.
    /// `style` is SwiftUI's fill rule; `fillStyle` selects the visible texture.
    @MainActor
    public func brushFill(_ tip: BrushTip = .monoline, color: Color = .primary,
                   textureStrength: Double = 0.8, grainScale: CGFloat = 240,
                   fillStyle: BrushFillStyle = .grain,
                   style: FillStyle = FillStyle()) -> some View {
        let strength = textureStrength.isFinite ? min(max(textureStrength, 0), 1) : 0.8
        let scale = grainScale.isFinite ? min(max(grainScale, 16), 2048) : 240
        return BrushFill(shape: self, tip: tip, color: color, strength: strength,
                         scale: scale, fillStyle: fillStyle.sanitized, style: style)
    }
}

private struct BrushFill<S: Shape>: View {
    let shape: S
    let tip: BrushTip
    let color: Color
    let strength: Double
    let scale: CGFloat
    let fillStyle: BrushFillStyle
    let style: FillStyle
    @Environment(\.self) private var environment

    var body: some View {
        GeometryReader { geometry in
            let path = shape.path(in: CGRect(origin: .zero, size: geometry.size))
            let resolved = color.resolve(in: environment)
            let key = BrushRasterKey(path: path, shape: ObjectIdentifier(tip.shape),
                                     grain: ObjectIdentifier(tip.grain), color: resolved,
                                     parameters: [strength, Double(scale), style.isEOFilled ? 1 : 0,
                                                  style.isAntialiased ? 1 : 0] + fillStyle.cacheParameters)
            CachedBrushCanvas(key: key) { rasterContent(path: path, color: Color(resolved)) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func rasterContent(path: Path, color: Color) -> some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            guard size.width.isFinite, size.height.isFinite,
                  size.width > 0, size.height > 0 else { return }
            context.clip(to: path, style: style)
            if strength > 0 {
                switch fillStyle {
                case .grain:
                    let grain = context.resolve(Image(decorative: tip.grain, scale: 1))
                    context.clipToLayer { mask in
                        // Apply color once so overlapping alpha retains the input opacity.
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
                case let .crayon(grainSize, seed):
                    context.clipToLayer { mask in
                        CrayonMarks.draw(in: &mask, path: path, size: size, strength: strength,
                                         grainSize: grainSize, seed: seed)
                    }
                }
            }
            context.fill(Path(bounds), with: .color(color))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
