import Foundation
import Metal
import PageBehavior
import PageWorkerKit
import PopupBookCore

@MainActor final class RoomInComputerPage: RenderedBookPage {
    private let scene: RoomInComputerScene
    private var gameplay = RoomInComputerGameplay()
    private var context = WorldContext(progress: 0, clock: 0, deltaTime: 0, stableDuration: 0)
    private var stripActive = false
    private var canSave = true
    private var restoreNotice: String?
    private var pendingStripSound = false
    private var lastStripSound = -1.0

    init() throws {
        scene = try RoomInComputerScene(guestAppearance: RoomGuestAppearance())
    }

    func prepare(_ startup: PageStartup) throws {
        scene.setViewport(CGSize(width: startup.width, height: startup.height))
        cancelInteraction()
        let restored = RoomInComputerSave.restore(state: startup.state, backup: startup.backup)
        gameplay = restored.gameplay
        canSave = restored.canSave
        restoreNotice = restored.notice.map { noticeText($0) }
    }

    func handle(_ input: PageInput) {
        let phaseBefore = RoomInComputerGameplay.phase(for: gameplay.roomTime)
        let canUseStrip =
            RoomInComputerFolding(progress: context.progress).canChangeTime
        defer {
            if RoomInComputerGameplay.phase(for: gameplay.roomTime) != phaseBefore {
                pendingStripSound = true
            }
        }
        switch input {
        case .cancel:
            cancelInteraction()
        case .pointer(let event):
            guard event.valid else { return }
            if !canUseStrip {
                cancelInteraction()
                return
            }
            switch event.kind {
            case .down:
                if let target = scene.pickStrip(x: event.x, y: event.y) {
                    stripActive = true
                    gameplay.handleStrip(target)
                }
            case .drag, .move:
                guard stripActive else { return }
                guard let target = scene.pickStrip(x: event.x, y: event.y) else { return }
                gameplay.handleStrip(target)
            case .up, .cancel:
                if stripActive {
                    stripActive = false
                    gameplay.endStripDrag()
                }
            }
        case .action(let action):
            guard canUseStrip else { return }
            switch action {
            case "room-dawn": gameplay.handleStrip(.dockMorning)
            case "room-afternoon": gameplay.handleStrip(.dockAfternoon)
            case "room-night": gameplay.handleStrip(.dockEvening)
            default: return
            }
        }
    }

    func advance(_ context: WorldContext) throws -> PagePresentation {
        self.context = context
        let folding = RoomInComputerFolding(progress: context.progress)
        gameplay.advance(deltaTime: context.deltaTime, folding: folding)
        let zh = isChinese
        let canUseStrip = folding.canChangeTime
        let shouldPlay = canUseStrip && pendingStripSound && context.clock - lastStripSound > 0.19
        pendingStripSound = false
        if shouldPlay { lastStripSound = context.clock }
        return PagePresentation(
            caption: gameplay.caption(zh: zh),
            accessibility: message("窗边小屋", "Window Nook"),
            actions: [
                PageAction("room-dawn", title: message("清晨", "Dawn"), enabled: canUseStrip),
                PageAction("room-afternoon", title: message("午后", "Afternoon"), enabled: canUseStrip),
                PageAction("room-night", title: message("夜晚", "Night"), enabled: canUseStrip),
            ],
            sounds: shouldPlay ? [PageSound("room.strip", .play)] : [],
            checkpoint: RoomInComputerSave.checkpoint(from: gameplay, canSave: canSave),
            canSave: canSave,
            notice: restoreNotice)
    }

    func render(into texture: MTLTexture, command: MTLCommandBuffer, context: WorldContext) throws {
        self.context = context
        scene.setViewport(CGSize(width: texture.width, height: texture.height))
        try scene.render(
            into: texture, command: command,
            folding: RoomInComputerFolding(progress: context.progress), gameplay: gameplay, context: context)
    }

    func pause() -> Data? {
        cancelInteraction()
        return RoomInComputerSave.pausePayload(from: gameplay, canSave: canSave)
    }

    func finish() -> Data? {
        cancelInteraction()
        return RoomInComputerSave.pausePayload(from: gameplay, canSave: canSave)
    }

    private func cancelInteraction() {
        stripActive = false
        pendingStripSound = false
        gameplay.cancelPointer()
    }

    private func noticeText(_ key: RoomSaveNoticeKey) -> String {
        switch key {
        case .backupRestored:
            return message("已从备份恢复房间时光。", "Room time restored from backup.")
        case .saveProtected:
            return message("原存档已保留，本次仍可拨动时光。", "Your save is safe. You can still move time.")
        case .futureMainReadOnly:
            return message(
                "主存档为更高版本，已用备份显示且不会写回。",
                "Main save uses a newer format; backup is shown read-only.")
        }
    }

    private var isChinese: Bool {
        Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: Locale.preferredLanguages)
            .first == "zh-Hans"
    }

    private func message(_ zh: String, _ en: String) -> String { isChinese ? zh : en }
}

PageWorker.run { try RoomInComputerPage() }
