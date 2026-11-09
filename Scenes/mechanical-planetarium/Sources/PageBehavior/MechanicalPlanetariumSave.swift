import Foundation

public struct MechanicalPlanetariumSave: Codable, Equatable, Sendable {
    public static let version = 1
    private let version: Int
    public let turns: Double
    public let paused: Bool

    public init(gameplay: MechanicalPlanetariumGameplay) {
        version = Self.version
        turns = gameplay.mechanism.turns
        paused = gameplay.isPaused
    }

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }

    public static func restore(state: Data?, backup: Data?) -> (
        gameplay: MechanicalPlanetariumGameplay, canSave: Bool
    ) {
        let decoder = JSONDecoder()
        var gameplay = MechanicalPlanetariumGameplay()
        var canSave = true
        for data in [state, backup].compactMap({ $0 }) {
            guard let saved = try? decoder.decode(Self.self, from: data) else {
                canSave = false
                continue
            }
            if saved.version != Self.version {
                canSave = false
                continue
            }
            guard saved.turns.isFinite, abs(saved.turns) < 1_000_000 else {
                canSave = false
                continue
            }
            gameplay.mechanism = MechanicalPlanetariumMechanism(turns: saved.turns)
            gameplay.isPaused = saved.paused
            return (gameplay, canSave)
        }
        return (gameplay, canSave)
    }
}
