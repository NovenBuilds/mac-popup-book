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
