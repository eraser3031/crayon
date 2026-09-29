# Crayon

[EN](README.md) · [KR](README.ko.md) · [JP](README.ja.md) · [CN](README.zh-CN.md)

AI-friendly package guide: [llms.txt](https://github.com/eraser3031/crayon/blob/main/llms.txt)

A Swift package for crayon fills, brush strokes, rough edges, and line-boil animation in SwiftUI.
Create crayon textures without external images, or supply your own brush tip and grain.

![Crayon: soft grain, directional rubs, and a light touch](Documentation/Images/crayon.png)

- **Requirements:** iOS 17+ · macOS 14+ · Swift tools 5.9+
- **Product / import:** `Crayon`
- Built on SwiftUI with no external package dependencies.

## Quick start

In Xcode, choose **Add Package Dependencies**, enter
`https://github.com/eraser3031/crayon.git`, select version **0.2.0**, and add
the `Crayon` product to your app target.

```swift
import SwiftUI
import Crayon

struct Drawing: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .brushFill(
                color: Color(red: 1, green: 0.84, blue: 0.25),
                textureStrength: 1,
                fillStyle: .crayon(seed: 7, edgeRoughness: 0.8, directionality: 0.5)
            )
            .frame(width: 280, height: 180)
            .padding(16)
    }
}
```

You can also add it to another Swift package.

```swift
// Package.swift dependencies
.package(url: "https://github.com/eraser3031/crayon.git", from: "0.2.0")

// Dependencies of the consuming target
.product(name: "Crayon", package: "crayon")
```

For local development, use Xcode's **Add Local** option or
`.package(path: "../crayon")` instead.

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

Three independent controls shape the result:

- **`textureStrength`** changes the interior: 0 is solid, 1 shows paper grain, and 2–4 make the wax lighter. Higher values mean a lighter fill, not darker pigment.
- **`edgeRoughness`** changes the boundary: 0 keeps the original shape, 1 gives the roughest edge.
- **`directionality`** changes how strongly back-and-forth rubbing appears: 0 keeps soft grain, 1 reveals diagonal rubs. It controls their prominence, not their angle.

### Compare strength and directionality

Rows vary `textureStrength` from 1 to 4; columns vary `directionality` from 0 to 1. Every tile uses the same color, seed, and `edgeRoughness: 0.8`.

![Strength 1–4 by directionality 0, 0.5, and 1](Documentation/Images/crayon-directionality.png)

[Compare the same grid with clean edges (`edgeRoughness: 0`)](Documentation/Images/crayon-directionality-clean.png).

### Lighter fills

The same fine paper grain remains as less wax is deposited. Directionality is fixed at 0 and edge roughness at 0.8.

![Crayon strength 1, 2, 3, and 4](Documentation/Images/crayon-lighter-coverage.png)

### Independent edges

A solid interior can have a rough edge, and a textured interior can have a clean edge. At `textureStrength: 0`, directionality has no visible effect because the interior is solid.

![Solid and textured fills with clean and rough edges](Documentation/Images/crayon-independent-controls.png)

### Parameters

| Setting | Default | Description |
| --- | --- | --- |
| `color` | `.primary` | Fill color. Its opacity is preserved. |
| `textureStrength` | `0.8` | `0...4` for crayon (`0...1` for grain). 0 is solid; 1 reveals paper grain; 2–4 deposit less wax evenly across the fill for a lighter color with fine paper grain; they do not add blank bands or enlarge paper gaps. Does not change edge roughness. |
| `.crayon(grainSize:)` | `1` | `0.5...4`. Controls the spatial size of paper grain and wax marks. |
| `.crayon(edgeRoughness:)` | `0.8` | `0...1`. 0 preserves the original boundary; 1 gives full edge displacement, independently of `textureStrength`. |
| `.crayon(directionality:)` | `0` | `0...1`. Blends soft grain into overlapping diagonal back-and-forth rubs. Controls the visibility of direction, not its angle. Independent of edge roughness and strength. |
| `.crayon(seed:)` | `0` | Reproduces the same pattern at the same size and settings. |
| `renderingMode` | `.asynchronous` | Use `.synchronous` for a one-shot `ImageRenderer` export. |

`grainScale` and `BrushTip` apply to the `.grain` style.
`fillStyle` selects the texture; the separate `style: FillStyle` controls SwiftUI's even-odd fill rule and antialiasing.

### Layout and rendering

Layout dimensions stay unchanged, but crayon pigment can extend slightly beyond the original boundary.
The rendering margin is `ceil(5 × grainSize × edgeRoughness) + 1` pt.
An ancestor's `.clipped()` can trim this pigment. At edge roughness 0, there is no extra overhang. Set `textureStrength` and `edgeRoughness` to 0 for a solid fill with a clean boundary. For migration from 0.1.x, see the [0.2.0 changelog](CHANGELOG.md#020--2026-09-29).

By default, `.crayon` computes its coverage image off the main actor. When `textureStrength`, `edgeRoughness`, `directionality`, or geometry changes, the previous texture remains visible until the new image is ready; rapid changes cancel obsolete work. The first appearance shows a solid fill until the texture is ready. Large fills still consume CPU and memory, so keeping texture strength fixed can help during frequent interaction. For a one-shot `ImageRenderer` export, pass `renderingMode: .synchronous` to include the texture in the first image. This mode performs the expensive calculation on the main actor. `.grain` fills use the shared raster cache, which coalesces changes for about 120 ms and also renders on the main actor.

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

Change the color, texture strength, edge roughness, directionality, and crayon mark size to compare crayon fills, default grain,
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

Validation for 0.2.0: **15 regression tests passed** with the native build system. Metal shader compilation is not verified for this release.
Use the sample app to inspect effects and animation. The root package is a library and has no `swift run` target.

### Regenerate preview images

Run from the repository root on macOS. The tool renders the public `Crayon` API with SwiftUI `ImageRenderer`
into 2× PNGs using fixed seeds and light mode.

```sh
swift run --package-path Tools/PreviewGenerator --build-system native \
  PreviewGenerator Documentation/Images --all
```

The `--all` option regenerates every preview, including the strength × directionality grids and independent-edge comparison. Use `--compare-directionality`, `--compare-coverage`, or `--compare-edges` to regenerate only one comparison. Images use synchronous rendering to capture the finished texture.
Use the sample app for Metal-based edge effects and line-boil animation.
