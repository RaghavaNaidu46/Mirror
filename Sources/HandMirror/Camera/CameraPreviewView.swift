import SwiftUI
import AVFoundation
import AppKit

/// SwiftUI wrapper around AVCaptureVideoPreviewLayer. The layer renders the
/// camera feed directly on the GPU — far cheaper than piping CMSampleBuffers
/// through SwiftUI.
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    var mirrored: Bool = true

    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        applyMirror(on: view)
        return view
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        if nsView.previewLayer.session !== session {
            nsView.previewLayer.session = session
        }
        applyMirror(on: nsView)
    }

    private func applyMirror(on view: PreviewNSView) {
        guard let connection = view.previewLayer.connection else { return }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }
}

final class PreviewNSView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()
    private var cursorTrackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer = CALayer()
        layer?.addSublayer(previewLayer)
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }

    // MARK: - Cursor reset
    //
    // NSPopover doesn't install cursor rects, and its window doesn't deliver
    // mouseMoved events until clicked. So when the popover appears, the cursor
    // inherits whatever the window beneath last claimed (e.g. an I-beam from a
    // text editor) and stays that way until the user clicks in.
    //
    // Fix: cover the preview with a tracking area for cursorUpdate + accept
    // first mouse so hover events fire from the moment the popover appears.

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = cursorTrackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .cursorUpdate,
                      .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        cursorTrackingArea = area
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Ensure the host window forwards mouse-moved events to this view even
        // before it becomes the key window — otherwise the tracking area
        // doesn't fire until the user clicks.
        window?.acceptsMouseMovedEvents = true
        // And reset the cursor immediately so the popover doesn't show whatever
        // the underlying window last claimed.
        NSCursor.arrow.set()
        window?.invalidateCursorRects(for: self)
    }

    /// Older AppKit cursor API — `resetCursorRects` + `addCursorRect` is what
    /// the cursor-rect manager actually consults on every mouse-move. Tracking
    /// areas alone don't reliably win cursor resolution inside an NSPopover's
    /// view hierarchy, so we register the rect explicitly here.
    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }
}
