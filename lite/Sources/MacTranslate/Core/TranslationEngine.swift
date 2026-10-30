import Foundation
import Translation

public struct TranslationResult: Sendable, Equatable {
    public let text: String
    public let isCloudFallback: Bool
    
    public init(text: String, isCloudFallback: Bool) {
        self.text = text
        self.isCloudFallback = isCloudFallback
    }
}

public enum TranslationEngineError: Error, LocalizedError, Equatable, Sendable {
    case notInstalled(source: String, target: String)
    case unsupportedLanguagePairing(source: String, target: String)
    case unsupportedLanguage(String)
    case nothingToTranslate
    case systemError(String)
    
    public var errorDescription: String? {
        switch self {
        case .notInstalled(let s, let t):
            return "Translation model for \(s) -> \(t) is not installed on-device. Please download it in System Settings."
        case .unsupportedLanguagePairing(let s, let t):
            return "Translation pairing \(s) -> \(t) is unsupported."
        case .unsupportedLanguage(let lang):
            return "Language \(lang) is not supported."
        case .nothingToTranslate:
            return "No text provided to translate."
        case .systemError(let msg):
            return "Translation error: \(msg)"
        }
    }
}

public final class TranslationEngine: @unchecked Sendable {
    public static let shared = TranslationEngine()
    
    private let availability = LanguageAvailability()
    private let lock = NSLock()
    
    // In-memory cache of TranslationSession keyed by "\(source)->\(target)"
    private var sessionCache: [String: Any] = [:]
    // Access order tracking for true LRU eviction of sessionCache (oldest at index 0, most recent at end)
    private var sessionAccessOrder: [String] = []
    // In-memory cache of model installation status
    private var installedCache: [String: Bool] = [:]
    
    public init() {
        // Cache starts empty — no hardcoded test values.
        // Asynchronously prefetch common models in background to warm cache.
        Task { [weak self] in
            await self?.prefetchCommonModels()
        }
    }
    
    // MARK: - Synchronous Lock-Protected Cache Accessors (Swift 6 Safe)
    
    private func getCachedSession(for key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        guard let session = sessionCache[key] else {
            return nil
        }
        // Move key to the end of sessionAccessOrder (most recently used)
        if let idx = sessionAccessOrder.firstIndex(of: key) {
            sessionAccessOrder.remove(at: idx)
        }
        sessionAccessOrder.append(key)
        return session
    }
    
    private func cacheSession(_ session: Any, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        // True LRU eviction cap to prevent unbounded session cache growth (max 16)
        if sessionCache[key] == nil {
            if sessionCache.count >= 16 {
                if !sessionAccessOrder.isEmpty {
                    let oldestKey = sessionAccessOrder.removeFirst()
                    sessionCache.removeValue(forKey: oldestKey)
                } else if let firstKey = sessionCache.keys.first {
                    sessionCache.removeValue(forKey: firstKey)
                }
            }
            sessionAccessOrder.append(key)
        } else {
            // Key already exists; update recency by moving to end
            if let idx = sessionAccessOrder.firstIndex(of: key) {
                sessionAccessOrder.remove(at: idx)
            }
            sessionAccessOrder.append(key)
        }
        sessionCache[key] = session
    }
    
    private func getCachedStatus(for key: String) -> Bool? {
        lock.lock()
        defer { lock.unlock() }
        return installedCache[key]
    }
    
    private func cacheStatus(_ installed: Bool, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        installedCache[key] = installed
    }
    
    // MARK: - Model Availability Checking
    
    private final class StatusBox: @unchecked Sendable {
        private var _done = false
        private var _status: LanguageAvailability.Status?
        private let condition = NSCondition()
        
        func finish(_ s: LanguageAvailability.Status) {
            condition.lock()
            _status = s
            _done = true
            condition.broadcast()
            condition.unlock()
        }
        
        var isDone: Bool {
            condition.lock()
            defer { condition.unlock() }
            return _done
        }
        
        var status: LanguageAvailability.Status? {
            condition.lock()
            defer { condition.unlock() }
            return _status
        }
        
        func waitForResult(deadline: Date) {
            if Thread.isMainThread {
                while !isDone && Date() < deadline {
                    RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
                }
            } else {
                condition.lock()
                while !_done && Date() < deadline {
                    let remaining = deadline.timeIntervalSinceNow
                    if remaining <= 0 { break }
                    _ = condition.wait(until: Date(timeIntervalSinceNow: min(0.01, remaining)))
                }
                condition.unlock()
            }
        }
    }
    
    /// Synchronously checks if model for pair is installed. Conforms to PROJECT.md interface contract.
    public func isModelInstalled(from sourceLang: String, to targetLang: String) -> Bool {
        let s = sourceLang.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let t = targetLang.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty, !t.isEmpty else {
            return false
        }
        
        let key = "\(s)->\(t)"
        if let cached = getCachedStatus(for: key) {
            return cached
        }
        
        let src = Locale.Language(identifier: s)
        let tgt = Locale.Language(identifier: t)
        let box = StatusBox()
        let avail = self.availability
        
        // Dispatch query with elevated priority so it is promptly scheduled by the cooperative pool
        Task.detached(priority: .userInitiated) {
            let status = await avail.status(from: src, to: tgt)
            box.finish(status)
        }
        
        let deadline = Date().addingTimeInterval(1.0)
        box.waitForResult(deadline: deadline)
        
        if box.isDone, let status = box.status {
            let installed = (status == .installed)
            cacheStatus(installed, for: key)
            return installed
        }
        
        // Timeout or unresolvable: do not permanently poison cache with false
        return false
    }
    
    /// Asynchronously queries LanguageAvailability and updates cache.
    public func checkModelInstalled(from sourceLang: String, to targetLang: String) async -> Bool {
        let s = sourceLang.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let t = targetLang.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty, !t.isEmpty else {
            return false
        }
        
        let key = "\(s)->\(t)"
        let src = Locale.Language(identifier: s)
        let tgt = Locale.Language(identifier: t)
        let status = await availability.status(from: src, to: tgt)
        let installed = (status == .installed)
        cacheStatus(installed, for: key)
        return installed
    }
    
    /// Asynchronously prefetches availability status for common high-frequency language pairs.
    public func prefetchCommonModels() async {
        let common = ["en", "uk", "es", "it", "ru", "fr", "de", "zh", "ja"]
        for src in common {
            for tgt in common where src != tgt {
                _ = await checkModelInstalled(from: src, to: tgt)
            }
        }
    }
    
    // MARK: - Translation Execution
    
    /// Translates text on Apple Neural Engine via cached TranslationSession with seamless cloud fallback.
    public func translate(
        text: String,
        from sourceLang: String,
        to targetLang: String
    ) async throws -> String {
        let result = try await translateWithInfo(text: text, from: sourceLang, to: targetLang)
        return result.text
    }
    
    /// Translates text and returns metadata indicating whether it was processed on Apple Neural Engine or via Cloud.
    public func translateWithInfo(
        text: String,
        from sourceLang: String,
        to targetLang: String
    ) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranslationEngineError.nothingToTranslate
        }
        
        let s = sourceLang.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let t = targetLang.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty, !t.isEmpty else {
            throw TranslationEngineError.unsupportedLanguagePairing(source: sourceLang, target: targetLang)
        }
        
        // Identity translation optimization
        if s == t {
            return TranslationResult(text: text, isCloudFallback: false)
        }
        
        // 1. Attempt on-device Apple Neural Engine translation
        #if compiler(>=6.4)
        if #available(macOS 26.0, *) {
            let key = "\(s)->\(t)"
            do {
                let session: TranslationSession
                if let cached = getCachedSession(for: key) as? TranslationSession {
                    session = cached
                } else {
                    let src = Locale.Language(identifier: s)
                    let tgt = Locale.Language(identifier: t)
                    let newSession = TranslationSession(installedSource: src, target: tgt)
                    try await newSession.prepareTranslation()
                    cacheSession(newSession, for: key)
                    session = newSession
                }
                
                let response = try await session.translate(trimmed)
                return TranslationResult(text: response.targetText, isCloudFallback: false)
            } catch {
                // Fall through to cloud translation
            }
        }
        #endif
        
        // 2. Cloud Fallback when offline model is not installed
        do {
            let cloudResult = try await CloudTranslationService.shared.translate(
                text: trimmed,
                from: s,
                to: t
            )
            return TranslationResult(text: cloudResult, isCloudFallback: true)
        } catch {
            throw TranslationEngineError.notInstalled(source: s, target: t)
        }
    }
}
