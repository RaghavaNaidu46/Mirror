import SwiftUI
import AVFoundation
import KeyboardShortcuts

/// Three-step first-run flow: welcome → camera permission → optional shortcut.
/// Re-shown via the status bar's "Reset Onboarding" action.
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var preferences = Preferences.shared

    @State private var step: Step = .welcome
    @State private var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    let onFinish: () -> Void

    enum Step: CaseIterable { case welcome, camera, shortcut }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 48)
                .padding(.top, 56)
                .padding(.bottom, 24)

            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { s in
                    Circle()
                        .fill(s == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.bottom, 18)
        }
        .frame(width: 520, height: 440)
        .background(.background)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:  welcomeStep
        case .camera:   cameraStep
        case .shortcut: shortcutStep
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)
            Text("Welcome to Hand Mirror").font(.title).bold()
            Text("A quick way to check your camera before any video call. Lives in your menu bar — one click and you're set.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            Spacer()
            Button { step = .camera } label: {
                Text("Get Started").frame(minWidth: 160)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Camera permission

    private var cameraStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "video.fill")
                .font(.system(size: 56))
                .foregroundStyle(cameraStatus == .authorized ? .green : .secondary)
            Text("Allow camera access").font(.title2).bold()
            Text(cameraStatusMessage)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            Spacer()
            HStack(spacing: 12) {
                if cameraStatus == .denied {
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.large)
                }
                Button(cameraStatus == .authorized ? "Continue" : "Allow Camera") {
                    requestOrAdvance()
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
        }
        .task { refreshStatus() }
    }

    private var cameraStatusMessage: String {
        switch cameraStatus {
        case .authorized:  return "Camera access granted. You're all set."
        case .notDetermined: return "Hand Mirror needs to see your camera to show you a preview. Click below to grant access."
        case .denied:      return "Camera access was denied. Enable it in System Settings → Privacy & Security → Camera, then return here."
        case .restricted:  return "Camera access is restricted on this Mac."
        @unknown default:  return "Unknown camera permission state."
        }
    }

    private func refreshStatus() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private func requestOrAdvance() {
        switch cameraStatus {
        case .authorized:
            step = .shortcut
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraStatus = granted ? .authorized : .denied
                    if granted { step = .shortcut }
                }
            }
        case .denied, .restricted:
            refreshStatus()
        @unknown default:
            break
        }
    }

    // MARK: - Shortcut

    private var shortcutStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "keyboard")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Set a hotkey").font(.title2).bold()
            Text("Optional — pick a global shortcut to toggle the mirror from anywhere. You can change it later in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            KeyboardShortcuts.Recorder("Toggle Mirror", name: .toggleMirror)
                .padding(.top, 8)

            Spacer()
            Button {
                preferences.onboardingComplete = true
                onFinish()
            } label: {
                Text("Finish").frame(minWidth: 160)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
    }
}
