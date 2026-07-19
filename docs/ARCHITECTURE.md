# Архитектура Petanque-Z

## Обзор

Petanque-Z — нативное iOS-приложение на SwiftUI. Камера захватывает кадры через AVFoundation, кадры анализируются Core ML-моделью (YOLO), в Phase 2 поверх добавляется ARKit для построения 3D-карты сцены.

## Стек

| Слой | Технология |
|---|---|
| UI | SwiftUI + (где нужно) `UIViewRepresentable` для `AVCaptureVideoPreviewLayer` |
| Захват камеры | AVFoundation (`AVCaptureSession`) |
| Детекция | Core ML (`Detector.mlpackage`, YOLOv10n, 640×640 вход) |
| AR (Phase 2) | ARKit (`ARSession`, мировая СК, raycast) |
| Идентификация (Phase 3) | Core ML / MobileNet embedding + косинусное расстояние |
| Сборка | XcodeGen (`project.yml` → `*.xcodeproj`) |
| Язык | Swift 5.9, строгая конкурентность (`SWIFT_STRICT_CONCURRENCY: complete`) |

## Структура папок

```
PetanqueZ/
├── App/             ← @main, RootView, глобальные настройки
├── Features/
│   ├── Camera/      ← AVCaptureSession, превью
│   ├── Detection/   ← YOLODetector, оверлей bbox
│   ├── AR/          ← ARSessionManager (Phase 2)
│   └── Scoring/     ← команды, счёт (Phase 3)
├── Domain/          ← модели данных: Detection, AppState, …
└── Resources/       ← Assets.xcassets, Detector.mlpackage
```

## Поток данных (Phase 1)

```
Камера (AVCaptureVideoDataOutput)
   │  CIImage / CVPixelBuffer
   ▼
CameraSession.onFrame  ──►  фоновой очередь (.userInitiated)
   │
   ▼
YOLODetector.processFrame(_:confidenceThreshold:)  →  [Detection]
   │   • letterbox 640×640
   │   • Detector.prediction(image:)
   │   • парсинг тензора var_1198 [1, N, 6]
   │   • unletterbox bbox → нормализованные [0..1]
   ▼
AppState ( @Observable )  ──►  SwiftUI перерисовка
   │
   ▼
DetectionOverlay (Canvas)  →  bbox на экране
```

## Модель детекции

- **Файл:** `PetanqueZ/Resources/Detector.mlpackage`
- **Архитектура:** YOLOv10n (nano), обучена на датасете Roboflow "tipe-petank"
- **Классы:** 2 — `BOULE` (шар, индекс 0), `COCHONNET` (индекс 1)
- **Вход:** `image: CVPixelBuffer` 640×640 BGRA
- **Выход:** `var_1198` — тензор `[1, N, 6]`, строка = `[x1, y1, x2, y2, score_boule, score_cochonnet]`
- **Размер весов:** ~4.6 МБ

Xcode автоматически генерирует Swift-класс `Detector` из `.mlpackage` при сборке. Имя входа/выхода берётся из модели.

## Конкурентность

- `CameraSession` — `@MainActor ObservableObject`; захват делегируется в `sessionQueue` / `dataOutputQueue`.
- `YOLODetector` — `final class … @unchecked Sendable`, инференс синхронный, запускать на фоновой очереди.
- UI обновляется только на главном потоке.
- Строгая конкурентность включена (`SWIFT_STRICT_CONCURRENCY: complete`).

## Конфигурация сборки

`project.yml` (XcodeGen):
- target `PetanqueZ`, тип `application`, платформа iOS
- `deploymentTarget.iOS: "17.0"`
- `PRODUCT_BUNDLE_IDENTIFIER: com.alexfrompiter.petanque-z`
- `TARGETED_DEVICE_FAMILY: "1"` (только iPhone)
- `INFOPLIST_FILE: PetanqueZ/Info.plist`, `GENERATE_INFOPLIST_FILE: NO`
- линкует `ARKit.framework`, `SceneKit.framework`
- бандлит `PetanqueZ/Resources` и `Detector.mlpackage`
- отдельный target `PetanqueZTests` для unit-тестов

## Инструкции для запуска

```bash
# Сгенерировать Xcode-проект
xcodegen generate

# Собрать для симулятора (проверка компиляции)
xcodebuild -scheme PetanqueZ -sdk iphonesimulator build

# Запустить тесты
xcodebuild test -scheme PetanqueZ -destination 'platform=iOS Simulator,name=iPhone 16'

# Открыть в Xcode
open PetanqueZ.xcodeproj
```

> ⚠️ Камера и детекция **не работают в iOS Simulator**. Для проверки нужна реальная сборка на iPhone.

## Риски и ограничения

- **Без LiDAR** точность AR-расстояний (Phase 2) — ±5–15 см. Граничные случаи (шары на 2–3 см) могут определяться неверно.
- **Re-идентификация шаров** (Phase 3) одного игрока очень сложна: металлические сферы визуально неразличимы. Реалистично отличать команды (если у шаров разные цвет/рисунок).
- **iOS Simulator** не подходит для Phase 1+ — нужен физический iPhone.
