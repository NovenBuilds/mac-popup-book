import PageBehavior
import XCTest

final class RoomInComputerGameplayTests: XCTestCase {
    func testDockSnapsTime() {
        var state = RoomInComputerGameplay()
        state.handleStrip(.dockMorning)
        XCTAssertEqual(state.roomTime, RoomInComputerGameplay.morningDock)
        XCTAssertEqual(state.guestGoal, .morning)

        state.handleStrip(.dockEvening)
        XCTAssertEqual(state.roomTime, RoomInComputerGameplay.eveningDock)
        XCTAssertEqual(state.guestGoal, .evening)
    }

    func testDragUpdatesLightAndGoal() {
        var state = RoomInComputerGameplay()
        state.handleStrip(.dragX(0.2))
        XCTAssertEqual(RoomInComputerGameplay.phase(for: state.roomTime), .morning)
        state.handleStrip(.dragX(0.55))
        XCTAssertEqual(RoomInComputerGameplay.phase(for: state.roomTime), .afternoon)
        XCTAssertEqual(state.guestGoal, .afternoon)
    }

    func testFastDragKeepsLastTargetOnly() {
        var state = RoomInComputerGameplay()
        let open = RoomInComputerFolding(progress: 1)
        state.handleStrip(.dragX(0.1))
        state.advance(deltaTime: 0.1, folding: open)
        XCTAssertLessThan(state.guestMove, 1)

        state.handleStrip(.dragX(0.95))
        XCTAssertEqual(state.guestGoal, .evening)
        let pos = state.guestDisplay
        XCTAssertEqual(pos.activity, .evening)
        XCTAssertLessThan(state.guestMove, 1)
    }

    func testGuestWalksWithoutTeleport() {
        var state = RoomInComputerGameplay()
        let open = RoomInComputerFolding(progress: 1)
        state.handleStrip(.dockMorning)
        let start = state.guestDisplay
        state.handleStrip(.dockEvening)
        state.advance(deltaTime: 0.05, folding: open)
        let mid = state.guestDisplay
        XCTAssertNotEqual(start.x, mid.x)
        XCTAssertLessThan(state.guestMove, 1)

        state.advance(deltaTime: RoomInComputerGameplay.walkDuration * 2, folding: open)
        XCTAssertEqual(state.guestMove, 1)
        XCTAssertEqual(state.guestDisplay.activity, .evening)
    }

    func testFoldCollapseResetsGuestHomeButKeepsRoomTime() {
        var state = RoomInComputerGameplay()
        state.handleStrip(.dockEvening)
        let closed = RoomInComputerFolding(progress: 0.1)
        state.advance(deltaTime: 0.2, folding: closed)
        XCTAssertEqual(state.guestGoal, .morning)
        XCTAssertEqual(state.guestMove, 1)
        XCTAssertEqual(state.roomTime, RoomInComputerGameplay.eveningDock)
    }

    func testReopenWalksToSavedTimePhase() {
        var state = RoomInComputerGameplay()
        let closed = RoomInComputerFolding(progress: 0.1)
        let open = RoomInComputerFolding(progress: 1)
        state.handleStrip(.dockEvening)
        state.advance(deltaTime: 0.1, folding: closed)
        XCTAssertEqual(state.guestDisplay.activity, .morning)

        state.advance(deltaTime: 0.05, folding: open)
        XCTAssertEqual(state.guestGoal, .evening)
        XCTAssertLessThan(state.guestMove, 1)

        state.advance(deltaTime: RoomInComputerGameplay.walkDuration * 2, folding: open)
        XCTAssertEqual(state.guestMove, 1)
        XCTAssertEqual(state.guestDisplay.activity, .evening)
        XCTAssertEqual(state.roomTime, RoomInComputerGameplay.eveningDock)
    }

    func testPrepareRestoreUsesSavedRoomTime() {
        let saved = RoomInComputerSnapshot(roomTime: 0.95)
        let state = RoomInComputerGameplay(restoredTime: saved.roomTime)
        XCTAssertEqual(state.roomTime, 0.95)
        XCTAssertEqual(state.guestGoal, .evening)
        XCTAssertEqual(state.guestDisplay.activity, .evening)
    }

    func testCancelPointerClearsDragging() {
        var state = RoomInComputerGameplay()
        state.handleStrip(.dragX(0.4))
        XCTAssertTrue(state.draggingStrip)
        state.cancelPointer()
        XCTAssertFalse(state.draggingStrip)
    }

    func testSnapshotRoundTrip() throws {
        var state = RoomInComputerGameplay()
        state.handleStrip(.dockAfternoon)
        let data = try JSONEncoder().encode(state.snapshot())
        let decoded = try JSONDecoder().decode(RoomInComputerSnapshot.self, from: data)
        let restored = RoomInComputerGameplay(restoredTime: decoded.roomTime)
        XCTAssertEqual(restored.roomTime, RoomInComputerGameplay.afternoonDock)
        XCTAssertFalse(restored.draggingStrip)
    }

    func testCaptionsLocalized() {
        var state = RoomInComputerGameplay()
        state.handleStrip(.dockAfternoon)
        XCTAssertTrue(state.caption(zh: true).contains("午后"))
        XCTAssertTrue(state.caption(zh: false).contains("Afternoon"))
    }
}

final class RoomInComputerFoldingTests: XCTestCase {
    func testLayerOrder() {
        let mid = RoomInComputerFolding(progress: 0.5)
        XCTAssertEqual(mid.floor, 1)
        XCTAssertGreaterThan(mid.walls, 0)
        XCTAssertGreaterThan(mid.bed, 0)
        XCTAssertEqual(mid.lamp, 0)
    }

    func testFullyOpen() {
        let open = RoomInComputerFolding(progress: 1)
        XCTAssertEqual(open.floor, 1)
        XCTAssertEqual(open.walls, 1)
        XCTAssertEqual(open.bed, 1)
        XCTAssertEqual(open.desk, 1)
        XCTAssertEqual(open.lamp, 1)
    }
}
