import AppKit
import SwiftUI
import Combine

/// Hosts the detached mirror window — borderless, floating above other apps.
/// Used when the user "tears off" the popover into a free-floating window.
final class MirrorWindowController: NSWindowController, NSWindowDelegate {
    private let appState: AppState
    private let onClose: () -> Void
    private let smartWindow = SmartWindowService()
    private var cancellables = Set<AnyCancellable>()
    private var snapOutsideClickMonitor: Any?

    init(appState: AppState, onClose: @escaping () -> Void) {
        self.appState = appState
        self.onClose = onClose

        let initialSize = appState.preferences.currentMirrorSize
        let window = MirrorPanel(
            contentRect: NSRect(x: 100, y: 100, width: initialSize.width, height: initialSize.height),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = appState.preferences.alwaysOnTop ? .floating : .normal
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        super.init(window: window)
        window.delegate = self

        let root = DetachedMirrorView(onClose: { [weak window] in window?.close() })
            .environmentObject(appState)
            .environmentObject(appState.preferences)
            .environmentObject(appState.pro)
        window.contentView = NSHostingView(rootView: root)

        smartWindow.bind(to: window)
        smartWindow.setEnabled(appState.preferences.smartWindowEnabled)

        observeResizeTriggers()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        appState.activeMirrorWindow = window
    }

    func windowWillClose(_ notification: Notification) {
        if appState.activeMirrorWindow === window {
            appState.activeMirrorWindow = nil
        }
        appState.isDetached = false
        appState.cameraManager.stop()
        stopSnapOutsideMonitor()
        onClose()
    }

    /// Live-resize the window when the mask style, window-size slider, or the
    /// inline Snap editor visibility changes; also install / tear down the
    /// outside-click monitor that auto-cancels an in-progress snap.
    private func observeResizeTriggers() {
        let p1 = appState.preferences.$maskStyle.map { _ in () }
        let p2 = appState.preferences.$windowSize.map { _ in () }
        let p3 = appState.$snapPreview.map { _ in () }
        p1.merge(with: p2, p3)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resizeToFitContent(animated: true)
                self?.syncSnapOutsideMonitor()
            }
            .store(in: &cancellables)
    }

    /// While the inline Snap editor is showing, watch for clicks outside this
    /// window — clicking away cancels the in-progress snap so it doesn't
    /// linger the next time the user opens the mirror.
    private func syncSnapOutsideMonitor() {
        if appState.snapPreview != nil {
            guard snapOutsideClickMonitor == nil else { return }
            snapOutsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                self?.appState.snapPreview = nil
            }
        } else {
            stopSnapOutsideMonitor()
        }
    }

    private func stopSnapOutsideMonitor() {
        if let monitor = snapOutsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            snapOutsideClickMonitor = nil
        }
    }

    private func resizeToFitContent(animated: Bool) {
        guard let window else { return }
        let mirrorSize = appState.preferences.currentMirrorSize
        let target: NSSize
        if appState.snapPreview != nil {
            // SnapEditorView's intrinsic frame is roughly 432×500 (polaroidWidth+80
            // × polaroidHeight+80). The VStack adds vertical spacing between the
            // mirror and the editor; add a little horizontal padding too.
            let editorWidth: CGFloat = 432
            let editorHeight: CGFloat = 500
            let vstackSpacing: CGFloat = 12
            target = NSSize(
                width: max(mirrorSize.width, editorWidth) + 24,
                height: mirrorSize.height + vstackSpacing + editorHeight + 24
            )
        } else {
            target = NSSize(width: mirrorSize.width, height: mirrorSize.height)
        }
        // Keep the window centered on its current location (so the polaroid
        // appears below the mirror) then clamp to the screen's visible frame
        // so the snap editor never opens off-screen.
        var frame = window.frame
        let center = NSPoint(x: frame.midX, y: frame.midY)
        frame.size = target
        frame.origin.x = center.x - target.width / 2
        frame.origin.y = center.y - target.height / 2

        if let visible = (window.screen ?? NSScreen.main)?.visibleFrame {
            if frame.width <= visible.width {
                if frame.maxX > visible.maxX { frame.origin.x = visible.maxX - frame.width }
                if frame.minX < visible.minX { frame.origin.x = visible.minX }
            } else {
                frame.origin.x = visible.minX
            }
            if frame.height <= visible.height {
                if frame.maxY > visible.maxY { frame.origin.y = visible.maxY - frame.height }
                if frame.minY < visible.minY { frame.origin.y = visible.minY }
            } else {
                frame.origin.y = visible.minY
            }
        }

        window.setFrame(frame, display: true, animate: animated)
    }
}

/// Borderless panel that can still become key (so it accepts the drag gesture and
/// keyboard events like ⌘W / Escape to dismiss).
final class MirrorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        // Escape (keyCode 53) or ⌘W → close.
        if event.keyCode == 53 {
            close()
            return
        }
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "w" {
            close()
            return
        }
        super.keyDown(with: event)
    }
}
