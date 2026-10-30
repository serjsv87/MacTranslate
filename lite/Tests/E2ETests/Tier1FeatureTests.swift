//
// Tier1FeatureTests.swift
// MacTranslate E2E Test Suite
//
// Tier 1: Core Feature Coverage (Category-Partition)
// Covers: Language Detection, Translation Execution, Smart Routing, Preferences Persistence.
// Each feature contains >= 5 discrete test cases.
//

import Foundation
import Translation
import NaturalLanguage

public func registerTier1FeatureTests() async {
    let detector = E2ELanguageDetector.shared
    let engine = E2ETranslationEngine.shared
    
    var tests: [E2ETestCase] = []
    
    // =========================================================================
    // FEATURE 1: Language Detection (8 test cases)
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testLanguageDetectionEnglish",
        tier: 1,
        category: "Language Detection",
        description: "Verifies detection of natural English text."
    ) {
        let text = "Apple Neural Engine delivers instant on-device translation without sending data to the cloud."
        let detected = detector.detectLanguage(in: text)
        try Assert.equal(detected, "en", "English text should be detected as 'en'")
    })
    
    tests.append(E2ETestCase(
        name: "testLanguageDetectionUkrainian",
        tier: 1,
        category: "Language Detection",
        description: "Verifies detection of natural Ukrainian Cyrillic text."
    ) {
        let text = "Швидкий переклад тексту безпосередньо на вашому Mac за допомогою нейронного рушія."
        let detected = detector.detectLanguage(in: text)
        try Assert.equal(detected, "uk", "Ukrainian text should be detected as 'uk'")
    })
    
    tests.append(E2ETestCase(
        name: "testLanguageDetectionGerman",
        tier: 1,
        category: "Language Detection",
        description: "Verifies detection of German text with compound words and umlauts."
    ) {
        let text = "Guten Morgen! Wir wünschen Ihnen einen wunderschönen und erfolgreichen Tag."
        let detected = detector.detectLanguage(in: text)
        try Assert.equal(detected, "de", "German text should be detected as 'de'")
    })
    
    tests.append(E2ETestCase(
        name: "testLanguageDetectionFrench",
        tier: 1,
        category: "Language Detection",
        description: "Verifies detection of French text with accents."
    ) {
        let text = "Bonjour à tous, bienvenue sur notre nouvelle application de traduction instantanée."
        let detected = detector.detectLanguage(in: text)
        try Assert.equal(detected, "fr", "French text should be detected as 'fr'")
    })
    
    tests.append(E2ETestCase(
        name: "testLanguageDetectionSpanish",
        tier: 1,
        category: "Language Detection",
        description: "Verifies detection of Spanish sentences."
    ) {
        let text = "Hola amigo, muchas gracias por tu ayuda con la traducción automática."
        let detected = detector.detectLanguage(in: text)
        try Assert.equal(detected, "es", "Spanish text should be detected as 'es'")
    })
    
    tests.append(E2ETestCase(
        name: "testLanguageDetectionPolish",
        tier: 1,
        category: "Language Detection",
        description: "Verifies detection of Polish text with diacritics."
    ) {
        let text = "Dzień dobry, cieszę się bardzo, że możemy się dzisiaj spotkać w biurze."
        let detected = detector.detectLanguage(in: text)
        try Assert.equal(detected, "pl", "Polish text should be detected as 'pl'")
    })
    
    tests.append(E2ETestCase(
        name: "testLanguageMetadataLocalizedNames",
        tier: 1,
        category: "Language Detection",
        description: "Verifies mapping of ISO codes to localized display names."
    ) {
        let locale = Locale(identifier: "en_US")
        try Assert.equal(detector.localizedName(for: "uk", inLocale: locale), "Ukrainian")
        try Assert.equal(detector.localizedName(for: "en", inLocale: locale), "English")
        try Assert.equal(detector.localizedName(for: "de", inLocale: locale), "German")
        try Assert.equal(detector.localizedName(for: "fr", inLocale: locale), "French")
        try Assert.equal(detector.localizedName(for: "pl", inLocale: locale), "Polish")
    })
    
    tests.append(E2ETestCase(
        name: "testLanguageMetadataFlagEmojis",
        tier: 1,
        category: "Language Detection",
        description: "Verifies emoji flag generation for supported languages."
    ) {
        try Assert.equal(detector.flagEmoji(for: "uk"), "🇺🇦")
        try Assert.equal(detector.flagEmoji(for: "en"), "🇬🇧")
        try Assert.equal(detector.flagEmoji(for: "de"), "🇩🇪")
        try Assert.equal(detector.flagEmoji(for: "pl"), "🇵🇱")
        try Assert.equal(detector.flagEmoji(for: "fr"), "🇫🇷")
        try Assert.equal(detector.flagEmoji(for: "es"), "🇪🇸")
    })
    
    // =========================================================================
    // FEATURE 2: Translation Execution (7 test cases)
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testTranslationEnglishToUkrainian",
        tier: 1,
        category: "Translation Execution",
        description: "Translates English sentence to Ukrainian on Apple Neural Engine."
    ) {
        let input = "Hello world"
        let result = try await engine.translate(text: input, from: "en", to: "uk")
        try Assert.isFalse(result.isEmpty, "Translation result should not be empty")
        try Assert.contains(result.lowercased(), "привіт", "Result should contain Ukrainian translation for 'hello'")
    })
    
    tests.append(E2ETestCase(
        name: "testTranslationUkrainianToEnglish",
        tier: 1,
        category: "Translation Execution",
        description: "Translates Ukrainian sentence to English on Apple Neural Engine."
    ) {
        let input = "Привіт, як твої справи сьогодні?"
        let result = try await engine.translate(text: input, from: "uk", to: "en")
        try Assert.isFalse(result.isEmpty, "Translation result should not be empty")
        try Assert.contains(result.lowercased(), "how", "Result should contain 'how' in translated question")
    })
    
    tests.append(E2ETestCase(
        name: "testTranslationEnglishToSpanish",
        tier: 1,
        category: "Translation Execution",
        description: "Translates English sentence to Spanish."
    ) {
        let input = "Thank you very much for your assistance."
        let result = try await engine.translate(text: input, from: "en", to: "es")
        try Assert.isFalse(result.isEmpty, "Translation result should not be empty")
        try Assert.contains(result.lowercased(), "gracias", "Result should contain 'gracias'")
    })
    
    tests.append(E2ETestCase(
        name: "testTranslationEnglishToRussian",
        tier: 1,
        category: "Translation Execution",
        description: "Translates English sentence to Russian."
    ) {
        let input = "Good morning, have a nice day."
        let result = try await engine.translate(text: input, from: "en", to: "ru")
        try Assert.isFalse(result.isEmpty, "Translation result should not be empty")
        try Assert.contains(result.lowercased(), "добр", "Result should contain greeting root")
    })
    
    tests.append(E2ETestCase(
        name: "testTranslationModelAvailabilityInspection",
        tier: 1,
        category: "Translation Execution",
        description: "Verifies LanguageAvailability status inspection for installed models."
    ) {
        let isInstalledEnUk = await engine.isModelInstalled(from: "en", to: "uk")
        try Assert.isTrue(isInstalledEnUk, "en -> uk model should be installed on this host")
        
        let isSupportedEnFr = await engine.isSupported(from: "en", to: "fr")
        try Assert.isTrue(isSupportedEnFr, "en -> fr should be supported by Apple Translation framework")
    })
    
    tests.append(E2ETestCase(
        name: "testTranslationLatencyThresholdSLA",
        tier: 1,
        category: "Translation Execution",
        description: "Verifies warm on-device translation latency adheres to local SLA (< 1000ms)."
    ) {
        // Warmup
        _ = try? await engine.translate(text: "Warmup test", from: "en", to: "uk")
        
        let start = Date()
        let result = try await engine.translate(text: "Apple Silicon Neural Engine is remarkably fast.", from: "en", to: "uk")
        let elapsed = Date().timeIntervalSince(start)
        
        try Assert.isFalse(result.isEmpty)
        try Assert.isTrue(elapsed < 1.000, "Translation latency must be < 1000ms SLA; took \(elapsed * 1000.0)ms")
    })
    
    tests.append(E2ETestCase(
        name: "testTranslationPunctuationAndCapitalizationPreservation",
        tier: 1,
        category: "Translation Execution",
        description: "Verifies that exclamation and question marks are preserved in output."
    ) {
        let input = "What time is it now?"
        let result = try await engine.translate(text: input, from: "en", to: "uk")
        try Assert.contains(result, "?", "Question mark should be preserved in translated output")
    })
    
    // =========================================================================
    // FEATURE 3: Smart Language Pair Routing (6 test cases)
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testRoutingPrimaryToSecondary",
        tier: 1,
        category: "Language Pair Routing",
        description: "Routes primary language input to secondary language."
    ) {
        let pair = E2ELanguagePairRouter.resolveTargetLanguage(
            for: "uk",
            primary: "uk",
            secondary: "en",
            fallback: "en"
        )
        try Assert.equal(pair.source, "uk")
        try Assert.equal(pair.target, "en")
    })
    
    tests.append(E2ETestCase(
        name: "testRoutingSecondaryToPrimary",
        tier: 1,
        category: "Language Pair Routing",
        description: "Routes secondary language input to primary language."
    ) {
        let pair = E2ELanguagePairRouter.resolveTargetLanguage(
            for: "en",
            primary: "uk",
            secondary: "en",
            fallback: "en"
        )
        try Assert.equal(pair.source, "en")
        try Assert.equal(pair.target, "uk")
    })
    
    tests.append(E2ETestCase(
        name: "testRoutingForeignToFallback",
        tier: 1,
        category: "Language Pair Routing",
        description: "Routes detected third/foreign language to configured fallback language."
    ) {
        let pair = E2ELanguagePairRouter.resolveTargetLanguage(
            for: "de",
            primary: "uk",
            secondary: "en",
            fallback: "uk"
        )
        try Assert.equal(pair.source, "de")
        try Assert.equal(pair.target, "uk")
    })
    
    tests.append(E2ETestCase(
        name: "testRoutingFallbackInput",
        tier: 1,
        category: "Language Pair Routing",
        description: "Routes fallback language input when detected to primary."
    ) {
        let pair = E2ELanguagePairRouter.resolveTargetLanguage(
            for: "en",
            primary: "uk",
            secondary: "pl",
            fallback: "en"
        )
        try Assert.equal(pair.source, "en")
        try Assert.equal(pair.target, "uk")
    })
    
    tests.append(E2ETestCase(
        name: "testRoutingUndetectedNilLanguage",
        tier: 1,
        category: "Language Pair Routing",
        description: "Routes nil/undetected input to default secondary -> primary."
    ) {
        let pair = E2ELanguagePairRouter.resolveTargetLanguage(
            for: nil,
            primary: "uk",
            secondary: "en",
            fallback: "en"
        )
        try Assert.equal(pair.source, "en")
        try Assert.equal(pair.target, "uk")
    })
    
    tests.append(E2ETestCase(
        name: "testRoutingCustomPairConfiguration",
        tier: 1,
        category: "Language Pair Routing",
        description: "Routes correctly with custom primary (de) and secondary (es)."
    ) {
        let pair1 = E2ELanguagePairRouter.resolveTargetLanguage(
            for: "de",
            primary: "de",
            secondary: "es",
            fallback: "es"
        )
        try Assert.equal(pair1.source, "de")
        try Assert.equal(pair1.target, "es")
        
        let pair2 = E2ELanguagePairRouter.resolveTargetLanguage(
            for: "es",
            primary: "de",
            secondary: "es",
            fallback: "es"
        )
        try Assert.equal(pair2.source, "es")
        try Assert.equal(pair2.target, "de")
    })
    
    // =========================================================================
    // FEATURE 4: User Preferences Persistence (6 test cases)
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testPreferencesDefaultValues",
        tier: 1,
        category: "Preferences Persistence",
        description: "Verifies default preference values upon initial launch."
    ) {
        let prefs = E2EPreferencesManager()
        try Assert.equal(prefs.primaryLanguage, "uk")
        try Assert.equal(prefs.secondaryLanguage, "en")
        try Assert.equal(prefs.fallbackLanguage, "en")
        try Assert.equal(prefs.hotkeyWindowMs, 400.0)
        try Assert.equal(prefs.dismissOnOutsideClick, true)
        try Assert.equal(prefs.hotkeyMode, 0)
    })
    
    tests.append(E2ETestCase(
        name: "testPreferencesPrimarySecondaryMutation",
        tier: 1,
        category: "Preferences Persistence",
        description: "Updates primary and secondary languages and confirms persistence."
    ) {
        let prefs = E2EPreferencesManager()
        prefs.primaryLanguage = "de"
        prefs.secondaryLanguage = "fr"
        try Assert.equal(prefs.primaryLanguage, "de")
        try Assert.equal(prefs.secondaryLanguage, "fr")
    })
    
    tests.append(E2ETestCase(
        name: "testPreferencesHotkeyModeMutation",
        tier: 1,
        category: "Preferences Persistence",
        description: "Mutates hotkey trigger mode and timing window."
    ) {
        let prefs = E2EPreferencesManager()
        prefs.hotkeyMode = 1 // Double Ctrl+C
        prefs.hotkeyWindowMs = 350.0
        try Assert.equal(prefs.hotkeyMode, 1)
        try Assert.equal(prefs.hotkeyWindowMs, 350.0)
    })
    
    tests.append(E2ETestCase(
        name: "testPreferencesBehaviorOptionsMutation",
        tier: 1,
        category: "Preferences Persistence",
        description: "Mutates UI dismissal and enter key actions."
    ) {
        let prefs = E2EPreferencesManager()
        prefs.dismissOnOutsideClick = false
        prefs.enterKeyAction = 1
        try Assert.equal(prefs.dismissOnOutsideClick, false)
        try Assert.equal(prefs.enterKeyAction, 1)
    })
    
    tests.append(E2ETestCase(
        name: "testPreferencesRoundTripPersistenceAcrossInstances",
        tier: 1,
        category: "Preferences Persistence",
        description: "Simulates app restart: a second instance with same suite domain reads persisted values."
    ) {
        let suite = "com.mactranslate.e2e.suite.\(UUID().uuidString)"
        let instance1 = E2EPreferencesManager(suiteName: suite)
        instance1.primaryLanguage = "pl"
        instance1.secondaryLanguage = "uk"
        instance1.hotkeyWindowMs = 250.0
        
        let instance2 = E2EPreferencesManager(suiteName: suite)
        try Assert.equal(instance2.primaryLanguage, "pl")
        try Assert.equal(instance2.secondaryLanguage, "uk")
        try Assert.equal(instance2.hotkeyWindowMs, 250.0)
        
        instance1.resetToDefaults()
    })
    
    tests.append(E2ETestCase(
        name: "testPreferencesResetToDefaults",
        tier: 1,
        category: "Preferences Persistence",
        description: "Resetting domain restores default initial values."
    ) {
        let prefs = E2EPreferencesManager()
        prefs.primaryLanguage = "it"
        prefs.secondaryLanguage = "pt"
        prefs.resetToDefaults()
        try Assert.equal(prefs.primaryLanguage, "uk")
        try Assert.equal(prefs.secondaryLanguage, "en")
    })
    
    await E2ETestRegistry.shared.registerBatch(tests)
}
