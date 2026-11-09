import Foundation

public struct RoomGuestWaypoint: Equatable, Sendable {
    public var x: Double
    public var z: Double

    public init(x: Double, z: Double) {
        self.x = x
        self.z = z
    }
}

/// 绕过扩张后家具占地的折线路径；停靠点与重定向共用。
public enum RoomGuestRouter {
    public static let eastLow = RoomGuestWaypoint(x: 0.82, z: -0.35)
    public static let eastHigh = RoomGuestWaypoint(x: 0.82, z: 0.35)
    public static let westLow = RoomGuestWaypoint(x: -0.88, z: -0.7)
    public static let westMid = RoomGuestWaypoint(x: -0.88, z: 0.28)
    public static let westHigh = RoomGuestWaypoint(x: -0.88, z: 0.52)

    public static let routeHubs: [RoomGuestWaypoint] = [
        eastLow, eastHigh, westLow, westMid, westHigh,
    ]

    public static func path(from start: RoomGuestWaypoint, to end: RoomGuestWaypoint) -> [RoomGuestWaypoint] {
        if segmentClear(from: start, to: end) {
            return [start, end]
        }

        var best: [RoomGuestWaypoint]?
        var bestLength = Double.infinity

        func consider(_ points: [RoomGuestWaypoint]) {
            guard pathClear(points) else { return }
            let length = polylineLength(points)
            if length < bestLength {
                bestLength = length
                best = points
            }
        }

        for hub in routeHubs {
            consider([start, hub, end])
        }
        for first in routeHubs {
            for second in routeHubs where first != second {
                consider([start, first, second, end])
            }
        }
        for first in routeHubs {
            for second in routeHubs where first != second {
                for third in routeHubs where third != second {
                    consider([start, first, second, third, end])
                }
            }
        }

        if let best { return best }
        for candidate in corridorCandidates(from: start, to: end) {
            if pathClear(candidate) { return candidate }
        }
        return [start, end]
    }

    private static func corridorCandidates(
        from start: RoomGuestWaypoint, to end: RoomGuestWaypoint
    ) -> [[RoomGuestWaypoint]] {
        [
            [start, eastLow, eastHigh, end],
            [start, eastLow, end],
            [start, eastHigh, end],
            [start, eastLow, westMid, end],
            [start, westHigh, westMid, westLow, end],
            [start, westMid, westHigh, end],
            [start, westLow, westMid, end],
            [start, eastHigh, westHigh, end],
            [start, eastLow, eastHigh, westHigh, end],
        ]
    }

    public static func point(along path: [RoomGuestWaypoint], progress: Double) -> (x: Double, z: Double) {
        guard path.count >= 2 else {
            return (path.first?.x ?? 0, path.first?.z ?? 0)
        }
        let progress = max(0, min(1, progress))
        let total = polylineLength(path)
        guard total > 0 else { return (path.last!.x, path.last!.z) }
        let target = progress * total
        var travelled = 0.0
        for index in path.indices.dropLast() {
            let start = path[index]
            let end = path[index + 1]
            let span = hypot(end.x - start.x, end.z - start.z)
            if travelled + span >= target {
                let local = span > 0 ? (target - travelled) / span : 1
                return (start.x + (end.x - start.x) * local, start.z + (end.z - start.z) * local)
            }
            travelled += span
        }
        return (path.last!.x, path.last!.z)
    }

    public static func pathClear(_ path: [RoomGuestWaypoint], stepsPerSegment: Int = 32) -> Bool {
        guard path.count >= 2 else { return true }
        for index in path.indices.dropLast() {
            if !segmentClear(from: path[index], to: path[index + 1], steps: stepsPerSegment) {
                return false
            }
        }
        return true
    }

    public static func segmentClear(
        from start: RoomGuestWaypoint, to end: RoomGuestWaypoint, steps: Int = 32
    ) -> Bool {
        guard steps > 0 else { return !RoomFurnitureLayout.overlapsFurniture(x: start.x, z: start.z) }
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let x = start.x + (end.x - start.x) * t
            let z = start.z + (end.z - start.z) * t
            if RoomFurnitureLayout.overlapsFurniture(x: x, z: z) { return false }
        }
        return true
    }

    private static func polylineLength(_ path: [RoomGuestWaypoint]) -> Double {
        guard path.count >= 2 else { return 0 }
        var total = 0.0
        for index in path.indices.dropLast() {
            let start = path[index]
            let end = path[index + 1]
            total += hypot(end.x - start.x, end.z - start.z)
        }
        return total
    }
}
