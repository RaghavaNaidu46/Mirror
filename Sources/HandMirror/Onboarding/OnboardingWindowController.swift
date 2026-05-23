import AppKit
import SwiftUI

/// Hosts the first-run onboarding flow in a standalone window. Activates the app
/// so the window appears on top and the user can interact normally.
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let appState: AppState
    private let onFinish: () -> Void

    init(appState: AppState, onFinish: @escaping () -> Void) {
        self.appState = appState
        self.onFinish = onFinish

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()

        super.init(window: window)
        window.delegate = self

        let root = OnboardingView(onFinish: { [weak self] in
            self?.close()
        })
        .environmentObject(appState)
        window.contentView = NSHostingView(rootView: root)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func showWindow(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        super.showWindow(sender)
    }

    func windowWillClose(_ notification: Notification) {
        onFinish()
    }
}
