import Foundation

public enum HotkeyMode: Int, CaseIterable, Codable, Sendable {
    case doubleCommandC = 0
    case doubleControlC = 1
    case alternate = 2
}

public enum EnterKeyAction: Int, CaseIterable, Codable, Sendable {
    case copyAndClose = 0
    case copyOnly = 1
}

public final class PreferencesManager: @unchecked Sendable {
    public static let shared = PreferencesManager()
    
    private let defaults: UserDefaults
    private let lock = NSLock()
    
    public enum Keys {
        public static let prefix = "com.mactranslate."
        public static let primaryLanguage = "com.mactranslate.primaryLanguage"
        public static let secondaryLanguage = "com.mactranslate.secondaryLanguage"
        public static let fallbackLanguage = "com.mactranslate.fallbackLanguage"
        public static let hotkeyMode = "com.mactranslate.hotkeyMode"
        public static let hotkeyWindowMs = "com.mactranslate.hotkeyWindowMs"
        public static let dismissOnOutsideClick = "com.mactranslate.dismissOnOutsideClick"
        public static let enterKeyAction = "com.mactranslate.enterKeyAction"
        public static let launchAtLogin = "com.mactranslate.launchAtLogin"
        public static let appLanguage = "com.mactranslate.appLanguage"
    }
    
    public init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }
    
    public var primaryLanguage: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let raw = defaults.object(forKey: Keys.primaryLanguage) as? String else {
                return "uk"
            }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "uk" : trimmed
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.set(trimmed.isEmpty ? "uk" : trimmed, forKey: Keys.primaryLanguage)
        }
    }
    
    public var secondaryLanguage: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let raw = defaults.object(forKey: Keys.secondaryLanguage) as? String else {
                return "en"
            }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "en" : trimmed
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.set(trimmed.isEmpty ? "en" : trimmed, forKey: Keys.secondaryLanguage)
        }
    }
    
    public var fallbackLanguage: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let raw = defaults.object(forKey: Keys.fallbackLanguage) as? String else {
                return "en"
            }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "en" : trimmed
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.set(trimmed.isEmpty ? "en" : trimmed, forKey: Keys.fallbackLanguage)
        }
    }
    
    public var hotkeyMode: HotkeyMode {
        get {
            lock.lock()
            defer { lock.unlock() }
            let raw = defaults.integer(forKey: Keys.hotkeyMode)
            return HotkeyMode(rawValue: raw) ?? .doubleCommandC
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            defaults.set(newValue.rawValue, forKey: Keys.hotkeyMode)
        }
    }
    
    public var hotkeyWindowMs: Double {
        get {
            lock.lock()
            defer { lock.unlock() }
            let val = defaults.double(forKey: Keys.hotkeyWindowMs)
            return val > 0 ? val : 400.0
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            defaults.set(newValue, forKey: Keys.hotkeyWindowMs)
        }
    }
    
    public var dismissOnOutsideClick: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let val = defaults.object(forKey: Keys.dismissOnOutsideClick) as? Bool else {
                return true
            }
            return val
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            defaults.set(newValue, forKey: Keys.dismissOnOutsideClick)
        }
    }
    
    public var enterKeyAction: EnterKeyAction {
        get {
            lock.lock()
            defer { lock.unlock() }
            let raw = defaults.integer(forKey: Keys.enterKeyAction)
            return EnterKeyAction(rawValue: raw) ?? .copyAndClose
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            defaults.set(newValue.rawValue, forKey: Keys.enterKeyAction)
        }
    }
    
    public var launchAtLogin: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return (defaults.object(forKey: Keys.launchAtLogin) as? Bool) ?? false
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            defaults.set(newValue, forKey: Keys.launchAtLogin)
        }
    }
    
    public var appLanguage: AppInterfaceLanguage {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let raw = defaults.string(forKey: Keys.appLanguage),
                  let val = AppInterfaceLanguage(rawValue: raw) else {
                return .system
            }
            return val
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            defaults.set(newValue.rawValue, forKey: Keys.appLanguage)
        }
    }
    
    // MARK: - Convenience Aliases
    
    public var fallbackTargetLanguage: String {
        get { fallbackLanguage }
        set { fallbackLanguage = newValue }
    }
    
    public var autoDismissOnBlur: Bool {
        get { dismissOnOutsideClick }
        set { dismissOnOutsideClick = newValue }
    }
    
    public var autoCopyOnEnter: Bool {
        get { enterKeyAction == .copyAndClose }
        set { enterKeyAction = newValue ? .copyAndClose : .copyOnly }
    }
    
    public var shortcutTimingWindow: TimeInterval {
        get { hotkeyWindowMs / 1000.0 }
        set { hotkeyWindowMs = newValue * 1000.0 }
    }
    
    public var replaceSelectionDirectly: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return defaults.bool(forKey: Keys.prefix + "replaceSelectionDirectly")
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            defaults.set(newValue, forKey: Keys.prefix + "replaceSelectionDirectly")
        }
    }
    
    public var languageRules: [String: String] {
        get {
            lock.lock()
            defer { lock.unlock() }
            if let dict = defaults.dictionary(forKey: Keys.prefix + "languageRules") as? [String: String], !dict.isEmpty {
                return dict
            }
            return [
                "uk": "en",
                "en": "uk",
                "ru": "en"
            ]
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            defaults.set(newValue, forKey: Keys.prefix + "languageRules")
        }
    }
    
    /// Resets all preference keys to defaults (useful for testing).
    public func resetToDefaults() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: Keys.primaryLanguage)
        defaults.removeObject(forKey: Keys.secondaryLanguage)
        defaults.removeObject(forKey: Keys.fallbackLanguage)
        defaults.removeObject(forKey: Keys.hotkeyMode)
        defaults.removeObject(forKey: Keys.hotkeyWindowMs)
        defaults.removeObject(forKey: Keys.dismissOnOutsideClick)
        defaults.removeObject(forKey: Keys.enterKeyAction)
        defaults.removeObject(forKey: Keys.launchAtLogin)
    }
}
