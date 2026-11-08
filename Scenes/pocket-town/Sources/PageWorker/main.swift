import Foundation
import Metal
import PageBehavior
import PageWorkerKit
import PopupBookCore

@MainActor final class PocketTownPage: RenderedBookPage {
    private let scene: PocketTownScene
    private var gameplay = PocketTownGameplay()
    private var context = WorldContext(progress: 0, clock: 0, deltaTime: 0, stableDuration: 0)

    init() throws {
        scene = try PocketTownScene()
    }

    func prepare(_ startup: PageStartup) throws {
        scene.setViewport(CGSize(width: startup.width, height: startup.height))
    }

    func handle(_ input: PageInput) {
        guard case .pointer(let event) = input, event.kind == .down, event.valid else { return }
        guard let target = scene.pickTarget(x: event.x, y: event.y) else { return }
        let folding = PocketTownFolding(progress: context.progress)
        gameplay.handleTap(target, folding: folding, now: context.clock)
    }

    func advance(_ context: WorldContext) throws -> PagePresentation {
        self.context = context
        let folding = PocketTownFolding(progress: context.progress)
        gameplay.advance(
            bookProgress: context.progress, clock: context.clock, deltaTime: context.deltaTime,
            folding: folding)
        let zh = isChinese
        var presentation = PagePresentation(
            caption: gameplay.caption(zh: zh),
            accessibility: message("口袋小镇", "Pocket Town"))
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
            folding: PocketTownFolding(progress: context.progress), gameplay: gameplay)
    }

    func pause() -> Data? { nil }
    func finish() -> Data? { nil }

    private var isChinese: Bool {
        Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: Locale.preferredLanguages)
            .first == "zh-Hans"
    }

    func message(_ zh: String, _ en: String) -> String { isChinese ? zh : en }

    private func noticeText(_ notice: PocketTownNotice, zh: Bool) -> String {
        switch notice {
        case .needOpen:
            return zh ? "先展开书页，再调度小火车。" : "Open the page before running the train."
        case .switchBlocked:
            return zh ? "火车经过道岔时不能切换。" : "Wait until the switch is clear."
        case .trainBusy:
            return zh ? "火车还在路上。" : "The train is still on its route."
        case .selectedRiverside:
            return zh ? "已切到河岸线。" : "Riverside loop selected."
        case .selectedClockTower:
            return zh ? "已切到钟楼线。" : "Clock tower loop selected."
        }
    }
}

PageWorker.run { try PocketTownPage() }
