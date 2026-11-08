import Foundation

public enum UnderwaterTheaterNotice: String, Equatable, Sendable {
    case needOpen
    case flowActive
    case westCurrent
    case archCurrent
    case shellCurrent
}

public struct UnderwaterTheaterGameplay: Equatable, Sendable {
    public private(set) var flowPoint: TheaterPoint
    public private(set) var flowStrength: Double
    public private(set) var dragging: Bool
    public var fishProgress: Double
    public private(set) var fishOffset: TheaterPoint
    public private(set) var patrolPhase: Double
    public var notice: UnderwaterTheaterNotice?
    public var noticeUntil: Double
    public var canInteract: Bool

    public static let patrolDuration = 28.0
    public static let flowDecayPerSecond = 1.35
    public static let foldedResetProgress = 0.22
    public static let tapHitRadius = 0.2

    public init() {
        flowPoint = TheaterPoint(0, 0)
        flowStrength = 0
        dragging = false
        fishProgress = 0
        fishOffset = TheaterPoint(0, 0)
        patrolPhase = 0
        notice = nil
        noticeUntil = 0
        canInteract = false
    }

    public static func clamp(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        guard value.isFinite else { return value.sign == .minus ? 0 : 1 }
        return min(1, max(0, value))
    }

    public mutating func handleTap(
        _ target: UnderwaterTheaterTapTarget, folding: UnderwaterTheaterFolding, now: Double
    ) {
        updateInteractionGate(folding: folding)
        guard canInteract else {
            setNotice(.needOpen, until: now + 2)
            return
        }
        let preset: UnderwaterTheaterTracks.TapCurrent
        let notice: UnderwaterTheaterNotice
        switch target {
        case .westSeaweed:
            preset = .westSeaweed
            notice = .westCurrent
        case .archRise:
            preset = .archRise
            notice = .archCurrent
        case .shellLedge:
            preset = .shellLedge
            notice = .shellCurrent
        }
        flowPoint = preset.sceneHint
        flowStrength = 1
        dragging = false
        setNotice(notice, until: now + 1.4)
    }

    public mutating func beginDrag(
        at point: TheaterPoint, folding: UnderwaterTheaterFolding, now: Double
    ) {
        updateInteractionGate(folding: folding)
        guard canInteract else {
            setNotice(.needOpen, until: now + 2)
            return
        }
        dragging = true
        flowPoint = UnderwaterTheaterSteering.clampToPage(point)
        flowStrength = 1
        notice = nil
    }

    public mutating func moveDrag(to point: TheaterPoint, folding: UnderwaterTheaterFolding) {
        updateInteractionGate(folding: folding)
        guard dragging, canInteract else { return }
        flowPoint = UnderwaterTheaterSteering.clampToPage(point)
        flowStrength = 1
    }

    public mutating func endDrag(now: Double) {
        dragging = false
        if flowStrength > 0.05 {
            setNotice(.flowActive, until: now + 1.2)
        }
    }

    public mutating func cancelDrag() {
        dragging = false
    }

    public mutating func advance(
        bookProgress: Double, clock: Double, deltaTime: Double, folding: UnderwaterTheaterFolding
    ) {
        let delta = max(0, deltaTime)
        updateInteractionGate(folding: folding)

        if !dragging {
            flowStrength = max(0, flowStrength - delta * Self.flowDecayPerSecond)
        }

        if bookProgress < Self.foldedResetProgress || folding.fish < 0.12 {
            let retreatRate = delta / 2.4
            fishProgress = max(0, fishProgress - retreatRate * 0.35)
            if fishProgress > 0.08 {
                fishProgress = max(0, fishProgress - retreatRate)
            } else {
                fishProgress = 0
            }
            fishOffset = UnderwaterTheaterSteering.integrate(
                current: fishOffset, target: TheaterPoint(0, 0), deltaTime: delta,
                flowStrength: 0, dragging: false)
        } else if folding.fish >= 0.55 {
            let guide = flowStrength * (dragging ? 1.0 : 0.65)
            let flowScene = flowPoint
            let sample = sampler().sample(fishProgress)
            let toward = flowScene - sample.position
            let distSq = toward.x * toward.x + toward.y * toward.y
            let alignment = distSq > 0.0001 ? min(1, 0.55 / distSq.squareRoot()) : 0
            let speed = (1.0 / Self.patrolDuration) * (1 + guide * (0.45 + alignment * 0.35))
            fishProgress += delta * speed
            if fishProgress >= 1 { fishProgress -= 1 }

            let anchor = sampler().sample(fishProgress).position
            let target = UnderwaterTheaterSteering.targetOffset(
                pathAnchor: anchor, flowScene: flowScene, flowStrength: flowStrength)
            var next = UnderwaterTheaterSteering.integrate(
                current: fishOffset, target: target, deltaTime: delta,
                flowStrength: flowStrength, dragging: dragging)
            next = UnderwaterTheaterSteering.constrain(pathAnchor: anchor, offset: next)
            fishOffset = next
        }

        if folding.fish >= 0.4 && flowStrength < 0.08 {
            patrolPhase += delta / Self.patrolDuration
            if patrolPhase >= 1 { patrolPhase -= 1 }
            if fishProgress < 0.02 && folding.fish >= 0.7 {
                fishProgress = patrolPhase * 0.15
            }
        }

        if clock >= noticeUntil { notice = nil }
    }

    public func caption(zh: Bool) -> String {
        if dragging || flowStrength > 0.25 {
            return zh
                ? "拖动水流珠，让鱼群滑向珊瑚拱门。"
                : "Drag the flow bead to steer the school toward the arch."
        }
        if canInteract {
            return zh
                ? "按住拖动水流珠，或点三处浅流引导鱼群。"
                : "Drag the flow bead, or tap a gentle current to guide the fish."
        }
        return zh ? "海底剧场" : "Underwater Theater"
    }

    public func sampler() -> TheaterTrackSampler {
        TheaterTrackSampler(points: UnderwaterTheaterTracks.patrolLoop)
    }

    public func tapTarget(at point: TheaterPoint) -> UnderwaterTheaterTapTarget? {
        for preset in UnderwaterTheaterTracks.TapCurrent.allCases {
            let flow = preset.sceneHint
            let delta = point - flow
            if delta.x * delta.x + delta.y * delta.y <= Self.tapHitRadius * Self.tapHitRadius {
                switch preset {
                case .westSeaweed: return .westSeaweed
                case .archRise: return .archRise
                case .shellLedge: return .shellLedge
                }
            }
        }
        return nil
    }

    public var fishVisible: Bool { fishProgress >= 0.001 }

    /// 巡游路径锚点 + 限幅偏航后的鱼群中心，供画面与测试读取。
    public func schoolCenter() -> (position: TheaterPoint, heading: Double, steerHeading: Double) {
        let sample = sampler().sample(fishProgress)
        let world = sample.position + fishOffset
        let steerHeading: Double
        let offsetMagSq = fishOffset.x * fishOffset.x + fishOffset.y * fishOffset.y
        if offsetMagSq > 0.0004 {
            steerHeading = atan2(fishOffset.y, fishOffset.x)
        } else {
            steerHeading = sample.heading
        }
        return (world, sample.heading, steerHeading)
    }

    private mutating func updateInteractionGate(folding: UnderwaterTheaterFolding) {
        canInteract = folding.coral >= 0.62 && folding.seabed >= 0.22 && folding.fish >= 0.35
    }

    private mutating func setNotice(_ value: UnderwaterTheaterNotice, until: Double) {
        notice = value
        noticeUntil = until
    }
}
