import Foundation

public struct LLMEvolutionGameplay: Equatable, Sendable {
    public var selectedExample: LLMEvolutionExample
    public var selectedBooth: LLMEvolutionBooth
    public var showSource: Bool
    public private(set) var notice: LLMEvolutionNotice?
    public private(set) var noticeUntil: Double
    public private(set) var canInteract: Bool

    public static let openThreshold = 0.78
    public static let foldResetProgress = 0.22

    public init(
        selectedExample: LLMEvolutionExample = .continueSentence,
        selectedBooth: LLMEvolutionBooth = .nextToken, showSource: Bool = false
    ) {
        self.selectedExample = selectedExample
        self.selectedBooth = selectedBooth
        self.showSource = showSource
        notice = nil
        noticeUntil = 0
        canInteract = false
    }

    public mutating func handleTap(_ target: LLMEvolutionTapTarget, folding: LLMEvolutionFolding, now: Double)
    {
        updateInteractionGate(folding: folding, progress: nil)
        guard canInteract else {
            setNotice(.needOpen, until: now + 2)
            return
        }

        switch target {
        case .example(let example):
            selectedExample = example
            setNotice(.pickedExample, until: now + 1.2)
        case .booth(let booth):
            selectedBooth = booth
            setNotice(.pickedBooth, until: now + 1.2)
        case .sourcePanel:
            showSource.toggle()
        }
    }

    public mutating func handleAction(_ action: String, folding: LLMEvolutionFolding, now: Double) {
        updateInteractionGate(folding: folding, progress: nil)
        guard canInteract else {
            setNotice(.needOpen, until: now + 2)
            return
        }
        switch action {
        case "next-example":
            let next = (selectedExample.rawValue + 1) % LLMEvolutionExample.allCases.count
            selectedExample = LLMEvolutionExample(rawValue: next) ?? .continueSentence
            setNotice(.pickedExample, until: now + 1.2)
        case "next-booth":
            let next = (selectedBooth.rawValue + 1) % LLMEvolutionBooth.allCases.count
            selectedBooth = LLMEvolutionBooth(rawValue: next) ?? .nextToken
            setNotice(.pickedBooth, until: now + 1.2)
        case "toggle-source":
            showSource.toggle()
        default:
            if action.hasPrefix("select-example-"),
                let value = Int(action.replacingOccurrences(of: "select-example-", with: "")),
                let example = LLMEvolutionExample(rawValue: value)
            {
                selectedExample = example
                setNotice(.pickedExample, until: now + 1.2)
            } else if action.hasPrefix("select-booth-"),
                let value = Int(action.replacingOccurrences(of: "select-booth-", with: "")),
                let booth = LLMEvolutionBooth(rawValue: value)
            {
                selectedBooth = booth
                setNotice(.pickedBooth, until: now + 1.2)
            }
        }
    }

    public mutating func advance(
        bookProgress: Double, clock: Double, deltaTime: Double, folding: LLMEvolutionFolding
    ) {
        _ = max(0, deltaTime)
        updateInteractionGate(folding: folding, progress: bookProgress)
        if clock >= noticeUntil { notice = nil }
    }

    public func caption(zh: Bool) -> String {
        let example = LLMEvolutionExhibit.exampleLabel(selectedExample, zh: zh)
        let booth = LLMEvolutionExhibit.boothLabel(selectedBooth, zh: zh)
        let panel = LLMEvolutionExhibit.panel(example: selectedExample, booth: selectedBooth, zh: zh)
        if canInteract {
            return zh
                ? "例子「\(example)」· 展台「\(booth)」：\(panel.headline)"
                : "Sample “\(example)” · Booth “\(booth)”: \(panel.headline)"
        }
        return zh ? "文字如何长出能力" : "How text grows into capability"
    }

    public func detailCaption(zh: Bool) -> String {
        let panel = LLMEvolutionExhibit.panel(example: selectedExample, booth: selectedBooth, zh: zh)
        var lines = [panel.body]
        if showSource, let source = panel.sourceLine {
            lines.append(source)
        }
        let tag: String
        switch panel.kind {
        case .prefab: tag = zh ? "【预制示意】" : "[Prefabricated]"
        case .schematic: tag = zh ? "【视觉比喻】" : "[Visual metaphor]"
        case .historical: tag = zh ? "【史实节点】" : "[Historical milestone]"
        case .notApplicable: tag = zh ? "【不适用】" : "[Not applicable]"
        }
        return tag + " " + lines.joined(separator: zh ? " " : " ")
    }

    public func introduction(zh: Bool) -> String {
        if canInteract {
            return zh
                ? "点选左上例子与沿线展台，看预制或不适用的说明；点右下角来源牌展开研究出处。"
                : "Pick a sample and a booth along the tape; tap the source plaque to expand references."
        }
        return zh ? "先展开书页，进入离线技术展览。" : "Open the page to enter the offline exhibit."
    }

    /// Main tape segment indices (0…tape.count-2) lit when booth is on the spine.
    public func highlightedTapeSegmentIndices() -> [Int] {
        switch selectedBooth {
        case .nextToken: return [0, 1]
        case .attention: return [1, 2]
        case .pretrain: return [2, 3]
        case .instructionFeedback: return [3, 4]
        case .multimodal: return [4]
        case .researchBranch: return [2, 3, 4]
        }
    }

    public func highlightsBranch() -> Bool { selectedBooth == .researchBranch }

    private mutating func updateInteractionGate(folding: LLMEvolutionFolding, progress: Double?) {
        let progressAmount = progress.map { Self.clamp($0) }
        let folded =
            (progressAmount ?? 1) < Self.foldResetProgress || folding.booths < Self.openThreshold
        canInteract = !folded && folding.tape > 0.35
    }

    private mutating func setNotice(_ value: LLMEvolutionNotice, until: Double) {
        notice = value
        noticeUntil = until
    }

    private static func clamp(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        guard value.isFinite else { return value.sign == .minus ? 0 : 1 }
        return min(1, max(0, value))
    }
}
