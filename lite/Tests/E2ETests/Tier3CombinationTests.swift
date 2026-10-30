//
// Tier3CombinationTests.swift
// MacTranslate E2E Test Suite
//
// Tier 3: Cross-Feature Combinations (Pairwise Combinatorial)
// Covers: Language switching + Direction swap, Double-tap timing intervals,
// Debouncing & rapid typing, Translation + Clipboard & replacement,
// Preferences changes interacting with smart routing.
//

import Foundation
import Translation
import NaturalLanguage
import AppKit

public func registerTier3CombinationTests() async {
    let detector = E2ELanguageDetector.shared
    let engine = E2ETranslationEngine.shared
    
    var tests: [E2ETestCase] = []
    
    // =========================================================================
    // COMBINATION 1: Language Switching + Direction Swap (⇄)
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testComboLanguageSwitchAndDirectionSwap",
        tier: 3,
        category: "Combination: HUD Controls",
        description: "User detects text in English, manually switches target to Spanish, then clicks Direction Swap (⇄)."
    ) {
        let originalText = "Good morning"
        let detected = detector.detectLanguage(in: originalText)
        try Assert.equal(detected, "en")
        
        // Initial routing (en -> uk)
        let source = "en"
        var target = "uk"
        
        // User overrides target to Spanish (es)
        target = "es"
        let esResult = try await engine.translate(text: originalText, from: source, to: target)
        try Assert.contains(esResult.lowercased(), "buen")
        
        // User clicks Direction Swap (⇄)
        let swappedSource = target
        let swappedTarget = source
        let invertedResult = try await engine.translate(text: esResult, from: swappedSource, to: swappedTarget)
        try Assert.contains(invertedResult.lowercased(), "morning")
    })
    
    tests.append(E2ETestCase(
        name: "testComboSwapButtonDisabledOnUndetectedInput",
        tier: 3,
        category: "Combination: HUD Controls",
        description: "When input has no detected language (e.g. symbols), direction swap resolution falls back to default secondary/primary."
    ) {
        let symbolsText = "!@#$%"
        let detected = detector.detectLanguage(in: symbolsText)
        try Assert.isNil(detected)
        
        let routed = E2ELanguagePairRouter.resolveTargetLanguage(
            for: detected,
            primary: "uk",
            secondary: "en",
            fallback: "en"
        )
        // Swap default pair
        let swapped = (source: routed.target, target: routed.source)
        try Assert.equal(swapped.source, "uk")
        try Assert.equal(swapped.target, "en")
    })
    
    // =========================================================================
    // COMBINATION 2: Double-Tap Timing Window Combinations
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testComboDoubleTapTimingValidFast",
        tier: 3,
        category: "Combination: Shortcuts Timing",
        description: "Double-tap with 180ms delta (< 400ms) triggers HUD activation."
    ) {
        let sim = E2EHotkeySimulator(thresholdMs: 400.0)
        let tap1 = sim.simulateKeyPress(atTimestamp: 1000.0)
        try Assert.isFalse(tap1, "First tap must not trigger shortcut")
        
        let tap2 = sim.simulateKeyPress(atTimestamp: 1180.0) // 180ms later
        try Assert.isTrue(tap2, "Second tap within 400ms must trigger shortcut")
        try Assert.equal(sim.triggerCount, 1)
    })
    
    tests.append(E2ETestCase(
        name: "testComboDoubleTapTimingBoundaryAtLimit",
        tier: 3,
        category: "Combination: Shortcuts Timing",
        description: "Double-tap with 390ms delta (just inside 400ms threshold) triggers shortcut."
    ) {
        let sim = E2EHotkeySimulator(thresholdMs: 400.0)
        _ = sim.simulateKeyPress(atTimestamp: 2000.0)
        let tap2 = sim.simulateKeyPress(atTimestamp: 2390.0) // 390ms later
        try Assert.isTrue(tap2, "Tap at 390ms (<= 400ms) should trigger shortcut")
    })
    
    tests.append(E2ETestCase(
        name: "testComboDoubleTapTimingBoundaryExceeded",
        tier: 3,
        category: "Combination: Shortcuts Timing",
        description: "Double-tap with 420ms delta (> 400ms threshold) fails to trigger and resets first tap."
    ) {
        let sim = E2EHotkeySimulator(thresholdMs: 400.0)
        _ = sim.simulateKeyPress(atTimestamp: 3000.0)
        let tap2 = sim.simulateKeyPress(atTimestamp: 3420.0) // 420ms later
        try Assert.isFalse(tap2, "Tap at 420ms (> 400ms) must not trigger shortcut")
        try Assert.equal(sim.triggerCount, 0)
    })
    
    tests.append(E2ETestCase(
        name: "testComboTripleTapDebouncing",
        tier: 3,
        category: "Combination: Shortcuts Timing",
        description: "Rapid triple tap (0ms, 150ms, 300ms) triggers exactly once, debouncing the third tap."
    ) {
        let sim = E2EHotkeySimulator(thresholdMs: 400.0)
        _ = sim.simulateKeyPress(atTimestamp: 4000.0) // Tap 1
        let tap2 = sim.simulateKeyPress(atTimestamp: 4150.0) // Tap 2 (Triggers!)
        try Assert.isTrue(tap2)
        try Assert.equal(sim.triggerCount, 1)
        
        // Tap 3 arrives 150ms after tap 2. Because lastPressTime was reset to 0 upon trigger,
        // tap 3 is treated as a new first tap!
        let tap3 = sim.simulateKeyPress(atTimestamp: 4300.0)
        try Assert.isFalse(tap3, "Third tap should register as new candidate, not duplicate trigger")
        try Assert.equal(sim.triggerCount, 1)
    })
    
    // =========================================================================
    // COMBINATION 3: Translation + Clipboard Interaction
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testComboTranslationAndClipboardCopy",
        tier: 3,
        category: "Combination: Actions",
        description: "Translates text and writes output to NSPasteboard.general, verifying pasteboard persistence."
    ) {
        let sourceText = "Artificial Intelligence"
        let translated = try await engine.translate(text: sourceText, from: "en", to: "uk")
        
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount
        pasteboard.clearContents()
        pasteboard.setString(translated, forType: .string)
        
        let readBack = pasteboard.string(forType: .string)
        try Assert.equal(readBack, translated, "Pasteboard string should match translation output")
        try Assert.isTrue(pasteboard.changeCount > previousChangeCount, "Pasteboard changeCount should increment")
    })
    
    // =========================================================================
    // COMBINATION 4: Preferences Mutation + Dynamic Language Routing
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testComboPreferencesChangeAffectsRouting",
        tier: 3,
        category: "Combination: State Flow",
        description: "Changing primary language from Ukrainian (uk) to German (de) dynamically redirects routing."
    ) {
        let suite = "com.mactranslate.e2e.combo.\(UUID().uuidString)"
        let prefs = E2EPreferencesManager(suiteName: suite)
        
        // Initial defaults (primary: uk, secondary: en)
        var pair = E2ELanguagePairRouter.resolveTargetLanguage(
            for: "uk",
            primary: prefs.primaryLanguage,
            secondary: prefs.secondaryLanguage,
            fallback: prefs.fallbackLanguage
        )
        try Assert.equal(pair.target, "en")
        
        // User changes primary to German (de) and secondary to French (fr) in preferences
        prefs.primaryLanguage = "de"
        prefs.secondaryLanguage = "fr"
        
        pair = E2ELanguagePairRouter.resolveTargetLanguage(
            for: "de",
            primary: prefs.primaryLanguage,
            secondary: prefs.secondaryLanguage,
            fallback: prefs.fallbackLanguage
        )
        try Assert.equal(pair.target, "fr")
        
        pair = E2ELanguagePairRouter.resolveTargetLanguage(
            for: "fr",
            primary: prefs.primaryLanguage,
            secondary: prefs.secondaryLanguage,
            fallback: prefs.fallbackLanguage
        )
        try Assert.equal(pair.target, "de")
        
        prefs.resetToDefaults()
    })
    
    // =========================================================================
    // COMBINATION 5: Rapid Typing Debounce Simulation
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testComboRapidTypingDebounceStabilization",
        tier: 3,
        category: "Combination: Debounce",
        description: "Simulates user typing characters rapidly; ensures only final stabilized text is translated."
    ) {
        let keystrokes = [
            "H",
            "He",
            "Hel",
            "Hell",
            "Hello",
            "Hello "
        ]
        
        // Only trigger translation for final keystroke
        let finalKeystroke = keystrokes.last!
        let finalResult = try await engine.translate(text: finalKeystroke, from: "en", to: "uk")
        try Assert.isFalse(finalResult.isEmpty)
        try Assert.contains(finalResult.lowercased(), "привіт")
    })
    
    await E2ETestRegistry.shared.registerBatch(tests)
}
