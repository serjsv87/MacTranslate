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
    public func replaceSelectedText(with newText: String, targetApp: NSRunningApplication? = nil) {
        let clean = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strategy 1: Attempt direct in-place mutation via Accessibility
        if replaceViaAccessibility(newText: clean) {
            return
        }
        
        // Strategy 2: Fallback to synthetic paste injection (⌘V / ⌃V)
        replaceViaSyntheticPaste(newText: clean, targetApp: targetApp)
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
        
        var isSettable: DarwinBoolean = false
        let settableStatus = AXUIElementIsAttributeSettable(
            targetElement,
            kAXSelectedTextAttribute as CFString,
            &isSettable
        )
        guard settableStatus == .success, isSettable.boolValue else {
            return false
        }
        
        let status = AXUIElementSetAttributeValue(
            targetElement,
            kAXSelectedTextAttribute as CFString,
            clean as CFTypeRef
        )
        return status == .success
    }
    
    /// Synthesizes ⌘V keypress. Leaves the translated text in the pasteboard permanently.
    public func replaceViaSyntheticPaste(newText: String, targetApp: NSRunningApplication? = nil) {
        let clean = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Put replacement text on pasteboard
        _ = pasteboard.clearContents()
        _ = pasteboard.setString(clean, forType: .string)
        
        // 2. Synthesize Command-V keypress sequence
        postSyntheticPasteCommand(targetApp: targetApp)
    }
    
    /// Posts virtual keycode 0x09 ('V') with Command modifier to event taps and target process.
    public func postSyntheticPasteCommand(targetApp: NSRunningApplication? = nil) {
        let vKeyCode: CGKeyCode = 0x09   // 'V'
        let cmdKeyCode: CGKeyCode = 0x37 // '⌘' (Command)
        
        let src = CGEventSource(stateID: .combinedSessionState)
        
        // 1. Synthesize Command key down
        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: cmdKeyCode, keyDown: true)
        cmdDown?.flags = .maskCommand
        
        // 2. Synthesize 'V' key down with Command flag
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true)
        vDown?.flags = .maskCommand
        
        // 3. Synthesize 'V' key up with Command flag
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false)
        vUp?.flags = .maskCommand
        
        // 4. Synthesize Command key up
        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: cmdKeyCode, keyDown: false)
        cmdUp?.flags = []
        
        // Post EXACTLY ONCE to avoid duplicate pasting:
        // If targetApp PID is specified, dispatch directly to target process; otherwise to active session.
        if let pid = targetApp?.processIdentifier, pid != ProcessInfo.processInfo.processIdentifier {
            cmdDown?.postToPid(pid)
            vDown?.postToPid(pid)
            usleep(25000)
            vUp?.postToPid(pid)
            cmdUp?.postToPid(pid)
        } else {
            cmdDown?.post(tap: .cgAnnotatedSessionEventTap)
            vDown?.post(tap: .cgAnnotatedSessionEventTap)
            usleep(25000)
            vUp?.post(tap: .cgAnnotatedSessionEventTap)
            cmdUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
