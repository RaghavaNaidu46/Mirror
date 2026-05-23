import KeyboardShortcuts

/// Global hotkeys exposed via the KeyboardShortcuts package.
/// The user binds these in Settings → General; the actual handler is attached in
/// `AppDelegate.applicationDidFinishLaunching`.
extension KeyboardShortcuts.Name {
    static let toggleMirror = Self("toggleMirror")
    static let takeSnap     = Self("takeSnap")
}
