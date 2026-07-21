import SwiftUI

/// Оверлей, рисующий bbox детекций поверх превью камеры.
///
/// Детекции приходят в нормализованных координатах [0..1] исходного
/// изображения (landscape, 1920×1080). `AVCaptureVideoPreviewLayer`
/// автоматически поворачивает кадр на 90° CCW для портретного экрана
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
                drawDetection(in: rect, detection: detection, context: &context)
            }
        }
        .allowsHitTesting(false)
    }

    /// Преобразует нормализованный bbox в экранный прямоугольник.
    ///
    /// Шаги:
    /// 1. CCW 90° поворот ландшафтного кадра в портретный:
    ///    (nx, ny) в ландшафте → (ny, 1-nx) в портрете.
    ///    После поворота эффективный размер: imgH × imgW (1080×1920).
    /// 2. AspectFill масштабирование портретного кадра к экрану:
    ///    scale = max(screenW / imgH, screenH / imgW).
    /// 3. Обрезка (crop) по оси, которая шире экрана.
    private func frameRect(for detection: Detection, in screenSize: CGSize) -> CGRect? {
        guard let imgW = imageSize.width.nonZero,
              let imgH = imageSize.height.nonZero,
              screenSize.width > 0, screenSize.height > 0 else { return nil }

        // Шаг 2: AspectFill масштаб.
        let scaleX = screenSize.width / imgH
        let scaleY = screenSize.height / imgW
        let scale = max(scaleX, scaleY)

        let scaledW = imgH * scale  // ширина повёрнутого кадра на экране
        let scaledH = imgW * scale  // высота повёрнутого кадра на экране

        // Обрезка по оси X (горизонтальная, если кадр шире экрана).
        let cropX = max(0, (scaledW - screenSize.width) / 2)
        // Обрезка по оси Y (вертикальная, если кадр выше экрана).
        let cropY = max(0, (scaledH - screenSize.height) / 2)

        // Шаг 1 + 2 + 3: маппинг bbox из нормализованного ландшафта в экран.
        // CCW 90°: image_Y → screen_X, image_X → screen_Y (с инверсией 1-x).
        let x = detection.bbox.minY * scaledW - cropX
        let y = (1.0 - detection.bbox.maxX) * scaledH - cropY
        let w = detection.bbox.height * scaledW
        let h = detection.bbox.width * scaledH

        return CGRect(x: x, y: y, width: w, height: h).intersection(
            CGRect(origin: .zero, size: screenSize)
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