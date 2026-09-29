import SwiftUI

/// Generates the expensive crayon coverage off the main actor. Color is applied
/// when drawing, so a tint change does not require another coverage pass.
@MainActor
struct AsyncCrayonCanvas: View {
    let path: Path
    let color: Color
    let strength: Double
    let grainSize: CGFloat
    let seed: UInt32
    let edgeRoughness: Double
    let directionality: Double
    let style: FillStyle
    let outset: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var snapshot: Snapshot?
    @State private var currentRequest: Request?
    @State private var renderTask: Task<Void, Never>?

    private struct Request: Equatable {
        let path: Path
        let size: CGSize
        let displayScale: CGFloat
        let strength: Double
        let grainSize: CGFloat
        let seed: UInt32
        let edgeRoughness: Double
        let directionality: Double
        let isEOFilled: Bool
        let isAntialiased: Bool
        let outset: CGFloat
    }

    private struct Snapshot {
        let request: Request
        let image: CGImage
    }

    var body: some View {
        GeometryReader { geometry in
            let request = Request(path: path, size: geometry.size, displayScale: displayScale,
                                  strength: strength, grainSize: grainSize, seed: seed, edgeRoughness: edgeRoughness, directionality: directionality,
                                  isEOFilled: style.isEOFilled, isAntialiased: style.isAntialiased,
                                  outset: outset)
            Canvas { context, size in
                let bounds = CGRect(origin: .zero, size: size)
                if let snapshot {
                    var coverage = context.resolve(Image(decorative: snapshot.image, scale: 1))
                    coverage.shading = .color(color)
                    context.draw(coverage, in: bounds)
                } else {
                    // First appearance stays cheap and usable until coverage is ready.
                    context.clip(to: path, style: style)
                    context.fill(Path(bounds), with: .color(color))
                }
            }
            .onChange(of: request, initial: true) { _, updated in regenerate(updated) }
            .onDisappear {
                renderTask?.cancel()
                renderTask = nil
                currentRequest = nil
                snapshot = nil
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func regenerate(_ request: Request) {
        currentRequest = request
        renderTask?.cancel()
        guard snapshot?.request != request else {
            renderTask = nil
            return
        }
        renderTask = Task.detached(priority: .userInitiated) { [request, style] in
            let image = CrayonMarks.image(path: request.path, size: request.size,
                                          displayScale: request.displayScale,
                                          strength: request.strength, grainSize: request.grainSize,
                                          seed: request.seed, edgeRoughness: request.edgeRoughness, directionality: request.directionality, style: style, outset: request.outset,
                                          shouldCancel: { Task.isCancelled })
            await MainActor.run {
                guard currentRequest == request, !Task.isCancelled else { return }
                snapshot = image.map { Snapshot(request: request, image: $0) }
                renderTask = nil
            }
        }
    }
}
