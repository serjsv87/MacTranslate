import Testing
@testable import MacTranslate

@Suite("Language Pair Routing Tests")
struct LanguagePairRoutingTests {
    let router = LanguagePairRouter(primary: "uk", secondary: "en", fallback: "en")
    
    @Test("Bidirectional routing between Primary and Secondary")
    func testBidirectionalRouting() {
        let fromPrimary = router.route(detectedLanguage: "uk")
        #expect(fromPrimary.source == "uk")
        #expect(fromPrimary.target == "en")
        
        let fromSecondary = router.route(detectedLanguage: "en")
        #expect(fromSecondary.source == "en")
        #expect(fromSecondary.target == "uk")
    }
    
    @Test("Third language routes to fallback target")
    func testThirdLanguageRouting() {
        let fromGerman = router.route(detectedLanguage: "de")
        #expect(fromGerman.source == "de")
        #expect(fromGerman.target == "en")
        
        let fromPolish = router.route(detectedLanguage: "pl")
        #expect(fromPolish.source == "pl")
        #expect(fromPolish.target == "en")
    }
    
    @Test("Fallback collision avoidance")
    func testFallbackCollision() {
        // When detected language matches fallback, target must switch to primary
        let customRouter = LanguagePairRouter(primary: "uk", secondary: "fr", fallback: "de")
        let fromGerman = customRouter.route(detectedLanguage: "de")
        #expect(fromGerman.source == "de")
        #expect(fromGerman.target == "uk")
    }
    
    @Test("Undetected language routes to default pair")
    func testUndetectedRouting() {
        let nilRoute = router.route(detectedLanguage: nil)
        #expect(nilRoute.source == "en")
        #expect(nilRoute.target == "uk")
        
        let emptyRoute = router.route(detectedLanguage: "")
        #expect(emptyRoute.source == "en")
        #expect(emptyRoute.target == "uk")
        
        let whitespaceRoute = router.route(detectedLanguage: "   \n\t  ")
        #expect(whitespaceRoute.source == "en")
        #expect(whitespaceRoute.target == "uk")
    }
    
    @Test("Static resolveTargetLanguage contract compliance")
    func testStaticContract() {
        let result = LanguagePairRouter.resolveTargetLanguage(
            for: "uk",
            primary: "uk",
            secondary: "en",
            fallback: "en"
        )
        #expect(result.source == "uk")
        #expect(result.target == "en")
        
        let resultFallback = LanguagePairRouter.resolveTargetLanguage(
            for: "es",
            primary: "uk",
            secondary: "en",
            fallback: "fr"
        )
        #expect(resultFallback.source == "es")
        #expect(resultFallback.target == "fr")
    }
}
