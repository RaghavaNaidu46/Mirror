import SwiftUI
import Darwin

@main
struct HandMirrorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Suppress the Metal API debug-layer false positive that AVCapture's
        // reactions compositor triggers on Apple Silicon. The compositor calls
        // `didModifyRange:` on a Shared-mode buffer (a no-op on unified memory
        // but the validator catches it). The scheme also sets these, but we
        // belt-and-brace here in case the app is launched outside Xcode.
        setenv("MTL_DEBUG_LAYER", "0", 1)
        setenv("MTL_DEBUG_LAYER_ERROR_MODE", "nslog", 1)
    }

    var body: some Scene {
        Settings {
            SettingsRoot()
                .environmentObject(appDelegate.appState)
                .captureOpenSettings()
        }
    }
}
