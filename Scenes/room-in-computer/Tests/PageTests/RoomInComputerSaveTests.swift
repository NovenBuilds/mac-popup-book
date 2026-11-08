import PageBehavior
import PopupBookCore
import XCTest

final class RoomInComputerSaveTests: XCTestCase {
    func testMainBadBackupGood() throws {
        let backup = try JSONEncoder().encode(RoomInComputerSnapshot(roomTime: 0.88))
        let result = RoomInComputerSave.restore(state: Data("not-json".utf8), backup: backup)
        XCTAssertEqual(result.gameplay.roomTime, 0.88)
        XCTAssertTrue(result.canSave)
        XCTAssertEqual(result.notice, .backupRestored)
        XCTAssertNotNil(RoomInComputerSave.checkpoint(from: result.gameplay, canSave: result.canSave))
    }

    func testBothBadDisablesSave() {
        let result = RoomInComputerSave.restore(
            state: Data("bad".utf8), backup: Data("also-bad".utf8))
        XCTAssertFalse(result.canSave)
        XCTAssertEqual(result.notice, .saveProtected)
        XCTAssertNil(RoomInComputerSave.checkpoint(from: result.gameplay, canSave: result.canSave))
        XCTAssertNil(RoomInComputerSave.pausePayload(from: result.gameplay, canSave: result.canSave))
    }

    func testUnknownVersionRejected() {
        let data = Data("{\"version\":2,\"roomTime\":0.5}".utf8)
        XCTAssertThrowsError(try RoomInComputerSnapshot.decoded(data)) { error in
            guard case StateRestoreError.unsupportedVersion(2) = error else {
                return XCTFail("expected unsupported version")
            }
        }
        let result = RoomInComputerSave.restore(state: data, backup: nil)
        XCTAssertFalse(result.canSave)
        XCTAssertEqual(result.notice, .saveProtected)
    }

    func testValidMainNeedsNoBackup() throws {
        let state = try JSONEncoder().encode(RoomInComputerSnapshot(roomTime: 0.25))
        let result = RoomInComputerSave.restore(state: state, backup: nil)
        XCTAssertEqual(result.gameplay.roomTime, 0.25)
        XCTAssertTrue(result.canSave)
        XCTAssertNil(result.notice)
    }
}
