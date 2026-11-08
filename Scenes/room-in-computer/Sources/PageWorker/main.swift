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

    init() throws {
        scene = try RoomInComputerScene()
    }

    func prepare(_ startup: PageStartup) throws {
        scene.setViewport(CGSize(width: startup.width, height: startup.height))
        cancelInteraction()
        if let data = startup.state ?? startup.backup,
            let snapshot = try? JSONDecoder().decode(RoomInComputerSnapshot.self, from: data)
        {
            gameplay = RoomInComputerGameplay(restoredTime: snapshot.roomTime)
        }
    }

    func handle(_ input: PageInput) {
        switch input {
        case .cancel:
            cancelInteraction()
        case .pointer(let event):
            guard event.valid else { return }
            switch event.kind {
            case .down:
                if let target = scene.pickStrip(x: event.x, y: event.y) {
                    stripActive = true
                    gameplay.handleStrip(target)
                }
            case .drag, .move:
                guard stripActive else { return }
                if let target = scene.pickStrip(x: event.x, y: event.y) {
                    gameplay.handleStrip(target)
                } else {
                    gameplay.handleStrip(.dragX(event.x))
                }
            case .up, .cancel:
                if stripActive {
                    stripActive = false
                    gameplay.endStripDrag()
                }
            }
        case .action:
            break
        }
    }

    func advance(_ context: WorldContext) throws -> PagePresentation {
        self.context = context
        let folding = RoomInComputerFolding(progress: context.progress)
        gameplay.advance(deltaTime: context.deltaTime, folding: folding)
        let zh = isChinese
        return PagePresentation(
            caption: gameplay.caption(zh: zh),
            accessibility: message("住在电脑里的小屋", "Room in the Computer"))
    }

    func render(into texture: MTLTexture, command: MTLCommandBuffer, context: WorldContext) throws {
        self.context = context
        scene.setViewport(CGSize(width: texture.width, height: texture.height))
        try scene.render(
            into: texture, command: command,
            folding: RoomInComputerFolding(progress: context.progress), gameplay: gameplay)
    }

    func pause() -> Data? {
        cancelInteraction()
        return try? JSONEncoder().encode(gameplay.snapshot())
    }

    func finish() -> Data? {
        cancelInteraction()
        return try? JSONEncoder().encode(gameplay.snapshot())
    }

    private func cancelInteraction() {
        stripActive = false
        gameplay.cancelPointer()
    }

    private var isChinese: Bool {
        Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: Locale.preferredLanguages)
            .first == "zh-Hans"
    }

    private func message(_ zh: String, _ en: String) -> String { isChinese ? zh : en }
}

PageWorker.run { try RoomInComputerPage() }
