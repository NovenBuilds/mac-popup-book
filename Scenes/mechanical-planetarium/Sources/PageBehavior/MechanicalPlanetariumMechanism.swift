import Foundation

/// 压缩比例的太阳—地—月示意；纯几何，供行为测试与渲染共用。
public struct MechanicalPlanetariumMechanism: Equatable, Sendable {
    public var turns: Double

    public static let earthOrbitPerTurn = 0.045
    public static let moonCyclePerTurn = 1.0
    public static let earthSpinPerTurn = 2.2

    public static let earthOrbitRadius = 0.64
    public static let moonOrbitRadius = 0.15

    /// 曲柄一圈对应三个月相停靠（新月、上弦、满月）。
    public static let observationTurnOffsets: [Double] = [0, 0.25, 0.5]

    public init(turns: Double = 0) {
        self.turns = turns.isFinite ? turns : 0
    }

    public var moonElongation: Double { turns * Self.moonCyclePerTurn * 2 * .pi }

    public var illuminatedFraction: Double { (1 - cos(moonElongation)) / 2 }

    public var earthOrbitAngle: Double { turns * Self.earthOrbitPerTurn * 2 * .pi }

    public var earthSpinAngle: Double { turns * Self.earthSpinPerTurn * 2 * .pi }

    public var crankAngle: Double { turns * 2 * .pi }

    public func sunPosition() -> SIMD3<Double> { SIMD3(0, 0.36, 0) }

    public func earthPosition() -> SIMD3<Double> {
        let angle = earthOrbitAngle
        return SIMD3(
            Self.earthOrbitRadius * cos(angle), 0.36, Self.earthOrbitRadius * sin(angle))
    }

    public func moonPosition() -> SIMD3<Double> {
        let earth = earthPosition()
        // 相位零点：elongation=0 时月球在地球朝向太阳一侧（新月），与 lunarPhaseName 一致。
        let angle = earthOrbitAngle + moonElongation + .pi
        return earth
            + SIMD3(Self.moonOrbitRadius * cos(angle), 0, Self.moonOrbitRadius * sin(angle))
    }

    /// 太阳在原点平面上的水平距离，供月相几何测试。
    public func horizontalDistanceFromSun(_ position: SIMD3<Double>) -> Double {
        (position.x * position.x + position.z * position.z).squareRoot()
    }

    /// 月球受光面朝太阳方向；返回单位向量。
    public func moonTowardSunDirection() -> SIMD3<Double> {
        let delta = sunPosition() - moonPosition()
        let length = (delta.x * delta.x + delta.y * delta.y + delta.z * delta.z).squareRoot()
        guard length > 1e-9 else { return SIMD3(1, 0, 0) }
        return delta / length
    }

    public func lunarPhaseName(zh: Bool) -> String {
        let wrapped = moonElongation.truncatingRemainder(dividingBy: 2 * .pi)
        let phase = wrapped < 0 ? wrapped + 2 * .pi : wrapped
        switch phase {
        case ..<(.pi / 8), (15 * .pi / 8)...:
            return zh ? "新月" : "New moon"
        case (.pi / 8)..<(3 * .pi / 8):
            return zh ? "蛾眉月" : "Waxing crescent"
        case (3 * .pi / 8)..<(5 * .pi / 8):
            return zh ? "上弦月" : "First quarter"
        case (5 * .pi / 8)..<(7 * .pi / 8):
            return zh ? "盈凸月" : "Waxing gibbous"
        case (7 * .pi / 8)..<(9 * .pi / 8):
            return zh ? "满月" : "Full moon"
        case (9 * .pi / 8)..<(11 * .pi / 8):
            return zh ? "亏凸月" : "Waning gibbous"
        case (11 * .pi / 8)..<(13 * .pi / 8):
            return zh ? "下弦月" : "Last quarter"
        default:
            return zh ? "残月" : "Waning crescent"
        }
    }

    public func nearestObservationIndex(tolerance: Double = 0.04) -> Int? {
        let fractional = turns - floor(turns)
        for (index, offset) in Self.observationTurnOffsets.enumerated() {
            let delta = abs(fractional - offset)
            let wrapped = min(delta, 1 - delta)
            if wrapped <= tolerance { return index }
        }
        return nil
    }

    public mutating func snapToObservation(_ index: Int) {
        guard Self.observationTurnOffsets.indices.contains(index) else { return }
        let offset = Self.observationTurnOffsets[index]
        let base = floor(turns)
        let candidates = [base + offset, base - 1 + offset, base + 1 + offset]
        if let nearest = candidates.min(by: { abs($0 - turns) < abs($1 - turns) }) {
            turns = nearest
        }
    }
}
