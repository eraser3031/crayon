# Crayon

[EN](README.md) · [KR](README.ko.md) · [JP](README.ja.md) · [CN](README.zh-CN.md)

A Swift package for crayon fills, brush strokes, rough edges, and line-boil animation in SwiftUI.
Create crayon textures without external images, or supply your own brush tip and grain.

![Crayon fill with subtle diagonal layers, paper gaps, and rough edges](Documentation/Images/crayon.png)

- **Requirements:** iOS 17+ · macOS 14+ · Swift tools 5.9+
- **Product / import:** `Crayon`
- Built on SwiftUI with no external package dependencies.

## Quick start

In Xcode, choose **Add Package Dependencies → Add Local**, select this repository,
and add the `Crayon` product to your app target.

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

You can also add it as a local dependency in another Swift package.

```swift
// Package.swift dependencies
.package(path: "../crayon")

// Dependencies of the consuming target
.product(name: "Crayon", package: "crayon")
```

## What can you draw?

| API | Purpose |
| --- | --- |
| `Shape.brushFill(..., fillStyle: .grain)` | Fill with a prepared brush grain. The default style. |
| `Shape.brushFill(..., fillStyle: .crayon(...))` | Crayon fill with layered wax, paper gaps, and rough edges |
| `Shape.brushStroke` / `Path.brushStroke` | Draw strokes by stamping a brush tip along a path |
| `Color.texturing` | Roughen the edges of a solid-color shape |
| `View.boiling` | Add a subtle, hand-drawn wobble |

![grain and crayon styles using the same brushFill API, alongside brushStroke](Documentation/Images/drawing-styles.png)

These previews are rendered with this repository's public API and the default `.monoline` tip.
Custom tips change the appearance of `.grain` fills and brush strokes.

## Crayon fills

Select `fillStyle` on **the same `brushFill` API**.
No separate crayon modifier or texture image is required.

The renderer approximates three wax passes accumulating over fixed paper relief.
Paper shows through grooves the pressure does not reach; overlapping passes leave subtle diagonal variations in density.
The boundary reflects uneven stopping positions and fine grain, without a separate outline.

![Crayon texture strength at 0, 0.5, and 1](Documentation/Images/crayon-strength.png)

| Setting | Default | Description |
| --- | --- | --- |
| `color` | `.primary` | Fill color. Its opacity is preserved. |
| `textureStrength` | `0.8` | `0...1`. 0 is solid; 1 reveals the full paper gaps and rough edges. |
| `.crayon(grainSize:)` | `1` | `0.5...4`. Controls the spatial size of paper grain and wax marks. |
| `.crayon(seed:)` | `0` | Reproduces the same pattern at the same size and settings. |

`grainScale` and `BrushTip` apply to the `.grain` style.
`fillStyle` selects the texture; the separate `style: FillStyle` controls SwiftUI's even-odd fill rule and antialiasing.

Layout dimensions stay unchanged, but crayon pigment can extend slightly beyond the original boundary.
The rendering margin is `ceil(5 × grainSize × textureStrength) + 1` pt.
An ancestor's `.clipped()` can trim this pigment. At strength 0, there is no extra overhang.

## Brush fills and strokes

```swift
RoundedRectangle(cornerRadius: 24)
    .brushFill(.monoline, color: .orange, textureStrength: 0.8)
    .overlay {
        RoundedRectangle(cornerRadius: 24)
            .brushStroke(.monoline, color: .brown, width: 3)
    }
    .frame(width: 220, height: 140)
```

`brushStroke` exposes `width` (pt), `spacing`, `flow`, and `grainScale`.
Strokes are centered on the shape boundary, so leave room for their outer half.
The same API is available on `Path`.

### Custom brushes

```swift
// Load once from your image file URLs, then reuse.
let tip = try BrushTip(shapeURL: shapeURL, grainURL: grainURL)

// Inside a SwiftUI view
Circle()
    .brushFill(tip, color: .blue, grainScale: 240)
    .frame(width: 160, height: 160)
```

`BrushTip.monoline` is the built-in brush and needs no external resources.
The image loader converts black marks on white backgrounds into alpha masks and trims transparent tip margins.
Inputs are limited to 4096 px per side; unreadable images throw `BrushTip.LoadError.invalidImage`.
Procreate brush files are not parsed directly.

## Edge textures

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

This effect is for solid-color shapes. `TexturingShape` supports rectangles, rounded rectangles, capsules, and circles,
and can also be used as a regular `Shape`. Rounded corners use the circular style.
The same seed and coordinates produce the same pattern.

## Line-boil animation

```swift
Circle()
    .brushStroke(.monoline, color: .blue, width: 4)
    .boiling(amount: 1.2, framesPerSecond: 6)
    .frame(width: 120, height: 120)
```

Cycles through three fixed distortions. Apply it to decorative views so backgrounds and text remain steady.
Animation stops when Reduce Motion is enabled, the scene is inactive, or the view disappears.
Use the sample app to see motion; README images are static.

## Run the sample app

Open [CrayonSample.xcodeproj](Examples/CrayonSample/CrayonSample.xcodeproj) in Xcode,
select the `CrayonSample` scheme, and run on an iOS Simulator or My Mac.
It references this repository's package locally, so no separate installation is needed.

Change the color, texture strength, and crayon mark size to compare crayon fills, default grain,
brush strokes, and edge textures. A toggle turns line-boil animation on and off.

If another open project uses the same local package, Xcode may report
`already opened from another project or workspace`.
Close that project window and reopen the sample.

```sh
xcodebuild -project Examples/CrayonSample/CrayonSample.xcodeproj \
  -scheme CrayonSample -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

## Development and verification

```text
Sources/Crayon/
  BrushStroke/        # Stroke/fill API, sampling, crayon renderer, raster cache
  Texturing/          # Edge texture API and renderer
  Boiling/            # Boiling View modifier
  Shaders/            # EdgeTexture.metal, LineBoil.metal
Examples/CrayonSample/ # iOS / macOS sample app
Tests/CrayonTests/     # Geometry, image loading, public API and rendering tests
Tools/PreviewGenerator/ # README preview generator
Documentation/Images/ # Generated preview PNGs
```

Xcode / a Metal Toolchain capable of compiling Metal is required.
Shaders compile into the package bundle's `default.metallib` and load through `ShaderLibrary.bundle(.module)`.
They do not depend on the app's default shader library or `Bundle.main`.

```sh
swift build
swift test
```

If SwiftPM cannot find the Metal Toolchain, run the Swift regression tests with the command below.
The native build system only copies Metal sources, so also use the Xcode sample build above to verify shader compilation.

```sh
swift test --build-system native
```

Latest implementation checks: **11 regression tests passed** and **the iOS Simulator sample app built successfully**.
Use the sample app to inspect effects and animation. The root package is a library and has no `swift run` target.

### Regenerate preview images

Run from the repository root on macOS. The tool renders the public `Crayon` API with SwiftUI `ImageRenderer`
into 2× PNGs using fixed seeds and light mode.

```sh
swift run --package-path Tools/PreviewGenerator --build-system native \
  PreviewGenerator Documentation/Images
```

The generator produces static previews of crayon fills, grain fills, and brush strokes.
Use the sample app for Metal-based edge effects and line-boil animation.
