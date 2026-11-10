import Foundation
import Metal
import PageBehavior
import PageWorkerKit
import PopupBookCore

@MainActor final class PocketTownPage: RenderedBookPage {
    private let scene: PocketTownScene
    private var gameplay = PocketTownGameplay()
    private var pendingSounds: [PageSound] = []
    private var runningSound = false
    private var nearBridge = false
    private var nearClock = false
    private var context = WorldContext(progress: 0, clock: 0, deltaTime: 0, stableDuration: 0)

    init() throws {
        scene = try PocketTownScene()
    }

    func prepare(_ startup: PageStartup) throws {
        scene.setViewport(CGSize(width: startup.width, height: startup.height))
    }

    func handle(_ input: PageInput) {
        let target: PocketTownTapTarget?
        switch input {
        case .pointer(let event) where event.kind == .down && event.valid:
            target = scene.pickTarget(x: event.x, y: event.y)
        case .action("town-switch"):
            target = .switchRail
        case .action("town-depart"):
            target = .station
        default:
            return
        }
        guard let target else { return }
        let oldRoute = gameplay.selectedRoute
        let wasRunning = gameplay.trainIsRunning
        let folding = PocketTownFolding(progress: context.progress)
        gameplay.handleTap(target, folding: folding, now: context.clock)
        if oldRoute != gameplay.selectedRoute { pendingSounds.append(PageSound("town.switch", .play)) }
        if !wasRunning && gameplay.trainIsRunning { pendingSounds.append(PageSound("town.depart", .play)) }
    }

    func advance(_ context: WorldContext) throws -> PagePresentation {
        self.context = context
        let folding = PocketTownFolding(progress: context.progress)
        let wasRunning = gameplay.trainIsRunning
        let angle: Double?
        switch context.inputState {
        case .tracking: angle = context.lidAngle
        case .unavailable: angle = nil
        case .manual: angle = 35 + 70 * context.progress
        case nil: angle = context.lidAngle ?? (35 + 70 * context.progress)
        }
        let arrived = gameplay.advance(
            bookProgress: context.progress, clock: context.clock, deltaTime: context.deltaTime,
            folding: folding, lidAngle: context.pageReady == false ? 0 : angle)
        if !wasRunning && gameplay.trainIsRunning {
            pendingSounds.append(PageSound("town.depart", .play))
        }
        if arrived {
            pendingSounds.append(PageSound("town.arrive", .play))
        }
        let moving = gameplay.trainIsMoving && context.pageReady != false
        if moving != runningSound {
            pendingSounds.append(PageSound("town.running", moving ? .begin : .end, fade: 0.18))
            runningSound = moving
        }
        let train = gameplay.sampler().sample(gameplay.routeProgress).position
        let crossingBridge = moving && abs(train.x + 0.25) < 0.29
        let passingClock =
            moving && gameplay.displayRoute == .clockTower
            && hypot(train.x + 0.76, train.y - 0.94) < 0.19
        if crossingBridge && !nearBridge { pendingSounds.append(PageSound("town.bridge", .play)) }
        if passingClock && !nearClock { pendingSounds.append(PageSound("town.clock", .play)) }
        nearBridge = crossingBridge
        nearClock = passingClock
        let zh = isChinese
        let sounds =
            context.progress >= PocketTownGameplay.foldedResetProgress
            ? pendingSounds : pendingSounds.filter { $0.operation == .end }
        pendingSounds.removeAll(keepingCapacity: true)
        var presentation = PagePresentation(
            caption: gameplay.caption(zh: zh),
            accessibility: message("口袋小镇", "Pocket Town"),
            actions: [
                PageAction(
                    "town-switch", title: message("切换道岔", "Switch track"), enabled: gameplay.canInteract,
                    shortcut: "s"),
                PageAction(
                    "town-depart", title: message("发车", "Depart"),
                    enabled: gameplay.canInteract && !gameplay.trainIsRunning, shortcut: "d"),
            ],
            sounds: sounds,
            hint: message(
                "拨道岔选下一圈路线。打开超过 90° 自动发车，也可以点车站发车。",
                "Set the switch for the next lap. Open past 90° or click the station to depart."))
        if let notice = gameplay.notice {
            presentation.notice = noticeText(notice, zh: zh)
        } else if context.inputState == .unavailable && gameplay.trainIsRunning && !gameplay.trainIsMoving {
            presentation.notice = message(
                "铰链读数暂不可用，列车等待读数恢复。", "The train is waiting for the lid angle to return.")
        }
        return presentation
    }

    func render(into texture: MTLTexture, command: MTLCommandBuffer, context: WorldContext) throws {
        self.context = context
        scene.setViewport(CGSize(width: texture.width, height: texture.height))
        try scene.render(
            into: texture, command: command,
            folding: PocketTownFolding(progress: context.progress), gameplay: gameplay, clock: context.clock)
    }

    func pause() -> Data? {
        pendingSounds.removeAll(keepingCapacity: true)
        return nil
    }

    func finish() -> Data? { pause() }

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
