import PageBehavior
import XCTest

final class RoomGuestRouterTests: XCTestCase {
    func testRouteHubsAreClear() {
        for hub in RoomGuestRouter.routeHubs {
            XCTAssertFalse(
                RoomFurnitureLayout.overlapsFurniture(x: hub.x, z: hub.z),
                "hub (\(hub.x), \(hub.z)) overlaps furniture")
        }
    }

    func testAllDockPairRoutesClearFurniture() {
        let phases: [RoomTimePhase] = [.morning, .afternoon, .evening]
        for fromPhase in phases {
            for toPhase in phases {
                let from = RoomFurnitureLayout.pose(for: fromPhase)
                let to = RoomFurnitureLayout.pose(for: toPhase)
                let path = RoomGuestRouter.path(
                    from: RoomGuestWaypoint(x: from.x, z: from.z),
                    to: RoomGuestWaypoint(x: to.x, z: to.z))
                XCTAssertGreaterThanOrEqual(path.count, 2)
                XCTAssertTrue(RoomGuestRouter.pathClear(path), "\(fromPhase) -> \(toPhase)")
            }
        }
    }

    func testWalkSamplesNeverOverlapFurniture() {
        var state = RoomInComputerGameplay()
        let open = RoomInComputerFolding(progress: 1)
        state.handleStrip(.dockMorning)
        state.handleStrip(.dockEvening)
        let frames = Int(RoomInComputerGameplay.walkDuration / 0.04) + 4
        for _ in 0..<frames {
            let guest = state.guestDisplay
            XCTAssertFalse(
                RoomFurnitureLayout.overlapsFurniture(x: guest.x, z: guest.z),
                "guest at (\(guest.x), \(guest.z))")
            state.advance(deltaTime: 0.04, folding: open)
        }
    }

    func testMidWalkRetargetUsesAvoidancePath() {
        var state = RoomInComputerGameplay()
        let open = RoomInComputerFolding(progress: 1)
        state.handleStrip(.dockMorning)
        state.advance(deltaTime: 0.2, folding: open)
        let mid = state.guestDisplay
        state.handleStrip(.dragX(0.9))
        XCTAssertTrue(RoomGuestRouter.pathClear(state.guestPath))
        for _ in 0..<60 {
            let guest = state.guestDisplay
            XCTAssertFalse(RoomFurnitureLayout.overlapsFurniture(x: guest.x, z: guest.z))
            state.advance(deltaTime: 0.04, folding: open)
            if state.guestMove >= 1 { break }
        }
        _ = mid
    }
}
