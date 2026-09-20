import SwiftUI

extension View {
    /// Cycles three fixed spatial distortions for a hand-drawn line-boil effect.
    /// Apply directly to a stroke/canvas, before its background or labels.
    public func boiling(isEnabled: Bool = true, amount: CGFloat = 1.2,
                 framesPerSecond: Double = 6) -> some View {
        modifier(BoilingModifier(isEnabled: isEnabled, amount: amount,
                                 framesPerSecond: framesPerSecond))
    }
}

private struct BoilingModifier: ViewModifier {
    let isEnabled: Bool
    let amount: CGFloat
    let framesPerSecond: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    func body(content: Content) -> some View {
        let amplitude = amount.isFinite ? min(max(amount, 0), 8) : 1.2
        let fps = framesPerSecond.isFinite ? min(max(framesPerSecond, 1), 12) : 6
        let active = isEnabled && amplitude > 0 && !reduceMotion && scenePhase == .active && isVisible
        Group {
            if active {
                // No path resampling per tick: only the shader's frame argument changes.
                TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: 0), by: 1 / fps)) { timeline in
                    let frame = floor(timeline.date.timeIntervalSinceReferenceDate * fps)
                        .truncatingRemainder(dividingBy: 3)
                    let margin = ceil(amplitude) + 1
                    content
                        .padding(margin)
                        .distortionEffect(
                            ShaderLibrary.bundle(.module).lineBoil(.float(Float(amplitude)), .float(Float(frame))),
                            maxSampleOffset: CGSize(width: amplitude, height: amplitude)
                        )
                        .padding(-margin)
                }
            } else {
                content
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}
