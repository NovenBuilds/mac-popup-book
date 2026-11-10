import Foundation
import Metal
import PageBehavior
import PageWorkerKit
import PopupBookCore

@MainActor final class MechanicalPlanetariumPage: RenderedBookPage {
    private let scene: MechanicalPlanetariumScene
    private var gameplay = MechanicalPlanetariumGameplay()
    private var context = WorldContext(progress: 0, clock: 0, deltaTime: 0, stableDuration: 0)
    private var crankDragActive = false
    private var canSave = true
    private var lastClickTime = -1.0
    private var lastClickTurns = 0.0
    private var pendingClick = false
    private var driveSound = false

    init() throws {
        scene = try MechanicalPlanetariumScene()
    }

    func prepare(_ startup: PageStartup) throws {
        scene.setViewport(CGSize(width: startup.width, height: startup.height))
        let restored = MechanicalPlanetariumSave.restore(state: startup.state, backup: startup.backup)
        gameplay = restored.gameplay
        canSave = restored.canSave
        lastClickTurns = gameplay.mechanism.turns
    }

    func handle(_ input: PageInput) {
        let wasPaused = gameplay.isPaused
        defer {
            if gameplay.isPaused != wasPaused || abs(gameplay.mechanism.turns - lastClickTurns) >= 0.075 {
                pendingClick = true
                lastClickTurns = gameplay.mechanism.turns
            }
        }
        switch input {
        case .pointer(let event):
            guard event.valid else { return }
            let folding = MechanicalPlanetariumFolding(progress: context.progress)
            switch event.kind {
            case .down:
                guard let target = scene.pickTarget(x: event.x, y: event.y) else { return }
                if target == .crank {
                    gameplay.beginCrankDrag(x: event.x, folding: folding, now: context.clock)
                    crankDragActive = gameplay.draggingCrank
                } else {
                    gameplay.handleTap(target, folding: folding, now: context.clock)
                }
            case .drag, .move:
                guard crankDragActive, gameplay.canDriveMechanism else { return }
                gameplay.updateCrankDrag(x: event.x)
            case .up:
                if crankDragActive {
                    gameplay.endCrankDrag()
                    crankDragActive = false
                }
            case .cancel:
                gameplay.cancelInteraction()
                crankDragActive = false
            }
        case .cancel:
            gameplay.cancelInteraction()
            crankDragActive = false
        case .action(let action):
            let folding = MechanicalPlanetariumFolding(progress: context.progress)
            gameplay.handleAction(action, folding: folding, now: context.clock)
            if gameplay.isPaused {
                crankDragActive = false
            }
        }
    }

    func advance(_ context: WorldContext) throws -> PagePresentation {
        self.context = context
        let folding = MechanicalPlanetariumFolding(progress: context.progress)
        gameplay.advance(clock: context.clock, deltaTime: context.deltaTime, folding: folding)
        let zh = isChinese
        var caption = gameplay.caption(zh: zh) + " " + gameplay.disclaimer(zh: zh)
        if let observation = gameplay.observationCaption(zh: zh) {
            caption += " \(observation)"
        }
        let keys = [
            "step-back": "b", "step-forward": "f", "pause-toggle": "p",
            "observe-new": "n", "observe-quarter": "q", "observe-full": "m",
        ]
        let actions = gameplay.presentationActions(zh: zh).map {
            PageAction($0.id, title: $0.title, enabled: $0.enabled, shortcut: keys[$0.id])
        }
        let shouldClick = pendingClick && gameplay.canInteract && context.clock - lastClickTime > 0.16
        pendingClick = false
        if shouldClick { lastClickTime = context.clock }
        var sounds = shouldClick ? [PageSound("planet.detent", .play)] : []
        let driveAudible =
            gameplay.canInteract && !gameplay.isPaused && context.pageReady != false
            && (gameplay.automaticDrive || gameplay.draggingCrank)
        if driveAudible != driveSound {
            sounds.append(PageSound("planet.drive", driveAudible ? .begin : .end, fade: 0.30))
            driveSound = driveAudible
        }
        var presentation = PagePresentation(
            caption: caption,
            accessibility: message("机械天文馆", "Mechanical Planetarium"),
            actions: actions,
            sounds: sounds,
            checkpoint: savedState(),
            canSave: canSave,
            hint: message(
                "拖动黄铜曲柄转动天体，点月相按钮停在观察点。",
                "Drag the brass crank, or click a Moon phase to stop at that view."))
        if let notice = gameplay.notice {
            presentation.notice = noticeText(notice, zh: zh)
        } else if !canSave {
            presentation.notice = message(
                "当前存档已保护，仍可操作机关。", "Saved position is protected. You can still use the mechanism.")
        }
        return presentation
    }

    func render(into texture: MTLTexture, command: MTLCommandBuffer, context: WorldContext) throws {
        self.context = context
        scene.setViewport(CGSize(width: texture.width, height: texture.height))
        try scene.render(
            into: texture, command: command,
            folding: MechanicalPlanetariumFolding(progress: context.progress), gameplay: gameplay)
    }

    func pause() -> Data? {
        gameplay.cancelInteraction()
        crankDragActive = false
        pendingClick = false
        return savedState()
    }

    func finish() -> Data? { pause() }

    private func savedState() -> Data? {
        canSave ? MechanicalPlanetariumSave(gameplay: gameplay).encoded() : nil
    }

    private var isChinese: Bool {
        Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: Locale.preferredLanguages)
            .first == "zh-Hans"
    }

    func message(_ zh: String, _ en: String) -> String { isChinese ? zh : en }

    private func noticeText(_ notice: MechanicalPlanetariumNotice, zh: Bool) -> String {
        switch notice {
        case .needOpen:
            return zh ? "先展开支架与轨道，再转动曲柄。" : "Open the brackets and orbits before turning the crank."
        case .paused:
            return zh ? "机关已暂停。" : "Mechanism paused."
        case .driveWhilePaused:
            return zh ? "已暂停，先点恢复再拖动或步进。" : "Paused. Resume before turning or stepping."
        case .resumed:
            return zh ? "继续观察。" : "Observation resumed."
        case .steppedForward:
            return zh ? "曲柄前进一小步。" : "Crank stepped forward."
        case .steppedBack:
            return zh ? "曲柄倒退一小步。" : "Crank stepped back."
        case .snappedObservation:
            return zh ? "已停靠到观察点。" : "Snapped to an observation stop."
        }
    }
}

PageWorker.run { try MechanicalPlanetariumPage() }
