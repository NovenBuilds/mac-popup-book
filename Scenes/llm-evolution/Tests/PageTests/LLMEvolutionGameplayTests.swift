import PageBehavior
import XCTest

final class LLMEvolutionGameplayTests: XCTestCase {
    func testPickExampleAndBoothWhenOpen() {
        var state = LLMEvolutionGameplay()
        let folding = LLMEvolutionFolding(progress: 1)
        state.handleTap(.example(.politeRewrite), folding: folding, now: 0)
        XCTAssertEqual(state.selectedExample, .politeRewrite)
        state.handleTap(.booth(.multimodal), folding: folding, now: 1)
        XCTAssertEqual(state.selectedBooth, .multimodal)
    }

    func testBlockedWhenFolded() {
        var state = LLMEvolutionGameplay()
        let folding = LLMEvolutionFolding(progress: 0.1)
        state.handleTap(.booth(.attention), folding: folding, now: 0)
        XCTAssertEqual(state.selectedBooth, .nextToken)
        XCTAssertEqual(state.notice, .needOpen)
    }

    func testMultimodalNotApplicableForContinuationSample() {
        let panel = LLMEvolutionExhibit.panel(example: .continueSentence, booth: .multimodal, zh: true)
        XCTAssertEqual(panel.kind, .notApplicable)
    }

    func testVisionSampleHasMultimodalPrefab() {
        let panel = LLMEvolutionExhibit.panel(example: .imageJudgment, booth: .multimodal, zh: true)
        XCTAssertEqual(panel.kind, .prefab)
        XCTAssertTrue(panel.body.contains("预制"))
    }

    func testActionCyclesExampleAndBooth() {
        var state = LLMEvolutionGameplay()
        let folding = LLMEvolutionFolding(progress: 1)
        state.handleAction("next-example", folding: folding, now: 0)
        XCTAssertEqual(state.selectedExample, .politeRewrite)
        state.handleAction("next-booth", folding: folding, now: 1)
        XCTAssertEqual(state.selectedBooth, .attention)
        state.handleAction("toggle-source", folding: folding, now: 2)
        XCTAssertTrue(state.showSource)
    }

    func testHighlightIndicesForBranchBooth() {
        let state = LLMEvolutionGameplay(selectedBooth: .researchBranch)
        XCTAssertTrue(state.highlightsBranch())
        XCTAssertFalse(state.highlightedTapeSegmentIndices().isEmpty)
    }

    func testTapeLayoutHasDistinctAnchors() {
        let anchors = LLMEvolutionBooth.allCases.map { LLMEvolutionLayout.boothAnchor($0) }
        XCTAssertEqual(Set(anchors.map { "\($0.x),\($0.z)" }).count, anchors.count)
    }

    func testHitNamesCoverThreeExamplesAndSixBooths() {
        XCTAssertEqual(LLMEvolutionLayout.HitNames.allExampleNames.count, 3)
        XCTAssertEqual(LLMEvolutionLayout.HitNames.allBoothNames.count, 6)
        XCTAssertEqual(Set(LLMEvolutionLayout.HitNames.allExampleNames).count, 3)
        XCTAssertEqual(Set(LLMEvolutionLayout.HitNames.allBoothNames).count, 6)
    }

    func testParseHitRoundTripsEveryTarget() {
        for example in LLMEvolutionExample.allCases {
            let name = LLMEvolutionLayout.HitNames.example(example)
            guard case .example(let parsed)? = LLMEvolutionLayout.parseHit(name) else {
                return XCTFail("missing example hit \(name)")
            }
            XCTAssertEqual(parsed, example)
        }
        for booth in LLMEvolutionBooth.allCases {
            let name = LLMEvolutionLayout.HitNames.booth(booth)
            guard case .booth(let parsed)? = LLMEvolutionLayout.parseHit(name) else {
                return XCTFail("missing booth hit \(name)")
            }
            XCTAssertEqual(parsed, booth)
        }
        XCTAssertEqual(LLMEvolutionLayout.parseHit(LLMEvolutionLayout.HitNames.source), .sourcePanel)
    }

    func testSemanticSelectActionsMatchTap() {
        var viaTap = LLMEvolutionGameplay()
        var viaAction = LLMEvolutionGameplay()
        let folding = LLMEvolutionFolding(progress: 1)
        viaTap.handleTap(.booth(.instructionFeedback), folding: folding, now: 0)
        viaAction.handleAction("select-booth-3", folding: folding, now: 0)
        XCTAssertEqual(viaTap.selectedBooth, viaAction.selectedBooth)
        viaTap.handleTap(.example(.imageJudgment), folding: folding, now: 1)
        viaAction.handleAction("select-example-2", folding: folding, now: 1)
        XCTAssertEqual(viaTap.selectedExample, viaAction.selectedExample)
    }
}
