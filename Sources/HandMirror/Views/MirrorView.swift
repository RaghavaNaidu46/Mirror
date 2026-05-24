import SwiftUI
import AVFoundation

/// The view shown inside the menu bar popover (and inside the detached window).
/// Renders the camera preview, the user-selected mask shape with zoom/rotation,
/// the transient overlays (snap button, reactions toggle, mic meter, Saved
/// pill), and — when a Snap is in progress — the inline Polaroid editor below
/// the preview.
struct MirrorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var preferences: Preferences

    var body: some View {
        MirrorBody(appState: appState,
                   camera: appState.cameraManager,
                   preferences: preferences,
                   mic: appState.micMonitor)
    }
}

private struct MirrorBody: View {
    @ObservedObject var appState: AppState
    @ObservedObject var camera: CameraManager
    @ObservedObject var preferences: Preferences
    @ObservedObject var mic: MicMonitor
    @State private var snapSavedShown = false
    @State private var isHovering = false
    @State private var showReactionsBar = false
    @State private var hideReactionsTask: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 12) {
            mirrorSurface

            if let preview = appState.snapPreview {
                SnapEditorView(
                    image: preview.image,
                    dateText: preview.dateText,
                    maskStyle: preview.maskStyle,
                    onSave: { data in appState.snaps.saveSnap(data) },
                    onCancel: { appState.snaps.dismissEditor() }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, appState.snapPreview != nil ? 12 : 0)
        .padding(.horizontal, appState.snapPreview != nil ? 12 : 0)
        .animation(.easeInOut(duration: 0.2), value: appState.snapPreview != nil)
        .onAppear { syncMic() }
        .onDisappear {
            mic.stop()
            showReactionsBar = false
        }
        .onChange(of: preferences.micCheckEnabled) { _, _ in syncMic() }
        .onReceive(NotificationCenter.default.publisher(for: .snapSaved)) { _ in
            withAnimation(.easeOut(duration: 0.15)) { snapSavedShown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeIn(duration: 0.3)) { snapSavedShown = false }
            }
        }
    }

    // MARK: - Mirror surface (camera + overlays)

    private var mirrorSurface: some View {
        ZStack {
            switch camera.authorizationStatus {
            case .authorized:
                CameraPreviewView(
                    session: camera.session,
                    mirrored: preferences.mirrorHorizontally
                )
                .scaleEffect(CGFloat(preferences.maskZoom))
                .rotationEffect(.degrees(preferences.maskRotation))
            case .notDetermined:
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for camera permission…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            default:
                deniedView
            }

            // Every interactive / informational overlay is hidden during a
            // snap capture so it doesn't end up in the saved screenshot.
            if shouldShowMicMeter && !appState.isCapturingSnap {
                MicMeterView(monitor: mic)
                    .padding(.bottom, overlayBottomInset)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if preferences.reactionsTriggersVisible && showReactionsBar && !appState.isCapturingSnap {
                reactionsOverlay
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if preferences.reactionsTriggersVisible && !showReactionsBar && !appState.isCapturingSnap {
                reactionsToggleButton
                    .padding(.bottom, overlayCornerInset)
                    .padding(.leading, overlayCornerInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .opacity(isHovering ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            }

            if preferences.snapsEnabled && !appState.isCapturingSnap && appState.snapPreview == nil {
                snapButton
                    .padding(.bottom, overlayCornerInset)
                    .padding(.trailing, overlayCornerInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .opacity(isHovering ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            }

            if appState.snapPreview == nil && !appState.isCapturingSnap {
                settingsLinkButton
                    .padding(.top, overlayCornerInset)
                    .padding(.trailing, overlayCornerInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .opacity(isHovering ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            }

            if snapSavedShown {
                savedPill
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(width: preferences.currentMirrorSize.width,
               height: preferences.currentMirrorSize.height)
        .background(Color.black)
        .clipShape(currentShape)
        .contentShape(currentShape)
        .onHover { hovering in
            isHovering = hovering
            // Skip while the snap editor is active — PaintCanvasOverlay owns
            // the cursor (pencil) over the polaroid, and racing it from here
            // makes the cursor blink during layout transitions.
            if hovering && appState.snapPreview == nil { NSCursor.arrow.set() }
        }
        .onContinuousHover { phase in
            // Fires on every cursor-position update while the mouse is over
            // the mirror — keeps the arrow cursor sticky even when AppKit
            // tries to inherit something else (e.g. the I-beam from a text
            // editor behind the popover). Same snap-editor exception as above.
            if case .active = phase, appState.snapPreview == nil {
                NSCursor.arrow.set()
            }
        }
    }

    private var shouldShowMicMeter: Bool {
        guard preferences.micCheckEnabled else { return false }
        return preferences.micCheckShowOnHover ? isHovering : true
    }

    /// Push corner buttons (snap, reactions toggle, settings gear) inward
    /// when the mask is a circle so they stay inside the visible region.
    /// Derived from geometry: the corner of the bounding square sits
    /// `radius·(1 - 1/√2)` beyond the circle's edge at 45° — plus margin so
    /// the button doesn't kiss the curve. Scales with the window size.
    private var overlayCornerInset: CGFloat {
        guard MaskStyle(rawValue: preferences.maskStyle) == .circle else { return 12 }
        let radius = preferences.currentMirrorSize.width / 2
        // Geometric: distance from the bounding-square corner to where the
        // circle's edge crosses the 45° diagonal. A circular button's
        // bounding-box corner extends ~16·(1-1/√2)≈4.7pt past the button's
        // visible edge, so this naturally leaves a small margin — no extra
        // padding needed.
        return radius * (1 - 1.0 / sqrt(2.0))
    }

    /// In circle mode we lay reactions along a bottom arc inside the mirror;
    /// otherwise it's the regular horizontal capsule pinned to the bottom.
    @ViewBuilder
    private var reactionsOverlay: some View {
        let isCircle = MaskStyle(rawValue: preferences.maskStyle) == .circle
        let trigger: (AVCaptureReactionType) -> Void = { reaction in
            camera.performReaction(reaction)
            scheduleReactionsAutoHide()
        }
        if isCircle {
            ReactionsBar(available: camera.availableReactions,
                         onTrigger: trigger,
                         layout: .arc)
                .frame(width: preferences.currentMirrorSize.width,
                       height: preferences.currentMirrorSize.height)
        } else {
            ReactionsBar(available: camera.availableReactions,
                         onTrigger: trigger,
                         layout: .capsule)
                .padding(.bottom, shouldShowMicMeter ? overlayBottomInset + 30 : overlayBottomInset)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    /// Push bottom-centered overlays (mic meter) up from the edge when the
    /// mask is a circle so they don't poke past the curve. Proportional to
    /// the window size.
    private var overlayBottomInset: CGFloat {
        guard MaskStyle(rawValue: preferences.maskStyle) == .circle else { return 14 }
        return preferences.currentMirrorSize.height * 0.18
    }

    private func syncMic() {
        if preferences.micCheckEnabled { mic.start() } else { mic.stop() }
    }

    private var snapButton: some View {
        Button {
            appState.snaps.takeSnap()
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.55), in: Circle())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .help("Take Snap")
    }

    /// Native `SettingsLink` button — opens the Settings scene via SwiftUI's
    /// canonical mechanism (the same one the NSMenu path now relays through).
    private var settingsLinkButton: some View {
        SettingsLink {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.55), in: Circle())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .help("Settings")
    }

    private var reactionsToggleButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { showReactionsBar = true }
            scheduleReactionsAutoHide()
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.55), in: Circle())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .help("Reactions")
    }

    private func scheduleReactionsAutoHide(delay: TimeInterval = 3.0) {
        hideReactionsTask?.cancel()
        let task = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.2)) { showReactionsBar = false }
        }
        hideReactionsTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private var savedPill: some View {
        Text("Saved")
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundStyle(.primary)
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
    }

    private var deniedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Camera access denied")
                .font(.headline)
            Text("Enable camera access in System Settings → Privacy & Security → Camera.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding()
        .foregroundStyle(.white)
    }

    private var currentShape: AnyShape {
        switch MaskStyle(rawValue: preferences.maskStyle) ?? .defaultChrome {
        case .defaultChrome: return AnyShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .square:        return AnyShape(Rectangle())
        case .circle:        return AnyShape(Circle())
        }
    }
}
