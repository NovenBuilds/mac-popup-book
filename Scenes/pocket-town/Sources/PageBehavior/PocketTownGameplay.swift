import Foundation

public enum PocketTownNotice: String, Equatable, Sendable {
    case needOpen
    case switchBlocked
    case trainBusy
    case selectedRiverside
    case selectedClockTower
}

public enum PocketTownTapTarget: Equatable, Sendable {
    case station
    case switchRail
}

public struct PocketTownGameplay: Equatable, Sendable {
    public enum TrainPhase: Equatable, Sendable {
        case atStation
        case running(progress: Double)
    }

    /// 道岔为下一趟所选线路；发车后不再影响本趟采样与字幕。
    public var selectedRoute: PocketTownRoute
    public private(set) var tripRoute: PocketTownRoute?
    public var train: TrainPhase
    public var notice: PocketTownNotice?
    public var noticeUntil: Double
    public var canInteract: Bool

    public static let loopDuration = 24.0
    public static let switchRadius = 0.18
    public static let foldedResetProgress = 0.22

    public init(selectedRoute: PocketTownRoute = .riverside) {
        self.selectedRoute = selectedRoute
        tripRoute = nil
        train = .atStation
        notice = nil
        noticeUntil = 0
        canInteract = false
    }

    public static func clamp(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        guard value.isFinite else { return value.sign == .minus ? 0 : 1 }
        return min(1, max(0, value))
    }

    public mutating func handleTap(_ target: PocketTownTapTarget, folding: PocketTownFolding, now: Double) {
        updateInteractionGate(folding: folding)
        guard canInteract else {
            setNotice(.needOpen, until: now + 2)
            return
        }

        switch target {
        case .switchRail:
            guard canToggleSwitch() else {
                setNotice(.switchBlocked, until: now + 1.6)
                return
            }
            selectedRoute = selectedRoute == .riverside ? .clockTower : .riverside
            setNotice(
                selectedRoute == .riverside ? .selectedRiverside : .selectedClockTower, until: now + 1.4)
        case .station:
            switch train {
            case .atStation:
                tripRoute = selectedRoute
                train = .running(progress: 0)
                notice = nil
            case .running:
                setNotice(.trainBusy, until: now + 1.4)
            }
        }
    }

    public mutating func advance(
        bookProgress: Double, clock: Double, deltaTime: Double, folding: PocketTownFolding
    ) {
        let delta = max(0, deltaTime)
        updateInteractionGate(folding: folding)

        if bookProgress < Self.foldedResetProgress {
            resetTrainAtStation()
        } else {
            switch train {
            case .atStation:
                break
            case .running(let progress):
                let next = progress + delta / Self.loopDuration
                if next >= 1 {
                    resetTrainAtStation()
                } else {
                    train = .running(progress: next)
                }
            }
        }

        if clock >= noticeUntil { notice = nil }
    }

    public func caption(zh: Bool) -> String {
        let routeName =
            (displayRoute == .riverside)
            ? (zh ? "河岸线" : "Riverside loop")
            : (zh ? "钟楼线" : "Clock tower loop")
        switch train {
        case .atStation where canInteract:
            return zh
                ? "点击车站发车，点击道岔切到\(routeName)。"
                : "Tap the station to depart. Switch is on \(routeName)."
        case .atStation:
            return zh ? "口袋小镇" : "Pocket Town"
        case .running:
            return zh ? "小火车正在走\(routeName)。" : "Train on \(routeName)."
        }
    }

    /// 本趟行程采样线路；停站时等同 `selectedRoute`。
    public var displayRoute: PocketTownRoute { tripRoute ?? selectedRoute }

    public func sampler() -> PocketTownTrackSampler {
        PocketTownTrackSampler(points: PocketTownTracks.fullPath(route: displayRoute))
    }

    public func samplerForTrip() -> PocketTownTrackSampler? {
        guard let tripRoute else { return nil }
        return PocketTownTrackSampler(points: PocketTownTracks.fullPath(route: tripRoute))
    }

    public var routeProgress: Double {
        switch train {
        case .atStation: return 0
        case .running(let progress): return progress
        }
    }

    public var trainIsRunning: Bool {
        if case .running = train { return true }
        return false
    }

    private mutating func resetTrainAtStation() {
        train = .atStation
        tripRoute = nil
    }

    private mutating func updateInteractionGate(folding: PocketTownFolding) {
        canInteract = folding.routes >= 0.82 && folding.houses >= 0.18
    }

    private func canToggleSwitch() -> Bool {
        switch train {
        case .atStation:
            return true
        case .running(let progress):
            let sample = sampler().sample(progress).position
            let delta = sample - PocketTownTracks.switchCenter
            return delta.x * delta.x + delta.y * delta.y > Self.switchRadius * Self.switchRadius
        }
    }

    private mutating func setNotice(_ value: PocketTownNotice, until: Double) {
        notice = value
        noticeUntil = until
    }
}
