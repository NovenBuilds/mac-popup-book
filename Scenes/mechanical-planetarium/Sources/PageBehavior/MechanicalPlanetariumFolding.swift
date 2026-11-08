/// 纯本地跨页折纸规则；不依赖宿主、渲染、硬件或持久化。
public struct MechanicalPlanetariumFolding: Equatable, Sendable {
    public let backdrop: Double
    public let basePlate: Double
    public let brackets: Double
    public let orbits: Double
    public let bodies: Double
    public let crank: Double

    public init(progress: Double) {
        let progress = Self.clamp(progress)
        backdrop = Self.stage(progress, start: 0, end: 0.35)
        basePlate = Self.stage(progress, start: 0.02, end: 0.3)
        brackets = Self.stage(progress, start: 0.12, end: 0.52)
        orbits = Self.stage(progress, start: 0.28, end: 0.76)
        bodies = Self.stage(progress, start: 0.48, end: 0.95)
        crank = Self.stage(progress, start: 0.58, end: 1)
    }

    public var canDrive: Bool { bodies >= 0.55 && crank >= 0.45 }

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
