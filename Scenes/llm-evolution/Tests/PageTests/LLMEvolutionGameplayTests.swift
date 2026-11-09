import PageBehavior
import XCTest

final class LLMEvolutionGameplayTests: XCTestCase {
    func testPlaysThreeActsAndStopsInGallery() {
        var show = LLMEvolutionGameplay()
        for act in 0..<3 {
            XCTAssertEqual(show.act, act)
            show.advance(progress: 1, deltaTime: 10)
        }
        XCTAssertTrue(show.finished)
        show.advance(progress: 1, deltaTime: 10)
        XCTAssertEqual(show.elapsed, 30)
        XCTAssertTrue(show.handleAction("show-replay"))
        XCTAssertEqual(show.elapsed, 0)
        XCTAssertFalse(show.finished)
    }

    func testFoldAndPauseKeepTheExactPlayhead() {
        var show = LLMEvolutionGameplay()
        show.advance(progress: 1, deltaTime: 13.8)
        show.advance(progress: 0.55, deltaTime: 10)
        XCTAssertEqual(show.act, 1)
        XCTAssertEqual(show.elapsed, 13.8)
        XCTAssertFalse(show.handleAction("show-next"))
        show.advance(progress: 0.91, deltaTime: 2)
        XCTAssertEqual(show.elapsed, 13.8)
        show.advance(progress: 0.95, deltaTime: 0.2)
        XCTAssertEqual(show.elapsed, 14, accuracy: 1e-9)
        XCTAssertTrue(show.handleAction("show-toggle"))
        show.advance(progress: 0.5, deltaTime: 1)
        show.advance(progress: 1, deltaTime: 5)
        XCTAssertTrue(show.userPaused)
        XCTAssertEqual(show.elapsed, 14, accuracy: 1e-9)
        XCTAssertTrue(show.handleAction("show-toggle"))
        show.advance(progress: 1, deltaTime: 1)
        XCTAssertEqual(show.elapsed, 15, accuracy: 1e-9)
    }

    func testActControlsAndSources() {
        var show = LLMEvolutionGameplay()
        show.advance(progress: 1, deltaTime: 3)
        XCTAssertTrue(show.handleAction("show-next"))
        XCTAssertEqual(show.elapsed, 10)
        XCTAssertTrue(show.handleAction("toggle-source"))
        show.advance(progress: 1, deltaTime: 5)
        XCTAssertEqual(show.elapsed, 10)
        XCTAssertTrue(show.detail(zh: true).contains("2017"))
        XCTAssertTrue(show.detail(zh: true).contains("预制示例"))
        XCTAssertTrue(show.handleAction("show-previous"))
        XCTAssertEqual(show.act, 0)
    }

    func testVisionSampleHasMultimodalPrefab() {
        let panel = LLMEvolutionExhibit.panel(example: .imageJudgment, booth: .multimodal, zh: true)
        XCTAssertEqual(panel.kind, .prefab)
        XCTAssertTrue(panel.body.contains("预制"))
    }
}
