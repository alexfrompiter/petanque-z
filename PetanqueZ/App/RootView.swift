import CoreImage
import SwiftUI

/// Корневой экран: превью камеры с оверлеем детекций + HUD с FPS и счётчиком.
struct RootView: View {
    @StateObject private var camera = CameraSession()
    @State private var state = AppState()

    /// Запускается на фоновой очереди — один экземпляр на всё время жизни экрана.
    @State private var detector = YOLODetector()
    private let inferenceQueue = DispatchQueue(
        label: "com.alexfrompiter.petanque-z.inference",
        qos: .userInitiated
    )

    /// Порог уверенности детекции (доступен для будущих настроек).
    @State private var confidenceThreshold: Float = YOLODetector.defaultConfidenceThreshold

    /// Размер входного изображения (узнаём из первого кадра).
    @State private var imageSize: CGSize = CGSize(width: 1920, height: 1080)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                if camera.status == .running {
                    ZStack {
                        CameraPreviewView(session: camera.session)
                        DetectionOverlay(
                            detections: state.detections,
                            imageSize: imageSize,
                            canvasSize: geo.size
                        )
                    }
                } else {
                    placeholderView
                }
            }
            .ignoresSafeArea()

            VStack {
                if camera.status == .running {
                    hud
                } else {
                    statusBanner
                }
                Spacer()
            }
        }
        .task {
            // Подключаем обработчик кадров: детекция на фоновой очереди,
            // обновление состояния — на главном потоке.
            camera.onFrame = { [detector, inferenceQueue] ciImage in
                let threshold = confidenceThreshold
                let extent = ciImage.extent
                let size = CGSize(width: extent.width, height: extent.height)
                inferenceQueue.async {
                    let detections = detector.processFrame(
                        ciImage,
                        confidenceThreshold: threshold
                    )
                    Task { @MainActor in
                        if size != imageSize { imageSize = size }
                        state.update(detections: detections)
                    }
                }
            }
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    // MARK: - HUD

    @ViewBuilder
    private var hud: some View {
        HStack(spacing: 12) {
            HudChip(
                icon: "circle.grid.cross",
                text: "\(state.boulesCount) шаров"
            )
            HudChip(
                icon: "scope",
                text: "\(state.cochonnetsCount) кош."
            )
            HudChip(
                icon: "speedometer",
                text: String(format: "%.0f FPS", state.fps)
            )
        }
        .padding(.top, 8)
    }

    // MARK: - Placeholder / status

    @ViewBuilder
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: iconForStatus)
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text(titleForStatus)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            if case .denied = camera.status {
                Button("Открыть настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var statusBanner: some View {
        Text(statusText)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 8)
    }

    // MARK: - Helpers

    private var iconForStatus: String {
        switch camera.status {
        case .idle, .authorizing: return "camera"
        case .denied: return "camera.metering.unknown"
        case .failed: return "exclamationmark.triangle"
        case .running: return "circle.grid.cross"
        }
    }

    private var titleForStatus: String {
        switch camera.status {
        case .idle: return "Petanque-Z"
        case .authorizing: return "Запрашиваем доступ к камере…"
        case .denied: return "Доступ к камере запрещён"
        case .failed(let message): return message
        case .running: return ""
        }
    }

    private var statusText: String {
        switch camera.status {
        case .authorizing: return "Нажмите «Разрешить» в системном диалоге"
        default: return ""
        }
    }
}

// MARK: - HUD chip

private struct HudChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .monospacedDigit()
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
