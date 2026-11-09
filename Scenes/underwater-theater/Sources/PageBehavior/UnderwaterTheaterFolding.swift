/// 纯行为开合规则，不依赖主机、渲染或硬件。
public struct UnderwaterTheaterFolding: Equatable, Sendable {
    public let seabed: Double
    public let backdrop: Double
    public let rearCoral: Double
    public let coral: Double
    public let seaweed: Double
    public let fish: Double
    public let shimmer: Double

    public init(progress: Double) {
        let progress = Self.clamp(progress)
        seabed = Self.stage(progress, start: 0, end: 0.3)
        backdrop = Self.stage(progress, start: 0.07, end: 0.26)
        rearCoral = Self.stage(progress, start: 0.26, end: 0.53)
        coral = Self.stage(progress, start: 0.14, end: 0.56)
        seaweed = Self.stage(progress, start: 0.26, end: 0.72)
        fish = Self.stage(progress, start: 0.48, end: 0.86)
        shimmer = Self.stage(progress, start: 0.58, end: 1)
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
