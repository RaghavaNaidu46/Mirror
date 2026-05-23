import Foundation
import SwiftUI
import AppKit
import Combine

/// Global app state. Holds the camera manager, user preferences, and
/// inter-feature coordination signals.
final class AppState: ObservableObject {
    let cameraManager = CameraManager()
    let preferences = Preferences.shared
    let micMonitor = MicMonitor()
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
}

struct SnapPreview: Equatable {
    let image: NSImage
    let dateText: String?
    let maskStyle: MaskStyle
}
