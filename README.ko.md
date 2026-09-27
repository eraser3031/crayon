# Crayon

[EN](README.md) · [KR](README.ko.md) · [JP](README.ja.md) · [CN](README.zh-CN.md)

SwiftUI에서 크레파스로 칠한 면, 브러시 선, 거친 가장자리와 보일링 애니메이션을 그리는 Swift Package입니다.
외부 이미지 없이 크레파스 질감을 만들거나, 직접 준비한 브러시 팁과 그레인을 사용할 수 있습니다.

![크레파스 채우기: 은은한 대각선 결, 종이의 빈틈, 거친 경계](Documentation/Images/crayon.png)

- **지원 환경:** iOS 17+ · macOS 14+ · Swift tools 5.9+
- **제품 / import:** `Crayon`
- SwiftUI 기반이며 외부 패키지 의존성이 없습니다.

## 빠르게 시작하기

Xcode의 **Add Package Dependencies**에서
`https://github.com/eraser3031/crayon.git`을 입력하고 버전 **0.1.1**을 선택한 뒤,
앱 타깃에 `Crayon` 제품을 추가하세요.

```swift
import SwiftUI
import Crayon

struct Drawing: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .brushFill(
                color: Color(red: 1, green: 0.84, blue: 0.25),
                textureStrength: 0.9,
                fillStyle: .crayon(grainSize: 1, seed: 7)
            )
            .frame(width: 280, height: 180)
            .padding(16)
    }
}
```

다른 Swift Package에서도 의존성으로 추가할 수 있습니다.

```swift
// Package.swift의 dependencies
.package(url: "https://github.com/eraser3031/crayon.git", from: "0.1.1")

// 사용하는 target의 dependencies
.product(name: "Crayon", package: "crayon")
```

로컬 개발 시에는 Xcode의 **Add Local** 또는 `.package(path: "../crayon")`을 사용하세요.

## 무엇을 그릴 수 있나요?

| API | 역할 |
| --- | --- |
| `Shape.brushFill(..., fillStyle: .grain)` | 준비된 브러시 그레인으로 면 채우기. 기본 스타일입니다. |
| `Shape.brushFill(..., fillStyle: .crayon(...))` | 왁스가 겹쳐진 결, 종이 틈, 거친 경계가 있는 크레파스 채우기 |
| `Shape.brushStroke` / `Path.brushStroke` | 경로를 따라 브러시 팁을 찍어 선 그리기 |
| `Color.texturing` | 단색 도형의 경계를 거칠게 만들기 |
| `View.boiling` | 손그림처럼 조금씩 흔들리는 애니메이션 |

![동일한 brushFill의 grain과 crayon 스타일, 그리고 brushStroke 비교](Documentation/Images/drawing-styles.png)

미리보기는 이 저장소의 공개 API로 렌더링한 이미지입니다. 기본 `.monoline` 팁을 사용했으며,
사용자 지정 팁을 전달하면 `.grain`과 브러시 선의 모양이 달라집니다.

## 크레파스 채우기

크레파스도 **같은 `brushFill` API**에서 `fillStyle`을 선택합니다.
별도 크레파스 모디파이어나 텍스처 이미지가 필요하지 않습니다.

종이의 고정된 요철 위에 세 번의 왁스 칠이 쌓이는 과정을 단순화한 모델입니다.
압력이 닿지 않는 홈에는 종이가 비치고, 겹쳐 칠한 부분에는 은은한 대각선 농도 차이가 남습니다.
경계도 칠이 끝나는 위치와 작은 입자의 변화를 반영하며, 외곽선을 따로 그리지 않습니다.

![크레파스 질감 강도 0, 0.5, 1 비교](Documentation/Images/crayon-strength.png)

| 설정 | 기본값 | 설명 |
| --- | --- | --- |
| `color` | `.primary` | 칠할 색. 색의 불투명도를 보존합니다. |
| `textureStrength` | `0.8` | `0...1`. 0은 단색, 1은 종이 틈과 거친 경계가 가장 잘 드러납니다. |
| `.crayon(grainSize:)` | `1` | `0.5...4`. 종이 입자와 칠 자국의 공간적 크기를 조절합니다. |
| `.crayon(seed:)` | `0` | 같은 크기와 설정에서 같은 패턴을 재현하는 값입니다. |
| `renderingMode` | `.asynchronous` | 한 번에 만드는 `ImageRenderer` 내보내기에는 `.synchronous`를 사용합니다. |

`grainScale`과 `BrushTip`은 `.grain` 스타일용입니다.
`fillStyle`은 질감 선택이고, 별도의 `style: FillStyle`은 SwiftUI의 even-odd 채우기 규칙과 안티앨리어싱 설정입니다.

레이아웃 크기는 유지하지만 크레파스 입자는 원래 경계 밖으로 조금 돌출됩니다.
렌더링 여유 공간은 `ceil(5 × grainSize × textureStrength) + 1`pt이며,
부모의 `.clipped()`는 이 입자를 자를 수 있습니다. 강도 0에서는 추가 돌출이 없습니다.

기본 설정에서 `.crayon`의 질감 이미지는 메인 액터 밖에서 계산합니다. `textureStrength`나 크기가 바뀌면 새 이미지가 준비될 때까지 이전 질감을 표시하고, 빠른 연속 변경에서는 이전 계산을 취소합니다. 처음 나타날 때는 질감이 준비될 때까지 단색으로 표시됩니다. 큰 채우기는 CPU와 메모리를 계속 사용하므로 잦은 입력 중에는 강도를 고정하는 편이 유리할 수 있습니다. 한 번에 결과를 만드는 `ImageRenderer` 내보내기에는 `renderingMode: .synchronous`를 지정해야 첫 이미지에 질감이 포함됩니다. 이 모드는 메인 액터에서 질감을 계산합니다. `.grain` 채우기는 공용 래스터 캐시를 사용하며 변경을 약 120ms 동안 모은 뒤 메인 액터에서 다시 그립니다.

## 브러시 채우기와 선

```swift
RoundedRectangle(cornerRadius: 24)
    .brushFill(.monoline, color: .orange, textureStrength: 0.8)
    .overlay {
        RoundedRectangle(cornerRadius: 24)
            .brushStroke(.monoline, color: .brown, width: 3)
    }
    .frame(width: 220, height: 140)
```

`brushStroke`는 `width`(pt), `spacing`, `flow`, `grainScale`을 조절할 수 있습니다.
선은 도형 경계의 중앙에 그려지므로, 바깥쪽 획을 보이려면 주변 여백을 확보하세요.
`Path`에도 같은 API를 사용할 수 있습니다.

### 사용자 지정 브러시

```swift
// 준비된 파일 URL에서 한 번 로드한 뒤 재사용합니다.
let tip = try BrushTip(shapeURL: shapeURL, grainURL: grainURL)

// SwiftUI 뷰 안에서
Circle()
    .brushFill(tip, color: .blue, grainScale: 240)
    .frame(width: 160, height: 160)
```

`BrushTip.monoline`은 외부 리소스가 없는 기본 브러시입니다.
이미지 로더는 검은 자국 / 흰 배경 이미지를 알파 마스크로 변환하고 팁의 투명 여백을 잘라냅니다.
입력은 한 변 최대 4096px이며, 읽을 수 없는 이미지는 `BrushTip.LoadError.invalidImage`를 발생시킵니다.
Procreate 브러시 파일을 직접 해석하지는 않습니다.

## 가장자리 텍스처

```swift
Color.blue.texturing(
    in: .roundedRectangle(cornerRadius: 12),
    x: 0.5, y: 0.5, radius: 4,
    pattern: TexturingPattern(
        grainSize: 0.6, coarseSize: 3, roughness: 0.4, seed: 42
    )
)
.frame(width: 220, height: 140)
```

단색 도형용 효과입니다. `TexturingShape`는 사각형, 둥근 사각형, 캡슐, 원을 지원하며
일반 `Shape`로도 사용할 수 있습니다. 둥근 모서리는 circular 방식이고,
같은 seed와 좌표는 같은 패턴을 만듭니다.

## 보일링 애니메이션

```swift
Circle()
    .brushStroke(.monoline, color: .blue, width: 4)
    .boiling(amount: 1.2, framesPerSecond: 6)
    .frame(width: 120, height: 120)
```

세 가지 고정 변형을 순환합니다. 배경이나 글자까지 흔들리지 않도록 장식 뷰에 적용하세요.
동작 줄이기 설정, 비활성 장면, 화면에서 사라진 뷰에서는 애니메이션을 중지합니다.
정적인 README 이미지에서는 움직임을 볼 수 없으므로 샘플 앱에서 확인하세요.

## 샘플 앱 실행

[CrayonSample.xcodeproj](Examples/CrayonSample/CrayonSample.xcodeproj)을 Xcode에서 열고
`CrayonSample` 스킴과 iOS Simulator 또는 My Mac을 선택해 실행하세요.
저장소의 패키지를 로컬로 참조하므로 별도 설치는 필요하지 않습니다.

샘플에서는 색, 질감 강도, 크레파스 자국 크기를 바꾸고
크레파스 채우기 · 기본 그레인 · 브러시 선 · 가장자리 텍스처를 비교할 수 있습니다.
보일링을 켜고 끄는 토글도 있습니다.

같은 로컬 패키지를 다른 프로젝트에서 이미 열었다면 Xcode에
`already opened from another project or workspace` 오류가 표시될 수 있습니다.
해당 프로젝트 창을 닫은 뒤 샘플을 다시 열어 주세요.

```sh
xcodebuild -project Examples/CrayonSample/CrayonSample.xcodeproj \
  -scheme CrayonSample -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

## 개발과 검증

```text
Sources/Crayon/
  BrushStroke/        # 선·면 공개 API, 샘플링, 크레파스 렌더러, 래스터 캐시
  Texturing/          # 가장자리 텍스처 API와 렌더러
  Boiling/            # 보일링 View modifier
  Shaders/            # EdgeTexture.metal, LineBoil.metal
Examples/CrayonSample/ # iOS / macOS 샘플 앱
Tests/CrayonTests/     # 기하·이미지 로딩·공개 API·렌더링 회귀 테스트
Tools/PreviewGenerator/ # README 이미지 생성 도구
Documentation/Images/ # 생성된 미리보기 PNG
```

Metal 컴파일이 가능한 Xcode / Metal Toolchain이 필요합니다.
셰이더는 패키지 번들의 `default.metallib`로 컴파일되고 `ShaderLibrary.bundle(.module)`로 로드됩니다.
앱의 기본 셰이더 라이브러리나 `Bundle.main`에 의존하지 않습니다.

```sh
swift build
swift test
```

SwiftPM에서 Metal Toolchain을 찾지 못하는 환경에서는 다음 명령으로 Swift 코드의 회귀 테스트를 실행할 수 있습니다.
native 빌드 시스템은 Metal 소스를 복사만 하므로, 위의 Xcode 샘플 빌드로 셰이더 컴파일도 확인해야 합니다.

```sh
swift test --build-system native
```

최근 구현 검증: 회귀 테스트 **11개 통과**, **iOS Simulator 샘플 앱 빌드 성공**.
실제 효과와 애니메이션은 샘플 앱에서 확인하세요. 루트 패키지는 라이브러리이므로 `swift run` 대상이 없습니다.

### 미리보기 이미지 다시 만들기

macOS에서 저장소 루트를 기준으로 실행합니다. 실제 `Crayon` 공개 API를 SwiftUI `ImageRenderer`로
2배 해상도의 PNG로 저장합니다. 고정 seed와 밝은 색상 모드를 사용합니다.

```sh
swift run --package-path Tools/PreviewGenerator --build-system native \
  PreviewGenerator Documentation/Images
```

이 도구는 크레파스, 그레인, 브러시 선의 정적 이미지를 생성합니다.
Metal 기반 가장자리 효과와 보일링은 샘플 앱에서 확인합니다.
