import PageBehavior
import XCTest

final class MechanicalPlanetariumSaveTests: XCTestCase {
    func testRestoresFractionalTurnsAndPauseAfterLeavingThePage() throws {
        var gameplay = MechanicalPlanetariumGameplay()
        gameplay.mechanism.turns = -3.25
        gameplay.isPaused = true
        let data = try XCTUnwrap(MechanicalPlanetariumSave(gameplay: gameplay).encoded())
        let restored = MechanicalPlanetariumSave.restore(state: data, backup: nil)
        XCTAssertEqual(restored.gameplay.mechanism.turns, -3.25)
        XCTAssertTrue(restored.gameplay.isPaused)
        XCTAssertTrue(restored.canSave)
    }

    func testNewerStateIsProtectedWhenUsingBackup() throws {
        let newer = Data(#"{"version":2,"turns":8,"paused":true}"#.utf8)
        var gameplay = MechanicalPlanetariumGameplay()
        gameplay.mechanism.turns = 1.5
        let backup = try XCTUnwrap(MechanicalPlanetariumSave(gameplay: gameplay).encoded())
        let restored = MechanicalPlanetariumSave.restore(state: newer, backup: backup)
        XCTAssertEqual(restored.gameplay.mechanism.turns, 1.5)
        XCTAssertFalse(restored.canSave)
    }

    func testIlluminatedFractionMatchesObservationStops() {
        XCTAssertEqual(MechanicalPlanetariumMechanism(turns: 0).illuminatedFraction, 0, accuracy: 1e-9)
        XCTAssertEqual(MechanicalPlanetariumMechanism(turns: 0.25).illuminatedFraction, 0.5, accuracy: 1e-9)
        XCTAssertEqual(MechanicalPlanetariumMechanism(turns: 0.5).illuminatedFraction, 1, accuracy: 1e-9)
    }
}
