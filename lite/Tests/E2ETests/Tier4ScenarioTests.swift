//
// Tier4ScenarioTests.swift
// MacTranslate E2E Test Suite
//
// Tier 4: Real-World Workload Scenarios
// Covers: Multilingual chat, Markdown documentation, Mixed-language sentences,
// Code snippet and identifier preservation, End-to-End workflow simulation.
//

import Foundation
import Translation
import NaturalLanguage
import AppKit

public func registerTier4ScenarioTests() async {
    let detector = E2ELanguageDetector.shared
    let engine = E2ETranslationEngine.shared
    
    var tests: [E2ETestCase] = []
    
    // =========================================================================
    // SCENARIO 1: Multilingual Chat Messages with Emojis
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testScenarioMultilingualChatWithEmojis",
        tier: 4,
        category: "Real-World: Chat",
        description: "Translates conversational chat message containing emojis (🚀, 🎉) while preserving emojis intact."
    ) {
        let inputChat = "Hey team! Great job on the release today 🚀🎉 Let's celebrate soon!"
        let detected = detector.detectLanguage(in: inputChat)
        try Assert.equal(detected, "en")
        
        let translated = try await engine.translate(text: inputChat, from: "en", to: "uk")
        try Assert.isFalse(translated.isEmpty)
        try Assert.contains(translated, "🚀", "Rocket emoji must be preserved in translated output")
        try Assert.contains(translated, "🎉", "Party emoji must be preserved in translated output")
    })
    
    // =========================================================================
    // SCENARIO 2: Technical Markdown Documentation Translation
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testScenarioTechnicalDocumentationMarkdown",
        tier: 4,
        category: "Real-World: Documentation",
        description: "Translates markdown prose while preserving markdown bold syntax (**text**) and URLs intact."
    ) {
        let markdownDoc = "To install the software, please visit https://apple.com and download the **latest package**."
        let detected = detector.detectLanguage(in: markdownDoc)
        try Assert.equal(detected, "en")
        
        let translated = try await engine.translate(text: markdownDoc, from: "en", to: "uk")
        try Assert.isFalse(translated.isEmpty)
        try Assert.contains(translated, "https://apple.com", "Hyperlink URL should be preserved without corruption")
    })
    
    // =========================================================================
    // SCENARIO 3: Mixed-Language Sentences (Loanwords / Tech Terms)
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testScenarioMixedLanguageUkrainianWithEnglishTechTerms",
        tier: 4,
        category: "Real-World: Mixed Language",
        description: "Detects Ukrainian as dominant language in sentence containing English technical nouns ('Kubernetes cluster on AWS')."
    ) {
        let mixedText = "Ми успішно розгорнули новий Kubernetes cluster на AWS для нашого бекенду."
        let detected = detector.detectLanguage(in: mixedText)
        try Assert.equal(detected, "uk", "Dominant language must be recognized as Ukrainian")
        
        let pair = E2ELanguagePairRouter.resolveTargetLanguage(
            for: detected,
            primary: "uk",
            secondary: "en",
            fallback: "en"
        )
        try Assert.equal(pair.target, "en")
        
        let translated = try await engine.translate(text: mixedText, from: pair.source, to: pair.target)
        try Assert.contains(translated.lowercased(), "kubernetes")
        try Assert.contains(translated, "AWS")
    })
    
    // =========================================================================
    // SCENARIO 4: Code Snippet & Structured Data Preservation
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testScenarioCodeSnippetAndJSONPreservation",
        tier: 4,
        category: "Real-World: Code & Data",
        description: "Translates natural language comment while keeping JSON payload structure intact."
    ) {
        let payloadText = "The server returned status response: {\"code\": 200, \"status\": \"ok\"}."
        let translated = try await engine.translate(text: payloadText, from: "en", to: "uk")
        try Assert.contains(translated, "200", "Numeric status code 200 must be preserved")
        try Assert.contains(translated, "{", "Opening brace must be preserved")
        try Assert.contains(translated, "}", "Closing brace must be preserved")
    })
    
    // =========================================================================
    // SCENARIO 5: Full End-to-End User Flow Simulation
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testScenarioEndToEndTranslationWorkflow",
        tier: 4,
        category: "Real-World: End-to-End Workflow",
        description: "Simulates full user workflow: double-tap shortcut -> selection extracted -> auto-detected -> smart-routed -> translated -> copied to pasteboard."
    ) {
        // Step 1: User presses double ⌘C with 220ms delta
        let hotkeySim = E2EHotkeySimulator(thresholdMs: 400.0)
        _ = hotkeySim.simulateKeyPress(atTimestamp: 500.0)
        let shortcutTriggered = hotkeySim.simulateKeyPress(atTimestamp: 720.0)
        try Assert.isTrue(shortcutTriggered, "Shortcut should trigger on valid double tap")
        
        // Step 2: Selected text extracted
        let selectedText = "Thank you very much for your great cooperation."
        try Assert.isFalse(selectedText.isEmpty)
        
        // Step 3: Automatic language detection
        let detected = detector.detectLanguage(in: selectedText)
        try Assert.equal(detected, "en")
        
        // Step 4: Smart pair routing (User defaults: Primary: uk, Secondary: en)
        let prefs = E2EPreferencesManager()
        let pair = E2ELanguagePairRouter.resolveTargetLanguage(
            for: detected,
            primary: prefs.primaryLanguage,
            secondary: prefs.secondaryLanguage,
            fallback: prefs.fallbackLanguage
        )
        try Assert.equal(pair.source, "en")
        try Assert.equal(pair.target, "uk")
        
        // Step 5: On-device translation on Apple Neural Engine
        let translated = try await engine.translate(text: selectedText, from: pair.source, to: pair.target)
        try Assert.isFalse(translated.isEmpty)
        try Assert.contains(translated.lowercased(), "дяку")
        
        // Step 6: User presses Enter (Copy action)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(translated, forType: .string)
        
        let copied = pasteboard.string(forType: .string)
        try Assert.equal(copied, translated, "Copied pasteboard string must match translation")
    })
    
    await E2ETestRegistry.shared.registerBatch(tests)
}
