import Foundation
import Metal
import PageBehavior
import PageWorkerKit
import PopupBookCore

@MainActor final class PocketTownPage: RenderedBookPage {
    private let scene: PocketTownScene

    init() throws {
        scene = try PocketTownScene()
    }

    func prepare(_ startup: PageStartup) throws {}
    func handle(_ input: PageInput) {}

    func advance(_ context: WorldContext) throws -> PagePresentation {
        let name = message("口袋小镇", "Pocket Town")
        return PagePresentation(caption: name, accessibility: name)
    }

    func render(into texture: MTLTexture, command: MTLCommandBuffer, context: WorldContext) throws {
        try scene.render(
            into: texture, command: command, folding: PocketTownFolding(progress: context.progress))
    }

    func pause() -> Data? { nil }
    func finish() -> Data? { nil }

    func message(_ zh: String, _ en: String) -> String {
        Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: Locale.preferredLanguages)
            .first == "zh-Hans" ? zh : en
    }
}

PageWorker.run { try PocketTownPage() }
