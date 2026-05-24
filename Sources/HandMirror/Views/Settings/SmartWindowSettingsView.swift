import SwiftUI

struct SmartWindowSettingsView: View {
    @ObservedObject private var preferences = Preferences.shared
    @EnvironmentObject private var pro: Pro
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsForm {
            Section {
                Toggle(isOn: pro.gatedBinding($preferences.smartWindowEnabled, freeValue: false, onLocked: { appState.showPaywall() })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Smart Window")
                        Text("Remembers where the mirror is placed in different app and display contexts, so it always lands in the right spot.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
