import CoreGraphics
import Foundation

/// Класс детектируемого объекта.
enum DetectionClass: String, Codable, Hashable, Sendable {
    /// Шар (boule).
    case boule
    /// Кошонет (маленький целевой шар).
    case cochonnet

    /// Человекочитаемое название класса на русском.
    var displayName: String {
        switch self {
        case .boule: return "Шар"
        case .cochonnet: return "Кошонет"
        }
    }

    /// Цвет ассоциированный с классом для оверлея.
    var overlayColorHex: String {
        switch self {
        case .boule: return "#4DD864"      // зелёный
        case .cochonnet: return "#FFD60A"  // жёлтый
        }
    }
}

/// Один объект, найденный детектором в кадре.
///
/// `bbox` — нормализованные координаты [0..1] в системе координат исходного
/// изображения (до letterbox). `origin` = левый-верхний угол, как у `CGRect`.
struct Detection: Hashable, Identifiable, Sendable {
    let id: String
    let cls: DetectionClass
    let bbox: CGRect
    let score: Float
}
