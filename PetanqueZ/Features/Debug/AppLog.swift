import Foundation
import OSLog

/// Простой логгер: пишет в файл `petanque-z-debug.log` в Caches и в OS Log.
///
/// Потокобезопасный. Файл rotates — обрезается до `maxFileBytes` при превышении.
final class AppLog: @unchecked Sendable {

    static let shared = AppLog()

    private let queue = DispatchQueue(label: "com.alexfrompiter.petanque-z.log")
    private let logger = Logger(subsystem: "com.alexfrompiter.petanque-z", category: "app")
    private let maxFileBytes = 1_000_000  // ~1 MB
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private lazy var fileURL: URL? = {
        let fm = FileManager.default
        guard let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = caches.appendingPathComponent("petanque-z-debug.log")
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil)
        }
        return url
    }()

    private init() {}

    // MARK: - Public

    /// Полный путь к файлу лога (для отображения пользователю).
    var logFilePath: String? { fileURL?.path }

    /// Записывает строку в лог.
    func log(_ message: String, level: OSLogType = .default) {
        let line = "[\(dateFormatter.string(from: Date()))] \(message)\n"
        queue.async { [weak self] in
            self?.writeToFile(line)
        }
        switch level {
        case .error: self.logger.error("\(message, privacy: .public)")
        case .info:  self.logger.info("\(message, privacy: .public)")
        default:     self.logger.log("\(message, privacy: .public)")
        }
        // Дублируем в stdout для удобства при отладке через Xcode console.
        print(line, terminator: "")
    }

    /// Считывает всё содержимое лога (для шеринга).
    func readAll() -> String {
        guard let fileURL else { return "" }
        return (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    /// Очищает лог.
    func clear() {
        queue.async { [weak self] in
            guard let self, let fileURL = self.fileURL else { return }
            try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Private

    private func writeToFile(_ line: String) {
        guard let fileURL else { return }
        let fm = FileManager.default
        // Rotate если файл слишком большой.
        if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? UInt64,
           size > maxFileBytes {
            // Оставляем последнюю половину.
            if let data = try? Data(contentsOf: fileURL),
               data.count > maxFileBytes / 2 {
                let tail = data.suffix(maxFileBytes / 2)
                try? tail.write(to: fileURL)
            } else {
                try? "".write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            if let data = line.data(using: .utf8) {
                handle.write(data)
            }
            try? handle.close()
        }
    }
}
