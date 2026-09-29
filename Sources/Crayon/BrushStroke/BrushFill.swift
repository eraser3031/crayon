import SwiftUI

/// The texture used inside a shape. `grain` uses the prepared brush tip;
/// `crayon` creates wax marks and paper gaps without an image resource.
public enum BrushFillStyle: Equatable, Sendable {
    case grain
    /// Edge roughness controls boundary displacement independently of texture strength.
    /// Directionality (0...1) reveals overlapping diagonal back-and-forth rubs; 0 keeps soft grain.
    case crayon(grainSize: CGFloat = 1, seed: UInt32 = 0, edgeRoughness: Double = 0.8, directionality: Double = 0)

    var sanitized: Self {
        switch self {
        case .grain:
            return .grain
        case let .crayon(grainSize, seed, edgeRoughness, directionality):
            return .crayon(grainSize: grainSize.isFinite ? min(max(grainSize, 0.5), 4) : 1,
                           seed: seed, edgeRoughness: edgeRoughness.isFinite ? min(max(edgeRoughness, 0), 1) : 0.8,
                           directionality: directionality.isFinite ? min(max(directionality, 0), 1) : 0)
        }
    }

    var cacheParameters: [Double] {
        switch self {
        case .grain: [0, 0, 0]
        case let .crayon(grainSize, seed, edgeRoughness, directionality): [1, Double(grainSize), Double(seed), edgeRoughness, directionality]
        }
    }
}

/// Controls when a crayon fill generates its coverage image.
/// Use synchronous rendering for one-shot `ImageRenderer` exports.
public enum BrushFillRenderingMode: Sendable {
    case asynchronous
    case synchronous
}

extension Shape {
    /// Fills this shape with either the prepared tip's grain or a crayon texture.
    /// Strength 0 is solid; 1 shows the selected texture's full paper gaps.
    /// Crayon supports up to 4 for lighter wax deposits across the fill; grain caps at 1.
    /// Crayon coverage is generated off the main actor by default. Use synchronous
    /// rendering when a one-shot ImageRenderer must capture the finished texture.
    /// `style` is SwiftUI's fill rule; `fillStyle` selects the visible texture.
    @MainActor
    public func brushFill(_ tip: BrushTip = .monoline, color: Color = .primary,
                   textureStrength: Double = 0.8, grainScale: CGFloat = 240,
                   fillStyle: BrushFillStyle = .grain,
                   renderingMode: BrushFillRenderingMode = .asynchronous,
                   style: FillStyle = FillStyle()) -> some View {
        let maximumStrength: Double = if case .crayon = fillStyle { 4 } else { 1 }
        let strength = textureStrength.isFinite ? min(max(textureStrength, 0), maximumStrength) : 0.8
        let scale = grainScale.isFinite ? min(max(grainScale, 16), 2048) : 240
        return BrushFill(shape: self, tip: tip, color: color, strength: strength,
                         scale: scale, fillStyle: fillStyle.sanitized,
                         renderingMode: renderingMode, style: style)
    }
}

private struct BrushFill<S: Shape>: View {
    let shape: S
    let tip: BrushTip
    let color: Color
    let strength: Double
    let scale: CGFloat
    let fillStyle: BrushFillStyle
    let renderingMode: BrushFillRenderingMode
    let style: FillStyle
    @Environment(\.self) private var environment

    var body: some View {
        GeometryReader { geometry in
            let outset: CGFloat = {
                if case let .crayon(grainSize, _, edgeRoughness, _) = fillStyle, edgeRoughness > 0 {
                    return ceil(5 * grainSize * edgeRoughness) + 1
                }
                return 0
            }()
            let path = shape.path(in: CGRect(origin: .zero, size: geometry.size))
                .applying(CGAffineTransform(translationX: outset, y: outset))
            let resolved = color.resolve(in: environment)
            let key = BrushRasterKey(path: path, shape: ObjectIdentifier(tip.shape),
                                     grain: ObjectIdentifier(tip.grain), color: resolved,
                                     parameters: [strength, Double(scale), style.isEOFilled ? 1 : 0,
                                                  style.isAntialiased ? 1 : 0] + fillStyle.cacheParameters)
            Group {
                if case let .crayon(grainSize, seed, edgeRoughness, directionality) = fillStyle,
                   (strength > 0 || edgeRoughness > 0), renderingMode == .asynchronous {
                    AsyncCrayonCanvas(path: path, color: Color(resolved), strength: strength,
                                      grainSize: grainSize, seed: seed, edgeRoughness: edgeRoughness, directionality: directionality, style: style, outset: outset)
                } else {
                    CachedBrushCanvas(key: key) {
                        rasterContent(path: path, color: Color(resolved), outset: outset)
                    }
                }
            }
            .frame(width: geometry.size.width + 2 * outset,
                   height: geometry.size.height + 2 * outset)
            .offset(x: -outset, y: -outset)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func rasterContent(path: Path, color: Color, outset: CGFloat) -> some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            guard size.width.isFinite, size.height.isFinite,
                  size.width > 0, size.height > 0 else { return }
            if case let .crayon(grainSize, seed, edgeRoughness, directionality) = fillStyle, strength > 0 || edgeRoughness > 0 {
                if let image = CrayonMarks.image(path: path, size: size,
                                                displayScale: environment.displayScale,
                                                strength: strength, grainSize: grainSize,
                                                seed: seed, edgeRoughness: edgeRoughness, directionality: directionality, style: style, outset: outset) {
                    var coverage = context.resolve(Image(decorative: image, scale: 1))
                    coverage.shading = .color(color)
                    context.draw(coverage, in: bounds)
                }
                return
            }
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
                case .crayon: break
                }
            }
            context.fill(Path(bounds), with: .color(color))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
