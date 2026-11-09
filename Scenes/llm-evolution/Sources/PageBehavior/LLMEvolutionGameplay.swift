public struct LLMEvolutionGameplay: Equatable, Sendable {
    public static let actDuration = 10.0
    public static let duration = 3 * actDuration

    public private(set) var elapsed = 0.0
    public private(set) var userPaused = false
    public private(set) var showSource = false
    public private(set) var canInteract = false

    public var finished: Bool { elapsed >= Self.duration }
    public var act: Int { min(2, Int(elapsed / Self.actDuration)) }
    public var actTime: Double { elapsed - Double(act) * Self.actDuration }

    public init() {}

    public mutating func advance(progress: Double, deltaTime: Double) {
        canInteract = progress >= (canInteract ? 0.90 : 0.93)
        guard canInteract, !userPaused, !showSource, deltaTime.isFinite, deltaTime > 0 else { return }
        elapsed = min(Self.duration, elapsed + deltaTime)
    }

    @discardableResult
    public mutating func handleAction(_ action: String) -> Bool {
        guard canInteract else { return false }
        switch action {
        case "show-toggle" where !finished: userPaused.toggle()
        case "show-replay":
            elapsed = 0
            userPaused = false
            showSource = false
        case "show-previous" where act > 0: elapsed = Double(act - 1) * Self.actDuration
        case "show-next" where act < 2: elapsed = Double(act + 1) * Self.actDuration
        case "toggle-source": showSource.toggle()
        default: return false
        }
        return true
    }

    public func caption(zh: Bool) -> String {
        if !canInteract {
            return zh ? "打开书页，工坊就会开演。" : "Open the page to start the workshop."
        }
        if finished {
            return zh ? "巡演结束，四张成品留在展台上。" : "The show has ended. Four prints stay on display."
        }
        if userPaused { return zh ? "巡演已暂停。" : "Show paused." }
        let captions =
            zh
            ? ["同一条纸带，从岔口印出两种续写。", "加上「更礼貌」，关键词连起，纸带印出新说法。", "图像卡与提问会合，印出图文判断。"]
            : [
                "One strip prints two endings at the fork.",
                "Polite cues connect and the press prints a rewrite.",
                "The picture meets a question and the press prints a judgment.",
            ]
        return captions[act]
    }

    public func detail(zh: Bool) -> String {
        let selection: [(LLMEvolutionExample, LLMEvolutionBooth)] = [
            (.continueSentence, .nextToken), (.politeRewrite, .attention), (.imageJudgment, .multimodal),
        ]
        let (example, booth) = selection[act]
        let panel = LLMEvolutionExhibit.panel(example: example, booth: booth, zh: zh)
        let references = [
            LLMEvolutionExhibit.panel(example: example, booth: .pretrain, zh: zh),
            LLMEvolutionExhibit.panel(example: example, booth: .researchBranch, zh: zh),
        ]
        var lines = [zh ? "展品均为预制示例。" : "The prints are fixed examples.", panel.body]
        lines += ([panel] + references).compactMap(\.sourceLine)
        if act == 1 {
            let feedback = LLMEvolutionExhibit.panel(example: example, booth: .instructionFeedback, zh: zh)
            lines += [feedback.body] + [feedback.sourceLine].compactMap { $0 }
        }
        return lines.joined(separator: " ")
    }
}
