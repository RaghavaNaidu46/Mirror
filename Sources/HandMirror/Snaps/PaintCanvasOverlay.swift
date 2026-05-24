import SwiftUI
import AppKit

/// Transparent NSView placed on top of the SwiftUI drawing Canvas. Its job:
///   1. Capture mouse events for drawing strokes (forwarded via closures).
///   2. Override `mouseDownCanMoveWindow = false` so dragging inside the
///      polaroid annotates the photo rather than dragging the detached
///      window. Other parts of the window keep their normal background-drag
///      behavior — only this rectangle blocks it.
///   3. Set the pencil cursor on entry / restore arrow on exit via an
///      `NSTrackingArea` (more reliable than `addCursorRect` when an NSView
///      is hosted inside SwiftUI's view hierarchy).
struct PaintCanvasOverlay: NSViewRepresentable {
    let onPoint: (CGPoint) -> Void
    let onEnd: () -> Void

    func makeNSView(context: Context) -> PaintNSView {
        let view = PaintNSView()
        view.onPoint = onPoint
        view.onEnd = onEnd
        return view
    }

    func updateNSView(_ nsView: PaintNSView, context: Context) {
        nsView.onPoint = onPoint
        nsView.onEnd = onEnd
    }
}

final class PaintNSView: NSView {
    var onPoint: (CGPoint) -> Void = { _ in }
    var onEnd: () -> Void = {}

    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }            // match SwiftUI top-down Y
    override var mouseDownCanMoveWindow: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.pencilTip.set()
    }

    override func mouseMoved(with event: NSEvent) {
        // Cocoa sometimes drops back to the arrow as the cursor moves; keep
        // the pencil active across the whole drawing area.
        NSCursor.pencilTip.set()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.pencilTip.set()
        forward(event)
    }

    override func mouseDragged(with event: NSEvent) {
        NSCursor.pencilTip.set()
        forward(event)
    }

    override func mouseUp(with event: NSEvent) {
        onEnd()
    }

    /// Register the pencil as the *native* cursor for this rect with AppKit's
    /// cursor-rect manager. Without this, fast cursor movement into the
    /// polaroid briefly shows the arrow (system default) between events
    /// because the tracking-area `mouseEntered`/`mouseMoved` callbacks
    /// haven't caught up yet.
    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .pencilTip)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.invalidateCursorRects(for: self)
    }

    private func forward(_ event: NSEvent) {
        onPoint(convert(event.locationInWindow, from: nil))
    }
}
