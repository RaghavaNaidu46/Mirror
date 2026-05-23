import AVFoundation
import Combine

/// Monitors the default microphone input and publishes a 0…1 level value.
/// Backed by AVAudioEngine + an input-node tap; cheap enough to run while the
/// mirror is open, gated by the Mic Check preference toggle.
final class MicMonitor: ObservableObject {
    @Published private(set) var level: Float = 0
    @Published private(set) var isRunning: Bool = false

    private let engine = AVAudioEngine()
    private var smoothedLevel: Float = 0

    /// Raw mic input from line-level speech peaks around 0.1–0.3 — multiply so
    /// normal talking pushes the meter into the mid/upper bars instead of
    /// barely flickering the first one.
    private let inputGain: Float = 4.0

    func start() {
        guard !isRunning else { return }

        // Microphone permission — declared in Info.plist; request if undecided.
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            installTapAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                guard granted else {
                    NSLog("MicMonitor: microphone access denied")
                    return
                }
                DispatchQueue.main.async { self?.installTapAndStart() }
            }
        default:
            NSLog("MicMonitor: microphone access not granted")
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine.reset()
        isRunning = false
        level = 0
        smoothedLevel = 0
    }

    private func installTapAndStart() {
        let input = engine.inputNode
        // `outputFormat(forBus:)` is what flows out of the input node to the
        // tap — `inputFormat` describes the hardware format and isn't always
        // populated until the engine is running.
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            NSLog("MicMonitor: invalid input format (\(format)), aborting")
            return
        }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            let peak = MicMonitor.peakLevel(of: buffer)
            DispatchQueue.main.async {
                guard let self else { return }
                let boosted = min(peak * self.inputGain, 1.0)
                // Light attack, slower decay so the bars don't strobe.
                self.smoothedLevel = max(boosted, self.smoothedLevel * 0.85)
                self.level = self.smoothedLevel
            }
        }

        engine.prepare()
        do {
            try engine.start()
            isRunning = true
        } catch {
            NSLog("MicMonitor: failed to start — \(error.localizedDescription)")
        }
    }

    private static func peakLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        var peak: Float = 0
        for c in 0..<channelCount {
            let samples = channelData[c]
            for i in 0..<frameLength {
                let v = abs(samples[i])
                if v > peak { peak = v }
            }
        }
        return min(peak, 1.0)
    }
}
