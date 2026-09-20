#include <metal_stdlib>
using namespace metal;

// Three repeatable drawings, not time-continuous wobbling or whole-view translation.
// Neighboring pixels move together, preserving a thin stroke's local thickness.
[[ stitchable ]] float2 lineBoil(float2 position, float amount, float frame) {
    float phase = frame * 2.09439510239;
    float x = sin(position.y * 0.075 + position.x * 0.023 + phase)
            + 0.35 * sin(position.y * 0.19 - position.x * 0.037 + phase * 2.0);
    float y = sin(position.x * 0.069 - position.y * 0.027 + phase + 1.7)
            + 0.35 * sin(position.x * 0.17 + position.y * 0.041 - phase);
    // Components are bounded by amount, matching maxSampleOffset exactly.
    return position + float2(x, y) * (amount / 1.35);
}
