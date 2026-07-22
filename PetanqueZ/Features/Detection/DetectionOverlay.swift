import SwiftUI

/// Оверлей, рисующий bbox детекций поверх превью камеры.
///
/// Детекции приходят в нормализованных координатах [0..1] исходного
/// изображения (landscape, 1920×1080). `AVCaptureVideoPreviewLayer`
/// автоматически поворачивает кадр на 90° CW для портретного экрана
/// и применяет `resizeAspectFill`.
struct DetectionOverlay: View {
    let detections: [Detection]
    /// Физический размер входного изображения (landscape, например 1920×1080).
    let imageSize: CGSize
    /// Размер области рисования (экран, портрет, например 393×852).
    let canvasSize: CGSize

    var body: some View {
        Canvas { context, size in
            for detection in detections {
                guard let rect = frameRect(for: detection, in: size) else { continue }
                drawBox(in: rect, color: detection.cls.overlayColorHex, context: &context)
            }
        }
        .allowsHitTesting(false)
    }

    /// Преобразует нормализованный bbox в экранный прямоугольник.
    ///
    /// CW 90° поворот ландшафтного кадра в портретный:
    ///   (nx, ny) в ландшафте → (1-ny, nx) в портрете.
    /// После поворота эффективный размер кадра: imgH × imgW (1080×1920).
    ///
    /// Затем AspectFill: scale = max(screenW/imgH, screenH/imgW),
    /// обрезка по оси, которая шире экрана.
    private func frameRect(for detection: Detection, in screenSize: CGSize) -> CGRect? {
        Self.transform(detection.bbox, image: imageSize, screen: screenSize)?.rect
    }

    /// Детали преобразования bbox в экранные координаты (для рисования и лога).
    struct Transform: CustomStringConvertible {
        let rect: CGRect       // итоговый экранный прямоугольник (до intersection)
        let scale: CGFloat     // коэффициент AspectFill
        let scaledW: CGFloat   // ширина кадра на экране
        let scaledH: CGFloat   // высота кадра на экране
        let cropX: CGFloat     // горизонтальная обрезка
        let cropY: CGFloat     // вертикальная обрезка

        var description: String {
            String(format: "rect=[%.1f,%.1f %.1fx%.1f] scale=%.4f scaled=%.1fx%.1f crop=[%.1f,%.1f]",
                   rect.minX, rect.minY, rect.width, rect.height,
                   scale, scaledW, scaledH, cropX, cropY)
        }
    }

    /// Статическое преобразование нормализованного bbox в экранные координаты.
    /// Используется и оверлеем, и логированием (одна математика — один источник правды).
    static func transform(_ bbox: CGRect, image: CGSize, screen: CGSize) -> Transform? {
        guard let imgW = image.width.nonZero,
              let imgH = image.height.nonZero,
              screen.width > 0, screen.height > 0 else { return nil }

        let scaleX = screen.width / imgH
        let scaleY = screen.height / imgW
        let scale = max(scaleX, scaleY)

        let scaledW = imgH * scale
        let scaledH = imgW * scale

        let cropX = max(0, (scaledW - screen.width) / 2)
        let cropY = max(0, (scaledH - screen.height) / 2)

        // CW 90°: image_Y → screen_X (инверсия), image_X → screen_Y.
        let x = (1.0 - bbox.maxY) * scaledW - cropX
        let y = bbox.minX * scaledH - cropY
        let w = bbox.height * scaledW
        let h = bbox.width * scaledH

        return Transform(
            rect: CGRect(x: x, y: y, width: w, height: h),
            scale: scale, scaledW: scaledW, scaledH: scaledH,
            cropX: cropX, cropY: cropY
        )
    }

    private func drawBox(
        in rect: CGRect,
        color hex: String,
        context: inout GraphicsContext
    ) {
        guard rect.width > 1, rect.height > 1 else { return }
        let color = Color(hex: hex)
        context.stroke(Path(rect), with: .color(color), lineWidth: 3)
    }
}

// MARK: - Helpers

private extension CGFloat {
    var nonZero: CGFloat? { self > 0 ? self : nil }
}

extension Color {
    /// Создаёт Color из HEX-строки вида "#RRGGBB" или "RRGGBB".
    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
