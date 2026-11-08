import Foundation

/// 鱼群相对安全巡游路径的横向/纵深偏移；与场景珊瑚、页边几何对齐。
public enum UnderwaterTheaterSteering: Equatable, Sendable {
    public struct CoralObstacle: Equatable, Sendable {
        public var center: TheaterPoint
        public var radius: Double
    }

    public static let maxOffsetRadius = 0.36
    public static let steerRate = 3.4
    public static let returnRate = 2.6
    public static let minBoundsX = -1.12
    public static let maxBoundsX = 1.12
    public static let minBoundsY = -0.52
    public static let maxBoundsY = 0.4

    public static let coralObstacles: [CoralObstacle] = [
        CoralObstacle(center: TheaterPoint(-0.26, 0.1), radius: 0.21),
        CoralObstacle(center: TheaterPoint(0.3, 0.08), radius: 0.19),
        CoralObstacle(center: TheaterPoint(-0.35, -0.06), radius: 0.17),
    ]

    public static func targetOffset(
        pathAnchor: TheaterPoint, flowScene: TheaterPoint, flowStrength: Double
    ) -> TheaterPoint {
        let strength = UnderwaterTheaterGameplay.clamp(flowStrength)
        guard strength > 0.001 else { return TheaterPoint(0, 0) }
        let delta = flowScene - pathAnchor
        let distSq = delta.x * delta.x + delta.y * delta.y
        guard distSq > 0.0001 else { return TheaterPoint(0, 0) }
        let dist = distSq.squareRoot()
        let pull = min(maxOffsetRadius * strength, dist * 0.62)
        return TheaterPoint(delta.x / dist * pull, delta.y / dist * pull)
    }

    public static func integrate(
        current: TheaterPoint, target: TheaterPoint, deltaTime: Double,
        flowStrength: Double, dragging: Bool
    ) -> TheaterPoint {
        let delta = max(0, deltaTime)
        let active = flowStrength > 0.04
        let rate = active ? steerRate * (dragging ? 1.15 : 0.9) : returnRate
        let step = min(1, rate * delta)
        return TheaterPoint(
            current.x + (target.x - current.x) * step,
            current.y + (target.y - current.y) * step)
    }

    public static func constrain(pathAnchor: TheaterPoint, offset: TheaterPoint) -> TheaterPoint {
        var world = pathAnchor + offset
        world = clampToPage(world)

        for obstacle in coralObstacles {
            world = pushOutside(world, obstacle: obstacle)
        }

        var adjusted = world - pathAnchor
        let magSq = adjusted.x * adjusted.x + adjusted.y * adjusted.y
        let maxSq = maxOffsetRadius * maxOffsetRadius
        if magSq > maxSq, magSq > 0.0001 {
            let scale = maxOffsetRadius / magSq.squareRoot()
            adjusted = adjusted * scale
            world = pathAnchor + adjusted
            world = clampToPage(world)
            for obstacle in coralObstacles {
                world = pushOutside(world, obstacle: obstacle)
            }
            adjusted = world - pathAnchor
        }
        return adjusted
    }

    public static func clampToPage(_ point: TheaterPoint) -> TheaterPoint {
        TheaterPoint(
            min(maxBoundsX, max(minBoundsX, point.x)),
            min(maxBoundsY, max(minBoundsY, point.y)))
    }

    private static func pushOutside(_ point: TheaterPoint, obstacle: CoralObstacle) -> TheaterPoint {
        let dx = point.x - obstacle.center.x
        let dy = point.y - obstacle.center.y
        let distSq = dx * dx + dy * dy
        let minDist = obstacle.radius + 0.05
        guard distSq < minDist * minDist else { return point }
        if distSq < 0.00001 {
            return TheaterPoint(obstacle.center.x + minDist, obstacle.center.y)
        }
        let dist = distSq.squareRoot()
        let scale = minDist / dist
        return TheaterPoint(obstacle.center.x + dx * scale, obstacle.center.y + dy * scale)
    }
}
