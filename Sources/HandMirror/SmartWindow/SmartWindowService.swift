import AppKit
import Combine

/// Remembers the detached mirror window's position per (frontmost app, screen)
/// context. When the user moves the window, the position is saved against the
/// current context. When the context changes (frontmost app switches, screens
/// reconfigure) the window is restored to the position it last had in that
/// context.
final class SmartWindowService {
    private weak var window: NSWindow?
    private var workspaceObserver: NSObjectProtocol?
    private var windowMoveObserver: NSObjectProtocol?
    private let defaults = UserDefaults.standard
    private let storageKey = "smartWindowPositions"
    private var isEnabled: Bool = false

    func bind(to window: NSWindow) {
        self.window = window
    }

    func setEnabled(_ enabled: Bool) {
        if enabled, !isEnabled {
            isEnabled = true
            startObserving()
            restorePosition()
        } else if !enabled, isEnabled {
            isEnabled = false
            stopObserving()
        }
    }

    // MARK: - Observation

    private func startObserving() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.restorePosition()
        }

        if let window {
            windowMoveObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification, object: window, queue: .main
            ) { [weak self] _ in
                self?.savePosition()
            }
        }
    }

    private func stopObserving() {
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        if let windowMoveObserver { NotificationCenter.default.removeObserver(windowMoveObserver) }
        workspaceObserver = nil
        windowMoveObserver = nil
    }

    // MARK: - Context + storage

    private var contextKey: String {
        let bundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
        let screen = window?.screen?.localizedName ?? NSScreen.main?.localizedName ?? "main"
        return "\(bundle)|\(screen)"
    }

    private func savePosition() {
        guard let window, window.isVisible else { return }
        var positions = (defaults.dictionary(forKey: storageKey) as? [String: [String: CGFloat]]) ?? [:]
        positions[contextKey] = ["x": window.frame.origin.x, "y": window.frame.origin.y]
        defaults.set(positions, forKey: storageKey)
    }

    private func restorePosition() {
        guard let window, window.isVisible else { return }
        let positions = (defaults.dictionary(forKey: storageKey) as? [String: [String: CGFloat]]) ?? [:]
        if let dict = positions[contextKey], let x = dict["x"], let y = dict["y"] {
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
