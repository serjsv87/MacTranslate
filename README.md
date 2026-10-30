# MacTranslate ⚡

<div align="center">

![macOS 15+](https://img.shields.io/badge/macOS-15%2B%20%7C%20Apple%20Silicon-blue?style=flat-square&logo=apple)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square&logo=swift)
![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Privacy: 100% Offline](https://img.shields.io/badge/Privacy-100%25%20Offline-success?style=flat-square)
![Engine: Apple Neural Engine](https://img.shields.io/badge/Inference-Apple%20Neural%20Engine-purple?style=flat-square)
[![Give me coffee](https://img.shields.io/badge/☕%EF%B8%8F%20Give%20me%20coffee-TRC20-yellow?style=flat-square)](#️-give-me-coffee--support-the-project)

**Ultra-fast, native macOS offline translation utility running locally on Apple Silicon.**  
*Instant translation at your fingertips, just like DeepL — without cloud latency, character limits, or subscriptions.*

[Why MacTranslate?](#-why-mactranslate-speed-convenience--zero-limits) • [Features](#-features) • [Lite vs Pro (soon)](#️-mactranslate-lite-vs-pro-soon) • [Shortcuts](#-keyboard-shortcuts) • [Installation](#-installation) • [Permissions](#-security--permissions) • [Give me coffee ☕️](#️-give-me-coffee--support-the-project)

</div>

---

## ⚡ Why MacTranslate? Speed, Convenience & Zero Limits

Most modern translation tools force you to trade away your privacy, pay monthly subscriptions, or struggle with restrictive free-tier character caps. **MacTranslate was built to eliminate these compromises entirely.**

| Metric / Feature | 🌐 DeepL / Google Cloud | ⚡ MacTranslate Lite |
| :--- | :---: | :---: |
| **Translation Speed** | 400ms – 1,200ms (Network ping + Cloud queue) | **< 80ms** (Instant on-device Neural Engine) |
| **Character Limits** | 1,500 chars limit (DeepL Free) | **♾️ UNLIMITED (Translate entire texts)** |
| **Daily / Monthly Quotas** | Strict API caps & rate limiting | **🚫 ZERO limits — translate 24/7** |
| **Internet Required** | Yes (Fails on airplanes, trains, roaming) | **No — 100% Offline & Autonomous** |
| **Clipboard Privacy** | Sent to remote 3rd-party servers | **🔒 Never leaves your Mac's RAM** |
| **In-Place Replace (`⌘V`)** | Copy, Switch app, Select, Paste | **⚡ One-tap instant in-place replacement** |
| **Price** | Free with limits or $104+/year | **🆓 100% Free & Open Source (MIT)** |

---

## 🎯 Unbeatable Speed & Convenience

1. ⚡ **Instant Response (<80ms)**:
   Powered by Apple's on-device `Translation.framework` executing directly on the **Apple Neural Engine (ANE)**. Translation happens while you blink, using virtually zero CPU or battery.
2. 🙌 **Double-Tap Hotkey (`⌘C + C` or `⌥Space`)**:
   Select any word or passage anywhere in macOS, double-tap `⌘C`, and an elegant floating HUD appears instantly near your cursor.
3. ⚡ **One-Tap In-Place Replace (`⌘V` / Replace)**:
   Done reading the translation? Press `⌘V` (or click Replace) and MacTranslate automatically switches back to your active app (Telegram, Slack, Notes, Xcode, Mail, Word) and replaces the selected text with the translation.
4. 🔄 **Smart Bidirectional Language Routing**:
   No need to manually pick source and target languages:
   - 🇷🇺 Russian ➔ 🇬🇧 English
   - 🇬🇧 English ➔ 🇺🇦 Ukrainian
   - 🇺🇦 Ukrainian ➔ 🇬🇧 English
   - Custom user rules with fallback language support.
5. 🔊 **Native Voice Pronunciation**:
   Pronounce source or translated text with Apple's high-definition localized voice models via `AVSpeechSynthesizer`.
6. 🌐 **Bilingual Interface**:
   Seamlessly switch the app interface between **English** and **Ukrainian** in Settings.

---

## ⭐️ MacTranslate Lite vs Pro (soon)

MacTranslate is offered in two tiers: **Lite** (100% Free & Open-Source) and **Pro** (Enhanced Power Tools for Professionals & Language Learners at $12/year — **soon**).

| Feature | 🆓 MacTranslate Lite (Free) | ⭐️ MacTranslate Pro ($12/yr) *(soon)* |
| :--- | :---: | :---: |
| **Unlimited Offline Translations** | ✅ Included (Apple Neural Engine) | ✅ Included (Apple Neural Engine) |
| **Global Double-Tap Hotkey (`⌘C + C`)** | ✅ Included | ✅ Included |
| **Instant In-Place Paste (`⌘V` / Replace)** | ✅ Included | ✅ Included |
| **Smart Routing Rules (RU➔EN, EN➔UA, UA➔EN)** | ✅ Included | ✅ Included |
| **TTS Pronunciation & Audio Synthesis** | ✅ Included | ✅ Included |
| **Bilingual UI (English & Ukrainian)** | ✅ Included | ✅ Included |
| **Zero Character Limits & Zero Telemetry** | ✅ 100% Free Forever | ✅ Included |
| **📸 Screen OCR Area Translation (`⌥S`)** | ❌ (Upgrade to Pro — soon) | ✅ **Apple Vision on-device OCR** |
| **🎭 Live AI Tone Switcher (Business/Casual/Tech)** | ❌ (Upgrade to Pro — soon) | ✅ **Dynamic style transformation** |
| **🎯 Contextual App Profiles (Per-app rules)** | ❌ (Upgrade to Pro — soon) | ✅ **Auto-adapts to active app** |
| **📚 Vocabulary History & Anki Flashcard Export** | ❌ (Upgrade to Pro — soon) | ✅ **1-Click CSV Spaced Repetition** |

---

## 🚀 Pro Features Overview (soon)

* **📸 Screen OCR Translation (`⌥S`)**: Capture text inside YouTube subtitles, video games, protected PDFs, images, or web diagrams and translate them instantly with on-device Apple Vision.
* **🎭 Live AI Tone Switcher**: Transform translations on the fly between **Standard**, **Formal / Business** (corporate emails), **Casual / Friendly** (chats), and **Concise / Technical** (documentation).
* **🎯 Contextual App Profiles**: Assign specific default language pairs to individual apps (e.g. Xcode -> technical English, Telegram -> casual Ukrainian).
* **📇 Vocabulary Bank & Anki CSV Export**: Save translated words to your personal study bank with one tap. Export formatted `.csv` flashcards for **Anki** (Spaced Repetition System) to master new vocabulary effortlessly.

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Description |
| :--- | :--- |
| **`⌘C + C`** | Trigger translation on selected text anywhere in macOS |
| **`⌘V`** / **`⌃V`** | **Instant In-Place Paste**: Switches back to active app and pastes translation |
| **`⌘↩`** (`Cmd + Enter`) | Copy translation to clipboard and dismiss HUD |
| **`Enter`** | Insert a newline into the source text area |
| **`Esc`** | Dismiss floating HUD |
| **`⌥Space`** | Alternate global trigger shortcut |
| **`⌥S`** *(Pro — soon)* | **Screen OCR**: Drag crosshair over any screen area to translate |
| **`⌘H`** *(Pro — soon)* | Open Vocabulary History and Anki Export window |
| **`⌘,`** | Open Preferences / Settings window |

---

## 🚀 Installation

### Option 1: Pre-built Disk Image (DMG)
1. Download [`MacTranslate.dmg`](https://github.com/serjsv87/MacTranslate/releases/latest).
2. Open `MacTranslate.dmg` and drag `MacTranslate.app` into your `/Applications` folder.
3. Launch **MacTranslate** from Spotlight or Applications.
4. When prompted, grant **Accessibility** permissions (needed for `⌘C + C` shortcut detection and `⌘V` text replacement).

---

## 🛡️ Security & Permissions

MacTranslate requires macOS **Accessibility** permission strictly to detect global double-taps (`⌘C + C`) and insert translated text back into your active window.

* **Zero Network Usage**: MacTranslate does not initiate network connections. Your clipboard contents never leave your machine.
* **Open Source Transparency**: All source code is public and auditable under the MIT license.
* **Zero Telemetry**: No analytics, crash loggers, or tracking scripts.

For technical details, see [PERMISSIONS.md](PERMISSIONS.md).

---

## 🛠️ Building from Source

### Prerequisites
- macOS 15.0 or later (Sequoia)
- Xcode 16.0+ or Swift 6.0 toolchain
- Apple Silicon Mac (M1/M2/M3/M4) recommended

### Build & Package
```bash
# Clone the repository
git clone https://github.com/serjsv87/MacTranslate.git
cd MacTranslate/lite

# Build release bundle and DMG installer
./build_app.sh
```
The compiled `MacTranslate.app` and `MacTranslate.dmg` will be generated directly in the `lite/` folder.

---

## ☕️ Give me coffee / Support the Project

If you love **MacTranslate** and want to support its ongoing open-source development:

* **Network**: `TRON (TRC20)`
* **USDT Address**: `TByNXKW2VpECVUpTZFUbyo8YGgYsbC1HJV`

Every cup of coffee helps keep MacTranslate fast, 100% offline, privacy-first, and freely available for everyone! 🚀

---

## 📄 License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more details.
