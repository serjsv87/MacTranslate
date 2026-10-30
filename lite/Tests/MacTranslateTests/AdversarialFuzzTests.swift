import Testing
import Foundation
import Translation
@testable import MacTranslate

@Suite("Milestone 1 Adversarial Fuzz Tests", .serialized)
struct AdversarialFuzzTests {
    let detector = LanguageDetector.shared
    let engine = TranslationEngine.shared

    // MARK: - 1. Extreme Inputs
    
    @Test("Extreme Input: 10,000 character English string language detection")
    func testExtreme10kEnglishDetection() {
        let sample = "The quick brown fox jumps over the lazy dog. Swift is a powerful and intuitive language. "
        let repeatCount = (10_000 / sample.count) + 1
        let text10k = String(repeating: sample, count: repeatCount).prefix(10_000).description
        #expect(text10k.count == 10_000)
        
        let start = DispatchTime.now()
        let detected = detector.detectLanguage(in: text10k)
        let end = DispatchTime.now()
        let ms = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
        
        print("[FUZZ] 10,000 chars English detection: \(detected ?? "nil") in \(ms) ms")
        #expect(detected == "en")
        #expect(ms < 500.0) // Must not stall
    }

    @Test("Extreme Input: 10,000 character Ukrainian string language detection")
    func testExtreme10kUkrainianDetection() {
        let sample = "Швидка брунатна лисиця стрибає через ледачого пса. Українська мова солов'їна та прекрасна. "
        let repeatCount = (10_000 / sample.count) + 1
        let text10k = String(repeating: sample, count: repeatCount).prefix(10_000).description
        #expect(text10k.count == 10_000)
        
        let start = DispatchTime.now()
        let detected = detector.detectLanguage(in: text10k)
        let end = DispatchTime.now()
        let ms = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
        
        print("[FUZZ] 10,000 chars Ukrainian detection: \(detected ?? "nil") in \(ms) ms")
        #expect(detected == "uk")
        #expect(ms < 500.0)
    }

    @Test("Extreme Input: 10,000 character random noise without letters")
    func testExtreme10kNoiseDetection() {
        let noise = String(repeating: "!@#$%^&*()_+-=[]{}|;':\",./<>?~` 0123456789 \n\t", count: 250)
        let start = DispatchTime.now()
        let detected = detector.detectLanguage(in: noise)
        let end = DispatchTime.now()
        let ms = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
        
        print("[FUZZ] 10,000 chars noise detection: \(detected ?? "nil") in \(ms) ms")
        #expect(detected == nil)
        #expect(ms < 50.0)
    }

    @Test("Extreme Input: Unicode null bytes in language detection, routing, and translation")
    func testUnicodeNullBytes() async throws {
        #expect(detector.detectLanguage(in: "\0") == nil)
        #expect(detector.detectLanguage(in: "\0\0\0\0\0") == nil)
        #expect(detector.detectLanguage(in: "Hello\0World! How are you today?") == "en")
        #expect(detector.detectLanguage(in: "Привіт\0Світ! Як твої справи?") == "uk")
        
        // Null bytes in language codes for router
        let route = LanguagePairRouter.resolveTargetLanguage(for: "en\0", primary: "uk\0", secondary: "en\0", fallback: "en\0")
        #expect(route.source == "en\0")
        
        // Live translation with null byte
        let nullTranslated = try await engine.translate(text: "Hello\0world", from: "en", to: "uk")
        print("[FUZZ] Live translation with null byte result: '\(nullTranslated)'")
        #expect(!nullTranslated.isEmpty)
    }

    @Test("Extreme Input: Emoji-only strings in detection and translation")
    func testEmojiOnlyInputs() async {
        let emojis = "😀😃😄😁😆😅😂🤣😭😱🔥✨🎉🚀👍🏽👨‍👩‍👧‍👦🇺🇦🇬🇧"
        #expect(detector.detectLanguage(in: emojis) == nil)
        
        // Mixed text with heavy emojis
        let mixed = "🇺🇦 Привіт друзі! 🎉🚀 Як справи? 😀"
        #expect(detector.detectLanguage(in: mixed) == "uk")
        
        let mixedEn = "🚀 Hello team! 🎉 Good morning! ☀️"
        #expect(detector.detectLanguage(in: mixedEn) == "en")
        
        // Translation of emoji-only string
        do {
            let res = try await engine.translate(text: emojis, from: "en", to: "uk")
            print("[FUZZ] Emoji-only translation result: '\(res)'")
        } catch {
            print("[FUZZ] Emoji-only translation threw: \(error)")
        }
    }

    @Test("Extreme Input: RTL text (Arabic and Hebrew)")
    func testRTLText() async throws {
        // Arabic is in supportedLanguages ("ar")
        let arabic = "مرحبا بالعالم، كيف حالك اليوم؟ أتمنى لك يوما جميلا وموفقا"
        let detectedArabic = detector.detectLanguage(in: arabic)
        print("[FUZZ] Arabic detection: \(detectedArabic ?? "nil")")
        #expect(detectedArabic == "ar")
        
        // Hebrew is NOT in supportedLanguages
        let hebrew = "שלום עולם מה שלומך היום? אני מקווה שיהיה לך יום נפלא"
        let detectedHebrew = detector.detectLanguage(in: hebrew)
        print("[FUZZ] Hebrew detection (not in supportedLanguages): \(detectedHebrew ?? "nil")")
        #expect(detectedHebrew == nil)
        
        // Live translation of Arabic to English
        let arabicStatus = engine.isModelInstalled(from: "ar", to: "en")
        print("[FUZZ] ar->en model installed: \(arabicStatus)")
        if arabicStatus {
            let translated = try await engine.translate(text: "مرحبا بالعالم", from: "ar", to: "en")
            print("[FUZZ] Arabic translated to English: '\(translated)'")
            #expect(!translated.isEmpty)
        }
    }

    @Test("Extreme Input: Markdown with code blocks")
    func testMarkdownWithCodeBlocks() async throws {
        let markdown = """
        # Architecture Overview
        Here is a brief description of the translation pipeline and its core features.
        
        ```swift
        func executeTranslation(input: String) async throws -> String {
            let session = try await acquireSession()
            return try await session.translate(input)
        }
        ```
        
        The code above demonstrates asynchronous session acquisition and task execution.
        """
        
        let detected = detector.detectLanguage(in: markdown)
        print("[FUZZ] Markdown detection: \(detected ?? "nil")")
        #expect(detected == "en")
        
        let start = DispatchTime.now()
        let translated = try await engine.translate(text: markdown, from: "en", to: "uk")
        let ms = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
        print("[FUZZ] Markdown translation took \(ms) ms, length: \(translated.count)")
        #expect(!translated.isEmpty)
    }

    @Test("Extreme Input: TranslationEngine length scaling (100, 500, 1000, 2000 chars)")
    func testTranslationEngineLengthScaling() async throws {
        let sample = "The quick brown fox jumps over the lazy dog. Swift is very fast. "
        let sizes = [100, 500, 1000, 2000]
        
        for size in sizes {
            let count = (size / sample.count) + 1
            let text = String(repeating: sample, count: count).prefix(size).description
            
            // Identity translation
            let idStart = DispatchTime.now()
            let idRes = try await engine.translate(text: text, from: "en", to: "en")
            let idMs = Double(DispatchTime.now().uptimeNanoseconds - idStart.uptimeNanoseconds) / 1_000_000.0
            #expect(idRes == text)
            print("[FUZZ] Identity \(size) chars translation: \(idMs) ms")
            
            // Live translation
            let liveStart = DispatchTime.now()
            do {
                let liveRes = try await engine.translate(text: text, from: "en", to: "uk")
                let liveMs = Double(DispatchTime.now().uptimeNanoseconds - liveStart.uptimeNanoseconds) / 1_000_000.0
                print("[FUZZ] Live \(size) chars translation: \(liveMs) ms, output length: \(liveRes.count)")
                #expect(!liveRes.isEmpty)
            } catch {
                let liveMs = Double(DispatchTime.now().uptimeNanoseconds - liveStart.uptimeNanoseconds) / 1_000_000.0
                print("[FUZZ] Live \(size) chars translation failed after \(liveMs) ms: \(error)")
            }
        }
    }

    // MARK: - 2. Fault Injection

    @Test("Fault Injection: Diagnostic inspection of TranslationError on invalid pair")
    func testFaultInjectionDiagnosticError() async {
        let avail = LanguageAvailability()
        let statusXxYy = await avail.status(from: Locale.Language(identifier: "xx"), to: Locale.Language(identifier: "yy"))
        print("[FUZZ] LanguageAvailability status for xx->yy: \(statusXxYy)")
        #expect(statusXxYy == .unsupported)
        
        let installed = engine.isModelInstalled(from: "xx", to: "yy")
        #expect(installed == false)
        
        // Directly inspect what TranslationSession throws
        if #available(macOS 26.0, *) {
            let src = Locale.Language(identifier: "xx")
            let tgt = Locale.Language(identifier: "yy")
            let rawSession = TranslationSession(installedSource: src, target: tgt)
            
            do {
                try await rawSession.prepareTranslation()
                Issue.record("Expected rawSession.prepareTranslation() to throw for xx->yy")
            } catch let err as TranslationError {
                let nsErr = err as NSError
                print("[FUZZ] rawSession threw TranslationError:")
                print("       description: \(err)")
                print("       localizedDescription: \(err.localizedDescription)")
                print("       domain: \(nsErr.domain)")
                print("       code: \(nsErr.code)")
                print("       userInfo: \(nsErr.userInfo)")
            } catch {
                print("[FUZZ] rawSession threw non-TranslationError: \(error)")
            }
        }
        
        // Inspect what TranslationEngine translates
        do {
            _ = try await engine.translate(text: "Hello", from: "xx", to: "yy")
            Issue.record("Expected engine.translate to throw")
        } catch {
            print("[FUZZ] engine.translate(xx->yy) threw: \(error)")
        }
    }

    @Test("Fault Injection: Uninstalled supported language pair behavior (ja->ko)")
    func testUninstalledLanguagePairStatus() async {
        let avail = LanguageAvailability()
        let s = Locale.Language(identifier: "ja")
        let t = Locale.Language(identifier: "ko")
        let statusJaKo = await avail.status(from: s, to: t)
        print("[FUZZ] LanguageAvailability status for ja->ko: \(statusJaKo)")
        
        let installedSync = engine.isModelInstalled(from: "ja", to: "ko")
        let installedAsync = await engine.checkModelInstalled(from: "ja", to: "ko")
        
        // TranslationEngine must dynamically match actual system status
        #expect(installedSync == (statusJaKo == .installed))
        #expect(installedAsync == (statusJaKo == .installed))
        
        if statusJaKo == .supported {
            do {
                _ = try await engine.translate(text: "こんにちは", from: "ja", to: "ko")
                Issue.record("Expected translate(ja->ko) to throw notInstalled error")
            } catch let error as TranslationEngineError {
                switch error {
                case .notInstalled(let src, let tgt):
                    #expect(src == "ja")
                    #expect(tgt == "ko")
                default:
                    Issue.record("Expected TranslationEngineError.notInstalled, got: \(error)")
                }
            } catch {
                Issue.record("Expected TranslationEngineError, got: \(error)")
            }
        } else if statusJaKo == .installed {
            do {
                let res = try await engine.translate(text: "こんにちは", from: "ja", to: "ko")
                #expect(!res.isEmpty)
                print("[FUZZ] ja->ko live translation output: '\(res)'")
            } catch {
                Issue.record("Translation for installed model ja->ko failed: \(error)")
            }
        }
    }

    @Test("Fault Injection: Invalid BCP-47 codes")
    func testFaultInjectionInvalidBCP47() {
        let invalidCodes = [
            "",
            "   ",
            "x",
            "invalid_code",
            "12345",
            "!@#$%",
            "nonexistent-bcp-47-tag-too-long",
            "../etc/passwd",
            "\0\0"
        ]
        
        for code in invalidCodes {
            let name = detector.localizedName(for: code)
            let flag = detector.flagEmoji(for: code)
            #expect(!name.isEmpty || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(flag == "🌐" || flag.unicodeScalars.count >= 1)
        }
    }

    @Test("Fault Injection: Corrupted UserDefaults keys and empty string vulnerability")
    func testFaultInjectionCorruptedUserDefaults() {
        let suiteName = "com.mactranslate.fuzz.corrupted.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        
        // Inject corrupt data types into UserDefaults keys
        defaults.set(12345, forKey: PreferencesManager.Keys.primaryLanguage)
        defaults.set(Data([0x00, 0xFF, 0xFE]), forKey: PreferencesManager.Keys.secondaryLanguage)
        defaults.set(true, forKey: PreferencesManager.Keys.fallbackLanguage)
        defaults.set(999, forKey: PreferencesManager.Keys.hotkeyMode)
        defaults.set(-500.0, forKey: PreferencesManager.Keys.hotkeyWindowMs)
        defaults.set(-42, forKey: PreferencesManager.Keys.enterKeyAction)
        defaults.set("notABool", forKey: PreferencesManager.Keys.dismissOnOutsideClick)
        
        let prefs = PreferencesManager(userDefaults: defaults)
        
        // Verify self-healing fallback to safe defaults where types are handled
        #expect(prefs.primaryLanguage == "uk") // Int 12345 rejected -> "uk"
        #expect(prefs.secondaryLanguage == "en") // Data rejected -> "en"
        #expect(prefs.fallbackLanguage == "en") // Bool true rejected -> "en"
        #expect(prefs.hotkeyMode == .doubleCommandC)
        #expect(prefs.enterKeyAction == .copyAndClose)
        #expect(prefs.hotkeyWindowMs == 400.0)
        #expect(prefs.dismissOnOutsideClick == true) // "notABool" rejected -> true
        
        // Empty string and whitespace sanitization
        defaults.set("", forKey: PreferencesManager.Keys.primaryLanguage)
        #expect(prefs.primaryLanguage == "uk")
        
        defaults.set("   \n\t ", forKey: PreferencesManager.Keys.secondaryLanguage)
        #expect(prefs.secondaryLanguage == "en")
        
        defaults.set("", forKey: PreferencesManager.Keys.fallbackLanguage)
        #expect(prefs.fallbackLanguage == "en")
        
        // Routing remains stable and never resolves to empty language codes
        let routed = LanguagePairRouter.resolveTargetLanguage(for: "en", primary: prefs.primaryLanguage, secondary: "en", fallback: "uk")
        #expect(routed.source == "en")
        #expect(routed.target == "uk")
    }

    // MARK: - 3. Router Permutation Testing

    @Test("Router Permutations: primary == secondary")
    func testRouterPrimaryEqualsSecondary() {
        // When primary == secondary ("en" == "en"), routing detected "en"
        let routeEn = LanguagePairRouter.resolveTargetLanguage(for: "en", primary: "en", secondary: "en", fallback: "uk")
        print("[FUZZ] Router primary==secondary ('en' detected): source=\(routeEn.source), target=\(routeEn.target)")
        // Since detected == primary ("en" == "en"), target is secondary ("en")
        #expect(routeEn.source == "en")
        #expect(routeEn.target == "en")
        
        // When third language is detected ("de")
        let routeDe = LanguagePairRouter.resolveTargetLanguage(for: "de", primary: "en", secondary: "en", fallback: "uk")
        print("[FUZZ] Router primary==secondary ('de' detected): source=\(routeDe.source), target=\(routeDe.target)")
        #expect(routeDe.source == "de")
        #expect(routeDe.target == "uk")
    }

    @Test("Router Permutations: secondary == fallback")
    func testRouterSecondaryEqualsFallback() {
        // primary: "uk", secondary: "en", fallback: "en"
        let p = "uk", s = "en", f = "en"
        
        // Detected primary -> secondary
        let r1 = LanguagePairRouter.resolveTargetLanguage(for: "uk", primary: p, secondary: s, fallback: f)
        #expect(r1.source == "uk" && r1.target == "en")
        
        // Detected secondary -> primary
        let r2 = LanguagePairRouter.resolveTargetLanguage(for: "en", primary: p, secondary: s, fallback: f)
        #expect(r2.source == "en" && r2.target == "uk")
        
        // Detected third language ("fr") -> fallback ("en")
        let r3 = LanguagePairRouter.resolveTargetLanguage(for: "fr", primary: p, secondary: s, fallback: f)
        #expect(r3.source == "fr" && r3.target == "en")
    }

    @Test("Router Permutations: primary == fallback")
    func testRouterPrimaryEqualsFallback() {
        // primary: "uk", secondary: "en", fallback: "uk"
        let p = "uk", s = "en", f = "uk"
        
        // Detected primary -> secondary
        let r1 = LanguagePairRouter.resolveTargetLanguage(for: "uk", primary: p, secondary: s, fallback: f)
        #expect(r1.source == "uk" && r1.target == "en")
        
        // Detected secondary -> primary
        let r2 = LanguagePairRouter.resolveTargetLanguage(for: "en", primary: p, secondary: s, fallback: f)
        #expect(r2.source == "en" && r2.target == "uk")
        
        // Detected third language ("es") -> fallback ("uk")
        let r3 = LanguagePairRouter.resolveTargetLanguage(for: "es", primary: p, secondary: s, fallback: f)
        #expect(r3.source == "es" && r3.target == "uk")
    }

    @Test("Router Permutations: primary == secondary == fallback")
    func testRouterAllEqual() {
        // primary: "en", secondary: "en", fallback: "en"
        let p = "en", s = "en", f = "en"
        
        let rEn = LanguagePairRouter.resolveTargetLanguage(for: "en", primary: p, secondary: s, fallback: f)
        #expect(rEn.source == "en" && rEn.target == "en")
        
        let rFr = LanguagePairRouter.resolveTargetLanguage(for: "fr", primary: p, secondary: s, fallback: f)
        #expect(rFr.source == "fr" && rFr.target == "en")
        
        let rNil = LanguagePairRouter.resolveTargetLanguage(for: nil, primary: p, secondary: s, fallback: f)
        #expect(rNil.source == "en" && rNil.target == "en")
    }

    @Test("Router Permutations: nil and whitespace detection")
    func testRouterNilAndWhitespacePermutations() {
        let p = "uk", s = "en", f = "de"
        
        let nilRoute = LanguagePairRouter.resolveTargetLanguage(for: nil, primary: p, secondary: s, fallback: f)
        #expect(nilRoute.source == "en" && nilRoute.target == "uk")
        
        let emptyRoute = LanguagePairRouter.resolveTargetLanguage(for: "", primary: p, secondary: s, fallback: f)
        #expect(emptyRoute.source == "en" && emptyRoute.target == "uk")
        
        let whitespaceRoute = LanguagePairRouter.resolveTargetLanguage(for: "  \n\t  ", primary: p, secondary: s, fallback: f)
        #expect(whitespaceRoute.source == "en" && whitespaceRoute.target == "uk")
    }

    @Test("Router Permutations: Case insensitivity and whitespace trimming")
    func testRouterCaseAndWhitespace() {
        let r1 = LanguagePairRouter.resolveTargetLanguage(for: "  UK  ", primary: "uk", secondary: "en", fallback: "de")
        #expect(r1.source == "uk" && r1.target == "en")
        
        let r2 = LanguagePairRouter.resolveTargetLanguage(for: "  EN  ", primary: "uk", secondary: "en", fallback: "de")
        #expect(r2.source == "en" && r2.target == "uk")
        
        let r3 = LanguagePairRouter.resolveTargetLanguage(for: "  FR  ", primary: "uk", secondary: "en", fallback: "de")
        #expect(r3.source == "fr" && r3.target == "de")
    }
}
