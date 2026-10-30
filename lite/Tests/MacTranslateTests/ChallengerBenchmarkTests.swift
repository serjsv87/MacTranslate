import Testing
import Foundation
@testable import MacTranslate

@Suite("Challenger Benchmark Tests", .serialized)
struct ChallengerBenchmarkTests {
    let detector = LanguageDetector.shared

    // MARK: - 1. Chinese vs Japanese Disambiguation Benchmark
    
    // Benchmark dataset of Simplified Chinese sentences
    static let simplifiedChineseCorpus: [String] = [
        "今天天气非常晴朗，我们计划去公园散步。",
        "请问最近的地铁站在哪里？我需要去市中心。",
        "人工智能和机器学习正在深刻改变各行各业的生产力模式。",
        "本项目基于苹果公司的翻译框架和自然语言处理框架构建。",
        "敏捷的棕色狐狸跳过懒惰的狗。",
        "请在会议开始前确认所有参会人员都已经收到最新版本的议程安排。",
        "在计算机科学中，算法是解决特定问题的一系列明确指令。",
        "虽然面临诸多挑战，但团队依然按时高质量完成了第一阶段的交付。",
        "床前明月光，疑是地上霜。举头望明月，低头思故乡。",
        "千里之行，始于足下。",
        "中华人民共和国位于亚洲东部，太平洋西岸。",
        "系统偏好设置中可以配置快捷键和语言对。",
        "苹果发布了全新的操作系统更新，修复了若干安全漏洞并提升了性能。",
        "这个功能非常实用，大大提升了日常办公和文档翻译的效率。",
        "数据库事务必须满足原子性、一致性、隔离性和持久性。",
        "网络连接超时，请检查您的路由器设置或稍后重试。",
        "昨天下了一整夜的大雨，今天早晨空气格外清新。",
        "这是一段简体中文测试文本，用于验证语言检测准确率。",
        "为了保证代码质量，我们需要进行详尽的单元测试和模糊测试。",
        "健康的生活方式包括均衡的饮食、充足的睡眠和适度的体育锻炼。"
    ]

    // Benchmark dataset of Traditional Chinese sentences
    static let traditionalChineseCorpus: [String] = [
        "這是一個繁體中文的測試句子，請確認檢測結果正確。",
        "會議即將開始，請所有與會人員盡快就座。",
        "機器學習模型需要強大的評估指標與驗證架構。",
        "香港與台灣的繁體中文使用者習慣使用傳統漢字。",
        "請在提交程式碼前執行完整的單元測試與端對端測試。",
        "自然語言處理技術使得跨語言溝通變得更加便捷與高效。",
        "系統偏好設定允許使用者自訂全域快捷鍵與預設翻譯目標。",
        "今天的天氣非常舒適，微風徐徐，適合外出郊遊拍照。",
        "軟體架構設計必須兼顧效能、擴充性與長期維護成本。",
        "這份合約的所有條款均已由雙方法律顧問仔細審閱與確認。",
        "光陰似箭，日月如梭，轉眼間一年又即將過去。",
        "雲端運算與邊緣計算的結合為現代分散式系統提供了新的可能性。",
        "請勿在此處吸煙或大聲喧嘩，以維護良好的公共空間品質。",
        "這家餐廳的招牌點心遠近馳名，吸引了無數老饕前來品嚐。",
        "中華文化源遠流長，傳統書法與水墨藝術具有獨特的審美價值。",
        "這項新技術將大幅縮短數據處理時間並降低伺服器負載。",
        "無論遇到多大的困難，我們都必須保持冷靜並尋找最佳解決方案。",
        "請確認您的電子郵件地址與聯絡電話是否填寫無誤。",
        "這款應用程式支援多種語言的即時雙向翻譯功能。",
        "綠色能源的發展對於減緩全球氣候變遷具有舉足輕重的影響。"
    ]

    // Benchmark dataset of Japanese sentences (Kanji + Kana)
    static let japaneseCorpus: [String] = [
        "素早い茶色のキツネが怠惰な犬を飛び越えます。",
        "こんにちは、お元気ですか？今日のランチはまだ予定通りですか？",
        "会議の前に添付書類を確認していただけますでしょうか？",
        "AppleのTranslationフレームワークを利用してローカル翻訳を実行します。",
        "日本語の文章には漢字とひらがな、カタカナが混ざっています。",
        "明日の朝９時に駅の改札口で待ち合わせをしましょう。",
        "このアプリケーションは使いやすく、翻訳速度も非常に高速です。",
        "東京の桜は満開の時期を迎え、多くの花見客で賑わっています。",
        "新しい機能のリリースに伴い、ドキュメントの更新が必要です。",
        "システム設定からショートカットキーを自由に変更できます。",
        "美味しいラーメンを食べに、話題の新しいお店に行きました。",
        "プログラミング言語の進化により、開発効率が飛躍的に向上しました。",
        "昨夜の地震は震度３でしたが、特に被害はありませんでした。",
        "最新の人工知能技術がビジネスの様々な場面で活用されています。",
        "週末は家族と一緒に温泉旅行に行く予定を立てています。",
        "ファイルのアップロード中にエラーが発生しました。再試行してください。",
        "四季折々の自然の美しさを感じることができる素晴らしい庭園です。",
        "この辞書には専門用語から日常会話まで幅広く収録されています。",
        "電車が遅延しているため、到着が少し遅れる見込みです。",
        "お忙しいところ恐縮ですが、ご返信のほどよろしくお願い申し上げます。"
    ]

    @Test("Empirical Benchmark: Simplified Chinese (zh-Hans) classification and zero ja misclassification")
    func testSimplifiedChineseBenchmark() {
        var jaCount = 0
        var zhCount = 0
        var otherCount = 0
        
        for sentence in Self.simplifiedChineseCorpus {
            let detected = detector.detectLanguage(in: sentence)
            if detected == "ja" {
                jaCount += 1
            } else if detected == "zh" {
                zhCount += 1
            } else {
                otherCount += 1
            }
        }
        
        print("[BENCHMARK] Simplified Chinese total: \(Self.simplifiedChineseCorpus.count), detected as 'zh': \(zhCount), misclassified as 'ja': \(jaCount), other: \(otherCount)")
        // Criterion 1: Ensure 0% Chinese misclassification as Japanese ("ja")
        #expect(jaCount == 0, "Simplified Chinese was misclassified as Japanese ('ja')!")
        // Ensure accurate detection
        #expect(zhCount == Self.simplifiedChineseCorpus.count, "Some Simplified Chinese sentences failed to detect as 'zh'")
    }

    @Test("Empirical Benchmark: Traditional Chinese (zh-Hant) classification and zero ja misclassification")
    func testTraditionalChineseBenchmark() {
        var jaCount = 0
        var zhCount = 0
        var otherCount = 0
        
        for sentence in Self.traditionalChineseCorpus {
            let detected = detector.detectLanguage(in: sentence)
            if detected == "ja" {
                jaCount += 1
            } else if detected == "zh" {
                zhCount += 1
            } else {
                otherCount += 1
            }
        }
        
        print("[BENCHMARK] Traditional Chinese total: \(Self.traditionalChineseCorpus.count), detected as 'zh': \(zhCount), misclassified as 'ja': \(jaCount), other: \(otherCount)")
        // Criterion 1: Ensure 0% Chinese misclassification as Japanese ("ja")
        #expect(jaCount == 0, "Traditional Chinese was misclassified as Japanese ('ja')!")
        // Ensure accurate detection
        #expect(zhCount == Self.traditionalChineseCorpus.count, "Some Traditional Chinese sentences failed to detect as 'zh'")
    }

    @Test("Empirical Benchmark: Japanese (Kanji + Kana) sentences correctly detect as ja")
    func testJapaneseBenchmark() {
        var jaCount = 0
        var zhCount = 0
        var otherCount = 0
        
        for sentence in Self.japaneseCorpus {
            let detected = detector.detectLanguage(in: sentence)
            if detected == "ja" {
                jaCount += 1
            } else if detected == "zh" {
                zhCount += 1
            } else {
                otherCount += 1
            }
        }
        
        print("[BENCHMARK] Japanese total: \(Self.japaneseCorpus.count), detected as 'ja': \(jaCount), misclassified as 'zh': \(zhCount), other: \(otherCount)")
        // Criterion 1: Ensure Japanese sentences correctly detect as "ja"
        #expect(jaCount == Self.japaneseCorpus.count, "Some Japanese sentences failed to detect as 'ja'")
        #expect(zhCount == 0, "Japanese was misclassified as Chinese ('zh')!")
    }

    // MARK: - 2. PreferencesManager Robustness & Type Fuzzing
    
    @Test("Fuzz UserDefaults keys with corrupted types (Int, Data, [String], Dictionary, Double, Bool)")
    func testPreferencesManagerTypeFuzzing() {
        let suiteName = "com.mactranslate.challenger.typefuzz.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to initialize UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let prefs = PreferencesManager(userDefaults: defaults)

        // Case A: Int injection
        defaults.set(42, forKey: PreferencesManager.Keys.primaryLanguage)
        defaults.set(-999, forKey: PreferencesManager.Keys.secondaryLanguage)
        defaults.set(0, forKey: PreferencesManager.Keys.fallbackLanguage)
        #expect(prefs.primaryLanguage == "uk")
        #expect(prefs.secondaryLanguage == "en")
        #expect(prefs.fallbackLanguage == "en")

        // Case B: Data injection
        defaults.set(Data([0xDE, 0xAD, 0xBE, 0xEF]), forKey: PreferencesManager.Keys.primaryLanguage)
        defaults.set(Data(), forKey: PreferencesManager.Keys.secondaryLanguage)
        defaults.set(Data([0x00]), forKey: PreferencesManager.Keys.fallbackLanguage)
        #expect(prefs.primaryLanguage == "uk")
        #expect(prefs.secondaryLanguage == "en")
        #expect(prefs.fallbackLanguage == "en")

        // Case C: [String] array injection
        defaults.set(["en", "es", "fr"], forKey: PreferencesManager.Keys.primaryLanguage)
        defaults.set([] as [String], forKey: PreferencesManager.Keys.secondaryLanguage)
        defaults.set(["zh"] as [String], forKey: PreferencesManager.Keys.fallbackLanguage)
        #expect(prefs.primaryLanguage == "uk")
        #expect(prefs.secondaryLanguage == "en")
        #expect(prefs.fallbackLanguage == "en")

        // Case D: [String: Any] dictionary injection
        defaults.set(["key": "value", "code": "ja"], forKey: PreferencesManager.Keys.primaryLanguage)
        defaults.set(["secondary": 123], forKey: PreferencesManager.Keys.secondaryLanguage)
        defaults.set([:] as [String: String], forKey: PreferencesManager.Keys.fallbackLanguage)
        #expect(prefs.primaryLanguage == "uk")
        #expect(prefs.secondaryLanguage == "en")
        #expect(prefs.fallbackLanguage == "en")

        // Case E: Double / Float injection
        defaults.set(3.1415926535, forKey: PreferencesManager.Keys.primaryLanguage)
        defaults.set(-0.0001, forKey: PreferencesManager.Keys.secondaryLanguage)
        defaults.set(Double.nan, forKey: PreferencesManager.Keys.fallbackLanguage)
        #expect(prefs.primaryLanguage == "uk")
        #expect(prefs.secondaryLanguage == "en")
        #expect(prefs.fallbackLanguage == "en")

        // Case F: Bool injection
        defaults.set(true, forKey: PreferencesManager.Keys.primaryLanguage)
        defaults.set(false, forKey: PreferencesManager.Keys.secondaryLanguage)
        defaults.set(true, forKey: PreferencesManager.Keys.fallbackLanguage)
        #expect(prefs.primaryLanguage == "uk")
        #expect(prefs.secondaryLanguage == "en")
        #expect(prefs.fallbackLanguage == "en")

        // Case G: Date injection
        defaults.set(Date(), forKey: PreferencesManager.Keys.primaryLanguage)
        defaults.set(Date.distantPast, forKey: PreferencesManager.Keys.secondaryLanguage)
        defaults.set(Date.distantFuture, forKey: PreferencesManager.Keys.fallbackLanguage)
        #expect(prefs.primaryLanguage == "uk")
        #expect(prefs.secondaryLanguage == "en")
        #expect(prefs.fallbackLanguage == "en")
    }

    @Test("Fuzz UserDefaults keys with empty strings and various whitespace variants")
    func testPreferencesManagerEmptyAndWhitespaceFuzzing() {
        let suiteName = "com.mactranslate.challenger.whitespacefuzz.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to initialize UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let prefs = PreferencesManager(userDefaults: defaults)

        let whitespaceVariants: [String] = [
            "",
            " ",
            "   ",
            "\t",
            "\n",
            "\r\n",
            "   \n\t\r   ",
            "\u{00A0}", // non-breaking space
            "\u{2000}", // en quad
            "\u{2001}", // em quad
            "\u{3000}", // ideographic space
            "  \u{3000}\t  \n "
        ]

        for ws in whitespaceVariants {
            // Direct write to UserDefaults
            defaults.set(ws, forKey: PreferencesManager.Keys.primaryLanguage)
            defaults.set(ws, forKey: PreferencesManager.Keys.secondaryLanguage)
            defaults.set(ws, forKey: PreferencesManager.Keys.fallbackLanguage)

            #expect(prefs.primaryLanguage == "uk", "Failed fallback for whitespace variant: '\(ws)'")
            #expect(!prefs.primaryLanguage.isEmpty)
            #expect(prefs.secondaryLanguage == "en", "Failed fallback for whitespace variant: '\(ws)'")
            #expect(!prefs.secondaryLanguage.isEmpty)
            #expect(prefs.fallbackLanguage == "en", "Failed fallback for whitespace variant: '\(ws)'")
            #expect(!prefs.fallbackLanguage.isEmpty)

            // Write through property setters
            prefs.primaryLanguage = ws
            prefs.secondaryLanguage = ws
            prefs.fallbackLanguage = ws

            #expect(prefs.primaryLanguage == "uk", "Setter failed fallback for whitespace variant: '\(ws)'")
            #expect(!prefs.primaryLanguage.isEmpty)
            #expect(prefs.secondaryLanguage == "en", "Setter failed fallback for whitespace variant: '\(ws)'")
            #expect(!prefs.secondaryLanguage.isEmpty)
            #expect(prefs.fallbackLanguage == "en", "Setter failed fallback for whitespace variant: '\(ws)'")
            #expect(!prefs.fallbackLanguage.isEmpty)
        }
    }

    @Test("Verify valid values are correctly stored and trimmed")
    func testPreferencesManagerValidValues() {
        let suiteName = "com.mactranslate.challenger.validvalues.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to initialize UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let prefs = PreferencesManager(userDefaults: defaults)

        // Valid language codes with surrounding whitespace
        prefs.primaryLanguage = "  zh  "
        prefs.secondaryLanguage = "  ja\n"
        prefs.fallbackLanguage = "\tde  "

        #expect(prefs.primaryLanguage == "zh")
        #expect(prefs.secondaryLanguage == "ja")
        #expect(prefs.fallbackLanguage == "de")

        // Router verification with these preferences
        let routedChinese = LanguagePairRouter.resolveTargetLanguage(
            for: "zh",
            primary: prefs.primaryLanguage,
            secondary: prefs.secondaryLanguage,
            fallback: prefs.fallbackLanguage
        )
        #expect(routedChinese.source == "zh")
        #expect(routedChinese.target == "ja")

        let routedJapanese = LanguagePairRouter.resolveTargetLanguage(
            for: "ja",
            primary: prefs.primaryLanguage,
            secondary: prefs.secondaryLanguage,
            fallback: prefs.fallbackLanguage
        )
        #expect(routedJapanese.source == "ja")
        #expect(routedJapanese.target == "zh")
    }

    @Test("Verify non-language preference keys robustness under corrupted values")
    func testNonLanguageKeysRobustness() {
        let suiteName = "com.mactranslate.challenger.nonlang.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to initialize UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let prefs = PreferencesManager(userDefaults: defaults)

        // Hotkey mode corrupted with invalid enum raw values and invalid types
        defaults.set(999, forKey: PreferencesManager.Keys.hotkeyMode)
        #expect(prefs.hotkeyMode == .doubleCommandC)
        defaults.set("invalidString", forKey: PreferencesManager.Keys.hotkeyMode)
        #expect(prefs.hotkeyMode == .doubleCommandC)

        // Hotkey window corrupted with non-positive values and invalid types
        defaults.set(0.0, forKey: PreferencesManager.Keys.hotkeyWindowMs)
        #expect(prefs.hotkeyWindowMs == 400.0)
        defaults.set(-100.0, forKey: PreferencesManager.Keys.hotkeyWindowMs)
        #expect(prefs.hotkeyWindowMs == 400.0)
        defaults.set("notADouble", forKey: PreferencesManager.Keys.hotkeyWindowMs)
        #expect(prefs.hotkeyWindowMs == 400.0)

        // Dismiss on outside click corrupted with string, array
        defaults.set("false", forKey: PreferencesManager.Keys.dismissOnOutsideClick) // String "false" is not Bool
        #expect(prefs.dismissOnOutsideClick == true)
        defaults.set([1, 2, 3], forKey: PreferencesManager.Keys.dismissOnOutsideClick)
        #expect(prefs.dismissOnOutsideClick == true)

        // Enter key action corrupted with invalid raw value and type
        defaults.set(-1, forKey: PreferencesManager.Keys.enterKeyAction)
        #expect(prefs.enterKeyAction == .copyAndClose)
        defaults.set(100, forKey: PreferencesManager.Keys.enterKeyAction)
        #expect(prefs.enterKeyAction == .copyAndClose)
        defaults.set("enterAction", forKey: PreferencesManager.Keys.enterKeyAction)
        #expect(prefs.enterKeyAction == .copyAndClose)

        // Launch at login corrupted with non-bool types
        defaults.set("true", forKey: PreferencesManager.Keys.launchAtLogin)
        #expect(prefs.launchAtLogin == false)
        defaults.set(12345, forKey: PreferencesManager.Keys.launchAtLogin)
        #expect(prefs.launchAtLogin == false)
    }

    // MARK: - 3. Advanced Edge Cases: Short Phrases & Mixed Script

    @Test("Short Chinese phrases (2-4 characters) disambiguation")
    func testShortChinesePhrases() {
        let shortChinese = [
            "你好",
            "谢谢",
            "再见",
            "对不起",
            "没关系",
            "早上好",
            "晚安",
            "恭喜",
            "请多关照",
            "没问题",
            "謝謝",
            "再見",
            "早安",
            "新年快樂",
            "恭喜發財",
            "沒問題"
        ]

        var jaCount = 0
        var zhCount = 0
        var nilOrOther = 0

        for phrase in shortChinese {
            let detected = detector.detectLanguage(in: phrase)
            if detected == "ja" {
                jaCount += 1
            } else if detected == "zh" {
                zhCount += 1
            } else {
                nilOrOther += 1
            }
        }

        print("[BENCHMARK-SHORT] Short Chinese count: \(shortChinese.count), detected 'zh': \(zhCount), 'ja': \(jaCount), other/nil: \(nilOrOther)")
        // Crucial requirement: Ensure 0% Chinese misclassification as Japanese ("ja")
        #expect(jaCount == 0, "Short Chinese phrases must NEVER be misclassified as Japanese ('ja')!")
    }

    @Test("Mixed Chinese/English and Japanese/English sentences")
    func testMixedScriptSentences() {
        let mixedChinese = [
            "在 macOS 15 上使用 Xcode 开发 Swift 应用程序。",
            "iPhone 16 Pro 搭载了最新的 A18 Pro 芯片，性能非常强劲。",
            "请问这个 API 接口返回的 HTTP 状态码是多少？",
            "我们正在使用 Git 进行代码版本控制和 Pull Request 审核。",
            "DeepSeek 和 OpenAI 都在大语言模型领域取得了突破性进展。"
        ]

        let mixedJapanese = [
            "macOS 15でXcodeを使ってSwiftアプリを開発しています。",
            "iPhone 16 Proには最新のA18 Proチップが搭載されています。",
            "このAPIのHTTPステータスコードを教えてください。",
            "Gitを使用してブランチ管理とPull Requestのレビューを行います。",
            "AI技術の急速な進化によりソフトウェアエンジニアリングが変化しています。"
        ]

        for s in mixedChinese {
            let d = detector.detectLanguage(in: s)
            print("[MIXED-ZH] '\(s)' -> detected: \(d ?? "nil")")
            // Crucial requirement: Chinese must NEVER be misclassified as Japanese ("ja")
            #expect(d != "ja", "Mixed Chinese sentence must NEVER be misclassified as 'ja'!")
        }

        for s in mixedJapanese {
            let d = detector.detectLanguage(in: s)
            print("[MIXED-JA] '\(s)' -> detected: \(d ?? "nil")")
            #expect(d == "ja", "Expected 'ja' for mixed Japanese sentence: \(s), got: \(d ?? "nil")")
            #expect(d != "zh")
        }
    }

    // MARK: - 4. Namespacing & Isolation

    @Test("PreferencesManager keys are properly namespaced and isolated from legacy bare keys")
    func testNamespaceIsolation() {
        let suiteName = "com.mactranslate.challenger.isolation.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to initialize UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Write to legacy bare keys (without com.mactranslate. prefix)
        defaults.set("bare_primary", forKey: "primaryLanguage")
        defaults.set("bare_secondary", forKey: "secondaryLanguage")

        let prefs = PreferencesManager(userDefaults: defaults)

        // Bare keys must NOT bleed into namespaced preferences
        #expect(prefs.primaryLanguage == "uk")
        #expect(prefs.secondaryLanguage == "en")

        // Writing to namespaced preferences must NOT overwrite bare keys
        prefs.primaryLanguage = "de"
        #expect(defaults.string(forKey: "primaryLanguage") == "bare_primary")
        #expect(defaults.string(forKey: PreferencesManager.Keys.primaryLanguage) == "de")
    }

    // MARK: - 5. Multithreaded Concurrent Fuzzing

    private final class ConcurrentContext: @unchecked Sendable {
        let defaults: UserDefaults
        let prefs: PreferencesManager
        init(defaults: UserDefaults, prefs: PreferencesManager) {
            self.defaults = defaults
            self.prefs = prefs
        }
    }

    @Test("Multithreaded concurrent fuzzing of PreferencesManager")
    func testConcurrentFuzzing() async {
        let suiteName = "com.mactranslate.challenger.concurrent.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to initialize UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let prefs = PreferencesManager(userDefaults: defaults)
        let context = ConcurrentContext(defaults: defaults, prefs: prefs)

        // Run 8 concurrent worker tasks performing 200 fuzzing operations each
        await withTaskGroup(of: Void.self) { group in
            for threadId in 0..<8 {
                group.addTask { [context] in
                    for i in 0..<200 {
                        let op = (threadId + i) % 7
                        switch op {
                        case 0:
                            // Corrupted Int
                            context.defaults.set(12345, forKey: PreferencesManager.Keys.primaryLanguage)
                        case 1:
                            // Corrupted Data
                            context.defaults.set(Data([0xAA, 0xBB]), forKey: PreferencesManager.Keys.secondaryLanguage)
                        case 2:
                            // Corrupted [String]
                            context.defaults.set(["a", "b"], forKey: PreferencesManager.Keys.primaryLanguage)
                        case 3:
                            // Empty string
                            context.defaults.set("", forKey: PreferencesManager.Keys.secondaryLanguage)
                            context.prefs.primaryLanguage = ""
                        case 4:
                            // Whitespace
                            context.defaults.set("   \t\n  ", forKey: PreferencesManager.Keys.primaryLanguage)
                            context.prefs.secondaryLanguage = "   "
                        case 5:
                            // Valid value
                            context.prefs.primaryLanguage = "zh"
                            context.prefs.secondaryLanguage = "ja"
                        default:
                            break
                        }

                        // Invariant verification on every iteration
                        let p = context.prefs.primaryLanguage
                        let s = context.prefs.secondaryLanguage
                        let f = context.prefs.fallbackLanguage

                        // Neither primaryLanguage nor secondaryLanguage must EVER be empty string
                        #expect(!p.isEmpty, "Thread \(threadId) observed empty primaryLanguage!")
                        #expect(!s.isEmpty, "Thread \(threadId) observed empty secondaryLanguage!")
                        #expect(!f.isEmpty, "Thread \(threadId) observed empty fallbackLanguage!")

                        // Routing invariant: router must resolve cleanly without crashing or empty strings
                        let routed = LanguagePairRouter.resolveTargetLanguage(for: "en", primary: p, secondary: s, fallback: f)
                        #expect(!routed.source.isEmpty)
                        #expect(!routed.target.isEmpty)
                    }
                }
            }
        }
    }
}

