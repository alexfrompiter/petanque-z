# Devlog Petanque-Z

Дневник разработки. Каждая запись соответствует одному значимому изменению (коммиту или набору коммитов).

## 2026-07-19

### Заведение репозитория и планирование

- Создал локальный git-репозиторий в `/Users/alex/projects/petanque-z`
- Создал репозиторий на GitHub: https://github.com/alexfrompiter/petanque-z
- Установил `gh` CLI, авторизовался как `alexfrompiter`
- Сделал первый коммит (`Initial commit: .gitignore + README`)
- Обсудили идею приложения: помощник для игроков в петанк — измерение расстояний до кошонета и ведение счёта
- Разбили разработку на 3 фазы (см. `ROADMAP.md`):
  - **Phase 1:** камера + детекция YOLO (тег `phase1-camera`)
  - **Phase 2:** ARKit + измерение расстояний (тег `phase2-arkit`)
  - **Phase 3:** команды + идентификация шаров + счёт (тег `phase3-scoring`)
- Нашёл существующий проект `~/projects/petanque/ios` с готовыми наработками
- Решено: начинаем заново в `petanque-z`, копируем только `Detector.mlpackage`
- Зафиксировали параметры:
  - Bundle ID: `com.alexfrompiter.petanque-z`
  - Минимум iOS: 17.0
  - Устройство: обычный iPhone (без LiDAR)
  - Язык интерфейса: русский
- Зафиксировали риски:
  - Без LiDAR точность AR-расстояний будет ±5–15 см
  - Re-идентификация отдельных шаров одного игрока — очень сложна

### Шаг 1 — Документация

- Создал `docs/ROADMAP.md` — три фазы с критериями готовности и тегами отката
- Создал `docs/ARCHITECTURE.md` — стек, структура папок, поток данных, описание модели
- Создал `docs/STATUS.md` — текущее состояние проекта
- Создал `docs/devlog.md` — этот дневник

### Шаг 2 — Каркас Xcode-проекта

- Попутно (пока шло планирование) вручную через Xcode был создан `petanque_z/` проект с неподходящими параметрами (iOS 26.5, bundle `com.alevko.*`). По согласованию удалил его.
- Создал чистую структуру `PetanqueZ/` (App, Features/Camera, Features/Detection, Domain, Resources) и `PetanqueZTests/`
- Скопировал `Detector.mlpackage` (4.5 МБ) из `~/projects/petanque/ios/Petanque/Resources/`
- Написал `project.yml` для XcodeGen:
  - target `PetanqueZ`, iOS 17.0, Swift 5.9, строгая конкурентность
  - Bundle ID `com.alexfrompiter.petanque-z`, только iPhone
  - линкует ARKit + SceneKit
  - бандлит `Assets.xcassets` и `Detector.mlpackage`
- Написал `PetanqueZ/Info.plist` (RU, `NSCameraUsageDescription`, `NSMotionUsageDescription`, capability `arm64`+`arkit`, только портрет)
- Создал пустые `Assets.xcassets` (AppIcon, AccentColor)
- Написал `PetanqueZApp.swift` (`@main`, тёмная тема) и `RootView.swift` (заглушка)
- `xcodegen generate` → создан `PetanqueZ.xcodeproj`
- `xcodebuild build` → ✅ **BUILD SUCCEEDED**. Xcode сам сгенерировал Swift-класс `Detector` из `.mlpackage` — значит модель корректно интегрирована.
- Обновил `.gitignore`: исключил `*.xcodeproj` и `DerivedData` (проект всегда регенерируется из `project.yml`)
- Важно: камера не работает в симуляторе — для проверки Phase 1 потребуется сборка на реальном iPhone.

