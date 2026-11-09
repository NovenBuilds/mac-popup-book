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
