# Crayon

SwiftUI에서 질감 있는 선과 면, 가장자리 텍스처, 보일링 애니메이션을 그리는 Swift Package입니다.
`turtle`에서 드로잉 구현을 분리했으며 앱이나 Firebase에 의존하지 않습니다.

- Swift tools 5.9 이상
- iOS 17 / macOS 14 이상
- 제품 및 모듈 이름: `Crayon`

## 설치

Xcode의 **Add Package Dependencies → Add Local**에서 이 폴더를 선택하고
앱 타깃에 `Crayon` 제품을 추가합니다. 다른 Swift Package에서는 다음처럼 연결합니다.

```swift
// Package.swift의 dependencies
.package(path: "../crayon")

// 사용하는 target의 dependencies
.product(name: "Crayon", package: "crayon")
```

`turtle`은 형제 폴더 `../crayon`을 로컬 패키지로 참조합니다. 두 저장소를 같은 상위 폴더에 두세요.

## 선·면·보일링

```swift
import SwiftUI
import Crayon

struct Drawing: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .brushFill(.monoline, color: .orange)
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .brushStroke(.monoline, color: .brown, width: 3)
            }
            .boiling(amount: 1.2, framesPerSecond: 6)
            .frame(width: 220, height: 140)
    }
}
```

- `Path.brushStroke`와 `Shape.brushStroke`: 경로를 따라 브러시 팁을 찍습니다. `width`는 pt 단위이며 `spacing`, `flow`, `grainScale`을 조절할 수 있습니다.
- `Shape.brushFill`: 도형 내부를 브러시 그레인으로 채웁니다. `textureStrength` 0은 단색, 1은 그레인의 투명 틈을 그대로 유지합니다.
- `View.boiling`: 세 가지 고정 변형을 순환합니다. 동작 줄이기 설정, 비활성 장면, 화면에서 사라진 뷰에서는 애니메이션을 중지합니다. 배경이나 글자까지 흔들리지 않도록 장식 뷰에 적용하세요.
- 선은 경계 중앙에 그려집니다. 상위 뷰의 clipping은 바깥쪽 획이나 입자를 자를 수 있습니다.

`BrushTip.monoline`은 외부 리소스가 없는 기본 브러시입니다. 질감 이미지는 호출 측에서 한 번 로드하여 재사용합니다.

```swift
let tip = try BrushTip(shapeURL: shapeURL, grainURL: grainURL)
```

현재 이미지 로더는 검은 자국/흰 배경 이미지를 알파 마스크로 변환하고 팁의 투명 여백을 잘라냅니다.
입력은 한 변 최대 4096px이며 읽을 수 없는 이미지는 `BrushTip.LoadError.invalidImage`를 발생시킵니다.
이 로더는 turtle의 파스텔 설정을 유지하며 임의의 Procreate 브러시 파일을 해석하지 않습니다.
파스텔 샘플 PNG는 turtle의 데모 리소스로 남아 있고 이 패키지에는 포함하지 않습니다.

## 가장자리 텍스처

```swift
Color.blue.texturing(
    in: .roundedRectangle(cornerRadius: 12),
    x: 0.5, y: 0.5, radius: 4,
    pattern: TexturingPattern(grainSize: 0.6, coarseSize: 3, roughness: 0.4, seed: 42)
)
```

`TexturingShape`는 사각형, 둥근 사각형, 캡슐, 원을 지원하며 `Shape`로도 사용할 수 있습니다.
단색 도형 전용 효과이며 둥근 모서리는 circular 방식입니다. 같은 seed와 좌표는 같은 패턴을 만듭니다.

## 구조와 검증

```text
Sources/Crayon/
  BrushStroke/       # 공개 브러시 API, 내부 샘플링 및 래스터 캐시
  Texturing/         # 공개 텍스처 API와 내부 렌더러
  Boiling/           # 보일링 View modifier
  Shaders/           # EdgeTexture.metal, LineBoil.metal
Tests/CrayonTests/   # 기하·브러시·공개 API 회귀 테스트
```

Metal 파일은 `.process("Shaders")` 리소스로 선언합니다. Xcode 빌드는 패키지 번들의
`default.metallib`로 컴파일하며 렌더러는 `ShaderLibrary.bundle(.module)`로 로드합니다.
앱의 기본 셰이더 라이브러리나 `Bundle.main`에 의존하지 않습니다.

```sh
swift build
swift test
xcodebuild -project ../turtle/turtle.xcodeproj -scheme turtle \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

Metal 컴파일이 가능한 Xcode/Metal Toolchain이 필요합니다. 이전 SwiftPM native 빌드 시스템은
Metal 소스를 복사만 하므로 `swift test --build-system native`는 Swift 코드의 회귀 검증용입니다.
셰이더 번들 검증은 Xcode 빌드 또는 Metal을 처리하는 SwiftPM 빌드 시스템으로 진행해야 합니다.

이 패키지는 라이브러리이므로 `swift run` 실행 대상은 없습니다. 실제 효과는 turtle에서 확인합니다.

### 현재 환경에서 확인한 결과

Xcode 27.1 / Swift 6.4에서 다음을 확인했습니다.

- `swift test --build-system native`: 테스트 9개 통과.
- turtle Debug / iOS Simulator: 앱 빌드 성공, 앱 내부 패키지 번들에 `default.metallib` 포함.
- Crayon Release / generic iOS: Swift와 Metal 빌드 성공.

현재 환경의 기본 `swift test`는 설치된 Metal Toolchain을 찾지 못해 실패합니다.
동일한 Metal 소스는 Xcode에서 정상 컴파일되므로, 이 환경에서는 위의 native 테스트와
Xcode 빌드를 함께 사용합니다. 실제 기기에서의 화면·애니메이션 확인은 별도입니다.
