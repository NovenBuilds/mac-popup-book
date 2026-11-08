import Foundation

public enum MechanicalPlanetariumNotice: String, Equatable, Sendable {
    case needOpen
    case paused
    case resumed
    case steppedForward
    case steppedBack
    case snappedObservation
    case driveWhilePaused
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

public enum MechanicalPlanetariumAction {
    public static let stepBack = "step-back"
    public static let stepForward = "step-forward"
    public static let pauseToggle = "pause-toggle"
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

    public var canDriveMechanism: Bool { canInteract && !isPaused }

    public mutating func handleAction(
        _ id: String, folding: MechanicalPlanetariumFolding, now: Double
    ) {
        switch id {
        case MechanicalPlanetariumAction.stepBack:
            handleTap(.stepBack, folding: folding, now: now)
        case MechanicalPlanetariumAction.stepForward:
            handleTap(.stepForward, folding: folding, now: now)
        case MechanicalPlanetariumAction.pauseToggle:
            handleTap(.pauseToggle, folding: folding, now: now)
        default:
            break
        }
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
            guard canDriveMechanism else {
                rejectDriveWhilePaused(until: now)
                return
            }
            mechanism.turns -= Self.stepTurns
            setNotice(.steppedBack, until: now + 1.2)
        case .stepForward:
            guard canDriveMechanism else {
                rejectDriveWhilePaused(until: now)
                return
            }
            mechanism.turns += Self.stepTurns
            setNotice(.steppedForward, until: now + 1.2)
        case .pauseToggle:
            if isPaused {
                isPaused = false
                setNotice(.resumed, until: now + 1.4)
            } else {
                isPaused = true
                endCrankDrag()
                setNotice(.paused, until: now + 1.4)
            }
        case .observeNewMoon:
            snapObservation(index: 0, now: now)
        case .observeFirstQuarter:
            snapObservation(index: 1, now: now)
        case .observeFullMoon:
            snapObservation(index: 2, now: now)
        }
    }

    public mutating func beginCrankDrag(x: Double, folding: MechanicalPlanetariumFolding, now: Double) {
        updateInteractionGate(folding: folding)
        guard canInteract else {
            setNotice(.needOpen, until: now + 2)
            return
        }
        guard canDriveMechanism else {
            rejectDriveWhilePaused(until: now)
            return
        }
        draggingCrank = true
        dragAnchorX = x
    }

    public mutating func updateCrankDrag(x: Double) {
        guard canDriveMechanism, draggingCrank, let anchor = dragAnchorX else { return }
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
        if isPaused {
            return zh
                ? "已暂停，\(phase)定格。点恢复或下方控制再继续。"
                : "Paused at \(phase). Resume or use the controls below to continue."
        }
        return zh
            ? "拖动曲柄或点按步进。当前\(phase)，运行中。"
            : "Drag the crank or tap step controls. \(phase), running."
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

    public func presentationActions(zh: Bool) -> [(id: String, title: String, enabled: Bool)] {
        let drive = canDriveMechanism
        let pauseTitle =
            isPaused
            ? (zh ? "恢复" : "Resume")
            : (zh ? "暂停" : "Pause")
        return [
            (MechanicalPlanetariumAction.stepBack, zh ? "后退" : "Step back", drive),
            (MechanicalPlanetariumAction.stepForward, zh ? "前进" : "Step forward", drive),
            (MechanicalPlanetariumAction.pauseToggle, pauseTitle, canInteract),
        ]
    }

    private mutating func snapObservation(index: Int, now: Double) {
        mechanism.snapToObservation(index)
        isPaused = true
        endCrankDrag()
        setNotice(.snappedObservation, until: now + 3)
    }

    private mutating func rejectDriveWhilePaused(until: Double) {
        setNotice(.driveWhilePaused, until: until + 1.6)
    }

    private mutating func updateInteractionGate(folding: MechanicalPlanetariumFolding) {
        canInteract = folding.canDrive
    }

    private mutating func setNotice(_ value: MechanicalPlanetariumNotice, until: Double) {
        notice = value
        noticeUntil = until
    }
}
