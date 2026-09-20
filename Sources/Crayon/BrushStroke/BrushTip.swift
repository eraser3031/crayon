import CoreGraphics
import ImageIO
import Foundation

/// Prepared once when loading a brush, then reused across strokes and redraws.
public struct BrushTip {
    public let shape: CGImage
    public let grain: CGImage
    public let rotation: Double
    public let positionJitter: CGFloat
    public let defaultSpacing: CGFloat
    public let defaultFlow: Double

    /// Approximation of the supplied Monoline preset using an original circular mask.
    public static let monoline: BrushTip = {
        func image(size: Int, circle: Bool) -> CGImage {
            let context = CGContext(data: nil, width: size, height: size,
                bitsPerComponent: 8, bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            if circle { context.fillEllipse(in: rect) } else { context.fill(rect) }
            return context.makeImage()!
        }
        return BrushTip(shape: image(size: 128, circle: true), grain: image(size: 1, circle: false),
                        rotation: 0, positionJitter: 0.08, defaultSpacing: 0.14148, defaultFlow: 1)
    }()

    private init(shape: CGImage, grain: CGImage, rotation: Double,
                 positionJitter: CGFloat, defaultSpacing: CGFloat, defaultFlow: Double) {
        self.shape = shape
        self.grain = grain
        self.rotation = rotation
        self.positionJitter = positionJitter
        self.defaultSpacing = defaultSpacing
        self.defaultFlow = defaultFlow
    }

    public init(shapeURL: URL, grainURL: URL) throws {
        rotation = 1.05427
        positionJitter = 0
        defaultSpacing = 0.08
        defaultFlow = 0.3
        shape = try Self.mask(from: shapeURL, grain: false)
        grain = try Self.mask(from: grainURL, grain: true)
    }

    private static func mask(from url: URL, grain: Bool) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw LoadError.invalidImage }
        let width = image.width, height = image.height
        guard width > 0, height > 0, width <= 4096, height <= 4096 else { throw LoadError.invalidImage }
        let row = width * 4
        var bytes = [UInt8](repeating: 0, count: row * height)
        let success = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: row, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard success else { throw LoadError.invalidImage }
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let sourceAlpha = Double(bytes[i + 3]) / 255
            let luminance = sourceAlpha > 0
                ? (Double(bytes[i]) * 0.2126 + Double(bytes[i + 1]) * 0.7152 + Double(bytes[i + 2]) * 0.0722) / (255 * sourceAlpha) : 1
            let darkness = max(0, min(1, 1 - luminance))
            // This sample has black-on-white sources. Grain contrast is an approximation,
            // not a mapping of Procreate's undocumented blend-mode values.
            let coverage = grain ? max(0, min(1, (darkness - 0.18) * 2.3)) : darkness
            let alpha = UInt8((coverage * sourceAlpha * 255).rounded())
            bytes[i] = alpha; bytes[i + 1] = alpha; bytes[i + 2] = alpha; bytes[i + 3] = alpha
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let result = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: row, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { throw LoadError.invalidImage }
        guard !grain else { return result }
        // Ignore near-transparent noise when finding the visible brush footprint.
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where bytes[y * row + x * 4 + 3] >= 5 {
                minX = min(minX, x); minY = min(minY, y)
                maxX = max(maxX, x); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY,
              let cropped = result.cropping(to: CGRect(x: minX, y: minY,
                  width: maxX - minX + 1, height: maxY - minY + 1)) else { throw LoadError.invalidImage }
        return cropped
    }

    public enum LoadError: Error { case invalidImage }
}

/// Converts point widths into a continuous small-size rendering policy.
enum BrushStrokeMetrics {
    static func width(_ value: CGFloat) -> CGFloat {
        value.isFinite ? min(max(value, 0), 512) : 64
    }

    static func thinWeight(width: CGFloat, displayScale: CGFloat) -> Double {
        let pixels = width * max(1, displayScale)
        let t = min(max((pixels - 3) / 9, 0), 1)
        return Double(1 - t * t * (3 - 2 * t))
    }

    static func accumulatedFlow(_ flow: Double) -> Double {
        1 - pow(1 - min(max(flow, 0), 1), 8)
    }
}

/// Stateless integer hashing avoids the visible rhythm of sinusoidal stamp offsets.
/// Independent streams keep horizontal and vertical displacement uncorrelated.
enum BrushStampNoise {
    static func offset(index: Int) -> CGPoint {
        CGPoint(x: value(index: index, seed: 0xA0761D6478BD642F),
                y: value(index: index, seed: 0xE7037ED1A0B428DB))
    }

    private static func value(index: Int, seed: UInt64) -> CGFloat {
        var bits = UInt64(truncatingIfNeeded: index) &+ seed
        bits = (bits ^ (bits >> 30)) &* 0xBF58476D1CE4E5B9
        bits = (bits ^ (bits >> 27)) &* 0x94D049BB133111EB
        bits ^= bits >> 31
        return CGFloat(bits >> 11) / CGFloat(1 << 53) * 2 - 1
    }
}
