import AppKit
import Foundation
import AVFoundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, HUDContentViewDelegate, StatusBarControllerDelegate, FloatingHUDPanelDelegate {
    private var statusBarController: StatusBarController!
    private var floatingHUDPanel: FloatingHUDPanel!
    private var speechSynthesizer: AVSpeechSynthesizer?
    
    // Active translation context
    private var currentSourceText: String = ""
    private var currentDetectedLanguage: String? = nil
    private var currentSelectedSource: String? = nil
    private var currentSelectedTarget: String = "en"
    private var activeTranslationTask: Task<Void, Never>? = nil
    private var previousActiveApp: NSRunningApplication? = nil
    private var lastActiveExternalApp: NSRunningApplication? = nil
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as background agent without Dock icon
        NSApp.setActivationPolicy(.accessory)
        
        setupComponents()
        setupHotkeys()
        
        // Check for updates on startup (at most once every 24h, or on explicit request)
        UpdateChecker.shared.checkForUpdates()
        setupAppFocusTracking()
    }
    
    private func setupAppFocusTracking() {
        // Track the frontmost third-party application so we can reliably refocus it on Cmd+V paste
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self else { return }
            if let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app != NSRunningApplication.current {
                Task { @MainActor [weak self] in
                    self?.lastActiveExternalApp = app
                    self?.previousActiveApp = app
                }
            }
        }
    }
    
    private func setupComponents() {
        floatingHUDPanel = FloatingHUDPanel()
        floatingHUDPanel.hudContentView.delegate = self
        floatingHUDPanel.panelDelegate = self
        
        statusBarController = StatusBarController()
        statusBarController.delegate = self
        
        speechSynthesizer = AVSpeechSynthesizer()
    }
    
    private func setupHotkeys() {
        let prefs = PreferencesManager.shared
        let hotkeyManager = HotkeyManager.shared
        
        hotkeyManager.setMode(prefs.hotkeyMode)
        hotkeyManager.setTimingWindow(prefs.shortcutTimingWindow)
        
        hotkeyManager.onDetailedTrigger = { [weak self] trigger in
            Task { @MainActor [weak self] in
                self?.handleHotkeyTrigger(trigger)
            }
        }
        
        hotkeyManager.start()
    }
    
    // MARK: - Translation Trigger Workflow
    
    private func handleHotkeyTrigger(_ trigger: HotkeyTriggerType) {
        if let currentFront = NSWorkspace.shared.frontmostApplication,
           currentFront != NSRunningApplication.current {
            previousActiveApp = currentFront
        }
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount
        
        // If trigger is doubleControlC or alternate, simulate Cmd+C to copy selected text
        if trigger == .doubleControlC || trigger == .alternate {
            simulateCommandC()
        }
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // Poll for up to 250ms (12 x 20ms) for the active application to finish copying
            for _ in 0..<12 {
                try? await Task.sleep(nanoseconds: 20_000_000)
                if pasteboard.changeCount != initialChangeCount {
                    break
                }
            }
            
            var text = ClipboardService.shared.getClipboardText()
            if text == nil || text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                text = ClipboardService.shared.extractSelectedText()
            }
            
            if let validText = text?.trimmingCharacters(in: .whitespacesAndNewlines), !validText.isEmpty {
                self.startTranslation(for: validText)
            } else {
                // If nothing was selected, open empty HUD so user can type directly
                self.showEmptyHUD()
            }
        }
    }
    
    private func simulateCommandC() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 8, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 8, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    public func showEmptyHUD() {
        currentSourceText = ""
        currentDetectedLanguage = nil
        currentSelectedSource = nil
        currentSelectedTarget = PreferencesManager.shared.secondaryLanguage
        
        floatingHUDPanel.hudContentView.update(
            sourceText: "",
            targetText: "",
            detectedLanguage: nil,
            selectedSourceLanguage: nil,
            selectedTargetLanguage: currentSelectedTarget,
            statusMessage: L10n("hud.type_prompt")
        )
        floatingHUDPanel.showNearCursor()
        floatingHUDPanel.hudContentView.focusSourceText()
    }
    
    public func startTranslation(for text: String) {
        currentSourceText = text
        
        // 1. Detect language
        let detected = LanguageDetector.shared.detectLanguage(in: text)
        currentDetectedLanguage = detected
        currentSelectedSource = nil // default to Auto
        
        // 2. Resolve default target language via smart pairing
        let target = LanguagePairRouter.shared.resolveTargetLanguage(detectedLanguage: detected)
        currentSelectedTarget = target
        
        // 3. Show HUD immediately near cursor with loading state
        floatingHUDPanel.hudContentView.update(
            sourceText: text,
            targetText: L10n("hud.translating"),
            detectedLanguage: detected,
            selectedSourceLanguage: nil,
            selectedTargetLanguage: target,
            statusMessage: L10n("hud.inference")
        )
        floatingHUDPanel.showNearCursor()
        
        // 4. Perform translation
        executeTranslation(sourceText: text, from: detected ?? "en", to: target)
    }
    
    private func executeTranslation(sourceText: String, from sourceLang: String, to targetLang: String) {
        activeTranslationTask?.cancel()
        
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            floatingHUDPanel.hudContentView.update(
                sourceText: "",
                targetText: "",
                detectedLanguage: currentDetectedLanguage,
                selectedSourceLanguage: currentSelectedSource,
                selectedTargetLanguage: targetLang,
                statusMessage: L10n("hud.ane_offline")
            )
            return
        }
        
        floatingHUDPanel.hudContentView.setTranslatingState(isLoading: true)
        
        activeTranslationTask = Task { @MainActor in
            do {
                let result = try await TranslationEngine.shared.translateWithInfo(
                    text: trimmed,
                    from: sourceLang,
                    to: targetLang
                )
                
                guard !Task.isCancelled else { return }
                
                floatingHUDPanel.hudContentView.update(
                    sourceText: sourceText,
                    targetText: result.text,
                    detectedLanguage: currentDetectedLanguage,
                    selectedSourceLanguage: currentSelectedSource,
                    selectedTargetLanguage: targetLang,
                    isCloudFallback: result.isCloudFallback
                )
                floatingHUDPanel.hudContentView.setTranslatingState(isLoading: false)
            } catch {
                guard !Task.isCancelled else { return }
                floatingHUDPanel.hudContentView.update(
                    sourceText: sourceText,
                    targetText: "Translation error: \(error.localizedDescription)",
                    detectedLanguage: currentDetectedLanguage,
                    selectedSourceLanguage: currentSelectedSource,
                    selectedTargetLanguage: targetLang,
                    statusMessage: "⚠️ Error"
                )
                floatingHUDPanel.hudContentView.setTranslatingState(isLoading: false)
            }
        }
    }
    
    // MARK: - HUDContentViewDelegate
    
    func hudContentViewDidRequestClose(_ view: HUDContentView) {
        floatingHUDPanel.dismiss()
    }
    
    func hudContentViewDidRequestCopy(_ view: HUDContentView, text: String) {
        ClipboardService.shared.copyToClipboard(text: text)
        
        if PreferencesManager.shared.autoCopyOnEnter {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.floatingHUDPanel.dismiss()
            }
        }
    }
    
    func hudContentViewDidRequestReplace(_ view: HUDContentView, text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        
        // 1. Copy translation to pasteboard first so it is immediately ready and stays there!
        ClipboardService.shared.copyToClipboard(text: cleanText)
        
        // 2. Prevent HotkeyManager's clipboard monitor from detecting our paste as a double-copy
        HotkeyManager.shared.temporarilyIgnoreClipboard(duration: 2.0)
        
        let appToRestore = previousActiveApp ?? lastActiveExternalApp ?? NSWorkspace.shared.frontmostApplication
        
        // 3. Hide HUD panel
        floatingHUDPanel.dismiss()
        
        Task { @MainActor in
            if let app = appToRestore, app != NSRunningApplication.current {
                if #available(macOS 14.0, *) {
                    NSApp.yieldActivation(to: app)
                }
                app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            }
            // Allow macOS window manager 180ms to refocus the text input target
            try? await Task.sleep(nanoseconds: 180_000_000)
            
            // 4. Perform direct replacement or synthetic paste (translation remains in clipboard)
            TextReplacementService.shared.replaceSelectedText(with: cleanText, targetApp: appToRestore)
        }
    }
    
    func hudContentViewDidRequestSpeak(_ view: HUDContentView, text: String, languageCode: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        speechSynthesizer?.stopSpeaking(at: .immediate)
        speechSynthesizer?.speak(utterance)
    }
    
    func hudContentViewDidRequestOpenSettings(_ view: HUDContentView) {
        SettingsWindowController.shared.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hudContentViewDidChangeSourceLanguage(_ view: HUDContentView, newLanguage: String?) {
        currentSelectedSource = newLanguage
        let effectiveSource = newLanguage ?? currentDetectedLanguage ?? "en"
        executeTranslation(sourceText: currentSourceText, from: effectiveSource, to: currentSelectedTarget)
    }
    
    func hudContentViewDidChangeTargetLanguage(_ view: HUDContentView, newLanguage: String) {
        currentSelectedTarget = newLanguage
        let effectiveSource = currentSelectedSource ?? currentDetectedLanguage ?? "en"
        executeTranslation(sourceText: currentSourceText, from: effectiveSource, to: newLanguage)
    }
    
    func hudContentViewDidRequestSwap(_ view: HUDContentView) {
        let oldSource = currentSelectedSource ?? currentDetectedLanguage ?? "en"
        let oldTarget = currentSelectedTarget
        
        currentSelectedSource = oldTarget
        currentSelectedTarget = oldSource
        
        executeTranslation(sourceText: currentSourceText, from: oldTarget, to: oldSource)
    }
    
    func hudContentViewDidEditSourceText(_ view: HUDContentView, newText: String) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            floatingHUDPanel.hudContentView.update(
                sourceText: "",
                targetText: "",
                detectedLanguage: nil,
                selectedSourceLanguage: currentSelectedSource,
                selectedTargetLanguage: currentSelectedTarget,
                statusMessage: "Введіть текст для перекладу"
            )
            return
        }
        
        currentSourceText = newText
        
        // Auto re-detect language when user types or edits
        let detected = LanguageDetector.shared.detectLanguage(in: trimmed)
        currentDetectedLanguage = detected
        
        // If user hasn't explicitly locked source, update target via smart routing
        if currentSelectedSource == nil {
            let target = LanguagePairRouter.shared.resolveTargetLanguage(detectedLanguage: detected)
            currentSelectedTarget = target
        }
        
        let effectiveSource = currentSelectedSource ?? detected ?? "en"
        executeTranslation(sourceText: newText, from: effectiveSource, to: currentSelectedTarget)
    }
    
    // MARK: - StatusBarControllerDelegate
    
    func statusBarControllerDidRequestTranslateClipboard(_ controller: StatusBarController) {
        if let text = ClipboardService.shared.getClipboardText(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            startTranslation(for: text)
        } else {
            showEmptyHUD()
        }
    }
    
    func statusBarControllerDidRequestOpenSettings(_ controller: StatusBarController) {
        SettingsWindowController.shared.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func statusBarControllerDidChangeLanguagePair(_ controller: StatusBarController, primary: String, secondary: String) {
        // If HUD is currently showing, re-resolve and update
        if floatingHUDPanel.isVisible {
            let target = LanguagePairRouter.shared.resolveTargetLanguage(detectedLanguage: currentDetectedLanguage)
            currentSelectedTarget = target
            let effectiveSource = currentSelectedSource ?? currentDetectedLanguage ?? "en"
            executeTranslation(sourceText: currentSourceText, from: effectiveSource, to: target)
        }
    }
    
    // MARK: - FloatingHUDPanelDelegate
    
    func floatingHUDPanelDidDismiss(_ panel: FloatingHUDPanel) {
        activeTranslationTask?.cancel()
        speechSynthesizer?.stopSpeaking(at: .immediate)
    }
}

// MARK: - Application Entry Point

@main
enum MacTranslateMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
