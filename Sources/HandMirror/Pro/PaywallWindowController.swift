import AppKit
import SwiftUI

/// Hosts the Plus paywall in its own borderless-content window. Opens centered,
/// closes when the user buys, restores, or hits the close button.
final class PaywallWindowController: NSWindowController, NSWindowDelegate {
    private let pro: Pro
    private let onClose: () -> Void

    init(pro: Pro, onClose: @escaping () -> Void) {
        self.pro = pro
        self.onClose = onClose

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 720),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "HandMirror Plus"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()

        super.init(window: window)
        window.delegate = self

        let root = PaywallView()
            .environmentObject(pro)
        window.contentView = NSHostingView(rootView: root)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func showWindow(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        super.showWindow(sender)
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
