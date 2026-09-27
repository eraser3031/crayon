# Changelog

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
