/// Pure page-local folding rules; no host, rendering, hardware or persistence dependencies.
public struct PocketTownFolding: Equatable, Sendable {
    public let ground: Double
    public let routes: Double
    public let houses: Double
    public let bridge: Double
    public let tower: Double
    public let stationCanopy: Double

    public init(progress: Double) {
        let progress = Self.clamp(progress)
        ground = Self.stage(progress, start: 0, end: 0.28)
        routes = Self.stage(progress, start: 0.04, end: 0.34)
        houses = Self.stage(progress, start: 0.22, end: 0.66)
        bridge = Self.stage(progress, start: 0.34, end: 0.74)
        tower = Self.stage(progress, start: 0.46, end: 0.9)
        stationCanopy = Self.stage(progress, start: 0.68, end: 1)
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
