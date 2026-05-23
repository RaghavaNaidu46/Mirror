import SwiftUI

struct WindowMaskSettingsView: View {
    @ObservedObject private var preferences = Preferences.shared

    var body: some View {
        SettingsForm {
            Section("Mask style") {
                HStack(spacing: 24) {
                    ForEach(MaskStyle.allCases) { style in
                        Button {
                            preferences.maskStyle = style.rawValue
                        } label: {
                            MaskStyleTile(style: style,
                                          selected: preferences.maskStyle == style.rawValue)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            Section {
                LabeledSlider(title: "Zoom",
                              value: $preferences.maskZoom,
                              range: 1...3,
                              ticks: ["1×", "2×", "3×"])
                LabeledSlider(title: "Rotation",
                              value: $preferences.maskRotation,
                              range: 0...270,
                              ticks: ["0°", "90°", "180°", "270°"])
            }
        }
    }
}

private struct MaskStyleTile: View {
    let style: MaskStyle
    let selected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                switch style {
                case .defaultChrome:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.4))
                case .square:
                    Rectangle().fill(Color.gray.opacity(0.4))
                case .circle:
                    Circle().fill(Color.gray.opacity(0.4))
                }
            }
            .frame(width: 86, height: 60)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            Text(style.displayName).font(.caption)
        }
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let ticks: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
            }
            Slider(value: $value, in: range)
            HStack {
                ForEach(Array(ticks.enumerated()), id: \.offset) { idx, label in
                    Text(label).font(.caption2).foregroundStyle(.secondary)
                    if idx < ticks.count - 1 { Spacer() }
                }
            }
        }
    }
}
