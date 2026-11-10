import Foundation
import PopupBookCore

/// The only writer of book navigation and process state. It never imports a renderer or a page.
@MainActor public final class BookCoordinator {
    public let registry: PageRegistry
    public private(set) var state = BookState()
    public private(set) var fold = FoldState()
    public var following: Bool { state.following }
    public var soundEnabled: Bool { state.soundEnabled }
    public var initialPage: String?
    public var onChange: (() -> Void)?
    public var onPageSelected: ((String) -> Void)?
    public var onSounds: ((String, [PageSound]) -> Void)?
    public var onScopeEnded: ((String) -> Void)?
    public var onScopeActive: ((String, Bool) -> Void)?
    private let source: any AngleSource
    private let clock: any FrameClock
    private let settings: any SettingsStore
    private let wallClock: (any WallClock)?
    private let factory: (PageDescriptor) -> any PageProcessPort
    private var ports: [String: any PageProcessPort] = [:]
    private var epochs: [String: Int] = [:]
    private var started: [String: Double] = [:]
    private var lastFrames: [String: Double] = [:]
    private var lastTick = 0.0
    private var phaseTime = 0.0
    private var outgoingPage: String?
    private var hasTargetFrame = false
    private var watchedPage: String?
    private var context = WorldContext(progress: 1, clock: 0, deltaTime: 0, stableDuration: 0)
    private var manual: Double { state.manualProgress }
    private var inputGeneration = 0
    private var lastValidReading: Double?
    private var activeAudioPage: String?
    public init(
        registry: PageRegistry, source: any AngleSource, clock: any FrameClock, settings: any SettingsStore,
        wallClock: (any WallClock)? = nil, factory: @escaping (PageDescriptor) -> any PageProcessPort
    ) {
        self.registry = registry
        self.source = source
        self.clock = clock
        self.settings = settings
        self.wallClock = wallClock
        self.factory = factory
        state.soundEnabled = settings.soundEnabled
        _ = fold.calibrate(settings.openAngle)
        state.openAngle = fold.openAngle
    }
    public func setActive(_ value: Bool) {
        guard value != state.active else { return }
        state.active = value
        watchedPage = nil
        if value {
            lastTick = clock.now
            for id in started.keys {
                started[id] = clock.now
                lastFrames[id] = clock.now
            }
            configureInput()
            clock.start { [weak self] time in self?.tick(time) }
            if state.current == nil, let first = registry.pages.first {
                open(
                    initialPage.flatMap { id in registry.pages.contains(where: { $0.id == id }) ? id : nil }
                        ?? first.id)
            }
        } else {
            inputGeneration += 1
            source.stop()
            clock.stop()
            for (id, port) in ports {
                port.pause()
                if state.pageStates[id] == .running || state.pageStates[id] == .ready {
                    state.pageStates[id] = .paused
                }
            }
        }
        updateAudioScope()
        onChange?()
    }
    public func setFollowing(_ value: Bool) {
        guard value != following else { return }
        if !value { state.manualProgress = fold.progress }
        state.following = value
        configureInput()
        onChange?()
    }
    public func setManual(_ value: Double) {
        guard value.isFinite else { return }
        state.manualProgress = clamp(value)
        if !following { fold.target = manual }
        onChange?()
    }
    public func setSound(_ value: Bool) {
        state.soundEnabled = value
        settings.soundEnabled = value
        updateAudioScope()
        onChange?()
    }
    @discardableResult public func calibrate() -> Bool {
        guard let angle = fold.angle, fold.calibrate(angle) else { return false }
        settings.openAngle = fold.openAngle
        state.openAngle = fold.openAngle
        onChange?()
        return true
    }
    public func open(_ id: String) {
        guard state.phase == .idle, let descriptor = registry.pages.first(where: { $0.id == id }) else {
            return
        }
        if state.current == id, case .failed = state.pageStates[id] {} else if state.current == id { return }
        state.target = id
        state.failedTarget = nil
        outgoingPage = isFailed(state.current) ? nil : state.current
        hasTargetFrame = false
        state.phase = .preparing
        updateAudioScope()
        phaseTime = 0
        epochs[id, default: 0] += 1
        let token = epochs[id]!
        ports[id]?.stop()
        let port = factory(descriptor)
        ports[id] = port
        state.pageStates[id] = .starting
        started[id] = clock.now
        port.onReady = { [weak self] in
            guard let self, self.epochs[id] == token, self.state.target == id else { return }
            self.state.pageStates[id] = .ready
            self.lastFrames[id] = self.clock.now
            if self.state.current == nil || self.state.current == id || self.isFailed(self.state.current) {
                self.beginExpansion(id)
            } else {
                self.state.phase = .collapsing
                self.phaseTime = 0
            }
            self.onChange?()
        }
        port.onFrame = { [weak self] output in
            guard let self, self.epochs[id] == token, self.state.active, self.state.current == id,
                self.state.phase != .turning, self.state.pageStates[id] != .starting
            else { return }
            self.lastFrames[id] = self.clock.now
            if self.state.target == id && self.state.phase == .expanding {
                self.hasTargetFrame = true
            }
            self.state.output = output
            self.state.pageStates[id] = .running
            self.onSounds?(id, output.sounds)
            self.onChange?()
        }
        port.onFailure = { [weak self] error in
            guard let self, self.epochs[id] == token else { return }
            self.fail(id, error)
        }
        port.start(epoch: token)
        onChange?()
    }
    public func move(_ offset: Int) {
        guard let current = state.current, let index = registry.pages.firstIndex(where: { $0.id == current })
        else { return }
        let n = index + offset
        if registry.pages.indices.contains(n) { open(registry.pages[n].id) }
    }
    public func handle(_ input: PageInput) {
        guard state.active, state.phase == .idle, let id = state.current, !isFailed(id) else { return }
        ports[id]?.handle(input)
    }
    public func stop() {
        setActive(false)
        for id in Array(ports.keys) { retire(id, terminating: true) }
        state.current = nil
        state.target = nil
        state.phase = .idle
        outgoingPage = nil
    }
    private func configureInput() {
        inputGeneration += 1
        let token = inputGeneration
        source.stop()
        lastValidReading = nil
        fold.invalidateSensor(resetSampleOrder: true)
        state.angle = nil
        guard state.active else { return }
        if following {
            source.start { [weak self] sample in
                guard let self, self.inputGeneration == token, self.state.active, self.following else {
                    return
                }
                if self.fold.receive(sample) { self.lastValidReading = self.clock.now }
            }
        } else {
            fold.target = manual
        }
    }
    private func beginExpansion(_ id: String, from fraction: Double = 0) {
        if state.current != id { state.output = PagePresentation() }
        state.current = id
        state.turnProgress = 0
        state.phase = .expanding
        phaseTime = 0.3 * fraction
        watchedPage = nil
    }

    private func finishExpansion() {
        let selected = state.target
        state.phase = .idle
        state.target = nil
        if let old = outgoingPage, old != selected { retire(old, terminating: false) }
        outgoingPage = nil
        if let selected { onPageSelected?(selected) }
    }

    private func retire(_ id: String, terminating: Bool) {
        guard let port = ports.removeValue(forKey: id) else { return }
        epochs[id, default: 0] += 1
        if terminating { port.terminate() } else { port.stop() }
        onScopeEnded?(id)
        started[id] = nil
        lastFrames[id] = nil
        state.pageStates[id] = .stopped
    }
    private func updateAudioScope() {
        let current = state.current
        let threshold = activeAudioPage == nil ? 0.18 : 0.12
        let next =
            soundEnabled && state.active && state.phase == .idle
                && state.progress >= threshold && !isFailed(current) ? current : nil
        guard next != activeAudioPage else { return }
        if let activeAudioPage { onScopeActive?(activeAudioPage, false) }
        activeAudioPage = next
        if let next { onScopeActive?(next, true) }
    }
    private func isFailed(_ id: String?) -> Bool {
        guard let id else { return true }
        if case .failed = state.pageStates[id] { return true }
        return false
    }
    private func fail(_ id: String, _ error: PageError) {
        retire(id, terminating: true)
        state.pageStates[id] = .failed(error)
        if state.target == id {
            let phase = state.phase
            state.target = nil
            state.failedTarget = id
            if let old = outgoingPage, ports[old] != nil {
                if phase == .preparing {
                    state.phase = .idle
                } else {
                    let remaining = phase == .collapsing ? 1 - clamp(phaseTime / 0.25) : 0
                    beginExpansion(old, from: remaining)
                }
            } else {
                state.current = id
                state.output = PagePresentation()
                state.phase = .idle
                state.turnProgress = 0
            }
            outgoingPage = nil
        } else if state.current == id {
            if let target = state.target, state.phase == .collapsing || state.phase == .turning {
                beginExpansion(target)
            } else if state.target == nil {
                state.phase = .idle
                state.output = PagePresentation()
            }
        }
        updateAudioScope()
        onChange?()
    }
    private func tick(_ time: Double) {
        guard state.active, time.isFinite else { return }
        let dt = clamp(time - lastTick, 0, 0.05)
        lastTick = time
        if following, let lastValidReading, time - lastValidReading >= 1 {
            fold.invalidateSensor()
            self.lastValidReading = nil
        }
        context = fold.advance(dt)
        context.wallDate = wallClock?.date
        context.lidAngle = following ? fold.angle : nil
        context.inputState = following ? (fold.sensorAvailable ? .tracking : .unavailable) : .manual
        state.progress = context.progress
        state.angle = context.lidAngle
        if let target = state.target, state.pageStates[target] == .starting,
            time - (started[target] ?? time) > 10
        {
            fail(target, .startupTimeout)
        }
        let waitingToOpen = context.progress < 0.12 && state.phase != .idle && state.phase != .preparing
        let visible = state.current.flatMap { id in
            state.phase == .turning || waitingToOpen || isFailed(id) || state.pageStates[id] == .starting
                ? nil : id
        }
        if visible != watchedPage {
            watchedPage = visible
            if let visible { lastFrames[visible] = time }
        }
        if let visible, time - (lastFrames[visible] ?? time) > 3 { fail(visible, .stalled) }
        if context.progress >= 0.12 {
            switch state.phase {
            case .collapsing:
                phaseTime += dt
                if phaseTime >= 0.25 {
                    if let old = outgoingPage, let port = ports[old] {
                        port.pause()
                        state.pageStates[old] = .paused
                    }
                    state.phase = .turning
                    phaseTime = 0
                }
            case .turning:
                phaseTime += dt
                state.turnProgress = min(1, phaseTime / 0.45)
                if phaseTime >= 0.45, let target = state.target {
                    beginExpansion(target)
                }
            case .expanding:
                phaseTime += dt
                if phaseTime >= 0.3 && (state.target == nil || hasTargetFrame) {
                    finishExpansion()
                }
            default: break
            }
        }
        updateAudioScope()
        if let id = state.current, !isFailed(id), state.pageStates[id] != .starting,
            state.phase != .turning
        {
            var frame = context
            frame.pageReady = state.phase == .idle
            if state.phase == .collapsing {
                frame.progress = context.progress * (1 - clamp(phaseTime / 0.25))
            }
            if state.phase == .expanding { frame.progress = context.progress * clamp(phaseTime / 0.3) }
            ports[id]?.advance(frame)
        }
        onChange?()
    }
}
