import Foundation
import AppKit
import ApplicationServices

/// Helper utility for verifying, requesting, and polling macOS Accessibility permissions.
public enum AccessibilityHelper {
    
    /// Conforms to PROJECT.md: static func isAccessibilityTrusted() -> Bool
    public static func isAccessibilityTrusted() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// Prompts system dialog requesting Accessibility permissions for the process.
    @discardableResult
    public static func promptAccessibilityPermissions() -> Bool {
        if isAccessibilityTrusted() { return true }
        
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    /// Alias for promptAccessibilityPermissions
    @discardableResult
    public static func requestAccessibilityPermission() -> Bool {
        return promptAccessibilityPermissions()
    }
    
    /// Conforms to PROJECT.md: static func openAccessibilitySettings()
    /// Deep-links to macOS System Settings Privacy & Security -> Accessibility
    public static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            if NSWorkspace.shared.open(url) {
                return
            }
        }
        if let fallbackUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(fallbackUrl)
        }
    }
    
    /// Checks whether macOS Screen Recording permission is granted.
    public static func isScreenRecordingTrusted() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }
    
    /// Deep-links to macOS System Settings Privacy & Security -> Screen Recording
    public static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            if NSWorkspace.shared.open(url) {
                return
            }
        }
        if let fallbackUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(fallbackUrl)
        }
    }
    
    /// Asynchronously polls Accessibility trust status until granted or timeout occurs.
    @discardableResult
    public static func pollAccessibilityStatus(
        timeout: TimeInterval = 60.0,
        interval: TimeInterval = 0.5
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isAccessibilityTrusted() {
                return true
            }
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        return isAccessibilityTrusted()
    }
    
    /// Polls AXIsProcessTrusted periodically until granted or cancelled, notifying on the main actor.
    public static func pollForTrust(
        interval: TimeInterval = 1.0,
        timeout: TimeInterval = 60.0,
        onChange: @escaping @Sendable (Bool) -> Void
    ) -> Task<Void, Never> {
        return Task {
            var elapsed: TimeInterval = 0
            var lastState = isAccessibilityTrusted()
            
            while !Task.isCancelled && elapsed < timeout {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                elapsed += interval
                
                let currentState = isAccessibilityTrusted()
                if currentState != lastState {
                    lastState = currentState
                    await MainActor.run {
                        onChange(currentState)
                    }
                    if currentState { break }
                }
            }
        }
    }
}
