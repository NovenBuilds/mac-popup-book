import Foundation
import Metal
import PageBehavior
import PageWorkerKit
import PopupBookCore

@MainActor final class LLMEvolutionPage: RenderedBookPage {
    private let scene: LLMEvolutionScene
    private var gameplay = LLMEvolutionGameplay()
    private var pendingCue = false

    init() throws { scene = try LLMEvolutionScene(zh: Self.isChinese) }

    func prepare(_ startup: PageStartup) throws {
        scene.setViewport(CGSize(width: startup.width, height: startup.height))
    }

    func handle(_ input: PageInput) {
        switch input {
        case .pointer(let event):
            guard event.kind == .down, event.valid, scene.pickedSource(x: event.x, y: event.y) else { return }
            pendingCue = gameplay.handleAction("toggle-source") || pendingCue
        case .action(let action):
            pendingCue = gameplay.handleAction(action) || pendingCue
        case .cancel: break
        }
    }

    func advance(_ context: WorldContext) throws -> PagePresentation {
        let oldAct = gameplay.act
        gameplay.advance(progress: context.progress, deltaTime: context.deltaTime)
        let zh = Self.isChinese
        let canUse = gameplay.canInteract
        let shouldPlay = canUse && (pendingCue || gameplay.act != oldAct)
        pendingCue = false
        var presentation = PagePresentation(
            caption: gameplay.caption(zh: zh),
            accessibility: message("字间工坊", "Letter Workshop"),
            actions: [
                PageAction(
                    "show-toggle",
                    title: gameplay.userPaused ? message("继续", "Continue") : message("暂停", "Pause"),
                    enabled: canUse && !gameplay.finished, shortcut: "p"),
                PageAction("show-replay", title: message("重播", "Replay"), enabled: canUse, shortcut: "r"),
                PageAction(
                    "show-previous", title: message("上一幕", "Previous act"),
                    enabled: canUse && gameplay.act > 0),
                PageAction(
                    "show-next", title: message("下一幕", "Next act"), enabled: canUse && gameplay.act < 2),
                PageAction(
                    "toggle-source",
                    title: gameplay.showSource
                        ? message("收起说明", "Close notes") : message("说明与来源", "Notes and sources"),
                    enabled: canUse, shortcut: "s"),
            ],
            sounds: shouldPlay ? [PageSound("exhibit.paper", .play)] : [])
        if gameplay.showSource && canUse {
            presentation.notice = gameplay.detail(zh: zh)
        }
        return presentation
    }

    func render(into texture: MTLTexture, command: MTLCommandBuffer, context: WorldContext) throws {
        scene.setViewport(CGSize(width: texture.width, height: texture.height))
        try scene.render(
            into: texture, command: command, folding: LLMEvolutionFolding(progress: context.progress),
            gameplay: gameplay)
    }

    func pause() -> Data? {
        pendingCue = false
        return nil
    }
    func finish() -> Data? { pause() }

    private static var isChinese: Bool {
        Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: Locale.preferredLanguages)
            .first == "zh-Hans"
    }

    private func message(_ zh: String, _ en: String) -> String { Self.isChinese ? zh : en }
}

PageWorker.run { try LLMEvolutionPage() }
