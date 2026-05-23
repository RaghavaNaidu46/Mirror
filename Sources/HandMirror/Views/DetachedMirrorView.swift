import SwiftUI

/// Wraps `MirrorView` for the detached window. Adds a single hover-revealed
/// close button so the user can dismiss the floating window without leaving
/// for the menu bar. ⌘W and Escape also work via `MirrorPanel.keyDown`.
struct DetachedMirrorView: View {
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MirrorView()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
                    .shadow(radius: 2)
            }
            .buttonStyle(.plain)
            .padding(8)
            .opacity(isHovering ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .help("Close mirror (⌘W)")
        }
        .onHover { isHovering = $0 }
    }
}
