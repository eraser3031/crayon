import SwiftUI

/// Raster coverage shared by the fill and its rough boundary. Noise is anchored
/// in local point coordinates; no contour dabs or regularly spaced scratches.
enum CrayonMarks {
    static func image(path: Path, size: CGSize, displayScale: CGFloat,
                      strength: Double, grainSize: CGFloat, seed: UInt32,
                      style: FillStyle, outset: CGFloat) -> CGImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        // Keep temporary masks bounded, including on very large decoration views.
        let scale = min(max(displayScale, 1), 2,
                        sqrt(2_097_152 / (size.width * size.height)))
        let width = max(1, Int(ceil(size.width * scale)))
        let height = max(1, Int(ceil(size.height * scale)))
        var silhouette = [UInt8](repeating: 0, count: width * height)
        let drawn = silhouette.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0) else { return false }
            // CG bitmap rows and SwiftUI paths use opposite vertical axes.
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: scale, y: -scale)
            context.setShouldAntialias(style.isAntialiased)
            context.setFillColor(gray: 1, alpha: 1)
            context.addPath(path.cgPath)
            context.drawPath(using: style.isEOFilled ? .eoFill : .fill)
            return true
        }
        guard drawn else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let offset = Double(seed & 0xffff) / 37
        let offsetY = Double(seed >> 16) / 41
        func coverage(_ x: Double, _ y: Double) -> Double {
            let ix = Int(floor(x)), iy = Int(floor(y))
            let fx = x - Double(ix), fy = y - Double(iy)
            func sample(_ x: Int, _ y: Int) -> Double {
                guard x >= 0, y >= 0, x < width, y < height else { return 0 }
                return Double(silhouette[y * width + x]) / 255
            }
            return mix(mix(sample(ix, iy), sample(ix + 1, iy), fx),
                       mix(sample(ix, iy + 1), sample(ix + 1, iy + 1), fx), fy)
        }
        for y in 0..<height {
            for x in 0..<width {
                let px = (Double(x) + 0.5) / Double(scale)
                let py = (Double(y) + 0.5) / Double(scale)
                let u = (px - Double(outset)) / Double(grainSize) + offset
                let v = (py - Double(outset)) / Double(grainSize) + offsetY
                let roughX = (noise(u / 3.1, v / 3.1) - 0.5) * 6
                    + (noise(u / 0.65, v / 0.65) - 0.5) * 2.6
                let roughY = (noise(u / 3.1 + 73, v / 3.1 + 19) - 0.5) * 6
                    + (noise(u / 0.65 + 31, v / 0.65 + 47) - 0.5) * 2.6
                let edge = coverage(Double(x) + roughX * Double(grainSize * scale) * strength,
                                    Double(y) + roughY * Double(grainSize * scale) * strength)
                guard edge > 0 else { continue }
                // Paper relief stays fixed across passes. Wax catches the peaks;
                // deeper, clustered valleys remain bare until pressure reaches them.
                let relief = noise(u / 0.55, v / 0.55) * 0.55
                    + noise(u / 2.1 + 11, v / 2.1 + 23) * 0.45
                let along = u * 0.78 - v * 0.63
                let across = u * 0.63 + v * 0.78
                let handPressure = noise(u / 23 + 51, v / 23 + 9)
                var waxCoverage = 0.0
                for pass in 0..<3 {
                    let shift = Double(pass) * 37
                    // Finite overlapping rubs: long-axis pressure variation is
                    // gentle, and each pass meets the same paper topography.
                    let pressure = noise(along / 13 + shift, across / 1.5 + shift)
                    let reach = 0.39 + pressure * 0.13 + handPressure * 0.08
                    let contact = min(1, max(0, (relief + reach - 0.60) / 0.12))
                    let deposit = contact * (0.40 + pressure * 0.24)
                    waxCoverage += (1 - waxCoverage) * deposit
                }
                let alpha = UInt8((edge * (1 - strength + strength * waxCoverage) * 255).rounded())
                let index = (y * width + x) * 4
                pixels[index] = alpha
                pixels[index + 1] = alpha
                pixels[index + 2] = alpha
                pixels[index + 3] = alpha
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    private static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    private static func noise(_ x: Double, _ y: Double) -> Double {
        let ix = Int64(floor(x)), iy = Int64(floor(y))
        let fx = x - floor(x), fy = y - floor(y)
        let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
        func hash(_ x: Int64, _ y: Int64) -> Double {
            var bits = UInt64(bitPattern: x) &* 0x9E3779B97F4A7C15
                &+ UInt64(bitPattern: y) &* 0xBF58476D1CE4E5B9
            bits = (bits ^ (bits >> 30)) &* 0xBF58476D1CE4E5B9
            bits = (bits ^ (bits >> 27)) &* 0x94D049BB133111EB
            return Double((bits ^ (bits >> 31)) >> 11) / Double(1 << 53)
        }
        return mix(mix(hash(ix, iy), hash(ix + 1, iy), sx),
                   mix(hash(ix, iy + 1), hash(ix + 1, iy + 1), sx), sy)
    }
}
