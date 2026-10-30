import Foundation

/// Service providing reliable cloud translation fallback when on-device models are not installed.
public final class CloudTranslationService: @unchecked Sendable {
    public static let shared = CloudTranslationService()
    
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Translates text via cloud API fallback with automatic HTML entity decoding.
    public func translate(
        text: String,
        from sourceLang: String,
        to targetLang: String
    ) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }
        
        let src = sourceLang.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let tgt = targetLang.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        var components = URLComponents(string: "https://api.mymemory.translated.net/get")
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "langpair", value: "\(src)|\(tgt)")
        ]
        
        guard let url = components?.url else {
            throw TranslationEngineError.systemError("Invalid translation URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 7.0
        request.setValue("MacTranslate/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw TranslationEngineError.systemError("Cloud translation server returned error")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationEngineError.systemError("Could not parse cloud translation response")
        }
        
        if let statusStr = json["responseStatus"] as? String, statusStr != "200" {
            throw TranslationEngineError.unsupportedLanguagePairing(source: sourceLang, target: targetLang)
        }
        if let statusInt = json["responseStatus"] as? Int, statusInt != 200 {
            throw TranslationEngineError.unsupportedLanguagePairing(source: sourceLang, target: targetLang)
        }
        
        guard let respData = json["responseData"] as? [String: Any],
              let rawTranslated = respData["translatedText"] as? String else {
            throw TranslationEngineError.systemError("Could not parse cloud translation response")
        }
        
        let upper = rawTranslated.uppercased()
        if upper.contains("INVALID SOURCE LANGUAGE") || upper.contains("INVALID TARGET LANGUAGE") || upper.contains("INVALID LANGUAGE") {
            throw TranslationEngineError.unsupportedLanguagePairing(source: sourceLang, target: targetLang)
        }
        
        return decodeHTMLEntities(rawTranslated)
    }
    
    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        return result
    }
}
