import SwiftUI
import AppKit

/// Inline Snap editor — the polaroid slides up from below the mirror, photo
/// "develops" (fades in) inside the frame, marker pen swings in from the right.
/// User scribbles annotations with a chosen pen color; Save flattens the
/// polaroid + canvas + annotations to a PNG and writes it to disk.
struct SnapEditorView: View {
    let image: NSImage
    let dateText: String?
    let maskStyle: MaskStyle

    let onSave: (Data) -> Void
    let onCancel: () -> Void

    @State private var strokes: [DrawStroke] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var currentColor: PenColor = .black
    @State private var savedToastShown = false

    @State private var polaroidIn = false
    @State private var photoOpacity: Double = 0
    @State private var photoScale: CGFloat = 1.18
    @State private var dateProgress: CGFloat = 0
    @State private var markerIn = false
    @State private var controlsIn = false

    /// Polaroid outer frame for the active mask style.
    private var polaroidWidth: CGFloat {
        photoSize.width + 32  // outerHorizontal × 2
    }
    private var polaroidHeight: CGFloat {
        photoSize.height + 16 + 84  // outerTop + outerBottom
    }
    private var photoSize: CGSize {
        switch maskStyle {
        case .defaultChrome:   return CGSize(width: 340, height: 340 * 9.0 / 16.0)
        case .square, .circle: return CGSize(width: 320, height: 320)
        }
    }

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 18) {
                polaroidWithMarker
                controlsRow
                    .opacity(controlsIn ? 1 : 0)
                    .offset(y: controlsIn ? 0 : 8)
            }
            .padding(.vertical, 20)

            if savedToastShown {
                Text("Saved")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16).padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                    .offset(y: polaroidHeight / 2 + 28)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(width: polaroidWidth + 80, height: polaroidHeight + 80)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        .onAppear(perform: runEntranceAnimation)
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        LinearGradient(
            colors: [
                Color(red: 0.84, green: 0.86, blue: 0.88),
                Color(red: 0.66, green: 0.70, blue: 0.74),
                Color(red: 0.42, green: 0.48, blue: 0.54),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .overlay(
            // Soft mist swirls for depth
            RadialGradient(
                colors: [Color.white.opacity(0.35), Color.white.opacity(0)],
                center: .init(x: 0.3, y: 0.65),
                startRadius: 20, endRadius: 240
            )
        )
        .overlay(
            RadialGradient(
                colors: [Color.white.opacity(0.25), Color.white.opacity(0)],
                center: .init(x: 0.8, y: 0.35),
                startRadius: 10, endRadius: 200
            )
        )
    }

    // MARK: - Polaroid with marker

    private var polaroidWithMarker: some View {
        ZStack {
            polaroid
                .rotationEffect(.degrees(-1.5))
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
                .scaleEffect(polaroidIn ? 1.0 : 0.85)
                .offset(y: polaroidIn ? 0 : 60)
                .opacity(polaroidIn ? 1 : 0)

            markerPen
                .rotationEffect(.degrees(8))
                .offset(x: polaroidWidth / 2 + 6, y: -40)
                .opacity(markerIn ? 1 : 0)
                .offset(x: markerIn ? 0 : 40)
        }
        .frame(width: polaroidWidth, height: polaroidHeight)
    }

    private var polaroid: some View {
        ZStack {
            PolaroidSnapView(
                image: image,
                dateText: dateText,
                mirrored: false,
                includeFrame: true,
                maskStyle: maskStyle,
                photoOpacity: photoOpacity,
                photoScale: photoScale,
                dateRevealProgress: dateProgress
            )

            // Renders strokes — SwiftUI Canvas is just for drawing; input is
            // handled by the PaintCanvasOverlay below so we can block the
            // window's drag-by-background within the polaroid bounds only.
            Canvas { context, _ in
                for stroke in strokes {
                    drawStroke(stroke.points, color: stroke.color.swiftUIColor, context: context)
                }
                if !currentStroke.isEmpty {
                    drawStroke(currentStroke, color: currentColor.swiftUIColor, context: context)
                }
            }
            .frame(width: polaroidWidth, height: polaroidHeight)
            .allowsHitTesting(false)

            // Captures mouse + sets pencil cursor + stops window-drag in this rect.
            PaintCanvasOverlay(
                onPoint: { point in currentStroke.append(point) },
                onEnd: {
                    if !currentStroke.isEmpty {
                        strokes.append(DrawStroke(color: currentColor, points: currentStroke))
                        currentStroke = []
                    }
                }
            )
            .frame(width: polaroidWidth, height: polaroidHeight)
        }
    }

    private func drawStroke(_ points: [CGPoint], color: Color, context: GraphicsContext) {
        guard points.count > 1 else {
            if let p = points.first {
                let rect = CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
            return
        }
        var path = Path()
        path.move(to: points[0])
        for p in points.dropFirst() { path.addLine(to: p) }
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Marker pen

    private var markerPen: some View {
        VStack(spacing: 0) {
            // Cap (colored tip)
            Capsule()
                .fill(currentColor.swiftUIColor)
                .frame(width: 16, height: 38)
            // Body
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.95),
                            Color(white: 0.78),
                            Color(white: 0.85),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: 13, height: 130)
            // Tail (white tip)
            Capsule()
                .fill(Color(white: 0.92))
                .frame(width: 10, height: 14)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 3)
        .animation(.easeInOut(duration: 0.18), value: currentColor)
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: 14) {
            ForEach(PenColor.allCases, id: \.self) { pen in
                Button { currentColor = pen } label: {
                    Circle()
                        .fill(pen.swiftUIColor)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: currentColor == pen ? 2.5 : 0)
                        )
                        .overlay(
                            Circle().stroke(Color.black.opacity(0.2), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                if !strokes.isEmpty { strokes.removeLast() }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.black.opacity(0.4), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(strokes.isEmpty)
            .opacity(strokes.isEmpty ? 0.4 : 1)
            .help("Undo")

            Button("Cancel") { onCancel() }
                .buttonStyle(.bordered)
                .controlSize(.small)

            Button("Save") { saveAndDismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Animation choreography

    private func runEntranceAnimation() {
        // 1. Polaroid slides up from below the mirror.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            polaroidIn = true
        }
        // 2. Photo lands inside the polaroid frame with a spring bounce —
        //    scale 1.18 → 1.0, opacity 0 → 1, slight settle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                photoOpacity = 1
                photoScale = 1.0
            }
        }
        // 3. Marker pen swings in from the right.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                markerIn = true
            }
        }
        // 4. Date stroke-reveals from left to right, like a pen drawing it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeInOut(duration: 0.7)) {
                dateProgress = 1.0
            }
        }
        // 5. Controls fade in below.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeOut(duration: 0.28)) {
                controlsIn = true
            }
        }
    }

    // MARK: - Save

    @MainActor
    private func saveAndDismiss() {
        // Flatten the polaroid + photo + drawing strokes to a PNG. We render
        // the polaroid in its un-tilted, fully-opaque form for the export.
        let snapshotView = ZStack {
            PolaroidSnapView(
                image: image,
                dateText: dateText,
                mirrored: false,
                includeFrame: true,
                maskStyle: maskStyle,
                photoOpacity: 1.0,
                photoScale: 1.0,
                dateRevealProgress: 1.0
            )
            Canvas { context, _ in
                for stroke in strokes {
                    drawStroke(stroke.points, color: stroke.color.swiftUIColor, context: context)
                }
            }
            .frame(width: polaroidWidth, height: polaroidHeight)
        }
        .frame(width: polaroidWidth, height: polaroidHeight)

        let renderer = ImageRenderer(content: snapshotView)
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: cgImage)
                  .representation(using: .png, properties: [:])
        else { return }

        withAnimation(.easeOut(duration: 0.18)) { savedToastShown = true }
        onSave(data)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onCancel()  // dismiss editor after the toast fades
        }
    }
}

// MARK: - Stroke + pen color

struct DrawStroke {
    let color: PenColor
    let points: [CGPoint]
}

enum PenColor: CaseIterable, Hashable {
    case black, red, blue, yellow, green

    var swiftUIColor: Color {
        switch self {
        case .black:  return .black
        case .red:    return Color(red: 0.95, green: 0.20, blue: 0.20)
        case .blue:   return Color(red: 0.12, green: 0.46, blue: 0.97)
        case .yellow: return Color(red: 0.95, green: 0.78, blue: 0.18)
        case .green:  return Color(red: 0.22, green: 0.74, blue: 0.32)
        }
    }
}
