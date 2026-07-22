import AVFoundation
import SwiftUI
import UIKit

/// SwiftUI-обёртка над AVCaptureVideoPreviewLayer для живого превью с камеры.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    /// Слабая ссылка на созданный UIView — чтобы лог мог прочитать его состояние.
    static var lastPreviewView: PreviewUIView?

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        // Для задней камеры mirroring должен быть выключен (false).
        view.videoPreviewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        view.videoPreviewLayer.connection?.isVideoMirrored = false
        view.backgroundColor = .black
        Self.lastPreviewView = view
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
        Self.lastPreviewView = uiView
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        /// Текущие параметры слоя для диагностики (в лог).
        var debugInfo: String {
            let l = videoPreviewLayer
            let c = l.connection
            let orient: String
            switch c?.videoOrientation {
            case .portrait: orient = "portrait"
            case .portraitUpsideDown: orient = "portraitUpsideDown"
            case .landscapeLeft: orient = "landscapeLeft"
            case .landscapeRight: orient = "landscapeRight"
            default: orient = "unknown(\(String(describing: c?.videoOrientation.rawValue)))"
            }
            let gravity: String
            switch l.videoGravity {
            case .resizeAspectFill: gravity = "resizeAspectFill"
            case .resizeAspect: gravity = "resizeAspect"
            case .resize: gravity = "resize"
            default: gravity = "other"
            }
            return "gravity=\(gravity) orientation=\(orient) mirrored=\(c?.isVideoMirrored ?? false) autoMirror=\(c?.automaticallyAdjustsVideoMirroring ?? false) frame=\(l.frame) bounds=\(l.bounds)"
        }
    }
}
