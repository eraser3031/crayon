#include <metal_stdlib>
using namespace metal;

// Fixed spatial hash: no time input, textures, or per-frame CPU work.
static float grainHash(float2 p) {
    float3 q = fract(float3(p.x, p.y, p.x) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

static float softNoise(float2 p) {
    float2 cell = floor(p);
    float2 t = fract(p);
    t = t * t * (3.0 - 2.0 * t);
    return mix(mix(grainHash(cell), grainHash(cell + float2(1, 0)), t.x),
               mix(grainHash(cell + float2(0, 1)), grainHash(cell + 1), t.x), t.y);
}

[[ stitchable ]] half4 edgeTexture(float2 position, half4 color, float2 size,
                                  float outset, float2 offset, float radius, float pixel,
                                  float shapeKind, float cornerRadius,
                                  float grainSize, float coarseSize, float roughness, float2 seedOffset) {
    float2 p = position - outset - offset;
    float2 center = p - size * 0.5;
    float halfShortSide = min(size.x, size.y) * 0.5;
    float distance;
    if (shapeKind > 1.5) {
        // An inscribed circle, even when the proposed bounds aren't square.
        distance = halfShortSide - length(center);
    } else {
        // A capsule is a rounded rectangle with the maximum corner radius.
        float corner = shapeKind > 0.5 ? halfShortSide : clamp(cornerRadius, 0.0, halfShortSide);
        float2 q = abs(center) - size * 0.5 + corner;
        distance = corner - length(max(q, 0.0)) - min(max(q.x, q.y), 0.0);
    }
    // Keep the center opaque even for small views or a large requested radius.
    float band = min(radius, max(0.001, min(size.x, size.y) * 0.45));
    if (distance >= band + pixel) return color;
    if (distance <= -band - pixel) return half4(0);

    // Coarse irregularity + fine grains; both use points, never normalized UVs.
    float coarse = softNoise(p / coarseSize + seedOffset);
    float fine = softNoise(p / grainSize + float2(17.3, 9.2) + seedOffset);
    float noise = (mix(coarse, fine, 1.0 - roughness) - 0.5) * 2.0;
    float edge = distance + noise * band;
    float alpha = smoothstep(-pixel * 0.5, pixel * 0.5, edge);
    return color * half(alpha); // Preserve premultiplied RGB and source opacity.
}
