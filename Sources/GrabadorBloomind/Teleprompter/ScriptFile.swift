import AppKit
import UniformTypeIdentifiers

/// Traer el guion desde un archivo: Word, texto plano, Markdown, RTF o
/// OpenDocument (decisión 118).
///
/// Lo lee AppKit, que ya sabe abrir todos esos formatos sin una sola dependencia
/// de más, así que no hay que descomprimir el `.docx` a mano ni meter una
/// librería al proyecto.
///
/// **Un Google Docs no se puede leer directo**: eso pediría red y una cuenta, y
/// la app no toca la red (decisión 14). El camino es bajarlo con Archivo →
/// Descargar → Word (.docx) y cargar ese archivo.
enum ScriptFile {

    /// Lo que se puede elegir en el cuadro de abrir. El texto plano cubre
    /// también el `.md`, que conforma a ese tipo.
    static var tiposSoportados: [UTType] {
        [.plainText, .rtf] + [
            "org.openxmlformats.wordprocessingml.document",   // .docx
            "com.microsoft.word.doc",                         // .doc
            "org.oasis-open.opendocument.text"                // .odt
        ].compactMap { UTType($0) }
    }

    /// El texto pelado de un documento.
    ///
    /// Del archivo se toma **solo el texto**: el teleprompter no muestra
    /// negritas ni tamaños, y arrastrar el formato ajeno obligaría a pelearlo
    /// justo cuando lo único que se quiere es leer.
    ///
    /// Devuelve nil si el archivo no trae texto —un PDF escaneado, una imagen—,
    /// para que quien llama avise en vez de cargar un guion vacío en silencio.
    static func texto(de url: URL) -> String? {
        if let documento = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
            let texto = documento.string
            if !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return texto }
        }
        // Último recurso: si el formato no se reconoció, se intenta como texto
        // plano. Un `.md` exportado con una extensión rara entra por acá.
        guard let plano = try? String(contentsOf: url, encoding: .utf8),
              !plano.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return plano
    }
}
