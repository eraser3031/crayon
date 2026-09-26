import Crayon
import ImageIO
import SwiftUI

/// Run from the repository root; pass an optional output directory.
@main
struct PreviewGenerator {
    static let yellow = Color(red: 1, green: 0.84, blue: 0.25)
    static let blue = Color(red: 0.28, green: 0.65, blue: 0.96)
    static let pink = Color(red: 1, green: 0.48, blue: 0.49)

    @MainActor
    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Documentation/Images",
                         isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try save("crayon", to: output, content:
            VStack(alignment: .leading, spacing: 24) {
                heading("Crayon", detail: "Wax layers · paper grain · broken edges")
                RoundedRectangle(cornerRadius: 26)
                    .brushFill(color: yellow, textureStrength: 0.9,
                               fillStyle: .crayon(seed: 7))
                    .frame(width: 680, height: 270)
            }.padding(36))
        try save("drawing-styles", to: output, content:
            VStack(alignment: .leading, spacing: 28) {
                heading("One fill API, two textures", detail: "brushFill(fillStyle:) + brushStroke")
                HStack(alignment: .top, spacing: 32) {
                    VStack(spacing: 20) {
                        RoundedRectangle(cornerRadius: 22)
                            .brushFill(.monoline, color: blue, textureStrength: 0.9)
                            .frame(width: 200, height: 140)
                        label(".grain", detail: "Prepared brush grain")
                    }
                    VStack(spacing: 20) {
                        RoundedRectangle(cornerRadius: 22)
                            .brushFill(color: blue, textureStrength: 0.9,
                                       fillStyle: .crayon(seed: 7))
                            .frame(width: 200, height: 140)
                        label(".crayon", detail: "Procedural wax coverage")
                    }
                    VStack(spacing: 20) {
                        Path { path in
                            path.move(to: CGPoint(x: 12, y: 112))
                            path.addCurve(to: CGPoint(x: 188, y: 28),
                                          control1: CGPoint(x: 68, y: -32),
                                          control2: CGPoint(x: 132, y: 170))
                        }.brushStroke(.monoline, color: pink, width: 16)
                            .frame(width: 200, height: 140)
                        label("brushStroke", detail: "Brush stamps along a path")
                    }
                }
            }.padding(36))
        try save("crayon-strength", to: output, content:
            VStack(alignment: .leading, spacing: 28) {
                heading("Crayon texture strength", detail: "textureStrength · grainSize: 1 · seed: 7")
                HStack(spacing: 32) {
                    ForEach([0.0, 0.5, 1.0], id: \.self) { strength in
                        VStack(spacing: 20) {
                            Circle().brushFill(color: pink, textureStrength: strength,
                                               fillStyle: .crayon(seed: 7))
                                .frame(width: 180, height: 180)
                            label(String(format: "%.1f", strength), detail: strength == 0 ? "Solid" : "Paper shows through")
                        }
                        .frame(width: 200)
                    }
                }
            }.padding(36))
    }

    static func heading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 28, weight: .bold, design: .rounded))
            Text(detail).font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }

    static func label(_ title: String, detail: String) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.system(size: 15, weight: .semibold, design: .monospaced))
            Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    @MainActor
    static func save<V: View>(_ name: String, to directory: URL, content: V) throws {
        let renderer = ImageRenderer(content: content.background(.white)
            .environment(\.colorScheme, .light).environment(\.displayScale, 2))
        renderer.scale = 2
        let url = directory.appendingPathComponent(name + ".png")
        guard let image = renderer.cgImage,
              let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        print(url.path)
    }
}
