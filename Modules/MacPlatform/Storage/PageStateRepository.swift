import Foundation
import PopupBookCore

/// Page schemas are opaque. Only worker-validated checkpoints can replace files or become backups.
@MainActor public final class PageStateRepository {
    private struct Pending {
        let url: URL
        var latest: Data
        var durable: Data?
        var lastAttempt = -Double.infinity
        var writing = false
        var flushRequested = false
        var timer: Task<Void, Never>?
    }

    private let base: URL
    private let writer = DispatchQueue(label: "local.forestbook.checkpoints", qos: .utility)
    private var pending: [String: Pending] = [:]
    private var blocked: Set<String> = []
    private var drainCallbacks: [() -> Void] = []
    public private(set) var errors: [String: String] = [:]
    public var onErrorChange: (() -> Void)?

    public init(base: URL) { self.base = base }

    private func location(_ page: PageDescriptor) throws -> URL {
        try page.validate()
        return page.legacyStateFile.map { base.appendingPathComponent($0) }
            ?? base.appendingPathComponent("pages/\(page.id)/state.json")
    }

    public func restore(_ page: PageDescriptor) -> (Data?, Data?) {
        do {
            let store = FileStateStore(url: try location(page))
            if let entry = pending[page.id], entry.latest != entry.durable {
                return (entry.latest, entry.durable ?? (try? store.loadBackup()))
            }
            return (try store.load(), try store.loadBackup())
        } catch {
            blocked.insert(page.id)
            setError(page.id, error.localizedDescription)
            return (nil, nil)
        }
    }

    public func save(_ page: PageDescriptor, data: Data, flush: Bool = false) {
        guard !blocked.contains(page.id) else { return }
        do {
            guard data.count <= 1_000_000 else { throw StateRestoreError.invalidState }
            var entry = try pending[page.id] ?? Pending(url: location(page), latest: data)
            entry.latest = data
            entry.flushRequested = entry.flushRequested || flush
            pending[page.id] = entry
            schedule(page.id)
        } catch { setError(page.id, error.localizedDescription) }
    }

    public func flushAll(completion: @escaping () -> Void) {
        for id in Array(pending.keys) {
            pending[id]?.flushRequested = true
            schedule(id)
        }
        drainCallbacks.append(completion)
        finishDrainIfIdle()
    }

    private func schedule(_ id: String) {
        guard var entry = pending[id], !entry.writing else { return }
        if entry.latest == entry.durable {
            entry.timer?.cancel()
            entry.timer = nil
            entry.flushRequested = false
            pending[id] = entry
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let delay = 1 - (now - entry.lastAttempt)
        if delay > 0 && !entry.flushRequested {
            guard entry.timer == nil else { return }
            entry.timer = Task { @MainActor [weak self] in
                do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) } catch { return }
                self?.pending[id]?.timer = nil
                self?.schedule(id)
            }
            pending[id] = entry
            return
        }

        entry.timer?.cancel()
        entry.timer = nil
        entry.lastAttempt = now
        entry.writing = true
        entry.flushRequested = false
        pending[id] = entry
        let (data, previous, url) = (entry.latest, entry.durable, entry.url)
        writer.async { [weak self] in
            let failure: String?
            do {
                try FileStateStore.write(data, previous: previous, to: url)
                failure = nil
            } catch { failure = error.localizedDescription }
            DispatchQueue.main.async { [weak self] in self?.didWrite(id, data: data, error: failure) }
        }
    }

    private func didWrite(_ id: String, data: Data, error: String?) {
        guard var entry = pending[id] else { return }
        entry.writing = false
        entry.lastAttempt = ProcessInfo.processInfo.systemUptime
        if error == nil { entry.durable = data }
        pending[id] = entry
        setError(id, error)
        if entry.latest != data || entry.flushRequested { schedule(id) }
        finishDrainIfIdle()
    }

    private func setError(_ id: String, _ error: String?) {
        guard errors[id] != error else { return }
        errors[id] = error
        onErrorChange?()
    }

    private func finishDrainIfIdle() {
        guard !pending.values.contains(where: \.writing) else { return }
        let callbacks = drainCallbacks
        drainCallbacks = []
        for callback in callbacks { callback() }
    }
}
