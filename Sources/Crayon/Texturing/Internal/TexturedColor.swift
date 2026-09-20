import SwiftUI

struct TexturedColor: View {
    let color: Color
    let shape: TexturingShape
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let pattern: TexturingPattern
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let radius = radius.isFinite ? max(0, radius) : 0
        let x = x.isFinite ? x : 0
        let y = y.isFinite ? y : 0
        // Include one antialiasing pixel beyond the maximum displaced edge.
        let pixel = 1 / max(displayScale, 1)
        let outset = ceil(radius + max(abs(x), abs(y)) + pixel)

        if radius == 0 {
            shape.fill(color) // Preserve the selected shape without a shader pass.
        } else {
            Color.clear.overlay {
                GeometryReader { geometry in
                    color
                        .frame(width: geometry.size.width + 2 * outset,
                               height: geometry.size.height + 2 * outset)
                        .colorEffect(ShaderLibrary.bundle(.module).edgeTexture(
                            .float2(Float(geometry.size.width), Float(geometry.size.height)),
                            .float(Float(outset)),
                            .float2(Float(x), Float(y)),
                            .float(Float(radius)),
                            .float(Float(pixel)),
                            .float(shape.shaderKind),
                            .float(Float(shape.cornerRadius)),
                            .float(Float(pattern.grainSize)),
                            .float(Float(pattern.coarseSize)),
                            .float(Float(pattern.roughness)),
                            .float2(pattern.seedOffsetX, pattern.seedOffsetY)
                        ))
                        .offset(x: -outset, y: -outset)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
