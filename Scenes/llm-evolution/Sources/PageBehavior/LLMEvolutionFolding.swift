/// Pure page-local folding rules; no host, rendering, hardware or persistence dependencies.
public struct LLMEvolutionFolding: Equatable, Sendable {
    public let desk: Double
    public let tape: Double
    public let booths: Double
    public let bridges: Double
    public let branch: Double

    public init(progress: Double) {
        let progress = Self.clamp(progress)
        desk = Self.stage(progress, start: 0, end: 0.24)
        tape = Self.stage(progress, start: 0.08, end: 0.42)
        booths = Self.stage(progress, start: 0.24, end: 0.76)
        bridges = Self.stage(progress, start: 0.38, end: 0.88)
        branch = Self.stage(progress, start: 0.52, end: 1)
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
