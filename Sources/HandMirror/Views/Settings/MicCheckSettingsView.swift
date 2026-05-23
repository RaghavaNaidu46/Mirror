import SwiftUI

struct MicCheckSettingsView: View {
    @ObservedObject private var preferences = Preferences.shared

    var body: some View {
        SettingsForm {
            Section {
                MicCheckHeroPreview()
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section {
                Toggle(isOn: $preferences.micCheckEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Mic Check")
                        Text("Quickly check if there's audio coming from your microphone")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $preferences.micCheckShowOnHover) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show only on hover")
                        Text("Useful for when you're recording your screen")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct MicCheckHeroPreview: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                           startPoint: .top, endPoint: .bottom)
            VStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 280, height: 160)
                    .overlay(
                        HStack(spacing: 3) {
                            ForEach(0..<4) { i in
                                Capsule().fill(Color.green)
                                    .frame(width: 4, height: CGFloat(8 + i * 3))
                            }
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.6), in: Capsule())
                        .offset(y: 64)
                    )
            }
        }
        .frame(height: 220)
    }
}
