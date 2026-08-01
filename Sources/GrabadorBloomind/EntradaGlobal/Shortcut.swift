import AppKit
import Carbon.HIToolbox

/// Una combinación de teclas.
///
/// Guarda su propia etiqueta ("⌥⌘3") en vez de derivarla del código de tecla.
/// Traducir un código a la letra que tiene impresa depende de la distribución de
/// teclado activa, y esa cuenta se hace bien una sola vez: cuando el usuario
/// aprieta la combinación. De ahí en adelante se muestra lo que él mismo tecleó.
struct Shortcut: Codable, Equatable {

    /// Código virtual de la tecla (`kVK_ANSI_3`, etc.).
    var tecla: Int
    /// Máscara de Carbon (`optionKey | cmdKey`).
    var modificadores: Int
    /// Cómo se muestra en la interfaz.
    var etiqueta: String

    init(tecla: Int, modificadores: Int, etiqueta: String) {
        self.tecla = tecla
        self.modificadores = modificadores
        self.etiqueta = etiqueta
    }

    /// Construye la combinación a partir de una tecla realmente apretada.
    ///
    /// Devuelve nil si no sirve como atajo global: sin modificadores, o con solo
    /// Shift, cualquier tecla le robaría la letra al resto del sistema.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon = 0
        var etiqueta = ""

        if flags.contains(.control) { carbon |= controlKey; etiqueta += "⌃" }
        if flags.contains(.option)  { carbon |= optionKey;  etiqueta += "⌥" }
        if flags.contains(.shift)   { carbon |= shiftKey;   etiqueta += "⇧" }
        if flags.contains(.command) { carbon |= cmdKey;     etiqueta += "⌘" }

        // Shift solo no alcanza: Shift+A es escribir una A.
        guard carbon != 0, carbon != shiftKey else { return nil }

        etiqueta += Self.nombre(de: Int(event.keyCode), event: event)
        self.init(tecla: Int(event.keyCode), modificadores: carbon, etiqueta: etiqueta)
    }

    /// Nombre visible de la tecla. Las especiales tienen su símbolo; el resto sale
    /// de lo que el teclado del usuario dice que produce esa tecla.
    private static func nombre(de codigo: Int, event: NSEvent) -> String {
        switch codigo {
        case kVK_Delete:        return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Return:        return "↩"
        case kVK_Space:         return "espacio"
        case kVK_Escape:        return "esc"
        case kVK_Tab:           return "⇥"
        case kVK_ANSI_KeypadDivide: return "teclado /"
        case kVK_ANSI_Keypad0...kVK_ANSI_Keypad9:
            return "teclado " + (event.charactersIgnoringModifiers ?? "?")
        default:
            let texto = event.charactersIgnoringModifiers ?? ""
            return texto.isEmpty ? "tecla \(codigo)" : texto.uppercased()
        }
    }
}
