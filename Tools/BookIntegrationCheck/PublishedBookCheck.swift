import Foundation
import PopupBookCore

/// Exercises the release manifest with the real page processes and temporary checkpoints.
@MainActor final class PublishedBookCheck {
    private enum Step {
        case page(String)
        case angle(Double, String)
        case action(String, sound: String?, feedback: [String])
        case feedback([String])
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
                    .settle(5),
                    .action("gentle-touch", sound: nil, feedback: ["轻抚", "petting"]),
                    .action("invite-closer", sound: nil, feedback: ["坐坐", "Moving"]),
                ]
            case "pocket-town":
                plan += [
                    .angle(0.52857, "station-72deg"),
                    .action("town-switch", sound: "town.switch", feedback: ["钟楼线", "Clock tower"]),
                    .action("town-depart", sound: "town.depart", feedback: ["正在走", "Train on"]),
                    .record("clock-route-72deg", frames: 12),
                    .angle(0.75, "clock-route-midway"),
                    .angle(0.04, "folded-during-trip"), .angle(1, "back-at-station"),
                    .feedback(["点击车站发车", "Tap the station"]),
                    .action("town-switch", sound: "town.switch", feedback: ["河岸线", "Riverside"]),
                    .action("town-depart", sound: "town.depart", feedback: ["正在走", "Train on"]),
                    .record("river-route-107deg", frames: 12),
                ]
            case "room-in-computer":
                plan += [
                    .angle(0.41429, "closing-64deg"), .angle(0.37143, "closing-61deg"),
                    .settle(0.4), .record("room-held-61deg", frames: 6),
                    .angle(0.41429, "reversing-64deg"), .angle(0.37143, "reversing-61deg"),
                    .angle(1, "room-after-reversal"),
                    .action("room-night", sound: "room.strip", feedback: ["夜晚", "Evening"]),
                    .action("room-dawn", sound: "room.strip", feedback: ["清晨", "Morning"]),
                    .action("room-afternoon", sound: "room.strip", feedback: ["午后", "Afternoon"]),
                ]
            case "underwater-theater":
                plan += [
                    .angle(0.50, "reef-half"), .settle(0.4), .record("reef-half", frames: 18),
                    .angle(0.96, "reef-above-100deg"), .settle(0.4), .record("reef-open", frames: 18),
                    .action("current-west", sound: "sea.current", feedback: ["左侧海草", "by the seaweed"]),
                    .action("current-shell", sound: "sea.current", feedback: ["贝壳台旁", "beside the shell"]),
                    .angle(0.04, "folded-during-current"), .angle(1, "current-reopened"),
                ]
            case "mechanical-planetarium":
                plan += [
                    .angle(0.50, "planet-half"), .settle(0.4), .record("planet-half", frames: 18),
                    .angle(0.96, "planet-above-100deg"), .settle(0.4), .record("planet-open", frames: 18),
                    .action(
                        "observe-quarter", sound: "planet.detent",
                        feedback: ["已暂停，上弦", "Paused at First quarter"]),
                    .action(
                        "observe-full", sound: "planet.detent", feedback: ["已暂停，满月", "Paused at Full moon"]),
                ]
            case "llm-evolution":
                plan += [
                    .action("show-replay", sound: "exhibit.paper", feedback: ["两种续写", "two endings"]),
                    .settle(7), .angle(1, "act-1-prints"),
                    .action("show-toggle", sound: "exhibit.paper", feedback: ["已暂停", "Show paused"]),
                    .angle(0.44, "show-folded"), .angle(1, "show-resumed-position"),
                    .feedback(["已暂停", "Show paused"]),
                    .action("show-toggle", sound: "exhibit.paper", feedback: ["两种续写", "two endings"]),
                    .action("show-next", sound: "exhibit.paper", feedback: ["更礼貌", "Polite cues"]),
                    .settle(3), .angle(1, "act-2-keywords"),
                    .action("toggle-source", sound: "exhibit.paper", feedback: ["2017"]),
                    .angle(1, "show-source-card"),
                    .action("toggle-source", sound: "exhibit.paper", feedback: ["更礼貌", "Polite cues"]),
                    .action("show-next", sound: "exhibit.paper", feedback: ["图文判断", "prints a judgment"]),
                    .settle(1), .angle(1, "act-3-picture"),
                    .settle(7), .settle(3), .angle(1, "show-gallery"),
                    .feedback(["巡演结束", "The show has ended"]),
                    .action("show-previous", sound: "exhibit.paper", feedback: ["更礼貌", "Polite cues"]),
                    .action("show-replay", sound: "exhibit.paper", feedback: ["两种续写", "two endings"]),
                    .settle(7), .settle(5), .feedback(["更礼貌", "Polite cues"]),
                    .settle(5), .settle(5), .feedback(["图文判断", "prints a judgment"]),
                    .settle(6), .settle(5), .feedback(["巡演结束", "The show has ended"]),
                    .angle(1, "uninterrupted-gallery"),
                ]
            default:
                break
            }
        }
        if pages.contains("mechanical-planetarium"), pages.last != "mechanical-planetarium" {
            plan += [.page("mechanical-planetarium"), .feedback(["已暂停，满月", "Paused at Full moon"])]
        }
        steps = plan
    }

    func record(_ sounds: [PageSound]) {
        soundEvents.formUnion(sounds.filter { $0.operation == .play }.map(\.id))
    }

    func step(_ check: Check, now: Double) {
        guard index < steps.count else {
            check.coordinator.stop()
            check.supervisor.shutdown()
            print("正式清单后台验收通过：开合、连续取帧、动作、声音事件和状态恢复。")
            exit(0)
        }
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
