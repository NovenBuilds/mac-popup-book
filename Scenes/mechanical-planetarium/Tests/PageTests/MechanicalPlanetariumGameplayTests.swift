import PageBehavior
import XCTest

final class MechanicalPlanetariumGameplayTests: XCTestCase {
    func testCrankDriveOnlyWhenOpen() {
        var state = MechanicalPlanetariumGameplay()
        let closed = MechanicalPlanetariumFolding(progress: 0.2)
        state.handleTap(.stepForward, folding: closed, now: 0)
        XCTAssertEqual(state.mechanism.turns, 0)
        XCTAssertEqual(state.notice, .needOpen)

        let open = MechanicalPlanetariumFolding(progress: 1)
        state.handleTap(.stepForward, folding: open, now: 1)
        XCTAssertGreaterThan(state.mechanism.turns, 0)
    }

    func testDragUpdatesTurnsContinuously() {
        var state = MechanicalPlanetariumGameplay()
        let open = MechanicalPlanetariumFolding(progress: 1)
        state.beginCrankDrag(x: 0.4, folding: open, now: 0)
        state.updateCrankDrag(x: 0.55)
        XCTAssertGreaterThan(state.mechanism.turns, 0)
        let first = state.mechanism.turns
        state.updateCrankDrag(x: 0.45)
        XCTAssertLessThan(state.mechanism.turns, first)
        state.endCrankDrag()
        XCTAssertFalse(state.draggingCrank)
    }

    func testCancelClearsCrankDrag() {
        var state = MechanicalPlanetariumGameplay()
        let open = MechanicalPlanetariumFolding(progress: 1)
        state.beginCrankDrag(x: 0.4, folding: open, now: 0)
        XCTAssertTrue(state.draggingCrank)
        state.cancelInteraction()
        XCTAssertFalse(state.draggingCrank)
        let turnsBefore = state.mechanism.turns
        state.updateCrankDrag(x: 0.9)
        XCTAssertEqual(state.mechanism.turns, turnsBefore)
    }

    func testPauseToggle() {
        var state = MechanicalPlanetariumGameplay()
        let open = MechanicalPlanetariumFolding(progress: 1)
        XCTAssertFalse(state.isPaused)
        state.handleTap(.pauseToggle, folding: open, now: 0)
        XCTAssertTrue(state.isPaused)
        state.handleTap(.pauseToggle, folding: open, now: 1)
        XCTAssertFalse(state.isPaused)
    }

    func testObservationSnapKeepsNearestCycle() {
        var state = MechanicalPlanetariumGameplay()
        state.mechanism.turns = 2.37
        state.mechanism.snapToObservation(1)
        let fractional = state.mechanism.turns - floor(state.mechanism.turns)
        XCTAssertEqual(fractional, 0.25, accuracy: 1e-9)
    }

    func testNewMoonMoonCloserToSunThanEarth() {
        let mechanism = MechanicalPlanetariumMechanism(turns: 0)
        let earthDist = mechanism.horizontalDistanceFromSun(mechanism.earthPosition())
        let moonDist = mechanism.horizontalDistanceFromSun(mechanism.moonPosition())
        XCTAssertLessThan(moonDist, earthDist)
        XCTAssertEqual(mechanism.lunarPhaseName(zh: true), "新月")
    }

    func testFullMoonMoonFartherFromSunThanEarth() {
        let mechanism = MechanicalPlanetariumMechanism(turns: 0.5)
        let earthDist = mechanism.horizontalDistanceFromSun(mechanism.earthPosition())
        let moonDist = mechanism.horizontalDistanceFromSun(mechanism.moonPosition())
        XCTAssertGreaterThan(moonDist, earthDist)
        XCTAssertEqual(mechanism.lunarPhaseName(zh: true), "满月")
    }

    func testMoonIlluminationFacesSun() {
        var mechanism = MechanicalPlanetariumMechanism(turns: 0.12)
        for step in 0..<40 {
            mechanism.turns = Double(step) * 0.1
            let towardSun = mechanism.moonTowardSunDirection()
            let moon = mechanism.moonPosition()
            let sun = mechanism.sunPosition()
            let raw = sun - moon
            let length = (raw.x * raw.x + raw.y * raw.y + raw.z * raw.z).squareRoot()
            let expected = raw / length
            XCTAssertEqual(towardSun.x, expected.x, accuracy: 1e-6)
            XCTAssertEqual(towardSun.y, expected.y, accuracy: 1e-6)
            XCTAssertEqual(towardSun.z, expected.z, accuracy: 1e-6)
        }
    }

    func testObservationHintsAtStops() {
        var state = MechanicalPlanetariumGameplay()
        state.mechanism.turns = 0.5
        XCTAssertNotNil(state.mechanism.nearestObservationIndex())
        XCTAssertNotNil(state.observationCaption(zh: true))
        state.mechanism.turns = 0.13
        XCTAssertNil(state.mechanism.nearestObservationIndex())
    }

    func testReversePreservesAngleCoherence() {
        var state = MechanicalPlanetariumGameplay()
        let open = MechanicalPlanetariumFolding(progress: 1)
        let original = state.mechanism.moonElongation
        state.handleTap(.stepForward, folding: open, now: 0)
        state.handleTap(.stepForward, folding: open, now: 0)
        state.handleTap(.stepBack, folding: open, now: 0)
        state.handleTap(.stepBack, folding: open, now: 0)
        XCTAssertEqual(state.mechanism.moonElongation, original, accuracy: 1e-9)
    }

    func testFoldingStagesMonotonic() {
        let early = MechanicalPlanetariumFolding(progress: 0.2)
        let late = MechanicalPlanetariumFolding(progress: 0.95)
        XCTAssertLessThan(early.bodies, late.bodies)
        XCTAssertLessThan(early.orbits, late.orbits)
        XCTAssertFalse(early.canDrive)
        XCTAssertTrue(late.canDrive)
    }
}
