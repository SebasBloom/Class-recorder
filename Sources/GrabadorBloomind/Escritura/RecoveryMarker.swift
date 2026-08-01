import Foundation

/// Detecta grabaciones que no cerraron bien.
///
/// Mientras se graba existe un archivo marcador con la ruta del video. Al cerrar
/// normalmente se borra. Si al arrancar la app el marcador sigue ahí, es que el
/// proceso murió a mitad de una grabación: se avisa y se ofrece abrir la carpeta.
///
/// Es la contraparte visible de la resistencia a fallos de la Fase 1. El archivo
/// fragmentado ya era recuperable; lo que faltaba era que alguien te lo dijera en
/// vez de que lo descubrieras solo.
enum RecoveryMarker {

    private static var url: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Grabador Bloomind/grabando.txt")
    }

    /// Deja constancia de que hay una grabación en curso.
    static func begin(outputURL: URL) {
        try? outputURL.path.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Borra la constancia. Se llama cuando la grabación cerró bien.
    static func end() {
        try? FileManager.default.removeItem(at: url)
    }

    /// La grabación que quedó a medias, si hay alguna y el archivo todavía existe.
    ///
    /// Se consume al leerla: el marcador se borra, así que el aviso aparece una
    /// sola vez y no en cada arranque.
    static func consumePending() -> URL? {
        guard let ruta = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        end()

        let archivo = URL(fileURLWithPath: ruta)
        guard FileManager.default.fileExists(atPath: archivo.path) else { return nil }
        return archivo
    }
}
