# Changelog

## 0.2.0 — 2026-09-29

- Separate crayon edge roughness (`edgeRoughness`, 0...1) from fill texture strength.
- Add `directionality` (0...1) for overlapping diagonal back-and-forth rubs; the default 0 preserves the soft paper grain.
- Extend crayon `textureStrength` to 0...4: values above 1 deposit less wax for lighter fills. Grain fills remain capped at 1.
- Refine the procedural paper texture and add independent controls to the sample app, rendered comparison grids, and regression coverage.
- Include both new controls in asynchronous render requests and raster cache keys.

Migration: existing `.crayon(...)` construction calls still compile. The crayon enum case now has four associated values, so exhaustive destructuring must be updated. Edge roughness now defaults to a fixed 0.8 instead of following texture strength. Set it explicitly to the former strength (0...1) to retain the previous edge displacement. The procedural interior texture has changed.

Validation: 15 Swift regression tests pass with `swift test --build-system native`. The default build's Metal shader compilation remains unverified in this environment.

## 0.1.1 — 2026-09-27

- Generate crayon fill coverage off the main actor by default so changing texture strength does not synchronously block button press updates.
- Keep the previous texture visible while a replacement is prepared, and cancel obsolete work during rapid changes.
- Add `renderingMode: .synchronous` for one-shot `ImageRenderer` exports and document rendering costs.

## 0.1.0 — 2026-09-27

Initial public release of the `Crayon` SwiftUI library.

- Crayon and grain fills with configurable texture strength, brush grain, and repeatable seeds.
- Brush strokes for `Shape` and `Path`, with a built-in monoline tip and custom image-based tips.
- Textured edges for solid-color shapes and three-frame line-boil animation.
- iOS and macOS sample app, rendered previews, and guides in English, Korean, Japanese, and Simplified Chinese.

Requires iOS 17 or macOS 14 and Swift tools 5.9 or later.
