import AppKit
import Foundation

@MainActor
public protocol StatusBarControllerDelegate: AnyObject {
    func statusBarControllerDidRequestTranslateClipboard(_ controller: StatusBarController)
    func statusBarControllerDidRequestOpenSettings(_ controller: StatusBarController)
    func statusBarControllerDidChangeLanguagePair(_ controller: StatusBarController, primary: String, secondary: String)
}

@MainActor
public final class StatusBarController: NSObject, NSMenuDelegate {
    public weak var delegate: StatusBarControllerDelegate?
    
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    
    public override init() {
        super.init()
        setupStatusItem()
        buildMenu()
        
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
        setupStatusItem()
        buildMenu()
    }
    
    private func setupStatusItem() {
        if let button = statusItem.button {
            button.title = "文/A"
            button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            button.toolTip = "MacTranslate — \(L10n("hud.ane_offline"))"
        }
        menu.delegate = self
        statusItem.menu = menu
    }
    
    public func menuWillOpen(_ menu: NSMenu) {
        buildMenu()
    }
    
    public func buildMenu() {
        menu.removeAllItems()
        
        let headerItem = NSMenuItem(title: "MacTranslate ⚡ Apple Neural Engine", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let translateItem = NSMenuItem(title: L10n("menu.translate_selection"), action: #selector(translateClipboardClicked), keyEquivalent: "t")
        translateItem.target = self
        menu.addItem(translateItem)
        
        let ocrItem = NSMenuItem(title: L10n("menu.screen_ocr_lite"), action: #selector(proFeatureClicked), keyEquivalent: "")
        ocrItem.target = self
        menu.addItem(ocrItem)
        
        let historyItem = NSMenuItem(title: L10n("menu.history_anki_lite"), action: #selector(proFeatureClicked), keyEquivalent: "")
        historyItem.target = self
        menu.addItem(historyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Language Pair Quick Picker
        let pairsMenu = NSMenu()
        let isUkrainian = LocalizationManager.shared.effectiveLanguageCode == "uk"
        let presetPairs: [(String, String, String)] = isUkrainian ? [
            ("uk", "en", "🇺🇦 Українська ⇄ 🇬🇧 English"),
            ("ru", "en", "🇷🇺 Російська ⇄ 🇬🇧 English"),
            ("pl", "en", "🇵🇱 Польська ⇄ 🇬🇧 English"),
            ("de", "en", "🇩🇪 Німецька ⇄ 🇬🇧 English"),
            ("es", "en", "🇪🇸 Іспанська ⇄ 🇬🇧 English"),
            ("fr", "en", "🇫🇷 Французька ⇄ 🇬🇧 English")
        ] : [
            ("uk", "en", "🇺🇦 Ukrainian ⇄ 🇬🇧 English"),
            ("ru", "en", "🇷🇺 Russian ⇄ 🇬🇧 English"),
            ("pl", "en", "🇵🇱 Polish ⇄ 🇬🇧 English"),
            ("de", "en", "🇩🇪 German ⇄ 🇬🇧 English"),
            ("es", "en", "🇪🇸 Spanish ⇄ 🇬🇧 English"),
            ("fr", "en", "🇫🇷 French ⇄ 🇬🇧 English")
        ]
        
        let currentPrimary = PreferencesManager.shared.primaryLanguage
        let currentSecondary = PreferencesManager.shared.secondaryLanguage
        
        for (p, s, title) in presetPairs {
            let item = NSMenuItem(title: title, action: #selector(pairSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = (p, s)
            if p == currentPrimary && s == currentSecondary {
                item.state = .on
            }
            pairsMenu.addItem(item)
        }
        
        let pairSubmenuItem = NSMenuItem(title: L10n("settings.section_rules"), action: nil, keyEquivalent: "")
        pairSubmenuItem.submenu = pairsMenu
        menu.addItem(pairSubmenuItem)
        
        // Hotkey Mode Quick Picker
        let hotkeyMenu = NSMenu()
        let currentMode = PreferencesManager.shared.hotkeyMode
        
        let hotkeyOptions: [(HotkeyMode, String)] = [
            (.doubleCommandC, L10n("settings.hotkey_double_cmd_c")),
            (.doubleControlC, L10n("settings.hotkey_double_ctrl_c")),
            (.alternate, L10n("settings.hotkey_alternate"))
        ]
        
        for (mode, title) in hotkeyOptions {
            let item = NSMenuItem(title: title, action: #selector(hotkeySelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            if mode == currentMode {
                item.state = .on
            }
            hotkeyMenu.addItem(item)
        }
        
        let hotkeySubmenuItem = NSMenuItem(title: L10n("settings.hotkey_shortcut"), action: nil, keyEquivalent: "")
        hotkeySubmenuItem.submenu = hotkeyMenu
        menu.addItem(hotkeySubmenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Accessibility status (Only shown if missing!)
        let axTrusted = AccessibilityHelper.isAccessibilityTrusted()
        if !axTrusted {
            let axItem = NSMenuItem(
                title: "⚠ \(L10n("settings.permissions_ax_missing"))",
                action: #selector(openAXClicked),
                keyEquivalent: ""
            )
            axItem.target = self
            menu.addItem(axItem)
            menu.addItem(NSMenuItem.separator())
        }
        
        // Settings
        let settingsItem = NSMenuItem(title: L10n("menu.settings"), action: #selector(settingsClicked), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // Give me coffee (TRC20)
        let coffeeItem = NSMenuItem(title: L10n("menu.coffee"), action: #selector(coffeeClicked), keyEquivalent: "")
        coffeeItem.target = self
        menu.addItem(coffeeItem)
        
        // GitHub Repository
        let githubItem = NSMenuItem(title: L10n("menu.github"), action: #selector(githubClicked), keyEquivalent: "")
        githubItem.target = self
        menu.addItem(githubItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: L10n("menu.quit"), action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    // MARK: - Actions
    
    @objc private func translateClipboardClicked() {
        delegate?.statusBarControllerDidRequestTranslateClipboard(self)
    }
    
    @objc private func proFeatureClicked() {
        let alert = NSAlert()
        alert.messageText = L10n("pro.alert_title")
        alert.informativeText = L10n("pro.alert_desc")
        alert.addButton(withTitle: L10n("pro.alert_btn"))
        alert.runModal()
    }
    
    @objc private func settingsClicked() {
        delegate?.statusBarControllerDidRequestOpenSettings(self)
    }
    
    @objc private func coffeeClicked() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(LocalizationManager.donationAddressTRC20, forType: .string)
        
        let alert = NSAlert()
        alert.messageText = L10n("settings.section_support")
        alert.informativeText = "\(L10n("settings.support_desc"))\n\n\(LocalizationManager.donationAddressTRC20)\n\n\(L10n("settings.support_copied"))"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func githubClicked() {
        if let url = URL(string: "https://github.com/serjsv87/MacTranslate") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func pairSelected(_ sender: NSMenuItem) {
        if let (p, s) = sender.representedObject as? (String, String) {
            PreferencesManager.shared.primaryLanguage = p
            PreferencesManager.shared.secondaryLanguage = s
            buildMenu()
            delegate?.statusBarControllerDidChangeLanguagePair(self, primary: p, secondary: s)
        }
    }
    
    @objc private func hotkeySelected(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? HotkeyMode {
            PreferencesManager.shared.hotkeyMode = mode
            HotkeyManager.shared.setMode(mode)
            buildMenu()
        }
    }
    
    @objc private func openAXClicked() {
        AccessibilityHelper.openAccessibilitySettings()
    }
    
    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }
}
