# Статус проекта Petanque-Z

Последнее обновление: 2026-07-19

## Сводка по фазам

| Фаза | Статус | Тег |
|---|---|---|
| Phase 0 — каркас репозитория | ✅ Готово | — |
| Phase 1 — камера + детекция | 🚧 В работе | — |
| Phase 2 — ARKit + расстояния | ⏳ Не начата | — |
| Phase 3 — команды + счёт | ⏳ Не начата | — |

## Что работает

- ✅ Git-репозиторий инициализирован
- ✅ Репозиторий на GitHub создан: https://github.com/alexfrompiter/petanque-z
- ✅ Документация: ROADMAP, ARCHITECTURE, STATUS, devlog
- ✅ Core ML модель (`Detector.mlpackage`) скопирована из `~/projects/petanque`

## В работе (Phase 1)

- 🚧 Каркас Xcode-проекта
- 🚧 Захват камеры (AVFoundation)
- 🚧 Детекция YOLO (Core ML)
- 🚧 Оверлей bbox
- 🚧 Unit-тесты

## Заблокировано

(пусто)

## Следующие шаги

1. Создать `project.yml`, `Info.plist`, `PetanqueZApp.swift`
2. Сгенерировать Xcode-проект: `xcodegen generate`
3. Реализовать захват камеры
4. Реализовать детекцию YOLO
5. Реализовать оверлей
6. Написать тесты, поставить тег `phase1-camera`

См. [ROADMAP.md](./ROADMAP.md) для полного плана.
