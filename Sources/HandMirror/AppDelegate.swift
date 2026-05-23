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

        if appState.preferences.onboardingComplete {
            appState.cameraManager.requestAccessAndStart()
        } else {
            showOnboarding()
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

    func showOnboarding() {
        if onboardingController == nil {
            onboardingController = OnboardingWindowController(appState: appState) { [weak self] in
                self?.onboardingController = nil
                self?.appState.cameraManager.requestAccessAndStart()
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
