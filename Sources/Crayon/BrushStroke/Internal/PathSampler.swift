import CoreGraphics

/// Flattens Beziers adaptively, then samples by arc length, independently per subpath.
enum PathSampler {
    static func points(on path: CGPath, spacing: CGFloat) -> [CGPoint] {
        let step = spacing.isFinite ? max(0.5, spacing) : 1
        var contours: [[CGPoint]] = []
        var current: [CGPoint] = []
        var cursor = CGPoint.zero
        func flush() {
            if !current.isEmpty { contours.append(current) }
            current = []
        }
        func flatten(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint, depth: Int = 0) {
            let polygon = distance(a, b) + distance(b, c) + distance(c, d)
            if depth >= 12 || polygon - distance(a, d) < 0.05 {
                current.append(d)
                return
            }
            let ab = midpoint(a, b), bc = midpoint(b, c), cd = midpoint(c, d)
            let abc = midpoint(ab, bc), bcd = midpoint(bc, cd)
            let m = midpoint(abc, bcd)
            flatten(a, ab, abc, m, depth: depth + 1)
            flatten(m, bcd, cd, d, depth: depth + 1)
        }
        path.applyWithBlock { pointer in
            let e = pointer.pointee
            switch e.type {
            case .moveToPoint:
                flush(); cursor = e.points[0]; current = [cursor]
            case .addLineToPoint:
                current.append(e.points[0]); cursor = e.points[0]
            case .addQuadCurveToPoint:
                let control = e.points[0], end = e.points[1]
                flatten(cursor, interpolate(cursor, control, 2 / 3), interpolate(end, control, 2 / 3), end)
                cursor = end
            case .addCurveToPoint:
                flatten(cursor, e.points[0], e.points[1], e.points[2]); cursor = e.points[2]
            case .closeSubpath:
                if let first = current.first { current.append(first); cursor = first }
                flush()
            @unknown default: break
            }
        }
        flush()
        var result: [CGPoint] = []
        for contour in contours {
            guard let first = contour.first else { continue }
            result.append(first)
            var remaining = step
            let contourStart = result.count - 1
            for (a, b) in zip(contour, contour.dropFirst()) {
                let length = distance(a, b)
                guard length > 0 else { continue }
                var along = remaining
                while along <= length && result.count < 20000 {
                    result.append(interpolate(a, b, along / length))
                    along += step
                }
                remaining = along - length
            }
            if contour.count > 1, contour.last == first,
               result.count > contourStart + 1, let last = result.last,
               distance(last, first) < step * 0.25 {
                result.removeLast()
            }
            // Don't double-stamp the endpoint of a closed contour.
            if let last = contour.last, last != first,
               let stamped = result.last, distance(stamped, last) > step * 0.25 {
                result.append(last)
            }
        }
        return result
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }
    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint { interpolate(a, b, 0.5) }
    private static func interpolate(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}
