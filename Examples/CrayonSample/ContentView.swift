import Crayon
import SwiftUI

struct ContentView: View {
    @State private var selectedColor = 0
    @State private var strength = 0.9
    @State private var grainSize = 1.0
    @State private var animateStroke = false

    private let colors: [(name: String, color: Color)] = [
        ("노랑", Color(red: 1, green: 0.82, blue: 0.23)),
        ("파랑", Color(red: 0.28, green: 0.65, blue: 0.96)),
        ("분홍", Color(red: 1, green: 0.48, blue: 0.49))
    ]

    private var color: Color { colors[selectedColor].color }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    controls

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                        SampleCard(title: "크레파스 칠", subtitle: "crayonFill · 종이 틈과 사선 자국") {
                            RoundedRectangle(cornerRadius: 28)
                                .crayonFill(color, textureStrength: strength,
                                            grainSize: grainSize, seed: 7)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 28)
                                        .brushStroke(.monoline, color: .indigo, width: 3)
                                }
                                .frame(width: 180, height: 125)
                        }

                        SampleCard(title: "브러시 채우기", subtitle: "brushFill · 기본 monoline 팁") {
                            Circle()
                                .brushFill(.monoline, color: color, textureStrength: strength)
                                .overlay {
                                    Circle().brushStroke(.monoline, color: .indigo, width: 4)
                                }
                                .frame(width: 130, height: 130)
                        }

                        SampleCard(title: "브러시 선", subtitle: "brushStroke · 경로를 따라 찍는 팁") {
                            Path { path in
                                path.move(to: CGPoint(x: 20, y: 110))
                                path.addCurve(to: CGPoint(x: 180, y: 35),
                                              control1: CGPoint(x: 80, y: -15),
                                              control2: CGPoint(x: 125, y: 165))
                            }
                            .brushStroke(.monoline, color: color, width: 15)
                            .boiling(amount: animateStroke ? 1 : 0)
                            .frame(width: 200, height: 140)
                        }

                        SampleCard(title: "가장자리 질감", subtitle: "texturing · 색과 경계의 노이즈") {
                            color.texturing(in: .roundedRectangle(cornerRadius: 26),
                                            radius: 7,
                                            pattern: TexturingPattern(seed: 7))
                                .frame(width: 180, height: 125)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Crayon Sample")
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("질감 살펴보기")
                .font(.title2.bold())
            Text("색과 강도를 바꾸면 네 가지 그리기 효과를 바로 비교할 수 있습니다.")
                .foregroundStyle(.secondary)

            Picker("색상", selection: $selectedColor) {
                ForEach(colors.indices, id: \.self) { index in
                    Text(colors[index].name).tag(index)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent("질감 강도", value: strength.formatted(.percent.precision(.fractionLength(0))))
            Slider(value: $strength, in: 0...1)
                .accessibilityLabel("질감 강도")

            LabeledContent("크레파스 자국 크기", value: grainSize.formatted(.number.precision(.fractionLength(1))))
            Slider(value: $grainSize, in: 0.5...2)
                .accessibilityLabel("크레파스 자국 크기")

            Toggle("브러시 선 보일링", isOn: $animateStroke)
        }
    }
}

#Preview {
    ContentView()
}
