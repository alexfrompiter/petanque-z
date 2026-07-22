import CoreImage
import SwiftUI

/// Корневой экран: превью камеры с оверлеем детекций + HUD + toolbar + меню.
struct RootView: View {
    @State private var camera = CameraSession()
    @State private var state = AppState()
    @State private var settings = SettingsStore()
    @State private var detector = YOLODetector()
    @State private var showSettings = false
    @State private var shareLog = false
    /// Последний измеренный размер экрана — для лога.
    @State private var lastScreenSize: CGSize = .zero
    /// Счётчик кадров для периодического логирования.
    @State private var frameLogCounter = 0

    private let inferenceQueue = DispatchQueue(
        label: "com.alexfrompiter.petanque-z.inference",
        qos: .userInitiated
    )

    /// Размер входного изображения (узнаём из первого кадра).
    @State private var imageSize: CGSize = CGSize(width: 1920, height: 1080)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geo in
                    let content = Group {
                        if camera.status == .running {
                            ZStack {
                                CameraPreviewView(session: camera.session)
                                if settings.detectionShowBoxes {
                                    DetectionOverlay(
                                        detections: state.detections,
                                        imageSize: imageSize,
                                        canvasSize: geo.size
                                    )
                                }
                            }
                        } else {
                            placeholderView
                        }
                    }
                    content
                        .onAppear { lastScreenSize = geo.size }
                        .onChange(of: geo.size) { _, newSize in lastScreenSize = newSize }
                }
                .ignoresSafeArea()

                // Сверху: HUD или статус-баннер
                VStack {
                    if camera.status == .running {
                        hud
                    } else {
                        statusBanner
                    }
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Настройки", systemImage: "gearshape")
                        }
                        Divider()
                        Button {
                            shareLog = true
                        } label: {
                            Label("Поделиться логом", systemImage: "doc.text")
                        }
                        Button {
                            AppLog.shared.clear()
                            AppLog.shared.log("Лог очищен пользователем")
                        } label: {
                            Label("Очистить лог", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        logBugReport()
                    } label: {
                        Image(systemName: "ladybug")
                            .font(.title3)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
        .sheet(isPresented: $shareLog) {
            ShareLogView()
        }
        .task {
            setupFrameHandler()
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: showSettings) { _, isShowing in
            // Пауза камеры/детекции пока открыты настройки — экономим батарею.
            if isShowing {
                camera.stop()
                state.resetThrottle()
            } else {
                camera.start()
                state.resetThrottle()
            }
        }
    }

    // MARK: - HUD

    @ViewBuilder
    private var hud: some View {
        HStack(spacing: 12) {
            HudChip(icon: "circle.grid.cross", text: "\(state.boulesCount) шаров")
            HudChip(icon: "scope", text: "\(state.cochonnetsCount) кош.")
            HudChip(icon: "speedometer", text: String(format: "%.0f FPS", state.fps))
        }
        .padding(.top, 4)
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

    // MARK: - Frame handler

    private func setupFrameHandler() {
        AppLog.shared.log("=== Petanque-Z запущен ===")
        AppLog.shared.log("Настройки: FPS детекции=\(settings.detectionFrameRate), showBoxes=\(settings.detectionShowBoxes)")

        camera.onFrame = { [detector, inferenceQueue, state, settings] ciImage in
            let threshold = YOLODetector.defaultConfidenceThreshold
            let extent = ciImage.extent
            let size = CGSize(width: extent.width, height: extent.height)
            let now = Date().timeIntervalSince1970

            // Троттлинг по целевому FPS из настроек.
            guard state.throttleShouldAllow(targetFPS: settings.detectionFrameRate, now: now) else {
                return
            }

            inferenceQueue.async {
                let detections = detector.processFrame(ciImage, confidenceThreshold: threshold)
                Task { @MainActor in
                    if size != imageSize { imageSize = size }
                    state.update(detections: detections, at: now)
                    logDetectionsPeriodically(detections)
                }
            }
        }
    }

    /// Логирует детекции каждые ~60 обработанных кадров (чтобы не заспамить).
    private func logDetectionsPeriodically(_ detections: [Detection]) {
        frameLogCounter += 1
        guard frameLogCounter % 60 == 0 else { return }
        AppLog.shared.log("Кадр #\(frameLogCounter): \(detections.count) детекций, imageSize=\(imageSize), screen=\(lastScreenSize)")
        for d in detections {
            AppLog.shared.log("  \(d.cls.displayName) score=\(String(format: "%.2f", d.score)) bbox=\(d.bbox)")
        }
    }

    /// Дамп текущего состояния по нажатию 🐛.
    private func logBugReport() {
        AppLog.shared.log("=== 🐛 BUG REPORT ===")
        AppLog.shared.log("Камера: status=\(String(describing: camera.status))")
        AppLog.shared.log("Изображение: \(imageSize)")
        AppLog.shared.log("Экран: \(lastScreenSize)")
        AppLog.shared.log("FPS детекции: \(String(format: "%.1f", state.fps))")
        AppLog.shared.log("Настройки: FPS=\(settings.detectionFrameRate), showBoxes=\(settings.detectionShowBoxes)")
        AppLog.shared.log("Детекций сейчас: \(state.detections.count)")
        for d in state.detections {
            AppLog.shared.log("  \(d.cls.rawValue) score=\(String(format: "%.2f", d.score)) bbox=\(String(format: "%.4f %.4f %.4f %.4f", d.bbox.minX, d.bbox.minY, d.bbox.maxX, d.bbox.maxY))")
        }
        AppLog.shared.log("Путь к логу: \(AppLog.shared.logFilePath ?? "нет")")
        AppLog.shared.log("=== END BUG REPORT ===")
    }
}

// MARK: - HUD chip

private struct HudChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing:  6) {
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
