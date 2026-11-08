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

    func testFutureMainWithOldBackupIsReadOnly() throws {
        let futureMain = Data("{\"version\":2,\"roomTime\":0.1}".utf8)
        let backup = try JSONEncoder().encode(RoomInComputerSnapshot(roomTime: 0.72))
        let result = RoomInComputerSave.restore(state: futureMain, backup: backup)
        XCTAssertEqual(result.gameplay.roomTime, 0.72)
        XCTAssertFalse(result.canSave)
        XCTAssertEqual(result.notice, .futureMainReadOnly)
        XCTAssertNil(RoomInComputerSave.checkpoint(from: result.gameplay, canSave: result.canSave))
    }

    func testMissingMainUsesValidBackup() throws {
        let backup = try JSONEncoder().encode(RoomInComputerSnapshot(roomTime: 0.44))
        let result = RoomInComputerSave.restore(state: nil, backup: backup)
        XCTAssertEqual(result.gameplay.roomTime, 0.44)
        XCTAssertTrue(result.canSave)
        XCTAssertNil(result.notice)
    }

    func testMissingMainBadBackupDisablesSave() {
        let result = RoomInComputerSave.restore(state: nil, backup: Data("broken".utf8))
        XCTAssertFalse(result.canSave)
        XCTAssertEqual(result.notice, .saveProtected)
        XCTAssertNil(RoomInComputerSave.checkpoint(from: result.gameplay, canSave: result.canSave))
    }

    func testMissingMainFutureBackupDisablesSave() {
        let futureBackup = Data("{\"version\":2,\"roomTime\":0.6}".utf8)
        let result = RoomInComputerSave.restore(state: nil, backup: futureBackup)
        XCTAssertFalse(result.canSave)
        XCTAssertEqual(result.notice, .saveProtected)
        XCTAssertNil(RoomInComputerSave.pausePayload(from: result.gameplay, canSave: result.canSave))
    }

    func testMissingBothAllowsNewSave() {
        let result = RoomInComputerSave.restore(state: nil, backup: nil)
        XCTAssertTrue(result.canSave)
        XCTAssertNil(result.notice)
        XCTAssertNotNil(RoomInComputerSave.checkpoint(from: result.gameplay, canSave: result.canSave))
    }
}
