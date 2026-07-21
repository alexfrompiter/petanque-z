import SwiftUI

/// Панель настроек приложения.
struct SettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        NavigationStack {
            Form {
                detectionSection
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { /* закрывается через presentationDetents */ }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Detection section

    @ViewBuilder
    private var detectionSection: some View {
        Section {
            // FPS детекции
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Частота детекции")
                    Spacer()
                    Text("\(settings.detectionFrameRate) кадр/с")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.detectionFrameRate) },
                        set: { settings.detectionFrameRate = Int($0) }
                    ),
                    in: Double(SettingsStore.minFrameRate)...Double(settings.maxCameraFPS),
                    step: 1
                )
                Text("От \(SettingsStore.minFrameRate) до \(settings.maxCameraFPS) кадр/с (FPS камеры)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Показывать боксы
            Toggle("Показывать шары и кошонеты", isOn: $settings.detectionShowBoxes)
        } header: {
            Text("Детекция")
        } footer: {
            Text("Эти настройки применяются немедленно и сохраняются между запусками.")
        }
    }
}

#Preview {
    SettingsView(settings: SettingsStore())
}
