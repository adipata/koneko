import SwiftUI

/// Compares a stroke drawn by the child with the expected KanjiVG stroke.
/// All points are in KanjiVG's 109×109 coordinate space.
nonisolated enum StrokeMatcher {
    static let sampleCount = 24

    enum Verdict: Equatable {
        case correct
        /// Right stroke, drawn from the wrong end.
        case reversed
        /// Matches a later stroke (index), so the order is wrong.
        case wrongOrder(Int)
        /// Doesn't match any stroke well enough.
        case tooFar
        /// Just a tap or a tiny scribble; ignore it.
        case tooShort
    }

    /// Evenly spaced points along a reference stroke.
    static func samples(of path: Path) -> [CGPoint] {
        (0..<sampleCount).map { index in
            let t = max(0.001, CGFloat(index) / CGFloat(sampleCount - 1))
            return path.trimmedPath(from: 0, to: t).currentPoint ?? .zero
        }
    }

    static func evaluate(
        drawn: [CGPoint],
        expectedIndex: Int,
        references: [[CGPoint]],
        tolerance: CGFloat
    ) -> Verdict {
        guard length(of: drawn) >= 2.5, references.indices.contains(expectedIndex) else { return .tooShort }
        let stroke = resample(drawn, count: sampleCount)
        let expected = references[expectedIndex]

        let forward = meanDistance(stroke, expected)
        if forward <= tolerance { return .correct }
        let backward = meanDistance(stroke, expected.reversed())
        if backward <= tolerance { return .reversed }

        for index in references.indices where index > expectedIndex {
            if meanDistance(stroke, references[index]) <= tolerance {
                return .wrongOrder(index)
            }
        }
        return .tooFar
    }

    // MARK: Geometry

    static func length(of points: [CGPoint]) -> CGFloat {
        zip(points, points.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    static func meanDistance(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
        let pairs = zip(a, b)
        let count = min(a.count, b.count)
        guard count > 0 else { return .infinity }
        return pairs.reduce(0) { $0 + distance($1.0, $1.1) } / CGFloat(count)
    }

    /// Resamples a polyline into `count` points evenly spaced along its length.
    static func resample(_ points: [CGPoint], count: Int) -> [CGPoint] {
        guard let first = points.first, let last = points.last else { return [] }
        let total = length(of: points)
        guard points.count > 1, total > 0 else { return Array(repeating: first, count: count) }

        let interval = total / CGFloat(count - 1)
        var result = [first]
        var accumulated: CGFloat = 0
        var previous = first
        var index = 1
        while index < points.count, result.count < count {
            let point = points[index]
            let segment = distance(previous, point)
            if segment > 0, accumulated + segment >= interval {
                let t = (interval - accumulated) / segment
                let newPoint = CGPoint(x: previous.x + t * (point.x - previous.x),
                                       y: previous.y + t * (point.y - previous.y))
                result.append(newPoint)
                previous = newPoint
                accumulated = 0
                // Stay on the same segment: there may be more samples on it.
            } else {
                accumulated += segment
                previous = point
                index += 1
            }
        }
        while result.count < count { result.append(last) }
        return result
    }
}
