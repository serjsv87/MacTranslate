import Foundation

public struct LanguagePairRouter: Sendable {
    public let primary: String
    public let secondary: String
    public let fallback: String
    public let customRules: [String: String]
    
    public init(
        primary: String = "uk",
        secondary: String = "en",
        fallback: String = "en",
        customRules: [String: String] = [:]
    ) {
        self.primary = primary
        self.secondary = secondary
        self.fallback = fallback
        self.customRules = customRules
    }
    
    /// Resolves target language pair from detected language and preference configuration.
    /// Conforms to PROJECT.md interface contract.
    public static func resolveTargetLanguage(
        for detectedLang: String?,
        primary: String,
        secondary: String,
        fallback: String
    ) -> (source: String, target: String) {
        let p = primary.lowercased()
        let s = secondary.lowercased()
        let f = fallback.lowercased()
        
        guard let rawDetected = detectedLang?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawDetected.isEmpty else {
            // Default when detection fails: secondary -> primary
            return (source: s, target: p)
        }
        
        let detected = rawDetected.lowercased()
        
        if detected == p {
            return (source: p, target: s)
        } else if detected == s {
            return (source: s, target: p)
        } else {
            // Third language -> fallback target, avoiding source == target
            let target = (detected == f) ? p : f
            return (source: detected, target: target)
        }
    }
    
    public func resolveTargetLanguage(
        for detectedLang: String?,
        primary: String,
        secondary: String,
        fallback: String
    ) -> (source: String, target: String) {
        Self.resolveTargetLanguage(for: detectedLang, primary: primary, secondary: secondary, fallback: fallback)
    }
    
    public func route(detectedLanguage: String?) -> (source: String, target: String) {
        guard let rawDetected = detectedLanguage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawDetected.isEmpty else {
            return (source: secondary, target: customRules[secondary] ?? primary)
        }
        
        let detected = rawDetected.lowercased()
        
        // 1. Check custom user routing rules first
        if let target = customRules[detected] {
            return (source: detected, target: target)
        }
        
        // 2. Standard pair routing fallback
        let p = primary.lowercased()
        let s = secondary.lowercased()
        let f = fallback.lowercased()
        
        if detected == p {
            return (source: p, target: s)
        } else if detected == s {
            return (source: s, target: p)
        } else {
            let target = (detected == f) ? p : f
            return (source: detected, target: target)
        }
    }
    
    public static var shared: LanguagePairRouter {
        let prefs = PreferencesManager.shared
        return LanguagePairRouter(
            primary: prefs.primaryLanguage,
            secondary: prefs.secondaryLanguage,
            fallback: prefs.fallbackLanguage,
            customRules: prefs.languageRules
        )
    }
    
    public func resolveTargetLanguage(detectedLanguage: String?) -> String {
        return route(detectedLanguage: detectedLanguage).target
    }
}
