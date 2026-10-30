import AppKit
import Foundation

@MainActor
public final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = SettingsWindowController()
    
    // UI Language Selector
    private let appLanguagePopUp = NSPopUpButton()
    
    // Fallback language picker
    private let fallbackPopUp = NSPopUpButton()
    
    // Dynamic Rules Stack
    private let rulesStackView = NSStackView()
    private var ruleRows: [(source: String, target: String, rowView: NSView)] = []
    
    // Hotkeys
    private var hotkeyRadios: [NSButton] = []
    
    // Behavior Checkboxes
    private let autoCopyCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoDismissCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let replaceSelectedCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    
    // Permissions Section Elements
    private let axHeader = NSTextField(labelWithString: "")
    private let axLabel = NSTextField(labelWithString: "")
    private let axStatusLabel = NSTextField(labelWithString: "")
    private let axButton = NSButton(title: "", target: nil, action: nil)
    
    private let permissionsTipLabel = NSTextField(wrappingLabelWithString: "")
    
    // Support (Give me coffee)
    private let supportHeader = NSTextField(labelWithString: "")
    private let supportDescLabel = NSTextField(wrappingLabelWithString: "")
    private let trc20AddressField = NSTextField()
    private let copyTRC20Button = NSButton(title: "", target: nil, action: nil)
    private let supportFeedbackLabel = NSTextField(labelWithString: "")
    
    // About & Version
    private let aboutHeader = NSTextField(labelWithString: "")
    private let versionLabel = NSTextField(labelWithString: "")
    private let checkUpdatesButton = NSButton(title: "", target: nil, action: nil)
    
    // Section headers & labels to refresh on language change
    private let generalHeader = NSTextField(labelWithString: "")
    private let appLangLabel = NSTextField(labelWithString: "")
    private let rulesHeader = NSTextField(labelWithString: "")
    private let rulesSubtitle = NSTextField(labelWithString: "")
    private let addRuleButton = NSButton(title: "", target: nil, action: nil)
    private let fallbackLabel = NSTextField(labelWithString: "")
    private let hotkeyHeader = NSTextField(labelWithString: "")
    private let behaviorHeader = NSTextField(labelWithString: "")
    
    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        
        setupUI()
        loadPreferences()
        refreshLocalization()
        
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
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func handleLanguageChange() {
        refreshLocalization()
        loadPreferences()
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        let scrollView = NSScrollView(frame: contentView.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        contentView.addSubview(scrollView)
        
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 14
        container.translatesAutoresizingMaskIntoConstraints = false
        container.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        
        let clipView = NSClipView()
        clipView.documentView = container
        scrollView.contentView = clipView
        
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            container.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            container.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        
        // --- SECTION 0: APP INTERFACE LANGUAGE ---
        container.addArrangedSubview(generalHeader)
        let appLangRow = NSStackView(views: [appLangLabel, appLanguagePopUp])
        appLangRow.orientation = .horizontal
        appLangRow.spacing = 10
        appLanguagePopUp.target = self
        appLanguagePopUp.action = #selector(appLanguageChanged)
        container.addArrangedSubview(appLangRow)
        
        // --- SECTION 1: LANGUAGE RULES ---
        container.addArrangedSubview(makeSeparator())
        container.addArrangedSubview(rulesHeader)
        rulesSubtitle.font = NSFont.systemFont(ofSize: 11)
        rulesSubtitle.textColor = NSColor.secondaryLabelColor
        container.addArrangedSubview(rulesSubtitle)
        
        rulesStackView.orientation = .vertical
        rulesStackView.alignment = .leading
        rulesStackView.spacing = 8
        rulesStackView.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(rulesStackView)
        
        addRuleButton.target = self
        addRuleButton.action = #selector(addRuleClicked)
        addRuleButton.bezelStyle = .rounded
        container.addArrangedSubview(addRuleButton)
        
        // Fallback target
        let fallbackRow = NSStackView(views: [fallbackLabel, fallbackPopUp])
        fallbackRow.orientation = .horizontal
        fallbackRow.spacing = 10
        fallbackPopUp.target = self
        fallbackPopUp.action = #selector(fallbackChanged)
        container.addArrangedSubview(fallbackRow)
        
        // --- SECTION 2: HOTKEYS ---
        container.addArrangedSubview(makeSeparator())
        container.addArrangedSubview(hotkeyHeader)
        
        for mode in HotkeyMode.allCases {
            let radio = NSButton(radioButtonWithTitle: "", target: self, action: #selector(hotkeyModeChanged(_:)))
            radio.tag = mode.rawValue
            hotkeyRadios.append(radio)
            container.addArrangedSubview(radio)
        }
        
        // --- SECTION 3: BEHAVIOR ---
        container.addArrangedSubview(makeSeparator())
        container.addArrangedSubview(behaviorHeader)
        
        autoCopyCheckbox.target = self
        autoCopyCheckbox.action = #selector(preferenceChanged)
        container.addArrangedSubview(autoCopyCheckbox)
        
        autoDismissCheckbox.target = self
        autoDismissCheckbox.action = #selector(preferenceChanged)
        container.addArrangedSubview(autoDismissCheckbox)
        
        replaceSelectedCheckbox.target = self
        replaceSelectedCheckbox.action = #selector(preferenceChanged)
        container.addArrangedSubview(replaceSelectedCheckbox)
        
        // --- SECTION 4: PERMISSIONS ---
        container.addArrangedSubview(makeSeparator())
        container.addArrangedSubview(axHeader)
        
        let axCol = NSStackView(views: [axLabel, axStatusLabel])
        axCol.orientation = .vertical
        axCol.alignment = .leading
        axCol.spacing = 2
        
        let axRow = NSStackView(views: [axCol, axButton])
        axRow.orientation = .horizontal
        axRow.distribution = .fill
        axRow.alignment = .centerY
        axRow.spacing = 16
        axButton.target = self
        axButton.action = #selector(openAXSettings)
        container.addArrangedSubview(axRow)
        
        permissionsTipLabel.textColor = .secondaryLabelColor
        permissionsTipLabel.font = NSFont.systemFont(ofSize: 11)
        permissionsTipLabel.lineBreakMode = .byWordWrapping
        container.addArrangedSubview(permissionsTipLabel)
        
        // --- SECTION 5: SUPPORT / GIVE ME COFFEE ---
        container.addArrangedSubview(makeSeparator())
        container.addArrangedSubview(supportHeader)
        
        supportDescLabel.textColor = .secondaryLabelColor
        supportDescLabel.font = NSFont.systemFont(ofSize: 11)
        supportDescLabel.lineBreakMode = .byWordWrapping
        container.addArrangedSubview(supportDescLabel)
        
        trc20AddressField.isEditable = false
        trc20AddressField.isSelectable = true
        trc20AddressField.stringValue = LocalizationManager.donationAddressTRC20
        trc20AddressField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        trc20AddressField.textColor = .textColor
        trc20AddressField.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5)
        trc20AddressField.isBezeled = true
        trc20AddressField.bezelStyle = .roundedBezel
        
        copyTRC20Button.bezelStyle = .rounded
        copyTRC20Button.target = self
        copyTRC20Button.action = #selector(copyTRC20Clicked)
        
        let supportRow = NSStackView(views: [trc20AddressField, copyTRC20Button])
        supportRow.orientation = .horizontal
        supportRow.spacing = 10
        supportRow.alignment = .centerY
        container.addArrangedSubview(supportRow)
        
        supportFeedbackLabel.textColor = .systemGreen
        supportFeedbackLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        supportFeedbackLabel.isHidden = true
        container.addArrangedSubview(supportFeedbackLabel)
        
        // --- SECTION 6: ABOUT & VERSION ---
        container.addArrangedSubview(makeSeparator())
        container.addArrangedSubview(aboutHeader)
        
        versionLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        checkUpdatesButton.bezelStyle = .rounded
        checkUpdatesButton.target = self
        checkUpdatesButton.action = #selector(checkUpdatesClicked)
        
        let versionRow = NSStackView(views: [versionLabel, checkUpdatesButton])
        versionRow.orientation = .horizontal
        versionRow.spacing = 12
        versionRow.alignment = .centerY
        container.addArrangedSubview(versionRow)
    }
    
    private func refreshLocalization() {
        window?.title = L10n("settings.title")
        
        styleHeader(generalHeader, text: L10n("settings.section_general"))
        appLangLabel.stringValue = L10n("settings.app_language")
        appLangLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        
        // Populate App Language dropdown
        appLanguagePopUp.removeAllItems()
        for lang in AppInterfaceLanguage.allCases {
            appLanguagePopUp.addItem(withTitle: lang.displayName)
            appLanguagePopUp.lastItem?.representedObject = lang
        }
        selectAppLanguage(PreferencesManager.shared.appLanguage)
        
        styleHeader(rulesHeader, text: L10n("settings.rules_header"))
        rulesSubtitle.stringValue = L10n("settings.fallback_desc")
        addRuleButton.title = L10n("settings.btn_add_rule")
        
        fallbackLabel.stringValue = L10n("settings.fallback_lang")
        fallbackLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        
        styleHeader(hotkeyHeader, text: L10n("settings.section_hotkeys"))
        let hotkeyTitles = [
            L10n("settings.hotkey_double_cmd_c"),
            L10n("settings.hotkey_double_ctrl_c"),
            L10n("settings.hotkey_alternate")
        ]
        for (i, radio) in hotkeyRadios.enumerated() where i < hotkeyTitles.count {
            radio.title = hotkeyTitles[i]
        }
        
        styleHeader(behaviorHeader, text: L10n("settings.section_behavior"))
        autoCopyCheckbox.title = L10n("hud.copy")
        autoDismissCheckbox.title = L10n("settings.dismiss_outside")
        replaceSelectedCheckbox.title = L10n("settings.replace_directly")
        
        styleHeader(axHeader, text: L10n("settings.permissions_title"))
        axLabel.stringValue = L10n("settings.permissions_ax_title")
        axLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        axButton.title = L10n("settings.btn_open_ax")
        permissionsTipLabel.stringValue = L10n("settings.permissions_reset_tip")
        
        styleHeader(supportHeader, text: L10n("settings.section_support"))
        supportDescLabel.stringValue = L10n("settings.support_desc")
        copyTRC20Button.title = "☕️ " + L10n("settings.btn_copy_trc20")
        
        styleHeader(aboutHeader, text: L10n("settings.section_about"))
        versionLabel.stringValue = "\(L10n("settings.version_label")) v\(UpdateChecker.currentVersion)"
        checkUpdatesButton.title = L10n("settings.btn_check_updates")
        
        updateAXStatus()
    }
    
    @objc private func checkUpdatesClicked() {
        UpdateChecker.shared.checkForUpdates(force: true, showUpToDateAlert: true)
    }
    
    @objc private func copyTRC20Clicked() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(LocalizationManager.donationAddressTRC20, forType: .string)
        
        supportFeedbackLabel.stringValue = L10n("settings.support_copied")
        supportFeedbackLabel.isHidden = false
        supportFeedbackLabel.alphaValue = 1.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                self.supportFeedbackLabel.animator().alphaValue = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.supportFeedbackLabel.isHidden = true
                self?.supportFeedbackLabel.alphaValue = 1.0
            }
        }
    }
    
    private func styleHeader(_ label: NSTextField, text: String) {
        label.stringValue = text
        label.font = NSFont.systemFont(ofSize: 13, weight: .bold)
    }
    
    private func makeSeparator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return box
    }
    
    private func populateLanguages(in popUp: NSPopUpButton) {
        popUp.removeAllItems()
        let detector = LanguageDetector.shared
        let langs = LanguageDetector.supportedLanguages
        for lang in langs {
            let flag = detector.flagEmoji(for: lang)
            let name = detector.localizedName(for: lang)
            popUp.addItem(withTitle: "\(flag) \(name)")
            popUp.lastItem?.representedObject = lang
        }
    }
    
    public func loadPreferences() {
        let prefs = PreferencesManager.shared
        
        selectAppLanguage(prefs.appLanguage)
        
        // Populate fallback
        populateLanguages(in: fallbackPopUp)
        selectLanguage(in: fallbackPopUp, code: prefs.fallbackLanguage)
        
        // Populate custom rules list
        rebuildRulesUI(rules: prefs.languageRules)
        
        for radio in hotkeyRadios {
            radio.state = (radio.tag == prefs.hotkeyMode.rawValue) ? .on : .off
        }
        
        autoCopyCheckbox.state = prefs.autoCopyOnEnter ? .on : .off
        autoDismissCheckbox.state = prefs.autoDismissOnBlur ? .on : .off
        replaceSelectedCheckbox.state = prefs.replaceSelectionDirectly ? .on : .off
        
        updateAXStatus()
    }
    
    private func selectAppLanguage(_ lang: AppInterfaceLanguage) {
        for item in appLanguagePopUp.itemArray {
            if let obj = item.representedObject as? AppInterfaceLanguage, obj == lang {
                appLanguagePopUp.select(item)
                return
            }
        }
    }
    
    @objc private func appLanguageChanged() {
        if let lang = appLanguagePopUp.selectedItem?.representedObject as? AppInterfaceLanguage {
            LocalizationManager.shared.currentLanguage = lang
        }
    }
    
    private func rebuildRulesUI(rules: [String: String]) {
        for row in ruleRows {
            row.rowView.removeFromSuperview()
        }
        ruleRows.removeAll()
        
        // Sort keys for consistent display (uk, en, ru first)
        let sortedKeys = rules.keys.sorted { k1, k2 in
            let order = ["uk": 0, "en": 1, "ru": 2]
            let o1 = order[k1] ?? 99
            let o2 = order[k2] ?? 99
            if o1 != o2 { return o1 < o2 }
            return k1 < k2
        }
        
        for src in sortedKeys {
            let tgt = rules[src] ?? "en"
            createRuleRow(source: src, target: tgt)
        }
    }
    
    private func createRuleRow(source: String, target: String) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        
        let ifLabel = NSTextField(labelWithString: L10n("settings.rule_if_detected"))
        ifLabel.font = NSFont.systemFont(ofSize: 12)
        row.addArrangedSubview(ifLabel)
        
        let srcPopUp = NSPopUpButton()
        populateLanguages(in: srcPopUp)
        selectLanguage(in: srcPopUp, code: source)
        srcPopUp.target = self
        srcPopUp.action = #selector(ruleValueChanged)
        row.addArrangedSubview(srcPopUp)
        
        let arrowLabel = NSTextField(labelWithString: "➔ \(L10n("settings.rule_translate_to"))")
        arrowLabel.font = NSFont.systemFont(ofSize: 12)
        row.addArrangedSubview(arrowLabel)
        
        let tgtPopUp = NSPopUpButton()
        populateLanguages(in: tgtPopUp)
        selectLanguage(in: tgtPopUp, code: target)
        tgtPopUp.target = self
        tgtPopUp.action = #selector(ruleValueChanged)
        row.addArrangedSubview(tgtPopUp)
        
        let deleteBtn = NSButton(title: "✕", target: self, action: #selector(deleteRuleClicked(_:)))
        deleteBtn.bezelStyle = .circular
        deleteBtn.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        row.addArrangedSubview(deleteBtn)
        
        rulesStackView.addArrangedSubview(row)
        ruleRows.append((source: source, target: target, rowView: row))
    }
    
    @objc private func addRuleClicked() {
        let usedSources = Set(ruleRows.map { $0.source })
        let available = LanguageDetector.supportedLanguages.first { !usedSources.contains($0) } ?? "de"
        let defaultTarget = PreferencesManager.shared.fallbackLanguage
        
        createRuleRow(source: available, target: defaultTarget)
        saveCurrentRules()
    }
    
    @objc private func deleteRuleClicked(_ sender: NSButton) {
        if let idx = ruleRows.firstIndex(where: { $0.rowView.subviews.contains(sender) }) {
            let row = ruleRows.remove(at: idx)
            row.rowView.removeFromSuperview()
            saveCurrentRules()
        }
    }
    
    @objc private func ruleValueChanged() {
        saveCurrentRules()
    }
    
    private func saveCurrentRules() {
        var updatedRules: [String: String] = [:]
        
        for (i, row) in ruleRows.enumerated() {
            let subviews = row.rowView.subviews.compactMap { $0 as? NSPopUpButton }
            if subviews.count >= 2 {
                let src = (subviews[0].selectedItem?.representedObject as? String) ?? "en"
                let tgt = (subviews[1].selectedItem?.representedObject as? String) ?? "uk"
                updatedRules[src] = tgt
                ruleRows[i].source = src
                ruleRows[i].target = tgt
            }
        }
        
        PreferencesManager.shared.languageRules = updatedRules
    }
    
    @objc private func fallbackChanged() {
        if let fb = fallbackPopUp.selectedItem?.representedObject as? String {
            PreferencesManager.shared.fallbackLanguage = fb
        }
    }
    
    public func updateAXStatus() {
        let isTrusted = AccessibilityHelper.isAccessibilityTrusted()
        if isTrusted {
            axStatusLabel.stringValue = L10n("settings.permissions_granted")
            axStatusLabel.textColor = .systemGreen
        } else {
            axStatusLabel.stringValue = L10n("settings.permissions_missing")
            axStatusLabel.textColor = .systemOrange
        }
    }
    
    public func windowDidBecomeKey(_ notification: Notification) {
        updateAXStatus()
    }
    
    private func selectLanguage(in popUp: NSPopUpButton, code: String) {
        for item in popUp.itemArray {
            if let rep = item.representedObject as? String, rep == code {
                popUp.select(item)
                return
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func preferenceChanged() {
        let prefs = PreferencesManager.shared
        prefs.autoCopyOnEnter = (autoCopyCheckbox.state == .on)
        prefs.autoDismissOnBlur = (autoDismissCheckbox.state == .on)
        prefs.replaceSelectionDirectly = (replaceSelectedCheckbox.state == .on)
    }
    
    @objc private func hotkeyModeChanged(_ sender: NSButton) {
        if let mode = HotkeyMode(rawValue: sender.tag) {
            PreferencesManager.shared.hotkeyMode = mode
            HotkeyManager.shared.setMode(mode)
        }
    }
    
    @objc private func openAXSettings() {
        AccessibilityHelper.openAccessibilitySettings()
    }
}
