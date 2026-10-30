import AppKit
import Foundation

@MainActor
public protocol FloatingHUDPanelDelegate: AnyObject {
    func floatingHUDPanelDidDismiss(_ panel: FloatingHUDPanel)
}

/// Floating, non-activating NSPanel for instantaneous HUD display without stealing focus.
public final class FloatingHUDPanel: NSPanel {
    public weak var panelDelegate: FloatingHUDPanelDelegate?
    public let hudContentView: HUDContentView
    
    private var globalClickMonitor: Any?
    
    public init() {
        self.hudContentView = HUDContentView(frame: NSRect(x: 0, y: 0, width: 480, height: 280))
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 280),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = hudContentView
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
    
    public override func cancelOperation(_ sender: Any?) {
        dismiss()
    }
    
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let isVKey = (event.keyCode == 9)
        let hasCmd = event.modifierFlags.contains(.command)
        let hasCtrl = event.modifierFlags.contains(.control)
        if isVKey && (hasCmd || hasCtrl) {
            let target = hudContentView.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !target.isEmpty {
                hudContentView.replaceClicked()
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    public override func keyDown(with event: NSEvent) {
        // Handle Escape
        if event.keyCode == 53 {
            dismiss()
            return
        }
        let isVKey = (event.keyCode == 9)
        let hasCmd = event.modifierFlags.contains(.command)
        let hasCtrl = event.modifierFlags.contains(.control)
        if isVKey && (hasCmd || hasCtrl) {
            let target = hudContentView.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !target.isEmpty {
                hudContentView.replaceClicked()
                return
            }
        }
        super.keyDown(with: event)
    }
    
    /// Positions and presents the panel near the cursor or center of screen.
    public func showNearCursor() {
        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let screenRect = screen.visibleFrame
        
        let panelWidth: CGFloat = 490
        let panelHeight: CGFloat = 315
        
        // Target position: slightly offset from mouse cursor
        var targetX = mouseLoc.x + 12
        var targetY = mouseLoc.y - panelHeight - 12
        
        // Clamp to screen bounds
        if targetX + panelWidth > screenRect.maxX {
            targetX = screenRect.maxX - panelWidth - 10
        }
        if targetX < screenRect.minX {
            targetX = screenRect.minX + 10
        }
        
        if targetY < screenRect.minY {
            targetY = mouseLoc.y + 20
        }
        if targetY + panelHeight > screenRect.maxY {
            targetY = screenRect.maxY - panelHeight - 10
        }
        
        setFrame(NSRect(x: targetX, y: targetY, width: panelWidth, height: panelHeight), display: true)
        
        makeKeyAndOrderFront(nil)
        setupOutsideClickMonitor()
    }
    
    public func dismiss() {
        orderOut(nil)
        removeOutsideClickMonitor()
        panelDelegate?.floatingHUDPanelDidDismiss(self)
    }
    
    private func setupOutsideClickMonitor() {
        removeOutsideClickMonitor()
        
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            Task { @MainActor in
                if PreferencesManager.shared.autoDismissOnBlur {
                    let clickLocation = NSEvent.mouseLocation
                    if !NSPointInRect(clickLocation, self.frame) {
                        self.dismiss()
                    }
                }
            }
        }
    }
    
    private func removeOutsideClickMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
    
    isolated deinit {
        removeOutsideClickMonitor()
    }
}
