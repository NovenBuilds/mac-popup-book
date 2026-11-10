import PageBehavior
import XCTest

final class PocketTownFoldingTests: XCTestCase {
    func testClosedAndOpenStates() {
        let closed = PocketTownFolding(progress: 0)
        XCTAssertEqual(closed.ground, 0)
        XCTAssertEqual(closed.routes, 0)
        XCTAssertEqual(closed.houses, 0)
        XCTAssertEqual(closed.bridge, 0)
        XCTAssertEqual(closed.tower, 0)
        XCTAssertEqual(closed.stationCanopy, 0)

        let open = PocketTownFolding(progress: 1)
        XCTAssertEqual(open.ground, 1)
        XCTAssertEqual(open.routes, 1)
        XCTAssertEqual(open.houses, 1)
        XCTAssertEqual(open.bridge, 1)
        XCTAssertEqual(open.tower, 1)
        XCTAssertEqual(open.stationCanopy, 1)
    }

    func testPartsStandInPlannedOrder() {
        let half = PocketTownFolding(progress: 0.5)
        XCTAssertEqual(half.ground, 1)
        XCTAssertEqual(half.routes, 1)
        XCTAssertGreaterThan(half.houses, 0)
        XCTAssertGreaterThan(half.bridge, 0)
        XCTAssertGreaterThan(half.tower, 0)
        XCTAssertEqual(half.stationCanopy, 0)
    }

    func testReversalReadsCurrentProgressDirectly() {
        let opened = PocketTownFolding(progress: 0.9)
        let reversed = PocketTownFolding(progress: 0.35)
        XCTAssertLessThan(reversed.tower, opened.tower)
        XCTAssertLessThan(reversed.stationCanopy, opened.stationCanopy)
        XCTAssertEqual(reversed, PocketTownFolding(progress: 0.35))

        let reopened = PocketTownFolding(progress: 0.75)
        XCTAssertGreaterThan(reopened.bridge, reversed.bridge)
        XCTAssertEqual(reopened, PocketTownFolding(progress: 0.75))
    }

    func testStagesNeverMoveBackwardDuringOpening() {
        var previous = PocketTownFolding(progress: 0)
        for progress in stride(from: 0.05, through: 1.0, by: 0.05) {
            let current = PocketTownFolding(progress: progress)
            XCTAssertGreaterThanOrEqual(current.ground, previous.ground)
            XCTAssertGreaterThanOrEqual(current.routes, previous.routes)
            XCTAssertGreaterThanOrEqual(current.houses, previous.houses)
            XCTAssertGreaterThanOrEqual(current.bridge, previous.bridge)
            XCTAssertGreaterThanOrEqual(current.tower, previous.tower)
            XCTAssertGreaterThanOrEqual(current.stationCanopy, previous.stationCanopy)
            previous = current
        }
    }

    func testInvalidProgressIsDeterministic() {
        XCTAssertEqual(PocketTownFolding(progress: .nan), PocketTownFolding(progress: 0))
        XCTAssertEqual(PocketTownFolding(progress: -.infinity), PocketTownFolding(progress: 0))
        XCTAssertEqual(PocketTownFolding(progress: .infinity), PocketTownFolding(progress: 1))
    }
}
