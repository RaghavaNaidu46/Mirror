import SwiftUI

struct ReactionsSettingsView: View {
    @ObservedObject private var preferences = Preferences.shared
    @EnvironmentObject private var pro: Pro
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsForm {
            Section {
                ReactionsHeroPreview()
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section {
                Toggle(isOn: pro.gatedBinding($preferences.reactionsTriggersVisible, freeValue: false, onLocked: { appState.showPaywall() })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Reaction triggers")
                        Text("Trigger the native macOS Reactions directly from HandMirror")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct ReactionsHeroPreview: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple.opacity(0.5), .pink.opacity(0.3)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            HStack(spacing: 8) {
                ForEach(["sparkles", "heart.fill", "hand.thumbsup.fill", "hand.thumbsdown.fill",
                         "balloon.fill", "cloud.rain.fill"], id: \.self) { name in
                    Image(systemName: name)
                        .font(.system(size: 18))
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.4), in: Circle())
                        .foregroundStyle(.white)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.3), in: Capsule())
            .offset(y: 70)
        }
        .frame(height: 220)
    }
}
