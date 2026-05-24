import AppKit
import SwiftUI

/// Owns the NSStatusItem in the menu bar and the popover that shows the mirror.
/// Click → toggle popover; right-click / option-click → context menu.
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var detachedWindowController: MirrorWindowController?
    private var eventMonitor: Any?
    private var popoverCursorMonitor: Any?
    private var globalCursorMonitor: Any?
    private var firstLaunchHintPopover: NSPopover?

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        configureStatusItem()
        configurePopover()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIconChange),
            name: .menuBarIconChanged,
            object: nil
        )
    }

    deinit {
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleIconChange() { refreshStatusItemIcon() }

    // MARK: - Status item

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        refreshStatusItemIcon()
    }

    /// Hides or shows the menu bar item. Used in combination with Notch Trigger
    /// when the user wants to rely exclusively on the notch as the entry point.
    func setStatusItemVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }

    /// Reads the current MenuBarIcon preference and updates the status item glyph.
    /// Called on launch and whenever the user picks a different icon in Settings.
    func refreshStatusItemIcon() {
        guard let button = statusItem.button else { return }
        let choice = MenuBarIcon(rawValue: appState.preferences.menuBarIconName) ?? .defaultIcon
        let image = NSImage(systemSymbolName: choice.symbolName, accessibilityDescription: "HandMirror")
        image?.isTemplate = true
        button.image = image
    }

    /// Called by the global shortcut handler. Toggles whichever surface is currently
    /// the active mirror (detached window if present, otherwise the popover).
    func toggleFromShortcut() { primaryClick() }

    /// Tiny first-launch tooltip anchored under the menu bar icon — points the
    /// user at where the app lives. One-shot: AppDelegate sets the flag after
    /// calling this so it never appears again.
    func showFirstLaunchHint() {
        guard let button = statusItem.button else { return }
        // If the main popover happens to be open, don't double-stack.
        if popover.isShown { return }

        let hint = NSPopover()
        hint.behavior = .transient
        hint.animates = true
        let view = FirstLaunchHintView { [weak hint] in hint?.performClose(nil) }
        let hosting = NSHostingController(rootView: view)
        hint.contentSize = NSSize(width: 260, height: 110)
        hint.contentViewController = hosting
        firstLaunchHintPopover = hint
        NSApp.activate(ignoringOtherApps: true)
        hint.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    /// Triggered by the Take Snap global shortcut or by the right-click menu item.
    func requestSnap() {
        appState.snaps.takeSnap()
    }

    // MARK: - Popover

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let mirrorRoot = MirrorView()
            .environmentObject(appState)
            .environmentObject(appState.preferences)
            .environmentObject(appState.pro)
            .captureOpenSettings()
        popover.contentSize = appState.preferences.currentMirrorSize
        popover.contentViewController = NSHostingController(rootView: mirrorRoot)
    }

    // MARK: - Actions

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { primaryClick(); return }
        switch event.type {
        case .rightMouseUp:
            showMenu()
        case .leftMouseUp where event.modifierFlags.contains(.option):
            showMenu()
        default:
            primaryClick()
        }
    }

    /// Left-click behavior. When a detached window exists we toggle its visibility
    /// instead of opening the popover — otherwise the user would see two live
    /// previews side-by-side.
    private func primaryClick() {
        if appState.isDetached, let controller = detachedWindowController {
            toggleDetachedVisibility(controller)
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    /// Toggle the mirror anchored to a specific NSView — used by the Notch
    /// Trigger so the popover opens directly under the notch instead of jumping
    /// to the status item.
    func toggleMirrorAnchored(to view: NSView) {
        if appState.isDetached, let controller = detachedWindowController {
            toggleDetachedVisibility(controller)
            return
        }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        if appState.preferences.onboardingComplete == false { return }
        appState.cameraManager.requestAccessAndStart()
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        appState.isMirrorOpen = true
        appState.activeMirrorWindow = popover.contentViewController?.view.window
        startEventMonitor()
    }

    private func toggleDetachedVisibility(_ controller: MirrorWindowController) {
        guard let window = controller.window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            appState.cameraManager.requestAccessAndStart()
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        // Belt-and-braces: don't ever show the popover while a detached window is live.
        if appState.isDetached { return }
        appState.cameraManager.requestAccessAndStart()
        popover.contentSize = appState.preferences.currentMirrorSize
        // Activate the app so the popover's window becomes key and claims
        // cursor authority — otherwise the cursor inherits whatever the
        // previously-active app (Xcode, a text editor) last set.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        appState.isMirrorOpen = true
        appState.activeMirrorWindow = popover.contentViewController?.view.window
        startEventMonitor()
        startPopoverCursorMonitors()
    }

    func popoverDidClose(_ notification: Notification) {
        appState.isMirrorOpen = false
        appState.activeMirrorWindow = nil
        // If the user dismissed the popover with an in-progress snap, cancel it
        // — we don't want it lingering when they reopen the mirror.
        appState.snapPreview = nil
        stopEventMonitor()
        stopPopoverCursorMonitors()
        if !appState.isDetached {
            appState.cameraManager.stop()
        }
    }

    // MARK: - Cursor enforcement
    //
    // NSPopover's window doesn't fully claim cursor authority — the cursor
    // sometimes inherits whatever the window underneath last set (e.g. an
    // I-beam from Xcode's source editor). Tracking areas and SwiftUI hover
    // modifiers aren't consistent enough on their own. So while the popover
    // is open, we install both a local and a global mouse-moved monitor and
    // force `NSCursor.arrow.set()` on every event that lands within the
    // popover window's frame.

    private func startPopoverCursorMonitors() {
        stopPopoverCursorMonitors()

        let handler: (NSEvent) -> Void = { [weak self] _ in
            guard let self,
                  let window = self.popover.contentViewController?.view.window,
                  window.isVisible
            else { return }
            // While the snap editor is up, `PaintCanvasOverlay` owns the
            // cursor over the polaroid (pencil). Forcing arrow here would
            // make the cursor flicker between pencil and arrow as the
            // monitor fires for every mouse-move event.
            if self.appState.snapPreview != nil { return }
            if window.frame.contains(NSEvent.mouseLocation) {
                NSCursor.arrow.set()
            }
        }

        popoverCursorMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            handler(event)
            return event
        }
        globalCursorMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { event in
            handler(event)
        }
    }

    private func stopPopoverCursorMonitors() {
        if let monitor = popoverCursorMonitor {
            NSEvent.removeMonitor(monitor)
            popoverCursorMonitor = nil
        }
        if let monitor = globalCursorMonitor {
            NSEvent.removeMonitor(monitor)
            globalCursorMonitor = nil
        }
    }

    // Close the popover when the user clicks outside of it.
    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover.performClose(nil)
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Right-click menu (mirrors the reference app's status-bar dropdown)

    private func showMenu() {
        let menu = NSMenu()

        // 1. Camera list at top, with ✓ next to the current device.
        let cameras = appState.cameraManager.availableCameras
        if cameras.isEmpty {
            let placeholder = menu.addItem(withTitle: "No cameras found", action: nil, keyEquivalent: "")
            placeholder.isEnabled = false
        } else {
            for camera in cameras {
                let item = menu.addItem(withTitle: camera.localizedName,
                                        action: #selector(menuSelectCamera(_:)),
                                        keyEquivalent: "")
                item.target = self
                item.representedObject = camera.uniqueID
                if camera.uniqueID == appState.cameraManager.currentDevice?.uniqueID {
                    item.state = .on
                }
            }
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Open Mirror", action: #selector(menuOpen), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Detach Window", action: #selector(menuDetach), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "HandMirror Plus…", action: #selector(menuPlus), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(menuSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Reset Onboarding", action: #selector(menuResetOnboarding), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quit HandMirror", action: #selector(menuQuit), keyEquivalent: "q").target = self

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Clear so left-click reverts to popover behavior on the next click.
        statusItem.menu = nil
    }

    @objc private func menuOpen() { primaryClick() }

    @objc private func menuDetach() {
        popover.performClose(nil)
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.appState.pro.canUsePlus {
                self.detachIntoWindow()
            } else {
                self.appState.showPaywall()
            }
        }
    }

    @objc private func menuSelectCamera(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let camera = appState.cameraManager.availableCameras.first(where: { $0.uniqueID == id })
        else { return }
        appState.cameraManager.selectDevice(camera)
    }

    @objc private func menuPlus() {
        Task { @MainActor [weak self] in self?.appState.showPaywall() }
    }

    @objc private func menuSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    @objc private func menuResetOnboarding() {
        appState.preferences.resetOnboarding()
        (NSApp.delegate as? AppDelegate)?.showOnboarding()
    }

    @objc private func menuQuit() { NSApp.terminate(nil) }

    private func openSettings() {
        // Relays through SettingsLink/openSettings — captured at app launch.
        SettingsOpener.shared.open()
    }

    // MARK: - Detach

    func detachIntoWindow() {
        if detachedWindowController == nil {
            detachedWindowController = MirrorWindowController(appState: appState) { [weak self] in
                self?.detachedWindowController = nil
            }
        }
        appState.isDetached = true
        appState.cameraManager.requestAccessAndStart()
        detachedWindowController?.showWindow(nil)
    }
}

/// Compact "you are here" pointer shown under the status item the first time
/// the user lands in the app post-onboarding.
private struct FirstLaunchHintView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                Text("You are here")
                    .font(.system(size: 15, weight: .semibold))
            }
            Text("HandMirror lives in your menu bar — click the icon any time to open your mirror.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Got it", action: onDismiss)
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 260)
    }
}
