import SwiftUI
import KeyboardShortcuts
import AVFoundation

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var preferences = Preferences.shared

    var body: some View {
        SettingsForm {
            Section("Camera") {
                CameraPickerRow(camera: appState.cameraManager)
                Toggle("Mirror horizontally", isOn: $preferences.mirrorHorizontally)
                Toggle(isOn: $preferences.centerStageEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use Center Stage")
                        Text(appState.cameraManager.isCenterStageSupported
                             ? "Automatically keep yourself centered in frame"
                             : "Current camera doesn't support Center Stage")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .disabled(!appState.cameraManager.isCenterStageSupported)
            }

            Section("Window") {
                HStack {
                    Text("Size")
                    Slider(value: $preferences.windowSize, in: 160...420, step: 10)
                    Text("\(Int(preferences.windowSize))").monospacedDigit().frame(width: 36, alignment: .trailing)
                }
                Toggle("Always on top", isOn: $preferences.alwaysOnTop)
                Toggle("Open mirror on launch", isOn: $preferences.openOnLaunch)
            }

            Section("Shortcuts") {
                KeyboardShortcuts.Recorder("Toggle Mirror", name: .toggleMirror)
                KeyboardShortcuts.Recorder("Take Snap",    name: .takeSnap)
            }

            Section("System") {
                Toggle("Launch at login", isOn: $preferences.launchAtLogin)
            }
        }
    }
}

private struct CameraPickerRow: View {
    @ObservedObject var camera: CameraManager

    var body: some View {
        Picker("Source", selection: Binding(
            get: { camera.currentDevice?.uniqueID ?? "" },
            set: { id in
                if let device = camera.availableCameras.first(where: { $0.uniqueID == id }) {
                    camera.selectDevice(device)
                }
            }
        )) {
            if camera.availableCameras.isEmpty {
                Text("No cameras detected").tag("")
            }
            ForEach(camera.availableCameras, id: \.uniqueID) { device in
                Text(device.localizedName).tag(device.uniqueID)
            }
        }
    }
}

/// Wraps `Form` with the styling common to every settings tab.
struct SettingsForm<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        Form { content }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
    }
}
