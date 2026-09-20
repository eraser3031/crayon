import Foundation

/// Spatial noise settings. Equal settings produce the same stationary pattern.
public struct TexturingPattern: Equatable, Sendable {
    public static let `default` = TexturingPattern()

    /// Fine noise scale in points (0.1...64), independent of the view size.
    public let grainSize: CGFloat
    /// Coarse noise scale in points (0.1...64).
    public let coarseSize: CGFloat
    /// Coarse noise weight (0...1); the remaining weight is fine noise.
    public let roughness: CGFloat
    /// Pattern variation; zero preserves the original pattern.
    public let seed: UInt32

    public init(grainSize: CGFloat = 0.32, coarseSize: CGFloat = 2.2,
         roughness: CGFloat = 0.28, seed: UInt32 = 0) {
        self.grainSize = Self.clamp(grainSize, to: 0.1...64, fallback: 0.32)
        self.coarseSize = Self.clamp(coarseSize, to: 0.1...64, fallback: 2.2)
        self.roughness = Self.clamp(roughness, to: 0...1, fallback: 0.28)
        self.seed = seed
    }

    // Split the integer before converting to float to avoid losing seed bits.
    // Bounded offsets also keep the hash's input precision useful.
    var seedOffsetX: Float { Float(seed & 0xffff) / 256 }
    var seedOffsetY: Float { Float(seed >> 16) / 256 }

    private static func clamp(_ value: CGFloat, to range: ClosedRange<CGFloat>, fallback: CGFloat) -> CGFloat {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
    }
}
