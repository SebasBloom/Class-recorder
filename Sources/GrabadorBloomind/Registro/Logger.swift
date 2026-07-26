import Foundation

/// Registro en archivo. Un archivo por grabación en ~/Library/Logs/Grabador Bloomind/,
/// más uno general mientras no hay grabación en curso. Conserva los últimos 20 y
/// borra los más viejos.
///
/// Regla de privacidad (plan, sección 5): acá se registra el evento, nunca el
/// contenido. "Censura permanente activada" sí; qué había en pantalla, jamás.
final class Logger {

    static let shared = Logger()

    private let directory: URL
    private let queue = DispatchQueue(label: "com.bloomind.grabador.log")
    private var handle: FileHandle?

    private static let maxLogFiles = 20

    private lazy var timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {
        directory = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Grabador Bloomind", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Abre un archivo de log nuevo y cierra el anterior. Al arrancar la app se
    /// llama con "app"; al iniciar cada grabación, con el nombre de la sesión.
    func openLog(named name: String) {
        queue.sync {
            closeCurrentHandle()

            let stamp = Self.fileNameFormatter.string(from: Date())
            let url = directory.appendingPathComponent("\(stamp) \(sanitized(name)).log")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)

            pruneOldLogs()
        }
        log("Log abierto: \(name)")
    }

    func log(_ message: String) {
        queue.async { [self] in
            let line = "[\(timestampFormatter.string(from: Date()))] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            handle?.write(data)
        }
    }

    func close() {
        queue.sync { closeCurrentHandle() }
    }

    // MARK: - Interno

    private func closeCurrentHandle() {
        try? handle?.close()
        handle = nil
    }

    /// Deja solo los `maxLogFiles` archivos más recientes.
    private func pruneOldLogs() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey]
        )) ?? []

        let logs = files.filter { $0.pathExtension == "log" }
        guard logs.count > Self.maxLogFiles else { return }

        let sorted = logs.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return da > db
        }
        for url in sorted.dropFirst(Self.maxLogFiles) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Los nombres de sesión los escribe el usuario: hay que sacarles lo que
    /// rompa una ruta de archivo.
    private func sanitized(_ name: String) -> String {
        let clean = name.components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined(separator: "-")
        return clean.isEmpty ? "sesion" : clean
    }

    private static let fileNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH'h'mm'm'ss"
        return f
    }()
}
