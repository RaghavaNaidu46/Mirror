import SwiftUI

struct SnapsSettingsView: View {
    @ObservedObject private var preferences = Preferences.shared
    @EnvironmentObject private var pro: Pro
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsForm {
            Section { SnapsHeroPreview() }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

            Section {
                Toggle(isOn: pro.gatedBinding($preferences.snapsEnabled, freeValue: false, onLocked: { appState.showPaywall() })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Snaps")
                        HStack(spacing: 4) {
                            Text("🎁").font(.caption)
                            Text("You have \(preferences.snapsFreeRemaining) free snaps remaining — on the house.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Toggle(isOn: $preferences.snapsIncludeFrame) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Include frame in picture")
                        Text("Captures the window border and annotations")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $preferences.snapsIncludeDate) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Include date")
                        Text("Shows the date as a handwritten annotation")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $preferences.snapsAutoSave) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Save automatically")
                        Text("Saves directly to your chosen location")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Save location")
                        Text("Choose a destination when you take your first snap")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        chooseSaveLocation()
                    } label: {
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func chooseSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            preferences.snapsSaveLocation = url.path
        }
    }
}

private struct SnapsHeroPreview: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.2)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 8) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 180, height: 220)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 158, height: 158)
                                .offset(y: -20)
                        )
                    Text("Jan 9  😊")
                        .font(.custom("Snell Roundhand", size: 22))
                        .padding(.bottom, 18)
                }
                Capsule()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 50, height: 16)
                    .overlay(Text("Saved").font(.caption2).foregroundStyle(.black))
            }
        }
        .frame(height: 320)
    }
}
