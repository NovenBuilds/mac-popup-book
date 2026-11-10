import PageBehavior
import XCTest

final class UnderwaterTheaterGameplayTests: XCTestCase {
    func testSpeciesLayersHaveClosingHysteresis() {
        var reef = ReefVisibility()
        for (progress, expected) in [
            (0.17, 0), (0.18, 1), (0.50, 2), (0.70, 3), (0.92, 3),
            (0.93, 4), (0.91, 4), (0.89, 3), (0.66, 3), (0.55, 2), (0.04, 0),
        ] {
            reef.advance(progress: progress)
            XCTAssertEqual(reef.layer, expected, "展开进度 \(progress)")
        }
    }

    func testSchoolMovesAtFixedFullOpening() {
        var state = UnderwaterTheaterGameplay()
        let folding = UnderwaterTheaterFolding(progress: 0.96)
        let start = state.fishProgress
        state.advance(bookProgress: 0.96, clock: 1, deltaTime: 1, folding: folding)
        XCTAssertNotEqual(state.fishProgress, start)
    }

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
        XCTAssertEqual(
            state.tapTarget(at: UnderwaterTheaterTracks.TapCurrent.shellLedge.sceneHint), .shellLedge)
    }

    func testTrackHeadingUsesPositiveXAsForward() {
        let east = TheaterTrackSampler(points: [TheaterPoint(0, 0), TheaterPoint(1, 0)])
        let forward = TheaterTrackSampler(points: [TheaterPoint(0, 0), TheaterPoint(0, 1)])
        XCTAssertEqual(east.sample(0.5).heading, 0, accuracy: 0.0001)
        XCTAssertEqual(forward.sample(0.5).heading, .pi / 2, accuracy: 0.0001)
    }

    func testPatrolLoopClosesInFrontOfCoral() {
        let track = TheaterTrackSampler(points: UnderwaterTheaterTracks.patrolLoop)
        XCTAssertEqual(track.points.first, track.points.last)
        XCTAssertGreaterThan(track.totalLength, 1.8)
        for point in track.points {
            XCTAssertGreaterThan(point.y, UnderwaterTheaterSteering.minBoundsY)
            XCTAssertLessThan(point.y, UnderwaterTheaterSteering.maxBoundsY)
        }
    }

    func testOppositeFlowsSteerDifferentDirections() {
        let open = UnderwaterTheaterFolding(progress: 1)
        var west = UnderwaterTheaterGameplay()
        var east = UnderwaterTheaterGameplay()
        west.fishProgress = 0.28
        east.fishProgress = 0.28

        west.beginDrag(at: TheaterPoint(-0.930, 0.65), folding: open, now: 0)
        east.beginDrag(at: TheaterPoint(0.868, 0.65), folding: open, now: 0)
        for step in 0..<30 {
            let time = Double(step) * 0.1
            west.fishProgress = 0.28
            east.fishProgress = 0.28
            west.moveDrag(to: TheaterPoint(-0.930, 0.65), folding: open)
            east.moveDrag(to: TheaterPoint(0.868, 0.65), folding: open)
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
        state.beginDrag(at: TheaterPoint(0.868, 0.65), folding: open, now: 0)
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

    func testWholeSchoolClearsCoralAndPageEvenWhenSteeredAtTheLaneEdges() {
        let track = TheaterTrackSampler(points: UnderwaterTheaterTracks.patrolLoop)
        let fishRadius = 0.155
        for sample in 0...180 {
            let anchor = track.sample(Double(sample) / 180).position
            for direction in 0..<24 {
                let heading = Double(direction) * .pi / 12
                let force = TheaterPoint(cos(heading), sin(heading))
                let school = anchor + UnderwaterTheaterSteering.constrain(pathAnchor: anchor, offset: force)
                for index in 0..<6 {
                    let fish =
                        school + UnderwaterTheaterSteering.formationOffset(index: index, heading: heading)
                    // Full tail and nose clear the front faces of the arch and grass at z = 0.13.
                    XCTAssertGreaterThan(fish.y - fishRadius, 0.13)
                    XCTAssertLessThan(fish.y + fishRadius, 1.17)
                    XCTAssertLessThan(abs(fish.x) + fishRadius, 1.15)
                    XCTAssertGreaterThan(
                        UnderwaterTheaterSteering.formationHeight(index: index, flutter: -1) - 0.082, 0.30)
                }
            }
        }
    }

    func testIndependentWildlifeLanesClearReefAndOtherAnimals() {
        for tick in 0...1600 {
            let clock = Double(tick) * 0.06
            let crab = ReefWildlifeMotion.crab(at: clock)
            let seahorse = ReefWildlifeMotion.seahorse(at: clock)
            let butterfly = ReefWildlifeMotion.butterfly(at: clock).position
            let sharkPose = ReefWildlifeMotion.shark(at: clock)
            let shark = sharkPose.position
            // Floor crab clears the ground, the star behind it, and the fish above it.
            XCTAssertGreaterThan(crab.y - 0.092, 0)
            XCTAssertLessThan(crab.z + 0.06, 1.01 - 0.135)
            XCTAssertLessThan(crab.y + 0.20, 0.30)
            // Seahorse clears the shell and the front school; butterfly has its own midwater lane.
            XCTAssertGreaterThan(seahorse.z - 0.05, UnderwaterTheaterTracks.shell.y + 0.13)
            XCTAssertGreaterThan(seahorse.x - 0.16, 0.93)
            XCTAssertLessThan(butterfly.z + 0.20, 0.13)
            XCTAssertGreaterThan(butterfly.y - 0.12, 0.43)
            // Include the lower shark fin above the highest paper skyline and arch.
            XCTAssertGreaterThan(shark.y - 0.16, 0.84)
            let tailReach = 0.39 * abs(sin(sharkPose.heading)) + 0.075 * abs(cos(sharkPose.heading))
            XCTAssertGreaterThan(shark.z - tailReach, -1.125)
        }
    }
}
