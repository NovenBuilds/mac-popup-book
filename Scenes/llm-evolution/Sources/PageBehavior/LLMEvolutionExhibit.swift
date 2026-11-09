import Foundation

public struct LLMEvolutionPanel: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case prefab
        case schematic
        case historical
        case notApplicable
    }

    public var kind: Kind
    public var headline: String
    public var body: String
    public var sourceLine: String?

    public init(kind: Kind, headline: String, body: String, sourceLine: String? = nil) {
        self.kind = kind
        self.headline = headline
        self.body = body
        self.sourceLine = sourceLine
    }
}

/// Offline exhibit copy: fixed samples only, never pretending to be live inference.
public enum LLMEvolutionExhibit {
    public static func panel(example: LLMEvolutionExample, booth: LLMEvolutionBooth, zh: Bool)
        -> LLMEvolutionPanel
    {
        switch (example, booth) {
        case (.continueSentence, .nextToken):
            return LLMEvolutionPanel(
                kind: .prefab,
                headline: zh ? "预制续写分支" : "Prefabricated continuations",
                body: zh
                    ? "输入：「清晨，小镇车站里」。候选 A：「第一班小火车轻轻靠站台。」候选 B：「站长的哨声还在槐树下回响。」（示意，非实时生成。）"
                    : "Prompt: “At dawn, the town station…” Branch A: “the first train eases to the platform.” Branch B: “the conductor’s whistle still lingers under the locust tree.” (Illustration, not live.)",
                sourceLine: zh ? "比喻：自回归下一词预测" : "Metaphor: autoregressive next-token prediction")

        case (.continueSentence, .attention):
            return LLMEvolutionPanel(
                kind: .schematic,
                headline: zh ? "示意注意力连线" : "Schematic attention links",
                body: zh
                    ? "处理「车站」时，示意连线指向「清晨」「小镇」等词卡。线条只表示「可参考不同位置」，不是真实权重。"
                    : "When handling “station”, schematic links touch “dawn” and “town”. Lines show “context can be used”, not real weights.",
                sourceLine: zh
                    ? "史实：Vaswani 等，2017，《Attention Is All You Need》"
                    : "History: Vaswani et al., 2017, “Attention Is All You Need”")

        case (.continueSentence, .pretrain):
            return LLMEvolutionPanel(
                kind: .historical,
                headline: zh ? "预训练如何支撑续写" : "Pre-training supports continuation",
                body: zh
                    ? "大量书页汇入共享装置后，同一模型更能根据上下文猜后续字词。此例只需文字，预训练直接相关。"
                    : "After many book pages feed a shared block, the same model better guesses what comes next. Text-only; pre-training applies directly.",
                sourceLine: zh
                    ? "史实：Radford 等，2018，生成式预训练"
                    : "History: Radford et al., 2018, generative pre-training")

        case (.continueSentence, .instructionFeedback):
            return LLMEvolutionPanel(
                kind: .notApplicable,
                headline: zh ? "此例不适用指令对齐" : "Instruction tuning not the focus here",
                body: zh
                    ? "续写只根据上文往下接，并未被要求遵循额外礼貌或格式。可比较预制：纯续写 vs 按「请用儿童语气」改写后版本（后者属另一展台思路）。"
                    : "Continuation only follows prior text, not an extra constraint. Contrast prefab: plain continuation vs child-friendly rewrite (the latter belongs to instruction tuning)."
            )

        case (.continueSentence, .multimodal):
            return LLMEvolutionPanel(
                kind: .notApplicable,
                headline: zh ? "本例没有图像输入" : "No image in this sample",
                body: zh
                    ? "多模态展台需要图文共同进入装置。请切换到「图文判断」例子。"
                    : "The multimodal booth needs image plus text. Switch to the vision judgment sample.")

        case (.continueSentence, .researchBranch):
            return LLMEvolutionPanel(
                kind: .schematic,
                headline: zh ? "分步提示分支（示意）" : "Chain-of-thought branch (schematic)",
                body: zh
                    ? "预制卡片：① 找时间地点 ② 猜下一事件 ③ 选更顺的句子。展示「提示写法」可改进表现，不等于模型内在思维。"
                    : "Prefab cards: ① time/place ② likely event ③ smoother sentence. Prompting can help; not visible inner monologue.",
                sourceLine: zh
                    ? "分支：Wei 等，2022，链式思维提示" : "Branch: Wei et al., 2022, chain-of-thought prompting")

        case (.politeRewrite, .nextToken):
            return LLMEvolutionPanel(
                kind: .notApplicable,
                headline: zh ? "任务不是单纯续写" : "Task is not plain continuation",
                body: zh
                    ? "例子要求把粗鲁句改成礼貌语气。若只做下一词预测，会沿原语气滑下去；请到「指令与人类反馈」看台。"
                    : "The task is polite rewriting. Raw next-token continuation keeps the rude tone; see instruction tuning."
            )

        case (.politeRewrite, .attention):
            return LLMEvolutionPanel(
                kind: .schematic,
                headline: zh ? "示意：盯住礼貌线索" : "Schematic: polite cues",
                body: zh
                    ? "示意高亮「请」「谢谢」「能否」等词卡连线，表示模型可借上下文定位语气目标。（示意权重。）"
                    : "Schematic links highlight “please”, “thank you”, “could”. Shows context can target tone. (Illustrative weights.)",
                sourceLine: zh ? "史实：注意力架构，2017" : "History: attention architecture, 2017")

        case (.politeRewrite, .pretrain):
            return LLMEvolutionPanel(
                kind: .historical,
                headline: zh ? "预训练提供语言基础" : "Pre-training supplies language prior",
                body: zh
                    ? "先学会通用文字统计与用法，才可能听懂「改礼貌」；但礼貌对齐还需后续训练目标。"
                    : "General text patterns come first; polite alignment needs later objectives.")

        case (.politeRewrite, .instructionFeedback):
            return LLMEvolutionPanel(
                kind: .prefab,
                headline: zh ? "预制：更符合意图的版本" : "Prefab: better-aligned rewrite",
                body: zh
                    ? "原句预制：「把东西给我。」指令对齐后预制：「请问可以把东西递给我吗？谢谢。」（固定示意结果。）"
                    : "Raw prefab: “Give me that.” After instruction tuning prefab: “Could you please hand it to me? Thank you.” (Fixed illustration.)",
                sourceLine: zh
                    ? "史实：Ouyang 等，2022，人类反馈指令训练"
                    : "History: Ouyang et al., 2022, instruction tuning with human feedback")

        case (.politeRewrite, .multimodal):
            return LLMEvolutionPanel(
                kind: .notApplicable,
                headline: zh ? "本例纯文字" : "Text-only sample",
                body: zh
                    ? "礼貌改写例子不含图像。多模态请切换第三组例子。"
                    : "This rewrite has no image. Use the vision sample for multimodal.")

        case (.politeRewrite, .researchBranch):
            return LLMEvolutionPanel(
                kind: .prefab,
                headline: zh ? "工具抽屉：检索礼貌范例" : "Tool drawer: polite exemplars",
                body: zh
                    ? "预制：模型先检索「客服话术」片段，再组合改写。展示外部检索与训练是不同层面。"
                    : "Prefab: retrieve “service phrases”, then rewrite. External retrieval vs weight updates are different layers.",
                sourceLine: zh
                    ? "分支：Yao 等，2022，ReAct 推理与行动" : "Branch: Yao et al., 2022, ReAct reasoning and action")

        case (.imageJudgment, .nextToken):
            return LLMEvolutionPanel(
                kind: .notApplicable,
                headline: zh ? "需图文联合判断" : "Needs image plus text",
                body: zh
                    ? "「晴天还是雨天出门」依赖图像。纯文字续写展台无法完成此任务。"
                    : "Sunny vs rainy outing depends on the picture. Text-only continuation cannot judge.")

        case (.imageJudgment, .attention):
            return LLMEvolutionPanel(
                kind: .schematic,
                headline: zh ? "示意：图文交叉注意力" : "Schematic: cross-modal links",
                body: zh
                    ? "图像区块「乌云」「水坑」与文字「雨伞」「出行」之间画示意桥，不冒充真实跨模态矩阵。"
                    : "Bridges link image patches “clouds”, “puddles” to words “umbrella”, “trip”. Not a real cross-attention matrix."
            )

        case (.imageJudgment, .pretrain):
            return LLMEvolutionPanel(
                kind: .historical,
                headline: zh ? "文字预训练 + 视觉对齐" : "Text pre-training plus vision alignment",
                body: zh
                    ? "大量文本与图文对共同训练后，模型才能把画面与问题连在一起。本例展示对齐后的离线判断。"
                    : "Text and image-text pairs align modalities before offline judgment here.")

        case (.imageJudgment, .instructionFeedback):
            return LLMEvolutionPanel(
                kind: .prefab,
                headline: zh ? "预制：更贴用户问法" : "Prefab: answer shaped to the question",
                body: zh
                    ? "同一图像，指令对齐后预制：「图中阴雨，建议带伞，暂缓远足。」比生硬单字「雨」更符合问句。"
                    : "Same image, tuned prefab: “Overcast with rain—bring an umbrella, postpone the hike.” Better than a one-word “rain.”",
                sourceLine: zh ? "史实：人类反馈常用于对齐回答风格" : "History: human feedback often aligns answer style")

        case (.imageJudgment, .multimodal):
            return LLMEvolutionPanel(
                kind: .prefab,
                headline: zh ? "预制图文判断" : "Prefabricated vision judgment",
                body: zh
                    ? "示意图像卡上画着一把红伞。输入文字「图中有红伞吗？」，装置印出「有一把红伞」。（离线预制。）"
                    : "The picture card shows a red umbrella. The question “Is there a red umbrella?” yields “Yes, a red umbrella.” (Offline prefab.)",
                sourceLine: zh
                    ? "史实：OpenAI，2023，GPT-4 技术报告（图文输入）"
                    : "History: OpenAI, 2023, GPT-4 report (image+text input)")

        case (.imageJudgment, .researchBranch):
            return LLMEvolutionPanel(
                kind: .prefab,
                headline: zh ? "检索 + 工具验证" : "Retrieval plus tool check",
                body: zh
                    ? "预制流程：① 识别天气线索 ② 检索本地出行建议库 ③ 输出带理由的一句话。展示分支研究与核心训练并行。"
                    : "Prefab flow: ① weather cues ② retrieve local travel tips ③ one-sentence rationale. Parallel research branch."
            )
        }
    }

    public static func boothLabel(_ booth: LLMEvolutionBooth, zh: Bool) -> String {
        switch booth {
        case .nextToken: return zh ? "接续文字" : "Next-token"
        case .attention: return zh ? "注意力" : "Attention"
        case .pretrain: return zh ? "预训练" : "Pre-training"
        case .instructionFeedback: return zh ? "指令与人类反馈" : "Instruction & feedback"
        case .multimodal: return zh ? "多模态" : "Multimodal"
        case .researchBranch: return zh ? "分支研究台" : "Research branch"
        }
    }

    public static func exampleLabel(_ example: LLMEvolutionExample, zh: Bool) -> String {
        switch example {
        case .continueSentence: return zh ? "续写一句话" : "Continue a sentence"
        case .politeRewrite: return zh ? "按要求改写" : "Rewrite on request"
        case .imageJudgment: return zh ? "图文判断" : "Image + text judgment"
        }
    }

    public static func boothSummary(_ booth: LLMEvolutionBooth, zh: Bool) -> String {
        switch booth {
        case .nextToken:
            return zh ? "根据上下文预测后续文字。" : "Predict what text comes next from context."
        case .attention:
            return zh ? "处理当前位置时可参考别处信息（示意）。" : "Current position can use information elsewhere (schematic)."
        case .pretrain:
            return zh ? "从大量文本学习，再服务不同任务。" : "Learn from lots of text, then adapt to tasks."
        case .instructionFeedback:
            return zh ? "让输出更符合用户意图，与单纯续写目标不同。" : "Align outputs with intent—distinct from raw continuation."
        case .multimodal:
            return zh ? "图像与文字一起进入同一装置。" : "Images and text enter the same apparatus."
        case .researchBranch:
            return zh ? "提示技巧、检索与工具是并行改进路线。" : "Prompting, retrieval, and tools evolve in parallel."
        }
    }
}
