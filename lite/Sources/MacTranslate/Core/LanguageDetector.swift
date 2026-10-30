import Foundation
import NaturalLanguage

public final class LanguageDetector: @unchecked Sendable {
    public static let shared = LanguageDetector()
    
    public static let supportedLanguages: [String] = [
        "ar", "de", "en", "es", "fr", "hi", "id", "it",
        "ja", "ko", "nl", "pl", "pt", "ru", "th", "tr",
        "uk", "vi", "zh"
    ]
    
    private let supportedSet: Set<String>
    private let languageConstraints: [NLLanguage]
    
    public init() {
        self.supportedSet = Set(Self.supportedLanguages)
        var constraints: [NLLanguage] = []
        for code in Self.supportedLanguages {
            if code == "zh" {
                constraints.append(contentsOf: [.simplifiedChinese, .traditionalChinese])
            } else {
                constraints.append(NLLanguage(code))
            }
        }
        self.languageConstraints = constraints
    }
    
    /// Detects the dominant language in text using constrained NLLanguageRecognizer.
    /// Returns BCP-47 base code (e.g., "en", "uk") or nil if input is empty, whitespace, numbers, or symbols.
    public func detectLanguage(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.contains(where: { $0.isLetter }) else { return nil }
        
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = self.languageConstraints
        recognizer.processString(trimmed)
        
        guard let dominant = recognizer.dominantLanguage else { return nil }
        let raw = dominant.rawValue
        guard raw != "und" else { return nil }
        
        // Map Chinese script variants (zh-Hans, zh-Hant) back to base code "zh"
        if raw == "zh-Hans" || raw == "zh-Hant" || dominant == .simplifiedChinese || dominant == .traditionalChinese {
            return "zh"
        }
        
        let baseCode = raw.components(separatedBy: "-").first?.lowercased() ?? raw.lowercased()
        return supportedSet.contains(baseCode) ? baseCode : nil
    }
    
    /// Returns the localized display name of the language code in the user's current locale.
    public func localizedName(for languageCode: String, locale: Locale? = nil) -> String {
        let clean = languageCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return "" }
        let targetLocale = locale ?? LocalizationManager.shared.currentLocale
        if let name = targetLocale.localizedString(forLanguageCode: clean), name.lowercased() != clean {
            return name.prefix(1).uppercased() + name.dropFirst()
        }
        return languageCode.uppercased()
    }
    
    /// Returns the country flag emoji corresponding to the language code.
    public func flagEmoji(for languageCode: String) -> String {
        let clean = languageCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let baseCode = clean.components(separatedBy: "-").first ?? clean
        
        let countryMapping: [String: String] = [
            "en": "GB", "uk": "UA", "ru": "RU", "de": "DE", "pl": "PL",
            "fr": "FR", "es": "ES", "it": "IT", "nl": "NL", "pt": "PT",
            "zh": "CN", "ja": "JP", "ko": "KR", "ar": "SA", "hi": "IN",
            "id": "ID", "th": "TH", "tr": "TR", "vi": "VN"
        ]
        
        guard let country = countryMapping[baseCode] else {
            return "🌐"
        }
        
        let base: UInt32 = 127397
        var flag = ""
        for scalar in country.uppercased().unicodeScalars {
            if let indicator = UnicodeScalar(base + scalar.value) {
                flag.unicodeScalars.append(indicator)
            }
        }
        return flag.isEmpty ? "🌐" : flag
    }
}
