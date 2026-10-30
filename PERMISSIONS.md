# Privacy & macOS Permissions Guide

**MacTranslate** is designed with a strict **local-first, privacy-by-design** philosophy. It requires **no network connectivity** to function, collects **zero analytics or telemetry**, and does not write your clipboard content or translated text to disk or cloud servers.

This document transparently explains the permissions MacTranslate requests, why they are required, how they are used, and how your privacy is protected.

---

## 1. Required Permission: Accessibility (`AXIsProcessTrusted`)

To provide a seamless workflow comparable to tools like DeepL, Alfred, or Raycast, MacTranslate asks for **Accessibility** permission in macOS:
`System Settings` ➔ `Privacy & Security` ➔ `Accessibility`.

### Why is this needed?

| Capability | Technical Mechanism | Why It Needs Accessibility |
| :--- | :--- | :--- |
| **Global Trigger (`⌘C + C`)** | `CGEventTap` & `NSEvent` global monitor | macOS restricts background utilities from detecting keyboard combinations pressed in other applications unless granted Accessibility trust. |
| **Selected Text Extraction** | Accessibility Element hierarchy (`AXUIElementCopyAttributeValue`) | When triggered via alternate hotkeys (e.g., `⌥Space`), MacTranslate attempts to inspect the active text selection directly without overwriting the user's pasteboard history. |
| **Replace Selected Text** | Synthetic keystroke insertion (`⌘V` event post) | If you enable *"Replace selected text directly"*, MacTranslate automatically pastes the translated result back into your target editor (Safari, Slack, Xcode, Mail, etc.). |

### What MacTranslate NEVER does:
- ❌ **No Keylogging**: MacTranslate does not log or record any keystrokes. The event tap strictly monitors for the `C` key code (8) combined with the Command modifier within a small double-tap timing window (default 650 ms). All other key events pass through completely untouched and unrecorded.
- ❌ **No Background Audio or Screen Capture**: MacTranslate has zero screen recording (`ScreenCaptureKit`), camera, or microphone permissions.
- ❌ **No Network Access**: The app runs offline on the Apple Neural Engine (`Translation.framework` on Apple Silicon). No text is ever uploaded to external APIs.

---

## 2. Zero-Permission Fallback Architecture

Even if you prefer **not** to grant Accessibility permissions, MacTranslate will still function:

1. **Pasteboard Change Count Monitoring**:
   macOS exposes `NSPasteboard.general.changeCount` as an unprivileged, sandboxed property. When you press `⌘C` twice quickly in any app, the system clipboard changes twice within 650 ms. MacTranslate detects this timing pattern with **zero permissions required**, reading only the copied string and immediately displaying the floating HUD.
2. **Status Bar Menu Bar Launcher**:
   You can click the `文/A` menu bar icon at any time and select **Translate Selection** (`⌘T`) to trigger translation with zero accessibility requirements.

---

## 3. How to Grant or Reset Permissions

### Step-by-Step Granting Guide
1. Launch **MacTranslate**.
2. If permissions are missing, click **Open Privacy Settings** in the Settings window (`⌘,`) or the Status Bar menu.
3. In macOS **System Settings** ➔ **Privacy & Security** ➔ **Accessibility**:
   - Locate `MacTranslate`.
   - Toggle the switch to **ON** (enter your Touch ID / password when prompted).
4. If MacTranslate is not in the list, click the **`+`** button, navigate to `/Applications`, and select `MacTranslate.app`.

### Troubleshooting Permission Invalidation (Code Signature Updates)
Whenever a native macOS application binary is recompiled or updated outside the Mac App Store, macOS TCC (Transparency, Consent, and Control) security subsystem may temporarily mark the existing Accessibility permission as invalid or stale.

If `⌘C + C` stops responding after updating the app:
1. Open **System Settings** ➔ **Privacy & Security** ➔ **Accessibility**.
2. Select **MacTranslate** and click the **`-`** (minus) button to remove the old entry.
3. Relaunch **MacTranslate** and toggle it back on when prompted.
