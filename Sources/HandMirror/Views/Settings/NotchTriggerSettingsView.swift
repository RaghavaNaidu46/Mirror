import SwiftUI

struct NotchTriggerSettingsView: View {
    @ObservedObject private var preferences = Preferences.shared

    var body: some View {
        SettingsForm {
            Section {
                NotchHeroPreview()
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section {
                Toggle(isOn: $preferences.notchTriggerEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Notch Trigger")
                        Text("Click the area behind the built-in camera to trigger HandMirror")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $preferences.hideMenuBarIconOnNotch) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide menu bar icon")
                        Text("When a display with a notch is available, hide the icon in the Menu bar.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Can produce unexpected behaviors if other apps are looking for clicks in the notch.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct NotchHeroPreview: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.orange.opacity(0.4), .blue.opacity(0.3)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack {
                Capsule()
                    .fill(Color.black)
                    .frame(width: 160, height: 22)
                    .padding(.top, 20)
                Spacer()
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
