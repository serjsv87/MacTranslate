import Foundation
import AppKit
import ApplicationServices

/// Protocol abstraction over NSPasteboard to allow unit testing with mock pasteboards.
public protocol PasteboardProtocol: AnyObject, Sendable {
    func string(forType dataType: NSPasteboard.PasteboardType) -> String?
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool
    func clearContents() -> Int
    var changeCount: Int { get }
}

extension NSPasteboard: @retroactive @unchecked Sendable {}
extension NSPasteboard: PasteboardProtocol {}

/// Service responsible for clipboard interactions and extracting selected text.
public final class ClipboardService: @unchecked Sendable {
    public static let shared = ClipboardService()
    
    private let pasteboard: PasteboardProtocol
    
    public init(pasteboard: PasteboardProtocol = NSPasteboard.general) {
        self.pasteboard = pasteboard
    }
    
    /// Conforms to PROJECT.md: func getSelectedText() -> String?
    public func getSelectedText() -> String? {
        // Method 1: AXUIElement inspection
        if let axText = getSelectedTextViaAccessibility(), !axText.isEmpty {
            return axText
        }
        
        // Method 2: Fallback to NSPasteboard.general
        if let pbText = pasteboard.string(forType: .string) {
            let trimmed = pbText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return pbText
            }
        }
        
        return nil
    }
    
    /// Conforms to PROJECT.md: func copyToClipboard(text: String)
    public func copyToClipboard(text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = pasteboard.clearContents()
        _ = pasteboard.setString(clean, forType: .string)
    }
    
    public func getClipboardText() -> String? {
        return getSelectedText()
    }
    
    public func extractSelectedText() -> String? {
        return getSelectedTextViaAccessibility() ?? getSelectedText()
    }
    
    /// Direct inspection of focused UI element selected text via Accessibility API.
    public func getSelectedTextViaAccessibility() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppRef: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedAppRef
        )
        guard appResult == .success, let focusedApp = focusedAppRef else {
            return nil
        }
        
        let appElement = unsafeDowncast(focusedApp, to: AXUIElement.self)
        var focusedElementRef: CFTypeRef?
        let elemResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )
        guard elemResult == .success, let focusedElement = focusedElementRef else {
            return nil
        }
        
        let targetElement = unsafeDowncast(focusedElement, to: AXUIElement.self)
        var selectedTextRef: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            targetElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextRef
        )
        guard textResult == .success, let text = selectedTextRef as? String else {
            return nil
        }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : text
    }
}
