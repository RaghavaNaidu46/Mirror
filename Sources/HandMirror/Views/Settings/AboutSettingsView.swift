import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)
                .padding(.top, 32)
            Text("HandMirror - Camera").font(.title2).bold()
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")")
                .foregroundStyle(.secondary)
            Text("A menu-bar webcam check, built with SwiftUI.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
