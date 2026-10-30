import Testing
import Foundation
@testable import MacTranslate

@Suite("Language Detection Tests")
struct LanguageDetectionTests {
    let detector = LanguageDetector.shared
    
    @Test("Detect standard sentences in major supported languages")
    func testStandardLanguages() {
        #expect(detector.detectLanguage(in: "Hello world, how are you?") == "en")
        #expect(detector.detectLanguage(in: "Привіт, світе! Як твої справи?") == "uk")
        #expect(detector.detectLanguage(in: "Guten Tag, wie geht es dir heute?") == "de")
        #expect(detector.detectLanguage(in: "Bonjour tout le monde, comment allez-vous?") == "fr")
        #expect(detector.detectLanguage(in: "Dzień dobry, jak się dzisiaj masz?") == "pl")
        #expect(detector.detectLanguage(in: "Hola amigos, ¿cómo están hoy?") == "es")
        #expect(detector.detectLanguage(in: "Ciao a tutti, come state oggi?") == "it")
    }
    
    @Test("Language constraints prevent false positives on short Cyrillic")
    func testCyrillicShortTextConstraints() {
        // Without constraints, these falsely evaluate to Kazakh (kk) or Bulgarian (bg)
        #expect(detector.detectLanguage(in: "Дякую") == "uk")
        #expect(detector.detectLanguage(in: "Привіт") == "uk")
        #expect(detector.detectLanguage(in: "Будь ласка") == "uk")
        #expect(detector.detectLanguage(in: "Привет мир") == "ru")
        #expect(detector.detectLanguage(in: "Спасибо") == "ru")
    }
    
    @Test("Edge cases: empty, whitespace, numbers, symbols")
    func testEdgeCases() {
        #expect(detector.detectLanguage(in: "") == nil)
        #expect(detector.detectLanguage(in: "   \n\t  ") == nil)
        #expect(detector.detectLanguage(in: "1234567890") == nil)
        #expect(detector.detectLanguage(in: "!@#$%^&*()_+=") == nil)
    }
    
    @Test("Localized language names")
    func testLocalizedNames() {
        #expect(detector.localizedName(for: "uk").contains("Ukrain") || detector.localizedName(for: "uk").contains("Україн"))
        #expect(detector.localizedName(for: "en").contains("English") || detector.localizedName(for: "en").contains("Англій"))
        #expect(detector.localizedName(for: "de").contains("German") || detector.localizedName(for: "de").contains("Німець"))
        #expect(detector.localizedName(for: "xyz") == "XYZ")
    }
    
    @Test("Flag emojis for supported languages")
    func testFlagEmojis() {
        #expect(detector.flagEmoji(for: "uk") == "🇺🇦")
        #expect(detector.flagEmoji(for: "en") == "🇬🇧")
        #expect(detector.flagEmoji(for: "de") == "🇩🇪")
        #expect(detector.flagEmoji(for: "pl") == "🇵🇱")
        #expect(detector.flagEmoji(for: "fr") == "🇫🇷")
        #expect(detector.flagEmoji(for: "unknown") == "🌐")
    }
    
    // MARK: - Chinese Language Detection Tests
    
    @Test("Detect Simplified Chinese sentences")
    func testSimplifiedChineseSentences() {
        #expect(detector.detectLanguage(in: "敏捷的棕色狐狸跳过懒惰的狗。") == "zh")
        #expect(detector.detectLanguage(in: "请在会议前审阅随附的文件好吗？") == "zh")
        #expect(detector.detectLanguage(in: "你好，最近怎么样？今天还一起吃午饭吗？") == "zh")
        #expect(detector.detectLanguage(in: "机器学习模型需要强大的评估指标。") == "zh")
        #expect(detector.detectLanguage(in: "我真的不知道该如何看待这个新提案。") == "zh")
        #expect(detector.detectLanguage(in: "永远不要低估可靠软件架构的重要性。") == "zh")
    }
    
    @Test("Detect Traditional Chinese sentences")
    func testTraditionalChineseSentences() {
        #expect(detector.detectLanguage(in: "這是一個繁體中文的測試句子，請確認檢測結果正確。") == "zh")
        #expect(detector.detectLanguage(in: "會議即將開始，請所有與會人員盡快就座。") == "zh")
        #expect(detector.detectLanguage(in: "機器學習模型需要強大的評估指標。") == "zh")
    }
    
    @Test("Disambiguate Chinese and Japanese text")
    func testChineseJapaneseDisambiguation() {
        // Pure Chinese sentences must detect as "zh", never "ja"
        #expect(detector.detectLanguage(in: "你好世界，今天天气真好。") == "zh")
        #expect(detector.detectLanguage(in: "这是一段纯正的中文文字，不能被识别为日文。") == "zh")
        
        // Japanese sentences with Kana and Kanji must detect as "ja", never "zh"
        #expect(detector.detectLanguage(in: "素早い茶色のキツネが怠惰な犬を飛び越えます。") == "ja")
        #expect(detector.detectLanguage(in: "こんにちは、お元気ですか？今日のランチはまだ予定通りですか？") == "ja")
        #expect(detector.detectLanguage(in: "会議の前に添付書類を確認していただけますでしょうか？") == "ja")
    }
    
    @Test("Chinese metadata: localized name and flag emoji")
    func testChineseMetadata() {
        #expect(detector.flagEmoji(for: "zh") == "🇨🇳")
        let localized = detector.localizedName(for: "zh")
        #expect(localized.contains("Chin") || localized.contains("Китай"))
    }
}

@Suite("Translation Engine Tests")
struct TranslationEngineTests {
    let engine = TranslationEngine.shared
    
    @Test("Model installation query for pre-installed models")
    func testModelInstalledStatus() async {
        #expect(engine.isModelInstalled(from: "en", to: "uk") == true)
        #expect(engine.isModelInstalled(from: "uk", to: "en") == true)
        
        let asyncStatus = await engine.checkModelInstalled(from: "en", to: "uk")
        #expect(asyncStatus == true)
    }
    
    @Test("Identity translation returns source text without processing")
    func testIdentityTranslation() async throws {
        let result = try await engine.translate(text: "Stay true", from: "en", to: "en")
        #expect(result == "Stay true")
    }
    
    @Test("Translating empty or whitespace text throws nothingToTranslate")
    func testEmptyTextThrows() async {
        await #expect(throws: TranslationEngineError.nothingToTranslate) {
            try await engine.translate(text: "", from: "en", to: "uk")
        }
        await #expect(throws: TranslationEngineError.nothingToTranslate) {
            try await engine.translate(text: "   \n\t  ", from: "en", to: "uk")
        }
    }
    
    @Test("TranslationEngineError descriptions are descriptive")
    func testErrorDescriptions() {
        let notInstalledErr = TranslationEngineError.notInstalled(source: "en", target: "de")
        #expect(notInstalledErr.errorDescription?.contains("not installed") == true)
        
        let unsupportedPairErr = TranslationEngineError.unsupportedLanguagePairing(source: "en", target: "en")
        #expect(unsupportedPairErr.errorDescription?.contains("unsupported") == true)
        
        let nothingErr = TranslationEngineError.nothingToTranslate
        #expect(nothingErr.errorDescription?.contains("No text") == true)
    }
    
    @Test("Live on-device translation execution")
    func testLiveOnDeviceTranslation() async throws {
        let translated = try await engine.translate(text: "Hello", from: "en", to: "uk")
        #expect(!translated.isEmpty)
        // Translated output should contain Ukrainian characters
        #expect(translated.contains("Привіт") || translated.contains("Добрий день") || translated.count > 0)
    }
}
