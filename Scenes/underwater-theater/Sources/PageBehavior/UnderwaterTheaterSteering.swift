import Foundation

/// 水流可以带动整队偏移。中心活动范围为队形、尾鳍和转向留出了净空。
public enum UnderwaterTheaterSteering {
    public static let maxOffsetRadius = 0.36
    public static let steerRate = 3.4
    public static let returnRate = 2.6

    public static let minBoundsX = -0.65
    public static let maxBoundsX = 0.48
    public static let minBoundsY = 0.61
    public static let maxBoundsY = 0.70

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
        let distance = hypot(offset.x, offset.y)
        let world = pathAnchor + offset * (distance > maxOffsetRadius ? maxOffsetRadius / distance : 1)
        let inLane = TheaterPoint(
            min(maxBoundsX, max(minBoundsX, world.x)),
            min(maxBoundsY, max(minBoundsY, world.y)))
        return inLane - pathAnchor
    }

    public static func clampToPage(_ point: TheaterPoint) -> TheaterPoint {
        TheaterPoint(min(1.12, max(-1.12, point.x)), min(0.82, max(-0.52, point.y)))
    }

    public static func formationOffset(index: Int, heading: Double) -> TheaterPoint {
        let side = Double(index % 3 - 1) * 0.12
        let lag = Double(index / 3) * -0.28
        return TheaterPoint(
            -sin(heading) * side + cos(heading) * lag,
            cos(heading) * side + sin(heading) * lag)
    }

    public static func formationHeight(index: Int, flutter: Double) -> Double {
        0.43 + Double(index % 3) * 0.11 + flutter * 0.018
    }
}
