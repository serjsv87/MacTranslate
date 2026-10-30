//
// Tier2BoundaryTests.swift
// MacTranslate E2E Test Suite
//
// Tier 2: Boundary & Corner Cases (Boundary Value Analysis)
// Covers: Empty strings, whitespace, numbers, symbols, extreme lengths,
// uninstalled languages, rapid typing bursts, and screen geometry clamping.
//

import Foundation
import Translation
import NaturalLanguage
import AppKit

public func registerTier2BoundaryTests() async {
    let detector = E2ELanguageDetector.shared
    let engine = E2ETranslationEngine.shared
    
    var tests: [E2ETestCase] = []
    
    // =========================================================================
    // BOUNDARY: Empty & Whitespace Inputs
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testBoundaryEmptyStringDetection",
        tier: 2,
        category: "Boundary: Empty Inputs",
        description: "Language detection on empty string returns nil without crashing."
    ) {
        let detected = detector.detectLanguage(in: "")
        try Assert.isNil(detected, "Empty string should produce nil detected language")
    })
    
    tests.append(E2ETestCase(
        name: "testBoundaryWhitespaceOnlyDetection",
        tier: 2,
        category: "Boundary: Empty Inputs",
        description: "Language detection on tabs, spaces, and newlines returns nil."
    ) {
        let detected = detector.detectLanguage(in: "   \t\n  \r\n   ")
        try Assert.isNil(detected, "Whitespace-only input should produce nil detected language")
    })
    
    tests.append(E2ETestCase(
        name: "testBoundaryEmptyStringTranslationThrows",
        tier: 2,
        category: "Boundary: Empty Inputs",
        description: "Translation on empty string throws nothingToTranslate or handles gracefully."
    ) {
        do {
            _ = try await engine.translate(text: "", from: "en", to: "uk")
            throw TestAssertionFailure(message: "Expected translation on empty string to throw error", file: #file, line: #line)
        } catch let err as TestAssertionFailure {
            throw err
        } catch {
            // Success: expected error was thrown
            try Assert.isTrue(error.localizedDescription.count > 0)
        }
    })
    
    tests.append(E2ETestCase(
        name: "testBoundaryWhitespaceStringTranslationThrows",
        tier: 2,
        category: "Boundary: Empty Inputs",
        description: "Translation on whitespace-only string throws or produces empty result."
    ) {
        do {
            _ = try await engine.translate(text: "    \n\t  ", from: "en", to: "uk")
            throw TestAssertionFailure(message: "Expected whitespace string to throw error", file: #file, line: #line)
        } catch let err as TestAssertionFailure {
            throw err
        } catch {
            // Success: expected error was thrown
            try Assert.isTrue(error.localizedDescription.count > 0)
        }
    })
    
    // =========================================================================
    // BOUNDARY: Numbers, Symbols & Punctuation
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testBoundaryNumbersOnlyDetection",
        tier: 2,
        category: "Boundary: Non-Linguistic",
        description: "Numeric string without linguistic tokens returns nil."
    ) {
        let detected = detector.detectLanguage(in: "1234567890 3.14159 42")
        try Assert.isNil(detected, "Numbers only should return nil language")
    })
    
    tests.append(E2ETestCase(
        name: "testBoundarySymbolsAndPunctuationDetection",
        tier: 2,
        category: "Boundary: Non-Linguistic",
        description: "ASCII symbols and punctuation without letters returns nil."
    ) {
        let detected = detector.detectLanguage(in: "!@#$%^&*()_+-=[]{}|;':\",./<>?`~")
        try Assert.isNil(detected, "Punctuation and symbols only should return nil language")
    })
    
    tests.append(E2ETestCase(
        name: "testBoundaryShortTextConstraintsResolution",
        tier: 2,
        category: "Boundary: Short Text Ambiguity",
        description: "Short Cyrillic text ('Привет мир') with languageConstraints resolves to Russian or Ukrainian, not unsupported languages."
    ) {
        let detected = detector.detectLanguage(in: "Привет мир")
        try Assert.notNil(detected)
        try Assert.isTrue(detected == "ru" || detected == "uk", "Cyrillic input should resolve to supported Cyrillic language; got: \(detected ?? "")")
    })
    
    // =========================================================================
    // BOUNDARY: Unsupported & Uninstalled Language Handling
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testBoundaryUnsupportedLanguageCodeThrows",
        tier: 2,
        category: "Boundary: Error Handling",
        description: "Attempting translation with invalid BCP-47 identifier throws an error."
    ) {
        do {
            _ = try await engine.translate(text: "Hello", from: "en", to: "zz_invalid")
            throw TestAssertionFailure(message: "Expected invalid language pair to throw error", file: #file, line: #line)
        } catch let err as TestAssertionFailure {
            throw err
        } catch {
            // Successfully caught translation error
            try Assert.isTrue(error.localizedDescription.count > 0)
        }
    })
    
    tests.append(E2ETestCase(
        name: "testBoundaryUnsupportedSourceLanguageInspection",
        tier: 2,
        category: "Boundary: Error Handling",
        description: "LanguageAvailability inspects and flags unsupported language pair."
    ) {
        let isSupported = await engine.isSupported(from: "fake_lang", to: "en")
        try Assert.isFalse(isSupported, "Fake language should be reported as unsupported")
    })
    
    // =========================================================================
    // BOUNDARY: Extreme Text Lengths
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testBoundaryLongTextPayload",
        tier: 2,
        category: "Boundary: Extreme Payload",
        description: "Large paragraph (over 1,000 characters) translates successfully on Apple Neural Engine."
    ) {
        let baseParagraph = "The Apple Neural Engine is a specialized hardware component designed specifically for accelerating machine learning and neural network computations locally on Apple Silicon devices. It enables instantaneous on-device language translation without sending sensitive user information over the network. "
        let largeText = String(repeating: baseParagraph, count: 4) // ~1,200 characters
        
        let result = try await engine.translate(text: largeText, from: "en", to: "uk")
        try Assert.isFalse(result.isEmpty)
        try Assert.isTrue(result.count > 500, "Translated result should be proportional to input length")
    })
    
    // =========================================================================
    // BOUNDARY: Rapid Bursts & Concurrency Stress
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testBoundaryRapidConsecutiveTranslations",
        tier: 2,
        category: "Boundary: Concurrency",
        description: "Executes 10 rapid sequential translations simulating live user typing."
    ) {
        let phrases = [
            "Hello",
            "Hello world",
            "Hello world this",
            "Hello world this is",
            "Hello world this is a",
            "Hello world this is a fast",
            "Hello world this is a fast test",
            "Done",
            "Good morning",
            "Goodbye"
        ]
        
        for phrase in phrases {
            let translated = try await engine.translate(text: phrase, from: "en", to: "uk")
            try Assert.isFalse(translated.isEmpty)
        }
    })
    
    // =========================================================================
    // BOUNDARY: Screen Geometry Clamping
    // =========================================================================
    
    tests.append(E2ETestCase(
        name: "testBoundaryScreenGeometryClampingTopRight",
        tier: 2,
        category: "Boundary: Geometry",
        description: "Cursor positioned at top-right edge clamps panel inside visible screen frame."
    ) {
        let visibleFrame = NSRect(x: 0, y: 25, width: 1920, height: 1030) // Excludes menu bar & dock
        let panelSize = NSSize(width: 440, height: 260)
        
        let cursor = NSPoint(x: 1910, y: 1050) // Very close to top right
        let origin = E2EGeometryHelper.clampWindowOrigin(
            cursor: cursor,
            windowSize: panelSize,
            screenVisibleFrame: visibleFrame
        )
        
        let panelFrame = NSRect(origin: origin, size: panelSize)
        try Assert.isTrue(panelFrame.maxX <= visibleFrame.maxX, "Panel must not exceed screen right edge")
        try Assert.isTrue(panelFrame.maxY <= visibleFrame.maxY, "Panel must not exceed screen top edge")
    })
    
    tests.append(E2ETestCase(
        name: "testBoundaryScreenGeometryClampingBottomLeft",
        tier: 2,
        category: "Boundary: Geometry",
        description: "Cursor positioned at bottom-left corner flips or clamps above dock."
    ) {
        let visibleFrame = NSRect(x: 0, y: 80, width: 1920, height: 975) // Dock at bottom
        let panelSize = NSSize(width: 440, height: 260)
        
        let cursor = NSPoint(x: 10, y: 85) // Bottom-left near dock
        let origin = E2EGeometryHelper.clampWindowOrigin(
            cursor: cursor,
            windowSize: panelSize,
            screenVisibleFrame: visibleFrame
        )
        
        let panelFrame = NSRect(origin: origin, size: panelSize)
        try Assert.isTrue(panelFrame.minX >= visibleFrame.minX, "Panel must stay inside screen left margin")
        try Assert.isTrue(panelFrame.minY >= visibleFrame.minY, "Panel must stay above bottom dock margin")
    })
    
    await E2ETestRegistry.shared.registerBatch(tests)
}
