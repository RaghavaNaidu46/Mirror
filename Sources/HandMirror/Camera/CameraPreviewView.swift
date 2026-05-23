import SwiftUI
import AVFoundation
import AppKit

/// SwiftUI wrapper around AVCaptureVideoPreviewLayer. The layer renders the
/// camera feed directly on the GPU — far cheaper than piping CMSampleBuffers
/// through SwiftUI.
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    var mirrored: Bool = true

    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        applyMirror(on: view)
        return view
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        if nsView.previewLayer.session !== session {
            nsView.previewLayer.session = session
        }
        applyMirror(on: nsView)
    }

    private func applyMirror(on view: PreviewNSView) {
        guard let connection = view.previewLayer.connection else { return }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }
}

final class PreviewNSView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer = CALayer()
        layer?.addSublayer(previewLayer)
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}
