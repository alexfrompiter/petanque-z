import XCTest
@testable import PetanqueZ

/// Тесты настроек (`SettingsStore`) и троттлинга детекции (`AppState`).
final class SettingsAndThrottleTests: XCTestCase {

    // MARK: - SettingsStore

    @MainActor
    func testSettingsStore_defaultsWhenEmpty() {
        let defaults = freshDefaults()
        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.detectionFrameRate, SettingsStore.defaultFrameRate)
        XCTAssertEqual(settings.maxCameraFPS, 30)
        XCTAssertTrue(settings.detectionShowBoxes)
    }

    @MainActor
    func testSettingsStore_persistsOnChange() {
        let defaults = freshDefaults()
        let settings = SettingsStore(defaults: defaults)

        settings.detectionFrameRate = 15
        settings.detectionShowBoxes = false

        // Проверяем, что записано в UserDefaults.
        XCTAssertEqual(defaults.integer(forKey: "settings.detection.frameRate"), 15)
        XCTAssertEqual(defaults.bool(forKey: "settings.detection.showBoxes"), false)

        // Новый экземпляр читает те же значения.
        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.detectionFrameRate, 15)
        XCTAssertFalse(restored.detectionShowBoxes)
    }

    @MainActor
    func testSettingsStore_clampsFrameRateToMax() {
        let defaults = freshDefaults()
        let settings = SettingsStore(defaults: defaults)
        settings.maxCameraFPS = 20

        settings.detectionFrameRate = 100  // слишком много
        XCTAssertEqual(settings.detectionFrameRate, 20)

        settings.detectionFrameRate = 0  // слишком мало
        XCTAssertEqual(settings.detectionFrameRate, SettingsStore.minFrameRate)
    }

    @MainActor
    func testSettingsStore_clampsWhenMaxShrinks() {
        let defaults = freshDefaults()
        let settings = SettingsStore(defaults: defaults)
        settings.detectionFrameRate = 25
        settings.maxCameraFPS = 10  // уменьшили верхнюю границу
        XCTAssertEqual(settings.detectionFrameRate, 10)
    }

    @MainActor
    func testSettingsStore_clampFrameRate_static() {
        XCTAssertEqual(SettingsStore.clampFrameRate(0, maxFPS: 30), 1)
        XCTAssertEqual(SettingsStore.clampFrameRate(15, maxFPS: 30), 15)
        XCTAssertEqual(SettingsStore.clampFrameRate(50, maxFPS: 30), 30)
        // Если maxFPS меньше minFrameRate — возвращаем minFrameRate.
        XCTAssertEqual(SettingsStore.clampFrameRate(5, maxFPS: 0), 1)
    }

    // MARK: - AppState throttle

    @MainActor
    func testAppState_throttleAllowsFirstCallThenBlocks() {
        let state = AppState()
        let base = Date().timeIntervalSince1970

        XCTAssertTrue(state.throttleShouldAllow(targetFPS: 10, now: base))
        // Следующий вызов сразу после — должен быть заблокирован (1/10 = 0.1 c).
        XCTAssertFalse(state.throttleShouldAllow(targetFPS: 10, now: base + 0.05))
        // Через 0.1 c — снова разрешено.
        XCTAssertTrue(state.throttleShouldAllow(targetFPS: 10, now: base + 0.11))
    }

    @MainActor
    func testAppState_throttleResetClearsGate() {
        let state = AppState()
        let base = Date().timeIntervalSince1970

        XCTAssertTrue(state.throttleShouldAllow(targetFPS: 5, now: base))
        state.resetThrottle()
        // После сброса — снова разрешено немедленно.
        XCTAssertTrue(state.throttleShouldAllow(targetFPS: 5, now: base + 0.01))
    }

    @MainActor
    func testAppState_throttleRejectsZeroFPS() {
        let state = AppState()
        XCTAssertFalse(state.throttleShouldAllow(targetFPS: 0, now: 0))
    }

    // MARK: - Helpers

    /// Свежий изолированный UserDefaults для каждого теста.
    private func freshDefaults() -> UserDefaults {
        let suite = "petanque-z.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            preconditionFailure("Не удалось создать test UserDefaults suite")
        }
        return defaults
    }
}
