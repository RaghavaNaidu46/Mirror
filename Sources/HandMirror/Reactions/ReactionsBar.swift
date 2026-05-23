import SwiftUI
import AVFoundation

/// Horizontal dock of buttons that trigger the native macOS reaction effects.
/// Visibility is gated by `Preferences.reactionsTriggersVisible`. We render in
/// one of two layouts:
///   - `.capsule` (default) — a horizontal pill of buttons; used for
///     rectangular and square mirror masks.
///   - `.arc` — buttons distributed along the bottom half-circle arc; used
///     when the mirror mask is a circle so the row doesn't overflow the
///     visible region.
struct ReactionsBar: View {
    let available: Set<AVCaptureReactionType>
    let onTrigger: (AVCaptureReactionType) -> Void
    var layout: Layout = .capsule

    enum Layout: Equatable {
        case capsule
        case arc
    }

    private let candidates: [(AVCaptureReactionType, String)] = [
        (.thumbsUp,   "hand.thumbsup.fill"),
        (.thumbsDown, "hand.thumbsdown.fill"),
        (.heart,      "heart.fill"),
        (.confetti,   "sparkles"),
        (.fireworks,  "sparkles.rectangle.stack"),
        (.balloons,   "balloon.fill"),
        (.rain,       "cloud.rain.fill"),
        (.lasers,     "wand.and.stars"),
    ]

    var body: some View {
        let items = candidates.filter { available.contains($0.0) }
        if items.isEmpty {
            EmptyView()
        } else {
            switch layout {
            case .capsule: capsuleLayout(items)
            case .arc:     arcLayout(items)
            }
        }
    }

    private func capsuleLayout(_ items: [(AVCaptureReactionType, String)]) -> some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.0.rawValue) { reaction, symbol in
                button(for: reaction, symbol: symbol)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.35), in: Capsule())
    }

    /// Place each button along the bottom arc of a circle that fills the
    /// available frame. Centers sit at ~80% of the bounding circle's radius so
    /// the buttons stay safely inside the mirror's circular clip.
    private func arcLayout(_ items: [(AVCaptureReactionType, String)]) -> some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let centerY = geo.size.height / 2
            let radius = min(geo.size.width, geo.size.height) * 0.4
            let count = items.count

            // Sweep the bottom arc from ~30° to ~150° (inset from the equator
            // so the end buttons don't crowd the circle's left/right edge).
            let startDeg: Double = 30
            let endDeg: Double = 150

            ForEach(Array(items.enumerated()), id: \.element.0.rawValue) { idx, item in
                let progress = count > 1 ? Double(idx) / Double(count - 1) : 0.5
                let angleDeg = startDeg + progress * (endDeg - startDeg)
                let radians = angleDeg * .pi / 180
                let x = centerX + cos(radians) * radius
                let y = centerY + sin(radians) * radius

                button(for: item.0, symbol: item.1)
                    .position(x: x, y: y)
            }
        }
    }

    private func button(for reaction: AVCaptureReactionType, symbol: String) -> some View {
        Button {
            onTrigger(reaction)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 26)
                .background(.black.opacity(0.55), in: Circle())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}
