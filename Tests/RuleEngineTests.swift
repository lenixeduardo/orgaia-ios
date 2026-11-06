import XCTest
@testable import OrgaIA

final class RuleEngineTests: XCTestCase {
    func testRecognizesPokemonFromOCR() {
        let result = RuleEngine.suggest(labels: [], ocr: "Pokémon TCG Charizard 006/165", isScreenshot: false, learned: [:])
        XCTAssertEqual(result.category, .pokemon)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.80)
    }

    func testDetectsProjectScreenshotOverGenericScreenshot() {
        let result = RuleEngine.suggest(labels: [], ocr: "GitHub Vercel Supabase deployment", isScreenshot: true, learned: [:])
        XCTAssertEqual(result.category, .projetos)
    }

    func testScreenshotWithoutText() {
        let result = RuleEngine.suggest(labels: [], ocr: "", isScreenshot: true, learned: [:])
        XCTAssertEqual(result.category, .capturas)
    }

    func testLowSignalGoesToReview() {
        let result = RuleEngine.suggest(labels: [], ocr: "", isScreenshot: false, learned: [:])
        XCTAssertEqual(result.category, .outros)
        XCTAssertLessThan(result.confidence, AppConfig.confidenceThreshold)
    }

    func testLearnedCategoryChangesSuggestion() {
        let result = RuleEngine.suggest(labels: [], ocr: "PORTUS relatório", isScreenshot: false,
                                        learned: ["portus": ["projetos": 5]])
        XCTAssertEqual(result.category, .projetos)
    }

    func testNormalizationRemovesAccents() {
        XCTAssertTrue(RuleEngine.tokens(from: "Promoção Pokémon").contains("pokemon"))
    }
}
