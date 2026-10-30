import Testing
import Foundation
@testable import MacTranslate

@Suite("Preferences Persistence Tests")
struct PreferencesPersistenceTests {
    let suiteName = "com.mactranslate.tests.preferences.\(UUID().uuidString)"
    
    private func createTestManager() -> PreferencesManager {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return PreferencesManager(userDefaults: defaults)
    }
    
    @Test("Default configuration on fresh launch")
    func testDefaults() {
        let prefs = createTestManager()
        #expect(prefs.primaryLanguage == "uk")
        #expect(prefs.secondaryLanguage == "en")
        #expect(prefs.fallbackLanguage == "en")
        #expect(prefs.hotkeyMode == .doubleCommandC)
        #expect(prefs.hotkeyWindowMs == 400.0)
        #expect(prefs.dismissOnOutsideClick == true)
        #expect(prefs.enterKeyAction == .copyAndClose)
        #expect(prefs.launchAtLogin == false)
    }
    
    @Test("Updating and persisting language settings")
    func testUpdatingLanguages() {
        let prefs = createTestManager()
        prefs.primaryLanguage = "de"
        prefs.secondaryLanguage = "fr"
        prefs.fallbackLanguage = "pl"
        
        #expect(prefs.primaryLanguage == "de")
        #expect(prefs.secondaryLanguage == "fr")
        #expect(prefs.fallbackLanguage == "pl")
    }
    
    @Test("Updating hotkey mode and timing")
    func testUpdatingHotkeys() {
        let prefs = createTestManager()
        prefs.hotkeyMode = .doubleControlC
        prefs.hotkeyWindowMs = 350.0
        #expect(prefs.hotkeyMode == .doubleControlC)
        #expect(prefs.hotkeyWindowMs == 350.0)
        
        prefs.hotkeyMode = .alternate
        #expect(prefs.hotkeyMode == .alternate)
    }
    
    @Test("Updating behavior preferences")
    func testUpdatingBehavior() {
        let prefs = createTestManager()
        prefs.dismissOnOutsideClick = false
        prefs.enterKeyAction = .copyOnly
        prefs.launchAtLogin = true
        
        #expect(prefs.dismissOnOutsideClick == false)
        #expect(prefs.enterKeyAction == .copyOnly)
        #expect(prefs.launchAtLogin == true)
    }
    
    @Test("Cross-instance persistence with identical suite")
    func testCrossInstancePersistence() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        
        let prefs1 = PreferencesManager(userDefaults: defaults)
        prefs1.primaryLanguage = "es"
        prefs1.enterKeyAction = .copyOnly
        prefs1.dismissOnOutsideClick = false
        
        let prefs2 = PreferencesManager(userDefaults: defaults)
        #expect(prefs2.primaryLanguage == "es")
        #expect(prefs2.enterKeyAction == .copyOnly)
        #expect(prefs2.dismissOnOutsideClick == false)
    }
    
    @Test("Reset to defaults restores initial settings")
    func testResetToDefaults() {
        let prefs = createTestManager()
        prefs.primaryLanguage = "ja"
        prefs.secondaryLanguage = "zh"
        prefs.fallbackLanguage = "ko"
        prefs.hotkeyMode = .alternate
        prefs.hotkeyWindowMs = 250.0
        prefs.dismissOnOutsideClick = false
        prefs.enterKeyAction = .copyOnly
        prefs.launchAtLogin = true
        
        prefs.resetToDefaults()
        
        #expect(prefs.primaryLanguage == "uk")
        #expect(prefs.secondaryLanguage == "en")
        #expect(prefs.fallbackLanguage == "en")
        #expect(prefs.hotkeyMode == .doubleCommandC)
        #expect(prefs.hotkeyWindowMs == 400.0)
        #expect(prefs.dismissOnOutsideClick == true)
        #expect(prefs.enterKeyAction == .copyAndClose)
        #expect(prefs.launchAtLogin == false)
    }
}
