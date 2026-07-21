import CoreImage
import CoreML
import CoreVideo
import Foundation

/// Детектор шаров и кошонета на основе Core ML-модели Detector (YOLOv10n).
///
/// Синхронный инференс — вызывать на фоновой очереди. Класс потокобезопасный
/// для одновременных вызовов только с одним и тем же экземпляром модели;
/// рекомендуется один экземпляр на очередь инференса.
final class YOLODetector: @unchecked Sendable {

    /// Размер стороны входного тензора модели.
    static let inputSize: CGFloat = 640

    /// Порог уверенности по умолчанию.
    static let defaultConfidenceThreshold: Float = 0.25

    private let model: Detector?
    private let ciContext = CIContext()

    /// Счётчик обработанных кадров (для логирования и отладки).
    private var frameCounter: Int = 0

    init() {
        let config = MLModelConfiguration()
        // Используем CPU/GPU по умолчанию; для ANE можно установить .cpuAndGPU.
        model = try? Detector(configuration: config)
    }

    /// Доступна ли модель (удалось ли загрузить).
    var isAvailable: Bool { model != nil }

    /// Обрабатывает один кадр и возвращает список детекций.
    ///
    /// - Parameters:
    ///   - ciImage: входной кадр.
    ///   - confidenceThreshold: минимальная уверенность (0..1).
    /// - Returns: массив детекций с bbox в нормализованных координатах [0..1]
    ///   относительно исходного изображения.
    func processFrame(
        _ ciImage: CIImage,
        confidenceThreshold: Float = YOLODetector.defaultConfidenceThreshold
    ) -> [Detection] {
        guard let model else { return [] }

        let imageW = ciImage.extent.width
        let imageH = ciImage.extent.height
        guard imageW > 0, imageH > 0 else { return [] }

        guard
            let pixelBuffer = letterboxTo640(ciImage),
            let output = try? model.prediction(image: pixelBuffer)
        else { return [] }

        // Геометрия обратного преобразования letterbox → исходные координаты.
        let gain = min(Self.inputSize / imageW, Self.inputSize / imageH)
        let scaledW = imageW * gain
        let scaledH = imageH * gain
        let padX = (Self.inputSize - scaledW) / 2
        let padY = (Self.inputSize - scaledH) / 2

        return parseDetections(
            from: output.var_1198,
            gain: gain,
            padX: padX,
            padY: padY,
            imageW: imageW,
            imageH: imageH,
            confidenceThreshold: confidenceThreshold
        )
    }

    /// Разбор выходного тензора модели в массив детекций.
    ///
    /// Вынесен в отдельный метод, чтобы его можно было покрыть unit-тестами
    /// с фиктивным `MLMultiArray`.
    ///
    /// Тензор имеет форму `[1, N, 6]`, где каждая строка —
    /// `[x1, y1, x2, y2, score_boule, score_cochonnet]` в пикселях входа 640×640.
    func parseDetections(
        from multiArray: MLMultiArray,
        gain: CGFloat,
        padX: CGFloat,
        padY: CGFloat,
        imageW: CGFloat,
        imageH: CGFloat,
        confidenceThreshold: Float
    ) -> [Detection] {
        let count = multiArray.shape[1].intValue
        let stride = multiArray.shape[2].intValue
        guard stride == 6 else { return [] }

        var detections: [Detection] = []
        let ptr = UnsafeMutablePointer<Float>(OpaquePointer(multiArray.dataPointer))

        for i in 0..<count {
            let offset = i * stride
            let x1 = CGFloat(ptr[offset])
            let y1 = CGFloat(ptr[offset + 1])
            let x2 = CGFloat(ptr[offset + 2])
            let y2 = CGFloat(ptr[offset + 3])
            let sBoule = Float(ptr[offset + 4])
            let sCochonnet = Float(ptr[offset + 5])

            let score: Float
            let cls: DetectionClass
            if sBoule > sCochonnet {
                score = sBoule
                cls = .boule
            } else {
                score = sCochonnet
                cls = .cochonnet
            }
            guard score >= confidenceThreshold else { continue }

            // Обратное преобразование letterbox → нормализованные [0..1].
            let x1n = (x1 - padX) / (imageW * gain)
            let y1n = (y1 - padY) / (imageH * gain)
            let x2n = (x2 - padX) / (imageW * gain)
            let y2n = (y2 - padY) / (imageH * gain)

            let bbox = CGRect(
                x: min(max(x1n, 0), 1),
                y: min(max(y1n, 0), 1),
                width: max(min(x2n, 1) - max(x1n, 0), 0),
                height: max(min(y2n, 1) - max(y1n, 0), 0)
            )

            detections.append(Detection(
                id: "\(cls.rawValue)-\(i)",
                cls: cls,
                bbox: bbox,
                score: score
            ))
        }
        return detections
    }

    // MARK: - Preprocessing

    /// Letterbox-преобразование кадра до 640×640 с заполнением нулями.
    private func letterboxTo640(_ ciImage: CIImage) -> CVPixelBuffer? {
        let target = Self.inputSize
        let gain = min(target / ciImage.extent.width, target / ciImage.extent.height)
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: gain, y: gain))
        let sw = scaled.extent.width
        let sh = scaled.extent.height
        let dx = (target - sw) / 2
        let dy = (target - sh) / 2

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault, Int(target), Int(target),
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            ] as CFDictionary,
            &pixelBuffer
        )
        guard let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        memset(
            CVPixelBufferGetBaseAddress(pixelBuffer),
            0,
            CVPixelBufferGetDataSize(pixelBuffer)
        )
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        let translated = scaled.transformed(by: CGAffineTransform(translationX: dx, y: dy))
        ciContext.render(translated, to: pixelBuffer)
        return pixelBuffer
    }
}
