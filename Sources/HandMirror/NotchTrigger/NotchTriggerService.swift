import AppKit

/// Places a transparent click-catcher panel over the display notch. A click in
/// the notch area routes to `MenuBarController.primaryClick()` — the same path
/// as clicking the menu bar icon. Only installs on displays that actually have
/// a notch (i.e. `safeAreaInsets.top > 0`).
final class NotchTriggerService {
    private weak var appState: AppState?
    private weak var menuBarController: MenuBarController?
    private var clickPanel: NSPanel?
    private var screenObserver: NSObjectProtocol?

    init(appState: AppState, menuBarController: MenuBarController) {
        self.appState = appState
        self.menuBarController = menuBarController

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.reinstallIfEnabled() }
    }

    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        uninstall()
    }

    var hasNotch: Bool {
        (NSScreen.main?.safeAreaInsets.top ?? 0) > 0
    }

    func setEnabled(_ enabled: Bool) {
        if enabled, hasNotch {
            install()
        } else {
            uninstall()
        }
    }

    private func reinstallIfEnabled() {
        guard let preferences = appState?.preferences, preferences.notchTriggerEnabled else { return }
        uninstall()
        install()
    }

    // MARK: - Click panel

    private func install() {
        guard clickPanel == nil, let screen = NSScreen.main else { return }
        let notchHeight = screen.safeAreaInsets.top
        let notchWidth: CGFloat = 220
        let notchOrigin = NSPoint(
            x: screen.frame.midX - notchWidth / 2,
            y: screen.frame.maxY - notchHeight
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: notchOrigin, size: NSSize(width: notchWidth, height: notchHeight)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.001) // imperceptible, still hit-testable
        panel.level = .statusBar + 1
        panel.ignoresMouseEvents = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let clickView = NotchClickView { [weak self] anchor in
            self?.menuBarController?.toggleMirrorAnchored(to: anchor)
        }
        panel.contentView = clickView
        panel.orderFront(nil)
        clickPanel = panel
    }

    private func uninstall() {
        clickPanel?.orderOut(nil)
        clickPanel = nil
    }
}

private final class NotchClickView: NSView {
    let onClick: (NSView) -> Void

    init(onClick: @escaping (NSView) -> Void) {
        self.onClick = onClick
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func mouseDown(with event: NSEvent) {
        onClick(self)
    }
}
