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
        let track = state.sampler()
        let distance = PocketTownTrackSampler(points: PocketTownTracks.approachSpine).totalLength
        state.train = .running(progress: distance / track.totalLength)
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

    func testBothRoutesLeaveAndReturnAlongTheSameStationTrack() {
        for route in [PocketTownRoute.riverside, .clockTower] {
            let sampler = PocketTownTrackSampler(points: PocketTownTracks.fullPath(route: route))
            XCTAssertEqual(sampler.sample(0).position, PocketTownTracks.station)
            XCTAssertEqual(sampler.sample(1).position.x, PocketTownTracks.station.x, accuracy: 0.000001)
            XCTAssertEqual(sampler.sample(0).heading, sampler.sample(1).heading, accuracy: 0.000001)
        }
    }

    func testWholeLocomotiveClearsBothRoutesFrom72Through107Degrees() {
        typealias Obstacle = (name: String, x: Double, z: Double, halfWidth: Double, halfDepth: Double)
        let fixed: [Obstacle] = [
            ("station", PocketTownTracks.stationWall.x, PocketTownTracks.stationWall.y, 0.27, 0.078),
            ("platform", -1.08, -0.72, 0.33, 0.0525),
            ("canopy supports", -1.10, -0.793, 0.26, 0.013),
            ("clock tower", -0.31, 0.39, 0.23, 0.16),
            ("red house", 0.38, 0.43, 0.18, 0.09),
            ("blue house", 0.81, 0.43, 0.17, 0.09),
            ("tan house", 1.16, 0.45, 0.16, 0.09),
            ("switch", 0.06, -0.20, 0.13, 0.115),
            ("river flag", -0.45, -0.29, 0.13, 0.055),
            ("west tree", -1.14, 0.24, 0.084, 0.084),
            ("southwest tree", -0.91, 0.56, 0.056, 0.056),
            ("northeast tree", 1.77, -0.69, 0.064, 0.064),
            ("southeast tree", 1.77, 0.61, 0.066, 0.066),
        ]
        // Conservative body envelope in the train's local axes, including wheels and headlight.
        let halfWidth = 0.068
        let halfLength = 0.130
        let trainTop = 0.048 + 0.145
        for degree in 72...107 {
            let progress = min(1, Double(degree - 35) / 70)
            let folding = PocketTownFolding(progress: progress)
            // The canopy extends forward and upward as it rotates, so its lowest
            // local point is the attachment height minus half the roof thickness.
            XCTAssertGreaterThan(0.02 + 0.267 - 0.012, trainTop)
            let sweptRailDepth = 0.008 + 0.077 * sin((1 - folding.bridge) * .pi / 2)
            var obstacles = fixed
            for center in [-0.52, 0.94] {
                for edge in [center - 0.17, center + 0.17] {
                    obstacles.append(
                        ("bridge rail", -0.25, edge - sweptRailDepth / 2, 0.281, sweptRailDepth / 2 + 0.008))
                }
            }
            for route in [PocketTownRoute.riverside, .clockTower] {
                let sampler = PocketTownTrackSampler(points: PocketTownTracks.fullPath(route: route))
                for step in 0...900 {
                    let sample = sampler.sample(Double(step) / 900)
                    let c = cos(sample.heading)
                    let s = sin(sample.heading)
                    for obstacle in obstacles {
                        let dx = obstacle.x - sample.position.x
                        let dz = obstacle.z - sample.position.y
                        let separated =
                            abs(dx) > abs(c) * halfWidth + abs(s) * halfLength + obstacle.halfWidth
                            || abs(dz) > abs(s) * halfWidth + abs(c) * halfLength + obstacle.halfDepth
                            || abs(c * dx - s * dz) > halfWidth + abs(c) * obstacle.halfWidth + abs(s)
                                * obstacle.halfDepth
                            || abs(s * dx + c * dz) > halfLength + abs(s) * obstacle.halfWidth + abs(c)
                                * obstacle.halfDepth
                        if !separated {
                            XCTFail(
                                "\(obstacle.name) intersects \(route) at \(degree)°, x=\(sample.position.x), z=\(sample.position.y)"
                            )
                            return
                        }
                    }
                }
            }
        }
    }
}
