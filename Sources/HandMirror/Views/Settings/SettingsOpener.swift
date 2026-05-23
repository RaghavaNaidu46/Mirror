import SwiftUI
import AppKit

/// Captures the SwiftUI `openSettings` environment action into a singleton so
/// AppKit code (the NSMenu in the status bar) can open the Settings scene.
///
/// SettingsLink is the canonical SwiftUI API for opening Settings, but NSMenuItem
/// can't host a SwiftUI view — so we relay through the captured `openSettings`
/// action. If the SwiftUI surface that captures the action hasn't rendered yet
/// (e.g. the user hits "Settings…" before ever opening the mirror), we fall
/// back to the standard responder-chain action so the window still opens.
final class SettingsOpener {
    static let shared = SettingsOpener()
    var action: (() -> Void)?

    /// Always dispatches to main — both NSMenu actions and SwiftUI render passes
    /// are on the main thread, but this keeps the contract explicit.
    func open() {
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            if let action = self?.action {
                action()
            } else {
                // Fallback before the SwiftUI environment has been captured.
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }
}

/// Attach this modifier to any SwiftUI surface that's reliably rendered during
/// app lifetime. It captures `openSettings` and stores it on `SettingsOpener`.
struct CaptureOpenSettings: ViewModifier {
    @Environment(\.openSettings) private var openSettings

    func body(content: Content) -> some View {
        content.task {
            SettingsOpener.shared.action = { openSettings() }
        }
    }
}

extension View {
    func captureOpenSettings() -> some View { modifier(CaptureOpenSettings()) }
}
