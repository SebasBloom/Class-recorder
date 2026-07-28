import Foundation

/// Rectángulo y punto propios en vez de CGRect/CGPoint: los tipos de CoreGraphics
/// se serializan como arreglos anidados ([[x,y],[w,h]]) y el plan exige que
/// config.json se pueda leer a mano.
struct StoredRect: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct StoredPoint: Codable, Equatable {
    var x: Double
    var y: Double
}

/// Configuración central de la app. Un solo archivo, en
/// ~/Library/Application Support/Grabador Bloomind/config.json.
///
/// Borrar ese archivo es un reset de fábrica: la app tiene que arrancar bien sin
/// él y regenerarlo con estos valores por defecto.
struct Configuration: Codable, Equatable {

    /// Carpeta donde se guardan las grabaciones.
    var outputFolder: String = Configuration.defaultOutputFolder

    /// Cuenta regresiva 3, 2, 1 antes de arrancar.
    var countdownEnabled: Bool = true

    // Memoria pegajosa del panel: cada campo recuerda lo último usado. Nulo
    // significa "todavía no se eligió", y cada fase lo llena cuando llega.
    var lastDisplayID: UInt32?
    var lastAudioMode: String?          // valor bruto de AudioMode
    var lastMicrophoneID: String?
    var lastCameraID: String?

    var bubbleFrame: StoredRect?
    var widgetPosition: StoredPoint?

    /// Slot de censura permanente. El de sesión vive solo en memoria y no se
    /// guarda nunca (decisión 5).
    var permanentRedactionRect: StoredRect?

    /// Atajos reasignados por el usuario: acción -> combinación. Vacío significa
    /// "todos en su valor por defecto". Se llena en la Fase 9.
    var shortcuts: [String: String] = [:]

    static var defaultOutputFolder: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/Grabador Bloomind", isDirectory: true)
            .path
    }
}

/// Lee y escribe la configuración en disco.
final class ConfigurationStore {

    static let shared = ConfigurationStore()

    private(set) var current = Configuration()

    private let fileURL: URL

    private init() {
        let folder = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Grabador Bloomind", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("config.json")
    }

    /// Carga el archivo. Si no existe o no se puede leer, arranca con los valores
    /// por defecto y lo regenera.
    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Logger.shared.log("No hay config.json, se crea con valores por defecto")
            current = Configuration()
            save()
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            current = try JSONDecoder().decode(Configuration.self, from: data)
            Logger.shared.log("Configuración cargada")
        } catch {
            // Nunca se descarta el archivo dañado en silencio: se aparta con otro
            // nombre por si hay que mirarlo, y se sigue con los defaults.
            let backup = fileURL.appendingPathExtension("dañado")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            Logger.shared.log("config.json ilegible (\(error.localizedDescription)); se apartó como config.json.dañado y se arranca con valores por defecto")
            current = Configuration()
            save()
        }
    }

    /// Modifica la configuración y la guarda. Todo cambio pasa por acá para que
    /// no queden valores solo en memoria.
    func update(_ change: (inout Configuration) -> Void) {
        change(&current)
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        // withoutEscapingSlashes: sin esto las rutas salen como "\/Users\/…" y el
        // plan exige que config.json se lea cómodo a mano.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            try encoder.encode(current).write(to: fileURL, options: .atomic)
        } catch {
            Logger.shared.log("ERROR guardando la configuración: \(error.localizedDescription)")
        }
    }
}
