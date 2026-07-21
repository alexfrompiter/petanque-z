import Foundation
import Observation

/// Потокобезопасное хранилище настроек приложения с сохранением в `UserDefaults`.
///
/// Использует макрос `@Observable` для интеграции со SwiftUI. Каждое свойство
/// отражается в `UserDefaults`, поэтому значения сохраняются между запусками.
@MainActor
@Observable
final class SettingsStore {

    // MARK: Keys

    private enum Key {
        static let detectionFrameRate = "settings.detection.frameRate"
        static let detectionShowBoxes = "settings.detection.showBoxes"
    }

    // MARK: Detection

    /// Целевая частота детекции (кадров/сек). Гарантированно в диапазоне
    /// `[minFrameRate; maxCameraFPS]`. По умолчанию 10.
    var detectionFrameRate: Int {
        didSet {
            guard detectionFrameRate != oldValue else { return }
            let clamped = Self.clampFrameRate(detectionFrameRate, maxFPS: maxCameraFPS)
            if clamped != detectionFrameRate {
                detectionFrameRate = clamped
            } else {
                defaults.set(detectionFrameRate, forKey: Key.detectionFrameRate)
            }
        }
    }

    /// Показывать ли bbox шаров и кошонетов. По умолчанию `true`.
    var detectionShowBoxes: Bool {
        didSet {
            guard detectionShowBoxes != oldValue else { return }
            defaults.set(detectionShowBoxes, forKey: Key.detectionShowBoxes)
        }
    }

    /// Верхняя граница слайдера FPS детекции (равна FPS камеры).
    /// Меняется в рантайме при определении FPS камеры.
    var maxCameraFPS: Int = 30 {
        didSet {
            guard maxCameraFPS != oldValue else { return }
            let clamped = Self.clampFrameRate(detectionFrameRate, maxFPS: maxCameraFPS)
            if clamped != detectionFrameRate {
                detectionFrameRate = clamped
            }
        }
    }

    /// Минимально допустимое значение FPS детекции.
    static let minFrameRate: Int = 1

    /// Значение FPS по умолчанию.
    static let defaultFrameRate: Int = 10

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Регистрируем дефолты один раз — будут возвращаться, если ключа ещё нет.
        defaults.register(defaults: [
            Key.detectionFrameRate: Self.defaultFrameRate,
            Key.detectionShowBoxes: true,
        ])

        self.detectionFrameRate = Self.clampFrameRate(
            defaults.integer(forKey: Key.detectionFrameRate),
            maxFPS: 30
        )
        self.detectionShowBoxes = defaults.bool(forKey: Key.detectionShowBoxes)
    }

    /// Ограничивает FPS в диапазоне `[minFrameRate; maxFPS]`.
    static func clampFrameRate(_ value: Int, maxFPS: Int) -> Int {
        min(max(value, minFrameRate), max(maxFPS, minFrameRate))
    }
}
