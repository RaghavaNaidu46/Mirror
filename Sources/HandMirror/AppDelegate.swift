import AppKit
import SwiftUI
import KeyboardShortcuts
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private(set) var menuBarController: MenuBarController?
    private var notchTrigger: NotchTriggerService?
    private var onboardingController: OnboardingWindowController?
    private var preferenceObservers: [NSKeyValueObservation] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicy()
        let controller = MenuBarController(appState: appState)
        menuBarController = controller
        notchTrigger = NotchTriggerService(appState: appState, menuBarController: controller)
        registerGlobalShortcuts()
        observePreferences()
        syncNotchTrigger()
        syncMenuBarIconVisibility()
        wireVictoryAutoSnap()

        if appState.preferences.onboardingComplete {
            // Don't start the camera here — that flips the green privacy
            // indicator on while the user hasn't actually asked to see the
            // mirror yet. The first popover open will start it lazily.
            maybeShowFirstLaunchHint()
        } else {
            showOnboarding()
        }
    }

    private func maybeShowFirstLaunchHint() {
        // Shown every launch (post-onboarding) so the user is always reminded
        // where the app lives — not just on first install.
        // Defer a beat so the status item is laid out before we anchor to it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.menuBarController?.showFirstLaunchHint()
        }
    }

    private func observePreferences() {
        // Re-sync notch + status item visibility when relevant prefs change.
        appState.preferences.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.syncNotchTrigger()
                self?.syncMenuBarIconVisibility()
                self?.syncCenterStage()
            }
        }.store(in: &preferencesCancellables)
    }

    private var preferencesCancellables = Set<AnyCancellable>()

    private func syncNotchTrigger() {
        notchTrigger?.setEnabled(appState.preferences.notchTriggerEnabled)
    }

    private func syncMenuBarIconVisibility() {
        guard let controller = menuBarController else { return }
        let hasNotch = notchTrigger?.hasNotch ?? false
        let hidden = appState.preferences.hideMenuBarIconOnNotch && hasNotch
        controller.setStatusItemVisible(!hidden)
    }

    private func syncCenterStage() {
        appState.cameraManager.applyCenterStage()
    }

    /// AVCapture's `.balloons` reaction is what the V-sign / peace hand
    /// gesture maps to in macOS Sonoma+. When the system fires that, start a
    /// 3-second countdown on the mirror — then take the snap. The countdown
    /// gives the user time to pose and lets the balloon animation start to
    /// settle before capture. Only runs when the user is Pro (Snaps is a Plus
    /// feature) and the mirror is currently visible.
    private func wireVictoryAutoSnap() {
        appState.cameraManager.onVictoryReaction = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.appState.pro.canUsePlus else { return }
                guard self.appState.activeMirrorWindow != nil else { return }
                self.startVictoryCountdown()
            }
        }
    }

    @MainActor
    private func startVictoryCountdown() {
        // Already counting down or an editor is up — ignore the new trigger.
        guard appState.snapCountdown == nil else { return }
        guard appState.snapPreview == nil else { return }
        tickCountdown(from: 3)
    }

    @MainActor
    private func tickCountdown(from value: Int) {
        appState.snapCountdown = value
        if value <= 0 {
            appState.snapCountdown = nil
            appState.snaps.takeSnap()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            // Bail if the mirror was dismissed mid-countdown.
            guard self.appState.activeMirrorWindow != nil else {
                self.appState.snapCountdown = nil
                return
            }
            self.tickCountdown(from: value - 1)
        }
    }

    func showOnboarding() {
        if onboardingController == nil {
            onboardingController = OnboardingWindowController(appState: appState) { [weak self] in
                self?.onboardingController = nil
                // Don't start the camera here — same reasoning as launch.
                // First popover open will request access + start.
                self?.maybeShowFirstLaunchHint()
            }
        }
        onboardingController?.showWindow(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// LSUIElement is set to true in Info.plist (no Dock icon by default), but the
    /// user can flip the "Show icon in the Dock" preference at runtime.
    func applyActivationPolicy() {
        NSApp.setActivationPolicy(appState.preferences.showInDock ? .regular : .accessory)
    }

    private func registerGlobalShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .toggleMirror) { [weak self] in
            self?.menuBarController?.toggleFromShortcut()
        }
        KeyboardShortcuts.onKeyUp(for: .takeSnap) { [weak self] in
            self?.menuBarController?.requestSnap()
        }
    }
}
