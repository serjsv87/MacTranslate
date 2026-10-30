import Foundation
import CoreGraphics
import AppKit
import Carbon

extension HotkeyMode {
    public var displayName: String {
        switch self {
        case .doubleCommandC: return "Double ⌘C (⌘C+C)"
        case .doubleControlC: return "Double ⌃C (⌃C+C)"
        case .alternate: return "Alternate (⌥Space)"
        }
    }
}

/// The specific trigger that fired the hotkey callback.
public enum HotkeyTriggerType: String, Sendable, Equatable {
    case doubleCommandC
    case doubleControlC
    case alternate
}

/// Abstract key event data model used for pure-logic gesture detection.
public struct KeyEvent: Sendable, Equatable {
    public let keyCode: UInt16
    public let isCommand: Bool
    public let isControl: Bool
    public let isAlternate: Bool
    public let timestamp: TimeInterval
    
    public init(
        keyCode: UInt16,
        isCommand: Bool = false,
        isControl: Bool = false,
        isAlternate: Bool = false,
        timestamp: TimeInterval
    ) {
        self.keyCode = keyCode
        self.isCommand = isCommand
        self.isControl = isControl
        self.isAlternate = isAlternate
        self.timestamp = timestamp
    }
}

/// Pure timing and state engine for double-tap detection.
/// Decoupled from macOS event tap APIs for 100% automated testability.
public final class DoubleTapDetector: @unchecked Sendable {
    public var mode: HotkeyMode?
    public var windowSeconds: TimeInterval
    public var minDebounceSeconds: TimeInterval
    
    private var lastCmdTimestamp: TimeInterval = 0
    private var lastCtrlTimestamp: TimeInterval = 0
    private let lock = NSLock()
    
    public init(
        mode: HotkeyMode? = nil,
        windowSeconds: TimeInterval = 0.650,
        minDebounceSeconds: TimeInterval = 0.050
    ) {
        self.mode = mode
        self.windowSeconds = windowSeconds
        self.minDebounceSeconds = minDebounceSeconds
    }
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        lastCmdTimestamp = 0
        lastCtrlTimestamp = 0
    }
    
    public func processKeyEvent(_ event: KeyEvent) -> HotkeyTriggerType? {
        lock.lock()
        defer { lock.unlock() }
        
        // 1. Alternate hotkey check (Option+Space: 49, Option+T: 17)
        // Only trigger if mode is explicitly set to .alternate
        if mode == .alternate && event.isAlternate && !event.isCommand && !event.isControl {
            if event.keyCode == 49 || event.keyCode == 17 {
                return .alternate
            }
        }
        
        // Key code 8 is ANSI 'C'
        guard event.keyCode == 8 else {
            return nil
        }
        
        // 2. Double Command-C
        if (mode == nil || mode == .doubleCommandC) && event.isCommand && !event.isControl && !event.isAlternate {
            let delta = event.timestamp - lastCmdTimestamp
            if lastCmdTimestamp > 0 && delta < minDebounceSeconds {
                return nil
            }
            if lastCmdTimestamp > 0 && delta <= windowSeconds {
                lastCmdTimestamp = 0 // Consumed! Prevents duplicate triple-tap triggers
                return .doubleCommandC
            } else {
                lastCmdTimestamp = event.timestamp
                return nil
            }
        }
        
        // 3. Double Control-C
        if (mode == nil || mode == .doubleControlC) && event.isControl && !event.isCommand && !event.isAlternate {
            let delta = event.timestamp - lastCtrlTimestamp
            if lastCtrlTimestamp > 0 && delta < minDebounceSeconds {
                return nil
            }
            if lastCtrlTimestamp > 0 && delta <= windowSeconds {
                lastCtrlTimestamp = 0 // Consumed!
                return .doubleControlC
            } else {
                lastCtrlTimestamp = event.timestamp
                return nil
            }
        }
        
        return nil
    }
}

/// Global Hotkey Manager coordinating CGEventTap, self-healing, and event dispatch.
public final class HotkeyManager: @unchecked Sendable {
    public static let shared = HotkeyManager()
    
    public let detector: DoubleTapDetector
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var clipboardTimer: Timer?
    private var carbonEventHandler: EventHandlerRef?
    private var alternateHotKeyRef: EventHotKeyRef?
    private var lastPasteboardCount: Int = 0
    private var lastPasteboardTimestamp: TimeInterval = 0
    private var lastDispatchTimestamp: TimeInterval = 0
    private var ignoreClipboardUntil: TimeInterval = 0
    private let stateLock = NSLock()
    
    public var onTrigger: (@Sendable () -> Void)?
    public var onDetailedTrigger: (@Sendable (HotkeyTriggerType) -> Void)?
    
    public var mode: HotkeyMode? {
        get { detector.mode }
        set { detector.mode = newValue }
    }
    
    public var windowMs: Double {
        get { detector.windowSeconds * 1000.0 }
        set { detector.windowSeconds = newValue / 1000.0 }
    }
    
    public func setMode(_ mode: HotkeyMode) {
        self.mode = mode
        if mode == .alternate {
            installCarbonHotKeys()
        } else {
            uninstallCarbonHotKeys()
        }
    }
    
    public func setTimingWindow(_ seconds: TimeInterval) {
        self.windowMs = seconds * 1000.0
    }
    
    public init(mode: HotkeyMode? = nil, windowMs: Double = 400.0) {
        self.detector = DoubleTapDetector(mode: mode, windowSeconds: windowMs / 1000.0)
    }
    
    /// Conforms to PROJECT.md: func startListening(onTrigger: @escaping () -> Void)
    public func startListening(onTrigger: @escaping @Sendable () -> Void) {
        self.onTrigger = onTrigger
        start()
    }
    
    /// Conforms to PROJECT.md: func stopListening()
    public func stopListening() {
        stop()
    }
    
    public func start() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        stopInternal()
        
        // Strategy 1: Low-level CGEventTap (.listenOnly)
        let mask = (1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleCGEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        )
        
        if let eventTap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            if let runLoopSource = runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
        
        // Strategy 2: NSEvent monitors (active in parallel for reliable event capture)
        installNSEventMonitors()
        
        // Strategy 3: Carbon Hotkeys (only if alternate mode is selected, to avoid intercepting ⌥Space from other apps like Gemini)
        if mode == .alternate {
            installCarbonHotKeys()
        }
        
        // Strategy 4: Pasteboard double-copy monitor (zero-permission guaranteed fallback for double ⌘C)
        startClipboardMonitor()
    }
    
    public func stop() {
        stateLock.lock()
        defer { stateLock.unlock() }
        stopInternal()
    }
    
    private func stopInternal() {
        uninstallCarbonHotKeys()
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            self.eventTap = nil
            self.runLoopSource = nil
        }
        
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.clipboardTimer?.invalidate()
            self?.clipboardTimer = nil
        }
        
        detector.reset()
    }
    
    public func temporarilyIgnoreClipboard(duration: TimeInterval = 1.2) {
        stateLock.lock()
        defer { stateLock.unlock() }
        ignoreClipboardUntil = ProcessInfo.processInfo.systemUptime + duration
        lastPasteboardCount = NSPasteboard.general.changeCount
        lastPasteboardTimestamp = 0
    }
    
    private func startClipboardMonitor() {
        lastPasteboardCount = NSPasteboard.general.changeCount
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.clipboardTimer?.invalidate()
            self.clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                self.stateLock.lock()
                let isIgnored = now < self.ignoreClipboardUntil
                self.stateLock.unlock()
                
                let current = NSPasteboard.general.changeCount
                if current != self.lastPasteboardCount {
                    self.lastPasteboardCount = current
                    if isIgnored {
                        self.lastPasteboardTimestamp = 0
                        return
                    }
                    let delta = now - self.lastPasteboardTimestamp
                    let win = max(self.detector.windowSeconds, 0.65)
                    if self.lastPasteboardTimestamp > 0 && delta <= win && delta >= 0.02 {
                        self.lastPasteboardTimestamp = 0
                        // Pasteboard changed twice within timing window => user pressed Cmd+C twice!
                        self.dispatchTrigger(.doubleCommandC)
                    } else {
                        self.lastPasteboardTimestamp = now
                    }
                }
            }
        }
    }
    
    private func handleCGEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Automatic Self-Healing on OS Timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }
        
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let isCmd = flags.contains(.maskCommand)
        let isCtrl = flags.contains(.maskControl)
        let isAlt = flags.contains(.maskAlternate)
        let timestamp = ProcessInfo.processInfo.systemUptime
        
        let keyEvent = KeyEvent(
            keyCode: keyCode,
            isCommand: isCmd,
            isControl: isCtrl,
            isAlternate: isAlt,
            timestamp: timestamp
        )
        
        if let trigger = detector.processKeyEvent(keyEvent) {
            dispatchTrigger(trigger)
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func installNSEventMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleNSEvent(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleNSEvent(event)
            return event
        }
    }
    
    private func handleNSEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        let flags = event.modifierFlags
        let isCmd = flags.contains(.command)
        let isCtrl = flags.contains(.control)
        let isAlt = flags.contains(.option)
        let timestamp = ProcessInfo.processInfo.systemUptime
        
        let keyEvent = KeyEvent(
            keyCode: keyCode,
            isCommand: isCmd,
            isControl: isCtrl,
            isAlternate: isAlt,
            timestamp: timestamp
        )
        
        if let trigger = detector.processKeyEvent(keyEvent) {
            dispatchTrigger(trigger)
        }
    }
    
    private func installCarbonHotKeys() {
        uninstallCarbonHotKeys()
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event = event, let userData = userData else { return noErr }
                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard status == noErr else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                if hkID.id == 1002 {
                    manager.dispatchTrigger(.alternate)
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &carbonEventHandler
        )
        guard status == noErr else { return }
        
        // Register Option+Space globally (kVK_Space = 49, optionKey = 0x0800)
        let altID = EventHotKeyID(signature: OSType(0x4D545241), id: 1002)
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            altID,
            GetEventDispatcherTarget(),
            0,
            &alternateHotKeyRef
        )
    }
    
    private func uninstallCarbonHotKeys() {
        if let ref = alternateHotKeyRef {
            UnregisterEventHotKey(ref)
            alternateHotKeyRef = nil
        }
        if let handler = carbonEventHandler {
            RemoveEventHandler(handler)
            carbonEventHandler = nil
        }
    }
    
    private func dispatchTrigger(_ trigger: HotkeyTriggerType) {
        stateLock.lock()
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastDispatchTimestamp < 0.40 {
            stateLock.unlock()
            return
        }
        lastDispatchTimestamp = now
        stateLock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            self?.onDetailedTrigger?(trigger)
            self?.onTrigger?()
        }
    }
}
