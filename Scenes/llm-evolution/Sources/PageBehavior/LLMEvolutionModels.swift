import Foundation

public enum LLMEvolutionExample: Int, CaseIterable, Equatable, Sendable, Codable {
    case continueSentence = 0
    case politeRewrite = 1
    case imageJudgment = 2
}

public enum LLMEvolutionBooth: Int, CaseIterable, Equatable, Sendable, Codable {
    case nextToken = 0
    case attention = 1
    case pretrain = 2
    case instructionFeedback = 3
    case multimodal = 4
    case researchBranch = 5
}

public enum LLMEvolutionTapTarget: Equatable, Sendable {
    case example(LLMEvolutionExample)
    case booth(LLMEvolutionBooth)
    case sourcePanel
}

public enum LLMEvolutionNotice: String, Equatable, Sendable {
    case needOpen
    case pickedExample
    case pickedBooth
}

public struct LLMEvolutionPoint: Equatable, Sendable, Codable {
    public var x: Double
    public var z: Double
    public init(_ x: Double, _ z: Double) {
        self.x = x
        self.z = z
    }
}

/// Tape spine and branch polyline shared with the scene renderer.
public enum LLMEvolutionLayout {
    public static let tape: [LLMEvolutionPoint] = [
        LLMEvolutionPoint(-1.42, -0.05),
        LLMEvolutionPoint(-0.78, -0.05),
        LLMEvolutionPoint(-0.18, -0.05),
        LLMEvolutionPoint(0.42, -0.05),
        LLMEvolutionPoint(1.02, -0.05),
        LLMEvolutionPoint(1.32, -0.05),
    ]

    public static let branch: [LLMEvolutionPoint] = [
        LLMEvolutionPoint(0.72, -0.05),
        LLMEvolutionPoint(0.72, 0.42),
        LLMEvolutionPoint(1.18, 0.42),
    ]

    /// SceneKit 命中节点名，与 `parseHit` 成对，供验收核对 3 例 × 6 展台。
    public enum HitNames {
        public static let source = "hit-source"

        public static func example(_ example: LLMEvolutionExample) -> String {
            "hit-example-\(example.rawValue)"
        }

        public static func booth(_ booth: LLMEvolutionBooth) -> String {
            "hit-booth-\(booth.rawValue)"
        }

        public static var allExampleNames: [String] {
            LLMEvolutionExample.allCases.map { example($0) }
        }

        public static var allBoothNames: [String] {
            LLMEvolutionBooth.allCases.map { booth($0) }
        }
    }

    public static func parseHit(_ name: String) -> LLMEvolutionTapTarget? {
        if name == HitNames.source { return .sourcePanel }
        if name.hasPrefix("hit-example-") {
            let raw = name.replacingOccurrences(of: "hit-example-", with: "")
            if let value = Int(raw), let example = LLMEvolutionExample(rawValue: value) {
                return .example(example)
            }
        }
        if name.hasPrefix("hit-booth-") {
            let raw = name.replacingOccurrences(of: "hit-booth-", with: "")
            if let value = Int(raw), let booth = LLMEvolutionBooth(rawValue: value) {
                return .booth(booth)
            }
        }
        return nil
    }

    public static func boothAnchor(_ booth: LLMEvolutionBooth) -> LLMEvolutionPoint {
        switch booth {
        case .nextToken: return LLMEvolutionPoint(-1.12, -0.05)
        case .attention: return LLMEvolutionPoint(-0.52, -0.05)
        case .pretrain: return LLMEvolutionPoint(0.04, -0.05)
        case .instructionFeedback: return LLMEvolutionPoint(0.58, -0.05)
        case .multimodal: return LLMEvolutionPoint(1.02, -0.05)
        case .researchBranch: return LLMEvolutionPoint(1.02, 0.42)
        }
    }
}
