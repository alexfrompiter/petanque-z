import SwiftUI

/// Оверлей, рисующий bbox детекций поверх превью камеры.
///
/// Детекции приходят в нормализованных координатах [0..1] исходного
/// изображения (landscape, width > height). Этот view отображает их с учётом
/// того, что `AVCaptureVideoPreviewLayer` использует `resizeAspectFill` и
/// показывает landscape-кадр в портретном экране.
struct DetectionOverlay: View {
    let detections: [Detection]
    /// Физический размер входного изображения (например, 1920×1080).
    let imageSize: CGSize
    /// Размер области вывода (экран).
    let canvasSize: CGSize

    var body: some View {
        Canvas { context, size in
            for detection in detections {
                guard let rect = frameRect(for: detection, in: size) else { continue }
                drawDetection(in: rect, detection: detection, context: &context)
            }
        }
        .allowsHitTesting(false)
    }

    /// Преобразует нормализованный bbox детекции в экранный прямоугольник.
    ///
    /// При `resizeAspectFill` кадр масштабируется так, чтобы **короткая** сторона
    /// изображения покрыла **длинную** сторону экрана (с обрезкой по другой оси).
    /// Для портретного экрана и landscape-кадра: высота кадра → ширина экрана.
    private func frameRect(for detection: Detection, in size: CGSize) -> CGRect? {
        guard let imgW = imageSize.width.nonZero,
              let imgH = imageSize.height.nonZero,
              size.width > 0, size.height > 0 else { return nil }

        let scale = size.width / imgH            // высота кадра → ширина экрана
        let scaledImgH = imgW * scale            // ширина кадра в экранных пикселях
        let cropY = (scaledImgH - size.height) / 2  // сколько уходит в обрезку сверху/снизу

        // Координаты в кадре (X вдоль длинной стороны, Y вдоль короткой)
        // поворачиваются на 90°: X_кадра → Y_экрана, Y_кадра → X_экрана.
        let x = detection.bbox.minY * size.width
        let y = detection.bbox.minX * scale - cropY
        let w = detection.bbox.height * size.width
        let h = detection.bbox.width * scale

        return CGRect(x: x, y: y, width: w, height: h).intersection(
            CGRect(origin: .zero, size: size)
        )
    }

    private func drawDetection(
        in rect: CGRect,
        detection: Detection,
        context: inout GraphicsContext
    ) {
        guard rect.width > 1, rect.height > 1 else { return }

        let color = Color(hex: detection.cls.overlayColorHex)
        context.stroke(Path(rect), with: .color(color), lineWidth: 3)

        // Подпись: класс + процент уверенности.
        let label = String(
            format: "%@ %.0f%%",
            detection.cls.displayName as NSString,
            detection.score * 100
        )
        let fontSize: CGFloat = 13
        let text = Text(label)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundColor(.white)
        let resolved = context.resolve(text)
        let pad: CGFloat = 4
        let labelW = resolved.measure(in: CGSize(width: 220, height: fontSize + 8)).width
        let labelH: CGFloat = fontSize + 8
        var labelOrigin = CGPoint(x: rect.minX, y: rect.minY - labelH)
        if labelOrigin.y < 0 { labelOrigin.y = rect.minY }
        let bgRect = CGRect(
            x: labelOrigin.x, y: labelOrigin.y,
            width: labelW + pad * 2, height: labelH
        )
        context.fill(Path(bgRect), with: .color(color.opacity(0.9)))
        context.draw(resolved, at: CGPoint(x: bgRect.midX, y: bgRect.midY), anchor: .center)
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
