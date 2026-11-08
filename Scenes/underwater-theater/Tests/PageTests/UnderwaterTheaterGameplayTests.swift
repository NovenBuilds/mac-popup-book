import PageBehavior
import XCTest

final class UnderwaterTheaterGameplayTests: XCTestCase {
    func testPresetCurrentWhenOpen() {
        var state = UnderwaterTheaterGameplay()
        let open = UnderwaterTheaterFolding(progress: 1)
        state.handleTap(.archRise, folding: open, now: 0)
        XCTAssertEqual(state.flowStrength, 1)
        XCTAssertEqual(state.notice, .archCurrent)
        XCTAssertEqual(state.flowPoint, UnderwaterTheaterTracks.TapCurrent.archRise.sceneHint)
    }

    func testInteractionBlockedWhenFolded() {
        var state = UnderwaterTheaterGameplay()
        let closed = UnderwaterTheaterFolding(progress: 0.15)
        state.beginDrag(at: TheaterPoint(0.000, 0.043), folding: closed, now: 0)
        XCTAssertFalse(state.dragging)
        XCTAssertEqual(state.notice, .needOpen)
    }

    func testFlowDecaysAfterRelease() {
        var state = UnderwaterTheaterGameplay()
        let open = UnderwaterTheaterFolding(progress: 1)
        state.beginDrag(at: TheaterPoint(-0.248, 0.000), folding: open, now: 0)
        state.endDrag(now: 0.2)
        XCTAssertFalse(state.dragging)
        state.advance(bookProgress: 1, clock: 0.3, deltaTime: 0.8, folding: open)
        XCTAssertLessThan(state.flowStrength, 0.2)
    }

    func testDragKeepsFlowStrength() {
        var state = UnderwaterTheaterGameplay()
        let open = UnderwaterTheaterFolding(progress: 1)
        state.beginDrag(at: TheaterPoint(0.000, 0.043), folding: open, now: 0)
        state.moveDrag(to: TheaterPoint(0.155, 0.086), folding: open)
        state.advance(bookProgress: 1, clock: 0.1, deltaTime: 0.5, folding: open)
        XCTAssertEqual(state.flowStrength, 1)
    }

    func testFishAdvancesWhenGuided() {
        var state = UnderwaterTheaterGameplay()
        let open = UnderwaterTheaterFolding(progress: 1)
        state.handleTap(.archRise, folding: open, now: 0)
        state.advance(bookProgress: 1, clock: 0.2, deltaTime: 4, folding: open)
        XCTAssertGreaterThan(state.fishProgress, 0.05)
    }

    func testFoldRetreatsFish() {
        var state = UnderwaterTheaterGameplay()
        let open = UnderwaterTheaterFolding(progress: 1)
        state.advance(bookProgress: 1, clock: 0, deltaTime: 10, folding: open)
        let before = state.fishProgress
        XCTAssertGreaterThan(before, 0.02)
        state.advance(
            bookProgress: UnderwaterTheaterGameplay.foldedResetProgress - 0.05, clock: 1, deltaTime: 2,
            folding: open)
        XCTAssertLessThan(state.fishProgress, before)
    }

    func testTapTargetsCoverThreeAlternatives() {
        let state = UnderwaterTheaterGameplay()
        XCTAssertEqual(state.tapTarget(at: TheaterPoint(-0.72, 0.18)), .westSeaweed)
        XCTAssertEqual(state.tapTarget(at: TheaterPoint(0.02, 0.32)), .archRise)
        XCTAssertEqual(state.tapTarget(at: TheaterPoint(0.72, 0.06)), .shellLedge)
    }

    func testTrackHeadingUsesPositiveXAsForward() {
        let east = TheaterTrackSampler(points: [TheaterPoint(0, 0), TheaterPoint(1, 0)])
        let forward = TheaterTrackSampler(points: [TheaterPoint(0, 0), TheaterPoint(0, 1)])
        XCTAssertEqual(east.sample(0.5).heading, 0, accuracy: 0.0001)
        XCTAssertEqual(forward.sample(0.5).heading, .pi / 2, accuracy: 0.0001)
    }

    func testPatrolLoopHasArchPoint() {
        XCTAssertTrue(UnderwaterTheaterTracks.patrolLoop.contains(UnderwaterTheaterTracks.archCenter))
        XCTAssertGreaterThan(
            TheaterTrackSampler(points: UnderwaterTheaterTracks.patrolLoop).totalLength, 2.5)
    }

    func testOppositeFlowsSteerDifferentDirections() {
        let open = UnderwaterTheaterFolding(progress: 1)
        var west = UnderwaterTheaterGameplay()
        var east = UnderwaterTheaterGameplay()
        west.fishProgress = 0.28
        east.fishProgress = 0.28

        west.beginDrag(at: TheaterPoint(-0.930, -0.086), folding: open, now: 0)
        east.beginDrag(at: TheaterPoint(0.868, -0.043), folding: open, now: 0)
        for step in 0..<30 {
            let time = Double(step) * 0.1
            west.fishProgress = 0.28
            east.fishProgress = 0.28
            west.moveDrag(to: TheaterPoint(-0.930, -0.086), folding: open)
            east.moveDrag(to: TheaterPoint(0.868, -0.043), folding: open)
            west.advance(bookProgress: 1, clock: time, deltaTime: 0.1, folding: open)
            east.advance(bookProgress: 1, clock: time, deltaTime: 0.1, folding: open)
        }

        XCTAssertLessThan(west.fishOffset.x, -0.03)
        XCTAssertGreaterThan(east.fishOffset.x, 0.03)
        XCTAssertLessThan(west.fishOffset.x, east.fishOffset.x - 0.06)
    }

    func testOffsetRelaxesTowardPatrolAfterFlowEnds() {
        var state = UnderwaterTheaterGameplay()
        let open = UnderwaterTheaterFolding(progress: 1)
        state.fishProgress = 0.32
        state.beginDrag(at: TheaterPoint(0.868, -0.043), folding: open, now: 0)
        state.advance(bookProgress: 1, clock: 0.2, deltaTime: 1.2, folding: open)
        let peaked = state.fishOffset
        XCTAssertGreaterThan(hypot(peaked.x, peaked.y), 0.04)

        state.endDrag(now: 0.5)
        for step in 0..<40 {
            state.advance(bookProgress: 1, clock: 1 + Double(step) * 0.1, deltaTime: 0.1, folding: open)
        }
        let mag = hypot(state.fishOffset.x, state.fishOffset.y)
        XCTAssertLessThan(mag, hypot(peaked.x, peaked.y) * 0.35)
        XCTAssertLessThan(mag, 0.03)
    }

    func testSteeredSchoolAvoidsCoralAndPageEdge() {
        var state = UnderwaterTheaterGameplay()
        let open = UnderwaterTheaterFolding(progress: 1)
        state.fishProgress = 0.2
        state.beginDrag(at: TheaterPoint(-1.178, -0.387), folding: open, now: 0)
        state.advance(bookProgress: 1, clock: 0, deltaTime: 2.5, folding: open)
        let center = state.schoolCenter().position
        XCTAssertGreaterThanOrEqual(center.x, UnderwaterTheaterSteering.minBoundsX)
        XCTAssertLessThanOrEqual(center.x, UnderwaterTheaterSteering.maxBoundsX)
        XCTAssertGreaterThanOrEqual(center.y, UnderwaterTheaterSteering.minBoundsY)
        XCTAssertLessThanOrEqual(center.y, UnderwaterTheaterSteering.maxBoundsY)
        for obstacle in UnderwaterTheaterSteering.coralObstacles {
            let dx = center.x - obstacle.center.x
            let dy = center.y - obstacle.center.y
            XCTAssertGreaterThanOrEqual(dx * dx + dy * dy, obstacle.radius * obstacle.radius)
        }
    }
}
