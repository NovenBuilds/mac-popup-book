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
    public static let station = PocketTownPoint(-1.12, -0.52)
    public static let switchCenter = PocketTownPoint(0.15, -0.52)
    public static let stationWall = PocketTownPoint(-1.10, -0.84)

    public static let approachSpine = [
        station, PocketTownPoint(-0.45, -0.52), switchCenter,
    ]

    public static let returnTrack = [
        PocketTownPoint(1.50, 0.65), PocketTownPoint(1.23, 0.94),
        PocketTownPoint(-1.28, 0.94), PocketTownPoint(-1.57, 0.64),
        PocketTownPoint(-1.57, -0.23), PocketTownPoint(-1.45, -0.46),
        PocketTownPoint(-1.30, -0.52), station,
    ]

    public static let riversideLoop =
        [
            switchCenter, PocketTownPoint(0.38, -0.79), PocketTownPoint(0.63, -0.94),
            PocketTownPoint(1.18, -0.94), PocketTownPoint(1.50, -0.63),
        ] + returnTrack

    public static let clockLoop =
        [
            switchCenter, PocketTownPoint(0.38, -0.28), PocketTownPoint(0.68, -0.08),
            PocketTownPoint(1.23, -0.08), PocketTownPoint(1.50, 0.17),
        ] + returnTrack

    public static func loop(for route: PocketTownRoute) -> [PocketTownPoint] {
        route == .riverside ? riversideLoop : clockLoop
    }

    public static func fullPath(route: PocketTownRoute) -> [PocketTownPoint] {
        approachSpine + loop(for: route).dropFirst()
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
