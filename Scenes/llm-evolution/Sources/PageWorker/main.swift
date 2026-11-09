import Foundation
import Metal
import PageBehavior
import PageWorkerKit
import PopupBookCore

@MainActor final class LLMEvolutionPage: RenderedBookPage {
    private let scene: LLMEvolutionScene
    private var gameplay = LLMEvolutionGameplay()
    private var pendingCue = false
    private var lastCueTime = -1.0
    private var context = WorldContext(progress: 0, clock: 0, deltaTime: 0, stableDuration: 0)

    init() throws {
        scene = try LLMEvolutionScene(zh: Self.isChinese)
    }

    func prepare(_ startup: PageStartup) throws {
        scene.setViewport(CGSize(width: startup.width, height: startup.height))
    }

    func handle(_ input: PageInput) {
        let folding = LLMEvolutionFolding(progress: context.progress)
        let previous = gameplay
        defer {
            if gameplay.canInteract
                && (gameplay.noticeUntil != previous.noticeUntil
                    || gameplay.showSource != previous.showSource)
            {
                pendingCue = true
            }
        }
        switch input {
        case .pointer(let event):
            guard event.kind == .down, event.valid else { return }
            guard let target = scene.pickTarget(x: event.x, y: event.y) else { return }
            gameplay.handleTap(target, folding: folding, now: context.clock)
        case .action(let action):
            gameplay.handleAction(action, folding: folding, now: context.clock)
        case .cancel:
            break
        }
    }

    func advance(_ context: WorldContext) throws -> PagePresentation {
        self.context = context
        let folding = LLMEvolutionFolding(progress: context.progress)
        gameplay.advance(
            bookProgress: context.progress, clock: context.clock, deltaTime: context.deltaTime,
            folding: folding)
        let zh = Self.isChinese
        let canUse = gameplay.canInteract
        let shouldPlay = pendingCue && canUse && context.clock - lastCueTime > 0.15
        pendingCue = false
        if shouldPlay { lastCueTime = context.clock }
        var presentation = PagePresentation(
            caption: gameplay.caption(zh: zh) + " — " + gameplay.detailCaption(zh: zh),
            accessibility: message("文字如何长出能力", "How Text Grows Into Capability"),
            actions: [
                PageAction(
                    "next-example", title: message("下一例子", "Next sample"), enabled: canUse, shortcut: "e"),
                PageAction(
                    "next-booth", title: message("下一展台", "Next booth"), enabled: canUse, shortcut: "b"),
                PageAction(
                    "toggle-source", title: message("切换来源", "Toggle sources"), enabled: canUse,
                    shortcut: "s"),
            ],
            sounds: shouldPlay ? [PageSound("exhibit.paper", .play)] : [])
        presentation.notice = noticeText(zh: zh)
        return presentation
    }

    func render(into texture: MTLTexture, command: MTLCommandBuffer, context: WorldContext) throws {
        self.context = context
        scene.setViewport(CGSize(width: texture.width, height: texture.height))
        let folding = LLMEvolutionFolding(progress: context.progress)
        try scene.render(
            into: texture, command: command, folding: folding, gameplay: gameplay, clock: context.clock)
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

    private func noticeText(zh: Bool) -> String? {
        if let notice = gameplay.notice {
            switch notice {
            case .needOpen:
                return zh ? gameplay.introduction(zh: true) : gameplay.introduction(zh: false)
            case .pickedExample:
                return zh
                    ? "已选例子：\(LLMEvolutionExhibit.exampleLabel(gameplay.selectedExample, zh: true))"
                    : "Sample: \(LLMEvolutionExhibit.exampleLabel(gameplay.selectedExample, zh: false))"
            case .pickedBooth:
                return zh
                    ? "已选展台：\(LLMEvolutionExhibit.boothLabel(gameplay.selectedBooth, zh: true))"
                    : "Booth: \(LLMEvolutionExhibit.boothLabel(gameplay.selectedBooth, zh: false))"
            }
        }
        return gameplay.canInteract ? gameplay.introduction(zh: zh) : nil
    }
}

PageWorker.run { try LLMEvolutionPage() }
