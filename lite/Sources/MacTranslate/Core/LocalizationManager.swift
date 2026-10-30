import Foundation

public enum AppInterfaceLanguage: String, CaseIterable, Codable, Sendable {
    case system = "system"
    case en = "en"
    case uk = "uk"
    
    public var displayName: String {
        switch self {
        case .system: return "System Default"
        case .en: return "English"
        case .uk: return "Українська"
        }
    }
}

public final class LocalizationManager: @unchecked Sendable {
    public static let shared = LocalizationManager()
    public static let languageDidChangeNotification = Notification.Name("MacTranslateAppLanguageDidChangeNotification")
    public static let donationAddressTRC20 = "TByNXKW2VpECVUpTZFUbyo8YGgYsbC1HJV"
    public static let donationNetwork = "USDT (TRC20)"
    
    private let lock = NSLock()
    private var cachedLanguage: AppInterfaceLanguage = .system
    
    private init() {
        self.cachedLanguage = PreferencesManager.shared.appLanguage
    }
    
    public var currentLanguage: AppInterfaceLanguage {
        get {
            lock.lock()
            defer { lock.unlock() }
            return cachedLanguage
        }
        set {
            lock.lock()
            cachedLanguage = newValue
            PreferencesManager.shared.appLanguage = newValue
            lock.unlock()
            
            NotificationCenter.default.post(name: Self.languageDidChangeNotification, object: nil)
        }
    }
    
    /// The effective language code ("en" or "uk")
    public var effectiveLanguageCode: String {
        let lang = currentLanguage
        if lang == .system {
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            if preferred.hasPrefix("uk") {
                return "uk"
            }
            return "en"
        }
        return lang.rawValue
    }
    
    public var currentLocale: Locale {
        return Locale(identifier: effectiveLanguageCode)
    }
    
    public func localized(_ key: String) -> String {
        let lang = effectiveLanguageCode
        if let dict = strings[lang], let val = dict[key] {
            return val
        }
        // Fallback to English
        if let dict = strings["en"], let val = dict[key] {
            return val
        }
        return key
    }
    
    private let strings: [String: [String: String]] = [
        "en": [
            // HUD
            "hud.auto_detect": "Auto-detect",
            "hud.auto_prefix": "Auto: ",
            "hud.ane_offline": "⚡ Apple Neural Engine (offline)",
            "hud.cloud_online": "☁️ Cloud Translation (online)",
            "hud.btn_download_model": "⬇ Download Offline",
            "hud.download_tooltip": "Open macOS settings to download offline language model",
            "hud.translating": "⏳ Translating...",
            "hud.inference": "⏳ Local inference...",
            "hud.type_prompt": "Type text to translate",
            "hud.copy": "Copy [ ⌘↩ ]",
            "hud.replace": "Paste to App [ ⌘V ]",
            "hud.toast_copied": "Copied! ✓",
            "hud.toast_replaced": "Pasted to App! ✓",
            "hud.speak_tooltip": "Pronounce text",
            "hud.settings_tooltip": "Settings",
            "hud.swap_tooltip": "Swap languages",
            "hud.close_tooltip": "Close",
            "hud.coffee_tooltip": "Give me coffee (TRC20): TByNXKW2VpECVUpTZFUbyo8YGgYsbC1HJV",
            "hud.toast_coffee_copied": "☕️ TRC20 address copied! Thank you!",
            
            // Menu Bar
            "menu.header": "MacTranslate ⚡ Apple Neural Engine",
            "menu.translate_selection": "Translate Selection",
            "menu.screen_ocr_lite": "📷 Screen OCR Translation [PRO]",
            "menu.history_anki_lite": "📜 Vocabulary & Anki [PRO]",
            "menu.coffee": "☕️ Give me coffee (TRC20)",
            "menu.settings": "Settings...",
            "menu.github": "GitHub Repository",
            "menu.about": "About MacTranslate",
            "menu.quit": "Quit MacTranslate",
            
            // Pro Upsell
            "pro.alert_title": "Feature available in MacTranslate Pro",
            "pro.alert_desc": "Screen OCR, AI Tone Switcher, History, Anki Vocabulary, and App Profiles are included in the Pro version ($12/year).",
            "pro.alert_btn": "Got it",
            
            // Settings Window
            "settings.title": "MacTranslate Settings",
            "settings.section_general": "General & Interface",
            "settings.section_rules": "Language Pairs & Routing Rules",
            "settings.section_hotkeys": "Shortcuts & Timing",
            "settings.section_behavior": "Behavior & Permissions",
            
            "settings.app_language": "App Language:",
            "settings.primary_lang": "Primary Language:",
            "settings.secondary_lang": "Secondary Language:",
            "settings.fallback_lang": "Fallback Target Language:",
            "settings.fallback_desc": "Used when the detected language matches no rule.",
            
            "settings.rules_header": "Default Translation Pairs (Routing Rules):",
            "settings.rule_if_detected": "When detected:",
            "settings.rule_translate_to": "Translate to:",
            "settings.btn_add_rule": "+ Add New Language Rule",
            
            "settings.hotkey_shortcut": "Trigger Shortcut:",
            "settings.hotkey_double_cmd_c": "Double ⌘C (⌘C+C)",
            "settings.hotkey_double_ctrl_c": "Double ⌃C (⌃C+C)",
            "settings.hotkey_alternate": "Alternate (⌥Space)",
            "settings.hotkey_timing": "Double-tap Timing Window:",
            
            "settings.dismiss_outside": "Dismiss popup when clicking outside",
            "settings.replace_directly": "Replace selected text directly on shortcut trigger",
            "settings.launch_at_login": "Launch MacTranslate automatically at login",
            
            "settings.permissions_title": "System Permissions:",
            "settings.permissions_ax_title": "Accessibility (Text Replacement & Hotkeys):",
            "settings.permissions_ax_missing": "Grant Accessibility Permission (Click)",
            "settings.permissions_screen_title": "Screen Recording (Screen OCR):",
            "settings.permissions_screen_missing": "Grant Screen Recording Permission (Click)",
            "settings.permissions_granted": "✓ Granted",
            "settings.permissions_missing": "⚠ Missing",
            "settings.btn_open_ax": "Open Accessibility Settings",
            "settings.btn_open_screen": "Open Screen Recording Settings",
            "settings.permissions_reset_tip": "💡 Tip for App Updates: If shortcuts or OCR stop responding after an update, open the respective section above, remove (-) or toggle MacTranslate off/on, and restart the app.",
            "settings.btn_open_privacy": "Open Privacy Settings",
            
            // Support / Give me coffee
            "settings.section_support": "☕️ Give me coffee / Support the Project",
            "settings.support_desc": "If you enjoy using MacTranslate, consider supporting its development with a coffee via USDT (TRC20):",
            "settings.btn_copy_trc20": "Copy TRC20 Address",
            "settings.support_copied": "✓ TRC20 Address Copied! Thank you! ☕️"
        ],
        "uk": [
            // HUD
            "hud.auto_detect": "Автовизначення",
            "hud.auto_prefix": "Авто: ",
            "hud.ane_offline": "⚡ Apple Neural Engine (офлайн)",
            "hud.cloud_online": "☁️ Хмарний переклад (онлайн)",
            "hud.btn_download_model": "⬇ Завантажити офлайн",
            "hud.download_tooltip": "Відкрити системні налаштування macOS для завантаження офлайн-мови",
            "hud.translating": "⏳ Перекладаємо...",
            "hud.inference": "⏳ Локальний інференс...",
            "hud.type_prompt": "Введіть текст для перекладу",
            "hud.copy": "Скопіювати [ ⌘↩ ]",
            "hud.replace": "Вставити в текст [ ⌘V ]",
            "hud.toast_copied": "Скопійовано! ✓",
            "hud.toast_replaced": "Вставлено! ✓",
            "hud.speak_tooltip": "Озвучити текст",
            "hud.settings_tooltip": "Налаштування",
            "hud.swap_tooltip": "Поміняти напрямок",
            "hud.close_tooltip": "Закрити",
            "hud.coffee_tooltip": "Пригостити кавою (TRC20): TByNXKW2VpECVUpTZFUbyo8YGgYsbC1HJV",
            "hud.toast_coffee_copied": "☕️ TRC20 адресу скопійовано! Дякую!",
            
            // Menu Bar
            "menu.header": "MacTranslate ⚡ Apple Neural Engine",
            "menu.translate_selection": "Перекласти виділене",
            "menu.screen_ocr_lite": "📷 Знімок екрана (OCR) [PRO]",
            "menu.history_anki_lite": "📜 Словник та Anki [PRO]",
            "menu.coffee": "☕️ Пригостити кавою (TRC20)",
            "menu.settings": "Налаштування...",
            "menu.github": "Репозиторій на GitHub",
            "menu.about": "Про MacTranslate",
            "menu.quit": "Вийти з MacTranslate",
            
            // Pro Upsell
            "pro.alert_title": "Функція доступна в MacTranslate Pro",
            "pro.alert_desc": "Знімок екрана (OCR), ШІ-стилі перекладу, Історія, Словник Anki та профілі додатків входять у Pro-версію ($12/рік).",
            "pro.alert_btn": "Зрозуміло",
            
            // Settings Window
            "settings.title": "Налаштування MacTranslate",
            "settings.section_general": "Загальні та мова інтерфейсу",
            "settings.section_rules": "Пари мов та правила перекладу",
            "settings.section_hotkeys": "Гарячі клавіші та таймінг",
            "settings.section_behavior": "Поведінка та дозволи",
            
            "settings.app_language": "Мова інтерфейсу:",
            "settings.primary_lang": "Основна мова:",
            "settings.secondary_lang": "Друга мова:",
            "settings.fallback_lang": "Мова за замовчуванням (Fallback):",
            "settings.fallback_desc": "Використовується, якщо для розпізнаної мови немає окремого правила.",
            
            "settings.rules_header": "Пари перекладу за замовчуванням (Routing Rules):",
            "settings.rule_if_detected": "Якщо розпізнано:",
            "settings.rule_translate_to": "перекладати на:",
            "settings.btn_add_rule": "+ Додати нове мовне правило",
            
            "settings.hotkey_shortcut": "Швидка клавіша:",
            "settings.hotkey_double_cmd_c": "Подвійний ⌘C (⌘C+C)",
            "settings.hotkey_double_ctrl_c": "Подвійний ⌃C (⌃C+C)",
            "settings.hotkey_alternate": "Альтернативна (⌥Space)",
            "settings.hotkey_timing": "Швидкість подвійного натискання:",
            
            "settings.dismiss_outside": "Закривати вікно при кліку поза ним",
            "settings.replace_directly": "Вставляти переклад одразу замість виділеного",
            "settings.launch_at_login": "Запускати MacTranslate автоматично при вході",
            
            "settings.permissions_title": "Системні дозволи:",
            "settings.permissions_ax_title": "Універсальний доступ (Вставка тексту та гарячі клавіші):",
            "settings.permissions_ax_missing": "Надати дозвіл «Універсальний доступ» (Натисніть)",
            "settings.permissions_screen_title": "Запис екрана (Переклад знімка OCR):",
            "settings.permissions_screen_missing": "Надати дозвіл «Запис екрана» (Натисніть)",
            "settings.permissions_granted": "✓ Надано",
            "settings.permissions_missing": "⚠ Не надано",
            "settings.btn_open_ax": "Відкрити «Універсальний доступ»",
            "settings.btn_open_screen": "Відкрити «Запис екрана»",
            "settings.permissions_reset_tip": "💡 Порада при оновленні: якщо після оновлення гарячі клавіші чи скріншот не реагують, перейдіть у потрібний розділ вище, вимкніть/увімкніть тумблер або видаліть (-) MacTranslate у налаштуваннях macOS і перезапустіть додаток.",
            "settings.btn_open_privacy": "Відкрити налаштування приватності",
            
            // Support / Give me coffee
            "settings.section_support": "☕️ Give me coffee / Підтримати проєкт",
            "settings.support_desc": "Подобається MacTranslate? Ви можете підтримати розвиток проєкту та пригостити автора кавою через USDT (TRC20):",
            "settings.btn_copy_trc20": "Скопіювати адресу TRC20",
            "settings.support_copied": "✓ Адресу TRC20 скопійовано! Дякуємо за каву! ☕️"
        ]
    ]
}

public func L10n(_ key: String) -> String {
    return LocalizationManager.shared.localized(key)
}
