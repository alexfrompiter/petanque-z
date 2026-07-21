import SwiftUI
import UniformTypeIdentifiers

/// Sheet для шаринга файла лога.
struct ShareLogView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let logText = AppLog.shared.readAll()
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("petanque-z-debug-\(Date().timeIntervalSince1970).txt")
        try? logText.write(to: tempURL, atomically: true, encoding: .utf8)

        return UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Ничего — VC не меняется.
    }
}
