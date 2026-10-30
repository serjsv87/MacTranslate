import Foundation
import AppKit
import CoreGraphics
import ApplicationServices

/// Service responsible for replacing selected text in active applications.
public final class TextReplacementService: @unchecked Sendable {
    public static let shared = TextReplacementService()
    
    private let pasteboard: PasteboardProtocol
    
    public init(pasteboard: PasteboardProtocol = NSPasteboard.general) {
        self.pasteboard = pasteboard
    }
    
    /// Conforms to PROJECT.md: func replaceSelectedText(with newText: String)
    public func replaceSelectedText(with newText: String) {
        let clean = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strategy 1: Attempt direct in-place mutation via Accessibility
        if replaceViaAccessibility(newText: clean) {
            return
        }
        
        // Strategy 2: Fallback to synthetic paste injection (⌘V)
        replaceViaSyntheticPaste(newText: clean)
    }
    
    /// Replaces active selection using AXUIElementSetAttributeValue.
    public func replaceViaAccessibility(newText: String) -> Bool {
        let clean = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AXIsProcessTrusted() else { return false }
        
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedAppRef
        ) == .success, let focusedApp = focusedAppRef else {
            return false
        }
        
        let appElement = unsafeDowncast(focusedApp, to: AXUIElement.self)
        var focusedElementRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        ) == .success, let focusedElement = focusedElementRef else {
            return false
        }
        
        let targetElement = unsafeDowncast(focusedElement, to: AXUIElement.self)
        let status = AXUIElementSetAttributeValue(
            targetElement,
            kAXSelectedTextAttribute as CFString,
            clean as CFTypeRef
        )
        return status == .success
    }
    
    /// Synthesizes ⌘V keypress. Leaves the translated text in the pasteboard permanently.
    public func replaceViaSyntheticPaste(newText: String) {
        let clean = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Put replacement text on pasteboard
        _ = pasteboard.clearContents()
        _ = pasteboard.setString(clean, forType: .string)
        
        // 2. Synthesize Command-V keypress
        postSyntheticPasteCommand()
    }
    
    /// Posts virtual keycode 0x09 ('V') with Command flag to event taps and target process.
    public func postSyntheticPasteCommand(targetApp: NSRunningApplication? = nil) {
        let vKeyCode: CGKeyCode = 0x09   // 'V'
        
        // Use nil event source to bind to the current active session without SkyLight mutex deadlock
        let vDown = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false)
        
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        
        // 1. Post to system-wide HID event tap (delivers directly to frontmost focused control)
        vDown?.post(tap: .cghidEventTap)
        usleep(35000) // 35ms hold time
        vUp?.post(tap: .cghidEventTap)
        
        // 2. Also post directly to target app PID if available as a targeted backup
        if let pid = targetApp?.processIdentifier, pid != ProcessInfo.processInfo.processIdentifier {
            vDown?.postToPid(pid)
            usleep(20000)
            vUp?.postToPid(pid)
        }
    }
}
