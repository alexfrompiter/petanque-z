@preconcurrency import AVFoundation
import CoreImage
import Foundation

/// Управляет жизненным циклом AVCaptureSession:
/// запрос разрешения, конфигурация задней камеры, запуск/останов, доставка кадров.
@MainActor
final class CameraSession: NSObject, ObservableObject {

    /// Состояние сессии для отображения в UI.
    enum Status: Equatable {
        case idle
        case authorizing
        case denied
        case running
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.alexfrompiter.petanque-z.camera.session")
    private let dataOutputQueue = DispatchQueue(
        label: "com.alexfrompiter.petanque-z.camera.output",
        qos: .userInitiated
    )

    /// Вызывается на главном потоке с каждым новым кадром.
    var onFrame: (@MainActor @Sendable (CIImage) -> Void)?

    // MARK: Lifecycle

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            status = .authorizing
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted {
                        self.configureAndStart()
                    } else {
                        self.status = .denied
                    }
                }
            }
        case .denied, .restricted:
            status = .denied
        @unknown default:
            status = .denied
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: Configuration

    private func configureAndStart() {
        let session = self.session
        let dataOutputQueue = self.dataOutputQueue
        sessionQueue.async { [self] in
            session.beginConfiguration()
            session.sessionPreset = .hd1920x1080

            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }

            guard
                let device = AVCaptureDevice.default(
                    .builtInWideAngleCamera, for: .video, position: .back
                ),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                session.commitConfiguration()
                Task { @MainActor in
                    self.status = .failed("Не удалось открыть заднюю камеру")
                }
                return
            }
            session.addInput(input)

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

            session.commitConfiguration()
            session.startRunning()

            Task { @MainActor in self.status = .running }
        }
    }

    // MARK: Frame delivery

    nonisolated private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        Task { @MainActor in
            self.onFrame?(ciImage)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        processFrame(sampleBuffer)
    }
}
