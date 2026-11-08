import PageBehavior
import XCTest

final class RoomFurnitureLayoutTests: XCTestCase {
    func testMorningPoseBesideBedNotOnFurniture() {
        let pose = RoomFurnitureLayout.pose(for: .morning)
        XCTAssertFalse(RoomFurnitureLayout.bed.contains(x: pose.x, z: pose.z))
        XCTAssertFalse(RoomFurnitureLayout.overlapsFurniture(x: pose.x, z: pose.z))
    }

    func testAfternoonPoseBesideDeskNotOnFurniture() {
        let pose = RoomFurnitureLayout.pose(for: .afternoon)
        XCTAssertFalse(RoomFurnitureLayout.desk.contains(x: pose.x, z: pose.z))
        XCTAssertFalse(RoomFurnitureLayout.overlapsFurniture(x: pose.x, z: pose.z))
    }

    func testEveningPoseBesideChairNotOnFurniture() {
        let pose = RoomFurnitureLayout.pose(for: .evening)
        XCTAssertFalse(RoomFurnitureLayout.chair.contains(x: pose.x, z: pose.z))
        XCTAssertFalse(RoomFurnitureLayout.overlapsFurniture(x: pose.x, z: pose.z))
    }

    func testGameplayUsesLayoutAnchors() {
        for phase in [RoomTimePhase.morning, .afternoon, .evening] {
            XCTAssertEqual(
                RoomInComputerGameplay.pose(for: phase), RoomFurnitureLayout.pose(for: phase))
        }
    }
}
