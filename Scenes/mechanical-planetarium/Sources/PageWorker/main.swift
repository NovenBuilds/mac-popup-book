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

    init() throws {
        scene = try MechanicalPlanetariumScene()
    }

    func prepare(_ startup: PageStartup) throws {
        scene.setViewport(CGSize(width: startup.width, height: startup.height))
    }

    func handle(_ input: PageInput) {
        switch input {
        case .pointer(let event):
            guard event.valid else { return }
            let folding = MechanicalPlanetariumFolding(progress: context.progress)
            switch event.kind {
            case .down:
                guard let target = scene.pickTarget(x: event.x, y: event.y) else { return }
                if target == .crank {
                    gameplay.beginCrankDrag(x: event.x, folding: folding, now: context.clock)
                    crankDragActive = true
                } else {
                    gameplay.handleTap(target, folding: folding, now: context.clock)
                }
            case .drag, .move:
                guard crankDragActive else { return }
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
        case .action:
            break
        }
    }

    func advance(_ context: WorldContext) throws -> PagePresentation {
        self.context = context
        let folding = MechanicalPlanetariumFolding(progress: context.progress)
        gameplay.advance(clock: context.clock, deltaTime: context.deltaTime, folding: folding)
        let zh = isChinese
        var caption = gameplay.caption(zh: zh) + " " + gameplay.disclaimer(zh: zh)
        if let observation = gameplay.observationCaption(zh: zh) {
            caption += zh ? " \(observation)" : " \(observation)"
        }
        var presentation = PagePresentation(
            caption: caption,
            accessibility: message("机械天文馆", "Mechanical Planetarium"))
        if let notice = gameplay.notice {
            presentation.notice = noticeText(notice, zh: zh)
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
        clearPointerInteraction()
        return nil
    }

    func finish() -> Data? {
        clearPointerInteraction()
        return nil
    }

    private func clearPointerInteraction() {
        gameplay.cancelInteraction()
        crankDragActive = false
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
            return zh ? "已暂停，仍可拖动曲柄微调。" : "Paused; you can still fine-tune with the crank."
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
