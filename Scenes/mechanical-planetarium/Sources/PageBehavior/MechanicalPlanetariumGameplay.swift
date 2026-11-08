import Foundation

public enum MechanicalPlanetariumNotice: String, Equatable, Sendable {
    case needOpen
    case paused
    case resumed
    case steppedForward
    case steppedBack
    case snappedObservation
}

public enum MechanicalPlanetariumTapTarget: Equatable, Sendable {
    case crank
    case stepBack
    case stepForward
    case pauseToggle
    case observeNewMoon
    case observeFirstQuarter
    case observeFullMoon
}

public struct MechanicalPlanetariumGameplay: Equatable, Sendable {
    public var mechanism: MechanicalPlanetariumMechanism
    public var isPaused: Bool
    public private(set) var draggingCrank: Bool
    public private(set) var dragAnchorX: Double?
    public var notice: MechanicalPlanetariumNotice?
    public var noticeUntil: Double
    public private(set) var canInteract: Bool

    public static let dragTurnsPerUnit = 1.4
    public static let stepTurns = 0.08
    public static let observationHints: [(zh: String, en: String)] = [
        ("新月：月球落在太阳与地球之间，夜侧朝向咱们。", "New moon: Moon sits between Sun and Earth; night face toward us."),
        ("上弦：一半被太阳照亮，像被点亮的半块搪瓷。", "First quarter: Half the moon is sunlit like enameled metal."),
        ("满月：地球在中间，整圈朝向太阳的一面都亮起来。", "Full moon: Earth is in the middle; the sun-facing side is fully lit."),
    ]

    public init() {
        mechanism = MechanicalPlanetariumMechanism()
        isPaused = false
        draggingCrank = false
        dragAnchorX = nil
        notice = nil
        noticeUntil = 0
        canInteract = false
    }

    public mutating func handleTap(
        _ target: MechanicalPlanetariumTapTarget, folding: MechanicalPlanetariumFolding, now: Double
    ) {
        updateInteractionGate(folding: folding)
        guard canInteract else {
            setNotice(.needOpen, until: now + 2)
            return
        }

        switch target {
        case .crank:
            break
        case .stepBack:
            mechanism.turns -= Self.stepTurns
            setNotice(.steppedBack, until: now + 1.2)
        case .stepForward:
            mechanism.turns += Self.stepTurns
            setNotice(.steppedForward, until: now + 1.2)
        case .pauseToggle:
            isPaused.toggle()
            setNotice(isPaused ? .paused : .resumed, until: now + 1.4)
        case .observeNewMoon:
            mechanism.snapToObservation(0)
            setNotice(.snappedObservation, until: now + 3)
        case .observeFirstQuarter:
            mechanism.snapToObservation(1)
            setNotice(.snappedObservation, until: now + 3)
        case .observeFullMoon:
            mechanism.snapToObservation(2)
            setNotice(.snappedObservation, until: now + 3)
        }
    }

    public mutating func beginCrankDrag(x: Double, folding: MechanicalPlanetariumFolding, now: Double) {
        updateInteractionGate(folding: folding)
        guard canInteract else {
            setNotice(.needOpen, until: now + 2)
            return
        }
        draggingCrank = true
        dragAnchorX = x
    }

    public mutating func updateCrankDrag(x: Double) {
        guard draggingCrank, let anchor = dragAnchorX else { return }
        let delta = x - anchor
        guard delta.isFinite, abs(delta) > 1e-6 else { return }
        mechanism.turns += delta * Self.dragTurnsPerUnit
        dragAnchorX = x
    }

    public mutating func endCrankDrag() {
        draggingCrank = false
        dragAnchorX = nil
    }

    public mutating func cancelInteraction() {
        endCrankDrag()
    }

    public mutating func advance(
        clock: Double, deltaTime: Double, folding: MechanicalPlanetariumFolding
    ) {
        _ = deltaTime
        updateInteractionGate(folding: folding)
        if clock >= noticeUntil { notice = nil }
    }

    public func caption(zh: Bool) -> String {
        if !canInteract {
            return zh ? "机械天文馆" : "Mechanical Planetarium"
        }
        let phase = mechanism.lunarPhaseName(zh: zh)
        let pause = isPaused ? (zh ? "已暂停" : "Paused") : (zh ? "运行中" : "Running")
        return zh
            ? "拖动曲柄或点按左右步进。当前\(phase)，\(pause)。"
            : "Drag the crank or tap step controls. \(phase), \(pause)."
    }

    public func disclaimer(zh: Bool) -> String {
        zh
            ? "机械示意：尺寸、距离与速度经过压缩。"
            : "Mechanical model: sizes, distances and speeds are compressed."
    }

    public func observationCaption(zh: Bool) -> String? {
        guard let index = mechanism.nearestObservationIndex() else { return nil }
        let hint = Self.observationHints[index]
        return zh ? hint.zh : hint.en
    }

    private mutating func updateInteractionGate(folding: MechanicalPlanetariumFolding) {
        canInteract = folding.canDrive
    }

    private mutating func setNotice(_ value: MechanicalPlanetariumNotice, until: Double) {
        notice = value
        noticeUntil = until
    }
}
