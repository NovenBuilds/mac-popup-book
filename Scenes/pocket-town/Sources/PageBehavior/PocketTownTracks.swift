import Foundation

public struct PocketTownPoint: Equatable, Sendable, Codable {
    public var x: Double
    public var y: Double
    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    static func + (lhs: PocketTownPoint, rhs: PocketTownPoint) -> PocketTownPoint {
        PocketTownPoint(lhs.x + rhs.x, lhs.y + rhs.y)
    }

    static func - (lhs: PocketTownPoint, rhs: PocketTownPoint) -> PocketTownPoint {
        PocketTownPoint(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    static func * (lhs: PocketTownPoint, scalar: Double) -> PocketTownPoint {
        PocketTownPoint(lhs.x * scalar, lhs.y * scalar)
    }
}

/// Shared track geometry matching `PocketTownScene` route polylines.
public enum PocketTownTracks {
    public static let station = PocketTownPoint(-1.36, -0.14)
    public static let switchCenter = PocketTownPoint(-0.14, 0.08)

    /// 河岸环线 — dark loop in the scene.
    public static let riversideLoop: [PocketTownPoint] = [
        PocketTownPoint(-1.48, -0.58), PocketTownPoint(-1.0, -0.9), PocketTownPoint(-0.34, -0.98),
        PocketTownPoint(0.35, -0.9), PocketTownPoint(0.94, -0.63), PocketTownPoint(1.28, -0.16),
        PocketTownPoint(1.08, 0.43), PocketTownPoint(0.5, 0.6), PocketTownPoint(-0.12, 0.37),
        PocketTownPoint(-0.52, -0.12), PocketTownPoint(-1.0, -0.18), PocketTownPoint(-1.48, -0.58),
    ]

    /// 钟楼环线 — golden loop in the scene.
    public static let clockLoop: [PocketTownPoint] = [
        PocketTownPoint(-1.52, -0.38), PocketTownPoint(-1.18, 0.18), PocketTownPoint(-0.63, 0.48),
        PocketTownPoint(-0.08, 0.74), PocketTownPoint(0.42, 0.75), PocketTownPoint(0.88, 0.52),
        PocketTownPoint(1.14, 0.13), PocketTownPoint(0.88, -0.24), PocketTownPoint(0.42, -0.38),
        PocketTownPoint(-0.1, -0.3), PocketTownPoint(-0.68, -0.13), PocketTownPoint(-1.52, -0.38),
    ]

    public static let approachSpine: [PocketTownPoint] = [
        station,
        PocketTownPoint(-1.22, -0.32),
        PocketTownPoint(-0.72, -0.18),
        switchCenter,
    ]

    public static func loopEntry(_ route: PocketTownRoute) -> PocketTownPoint {
        route == .riverside ? riversideLoop[0] : clockLoop[0]
    }

    /// 道岔→环线起点、环线起点→车站；与 `fullPath` 两端缺段一致，供画面与采样共用。
    public static func loopLinks(route: PocketTownRoute) -> [PocketTownPoint] {
        let entry = loopEntry(route)
        return [switchCenter, entry, station]
    }

    public static func fullPath(route: PocketTownRoute) -> [PocketTownPoint] {
        approachSpine + (route == .riverside ? riversideLoop : clockLoop) + [station]
    }
}

public enum PocketTownRoute: String, Codable, Equatable, Sendable {
    case riverside
    case clockTower
}

public struct PocketTownTrackSampler: Equatable, Sendable {
    public let points: [PocketTownPoint]
    public let segmentLengths: [Double]
    public let totalLength: Double

    public init(points: [PocketTownPoint]) {
        self.points = points
        var lengths: [Double] = []
        var total = 0.0
        for index in points.indices.dropLast() {
            let delta = points[index + 1] - points[index]
            let length = (delta.x * delta.x + delta.y * delta.y).squareRoot()
            lengths.append(length)
            total += length
        }
        segmentLengths = lengths
        totalLength = max(total, 0.001)
    }

    public func sample(_ progress: Double) -> (position: PocketTownPoint, heading: Double) {
        let progress = PocketTownGameplay.clamp(progress)
        var remaining = totalLength * progress
        for index in segmentLengths.indices {
            let length = segmentLengths[index]
            if remaining <= length || index == segmentLengths.count - 1 {
                let t = length > 0 ? remaining / length : 0
                let start = points[index]
                let end = points[index + 1]
                let position = start + (end - start) * t
                let heading = atan2(end.x - start.x, end.y - start.y)
                return (position, heading)
            }
            remaining -= length
        }
        let last = points.last ?? points[0]
        return (last, 0)
    }

    public func contains(near point: PocketTownPoint, radius: Double) -> Bool {
        let steps = 48
        for step in 0...steps {
            let sample = self.sample(Double(step) / Double(steps))
            let delta = sample.position - point
            if delta.x * delta.x + delta.y * delta.y <= radius * radius { return true }
        }
        return false
    }
}
