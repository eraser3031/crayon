import SwiftUI

/// One raster per mounted decoration. The caller's key must describe every drawing input.
/// This wraps brush-only content, never interactive views or the boiling shader itself.
@MainActor
struct CachedBrushCanvas<Key: Equatable, Content: View>: View {
    let key: Key
    @ViewBuilder let content: () -> Content
    @Environment(\.self) private var environment
    @State private var snapshot: Snapshot?
    @State private var currentRequest: Request?

    private struct Request: Equatable {
        let key: Key
        let size: CGSize
        let scale: CGFloat
    }
    private struct Snapshot {
        let request: Request
        let image: CGImage
    }

    var body: some View {
        GeometryReader { geometry in
            let request = Request(key: key, size: geometry.size, scale: environment.displayScale)
            ZStack(alignment: .topLeading) {
                if let snapshot {
                    Image(decorative: snapshot.image, scale: request.scale)
                        .resizable()
                        .frame(width: request.size.width, height: request.size.height)
                } else {
                    content()
                }
            }
            .onChange(of: request, initial: true) { _, updated in scheduleRebuild(updated) }
            .onDisappear {
                currentRequest = nil
                snapshot = nil
            }
        }
    }

    private func scheduleRebuild(_ request: Request) {
        currentRequest = request
        guard snapshot?.request != request else { return }
        Task { @MainActor in
            // Let the press animation commit first. Coalesce rapidly changing inputs,
            // while the last raster remains visible until its replacement is ready.
            if snapshot != nil {
                try? await Task.sleep(for: .milliseconds(120))
            } else {
                await Task.yield()
            }
            guard currentRequest == request, !Task.isCancelled else { return }
            rebuild(request)
        }
    }

    private func rebuild(_ request: Request) {
        guard snapshot?.request != request else { return }
        let width = ceil(request.size.width * request.scale)
        let height = ceil(request.size.height * request.scale)
        // Bound a decoration to 8 MiB of RGBA pixels. Large canvases use live rendering.
        guard width.isFinite, height.isFinite, width > 0, height > 0,
              width * height <= 2_097_152 else {
            snapshot = nil
            return
        }
        let renderer = ImageRenderer(content: content()
            .environment(\.self, environment)
            .frame(width: request.size.width, height: request.size.height))
        renderer.scale = request.scale
        renderer.proposedSize = ProposedViewSize(request.size)
        guard let image = renderer.cgImage else {
            snapshot = nil
            return
        }
        snapshot = Snapshot(request: request, image: image)
    }
}

/// Shared explicit invalidation inputs for fill and stroke rasterization.
struct BrushRasterKey: Equatable {
    let path: Path
    let shape: ObjectIdentifier
    let grain: ObjectIdentifier
    let color: Color.Resolved
    let parameters: [Double]
}
