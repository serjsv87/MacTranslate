//
// E2ETestHarness.swift
// MacTranslate E2E Test Suite
//
// Systematic 4-tier requirement-driven opaque-box test harness.
// Zero dependencies on Xcode/SwiftUI macros — 100% Apple Command Line Tools compatible.
//

import Foundation
import NaturalLanguage
import Translation
import AppKit

// MARK: - Assertion Types & Errors

public struct TestAssertionFailure: Error, Sendable, CustomStringConvertible {
    public let message: String
    public let file: String
    public let line: Int
    
    public var description: String {
        return "\(file):\(line): \(message)"
    }
}

public enum E2ETranslationError: Error, CustomStringConvertible, Sendable {
    case nothingToTranslate
    case unsupportedLanguagePairing
    case notInstalled
    case custom(String)
    
    public var description: String {
        switch self {
        case .nothingToTranslate: return "Nothing to translate"
        case .unsupportedLanguagePairing: return "Unsupported language pairing"
        case .notInstalled: return "Language model not installed"
        case .custom(let msg): return msg
        }
    }
}

public enum TestStatus: Sendable, Equatable {
    case passed
    case failed(String)
    case skipped(String)
}

public struct TestCaseResult: Sendable {
    public let name: String
    public let tier: Int
    public let category: String
    public let status: TestStatus
    public let duration: TimeInterval
    public let details: String?
    
    public var isSuccess: Bool {
        if case .passed = status { return true }
        return false
    }
}

// MARK: - Assertion Utilities

public enum Assert {
    public static func equal<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ message: String = "",
        file: String = #file,
        line: Int = #line
    ) throws {
        if actual != expected {
            let detail = message.isEmpty ? "Expected [\(expected)], got [\(actual)]" : "\(message) (Expected [\(expected)], got [\(actual)])"
            throw TestAssertionFailure(message: detail, file: file, line: line)
        }
    }
    
    public static func notEqual<T: Equatable>(
        _ actual: T,
        _ unexpected: T,
        _ message: String = "",
        file: String = #file,
        line: Int = #line
    ) throws {
        if actual == unexpected {
            let detail = message.isEmpty ? "Value should not equal [\(unexpected)]" : message
            throw TestAssertionFailure(message: detail, file: file, line: line)
        }
    }
    
    public static func isTrue(
        _ condition: Bool,
        _ message: String = "Condition expected to be true",
        file: String = #file,
        line: Int = #line
    ) throws {
        if !condition {
            throw TestAssertionFailure(message: message, file: file, line: line)
        }
    }
    
    public static func isFalse(
        _ condition: Bool,
        _ message: String = "Condition expected to be false",
        file: String = #file,
        line: Int = #line
    ) throws {
        if condition {
            throw TestAssertionFailure(message: message, file: file, line: line)
        }
    }
    
    @discardableResult
    public static func notNil<T>(
        _ value: T?,
        _ message: String = "Value expected to be non-nil",
        file: String = #file,
        line: Int = #line
    ) throws -> T {
        guard let unwrapped = value else {
            throw TestAssertionFailure(message: message, file: file, line: line)
        }
        return unwrapped
    }
    
    public static func isNil<T>(
        _ value: T?,
        _ message: String = "Value expected to be nil",
        file: String = #file,
        line: Int = #line
    ) throws {
        if value != nil {
            throw TestAssertionFailure(message: "\(message): got [\(String(describing: value))]", file: file, line: line)
        }
    }
    
    public static func contains(
        _ haystack: String,
        _ needle: String,
        _ message: String = "",
        file: String = #file,
        line: Int = #line
    ) throws {
        if !haystack.contains(needle) {
            let detail = message.isEmpty ? "Expected string to contain [\(needle)], but got: [\(haystack)]" : message
            throw TestAssertionFailure(message: detail, file: file, line: line)
        }
    }
    
    public static func withinTolerance(
        _ actual: Double,
        _ expected: Double,
        tolerance: Double,
        _ message: String = "",
        file: String = #file,
        line: Int = #line
    ) throws {
        let diff = abs(actual - expected)
        if diff > tolerance {
            let detail = message.isEmpty ? "Expected \(expected) ± \(tolerance), but got \(actual) (diff: \(diff))" : message
            throw TestAssertionFailure(message: detail, file: file, line: line)
        }
    }
    
    public static func throwsError<E: Error>(
        _ expectedErrorType: E.Type,
        _ message: String = "Expected error of type \(E.self)",
        file: String = #file,
        line: Int = #line,
        operation: () async throws -> Void
    ) async throws {
        do {
            try await operation()
            throw TestAssertionFailure(message: "\(message): no error was thrown", file: file, line: line)
        } catch let err as TestAssertionFailure {
            throw err
        } catch is E {
            // Success: expected error was thrown
        } catch {
            throw TestAssertionFailure(
                message: "\(message): caught unexpected error type \(type(of: error)): \(error)",
                file: file,
                line: line
            )
        }
    }
}

// MARK: - Test Registry & Harness

public final class E2ETestCase: @unchecked Sendable {
    public let name: String
    public let tier: Int
    public let category: String
    public let description: String
    public let run: () async throws -> Void
    
    public init(
        name: String,
        tier: Int,
        category: String,
        description: String = "",
        run: @escaping () async throws -> Void
    ) {
        self.name = name
        self.tier = tier
        self.category = category
        self.description = description
        self.run = run
    }
}

public actor E2ETestRegistry {
    public static let shared = E2ETestRegistry()
    private var testCases: [E2ETestCase] = []
    
    public func register(_ testCase: E2ETestCase) {
        testCases.append(testCase)
    }
    
    public func registerBatch(_ batch: [E2ETestCase]) {
        testCases.append(contentsOf: batch)
    }
    
    public func allTests() -> [E2ETestCase] {
        return testCases
    }
    
    public func filter(tier: Int? = nil, category: String? = nil, nameFilter: String? = nil) -> [E2ETestCase] {
        return testCases.filter { test in
            if let tier = tier, test.tier != tier { return false }
            if let category = category, !test.category.localizedCaseInsensitiveContains(category) { return false }
            if let nameFilter = nameFilter, !test.name.localizedCaseInsensitiveContains(nameFilter) { return false }
            return true
        }
    }
}

// MARK: - Opaque-Box Domain Helpers & Oracles
// These interact directly with Apple system frameworks conforming to PROJECT.md contracts.

public final class E2ELanguageDetector: @unchecked Sendable {
    public static let shared = E2ELanguageDetector()
    
    public let supportedLanguages: [String] = [
        "ar", "de", "en", "es", "fr", "hi", "id", "it",
        "ja", "ko", "nl", "pl", "pt", "ru", "th", "tr",
        "uk", "vi", "zh"
    ]
    
    private let flagMapping: [String: String] = [
        "en": "🇬🇧",
        "uk": "🇺🇦",
        "ru": "🇷🇺",
        "de": "🇩🇪",
        "pl": "🇵🇱",
        "fr": "🇫🇷",
        "es": "🇪🇸",
        "it": "🇮🇹",
        "nl": "🇳🇱",
        "pt": "🇵🇹",
        "zh": "🇨🇳",
        "ja": "🇯🇵",
        "ko": "🇰🇷",
        "ar": "🇸🇦",
        "hi": "🇮🇳",
        "id": "🇮🇩",
        "th": "🇹🇭",
        "tr": "🇹🇷",
        "vi": "🇻🇳"
    ]
    
    public func detectLanguage(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = supportedLanguages.map { NLLanguage($0) }
        recognizer.processString(trimmed)
        
        guard let dominant = recognizer.dominantLanguage else { return nil }
        let code = dominant.rawValue
        let baseCode = code.components(separatedBy: "-").first ?? code
        return supportedLanguages.contains(baseCode) ? baseCode : code
    }
    
    public func localizedName(for languageCode: String, inLocale locale: Locale = Locale(identifier: "en_US")) -> String {
        if let name = locale.localizedString(forLanguageCode: languageCode) {
            return name.capitalized
        }
        return languageCode.uppercased()
    }
    
    public func flagEmoji(for languageCode: String) -> String {
        let base = languageCode.components(separatedBy: "-").first?.lowercased() ?? languageCode
        return flagMapping[base] ?? "🌐"
    }
}

public actor E2ETranslationEngine {
    public static let shared = E2ETranslationEngine()
    
    private var sessionCache: [String: Any] = [:]
    
    public func isModelInstalled(from sourceLang: String, to targetLang: String) async -> Bool {
        let availability = LanguageAvailability()
        let src = Locale.Language(identifier: sourceLang)
        let tgt = Locale.Language(identifier: targetLang)
        let status = await availability.status(from: src, to: tgt)
        return status == .installed
    }
    
    public func isSupported(from sourceLang: String, to targetLang: String) async -> Bool {
        let availability = LanguageAvailability()
        let src = Locale.Language(identifier: sourceLang)
        let tgt = Locale.Language(identifier: targetLang)
        let status = await availability.status(from: src, to: tgt)
        return status != .unsupported
    }
    
    public func translate(text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw E2ETranslationError.nothingToTranslate
        }
        
        if #available(macOS 26.0, *) {
            let pairKey = "\(sourceLang)->\(targetLang)"
            let session: TranslationSession
            if let cached = sessionCache[pairKey] as? TranslationSession {
                session = cached
            } else {
                let src = Locale.Language(identifier: sourceLang)
                let tgt = Locale.Language(identifier: targetLang)
                session = TranslationSession(installedSource: src, target: tgt)
                try await session.prepareTranslation()
                sessionCache[pairKey] = session
            }
            let response = try await session.translate(text)
            return response.targetText
        } else {
            throw E2ETranslationError.unsupportedLanguagePairing
        }
    }
}

public struct E2ELanguagePairRouter {
    public static func resolveTargetLanguage(
        for detectedLang: String?,
        primary: String,
        secondary: String,
        fallback: String
    ) -> (source: String, target: String) {
        guard let detected = detectedLang else {
            return (source: secondary, target: primary)
        }
        
        if detected == primary {
            return (source: primary, target: secondary)
        } else if detected == secondary {
            return (source: secondary, target: primary)
        } else if detected == fallback {
            return (source: detected, target: primary)
        } else {
            return (source: detected, target: fallback)
        }
    }
}

public final class E2EPreferencesManager: @unchecked Sendable {
    private let suiteName: String
    private let userDefaults: UserDefaults
    
    public init(suiteName: String = "com.mactranslate.e2e.test.\(UUID().uuidString)") {
        self.suiteName = suiteName
        self.userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
    }
    
    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
    }
    
    public var primaryLanguage: String {
        get { userDefaults.string(forKey: "primaryLanguage") ?? "uk" }
        set { userDefaults.set(newValue, forKey: "primaryLanguage") }
    }
    
    public var secondaryLanguage: String {
        get { userDefaults.string(forKey: "secondaryLanguage") ?? "en" }
        set { userDefaults.set(newValue, forKey: "secondaryLanguage") }
    }
    
    public var fallbackLanguage: String {
        get { userDefaults.string(forKey: "fallbackLanguage") ?? "en" }
        set { userDefaults.set(newValue, forKey: "fallbackLanguage") }
    }
    
    public var hotkeyMode: Int {
        get { userDefaults.integer(forKey: "hotkeyMode") }
        set { userDefaults.set(newValue, forKey: "hotkeyMode") }
    }
    
    public var hotkeyWindowMs: Double {
        get {
            let val = userDefaults.double(forKey: "hotkeyWindowMs")
            return val > 0 ? val : 400.0
        }
        set { userDefaults.set(newValue, forKey: "hotkeyWindowMs") }
    }
    
    public var dismissOnOutsideClick: Bool {
        get {
            if userDefaults.object(forKey: "dismissOnOutsideClick") == nil { return true }
            return userDefaults.bool(forKey: "dismissOnOutsideClick")
        }
        set { userDefaults.set(newValue, forKey: "dismissOnOutsideClick") }
    }
    
    public var enterKeyAction: Int {
        get { userDefaults.integer(forKey: "enterKeyAction") }
        set { userDefaults.set(newValue, forKey: "enterKeyAction") }
    }
    
    public func resetToDefaults() {
        userDefaults.removePersistentDomain(forName: suiteName)
    }
}

public struct E2EGeometryHelper {
    public static func clampWindowOrigin(
        cursor: NSPoint,
        windowSize: NSSize,
        screenVisibleFrame: NSRect
    ) -> NSPoint {
        var originX = cursor.x + 12
        var originY = cursor.y - windowSize.height - 12
        
        let minX = screenVisibleFrame.minX + 8
        let maxX = screenVisibleFrame.maxX - windowSize.width - 8
        let minY = screenVisibleFrame.minY + 8
        let maxY = screenVisibleFrame.maxY - windowSize.height - 8
        
        if originX > maxX {
            originX = maxX
        }
        if originX < minX {
            originX = minX
        }
        
        if originY < minY {
            // Flip above cursor if constrained
            originY = cursor.y + 12
        }
        if originY > maxY {
            originY = maxY
        }
        
        return NSPoint(x: originX, y: originY)
    }
}

public final class E2EHotkeySimulator {
    public var lastPressTime: TimeInterval = 0
    public let thresholdMs: Double
    public private(set) var triggerCount: Int = 0
    
    public init(thresholdMs: Double = 400.0) {
        self.thresholdMs = thresholdMs
    }
    
    public func simulateKeyPress(atTimestamp timeMs: Double) -> Bool {
        let timeSec = timeMs / 1000.0
        let deltaSec = timeSec - lastPressTime
        let thresholdSec = thresholdMs / 1000.0
        
        if deltaSec <= thresholdSec && deltaSec > 0.05 {
            // Triggered
            triggerCount += 1
            lastPressTime = 0 // Reset
            return true
        } else {
            lastPressTime = timeSec
            return false
        }
    }
}

// MARK: - Test Suite Execution Engine

@main
public struct E2ETestHarnessMain {
    public static func main() async {
        let args = CommandLine.arguments
        var targetTier: Int? = nil
        var nameFilter: String? = nil
        var verbose: Bool = false
        var jsonOutput: Bool = false
        
        var i = 1
        while i < args.count {
            let arg = args[i]
            if arg == "--tier" && i + 1 < args.count {
                targetTier = Int(args[i + 1])
                i += 1
            } else if arg == "--filter" && i + 1 < args.count {
                nameFilter = args[i + 1]
                i += 1
            } else if arg == "--verbose" || arg == "-v" {
                verbose = true
            } else if arg == "--json" {
                jsonOutput = true
            } else if arg == "--help" || arg == "-h" {
                printUsage()
                return
            }
            i += 1
        }
        
        // Register all test suites
        await registerAllSuites()
        
        let testsToRun = await E2ETestRegistry.shared.filter(
            tier: targetTier,
            nameFilter: nameFilter
        )
        
        if !jsonOutput {
            print("\u{001B}[1;36m=================================================================\u{001B}[0m")
            print("\u{001B}[1;36m    MacTranslate E2E Opaque-Box Test Suite Runner (macOS 15+)   \u{001B}[0m")
            print("\u{001B}[1;36m=================================================================\u{001B}[0m")
            print("Total tests registered: \(await E2ETestRegistry.shared.allTests().count)")
            print("Tests selected to run : \(testsToRun.count)")
            if let t = targetTier { print("Filtered by Tier      : Tier \(t)") }
            if let f = nameFilter { print("Filtered by Name      : '\(f)'") }
            print("-----------------------------------------------------------------")
        }
        
        var results: [TestCaseResult] = []
        let suiteStartTime = Date()
        
        for test in testsToRun {
            let testStart = Date()
            var status: TestStatus = .passed
            var details: String? = nil
            
            do {
                try await test.run()
                status = .passed
            } catch let failure as TestAssertionFailure {
                status = .failed(failure.description)
                details = failure.description
            } catch {
                status = .failed("Unexpected error: \(error)")
                details = "\(error)"
            }
            
            let duration = Date().timeIntervalSince(testStart)
            let result = TestCaseResult(
                name: test.name,
                tier: test.tier,
                category: test.category,
                status: status,
                duration: duration,
                details: details
            )
            results.append(result)
            
            if !jsonOutput {
                let statusBadge: String
                switch status {
                case .passed:
                    statusBadge = "\u{001B}[32m[PASS]\u{001B}[0m"
                case .failed:
                    statusBadge = "\u{001B}[31m[FAIL]\u{001B}[0m"
                case .skipped:
                    statusBadge = "\u{001B}[33m[SKIP]\u{001B}[0m"
                }
                
                let durationMs = String(format: "%6.1f ms", duration * 1000.0)
                let tierTag = "T\(test.tier)"
                print("\(statusBadge) (\(tierTag)) \(durationMs) - [\(test.category)] \(test.name)")
                
                if case .failed(let err) = status {
                    print("       \u{001B}[31m↳ Error: \(err)\u{001B}[0m")
                } else if verbose && test.description.count > 0 {
                    print("       \u{001B}[90m↳ \(test.description)\u{001B}[0m")
                }
            }
        }
        
        let totalElapsed = Date().timeIntervalSince(suiteStartTime)
        let passCount = results.filter { $0.isSuccess }.count
        let failCount = results.filter { !$0.isSuccess }.count
        
        if jsonOutput {
            printJSONSummary(results: results, totalElapsed: totalElapsed)
        } else {
            print("-----------------------------------------------------------------")
            print("\u{001B}[1mExecution Summary:\u{001B}[0m")
            print("  Total Tests : \(results.count)")
            print("  Passed      : \u{001B}[32m\(passCount)\u{001B}[0m")
            print("  Failed      : \u{001B}[\(failCount > 0 ? "31" : "32")m\(failCount)\u{001B}[0m")
            print("  Elapsed     : \(String(format: "%.3f s", totalElapsed))")
            print("\u{001B}[1;36m=================================================================\u{001B}[0m")
        }
        
        if failCount > 0 {
            exit(1)
        } else {
            exit(0)
        }
    }
    
    private static func printUsage() {
        print("""
        Usage: run_e2e_tests [options]
        
        Options:
          --tier <1-4>      Run only tests in the specified Tier
          --filter <str>    Filter test cases by name substring
          --verbose, -v     Print detailed test descriptions
          --json            Format output as JSON
          --help, -h        Show this help message
        """)
    }
    
    private static func printJSONSummary(results: [TestCaseResult], totalElapsed: TimeInterval) {
        let passCount = results.filter { $0.isSuccess }.count
        let failCount = results.filter { !$0.isSuccess }.count
        print("{")
        print("  \"total\": \(results.count),")
        print("  \"passed\": \(passCount),")
        print("  \"failed\": \(failCount),")
        print("  \"elapsedSeconds\": \(totalElapsed),")
        print("  \"results\": [")
        for (idx, r) in results.enumerated() {
            let comma = idx < results.count - 1 ? "," : ""
            let statusStr = r.isSuccess ? "PASS" : "FAIL"
            let escapedDetails = r.details?.replacingOccurrences(of: "\"", with: "\\\"") ?? ""
            print("    {\"name\": \"\(r.name)\", \"tier\": \(r.tier), \"category\": \"\(r.category)\", \"status\": \"\(statusStr)\", \"durationMs\": \(r.duration * 1000.0), \"details\": \"\(escapedDetails)\"}\(comma)")
        }
        print("  ]")
        print("}")
    }
    
    private static func registerAllSuites() async {
        await registerTier1FeatureTests()
        await registerTier2BoundaryTests()
        await registerTier3CombinationTests()
        await registerTier4ScenarioTests()
    }
}
