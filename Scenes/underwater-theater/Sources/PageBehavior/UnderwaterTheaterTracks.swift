import Foundation

public struct TheaterPoint: Equatable, Sendable, Codable {
    public var x: Double
    public var y: Double
    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static func + (lhs: TheaterPoint, rhs: TheaterPoint) -> TheaterPoint {
        TheaterPoint(lhs.x + rhs.x, lhs.y + rhs.y)
    }

    public static func - (lhs: TheaterPoint, rhs: TheaterPoint) -> TheaterPoint {
        TheaterPoint(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    public static func * (lhs: TheaterPoint, scalar: Double) -> TheaterPoint {
        TheaterPoint(lhs.x * scalar, lhs.y * scalar)
    }
}

/// 与场景几何一致的巡游折线：自珊瑚后穿出，经拱门，绕至贝壳台再折返。
public enum UnderwaterTheaterTracks {
    public static let archCenter = TheaterPoint(0.02, 0.14)
    public static let retreatAnchor = TheaterPoint(-0.58, -0.06)

    public static let patrolLoop: [TheaterPoint] = [
        retreatAnchor,
        TheaterPoint(-0.38, 0.1),
        TheaterPoint(-0.14, 0.22),
        archCenter,
        TheaterPoint(0.2, 0.1),
        TheaterPoint(0.46, 0.04),
        TheaterPoint(0.64, -0.02),
        TheaterPoint(0.4, -0.14),
        TheaterPoint(0.04, -0.1),
        TheaterPoint(-0.3, -0.12),
        retreatAnchor,
    ]

    public enum TapCurrent: Int, CaseIterable, Equatable, Sendable {
        case westSeaweed
        case archRise
        case shellLedge

        public var sceneHint: TheaterPoint {
            switch self {
            case .westSeaweed: TheaterPoint(-0.72, 0.18)
            case .archRise: TheaterPoint(0.02, 0.32)
            case .shellLedge: TheaterPoint(0.72, 0.06)
            }
        }
    }
}

public struct TheaterTrackSampler: Equatable, Sendable {
    public let points: [TheaterPoint]
    public let segmentLengths: [Double]
    public let totalLength: Double

    public init(points: [TheaterPoint]) {
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

    public func sample(_ progress: Double) -> (position: TheaterPoint, heading: Double) {
        let progress = UnderwaterTheaterGameplay.clamp(progress)
        var remaining = totalLength * progress
        for index in segmentLengths.indices {
            let length = segmentLengths[index]
            if remaining <= length || index == segmentLengths.count - 1 {
                let t = length > 0 ? remaining / length : 0
                let start = points[index]
                let end = points[index + 1]
                let position = start + (end - start) * t
                let heading = atan2(end.y - start.y, end.x - start.x)
                return (position, heading)
            }
            remaining -= length
        }
        let last = points.last ?? points[0]
        return (last, 0)
    }
}

public enum UnderwaterTheaterTapTarget: Equatable, Sendable {
    case westSeaweed
    case archRise
    case shellLedge
}
