import AppKit
import Foundation

@MainActor
public protocol HUDContentViewDelegate: AnyObject, Sendable {
    func hudContentViewDidRequestClose(_ view: HUDContentView)
    func hudContentViewDidRequestCopy(_ view: HUDContentView, text: String)
    func hudContentViewDidRequestReplace(_ view: HUDContentView, text: String)
    func hudContentViewDidRequestSpeak(_ view: HUDContentView, text: String, languageCode: String)
    func hudContentViewDidRequestOpenSettings(_ view: HUDContentView)
    func hudContentViewDidChangeSourceLanguage(_ view: HUDContentView, newLanguage: String?)
    func hudContentViewDidChangeTargetLanguage(_ view: HUDContentView, newLanguage: String)
    func hudContentViewDidRequestSwap(_ view: HUDContentView)
    func hudContentViewDidEditSourceText(_ view: HUDContentView, newText: String)
}

final class SourceTextView: NSTextView {
    var onCommandEnter: (() -> Void)?
    var onCommandV: (() -> Bool)?
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 36 && event.modifierFlags.contains(.command) {
            onCommandEnter?()
            return true
        }
        let isVKey = (event.keyCode == 9)
        let hasCmd = event.modifierFlags.contains(.command)
        let hasCtrl = event.modifierFlags.contains(.control)
        if isVKey && (hasCmd || hasCtrl) {
            if let handled = onCommandV?(), handled {
                return true
            }
            if hasCtrl {
                self.paste(nil)
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 && event.modifierFlags.contains(.command) {
            onCommandEnter?()
            return
        }
        super.keyDown(with: event)
    }
}

/// The interactive content view inside the Floating HUD Panel.
@MainActor
public final class HUDContentView: NSView {
    public weak var delegate: HUDContentViewDelegate?
    
    // UI Elements
    private let visualEffectView = NSVisualEffectView()
    private let sourcePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let swapButton = NSButton()
    private let targetPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let closeButton = NSButton()
    
    private let sourceCardView = NSView()
    private var sourceScrollView: NSScrollView!
    private var sourceTextView: NSTextView!
    
    private let statusLabel = NSTextField(labelWithString: "⚡ Apple Neural Engine (офлайн)")
    
    private let targetCardView = NSView()
    private var targetScrollView: NSScrollView!
    private var targetTextView: NSTextView!
    
    private let copyButton = NSButton()
    private let replaceButton = NSButton()
    private let speakButton = NSButton()
    private let ocrButton = NSButton()
    private let historyButton = NSButton()
    private let settingsButton = NSButton()
    private let downloadModelButton = NSButton()
    private let toneSegmentedControl = NSSegmentedControl()
    private let toastLabel = NSTextField(labelWithString: "")
    
    private var detectedLanguage: String?
    private var isUpdatingUI: Bool = false
    private var textChangeTimer: Timer?
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
        
        // Background vibrancy
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(visualEffectView)
        
        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        setupHeader()
        setupSourceText()
        setupStatusLine()
        setupToneSelector()
        setupTargetText()
        setupFooter()
        populateLanguages()
        refreshLocalizedStrings()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange),
            name: LocalizationManager.languageDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleLanguageChange() {
        populateLanguages()
        refreshLocalizedStrings()
    }
    
    public func refreshLocalizedStrings() {
        copyButton.title = L10n("hud.copy")
        replaceButton.title = L10n("hud.replace")
        speakButton.toolTip = L10n("hud.speak_tooltip")
        settingsButton.toolTip = L10n("hud.settings_tooltip")
        swapButton.toolTip = L10n("hud.swap_tooltip")
        closeButton.toolTip = L10n("hud.close_tooltip")
        downloadModelButton.title = L10n("hud.btn_download_model")
        downloadModelButton.toolTip = L10n("hud.download_tooltip")
        if downloadModelButton.isHidden {
            statusLabel.stringValue = L10n("hud.ane_offline")
        } else {
            statusLabel.stringValue = L10n("hud.cloud_online")
        }
    }
    
    private func setupHeader() {
        sourcePopUp.translatesAutoresizingMaskIntoConstraints = false
        sourcePopUp.target = self
        sourcePopUp.action = #selector(sourceLanguageChanged)
        sourcePopUp.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        addSubview(sourcePopUp)
        
        swapButton.translatesAutoresizingMaskIntoConstraints = false
        swapButton.title = "⇄"
        swapButton.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        swapButton.bezelStyle = .texturedRounded
        swapButton.target = self
        swapButton.action = #selector(swapClicked)
        addSubview(swapButton)
        
        targetPopUp.translatesAutoresizingMaskIntoConstraints = false
        targetPopUp.target = self
        targetPopUp.action = #selector(targetLanguageChanged)
        targetPopUp.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        addSubview(targetPopUp)
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.title = "✕"
        closeButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        closeButton.bezelStyle = .circular
        closeButton.target = self
        closeButton.action = #selector(closeClicked)
        addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            sourcePopUp.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            sourcePopUp.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            sourcePopUp.widthAnchor.constraint(equalToConstant: 165),
            
            swapButton.leadingAnchor.constraint(equalTo: sourcePopUp.trailingAnchor, constant: 8),
            swapButton.centerYAnchor.constraint(equalTo: sourcePopUp.centerYAnchor),
            swapButton.widthAnchor.constraint(equalToConstant: 32),
            
            targetPopUp.leadingAnchor.constraint(equalTo: swapButton.trailingAnchor, constant: 8),
            targetPopUp.centerYAnchor.constraint(equalTo: sourcePopUp.centerYAnchor),
            targetPopUp.widthAnchor.constraint(equalToConstant: 165),
            
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            closeButton.centerYAnchor.constraint(equalTo: sourcePopUp.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func setupSourceText() {
        sourceCardView.wantsLayer = true
        sourceCardView.layer?.cornerRadius = 8
        sourceCardView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.25).cgColor
        sourceCardView.layer?.borderWidth = 1
        sourceCardView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        sourceCardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sourceCardView)
        
        let customSource = SourceTextView()
        customSource.isVerticallyResizable = true
        customSource.isHorizontallyResizable = false
        customSource.autoresizingMask = [.width]
        customSource.textContainer?.widthTracksTextView = true
        customSource.textContainerInset = NSSize(width: 4, height: 4)
        customSource.isEditable = true
        customSource.isSelectable = true
        customSource.isRichText = false
        customSource.font = NSFont.systemFont(ofSize: 14)
        customSource.textColor = NSColor.textColor
        customSource.insertionPointColor = NSColor.controlAccentColor
        customSource.drawsBackground = false
        customSource.delegate = self
        customSource.onCommandEnter = { [weak self] in
            self?.copyClicked()
        }
        customSource.onCommandV = { [weak self] in
            guard let self = self else { return false }
            let target = self.targetTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !target.isEmpty {
                self.replaceClicked()
                return true
            }
            return false
        }
        
        sourceScrollView = NSScrollView()
        sourceScrollView.translatesAutoresizingMaskIntoConstraints = false
        sourceScrollView.drawsBackground = false
        sourceScrollView.borderType = .noBorder
        sourceScrollView.hasVerticalScroller = true
        sourceScrollView.hasHorizontalScroller = false
        sourceScrollView.autohidesScrollers = true
        sourceScrollView.documentView = customSource
        sourceTextView = customSource
        
        sourceCardView.addSubview(sourceScrollView)
        
        NSLayoutConstraint.activate([
            sourceCardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            sourceCardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            sourceCardView.topAnchor.constraint(equalTo: sourcePopUp.bottomAnchor, constant: 10),
            sourceCardView.heightAnchor.constraint(equalToConstant: 80),
            
            sourceScrollView.leadingAnchor.constraint(equalTo: sourceCardView.leadingAnchor, constant: 6),
            sourceScrollView.trailingAnchor.constraint(equalTo: sourceCardView.trailingAnchor, constant: -6),
            sourceScrollView.topAnchor.constraint(equalTo: sourceCardView.topAnchor, constant: 6),
            sourceScrollView.bottomAnchor.constraint(equalTo: sourceCardView.bottomAnchor, constant: -6)
        ])
    }
    
    private func setupStatusLine() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = NSColor.secondaryLabelColor
        addSubview(statusLabel)
        
        downloadModelButton.translatesAutoresizingMaskIntoConstraints = false
        downloadModelButton.bezelStyle = .inline
        downloadModelButton.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        downloadModelButton.contentTintColor = NSColor.systemBlue
        downloadModelButton.title = L10n("hud.btn_download_model")
        downloadModelButton.toolTip = L10n("hud.download_tooltip")
        downloadModelButton.target = self
        downloadModelButton.action = #selector(downloadModelClicked)
        downloadModelButton.isHidden = true
        addSubview(downloadModelButton)
        
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statusLabel.topAnchor.constraint(equalTo: sourceCardView.bottomAnchor, constant: 6),
            
            downloadModelButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            downloadModelButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            downloadModelButton.heightAnchor.constraint(equalToConstant: 18)
        ])
    }
    
    @objc private func downloadModelClicked() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func setupToneSelector() {
        toneSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        toneSegmentedControl.segmentCount = 5
        toneSegmentedControl.setLabel("⚡ Оригінал", forSegment: 0)
        toneSegmentedControl.setLabel("💼 Діловий [PRO]", forSegment: 1)
        toneSegmentedControl.setLabel("💬 Розмовний [PRO]", forSegment: 2)
        toneSegmentedControl.setLabel("✍️ Граматика [PRO]", forSegment: 3)
        toneSegmentedControl.setLabel("✂️ Спростити [PRO]", forSegment: 4)
        toneSegmentedControl.selectedSegment = 0
        toneSegmentedControl.target = self
        toneSegmentedControl.action = #selector(toneClicked)
        toneSegmentedControl.segmentStyle = .texturedRounded
        toneSegmentedControl.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        addSubview(toneSegmentedControl)
        
        NSLayoutConstraint.activate([
            toneSegmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            toneSegmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            toneSegmentedControl.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 6),
            toneSegmentedControl.heightAnchor.constraint(equalToConstant: 22)
        ])
    }
    
    @objc private func toneClicked() {
        if toneSegmentedControl.selectedSegment != 0 {
            toneSegmentedControl.selectedSegment = 0
            showToast("⭐️ ШІ-стилі доступні в MacTranslate Pro ($12/рік)")
        }
    }
    
    private func setupTargetText() {
        targetCardView.wantsLayer = true
        targetCardView.layer?.cornerRadius = 8
        targetCardView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.35).cgColor
        targetCardView.layer?.borderWidth = 1
        targetCardView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        targetCardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(targetCardView)
        
        let customTarget = NSTextView()
        customTarget.isVerticallyResizable = true
        customTarget.isHorizontallyResizable = false
        customTarget.autoresizingMask = [.width]
        customTarget.textContainer?.widthTracksTextView = true
        customTarget.textContainerInset = NSSize(width: 4, height: 4)
        customTarget.isEditable = false
        customTarget.isSelectable = true
        customTarget.isRichText = false
        customTarget.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        customTarget.textColor = NSColor.textColor
        customTarget.drawsBackground = false
        
        targetScrollView = NSScrollView()
        targetScrollView.translatesAutoresizingMaskIntoConstraints = false
        targetScrollView.drawsBackground = false
        targetScrollView.borderType = .noBorder
        targetScrollView.hasVerticalScroller = true
        targetScrollView.hasHorizontalScroller = false
        targetScrollView.autohidesScrollers = true
        targetScrollView.documentView = customTarget
        targetTextView = customTarget
        
        targetCardView.addSubview(targetScrollView)
        
        NSLayoutConstraint.activate([
            targetCardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            targetCardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            targetCardView.topAnchor.constraint(equalTo: toneSegmentedControl.bottomAnchor, constant: 6),
            targetCardView.heightAnchor.constraint(equalToConstant: 95),
            
            targetScrollView.leadingAnchor.constraint(equalTo: targetCardView.leadingAnchor, constant: 6),
            targetScrollView.trailingAnchor.constraint(equalTo: targetCardView.trailingAnchor, constant: -6),
            targetScrollView.topAnchor.constraint(equalTo: targetCardView.topAnchor, constant: 6),
            targetScrollView.bottomAnchor.constraint(equalTo: targetCardView.bottomAnchor, constant: -6)
        ])
    }
    
    private func setupFooter() {
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.title = L10n("hud.copy")
        copyButton.bezelStyle = .rounded
        copyButton.keyEquivalent = "\r"
        copyButton.keyEquivalentModifierMask = [.command]
        copyButton.target = self
        copyButton.action = #selector(copyClicked)
        addSubview(copyButton)
        
        replaceButton.translatesAutoresizingMaskIntoConstraints = false
        replaceButton.title = L10n("hud.replace")
        replaceButton.bezelStyle = .rounded
        replaceButton.target = self
        replaceButton.action = #selector(replaceClicked)
        addSubview(replaceButton)
        
        speakButton.translatesAutoresizingMaskIntoConstraints = false
        speakButton.title = "🔊"
        speakButton.bezelStyle = .rounded
        speakButton.target = self
        speakButton.action = #selector(speakClicked)
        addSubview(speakButton)
        
        ocrButton.translatesAutoresizingMaskIntoConstraints = false
        ocrButton.title = "📷"
        ocrButton.toolTip = "Знімок екрана (OCR) [PRO]"
        ocrButton.bezelStyle = .rounded
        ocrButton.target = self
        ocrButton.action = #selector(ocrClicked)
        addSubview(ocrButton)
        
        historyButton.translatesAutoresizingMaskIntoConstraints = false
        historyButton.title = "📜"
        historyButton.toolTip = "Словник та Anki [PRO]"
        historyButton.bezelStyle = .rounded
        historyButton.target = self
        historyButton.action = #selector(historyClicked)
        addSubview(historyButton)
        
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.title = "⚙"
        settingsButton.bezelStyle = .rounded
        settingsButton.target = self
        settingsButton.action = #selector(settingsClicked)
        addSubview(settingsButton)
        
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        toastLabel.textColor = NSColor.systemGreen
        toastLabel.isHidden = true
        addSubview(toastLabel)
        
        NSLayoutConstraint.activate([
            copyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            copyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            copyButton.heightAnchor.constraint(equalToConstant: 28),
            
            replaceButton.leadingAnchor.constraint(equalTo: copyButton.trailingAnchor, constant: 8),
            replaceButton.centerYAnchor.constraint(equalTo: copyButton.centerYAnchor),
            replaceButton.heightAnchor.constraint(equalToConstant: 28),
            
            speakButton.leadingAnchor.constraint(equalTo: replaceButton.trailingAnchor, constant: 8),
            speakButton.centerYAnchor.constraint(equalTo: copyButton.centerYAnchor),
            speakButton.widthAnchor.constraint(equalToConstant: 32),
            speakButton.heightAnchor.constraint(equalToConstant: 28),
            
            ocrButton.leadingAnchor.constraint(equalTo: speakButton.trailingAnchor, constant: 6),
            ocrButton.centerYAnchor.constraint(equalTo: copyButton.centerYAnchor),
            ocrButton.widthAnchor.constraint(equalToConstant: 32),
            ocrButton.heightAnchor.constraint(equalToConstant: 28),
            
            historyButton.leadingAnchor.constraint(equalTo: ocrButton.trailingAnchor, constant: 6),
            historyButton.centerYAnchor.constraint(equalTo: copyButton.centerYAnchor),
            historyButton.widthAnchor.constraint(equalToConstant: 32),
            historyButton.heightAnchor.constraint(equalToConstant: 28),
            
            toastLabel.leadingAnchor.constraint(equalTo: historyButton.trailingAnchor, constant: 8),
            toastLabel.centerYAnchor.constraint(equalTo: copyButton.centerYAnchor),
            
            settingsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            settingsButton.centerYAnchor.constraint(equalTo: copyButton.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 32),
            settingsButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    @objc private func ocrClicked() {
        showToast("⭐️ Знімок екрана (OCR) доступний у Pro ($12/рік)")
    }
    
    @objc private func historyClicked() {
        showToast("⭐️ Словник та Anki доступні у Pro ($12/рік)")
    }
    
    private func populateLanguages() {
        sourcePopUp.removeAllItems()
        sourcePopUp.addItem(withTitle: L10n("hud.auto_detect"))
        sourcePopUp.lastItem?.representedObject = nil
        
        targetPopUp.removeAllItems()
        
        let detector = LanguageDetector.shared
        let langs = LanguageDetector.supportedLanguages
        
        for lang in langs {
            let flag = detector.flagEmoji(for: lang)
            let name = detector.localizedName(for: lang)
            let title = "\(flag) \(name)"
            
            sourcePopUp.addItem(withTitle: title)
            sourcePopUp.lastItem?.representedObject = lang
            
            targetPopUp.addItem(withTitle: title)
            targetPopUp.lastItem?.representedObject = lang
        }
    }
    
    // MARK: - Public State Configuration
    
    public func update(
        sourceText: String,
        targetText: String,
        detectedLanguage: String?,
        selectedSourceLanguage: String?,
        selectedTargetLanguage: String,
        statusMessage: String? = nil,
        isCloudFallback: Bool = false
    ) {
        isUpdatingUI = true
        defer { isUpdatingUI = false }
        
        self.detectedLanguage = detectedLanguage
        
        // Update source text with proper attributes
        let srcAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 14)
        ]
        sourceTextView.textStorage?.setAttributedString(NSAttributedString(string: sourceText, attributes: srcAttrs))
        
        // Update target text with proper attributes
        let tgtAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 15, weight: .medium)
        ]
        targetTextView.textStorage?.setAttributedString(NSAttributedString(string: targetText, attributes: tgtAttrs))
        
        if let msg = statusMessage {
            statusLabel.stringValue = msg
            downloadModelButton.isHidden = true
        } else if isCloudFallback {
            statusLabel.stringValue = L10n("hud.cloud_online")
            downloadModelButton.isHidden = false
        } else {
            statusLabel.stringValue = L10n("hud.ane_offline")
            downloadModelButton.isHidden = true
        }
        
        // Update Source PopUp selection
        if let selSrc = selectedSourceLanguage {
            selectItem(in: sourcePopUp, withRepresentedObject: selSrc)
        } else {
            // Auto option
            sourcePopUp.selectItem(at: 0)
            if let detected = detectedLanguage {
                let flag = LanguageDetector.shared.flagEmoji(for: detected)
                let name = LanguageDetector.shared.localizedName(for: detected)
                sourcePopUp.item(at: 0)?.title = "\(L10n("hud.auto_prefix"))\(flag) \(name)"
            } else {
                sourcePopUp.item(at: 0)?.title = L10n("hud.auto_detect")
            }
        }
        
        // Update Target PopUp selection
        selectItem(in: targetPopUp, withRepresentedObject: selectedTargetLanguage)
    }
    
    public func setTranslatingState(isLoading: Bool) {
        if isLoading {
            statusLabel.stringValue = L10n("hud.translating")
            downloadModelButton.isHidden = true
        } else {
            if downloadModelButton.isHidden {
                statusLabel.stringValue = L10n("hud.ane_offline")
            } else {
                statusLabel.stringValue = L10n("hud.cloud_online")
            }
        }
    }
    
    public func showToast(_ message: String) {
        toastLabel.stringValue = message
        toastLabel.isHidden = false
        toastLabel.alphaValue = 1.0
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 1.5
            toastLabel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.toastLabel.isHidden = true
                self?.toastLabel.alphaValue = 1.0
            }
        })
    }
    
    public func focusSourceText() {
        window?.makeFirstResponder(sourceTextView)
    }
    
    private func selectItem(in popUp: NSPopUpButton, withRepresentedObject object: String) {
        for item in popUp.itemArray {
            if let rep = item.representedObject as? String, rep == object {
                popUp.select(item)
                return
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func sourceLanguageChanged() {
        guard !isUpdatingUI else { return }
        let selectedLang = sourcePopUp.selectedItem?.representedObject as? String
        delegate?.hudContentViewDidChangeSourceLanguage(self, newLanguage: selectedLang)
    }
    
    @objc private func targetLanguageChanged() {
        guard !isUpdatingUI else { return }
        if let target = targetPopUp.selectedItem?.representedObject as? String {
            delegate?.hudContentViewDidChangeTargetLanguage(self, newLanguage: target)
        }
    }
    
    @objc private func swapClicked() {
        delegate?.hudContentViewDidRequestSwap(self)
    }
    
    @objc private func closeClicked() {
        delegate?.hudContentViewDidRequestClose(self)
    }
    
    @objc private func copyClicked() {
        let text = targetTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        showToast(L10n("hud.toast_copied"))
        delegate?.hudContentViewDidRequestCopy(self, text: text)
    }
    
    public var targetText: String {
        return targetTextView.string
    }
    
    private var isReplacingText = false
    
    @objc public func replaceClicked() {
        guard !isReplacingText else { return }
        let text = targetTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isReplacingText = true
        showToast(L10n("hud.toast_replaced"))
        delegate?.hudContentViewDidRequestReplace(self, text: text)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.isReplacingText = false
        }
    }
    
    @objc private func speakClicked() {
        let text = targetTextView.string
        guard !text.isEmpty else { return }
        let lang = (targetPopUp.selectedItem?.representedObject as? String) ?? "en"
        delegate?.hudContentViewDidRequestSpeak(self, text: text, languageCode: lang)
    }
    
    @objc private func settingsClicked() {
        delegate?.hudContentViewDidRequestOpenSettings(self)
    }
}

// MARK: - NSTextViewDelegate
extension HUDContentView: NSTextViewDelegate {
    public func textDidChange(_ notification: Notification) {
        guard !isUpdatingUI else { return }
        let newText = sourceTextView.string
        
        // Debounce text changes (300ms)
        textChangeTimer?.invalidate()
        textChangeTimer = Timer.scheduledTimer(withTimeInterval: 0.30, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.hudContentViewDidEditSourceText(self, newText: newText)
            }
        }
    }
}
