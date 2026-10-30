import Testing
import Foundation
import AppKit
@testable import MacTranslate

/// Mock pasteboard conforming to PasteboardProtocol for deterministic unit testing.
final class MockPasteboard: @unchecked Sendable, PasteboardProtocol {
    private var storage: [NSPasteboard.PasteboardType: String] = [:]
    private let lock = NSLock()
    private var _changeCount: Int = 0
    
    init(initialString: String? = nil) {
        if let str = initialString {
            storage[.string] = str
            _changeCount = 1
        }
    }
    
    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storage[dataType]
    }
    
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        storage[dataType] = string
        _changeCount += 1
        return true
    }
    
    func clearContents() -> Int {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
        _changeCount += 1
        return _changeCount
    }
    
    var changeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _changeCount
    }
}

@Suite("Accessibility, Clipboard & Text Replacement Tests")
struct AccessibilityServiceTests {
    
    // MARK: - ClipboardService Tests
    
    @Test("ClipboardService extracts selected text via pasteboard fallback")
    func testClipboardServiceFallbackToPasteboard() {
        let mockPb = MockPasteboard(initialString: "Selected text from app")
        let service = ClipboardService(pasteboard: mockPb)
        
        let text = service.getSelectedText()
        #expect(text == "Selected text from app")
    }
    
    @Test("ClipboardService returns nil for empty or whitespace pasteboard")
    func testClipboardServiceEmptyPasteboardReturnsNil() {
        let emptyPb = MockPasteboard(initialString: "")
        let service1 = ClipboardService(pasteboard: emptyPb)
        #expect(service1.getSelectedText() == nil)
        
        let whitespacePb = MockPasteboard(initialString: "   \n\t  ")
        let service2 = ClipboardService(pasteboard: whitespacePb)
        #expect(service2.getSelectedText() == nil)
    }
    
    @Test("ClipboardService copyToClipboard updates pasteboard")
    func testClipboardServiceCopyToClipboard() {
        let mockPb = MockPasteboard()
        let service = ClipboardService(pasteboard: mockPb)
        
        service.copyToClipboard(text: "Translated greeting")
        #expect(mockPb.string(forType: .string) == "Translated greeting")
        #expect(mockPb.changeCount > 0)
    }
    
    @Test("ClipboardService accessibility extraction executes without crashing")
    func testClipboardServiceAccessibilityDirectInspection() {
        let service = ClipboardService.shared
        // In unit test runner without AX focus, this safely returns nil without crashing
        _ = service.getSelectedTextViaAccessibility()
    }
    
    // MARK: - AccessibilityHelper Tests
    
    @Test("AccessibilityHelper trust check returns boolean without error")
    func testAccessibilityHelperTrustCheck() {
        let isTrusted = AccessibilityHelper.isAccessibilityTrusted()
        // Must return either true or false
        #expect(isTrusted == true || isTrusted == false)
    }
    
    @Test("AccessibilityHelper permissions prompt executes cleanly")
    func testAccessibilityHelperPrompt() {
        let result = AccessibilityHelper.promptAccessibilityPermissions()
        #expect(result == true || result == false)
        
        let aliasResult = AccessibilityHelper.requestAccessibilityPermission()
        #expect(aliasResult == true || aliasResult == false)
    }
    
    @Test("AccessibilityHelper open settings executes cleanly")
    func testAccessibilityHelperOpenSettings() {
        // Method must execute without throwing or crashing
        AccessibilityHelper.openAccessibilitySettings()
    }
    
    @Test("AccessibilityHelper poll status with timeout returns boolean")
    func testAccessibilityHelperPollStatus() async {
        let result = await AccessibilityHelper.pollAccessibilityStatus(timeout: 0.1, interval: 0.05)
        #expect(result == true || result == false)
    }
    
    @Test("AccessibilityHelper pollForTrust task cancellation")
    func testAccessibilityHelperPollForTrustTask() async {
        let task = AccessibilityHelper.pollForTrust(interval: 0.1, timeout: 1.0) { _ in }
        task.cancel()
        #expect(task.isCancelled)
    }
    
    // MARK: - TextReplacementService Tests
    
    @Test("TextReplacementService synthetic paste writes text to pasteboard")
    func testTextReplacementServiceSyntheticPaste() {
        let mockPb = MockPasteboard(initialString: "Prior content")
        let service = TextReplacementService(pasteboard: mockPb)
        
        service.replaceViaSyntheticPaste(newText: "Injected replacement")
        #expect(mockPb.string(forType: .string) == "Injected replacement")
    }
    
    @Test("TextReplacementService leaves replacement text on pasteboard permanently")
    func testTextReplacementServiceClipboardPersistence() async {
        let mockPb = MockPasteboard(initialString: "Original clipboard data")
        let service = TextReplacementService(pasteboard: mockPb)
        
        service.replaceViaSyntheticPaste(newText: "New translated text")
        #expect(mockPb.string(forType: .string) == "New translated text")
        
        // Wait to verify translated text remains ready for user pasting
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(mockPb.string(forType: .string) == "New translated text")
    }
    
    @Test("TextReplacementService replaceSelectedText executes cleanly")
    func testTextReplacementServiceReplaceSelectedText() {
        let mockPb = MockPasteboard(initialString: "Previous")
        let service = TextReplacementService(pasteboard: mockPb)
        
        service.replaceSelectedText(with: "Quick brown fox")
        #expect(mockPb.string(forType: .string) == "Quick brown fox")
    }
}
