import SwiftUI
import AppKit

struct AlternativeIconsSettingsView: View {
    @ObservedObject private var preferences = Preferences.shared
    @EnvironmentObject var appState: AppState

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 5)
    private let appIconColumns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 3)

    var body: some View {
        SettingsForm {
            Section("Menu bar icon") {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(MenuBarIcon.allCases) { icon in
                        MenuBarIconTile(icon: icon,
                                        selected: preferences.menuBarIconName == icon.rawValue)
                            .onTapGesture {
                                preferences.menuBarIconName = icon.rawValue
                                NotificationCenter.default.post(name: .menuBarIconChanged, object: nil)
                            }
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Toggle(isOn: Binding(
                    get: { preferences.showInDock },
                    set: { newValue in
                        preferences.showInDock = newValue
                        (NSApp.delegate as? AppDelegate)?.applyActivationPolicy()
                    }
                )) {
                    Text("Show icon in the Dock")
                }
            }

            Section("App icon") {
                LazyVGrid(columns: appIconColumns, spacing: 18) {
                    ForEach(AppIconChoice.allCases) { choice in
                        AppIconTile(choice: choice,
                                    selected: preferences.appIconName == choice.rawValue)
                            .onTapGesture {
                                preferences.appIconName = choice.rawValue
                                applyAppIcon(choice)
                            }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func applyAppIcon(_ choice: AppIconChoice) {
        // We don't ship icon assets yet — when we do, swap the image here.
        // For now this is a no-op placeholder; visual selection still persists.
        _ = choice
    }
}

private struct MenuBarIconTile: View {
    let icon: MenuBarIcon
    let selected: Bool
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon.symbolName)
                .font(.system(size: 22))
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(selected ? 0.10 : 0.05),
                            in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(selected ? Color.accentColor : .clear, lineWidth: 2)
                )
            Text(icon.displayName).font(.caption)
        }
    }
}

private struct AppIconTile: View {
    let choice: AppIconChoice
    let selected: Bool
    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [.red.opacity(0.7), .orange.opacity(0.5)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selected ? Color.accentColor : .clear, lineWidth: 3)
                )
            Text(choice.displayName).font(.caption)
        }
    }
}

extension Notification.Name {
    static let menuBarIconChanged = Notification.Name("menuBarIconChanged")
}
