import SwiftUI

/// Корневой экран: показывает превью камеры, статус и управление запуском.
struct RootView: View {
    @StateObject private var camera = CameraSession()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                if camera.status == .running {
                    CameraPreviewView(session: camera.session)
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    placeholderView
                }
            }
            .ignoresSafeArea()

            VStack {
                statusBanner
                Spacer()
            }
        }
        .task {
            camera.start()
        }
    }

    // MARK: Subviews

    @ViewBuilder
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: iconForStatus)
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text(titleForStatus)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            if case .denied = camera.status {
                Button("Открыть настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var statusBanner: some View {
        if camera.status == .running {
            EmptyView()
        } else {
            Text(statusText)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 8)
        }
    }

    // MARK: Helpers

    private var iconForStatus: String {
        switch camera.status {
        case .idle, .authorizing: return "camera"
        case .denied: return "camera.metering.unknown"
        case .failed: return "exclamationmark.triangle"
        case .running: return "circle.grid.cross"
        }
    }

    private var titleForStatus: String {
        switch camera.status {
        case .idle: return "Petanque-Z"
        case .authorizing: return "Запрашиваем доступ к камере…"
        case .denied: return "Доступ к камере запрещён"
        case .failed(let message): return message
        case .running: return ""
        }
    }

    private var statusText: String {
        switch camera.status {
        case .authorizing: return "Нажмите «Разрешить» в системном диалоге"
        default: return ""
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
