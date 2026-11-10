import Foundation
import PopupBookCore
import XCTest

@testable import MacPlatform

@MainActor final class PageStateRepositoryTests: XCTestCase {
    private func page(_ id: String, legacy: String? = nil) throws -> PageDescriptor {
        var object: [String: Any] = [
            "id": id, "order": 0, "names": ["en": id, "zh-Hans": id], "contractVersion": 1,
            "service": "local.test." + id, "product": "Worker", "audio": [],
        ]
        if let legacy { object["legacyStateFile"] = legacy }
        return try JSONDecoder().decode(
            PageDescriptor.self, from: JSONSerialization.data(withJSONObject: object))
    }
    private func drain(_ repository: PageStateRepository) async {
        await withCheckedContinuation { continuation in
            repository.flushAll { continuation.resume() }
        }
    }

    func testLegacyMappingAndTwoPagesNeverShareSnapshots() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = PageStateRepository(base: root)
        let a = try page("first", legacy: "resident.json")
        let b = try page("second")
        XCTAssertNil(repository.restore(a).0)
        XCTAssertNil(repository.restore(b).0)
        repository.save(a, data: Data([1]))
        repository.save(b, data: Data([9]))
        await drain(repository)
        repository.save(a, data: Data([2]))
        await drain(repository)
        XCTAssertEqual(repository.restore(a).0, Data([2]))
        XCTAssertEqual(repository.restore(a).1, Data([1]))
        XCTAssertEqual(repository.restore(b).0, Data([9]))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("resident.json")), Data([2]))
    }
    func testInvalidLegacyPathIsBlockedWithoutAffectingAnotherPage() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = PageStateRepository(base: root.appendingPathComponent("base"))
        let bad = try page("bad", legacy: "../escaped.json")
        let good = try page("good")
        XCTAssertNil(repository.restore(bad).0)
        repository.save(bad, data: Data([1]))
        XCTAssertNotNil(repository.errors["bad"])
        repository.save(good, data: Data([2]))
        await drain(repository)
        XCTAssertEqual(repository.restore(good).0, Data([2]))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: root.appendingPathComponent("escaped.json").path))
    }

    func testBurstCoalescesAndRestoresNewestBeforeFinalFlush() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = PageStateRepository(base: root)
        let page = try page("first", legacy: "resident.json")
        let file = root.appendingPathComponent("resident.json")
        repository.save(page, data: Data([0]))
        await drain(repository)
        for value in UInt8(1)...60 { repository.save(page, data: Data([value])) }
        XCTAssertEqual(try Data(contentsOf: file), Data([0]))
        XCTAssertEqual(repository.restore(page).0, Data([60]))
        repository.save(page, data: Data([61]), flush: true)
        await drain(repository)
        XCTAssertEqual(try Data(contentsOf: file), Data([61]))
        XCTAssertEqual(repository.restore(page).1, Data([0]))
    }

    func testFailedWriteRetainsLatestAndCanRetrySameSnapshot() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data([0]).write(to: root)
        let repository = PageStateRepository(base: root)
        let page = try page("first", legacy: "resident.json")
        repository.save(page, data: Data([2]))
        await drain(repository)
        XCTAssertNotNil(repository.errors[page.id])
        XCTAssertEqual(repository.restore(page).0, Data([2]))
        try FileManager.default.removeItem(at: root)
        repository.save(page, data: Data([2]), flush: true)
        await drain(repository)
        XCTAssertNil(repository.errors[page.id])
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("resident.json")), Data([2]))
    }
}

final class PageCheckpointBufferTests: XCTestCase {
    func testFinalTimeoutUsesLatestAndRejectsLateReplies() {
        var buffer = PageCheckpointBuffer()
        XCTAssertEqual(buffer.record(Data([1]), canSave: true), Data([1]))
        let pause = buffer.beginFinal()
        XCTAssertEqual(buffer.record(Data([2]), canSave: true), Data([2]))
        let exit = buffer.beginFinal()
        XCTAssertNil(buffer.completeFinal(pause, data: Data([1])))
        XCTAssertEqual(buffer.completeFinal(exit, data: nil), Data([2]))
        XCTAssertNil(buffer.completeFinal(exit, data: Data([3])))
    }

    func testFinalSnapshotSupersedesFrameAndProtectedStateClearsFallback() {
        var buffer = PageCheckpointBuffer()
        _ = buffer.record(Data([1]), canSave: true)
        let pause = buffer.beginFinal()
        XCTAssertEqual(buffer.completeFinal(pause, data: Data([2])), Data([2]))
        XCTAssertNil(buffer.record(nil, canSave: false))
        let exit = buffer.beginFinal()
        XCTAssertNil(buffer.completeFinal(exit, data: nil))
    }
}
