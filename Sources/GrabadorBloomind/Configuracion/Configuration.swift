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

/// Un guion cargado desde un archivo, con el nombre que se muestra en su
/// pestaña dentro del teleprompter.
struct StoredScript: Codable, Equatable {
    var nombre: String
    var texto: String
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
    /// Nombre de la sesión, que va en el nombre del archivo.
    var lastSessionName: String?
    /// Área personalizada de captura, en coordenadas globales. Nulo significa
    /// pantalla entera.
    var customArea: StoredRect?

    /// Color del lienzo del tablero: "blanco" o "negro".
    var boardColor: String?

    var bubbleFrame: StoredRect?
    /// La esquina de arriba a la derecha del widget, que es la que se queda
    /// quieta cuando la cápsula crece, se achica o pasa a modo mini. Reemplaza
    /// al origen que se guardaba antes de la Fase 16: un origen abajo a la
    /// izquierda se corre cada vez que cambia el ancho.
    var widgetTopRight: StoredPoint?
    /// El widget achicado a solo el cronómetro (decisión 125).
    var widgetMini: Bool = false

    /// El círculo amarillo del cursor y la onda del clic. Arranca prendido: es
    /// el comportamiento de siempre y lo que se quiere en un tutorial.
    var cursorHighlightEnabled: Bool = true

    /// Guion del teleprompter y sus valores de arranque. Es lo que se carga en
    /// el panel antes de grabar: lo que se ajuste con la grabación corriendo
    /// vive solo mientras dura esa grabación (decisión 91).
    var teleprompterScript: String?
    /// Guiones traídos de archivos, en el orden en que se van a ver. El guion
    /// escrito a mano en el panel va aparte, en `teleprompterScript`.
    var teleprompterScripts: [StoredScript] = []
    var teleprompterSpeed: Double = 5
    var teleprompterFontSize: Double = 38

    /// Atajos reasignados por el usuario: acción -> combinación. Vacío significa
    /// "todos en su valor por defecto".
    var shortcuts: [String: Shortcut] = [:]

    static var defaultOutputFolder: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/Grabador Bloomind", isDirectory: true)
            .path
    }

    init() {}

    /// Lectura tolerante: **un campo que no está en el archivo toma su valor por
    /// defecto** en vez de invalidar la configuración entera.
    ///
    /// Sin esto, la decodificación sintetizada de Swift exige que todos los
    /// campos no opcionales estén presentes, aunque el struct los declare con un
    /// valor por defecto: ese valor lo usa `init()`, no `init(from:)`. La
    /// consecuencia práctica, ya vista en carne propia, es que **agregar un campo
    /// manda a `config.json.dañado` la configuración de quien venía usando la
    /// app**, con sus atajos y su burbuja adentro. No se pierde, porque la
    /// decisión 21 la aparta en vez de pisarla, pero la app arranca de fábrica
    /// sin motivo (decisión 96).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        outputFolder     = try c.decodeIfPresent(String.self, forKey: .outputFolder) ?? Configuration.defaultOutputFolder
        countdownEnabled = try c.decodeIfPresent(Bool.self, forKey: .countdownEnabled) ?? true
        lastDisplayID    = try c.decodeIfPresent(UInt32.self, forKey: .lastDisplayID)
        lastAudioMode    = try c.decodeIfPresent(String.self, forKey: .lastAudioMode)
        lastMicrophoneID = try c.decodeIfPresent(String.self, forKey: .lastMicrophoneID)
        lastCameraID     = try c.decodeIfPresent(String.self, forKey: .lastCameraID)
        lastSessionName  = try c.decodeIfPresent(String.self, forKey: .lastSessionName)
        customArea       = try c.decodeIfPresent(StoredRect.self, forKey: .customArea)
        boardColor       = try c.decodeIfPresent(String.self, forKey: .boardColor)
        bubbleFrame      = try c.decodeIfPresent(StoredRect.self, forKey: .bubbleFrame)
        widgetTopRight   = try c.decodeIfPresent(StoredPoint.self, forKey: .widgetTopRight)
        widgetMini       = try c.decodeIfPresent(Bool.self, forKey: .widgetMini) ?? false
        cursorHighlightEnabled = try c.decodeIfPresent(Bool.self, forKey: .cursorHighlightEnabled) ?? true
        teleprompterScript   = try c.decodeIfPresent(String.self, forKey: .teleprompterScript)
        teleprompterScripts  = try c.decodeIfPresent([StoredScript].self, forKey: .teleprompterScripts) ?? []
        teleprompterSpeed    = try c.decodeIfPresent(Double.self, forKey: .teleprompterSpeed) ?? 5
        teleprompterFontSize = try c.decodeIfPresent(Double.self, forKey: .teleprompterFontSize) ?? 38
        shortcuts        = try c.decodeIfPresent([String: Shortcut].self, forKey: .shortcuts) ?? [:]
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
