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
        if CommandLine.arguments.contains("--reference-colors") {
            try save("crayon-reference-colors", to: output, content:
                VStack(alignment: .leading, spacing: 22) {
                    heading("크레용 질감 수정", detail: "실제 렌더링 · textureStrength: 1 · grainSize: 1 · 외곽 거칠기: 0.5")
                    HStack(spacing: 24) {
                        ForEach(0..<2) { index in
                            RoundedRectangle(cornerRadius: 36)
                                .brushFill(color: index == 0 ? Color(red: 0.15, green: 0.43, blue: 0.97) : Color(red: 1, green: 0.58, blue: 0.04),
                                           textureStrength: 1,
                                           fillStyle: .crayon(seed: 7, edgeRoughness: 0.5), renderingMode: .synchronous)
                                .frame(width: 340, height: 340)
                        }
                    }.padding(6)
                }.padding(24))
            return
        }
        if CommandLine.arguments.contains("--reference-texture") {
            try save("crayon-reference-texture", to: output, content:
                VStack(alignment: .leading, spacing: 20) {
                    heading("종이 결 위에 쌓이는 크레용", detail: "실제 렌더링 · textureStrength: 1 · grainSize: 1 · seed: 7")
                    Rectangle()
                        .brushFill(color: Color(red: 0.40, green: 0.70, blue: 0.70), textureStrength: 1,
                                   fillStyle: .crayon(seed: 7, edgeRoughness: 0), renderingMode: .synchronous)
                        .frame(width: 470, height: 650)
                }.padding(24))
            return
        }
        if CommandLine.arguments.contains("--compare-directionality") {
            for edge in [0.0, 0.8] {
                try save(edge == 0 ? "crayon-directionality-clean" : "crayon-directionality", to: output, content:
                    VStack(alignment: .leading, spacing: 20) {
                        heading("칠 강도 × 왕복 칠 방향성", detail: "외곽 거칠기: \(edge) · grainSize: 1 · seed: 7 · 실제 렌더링")
                        HStack(spacing: 24) {
                            ForEach([0.0, 0.5, 1.0], id: \.self) { direction in
                                Text("방향성 \(direction.formatted())")
                                    .font(.system(size: 16, weight: .semibold)).frame(width: 210)
                            }
                        }
                        ForEach([1.0, 2.0, 3.0, 4.0], id: \.self) { strength in
                            VStack(alignment: .leading, spacing: 10) {
                                Text("textureStrength: \(Int(strength))").font(.system(size: 15, weight: .medium))
                                HStack(spacing: 24) {
                                    ForEach([0.0, 0.5, 1.0], id: \.self) { direction in
                                        RoundedRectangle(cornerRadius: 20)
                                            .brushFill(color: Color(red: 0.40, green: 0.70, blue: 0.70), textureStrength: strength,
                                                       fillStyle: .crayon(seed: 7, edgeRoughness: edge, directionality: direction),
                                                       renderingMode: .synchronous)
                                            .frame(width: 194, height: 116).padding(8)
                                    }
                                }
                            }
                        }
                    }.padding(30))
            }
            return
        }
        if CommandLine.arguments.contains("--compare-coverage") {
            try save("crayon-lighter-coverage", to: output, content:
                VStack(alignment: .leading, spacing: 28) {
                    heading("부드러운 크레용 결 · 강도별 비교", detail: "외곽 거칠기 0.8 고정 · grainSize: 1 · seed: 7 · 실제 렌더링")
                    ForEach([1.0, 3.0], id: \.self) { start in
                        HStack(spacing: 36) {
                            ForEach([start, start + 1], id: \.self) { strength in
                                VStack(alignment: .leading, spacing: 18) {
                                    Text("textureStrength: \(Int(strength))")
                                        .font(.system(size: 17, weight: .semibold))
                                    RoundedRectangle(cornerRadius: 24)
                                        .brushFill(color: Color(red: 0.40, green: 0.70, blue: 0.70), textureStrength: strength,
                                                   fillStyle: .crayon(seed: 7, edgeRoughness: 0.8),
                                                   renderingMode: .synchronous)
                                        .frame(width: 280, height: 200).padding(10)
                                }
                            }
                        }
                    }
                }.padding(36))
            return
        }
        if CommandLine.arguments.contains("--compare-edges") {
            try save("crayon-independent-controls", to: output, content:
                VStack(alignment: .leading, spacing: 30) {
                    heading("내부 빈틈 × 외곽 거칠기", detail: "실제 Crayon 렌더링 · 동일한 색 / grainSize: 1 / seed: 7")
                    HStack(spacing: 36) {
                        Text("외곽 매끈 · 0").frame(width: 300)
                        Text("외곽 거침 · 1").frame(width: 300)
                    }.font(.system(size: 18, weight: .semibold))
                    ForEach([0.0, 1.0], id: \.self) { strength in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(strength == 0 ? "내부 꽉 채움 · textureStrength: 0" : "내부 빈틈 많음 · textureStrength: 1")
                                .font(.system(size: 16, weight: .medium))
                            HStack(spacing: 36) {
                                ForEach([0.0, 1.0], id: \.self) { roughness in
                                    RoundedRectangle(cornerRadius: 24)
                                        .brushFill(color: blue, textureStrength: strength,
                                                   fillStyle: .crayon(grainSize: 1, seed: 7, edgeRoughness: roughness),
                                                   renderingMode: .synchronous)
                                        .frame(width: 280, height: 180)
                                        .padding(10)
                                }
                            }
                        }
                    }
                }.padding(36))
            return
        }
        try save("crayon", to: output, content:
            VStack(alignment: .leading, spacing: 24) {
                heading("Crayon", detail: "Wax layers · paper grain · broken edges")
                RoundedRectangle(cornerRadius: 26)
                    .brushFill(color: yellow, textureStrength: 0.9,
                               fillStyle: .crayon(seed: 7), renderingMode: .synchronous)
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
                                       fillStyle: .crayon(seed: 7), renderingMode: .synchronous)
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
                                               fillStyle: .crayon(seed: 7), renderingMode: .synchronous)
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
