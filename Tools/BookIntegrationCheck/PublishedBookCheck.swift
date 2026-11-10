import Foundation
import PopupBookCore
import PopupBookRuntime

/// Exercises the release manifest with the real page processes and temporary checkpoints.
@MainActor final class PublishedBookCheck {
    private enum Step {
        case page(String)
        case angle(Double, String)
        case action(String, sound: String?, feedback: [String])
        case feedback([String])
        case sound(String, PageSound.Operation)
        case mute(Bool)
        case settle(Double)
        case record(String, frames: Int)
    }

    private let steps: [Step]
    private var index = 0
    private var startedAt: Double?
    private var captureRequested = false
    private var recordedFrames = 0
    private var nextRecordAt = 0.0
    private var soundEvents: Set<String> = []
    private var soundOperations: [String: Set<PageSound.Operation>] = [:]
    private var departureBeforeReady = false
    var checkpoints: [String: Data] = [:]

    init(pages: [String]) {
        var plan: [Step] = []
        for page in pages {
            plan += [
                .page(page), .angle(1, "open"), .angle(0.50, "half"), .angle(0.04, "closed"),
                .angle(1, "reopened"),
            ]
            switch page {
            case "forest-cabin":
                plan += [
                    .record("forest-entrance", frames: 26), .settle(1.5),
                    .action("gentle-touch", sound: nil, feedback: ["轻抚", "petting"]),
                    .action("invite-closer", sound: nil, feedback: ["坐坐", "Moving"]),
                    .record("forest-interaction", frames: 16),
                ]
            case "pocket-town":
                plan += [
                    .angle(0.04, "reset-before-manual-trip"), .angle(0.52857, "station-72deg"),
                    .action("town-switch", sound: "town.switch", feedback: ["钟楼线", "Clock tower"]),
                    .action("town-depart", sound: "town.depart", feedback: ["正在走", "Train on"]),
                    .record("clock-route-72deg", frames: 12),
                    .settle(6.5), .settle(6.5),
                    .sound("town.bridge", .play), .sound("town.clock", .play),
                    .angle(0.75, "clock-route-return"),
                    .angle(0.04, "folded-during-trip"), .angle(0.77, "below-90-station"),
                    .feedback(["自动发车", "past 90° to depart"]),
                    .action("town-switch", sound: "town.switch", feedback: ["河岸线", "Riverside"]),
                    .angle(0.81, "auto-depart-above-90"),
                    .feedback(["正在走", "Train on"]),
                    .sound("town.running", .begin),
                    .record("auto-moving", frames: 18),
                    .mute(true), .settle(0.7), .mute(false),
                    .angle(0.77, "auto-hold-below-90"),
                    .feedback(["火车已暂停", "Train paused"]), .sound("town.running", .end),
                    .settle(0.3), .record("auto-held", frames: 6),
                    .angle(1, "auto-resumed"),
                    .feedback(["正在走", "Train on"]),
                    .record("river-route-107deg", frames: 12),
                ]
            case "room-in-computer":
                plan += [
                    .angle(0.41429, "closing-64deg"), .angle(0.37143, "closing-61deg"),
                    .settle(0.4), .record("room-held-61deg", frames: 6),
                    .angle(0.41429, "reversing-64deg"), .angle(0.37143, "reversing-61deg"),
                    .angle(0.44, "guest-leaves-bed"),
                    .angle(0.60, "guest-crosses-room"),
                    .angle(0.70, "guest-walks-around-desk"),
                    .angle(1, "room-after-reversal"),
                    .action("room-night", sound: "room.strip", feedback: ["夜晚", "Evening"]),
                    .angle(1, "lamp-night"),
                    .action("room-lamp", sound: "room.lamp", feedback: ["夜晚", "Evening"]),
                    .angle(1, "lamp-night-off"),
                    .action("room-lamp", sound: "room.lamp", feedback: ["夜晚", "Evening"]),
                    .angle(1, "lamp-night-on"),
                    .action("room-dawn", sound: "room.strip", feedback: ["清晨", "Morning"]),
                    .action("room-afternoon", sound: "room.strip", feedback: ["午后", "Afternoon"]),
                    .settle(0.9), .angle(1, "lamp-afternoon"),
                    .record("room-reading", frames: 36), .sound("room.reading", .play),
                ]
            case "underwater-theater":
                plan += [
                    .angle(0.26, "reef-backdrop"),
                    .angle(0.40, "reef-folding-coral"),
                    .angle(0.50, "reef-half"), .settle(0.4), .record("reef-half", frames: 18),
                    .angle(0.96, "reef-above-100deg"), .settle(0.4), .record("reef-open", frames: 18),
                    .sound("sea.reef", .begin),
                    .action("current-west", sound: "sea.current", feedback: ["左侧海草", "by the seaweed"]),
                    .record("reef-current", frames: 18),
                    .action("current-shell", sound: "sea.current", feedback: ["贝壳台旁", "beside the shell"]),
                    .angle(0.04, "folded-during-current"), .angle(1, "current-reopened"),
                ]
            case "mechanical-planetarium":
                plan += [
                    .angle(0.50, "planet-half"), .settle(0.4), .record("planet-half", frames: 18),
                    .angle(0.96, "planet-above-100deg"), .settle(0.4), .record("planet-open", frames: 18),
                    .sound("planet.drive", .begin),
                    .action(
                        "observe-quarter", sound: "planet.detent",
                        feedback: ["已暂停，上弦", "Paused at First quarter"]),
                    .sound("planet.drive", .end),
                    .record("planet-quarter", frames: 12),
                    .action(
                        "observe-full", sound: "planet.detent", feedback: ["已暂停，满月", "Paused at Full moon"]),
                ]
            default:
                break
            }
        }
        if pages.contains("mechanical-planetarium"), let first = pages.first,
            first != "mechanical-planetarium"
        {
            if pages.last == "mechanical-planetarium" { plan.append(.page(first)) }
            plan += [.page("mechanical-planetarium"), .feedback(["已暂停，满月", "Paused at Full moon"])]
        }
        steps = plan
    }

    func record(_ sounds: [PageSound], phase: PageTurnPhase) {
        soundEvents.formUnion(sounds.filter { $0.operation == .play }.map(\.id))
        for sound in sounds {
            soundOperations[sound.id, default: []].insert(sound.operation)
            if sound.id == "town.depart", phase != .idle { departureBeforeReady = true }
        }
    }

    func step(_ check: Check, now: Double) {
        guard index < steps.count else {
            check.coordinator.stop()
            check.supervisor.shutdown()
            print("正式清单后台验收通过：开合、连续取帧、动作、声音事件和状态恢复。")
            exit(0)
        }
        if departureBeforeReady { check.fail("汽笛在翻页完成前触发") }
        let coordinator = check.coordinator!
        let state = coordinator.state
        if check.failed(state.current) { check.fail("正式场景进程失败：\(state.current ?? "未选页")") }

        let step = steps[index]
        if let startedAt, now - startedAt > 8 {
            check.fail("正式场景验收超时：\(state.current ?? "未选页") \(step)，反馈 \(state.output.caption)")
        }

        switch step {
        case .page(let page):
            guard state.phase == .idle, state.progress > 0.95 else { return }
            if startedAt == nil {
                startedAt = now
                if state.current != page { coordinator.open(page) }
            }
            guard state.current == page, coordinator.state.phase == .idle, check.current?.ready == true else {
                return
            }
            finishStep()
        case .angle(let progress, let label):
            if startedAt == nil {
                startedAt = now
                coordinator.setManual(progress)
                return
            }
            guard abs(state.progress - progress) < 0.012 else { return }
            if !captureRequested {
                captureRequested = true
                check.captureName = "\(state.current ?? "page")-\(label)"
                return
            }
            guard check.captureName == nil else { return }
            print("通过：\(state.current ?? "page") \(label)")
            finishStep()
        case .action(let action, let sound, let feedback):
            if startedAt == nil {
                guard state.output.actions.contains(where: { $0.id == action && $0.enabled }) else {
                    // Wait for the next presentation after opening, but time out if the action is missing.
                    if inputWaitStart == nil { inputWaitStart = now }
                    if now - (inputWaitStart ?? now) > 4 { check.fail("场景没有启用操作：\(action)") }
                    return
                }
                startedAt = now
                soundEvents.removeAll(keepingCapacity: true)
                coordinator.handle(.action(action))
                return
            }
            let output =
                state.output.caption + " " + (state.output.notice ?? "") + " " + state.output.accessibility
            guard feedback.contains(where: { output.contains($0) }),
                sound.map({ soundEvents.contains($0) }) ?? true,
                now - (startedAt ?? now) >= 0.31
            else { return }
            print("通过：\(state.current ?? "page") \(action)，声音事件 \(sound ?? "沿用原页验收")")
            finishStep()
        case .settle(let duration):
            if startedAt == nil { startedAt = now }
            if now - (startedAt ?? now) >= duration { finishStep() }
        case .record(let label, let frameCount):
            if startedAt == nil {
                startedAt = now
                nextRecordAt = now
            }
            guard check.captureName == nil else { return }
            if recordedFrames == frameCount {
                finishStep()
                return
            }
            guard now >= nextRecordAt else { return }
            let suffix = String(format: "%03d", recordedFrames)
            check.captureName = "\(state.current ?? "page")-\(label)-\(suffix)"
            nextRecordAt = now + 1.0 / 8
            recordedFrames += 1
        case .mute(let muted):
            if check.audition { coordinator.setSound(!muted) }
            finishStep()
        case .sound(let id, let operation):
            if startedAt == nil { startedAt = now }
            guard soundOperations[id]?.remove(operation) != nil else { return }
            print("通过：\(id) \(operation.rawValue)")
            finishStep()
        case .feedback(let feedback):
            if startedAt == nil { startedAt = now }
            guard feedback.contains(where: { state.output.caption.contains($0) }) else { return }
            finishStep()
        }
    }

    private var inputWaitStart: Double?

    private func finishStep() {
        index += 1
        startedAt = nil
        inputWaitStart = nil
        captureRequested = false
        recordedFrames = 0
    }
}
