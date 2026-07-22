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
        guard let imgW = imageSize.width.nonZero,
              let imgH = imageSize.height.nonZero,
              screenSize.width > 0, screenSize.height > 0 else { return nil }

        // AspectFill масштаб.
        let scaleX = screenSize.width / imgH
        let scaleY = screenSize.height / imgW
        let scale = max(scaleX, scaleY)

        let scaledW = imgH * scale
        let scaledH = imgW * scale

        // Обрезка по осям.
        let cropX = max(0, (scaledW - screenSize.width) / 2)
        let cropY = max(0, (scaledH - screenSize.height) / 2)

        // CW 90°: image_Y → screen_X (инверсия), image_X → screen_Y.
        let x = (1.0 - detection.bbox.maxY) * scaledW - cropX
        let y = detection.bbox.minX * scaledH - cropY
        let w = detection.bbox.height * scaledW
        let h = detection.bbox.width * scaledH

        return CGRect(x: x, y: y, width: w, height: h).intersection(
            CGRect(origin: .zero, size: screenSize)
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
