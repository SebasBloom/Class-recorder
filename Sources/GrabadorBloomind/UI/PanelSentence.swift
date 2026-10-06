import Foundation

/// La oración del panel, armada del estado (decisión 128): «Voy a grabar la
/// pantalla entera del Retina, con el micrófono DJI y la cámara FaceTime,
/// leyendo 3 guiones».
///
/// Solo arma el texto y dice qué pedazo es de qué control; dibujarlo y
/// tocarlo es cosa de `SentenceView`. Separado así se prueba sin abrir
/// ninguna ventana (`./probar.sh`, bloque "oracion").
enum PanelSentence {

    /// A qué control lleva cada fragmento que se toca.
    enum Parte: String {
        case area, pantalla, audio, camara, guion
    }

    enum Estilo {
        /// Azul y subrayado: se toca.
        case normal
        /// Lo que está apagado a propósito («sin cámara»): azul más liviano.
        case apagado
        /// Algo que falta y bloquea («sin permiso»): coral.
        case falta
        /// El micrófono: su subrayado es el medidor de nivel.
        case medidor
    }

    enum Pieza: Equatable {
        case texto(String)
        case fragmento(String, Parte, Estilo)
    }

    struct Estado {
        /// Ancho y alto del área elegida, o nil para la pantalla entera.
        var area: (ancho: Int, alto: Int)?
        var pantalla: String
        var audio: AudioMode
        /// Nombre completo del micrófono elegido; nil si no hay ninguno.
        var microfono: String?
        var microfonoSinPermiso: Bool
        var camara: String?
        var guiones: Int
    }

    static func armar(_ e: Estado) -> [Pieza] {
        var p: [Pieza] = [.texto("Voy a grabar ")]
        p.append(.fragmento(e.area.map { "un área de \($0.ancho)×\($0.alto)" } ?? "la pantalla entera", .area, .normal))
        p.append(.texto(" del "))
        p.append(.fragmento(pantallaCorta(e.pantalla), .pantalla, .normal))
        p.append(.texto(", "))

        if !e.audio.hasAudio {
            p.append(.fragmento("sin sonido", .audio, .apagado))
        } else {
            p.append(.texto("con "))
            if e.audio.capturesMicrophone {
                if let nombre = e.microfono {
                    if e.microfonoSinPermiso {
                        p.append(.fragmento(microfonoCorto(nombre) + " — sin permiso, tocá para darlo", .audio, .falta))
                    } else {
                        p.append(.fragmento(microfonoCorto(nombre), .audio, .medidor))
                    }
                } else {
                    p.append(.fragmento("ningún micrófono conectado", .audio, .falta))
                }
                if e.audio.capturesSystem {
                    p.append(.texto(" y "))
                    p.append(.fragmento("el sonido del PC", .audio, .normal))
                }
            } else {
                p.append(.fragmento("el sonido del PC", .audio, .normal))
            }
        }

        p.append(.texto(e.audio == .mixed ? ", y " : " y "))
        if let camara = e.camara {
            let corta = camaraCorta(camara)
            p.append(.fragmento(e.audio.hasAudio ? corta : "con " + corta, .camara, .normal))
        } else {
            p.append(.fragmento("sin cámara", .camara, .apagado))
        }

        if e.guiones > 0 {
            p.append(.texto(", leyendo "))
            p.append(.fragmento(e.guiones == 1 ? "1 guion" : "\(e.guiones) guiones", .guion, .normal))
        } else {
            p.append(.texto(", "))
            p.append(.fragmento("sin guion", .guion, .apagado))
        }
        p.append(.texto("."))
        return p
    }

    // MARK: - Nombres cortos

    // La oración no es una lista de dispositivos: es una frase. El nombre
    // completo va en el menú; en la frase va el nombre con que uno lo dice.

    /// Corta en la última palabra entera que entra y agrega puntos suspensivos.
    static func corto(_ s: String, _ maximo: Int) -> String {
        guard s.count > maximo else { return s }
        var c = String(s.prefix(maximo))
        if let espacio = c.lastIndex(of: " ") { c = String(c[..<espacio]) }
        return c + "…"
    }

    static func pantallaCorta(_ nombre: String) -> String {
        nombre.localizedCaseInsensitiveContains("retina") ? "Retina" : corto(nombre, 18)
    }

    static func microfonoCorto(_ nombre: String) -> String {
        var n = nombre
        // Los nombres vienen en el idioma del sistema: «AirPods Pro de
        // Sebastián» en español, «Sebastián’s AirPods Pro» en inglés. El dueño
        // y el camino («vía iPhone») no van en la frase.
        if let dueño = n.range(of: #"^.*['’]s "#, options: .regularExpression) { n.removeSubrange(dueño) }
        if let via = n.range(of: " vía ", options: .caseInsensitive) { n = String(n[..<via.lowerBound]) }
        if let de = n.range(of: #" de [A-ZÁÉÍÓÚÑ][\wáéíóúñ]*( [A-ZÁÉÍÓÚÑ][\wáéíóúñ]*)*$"#, options: .regularExpression) {
            n = String(n[..<de.lowerBound])
        }

        let minusculas = n.lowercased()
        if let airpods = minusculas.range(of: "airpods") {
            return "los " + corto(String(n[airpods.lowerBound...]), 16)
        }
        if minusculas.contains("macbook") { return "el micrófono del Mac" }
        if minusculas == "external microphone" { return "el micrófono externo" }
        if minusculas.hasPrefix("micrófono") || minusculas.hasPrefix("microfono") {
            return "el " + corto(n.prefix(1).lowercased() + n.dropFirst(), 22)
        }
        // «Blue Yeti Microphone» → «el micrófono Blue Yeti».
        if let palabra = n.range(of: #" (Microphone|Mic)$"#, options: [.regularExpression, .caseInsensitive]) {
            n = String(n[..<palabra.lowerBound])
        }
        return "el micrófono " + corto(n, 14)
    }

    static func camaraCorta(_ nombre: String) -> String {
        if nombre.localizedCaseInsensitiveContains("facetime") { return "la cámara FaceTime" }
        if nombre.localizedCaseInsensitiveContains("iphone") { return "el iPhone" }
        return "la cámara " + corto(nombre, 14)
    }

    /// Los AirPods como micrófono graban con calidad de teléfono: el perfil
    /// de manos libres de Bluetooth corta el sonido a 8 kHz. Medido.
    static func esMicrofonoDeTelefono(_ nombre: String?) -> Bool {
        nombre?.localizedCaseInsensitiveContains("airpods") ?? false
    }
}
