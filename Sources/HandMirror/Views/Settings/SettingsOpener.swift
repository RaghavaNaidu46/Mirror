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

    /// Opens the Settings scene reliably. Both paths run — the captured
    /// `openSettings` closure (set by `SettingsLink`/`@Environment` in any
    /// rendered SwiftUI view) plus the responder-chain selector that
    /// `SettingsLink` ultimately invokes. If the captured closure has been
    /// invalidated (e.g. the SwiftUI surface that owned it was torn down),
    /// the selector path still opens the window.
    func open() {
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.action?()
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)

            // Belt-and-braces: a beat later, find the Settings window and
            // bring it to the front explicitly. SwiftUI's open-settings
            // action sometimes leaves the window key-but-buried behind a
            // newly-activated app.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                for window in NSApp.windows
                where window.title.lowercased().contains("setting")
                   || window.title.lowercased().contains("preference") {
                    window.makeKeyAndOrderFront(nil)
                    break
                }
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
