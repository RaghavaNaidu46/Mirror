import AppKit

extension NSCursor {
    /// Custom cursor showing a full pencil — used over the Snap editor's
    /// drawing canvas so the user knows they're in "writing" mode. The
    /// `pencil` SF Symbol gives a proper pencil shape (tip + body + eraser)
    /// rather than just the bare tip.
    static let pencilTip: NSCursor = {
        let cfg = NSImage.SymbolConfiguration(pointSize: 26, weight: .regular)
        guard let symbol = NSImage(systemSymbolName: "pencil",
                                   accessibilityDescription: "Drawing")?
            .withSymbolConfiguration(cfg)
        else {
            return .crosshair
        }

        // The `pencil` glyph points down-left with the writing tip at the
        // bottom-left. The hot spot — the pixel the system treats as the
        // cursor's active "point" — sits at the very tip.
        let hot = NSPoint(x: 2, y: symbol.size.height - 2)
        return NSCursor(image: symbol, hotSpot: hot)
    }()
}
