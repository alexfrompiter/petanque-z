import SwiftUI

/// Корневой экран приложения.
struct RootView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "circle.grid.cross")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("Petanque-Z")
                    .font(.largeTitle.bold())
                Text("Каркас готов — Phase 1 в разработке")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding()
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
