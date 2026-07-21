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

    /// Количество кошонетов в last кадре.
    private(set) var cochonnetsCountValue: Int = 0

    /// Человекочитаемое количество кошонетов (для совместимости со старым API).
    var cochonnetsCount: Int { cochonnetsCountValue }

    /// Оценка FPS детекции на основе временных меток последних кадров.
    private(set) var fps: Double = 0

    /// Последнее измеренное значение FPS камеры.
    private(set) var cameraFPS: Int = 30

    private var frameTimestamps: [TimeInterval] = []
    private let fpsWindow = 30  // окно сглаживания

    // MARK: Throttle

    /// Время следующего разрешённого инференса (троттлинг по целевому FPS).
    private var nextAllowedInferenceTime: TimeInterval = 0

    /// Проверяет, разрешено ли в данный момент запускать инференс по троттлингу.
    ///
    /// - Parameter targetFPS: целевая частота детекции.
    /// - Parameter now: текущее время.
    /// - Returns: `true`, если инференс разрешён и внутреннее состояние обновлено.
    func throttleShouldAllow(targetFPS: Int, now: TimeInterval) -> Bool {
        guard targetFPS > 0 else { return false }
        if now < nextAllowedInferenceTime { return false }
        nextAllowedInferenceTime = now + 1.0 / Double(targetFPS)
        return true
    }

    /// Сбрасывает троттлинг (например, после паузы/возобновления работы).
    func resetThrottle() {
        nextAllowedInferenceTime = 0
    }

    // MARK: Update

    /// Обновляет состояние новыми детекциями и пересчитывает FPS.
    func update(detections: [Detection], at timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.detections = detections
        cochonnetsCountValue = detections.filter { $0.cls == .cochonnet }.count
        recomputeFPS(at: timestamp)
    }

    /// Обновляет FPS камеры на основе данных AVFoundation.
    func updateCameraFPS(_ fps: Int) {
        cameraFPS = max(1, fps)
    }

    private func recomputeFPS(at timestamp: TimeInterval) {
        frameTimestamps.push(timestamp, limit: fpsWindow)
        guard frameTimestamps.count >= 2,
              let first = frameTimestamps.first,
              let last = frameTimestamps.last,
              last > first
        else { return }
        fps = Double(frameTimestamps.count - 1) / (last - first)
    }
}

// MARK: - Helpers

private extension Array where Element == TimeInterval {
    /// Добавляет элемент и обрезает массив до `limit` последних элементов.
    mutating func push(_ element: Element, limit: Int) {
        append(element)
        if count > limit {
            removeFirst(count - limit)
        }
    }
}
