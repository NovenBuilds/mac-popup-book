import PageBehavior
import XCTest

final class PocketTownGameplayTests: XCTestCase {
    func testToggleRouteAtStation() {
        var state = PocketTownGameplay()
        let folding = PocketTownFolding(progress: 1)
        state.handleTap(.switchRail, folding: folding, now: 0)
        XCTAssertEqual(state.selectedRoute, .clockTower)
        state.handleTap(.switchRail, folding: folding, now: 1)
        XCTAssertEqual(state.selectedRoute, .riverside)
    }

    func testDispatchOnlyWhenOpen() {
        var state = PocketTownGameplay()
        let closed = PocketTownFolding(progress: 0.2)
        state.handleTap(.station, folding: closed, now: 0)
        XCTAssertEqual(state.train, .atStation)
        XCTAssertEqual(state.notice, .needOpen)

        let open = PocketTownFolding(progress: 1)
        state.handleTap(.station, folding: open, now: 1)
        XCTAssertEqual(state.train, .running(progress: 0))
        XCTAssertEqual(state.tripRoute, .riverside)
    }

    func testNoSecondTrainWhileRunning() {
        var state = PocketTownGameplay(selectedRoute: .clockTower)
        let folding = PocketTownFolding(progress: 1)
        state.handleTap(.station, folding: folding, now: 0)
        state.handleTap(.station, folding: folding, now: 0.5)
        XCTAssertTrue(state.trainIsRunning)
        XCTAssertEqual(state.notice, .trainBusy)
    }

    func testSwitchBlockedNearJunction() {
        var state = PocketTownGameplay()
        let folding = PocketTownFolding(progress: 1)
        state.handleTap(.station, folding: folding, now: 0)
        state.train = .running(progress: 0.14)
        state.handleTap(.switchRail, folding: folding, now: 0)
        XCTAssertEqual(state.selectedRoute, .riverside)
        XCTAssertEqual(state.notice, .switchBlocked)
    }

    func testRunningTripKeepsSamplerWhenNextRouteChanges() {
        var state = PocketTownGameplay(selectedRoute: .riverside)
        let folding = PocketTownFolding(progress: 1)
        state.handleTap(.station, folding: folding, now: 0)
        state.advance(bookProgress: 1, clock: 0.5, deltaTime: 6, folding: folding)
        XCTAssertTrue(state.trainIsRunning)
        XCTAssertGreaterThan(state.routeProgress, 0.2)

        let before = state.sampler().sample(state.routeProgress).position
        state.handleTap(.switchRail, folding: folding, now: 1)
        XCTAssertEqual(state.selectedRoute, .clockTower)
        XCTAssertEqual(state.tripRoute, .riverside)

        let after = state.sampler().sample(state.routeProgress).position
        XCTAssertEqual(before, after)
        XCTAssertTrue(state.caption(zh: true).contains("河岸线"))
    }

    func testCompletesLoopAndAllowsRedispatch() {
        var state = PocketTownGameplay()
        let folding = PocketTownFolding(progress: 1)
        state.handleTap(.station, folding: folding, now: 0)
        state.advance(
            bookProgress: 1, clock: 1, deltaTime: PocketTownGameplay.loopDuration + 1, folding: folding)
        XCTAssertEqual(state.train, .atStation)
        XCTAssertNil(state.tripRoute)
        state.handleTap(.station, folding: folding, now: 2)
        XCTAssertEqual(state.train, .running(progress: 0))
    }

    func testFoldResetSnapsTrainToStation() {
        var state = PocketTownGameplay(selectedRoute: .clockTower)
        let open = PocketTownFolding(progress: 1)
        state.handleTap(.station, folding: open, now: 0)
        state.train = .running(progress: 0.3)
        state.advance(
            bookProgress: PocketTownGameplay.foldedResetProgress - 0.05, clock: 0.1, deltaTime: 0.05,
            folding: open)
        XCTAssertEqual(state.train, .atStation)
        XCTAssertNil(state.tripRoute)
        XCTAssertEqual(state.routeProgress, 0)
    }

    func testSlowFoldAcrossThresholdResetsWithoutSuddenReopen() {
        var state = PocketTownGameplay()
        let open = PocketTownFolding(progress: 1)
        state.handleTap(.station, folding: open, now: 0)
        state.advance(bookProgress: 0.8, clock: 0, deltaTime: 3, folding: open)
        XCTAssertTrue(state.trainIsRunning)

        for (index, progress) in stride(from: 0.75, through: 0.18, by: -0.03).enumerated() {
            state.advance(
                bookProgress: progress, clock: Double(index) * 0.1, deltaTime: 0.1, folding: open)
        }
        XCTAssertEqual(state.train, .atStation)
        XCTAssertNil(state.tripRoute)

        state.advance(bookProgress: 0.95, clock: 2, deltaTime: 0.1, folding: open)
        XCTAssertEqual(state.train, .atStation)
        XCTAssertEqual(state.routeProgress, 0)
    }

    func testTracksMatchTwoDistinctLoops() {
        XCTAssertNotEqual(PocketTownTracks.riversideLoop, PocketTownTracks.clockLoop)
        XCTAssertGreaterThan(
            PocketTownTrackSampler(points: PocketTownTracks.fullPath(route: .riverside)).totalLength, 3)
        XCTAssertGreaterThan(
            PocketTownTrackSampler(points: PocketTownTracks.fullPath(route: .clockTower)).totalLength, 3)
    }

    func testLoopLinksMatchFullPathEnds() {
        for route in [PocketTownRoute.riverside, .clockTower] {
            let path = PocketTownTracks.fullPath(route: route)
            let links = PocketTownTracks.loopLinks(route: route)
            XCTAssertEqual(path[PocketTownTracks.approachSpine.count - 1], links[0])
            XCTAssertEqual(path[PocketTownTracks.approachSpine.count], links[1])
            XCTAssertEqual(path.last, links[2])
        }
    }
}
