import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Captures the current mirror window into a polaroid preview hosted inline in
/// the same popover / detached window (`AppState.snapPreview`). The user can
/// then annotate the polaroid via `SnapEditorView`; on save we flatten and
/// write a PNG to disk.
final class SnapsService {
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Capture

    func takeSnap() {
        Task { @MainActor [weak self] in
            self?.performSnap()
        }
    }

    @MainActor
    private func performSnap() {
        guard let appState else { return }
        // Ignore taps if an editor is already showing for the previous snap.
        guard appState.snapPreview == nil else { return }

        // Hide on-screen UI for a frame so it isn't captured.
        appState.isCapturingSnap = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.captureAndPresent()
            appState.isCapturingSnap = false
        }
    }

    @MainActor
    private func captureAndPresent() {
        guard let appState,
              let window = appState.activeMirrorWindow,
              window.isVisible
        else {
            NSSound.beep()
            return
        }

        let windowID = CGWindowID(window.windowNumber)
        guard let rawImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            NSSound.beep()
            return
        }

        // The popover window includes its arrow — crop down to the inner
        // content view so the snap is just the mirror content. For the
        // detached NSPanel, contentView fills the whole window so this is a
        // no-op.
        let cgImage = cropToContentArea(image: rawImage, window: window) ?? rawImage

        let image = NSImage(cgImage: cgImage, size: .init(width: cgImage.width, height: cgImage.height))
        let dateText = appState.preferences.snapsIncludeDate ? handwrittenDateString() : nil
        let maskStyle = MaskStyle(rawValue: appState.preferences.maskStyle) ?? .defaultChrome

        appState.snapPreview = SnapPreview(
            image: image,
            dateText: dateText,
            maskStyle: maskStyle
        )
    }

    /// Crops a window screenshot down to the window's `contentView` frame,
    /// removing any non-content chrome (in our case, NSPopover's arrow).
    @MainActor
    private func cropToContentArea(image: CGImage, window: NSWindow) -> CGImage? {
        guard let contentView = window.contentView else { return image }
        let scale = window.backingScaleFactor
        let contentInWindow = contentView.frame   // bottom-up window coordinates
        let windowHeight = window.frame.height

        // CGImage coords are top-down — flip Y.
        let cropX = contentInWindow.minX * scale
        let cropY = (windowHeight - contentInWindow.maxY) * scale
        let cropW = contentInWindow.width * scale
        let cropH = contentInWindow.height * scale

        let rect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
            .integral
        return image.cropping(to: rect)
    }

    // MARK: - Save (called from the inline editor)

    func dismissEditor() {
        appState?.snapPreview = nil
    }

    func saveSnap(_ data: Data) {
        guard let appState else { return }
        // Don't clear snapPreview here — the editor itself runs a brief "Saved"
        // toast and then dismisses via `onCancel`.
        save(data, preferences: appState.preferences)
    }

    private func save(_ data: Data, preferences: Preferences) {
        let filename = "HandMirror Snap \(filenameTimestamp()).png"

        if preferences.snapsAutoSave, !preferences.snapsSaveLocation.isEmpty {
            let url = URL(fileURLWithPath: preferences.snapsSaveLocation).appendingPathComponent(filename)
            do {
                try data.write(to: url)
                announceSaved(at: url)
            } catch {
                presentSavePanel(data: data, suggested: filename)
            }
        } else {
            presentSavePanel(data: data, suggested: filename)
        }

        if preferences.snapsFreeRemaining > 0 {
            preferences.snapsFreeRemaining -= 1
        }
    }

    private func presentSavePanel(data: Data, suggested: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggested
        panel.allowedContentTypes = [.png]
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
            announceSaved(at: url)
        }
    }

    private func announceSaved(at url: URL) {
        NotificationCenter.default.post(name: .snapSaved, object: url)
    }

    // MARK: - Formatting

    private func handwrittenDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date())
    }

    private func filenameTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: Date())
    }
}

extension Notification.Name {
    static let snapSaved = Notification.Name("snapSaved")
}
