import Foundation
import PopupBookCore

public enum RoomSaveNoticeKey: Equatable, Sendable {
    case backupRestored
    case saveProtected
    case futureMainReadOnly
}

public struct RoomInComputerRestoreResult: Equatable, Sendable {
    public var gameplay: RoomInComputerGameplay
    public var canSave: Bool
    public var notice: RoomSaveNoticeKey?

    public init(gameplay: RoomInComputerGameplay, canSave: Bool, notice: RoomSaveNoticeKey? = nil) {
        self.gameplay = gameplay
        self.canSave = canSave
        self.notice = notice
    }
}

public enum RoomInComputerSave {
    public static func restore(state: Data?, backup: Data?) -> RoomInComputerRestoreResult {
        guard let state else {
            guard let backup else {
                return RoomInComputerRestoreResult(gameplay: RoomInComputerGameplay(), canSave: true)
            }
            do {
                let snapshot = try RoomInComputerSnapshot.decoded(backup)
                return RoomInComputerRestoreResult(
                    gameplay: RoomInComputerGameplay(restoredTime: snapshot.roomTime), canSave: true)
            } catch {
                return RoomInComputerRestoreResult(
                    gameplay: RoomInComputerGameplay(), canSave: false, notice: .saveProtected)
            }
        }
        do {
            let snapshot = try RoomInComputerSnapshot.decoded(state)
            return RoomInComputerRestoreResult(
                gameplay: RoomInComputerGameplay(restoredTime: snapshot.roomTime), canSave: true)
        } catch {
            if isFutureVersion(error), let backup, let snapshot = try? RoomInComputerSnapshot.decoded(backup)
            {
                return RoomInComputerRestoreResult(
                    gameplay: RoomInComputerGameplay(restoredTime: snapshot.roomTime),
                    canSave: false, notice: .futureMainReadOnly)
            }
            if let backup, let snapshot = try? RoomInComputerSnapshot.decoded(backup) {
                return RoomInComputerRestoreResult(
                    gameplay: RoomInComputerGameplay(restoredTime: snapshot.roomTime),
                    canSave: true, notice: .backupRestored)
            }
            return RoomInComputerRestoreResult(
                gameplay: RoomInComputerGameplay(), canSave: false, notice: .saveProtected)
        }
    }

    private static func isFutureVersion(_ error: Error) -> Bool {
        if case StateRestoreError.unsupportedVersion = error { return true }
        return false
    }

    public static func checkpoint(from gameplay: RoomInComputerGameplay, canSave: Bool) -> Data? {
        guard canSave else { return nil }
        return try? JSONEncoder().encode(gameplay.snapshot())
    }

    public static func pausePayload(from gameplay: RoomInComputerGameplay, canSave: Bool) -> Data? {
        checkpoint(from: gameplay, canSave: canSave)
    }
}
