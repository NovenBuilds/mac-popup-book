import Foundation

/// Each reveal has a small closing margin so sensor jitter cannot toggle a species.
public struct ReefVisibility: Equatable, Sendable {
    public private(set) var layer = 0
    private static let thresholds = [0.18, 0.46, 0.68, 0.93]

    public init() {}

    public mutating func advance(progress: Double) {
        while layer < Self.thresholds.count && progress >= Self.thresholds[layer] { layer += 1 }
        while layer > 0 && progress < Self.thresholds[layer - 1] - 0.035 { layer -= 1 }
    }
}

/// Centers and facing for the independently moving animals. y is height above the book.
public enum ReefWildlifeMotion {
    public static func crab(at clock: Double) -> SIMD3<Double> {
        SIMD3(-1.14 + 0.14 * sin(clock * 0.67), 0.095, 0.76)
    }

    public static func seahorse(at clock: Double) -> SIMD3<Double> {
        SIMD3(1.19 + 0.045 * sin(clock * 0.59), 0.29 + 0.055 * cos(clock * 1.25), 0.51)
    }

    public static func butterfly(at clock: Double) -> (position: SIMD3<Double>, heading: Double) {
        let phase = clock * 0.56 + 0.9
        return (
            SIMD3(1.12 + 0.25 * cos(phase), 0.60 + 0.04 * sin(phase * 2), -0.24 + 0.11 * sin(phase)),
            -atan2(0.11 * cos(phase), -0.25 * sin(phase))
        )
    }

    public static func shark(at clock: Double) -> (position: SIMD3<Double>, heading: Double) {
        let phase = clock * 0.25 + 3.9
        return (
            SIMD3(1.18 * cos(phase), 1.03 + 0.026 * sin(phase * 2), -0.79 + 0.065 * sin(phase)),
            -atan2(0.065 * cos(phase), -1.18 * sin(phase))
        )
    }
}
