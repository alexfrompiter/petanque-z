import CoreML
import XCTest
@testable import PetanqueZ

/// Тесты YOLODetector — проверяют парсинг выходного тензора модели.
///
/// Инференс с реальной моделью и кадром в симуляторе не тестируется
/// (камера недоступна в симуляторе). Тестируется логика разбора тензора,
/// преобразование координат, пороги и маппинг классов.
final class YOLODetectorTests: XCTestCase {

    private func makeDetector() -> YOLODetector { YOLODetector() }

    /// Помощник: создаёт MLMultiArray формы [1, N, 6] с заданными строками.
    private func makeMultiArray(rows: [[Float]]) throws -> MLMultiArray {
        let n = rows.count
        let array = try MLMultiArray(shape: [1, NSNumber(value: n), 6], dataType: .float32)
        let ptr = array.dataPointer.assumingMemoryBound(to: Float.self)
        for (i, row) in rows.enumerated() {
            precondition(row.count == 6, "каждая строка должна иметь 6 значений")
            for j in 0..<6 {
                ptr[i * 6 + j] = row[j]
            }
        }
        return array
    }

    // MARK: parseDetections

    func testParseDetections_mapsScoreToCorrectClass() throws {
        let detector = makeDetector()
        let array = try makeMultiArray(rows: [
            // [x1, y1, x2, y2, s_boule, s_cochonnet]
            [320, 320, 420, 420, 0.9, 0.1],   // boule
            [100, 100, 130, 130, 0.2, 0.85],  // cochonnet
        ])

        let result = detector.parseDetections(
            from: array,
            gain: 640.0 / 1920.0,
            padX: 0,
            padY: (640 - 1080 * (640.0 / 1920.0)) / 2,
            imageW: 1920,
            imageH: 1080,
            confidenceThreshold: 0.25
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].cls, .boule)
        XCTAssertEqual(result[1].cls, .cochonnet)
        XCTAssertEqual(result[0].score, 0.9, accuracy: 1e-5)
        XCTAssertEqual(result[1].score, 0.85, accuracy: 1e-5)
    }

    func testParseDetections_dropsLowConfidence() throws {
        let detector = makeDetector()
        let array = try makeMultiArray(rows: [
            [320, 320, 420, 420, 0.1, 0.05],  // оба ниже 0.25
            [320, 320, 420, 420, 0.5, 0.1],   // выше 0.25
        ])

        let result = detector.parseDetections(
            from: array,
            gain: 1, padX: 0, padY: 0,
            imageW: 640, imageH: 640,
            confidenceThreshold: 0.25
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].cls, .boule)
    }

    func testParseDetections_clampsBBoxToUnitRange() throws {
        let detector = makeDetector()
        // Намеренно выходим за [0..1]: bbox частично за пределами кадра.
        let array = try makeMultiArray(rows: [
            [-100, -100, 200, 200, 0.9, 0.1],
        ])

        let result = detector.parseDetections(
            from: array,
            gain: 1, padX: 0, padY: 0,
            imageW: 640, imageH: 640,
            confidenceThreshold: 0.25
        )

        XCTAssertEqual(result.count, 1)
        let bbox = result[0].bbox
        XCTAssertGreaterThanOrEqual(bbox.minX, 0)
        XCTAssertGreaterThanOrEqual(bbox.minY, 0)
        XCTAssertLessThanOrEqual(bbox.maxX, 1)
        XCTAssertLessThanOrEqual(bbox.maxY, 1)
    }

    func testParseDetections_returnsEmptyOnWrongStride() throws {
        let detector = makeDetector()
        let array = try MLMultiArray(shape: [1, 2, 5], dataType: .float32)

        let result = detector.parseDetections(
            from: array,
            gain: 1, padX: 0, padY: 0,
            imageW: 640, imageH: 640,
            confidenceThreshold: 0.25
        )

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: DetectionClass

    func testDetectionClass_displayNamesAreInRussian() {
        XCTAssertEqual(DetectionClass.boule.displayName, "Шар")
        XCTAssertEqual(DetectionClass.cochonnet.displayName, "Кошонет")
    }

    // MARK: AppState

    @MainActor
    func testAppState_countsDetectionsByClass() {
        let state = AppState()
        let base = Date().timeIntervalSince1970
        let detections: [Detection] = [
            Detection(id: "1", cls: .boule, bbox: .zero, score: 0.9),
            Detection(id: "2", cls: .boule, bbox: .zero, score: 0.8),
            Detection(id: "3", cls: .cochonnet, bbox: .zero, score: 0.7),
        ]
        state.update(detections: detections, at: base)
        XCTAssertEqual(state.boulesCount, 2)
        XCTAssertEqual(state.cochonnetsCount, 1)
    }

    @MainActor
    func testAppState_computesFpsOverSlidingWindow() {
        let state = AppState()
        let start = Date().timeIntervalSince1970
        for i in 0..<10 {
            state.update(detections: [], at: start + Double(i) * 0.1)
        }
        // 10 кадров за 0.9 c → ~11 FPS (в пределах погрешности)
        XCTAssertGreaterThan(state.fps, 0)
        XCTAssertLessThan(abs(state.fps - 10.0 / 0.9), 1.5)
    }
}
