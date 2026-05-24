import SwiftUI

struct WindowMaskSettingsView: View {
    @ObservedObject private var preferences = Preferences.shared
    @EnvironmentObject private var pro: Pro
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsForm {
            Section("Mask style") {
                HStack(spacing: 24) {
                    ForEach(MaskStyle.allCases) { style in
                        Button {
                            selectStyle(style)
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
                              value: pro.gatedBinding($preferences.maskZoom, freeValue: 1.0, onLocked: { appState.showPaywall() }),
                              range: 1...3,
                              ticks: ["1×", "2×", "3×"])
                LabeledSlider(title: "Rotation",
                              value: pro.gatedBinding($preferences.maskRotation, freeValue: 0.0, onLocked: { appState.showPaywall() }),
                              range: 0...270,
                              ticks: ["0°", "90°", "180°", "270°"])
            }
        }
    }

    private func selectStyle(_ style: MaskStyle) {
        if style == .defaultChrome || pro.canUsePlus {
            preferences.maskStyle = style.rawValue
        } else {
            appState.showPaywall()
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
