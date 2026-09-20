import SwiftUI

extension Color {
    /// Textures an analytic shape without changing its layout size.
    /// X/Y shift the textured boundary in points; radius is the edge band's half-width.
    /// Grain stays fixed in point space. Ancestor clipping can trim the outer particles.
    /// This targets solid-color shapes, not arbitrary view/alpha outlines.
    public func texturing(in shape: TexturingShape = .rectangle,
                   x: CGFloat = 0.5, y: CGFloat = 0.5, radius: CGFloat = 4,
                   pattern: TexturingPattern = .default) -> some View {
        TexturedColor(color: self, shape: shape, x: x, y: y, radius: radius, pattern: pattern)
    }
}

