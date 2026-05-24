import Foundation
import SwiftUI
import AppKit
import Combine

/// Global app state. Holds the camera manager, user preferences, the Pro
/// entitlement manager, and inter-feature coordination signals.
final class AppState: ObservableObject {
    let cameraManager = CameraManager()
    let preferences = Preferences.shared
    let micMonitor = MicMonitor()
    let pro: Pro
    lazy var snaps: SnapsService = SnapsService(appState: self)

    @Published var isMirrorOpen: Bool = false
    @Published var isDetached: Bool = false
    /// True for a few frames around a Snap capture — the SwiftUI mirror view
    /// hides its on-screen Snap button while this is set so the button doesn't
    /// end up in the saved screenshot.
    @Published var isCapturingSnap: Bool = false

    /// The currently visible mirror window (popover or detached). Set by
    /// `MenuBarController` and `MirrorWindowController`. Used by `SnapsService`
    /// to find which window to screenshot.
    weak var activeMirrorWindow: NSWindow?

    /// Non-nil while a Snap is being annotated. The mirror's host window
    /// (popover or detached) grows to show the editor below the camera preview.
    @Published var snapPreview: SnapPreview?

    /// Live countdown for the victory-gesture auto-snap. Set to 3 the moment a
    /// V-sign is detected, ticks down once per second, and at 0 the actual
    /// snap fires. The mirror surface renders the number on top of the
    /// preview while this is non-nil.
    @Published var snapCountdown: Int?

    /// When non-nil, the detached window is in a free-trial session for a
    /// non-Pro user. Expires at this Date; the mirror surface renders a
    /// countdown chip and `MenuBarController` schedules a one-shot to close
    /// the window + open the paywall at the deadline.
    @Published var detachTrialDeadline: Date?

    private var paywallController: PaywallWindowController?

    init() {
        self.pro = MainActor.assumeIsolated { Pro() }
    }

    /// Open the HandMirror Plus paywall window (or bring it forward if it's
    /// already open).
    @MainActor
    func showPaywall() {
        if let existing = paywallController {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = PaywallWindowController(pro: pro) { [weak self] in
            self?.paywallController = nil
        }
        paywallController = controller
        controller.showWindow(nil)
    }
}

struct SnapPreview: Equatable {
    let image: NSImage
    let dateText: String?
    let maskStyle: MaskStyle
}
