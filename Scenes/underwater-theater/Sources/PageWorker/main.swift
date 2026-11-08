import Foundation
import Metal
import PageBehavior
import PageWorkerKit
import PopupBookCore

@MainActor final class UnderwaterTheaterPage: RenderedBookPage {
    private let scene: UnderwaterTheaterScene
    private var gameplay = UnderwaterTheaterGameplay()
    private var context = WorldContext(progress: 0, clock: 0, deltaTime: 0, stableDuration: 0)

    init() throws {
        scene = try UnderwaterTheaterScene()
    }

    func prepare(_ startup: PageStartup) throws {
        scene.setViewport(CGSize(width: startup.width, height: startup.height))
    }

    func handle(_ input: PageInput) {
        let folding = UnderwaterTheaterFolding(progress: context.progress)
        switch input {
        case .pointer(let event):
            guard event.valid else { return }
            switch event.kind {
            case .down:
                let tap =
                    scene.pickTarget(x: event.x, y: event.y) ?? gameplay.tapTarget(at: event.x, y: event.y)
                if let tap {
                    gameplay.handleTap(tap, folding: folding, now: context.clock)
                } else {
                    gameplay.beginDrag(x: event.x, y: event.y, folding: folding, now: context.clock)
                }
            case .move, .drag:
                gameplay.moveDrag(x: event.x, y: event.y, folding: folding)
            case .up:
                gameplay.endDrag(now: context.clock)
            case .cancel:
                gameplay.cancelDrag()
            }
        case .cancel:
            gameplay.cancelDrag()
        case .action:
            break
        }
    }

    func advance(_ context: WorldContext) throws -> PagePresentation {
        self.context = context
        let folding = UnderwaterTheaterFolding(progress: context.progress)
        gameplay.advance(
            bookProgress: context.progress, clock: context.clock, deltaTime: context.deltaTime,
            folding: folding)
        let zh = isChinese
        var presentation = PagePresentation(
            caption: gameplay.caption(zh: zh),
            accessibility: message("海底剧场", "Underwater Theater"))
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
            folding: UnderwaterTheaterFolding(progress: context.progress), gameplay: gameplay)
    }

    func pause() -> Data? {
        gameplay.cancelDrag()
        return nil
    }

    func finish() -> Data? { nil }

    private var isChinese: Bool {
        Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: Locale.preferredLanguages)
            .first == "zh-Hans"
    }

    private func message(_ zh: String, _ en: String) -> String { isChinese ? zh : en }

    private func noticeText(_ notice: UnderwaterTheaterNotice, zh: Bool) -> String {
        switch notice {
        case .needOpen:
            return zh ? "先展开海床与珊瑚，再引导鱼群。" : "Open the seabed and coral before guiding the fish."
        case .flowActive:
            return zh ? "水流散去，鱼群继续巡游。" : "The flow fades; the school keeps cruising."
        case .westCurrent:
            return zh ? "左侧海草间亮起一道浅流。" : "A gentle current stirs by the seaweed."
        case .archCurrent:
            return zh ? "拱门上方向下铺开一缕水纹。" : "A ripple spreads above the coral arch."
        case .shellCurrent:
            return zh ? "贝壳台旁涌出一股引导流。" : "A guiding current rises beside the shell."
        }
    }
}

PageWorker.run { try UnderwaterTheaterPage() }
