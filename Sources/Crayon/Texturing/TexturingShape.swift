import SwiftUI

/// Analytic shapes supported by the texture shader.
/// Rounded corners use circular arcs (not SwiftUI's continuous corner style).
/// Also a Shape, so the exact same geometry can define a button's hit region.
public enum TexturingShape: Shape {
    case rectangle
    case roundedRectangle(cornerRadius: CGFloat)
    case capsule
    case circle

    public func path(in rect: CGRect) -> Path {
        switch self {
        case .rectangle:
            Rectangle().path(in: rect)
        case .roundedRectangle(let radius):
            RoundedRectangle(cornerRadius: Self.sanitized(radius), style: .circular).path(in: rect)
        case .capsule:
            Capsule(style: .circular).path(in: rect)
        case .circle:
            Circle().path(in: rect)
        }
    }

    var shaderKind: Float {
        switch self {
        case .rectangle, .roundedRectangle: 0
        case .capsule: 1
        case .circle: 2
        }
    }

    var cornerRadius: CGFloat {
        if case .roundedRectangle(let radius) = self { return Self.sanitized(radius) }
        return 0
    }

    private static func sanitized(_ value: CGFloat) -> CGFloat {
        value.isFinite ? max(0, value) : 0
    }
}

