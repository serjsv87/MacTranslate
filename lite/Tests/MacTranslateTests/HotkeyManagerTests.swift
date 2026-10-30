import Testing
import Foundation
@testable import MacTranslate

@Suite("Hotkey Manager & Double Tap Detector Tests")
struct HotkeyManagerTests {
    
    @Test("Single Command-C does not trigger hotkey")
    func testSingleCommandCDoesNotTrigger() {
        let detector = DoubleTapDetector(mode: .doubleCommandC, windowSeconds: 0.400)
        let event = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.0)
        let trigger = detector.processKeyEvent(event)
        #expect(trigger == nil)
    }
    
    @Test("Double Command-C within window triggers .doubleCommandC")
    func testDoubleCommandCWithinWindowTriggers() {
        let detector = DoubleTapDetector(mode: .doubleCommandC, windowSeconds: 0.400)
        let tap1 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.000)
        let tap2 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.200) // 200ms delta
        
        #expect(detector.processKeyEvent(tap1) == nil)
        #expect(detector.processKeyEvent(tap2) == .doubleCommandC)
    }
    
    @Test("Double Command-C exceeding 400ms window does not trigger")
    func testDoubleCommandCExceedingWindowDoesNotTrigger() {
        let detector = DoubleTapDetector(mode: .doubleCommandC, windowSeconds: 0.400)
        let tap1 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.000)
        let tap2 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.450) // 450ms delta (> 400ms)
        
        #expect(detector.processKeyEvent(tap1) == nil)
        #expect(detector.processKeyEvent(tap2) == nil)
    }
    
    @Test("Rapid triple-tap does not cause duplicate trigger")
    func testRapidTripleTapSuppression() {
        let detector = DoubleTapDetector(mode: .doubleCommandC, windowSeconds: 0.400)
        let tap1 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.000)
        let tap2 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.200) // Double-tap fires
        let tap3 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.350) // Triple tap must NOT trigger
        let tap4 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.500) // Tap 4 matches Tap 3 -> fires!
        
        #expect(detector.processKeyEvent(tap1) == nil)
        #expect(detector.processKeyEvent(tap2) == .doubleCommandC)
        #expect(detector.processKeyEvent(tap3) == nil)
        #expect(detector.processKeyEvent(tap4) == .doubleCommandC)
    }
    
    @Test("Hardware bounce under 50ms debounce is rejected")
    func testHardwareBounceSuppression() {
        let detector = DoubleTapDetector(mode: .doubleCommandC, windowSeconds: 0.400, minDebounceSeconds: 0.050)
        let tap1 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.000)
        let bounce = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.020) // 20ms electrical chatter
        let tap2 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.200)   // Legitimate second tap
        
        #expect(detector.processKeyEvent(tap1) == nil)
        #expect(detector.processKeyEvent(bounce) == nil)
        #expect(detector.processKeyEvent(tap2) == .doubleCommandC)
    }
    
    @Test("Double Control-C triggers .doubleControlC")
    func testDoubleControlCTriggers() {
        let detector = DoubleTapDetector(mode: .doubleControlC, windowSeconds: 0.400)
        let tap1 = KeyEvent(keyCode: 8, isControl: true, timestamp: 1.000)
        let tap2 = KeyEvent(keyCode: 8, isControl: true, timestamp: 1.250)
        
        #expect(detector.processKeyEvent(tap1) == nil)
        #expect(detector.processKeyEvent(tap2) == .doubleControlC)
    }
    
    @Test("Alternate shortcuts (Option+Space and Option+T) trigger instantly")
    func testAlternateShortcutTriggers() {
        let detector = DoubleTapDetector(mode: .alternate)
        
        // Option+Space (keyCode 49)
        let optSpace = KeyEvent(keyCode: 49, isAlternate: true, timestamp: 1.000)
        #expect(detector.processKeyEvent(optSpace) == .alternate)
        
        // Option+T (keyCode 17)
        let optT = KeyEvent(keyCode: 17, isAlternate: true, timestamp: 2.000)
        #expect(detector.processKeyEvent(optT) == .alternate)
    }
    
    @Test("Conflicting modifiers (Cmd+Ctrl+C or Cmd+Alt+C) are ignored")
    func testConflictingModifiersIgnored() {
        let detector = DoubleTapDetector(mode: nil)
        let tap1 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.000)
        #expect(detector.processKeyEvent(tap1) == nil)
        
        // Command AND Control pressed simultaneously
        let tapConflicted = KeyEvent(keyCode: 8, isCommand: true, isControl: true, timestamp: 1.200)
        #expect(detector.processKeyEvent(tapConflicted) == nil)
        
        // Command AND Alternate pressed simultaneously
        let tapCmdAlt = KeyEvent(keyCode: 8, isCommand: true, isAlternate: true, timestamp: 1.250)
        #expect(detector.processKeyEvent(tapCmdAlt) == nil)
    }
    
    @Test("Mode filtering enforces only enabled shortcuts")
    func testModeFiltering() {
        // Mode set to doubleCommandC only
        let cmdOnlyDetector = DoubleTapDetector(mode: .doubleCommandC)
        let ctrl1 = KeyEvent(keyCode: 8, isControl: true, timestamp: 1.000)
        let ctrl2 = KeyEvent(keyCode: 8, isControl: true, timestamp: 1.200)
        #expect(cmdOnlyDetector.processKeyEvent(ctrl1) == nil)
        #expect(cmdOnlyDetector.processKeyEvent(ctrl2) == nil)
        
        // Mode set to doubleControlC only
        let ctrlOnlyDetector = DoubleTapDetector(mode: .doubleControlC)
        let cmd1 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.000)
        let cmd2 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.200)
        #expect(ctrlOnlyDetector.processKeyEvent(cmd1) == nil)
        #expect(ctrlOnlyDetector.processKeyEvent(cmd2) == nil)
        
        // Mode set to alternate only
        let altOnlyDetector = DoubleTapDetector(mode: .alternate)
        #expect(altOnlyDetector.processKeyEvent(cmd1) == nil)
        #expect(altOnlyDetector.processKeyEvent(cmd2) == nil)
        let optSpace = KeyEvent(keyCode: 49, isAlternate: true, timestamp: 1.300)
        #expect(altOnlyDetector.processKeyEvent(optSpace) == .alternate)
    }
    
    @Test("Custom timing window configurations")
    func testCustomWindowThreshold() {
        let detector = DoubleTapDetector(mode: .doubleCommandC, windowSeconds: 0.250) // 250ms window
        
        let tap1 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.000)
        let tapTooLate = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.300) // 300ms > 250ms
        #expect(detector.processKeyEvent(tap1) == nil)
        #expect(detector.processKeyEvent(tapTooLate) == nil)
        
        let tapWithin = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.450) // 150ms < 250ms
        #expect(detector.processKeyEvent(tapWithin) == .doubleCommandC)
    }
    
    @Test("Reset clears cached state")
    func testResetClearsState() {
        let detector = DoubleTapDetector(mode: .doubleCommandC, windowSeconds: 0.400)
        let tap1 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.000)
        #expect(detector.processKeyEvent(tap1) == nil)
        
        detector.reset()
        
        let tap2 = KeyEvent(keyCode: 8, isCommand: true, timestamp: 1.200)
        #expect(detector.processKeyEvent(tap2) == nil) // Treated as new first tap
    }
    
    @Test("Non-C keycodes are ignored")
    func testNonCKeycodesIgnored() {
        let detector = DoubleTapDetector(mode: .doubleCommandC)
        let keyA = KeyEvent(keyCode: 0, isCommand: true, timestamp: 1.000)
        let keyV = KeyEvent(keyCode: 9, isCommand: true, timestamp: 1.200)
        #expect(detector.processKeyEvent(keyA) == nil)
        #expect(detector.processKeyEvent(keyV) == nil)
    }
    
    @Test("HotkeyManager lifecycle, mode updates and display names")
    func testHotkeyManagerLifecycleAndProperties() {
        let manager = HotkeyManager(mode: .doubleCommandC, windowMs: 400.0)
        #expect(manager.mode == .doubleCommandC)
        #expect(manager.windowMs == 400.0)
        
        manager.mode = .doubleControlC
        #expect(manager.mode == .doubleControlC)
        
        manager.windowMs = 300.0
        #expect(manager.windowMs == 300.0)
        #expect(manager.detector.windowSeconds == 0.300)
        
        // Start and stop listening
        final class TriggerBox: @unchecked Sendable {
            var value = false
        }
        let box = TriggerBox()
        manager.startListening {
            box.value = true
        }
        manager.stopListening()
        #expect(box.value == false)
        
        // Display names
        #expect(HotkeyMode.doubleCommandC.displayName == "Double ⌘C (⌘C+C)")
        #expect(HotkeyMode.doubleControlC.displayName == "Double ⌃C (⌃C+C)")
        #expect(HotkeyMode.alternate.displayName == "Alternate (⌥Space)")
    }
}
