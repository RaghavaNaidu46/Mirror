import SwiftUI

/// Wraps Settings tabs that require HandMirror Plus. Shows the wrapped
/// content in `.earlyAccess` mode or when the user is subscribed; otherwise
/// displays an upsell panel with a button that opens the paywall.
struct ProGate<Content: View>: View {
    @EnvironmentObject var pro: Pro
    @EnvironmentObject var appState: AppState

    let title: String
    let subtitle: String
    let symbol: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        if pro.canUsePlus {
            content()
        } else {
            upsell
        }
    }

    private var upsell: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)

            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.red.opacity(0.85))
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color.red.opacity(0.10)))

            Text(title)
                .font(.title3).bold()

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                appState.showPaywall()
            } label: {
                Text("Get HandMirror Plus")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 22).padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)

            Button {
                Task { await pro.restore() }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
