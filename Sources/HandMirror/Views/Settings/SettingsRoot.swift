import SwiftUI

/// Root of the Settings window. A two-pane sidebar layout that mirrors the
/// reference HandMirror Plus settings: top group (General, About) plus a
/// "HandMirror Plus" group for the premium features.
struct SettingsRoot: View {
    @EnvironmentObject var appState: AppState
    @State private var selection: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 260)
        } detail: {
            detail
                .navigationSplitViewColumnWidth(min: 520, ideal: 620)
        }
        .frame(minWidth: 820, minHeight: 560)
        .toolbar { planChip }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(SettingsTab.topGroup) { tab in
                row(for: tab)
            }
            Section("HandMirror Plus") {
                ForEach(SettingsTab.plusGroup) { tab in
                    row(for: tab)
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func row(for tab: SettingsTab) -> some View {
        Label {
            HStack(spacing: 6) {
                Text(tab.title)
                if tab.showsNewBadge {
                    Text("NEW")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                Spacer()
            }
        } icon: {
            Image(systemName: tab.systemImage)
        }
        .tag(tab)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general:           GeneralSettingsView()
        case .about:             AboutSettingsView()
        case .snaps:             SnapsSettingsView()
        case .smartWindow:       SmartWindowSettingsView()
        case .windowMask:        WindowMaskSettingsView()
        case .notchTrigger:      NotchTriggerSettingsView()
        case .micCheck:          MicCheckSettingsView()
        case .reactions:         ReactionsSettingsView()
        case .alternativeIcons:  AlternativeIconsSettingsView()
        }
    }

    // MARK: - Plan chip
    //
    // Doubles as the entry point to the paywall when the user isn't Pro. If
    // they're already subscribed it just reads "HandMirror Plus" as a badge.

    @ToolbarContentBuilder
    private var planChip: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            PlanChipButton()
        }
    }
}

private struct PlanChipButton: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var pro: Pro

    var body: some View {
        Button {
            if !pro.canUsePlus { appState.showPaywall() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: pro.canUsePlus ? "checkmark.seal.fill" : "camera.fill")
                    .foregroundStyle(.red)
                Text(pro.canUsePlus ? "HandMirror Plus" : "Get HandMirror Plus")
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.black.opacity(0.3), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(pro.canUsePlus)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case general, about
    case snaps, smartWindow, windowMask, notchTrigger, micCheck, reactions, alternativeIcons

    var id: String { rawValue }

    static let topGroup: [SettingsTab] = [.general, .about]
    static let plusGroup: [SettingsTab] = [
        .snaps, .smartWindow, .windowMask, .notchTrigger, .micCheck, .reactions, .alternativeIcons
    ]

    var title: String {
        switch self {
        case .general:           return "General"
        case .about:             return "About"
        case .snaps:             return "Snaps"
        case .smartWindow:       return "Smart Window"
        case .windowMask:        return "Window Mask"
        case .notchTrigger:      return "Notch Trigger"
        case .micCheck:          return "Mic Check"
        case .reactions:         return "Reactions"
        case .alternativeIcons:  return "Alternative Icons"
        }
    }

    var systemImage: String {
        switch self {
        case .general:           return "gearshape"
        case .about:             return "info.circle"
        case .snaps:             return "person.crop.rectangle.badge.plus"
        case .smartWindow:       return "macwindow"
        case .windowMask:        return "theatermasks"
        case .notchTrigger:      return "rectangle.center.inset.filled"
        case .micCheck:          return "waveform"
        case .reactions:         return "sparkles"
        case .alternativeIcons:  return "square.grid.2x2"
        }
    }

    var showsNewBadge: Bool { self == .snaps }
}
