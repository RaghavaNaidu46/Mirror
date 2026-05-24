import SwiftUI
import AppKit

struct AlternativeIconsSettingsView: View {
    @ObservedObject private var preferences = Preferences.shared
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var pro: Pro

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 5)

    var body: some View {
        SettingsForm {
            Section("Menu bar icon") {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(MenuBarIcon.allCases) { icon in
                        MenuBarIconTile(icon: icon,
                                        selected: preferences.menuBarIconName == icon.rawValue)
                            .onTapGesture { selectIcon(icon) }
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Toggle(isOn: Binding(
                    get: { preferences.showInDock },
                    set: { newValue in
                        if newValue && !pro.canUsePlus {
                            appState.showPaywall()
                            return
                        }
                        preferences.showInDock = newValue
                        (NSApp.delegate as? AppDelegate)?.applyActivationPolicy()
                    }
                )) {
                    Text("Show icon in the Dock")
                }
            }
        }
    }

    /// The Default icon is free; anything else opens the paywall when the
    /// user isn't subscribed.
    private func selectIcon(_ icon: MenuBarIcon) {
        if icon == .defaultIcon || pro.canUsePlus {
            preferences.menuBarIconName = icon.rawValue
            NotificationCenter.default.post(name: .menuBarIconChanged, object: nil)
        } else {
            appState.showPaywall()
        }
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

extension Notification.Name {
    static let menuBarIconChanged = Notification.Name("menuBarIconChanged")
}
