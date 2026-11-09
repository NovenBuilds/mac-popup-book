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

/// 鱼群在拱门前方的水道巡游，整队都与可折叠的布景隔开。
public enum UnderwaterTheaterTracks {
    public static let frontWater = TheaterPoint(0.02, 0.655)
    public static let shell = TheaterPoint(0.76, 0.29)

    public static let patrolLoop: [TheaterPoint] = (0...48).map { step in
        let angle = Double(step % 48) * 2 * .pi / 48 + .pi
        return TheaterPoint(-0.05 + 0.48 * cos(angle), frontWater.y + 0.028 * sin(angle))
    }

    public enum TapCurrent: Int, CaseIterable, Equatable, Sendable {
        case westSeaweed
        case archRise
        case shellLedge

        public var sceneHint: TheaterPoint {
            switch self {
            case .westSeaweed: TheaterPoint(-0.72, 0.18)
            case .archRise: TheaterPoint(0.02, 0.32)
            case .shellLedge: TheaterPoint(shell.x + 0.28, shell.y)
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
