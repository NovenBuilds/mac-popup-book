import Foundation
import Metal
import PageBehavior
import PageWorkerKit
import PopupBookCore

@MainActor final class UnderwaterTheaterPage: RenderedBookPage {
    private let scene: UnderwaterTheaterScene
    private var gameplay = UnderwaterTheaterGameplay()
    private var pendingCurrentSound = false
    private var reefSound = false
    private var dragSound = false
    private var lastCurrentSound = -1.0
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
                let point = scene.flowPoint(x: event.x, y: event.y)
                let tap =
                    scene.pickTarget(x: event.x, y: event.y) ?? point.flatMap { gameplay.tapTarget(at: $0) }
                if let point,
                    hypot(point.x - gameplay.flowPoint.x, point.y - gameplay.flowPoint.y) < 0.11
                {
                    gameplay.beginDrag(at: point, folding: folding, now: context.clock)
                } else if let tap {
                    gameplay.handleTap(tap, folding: folding, now: context.clock)
                } else if let point {
                    gameplay.beginDrag(at: point, folding: folding, now: context.clock)
                } else {
                    return
                }
                pendingCurrentSound = gameplay.canInteract
            case .move, .drag:
                if let point = scene.flowPoint(x: event.x, y: event.y) {
                    gameplay.moveDrag(to: point, folding: folding)
                }
            case .up:
                gameplay.endDrag(now: context.clock)
            case .cancel:
                gameplay.cancelDrag()
            }
        case .cancel:
            gameplay.cancelDrag()
        case .action(let action):
            let target: UnderwaterTheaterTapTarget
            switch action {
            case "current-west": target = .westSeaweed
            case "current-arch": target = .archRise
            case "current-shell": target = .shellLedge
            default: return
            }
            gameplay.handleTap(target, folding: folding, now: context.clock)
            pendingCurrentSound = gameplay.canInteract
        }
    }

    func advance(_ context: WorldContext) throws -> PagePresentation {
        self.context = context
        let folding = UnderwaterTheaterFolding(progress: context.progress)
        gameplay.advance(
            bookProgress: context.progress, clock: context.clock, deltaTime: context.deltaTime,
            folding: folding)
        let zh = isChinese
        let shouldPlay =
            gameplay.canInteract && pendingCurrentSound && context.clock - lastCurrentSound > 0.20
        pendingCurrentSound = false
        if shouldPlay { lastCurrentSound = context.clock }
        var sounds = shouldPlay ? [PageSound("sea.current", .play)] : []
        let reefAudible = gameplay.reef.layer >= 1 && context.pageReady != false
        let dragAudible = reefAudible && gameplay.canInteract && gameplay.dragging
        if reefAudible != reefSound {
            sounds.append(PageSound("sea.reef", reefAudible ? .begin : .end, fade: 0.40))
            reefSound = reefAudible
        }
        if dragAudible != dragSound {
            sounds.append(PageSound("sea.drag", dragAudible ? .begin : .end, fade: 0.24))
            dragSound = dragAudible
        }
        var presentation = PagePresentation(
            caption: gameplay.caption(zh: zh),
            accessibility: message("海底剧场", "Underwater Theater"),
            actions: [
                PageAction(
                    "current-west", title: message("左侧浅流", "Seagrass current"), enabled: gameplay.canInteract,
                    shortcut: "w"),
                PageAction(
                    "current-arch", title: message("拱门水流", "Arch current"), enabled: gameplay.canInteract,
                    shortcut: "a"),
                PageAction(
                    "current-shell", title: message("贝壳水流", "Shell current"), enabled: gameplay.canInteract,
                    shortcut: "s"),
            ],
            sounds: sounds,
            hint: message(
                "拖动蓝色水流珠，看水纹和鱼群跟着转向。",
                "Drag the blue current bead and watch the ripples and fish turn with it."))
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
            folding: UnderwaterTheaterFolding(progress: context.progress), gameplay: gameplay,
            clock: context.clock)
    }

    func pause() -> Data? {
        gameplay.cancelDrag()
        pendingCurrentSound = false
        return nil
    }

    func finish() -> Data? { pause() }

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
