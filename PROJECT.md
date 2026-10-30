# Project: MacTranslate

## Architecture
MacTranslate is a native macOS 15+ background utility (`LSUIElement`) providing instant, local on-device translation using Apple's `Translation` framework (running on Apple Neural Engine) and `NaturalLanguage`.

### Module Boundaries
1. **Core Module (`Sources/MacTranslate/Core/`)**:
   - `LanguageDetector`: Auto language identification via `NLLanguageRecognizer`, language constraints for short strings, localized display names, and emoji flags.
   - `TranslationEngine`: On-device translation via `TranslationSession`, model status inspection (`LanguageAvailability`), session caching, latency optimization, and error handling.
   - `LanguagePairRouter`: Smart language routing (Primary <-> Secondary, fallback for third languages).
   - `PreferencesManager`: UserDefaults configuration persistence for pairs, hotkeys, and app behavior.
2. **Services Module (`Sources/MacTranslate/Services/`)**:
   - `HotkeyManager`: Double-tap detection (`⌘C+C`, `⌃C+C`) within 400ms time window via `CGEventTap` (.listenOnly) with timeout self-healing; alternate shortcut support.
   - `ClipboardService`: Active selection extraction via `AXUIElement` (`kAXSelectedTextAttribute`) with clipboard change fallback.
   - `TextReplacementService`: In-place text replacement in frontmost application via `AXUIElement` and synthetic `⌘V` paste.
   - `AccessibilityHelper`: `AXIsProcessTrusted` verification and direct deep-linking to macOS System Settings.
3. **UI Module (`Sources/MacTranslate/UI/`)**:
   - Native AppKit UI (100% compatible with Apple Command Line Tools without requiring `SwiftUIMacros`).
   - `FloatingHUDPanel`: Borderless, non-activating floating `NSPanel` (`.popUpMenu`, `.fullScreenAuxiliary`), cursor tracking with screen frame bounds clamping, `Esc` dismissal.
   - `HUDContentView`: Translucent `NSVisualEffectView` backdrop, source selector with Auto indicator, target selector with instant re-translation, direction swap (`⇄`), editable input text view, translated output view, action buttons (Copy / `Enter`, Replace, Speak TTS via `AVSpeechSynthesizer`, Settings `⚙`).
   - `StatusBarController`: Menu bar `NSStatusItem` with quick pair switcher, manual translate action, settings opener, permissions indicator, and quit option.
   - `SettingsWindowController`: Preferences window with tabs: Languages, Hotkeys, Behavior, and Accessibility permissions.
4. **App Lifecycle & Packaging (`Sources/MacTranslate/App/` & Scripts)**:
   - `AppDelegate` / `main.swift`: Coordinates lifecycle, initializes status item, HUD panel, hotkey manager, and translation engine.
   - `Info.plist`: Background agent configuration (`LSUIElement = true`).
   - `build_app.sh`: Automated compilation (`swift build -c release`) and packaging into standalone executable `MacTranslate.app` bundle.
5. **E2E Testing Track (`Tests/E2ETests/` & Test Harness)**:
   - Automated 4-tier requirement-driven opaque-box test suite + Tier 5 adversarial stress harness.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Language Detection | Detects source language of text using `NLLanguageRecognizer` | M1 | Survey §R1 |
| 2 | Language Metadata Display | Maps language codes to localized names & emoji flags | M1 | Survey §R1 |
| 3 | Translation Availability Inspection | Queries supported & installed models via `LanguageAvailability` | M1 | Survey §R1 |
| 4 | On-Device Translation Engine | Translates text on Apple Neural Engine via `TranslationSession` | M1 | Survey §R1 |
| 5 | Translation Session Caching | Caches active `TranslationSession` instances by language pair | M1 | Survey §R1 |
| 6 | Smart Language Pair Router | Routes text primary <-> secondary; fallback target for others | M1 | Survey §R1 |
| 7 | User Preferences Persistence | Persists configuration in `UserDefaults` | M1 | Survey §R1 |
| 8 | Double ⌘C+C Hotkey Detection | Triggers translation on double `⌘C` within 400ms | M2 | Survey §R2 |
| 9 | Double ⌃C+C Hotkey Detection | Triggers translation on double `⌃C` within 400ms | M2 | Survey §R2 |
| 10 | Alternate Global Hotkey | Triggers translation on alternative shortcut | M2 | Survey §R2 |
| 11 | Selected Text Extraction | Extracts text via `AXUIElement` or clipboard fallback | M2 | Survey §R2 |
| 12 | In-Place Text Replacement | Replaces selected text in active frontmost application | M2 | Survey §R2 |
| 13 | Accessibility Permission Checker | Verifies permissions via `AXIsProcessTrusted()` | M2 | Survey §R2 |
| 14 | Floating Non-Activating NSPanel | Borderless floating panel that doesn't steal focus | M3 | Survey §R3 |
| 15 | Cursor Positioning & Clamping | Positions HUD near mouse cursor within screen bounds | M3 | Survey §R3 |
| 16 | Escape Key Dismissal | Closes/hides HUD on `Esc` key press | M3 | Survey §R3 |
| 17 | Translucent HUD Styling | Translucent backdrop using `NSVisualEffectView` | M3 | Survey §R3 |
| 18 | Source Selector with Auto Indicator | Dropdown with detected language & manual override | M3 | Survey §R3 |
| 19 | Target Selector with Live Update | Dropdown with immediate re-translation | M3 | Survey §R3 |
| 20 | Direction Swap Button (⇄) | Swaps languages and inverts translated text | M3 | Survey §R3 |
| 21 | Editable Original Text Field | Text view for manual input/editing with debounced translation | M3 | Survey §R3 |
| 22 | High-Contrast Translated Display | Clean, selectable display for translated text | M3 | Survey §R3 |
| 23 | Copy Action with Feedback | Copies translation to clipboard (`Enter` key) with visual confirmation | M3 | Survey §R3 |
| 24 | Replace Action | Replaces selection in target application and dismisses HUD | M3 | Survey §R3 |
| 25 | Text-to-Speech (TTS) | Speaks translated text via `AVSpeechSynthesizer` | M3 | Survey §R3 |
| 26 | Settings Navigation Shortcut | Gear button in HUD opens Preferences window | M3 | Survey §R3 |
| 27 | Menu Bar NSStatusItem | Status item in macOS menu bar with icon and menu | M3 | Survey §R3 |
| 28 | Quick Pair Submenu | Menu item submenu for instant 1-click pair switching | M3 | Survey §R3 |
| 29 | Manual Translate Action | Menu item to translate clipboard (`⌘T`) | M3 | Survey §R3 |
| 30 | Permissions Indicator & Link | Status item menu link to System Settings if untrusted | M3 | Survey §R3 |
| 31 | Preferences Window Controller | Multi-tab settings window (`NSWindowController`) | M3 | Survey §R3 |
| 32 | Languages Preference Tab | Configures primary, secondary, and fallback languages | M3 | Survey §R3 |
| 33 | Hotkeys Preference Tab | Configures shortcut trigger and timing window | M3 | Survey §R3 |
| 34 | Behavior Preference Tab | Configures Enter action, outside click dismiss, auto-start | M3 | Survey §R3 |
| 35 | System Permissions Tab | Shows Accessibility trust status with Grant button | M3 | Survey §R3 |
| 36 | LSUIElement Background Mode | Hides app from Dock and prevents focus stealing | M4 | Survey §R4 |
| 37 | Automated Build Script (`build_app.sh`) | Compiles and packages `MacTranslate.app` bundle | M4 | Survey §R4 |
| 38 | Automated Unit Test Suite | Comprehensive unit tests for detection, routing, preferences | M4 | Survey §R4 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M0 | E2E Testing Track | Independent opaque-box test suite (Tiers 1-4) & TEST_READY.md | none | DONE |
| M1 | Core Translation & Routing Engine | Features 1-7: LanguageDetector, TranslationEngine, LanguagePairRouter, PreferencesManager, Unit Tests | none | DONE |
| M2 | Global Shortcuts & Accessibility | Features 8-13: HotkeyManager (400ms double-tap), ClipboardService, TextReplacementService, AccessibilityHelper | none | IN_PROGRESS |
| M3 | Interactive Floating HUD & UI | Features 14-35: FloatingHUDPanel, HUDContentView, StatusBarController, SettingsWindowController | M1, M2 | PLANNED |
| M4 | Packaging, Lifecycle & Build Script | Features 36-38: AppDelegate, main.swift, Info.plist, build_app.sh, Package.swift target updates | M1, M2, M3 | PLANNED |
| M5 | Final E2E Pass & Adversarial Hardening | Phase 1: 100% pass of Tiers 1-4. Phase 2: Tier 5 Adversarial Coverage Hardening | M0, M4 | PLANNED |

## Interface Contracts

### M1 (Core) ↔ M2 (Shortcuts/Services) & M3 (UI)
- `LanguageDetector`:
  - `func detectLanguage(in text: String) -> String?`
  - `func localizedName(for languageCode: String) -> String`
  - `func flagEmoji(for languageCode: String) -> String`
- `TranslationEngine`:
  - `func translate(text: String, from sourceLang: String, to targetLang: String) async throws -> String`
  - `func isModelInstalled(from sourceLang: String, to targetLang: String) -> Bool`
- `LanguagePairRouter`:
  - `func resolveTargetLanguage(for detectedLang: String?, primary: String, secondary: String, fallback: String) -> (source: String, target: String)`
- `PreferencesManager`:
  - `var primaryLanguage: String { get set }`
  - `var secondaryLanguage: String { get set }`
  - `var fallbackLanguage: String { get set }`
  - `var hotkeyMode: HotkeyMode { get set }`
  - `var hotkeyWindowMs: Double { get set }`
  - `var dismissOnOutsideClick: Bool { get set }`
  - `var enterKeyAction: EnterKeyAction { get set }`

### M2 (Shortcuts/Services) ↔ M3 (UI) & M4 (App)
- `HotkeyManager`:
  - `func startListening(onTrigger: @escaping () -> Void)`
  - `func stopListening()`
- `ClipboardService`:
  - `func getSelectedText() -> String?`
  - `func copyToClipboard(text: String)`
- `TextReplacementService`:
  - `func replaceSelectedText(with newText: String)`
- `AccessibilityHelper`:
  - `static func isAccessibilityTrusted() -> Bool`
  - `static func openAccessibilitySettings()`

### M3 (UI) ↔ M4 (App)
- `FloatingHUDPanel`:
  - `func present(withText text: String, nearCursor cursor: NSPoint)`
  - `func dismissHUD()`
- `StatusBarController`:
  - `func setupStatusItem()`
  - `func updatePermissionsIndicator(isTrusted: Bool)`
- `SettingsWindowController`:
  - `func showWindow()`

## Code Layout
```
translatemacos/
├── Package.swift
├── build_app.sh
├── Info.plist
├── Sources/
│   └── MacTranslate/
│       ├── main.swift
│       ├── App/
│       │   └── AppDelegate.swift
│       ├── Core/
│       │   ├── LanguageDetector.swift
│       │   ├── TranslationEngine.swift
│       │   ├── LanguagePairRouter.swift
│       │   └── PreferencesManager.swift
│       ├── Services/
│       │   ├── HotkeyManager.swift
│       │   ├── ClipboardService.swift
│       │   ├── TextReplacementService.swift
│       │   └── AccessibilityHelper.swift
│       └── UI/
│           ├── FloatingHUDPanel.swift
│           ├── HUDContentView.swift
│           ├── StatusBarController.swift
│           └── SettingsWindowController.swift
└── Tests/
    ├── MacTranslateTests/
    │   ├── LanguageDetectionTests.swift
    │   ├── LanguagePairRoutingTests.swift
    │   └── PreferencesPersistenceTests.swift
    └── E2ETests/
        ├── E2ETestHarness.swift
        ├── Tier1FeatureTests.swift
        ├── Tier2BoundaryTests.swift
        ├── Tier3CombinationTests.swift
        └── Tier4ScenarioTests.swift
```
