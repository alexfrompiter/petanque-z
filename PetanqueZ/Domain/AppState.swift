import Foundation
import Observation

/// Состояние сцены, которое перерисовывает UI при поступлении новых детекций.
@MainActor
@Observable
final class AppState {

    /// Последние полученные детекции (за текущий кадр).
    private(set) var detections: [Detection] = []

    /// Количество шаров в последнем кадре.
    var boulesCount: Int {
        detections.filter { $0.cls == .boule }.count
    }

    /// Количество кошонетов в последнем кадре.
    var cochonnetsCount: Int {
        detections.filter { $0.cls == .cochonnet }.count
    }

    /// Оценка FPS детекции на основе временных меток последних кадров.
    private(set) var fps: Double = 0

    private var frameTimestamps: [TimeInterval] = []
    private let fpsWindow = 30  // окно сглаживания

    /// Обновляет состояние новыми детекциями и пересчитывает FPS.
    func update(detections: [Detection], at timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.detections = detections
        recomputeFPS(at: timestamp)
    }

    private func recomputeFPS(at timestamp: TimeInterval) {
        frameTimestamps.append(timestamp)
        if frameTimestamps.count > fpsWindow {
            frameTimestamps.removeFirst(frameTimestamps.count - fpsWindow)
        }
        guard frameTimestamps.count >= 2,
              let first = frameTimestamps.first,
              let last = frameTimestamps.last,
              last > first
        else { return }
        let span = last - first
        fps = Double(frameTimestamps.count - 1) / span
    }
}
