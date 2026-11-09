import PageBehavior
import XCTest

final class MechanicalPlanetariumGameplayTests: XCTestCase {
    func testAutomaticDriveYieldsToCrankAndPauseAndKeepsPhaseWhenFolded() {
        var state = MechanicalPlanetariumGameplay()
        func tick(_ progress: Double) {
            state.advance(
                clock: 0, deltaTime: 0.05, folding: MechanicalPlanetariumFolding(progress: progress))
        }
        tick(0.50)
        XCTAssertEqual(state.mechanism.turns, 0)
        tick(0.92)
        XCTAssertEqual(state.mechanism.turns, 0)
        tick(0.96)
        let phase = state.mechanism.turns
        XCTAssertGreaterThan(phase, 0)
        tick(0.91)
        XCTAssertGreaterThan(state.mechanism.turns, phase)
        let open = MechanicalPlanetariumFolding(progress: 1)
        state.beginCrankDrag(x: 0.4, folding: open, now: 0)
        state.updateCrankDrag(x: 0.6)
        let manuallySet = state.mechanism.turns
        tick(1)
        XCTAssertEqual(state.mechanism.turns, manuallySet)
        state.endCrankDrag()
        tick(1)
        XCTAssertGreaterThan(state.mechanism.turns, manuallySet)
        let beforeFold = state.mechanism.turns
        tick(0.50)
        XCTAssertEqual(state.mechanism.turns, beforeFold)
        tick(1)
        XCTAssertEqual(state.mechanism.turns, beforeFold + 0.05 / 18, accuracy: 1e-9)
        state.handleTap(.pauseToggle, folding: open, now: 0)
        let paused = state.mechanism.turns
        tick(0.1)
        tick(1)
        XCTAssertTrue(state.isPaused)
        XCTAssertEqual(state.mechanism.turns, paused)
    }

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

    func testPausedBlocksManualDrive() {
        var state = MechanicalPlanetariumGameplay()
        let open = MechanicalPlanetariumFolding(progress: 1)
        state.handleTap(.pauseToggle, folding: open, now: 0)
        let turns = state.mechanism.turns
        state.handleTap(.stepForward, folding: open, now: 1)
        XCTAssertEqual(state.mechanism.turns, turns)
        XCTAssertEqual(state.notice, .driveWhilePaused)
        state.beginCrankDrag(x: 0.4, folding: open, now: 2)
        XCTAssertFalse(state.draggingCrank)
    }

    func testObservationSnapEntersPause() {
        var state = MechanicalPlanetariumGameplay()
        let open = MechanicalPlanetariumFolding(progress: 1)
        state.handleTap(.stepForward, folding: open, now: 0)
        state.handleTap(.observeFullMoon, folding: open, now: 0)
        XCTAssertTrue(state.isPaused)
        XCTAssertEqual(state.mechanism.turns - floor(state.mechanism.turns), 0.5, accuracy: 1e-9)
        let held = state.mechanism.turns
        state.handleTap(.stepForward, folding: open, now: 1)
        XCTAssertEqual(state.mechanism.turns, held)
    }

    func testPresentationActionsReflectPause() {
        var state = MechanicalPlanetariumGameplay()
        let open = MechanicalPlanetariumFolding(progress: 1)
        state.advance(clock: 0, deltaTime: 0, folding: open)
        var actions = state.presentationActions(zh: true)
        XCTAssertTrue(actions[0].enabled)
        XCTAssertTrue(actions[1].enabled)
        XCTAssertEqual(actions[2].title, "暂停")
        state.handleTap(.pauseToggle, folding: open, now: 0)
        actions = state.presentationActions(zh: true)
        XCTAssertFalse(actions[0].enabled)
        XCTAssertFalse(actions[1].enabled)
        XCTAssertEqual(actions[2].title, "恢复")
    }

    func testHandleActionMatchesTapTargets() {
        var state = MechanicalPlanetariumGameplay()
        let open = MechanicalPlanetariumFolding(progress: 1)
        state.handleAction(MechanicalPlanetariumAction.stepForward, folding: open, now: 0)
        XCTAssertGreaterThan(state.mechanism.turns, 0)
        state.handleAction(MechanicalPlanetariumAction.pauseToggle, folding: open, now: 1)
        XCTAssertTrue(state.isPaused)
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
