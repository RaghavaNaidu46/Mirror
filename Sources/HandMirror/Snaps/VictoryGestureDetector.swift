import AVFoundation
import Vision
import AppKit

/// Watches the camera stream for a V-sign hand pose using Vision's hand-pose
/// detector. Fires `onVictoryDetected` on the main queue when the pose is held
/// steadily for a few frames. Independent of the system Reactions / gestures
/// settings — the user doesn't need to enable anything in Control Center.
final class VictoryGestureDetector: NSObject {

    /// Pre-built Vision request reused frame-to-frame.
    private let handRequest: VNDetectHumanHandPoseRequest = {
        let req = VNDetectHumanHandPoseRequest()
        req.maximumHandCount = 2
        return req
    }()

    /// Serial queue the AVCaptureVideoDataOutput delivers samples on.
    let processingQueue = DispatchQueue(label: "com.handmirror.victory.detect")

    /// Frames per second we cap the detector at — Vision hand pose is heavy
    /// and we don't need more than a few samples to confirm a held pose.
    private let frameInterval: TimeInterval = 0.2  // 5 fps
    private var lastFrameAt: Date = .distantPast

    /// Number of consecutive matching frames required before firing.
    private let requiredMatches = 3
    private var consecutiveMatches = 0

    /// Don't fire the callback more than once per cooldown window — keeps a
    /// long-held V-sign from spamming snap countdowns.
    private let cooldown: TimeInterval = 6
    private var lastFireAt: Date = .distantPast

    /// Called on the main queue when a V-sign is detected.
    var onVictoryDetected: (() -> Void)?
}

extension VictoryGestureDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastFrameAt) >= frameInterval else { return }
        lastFrameAt = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do { try handler.perform([handRequest]) } catch { return }

        let observations = handRequest.results ?? []
        let matched = observations.contains { isVictoryPose($0) }
        if matched {
            consecutiveMatches += 1
            if consecutiveMatches >= requiredMatches,
               now.timeIntervalSince(lastFireAt) >= cooldown {
                lastFireAt = now
                consecutiveMatches = 0
                DispatchQueue.main.async { [weak self] in
                    self?.onVictoryDetected?()
                }
            }
        } else {
            consecutiveMatches = 0
        }
    }

    // MARK: - Pose check
    //
    // V-sign: index + middle fingers extended, ring + little fingers curled
    // toward the palm. Thumb can be tucked or loose — we don't constrain it.
    // Index and middle tips must be separated horizontally so a "two parallel
    // fingers" pose still counts but a "single pointing finger" doesn't.

    private func isVictoryPose(_ observation: VNHumanHandPoseObservation) -> Bool {
        guard
            let index = try? observation.recognizedPoints(.indexFinger),
            let middle = try? observation.recognizedPoints(.middleFinger),
            let ring = try? observation.recognizedPoints(.ringFinger),
            let little = try? observation.recognizedPoints(.littleFinger)
        else { return false }

        guard
            let indexTip = index[.indexTip],
            let indexPIP = index[.indexPIP],
            let indexMCP = index[.indexMCP],
            let middleTip = middle[.middleTip],
            let middlePIP = middle[.middlePIP],
            let middleMCP = middle[.middleMCP],
            let ringTip = ring[.ringTip],
            let ringMCP = ring[.ringMCP],
            let littleTip = little[.littleTip],
            let littleMCP = little[.littleMCP]
        else { return false }

        let conf: Float = 0.3
        guard indexTip.confidence > conf,
              indexPIP.confidence > conf,
              indexMCP.confidence > conf,
              middleTip.confidence > conf,
              middlePIP.confidence > conf,
              middleMCP.confidence > conf,
              ringTip.confidence > conf,
              ringMCP.confidence > conf,
              littleTip.confidence > conf,
              littleMCP.confidence > conf
        else { return false }

        let indexExtended = isExtended(mcp: indexMCP.location, pip: indexPIP.location, tip: indexTip.location)
        let middleExtended = isExtended(mcp: middleMCP.location, pip: middlePIP.location, tip: middleTip.location)
        guard indexExtended, middleExtended else { return false }

        // Reference span = how long an extended finger is in this hand.
        let referenceSpan = distance(indexMCP.location, indexTip.location)
        let ringCurled = distance(ringMCP.location, ringTip.location) < referenceSpan * 0.65
        let littleCurled = distance(littleMCP.location, littleTip.location) < referenceSpan * 0.65
        guard ringCurled, littleCurled else { return false }

        // Index and middle tips must be spread apart, otherwise we'd accept a
        // "pointing" pose (single finger up) as a V.
        let tipGap = distance(indexTip.location, middleTip.location)
        let mcpGap = distance(indexMCP.location, middleMCP.location)
        return tipGap > mcpGap * 1.5
    }

    private func isExtended(mcp: CGPoint, pip: CGPoint, tip: CGPoint) -> Bool {
        let v1x = pip.x - mcp.x, v1y = pip.y - mcp.y
        let v2x = tip.x - pip.x, v2y = tip.y - pip.y
        let m1 = (v1x * v1x + v1y * v1y).squareRoot()
        let m2 = (v2x * v2x + v2y * v2y).squareRoot()
        guard m1 > 0, m2 > 0 else { return false }
        let cosAngle = (v1x * v2x + v1y * v2y) / (m1 * m2)
        return cosAngle > 0.6  // PIP angle wider than ~53°
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
