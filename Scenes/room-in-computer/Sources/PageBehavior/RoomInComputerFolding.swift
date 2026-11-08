/// 书页开合分层：地板、墙、床桌、吊灯；不依赖宿主或渲染。
public struct RoomInComputerFolding: Equatable, Sendable {
    public let floor: Double
    public let walls: Double
    public let bed: Double
    public let desk: Double
    public let chair: Double
    public let lamp: Double

    public init(progress: Double) {
        let progress = Self.clamp(progress)
        floor = Self.stage(progress, start: 0, end: 0.26)
        walls = Self.stage(progress, start: 0.08, end: 0.38)
        bed = Self.stage(progress, start: 0.22, end: 0.58)
        desk = Self.stage(progress, start: 0.34, end: 0.72)
        chair = Self.stage(progress, start: 0.4, end: 0.78)
        lamp = Self.stage(progress, start: 0.62, end: 1)
    }

    static func stage(_ progress: Double, start: Double, end: Double) -> Double {
        let value = clamp((progress - start) / (end - start))
        return value * value * (3 - 2 * value)
    }

    static func clamp(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        guard value.isFinite else { return value.sign == .minus ? 0 : 1 }
        return min(1, max(0, value))
    }
}
