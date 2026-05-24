import AVFoundation
import AppKit
import Combine

/// Wraps AVCaptureSession. Enumerates cameras (built-in + external + iPhone
/// Continuity), starts/stops the session, and switches devices. The preview
/// layer is the only output — adding `AVCaptureVideoDataOutput` or
/// `AVCapturePhotoOutput` to the session while the Reactions compositor is
/// active causes Metal storage-mode assertions and KVO subclass linking
/// failures. Snaps capture from the window instead.
final class CameraManager: NSObject, ObservableObject {
    @Published private(set) var availableCameras: [AVCaptureDevice] = []
    @Published private(set) var currentDevice: AVCaptureDevice?
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var isRunning: Bool = false

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.handmirror.session")
    private var deviceInput: AVCaptureDeviceInput?
    private var observers: [NSObjectProtocol] = []
    private var reactionsObservation: NSKeyValueObservation?
    private var seenReactions = Set<TimeInterval>()

    /// Vision-based V-sign detector — runs on frames piped through
    /// `videoDataOutput`. The system's gesture-driven `.balloons` reaction is
    /// unreliable (it requires Reactions + Gestures to be on in Control
    /// Center), so we do the detection ourselves.
    private let victoryDetector = VictoryGestureDetector()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var didAddVideoOutput = false

    /// Called on the main queue when the system fires a Victory reaction (the
    /// peace-sign hand gesture, which AVCapture surfaces as `.balloons`).
    /// Wired up in AppDelegate to take an automatic snap.
    var onVictoryReaction: (() -> Void)?

    override init() {
        super.init()
        session.sessionPreset = .high
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(victoryDetector, queue: victoryDetector.processingQueue)
        victoryDetector.onVictoryDetected = { [weak self] in
            self?.onVictoryReaction?()
        }
        refreshDevices()
        registerForDeviceChanges()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: - Authorization

    func requestAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationStatus = .authorized
            start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.authorizationStatus = granted ? .authorized : .denied
                    if granted { self?.start() }
                }
            }
        case .denied, .restricted:
            authorizationStatus = .denied
        @unknown default:
            authorizationStatus = .denied
        }
    }

    // MARK: - Device enumeration

    func refreshDevices() {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .external,
            .continuityCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )
        DispatchQueue.main.async {
            self.availableCameras = discovery.devices
            if self.currentDevice == nil {
                let stored = Preferences.shared.selectedCameraID
                let preferred = discovery.devices.first(where: { $0.uniqueID == stored })
                    ?? AVCaptureDevice.default(for: .video)
                    ?? discovery.devices.first
                if let device = preferred {
                    self.configure(for: device)
                }
            }
        }
    }

    private func registerForDeviceChanges() {
        let connected = NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasConnected, object: nil, queue: .main
        ) { [weak self] _ in self?.refreshDevices() }
        let disconnected = NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasDisconnected, object: nil, queue: .main
        ) { [weak self] _ in self?.refreshDevices() }
        observers.append(connected)
        observers.append(disconnected)
    }

    // MARK: - Session control

    func start() {
        guard authorizationStatus == .authorized else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async { self.isRunning = self.session.isRunning }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async { self.isRunning = self.session.isRunning }
            }
        }
    }

    // MARK: - Device selection

    func selectDevice(_ device: AVCaptureDevice) {
        configure(for: device)
        Preferences.shared.selectedCameraID = device.uniqueID
    }

    private func configure(for device: AVCaptureDevice) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            if let existing = self.deviceInput {
                self.session.removeInput(existing)
            }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.deviceInput = input
                }
            } catch {
                NSLog("CameraManager: failed to create input — \(error.localizedDescription)")
            }
            if !self.didAddVideoOutput, self.session.canAddOutput(self.videoDataOutput) {
                self.session.addOutput(self.videoDataOutput)
                self.didAddVideoOutput = true
            }
            self.session.commitConfiguration()
            DispatchQueue.main.async {
                self.currentDevice = device
                self.applyCenterStage()
                self.observeReactions(on: device)
            }
        }
    }

    /// Observe `reactionEffectsInProgress` on the active device so we can
    /// react to gesture-triggered reactions. We track each reaction by its
    /// startTime to avoid firing the callback repeatedly while the same
    /// effect lingers in the array.
    private func observeReactions(on device: AVCaptureDevice) {
        reactionsObservation?.invalidate()
        reactionsObservation = device.observe(\.reactionEffectsInProgress, options: [.new]) { [weak self] _, change in
            guard let self, let effects = change.newValue else { return }

            // Reap stale entries that are no longer in-progress so we'll fire
            // again the next time the same reaction is performed.
            let liveKeys = Set(effects.map { $0.startTime.seconds })
            self.seenReactions = self.seenReactions.intersection(liveKeys)

            for effect in effects {
                let key = effect.startTime.seconds
                if self.seenReactions.contains(key) { continue }
                self.seenReactions.insert(key)
                if effect.reactionType == .balloons {
                    DispatchQueue.main.async { self.onVictoryReaction?() }
                }
            }
        }
    }

    // MARK: - Center Stage

    /// Whether the current device's active format advertises Center Stage support.
    /// Built-in Mac cameras on M-series and iPhone Continuity Cameras typically
    /// do; external USB webcams don't.
    var isCenterStageSupported: Bool {
        currentDevice?.activeFormat.isCenterStageSupported ?? false
    }

    /// Apply the user's Center Stage preference. Uses `.cooperative` control
    /// mode so the user can still flip it via Control Center → Video Effects
    /// without us fighting them.
    func applyCenterStage() {
        AVCaptureDevice.centerStageControlMode = .cooperative
        AVCaptureDevice.isCenterStageEnabled = Preferences.shared.centerStageEnabled
    }

    // MARK: - Reactions (Sonoma+)

    /// True when the system has reactions enabled (Control Center → Video
    /// Effects), the current device supports them, and the active format
    /// supports them. All three are required — calling `performEffect` when
    /// any are false raises an Objective-C exception.
    var canPerformReactions: Bool {
        guard let device = currentDevice else { return false }
        return AVCaptureDevice.reactionEffectsEnabled
            && device.canPerformReactionEffects
            && device.activeFormat.reactionEffectsSupported
    }

    /// Reaction types the current device actually offers. Different cameras
    /// advertise different subsets; calling `performEffect` for one not in this
    /// set raises an exception.
    var availableReactions: Set<AVCaptureReactionType> {
        guard let device = currentDevice,
              device.activeFormat.reactionEffectsSupported
        else { return [] }
        return Set(device.availableReactionTypes)
    }

    /// Triggers a system reaction effect on the current device.
    func performReaction(_ reaction: AVCaptureReactionType) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.canPerformReactions,
                  let device = self.currentDevice,
                  device.availableReactionTypes.contains(reaction)
            else {
                NSSound.beep()
                return
            }
            device.performEffect(for: reaction)
        }
    }
}
