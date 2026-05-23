import SwiftUI

struct SmartWindowSettingsView: View {
    @ObservedObject private var preferences = Preferences.shared

    var body: some View {
        SettingsForm {
            Section {
                Toggle(isOn: $preferences.smartWindowEnabled) {
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
