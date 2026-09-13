import AppKit

/// El orden de todas las ventanas propias, declarado en un solo lugar.
///
/// **Esto decide a quién le llega el clic**, no solo qué se ve encima de qué:
/// macOS entrega el evento de mouse a la ventana que esté más arriba en ese
/// punto de la pantalla.
///
/// Antes de esta pieza cada ventana se ponía `.floating` en su propio archivo, y
/// con cinco en el mismo nivel el orden efectivo lo decidía quién se hubiera
/// mostrado último. Como `DrawingWindow.present()` activa la app y se hace
/// ventana principal, la superficie de dibujo terminaba arriba de todo y,
/// cubriendo la pantalla entera, se quedaba con **todos** los clics: los botones
/// del widget no respondían mientras el tablero o el marcador estaban prendidos
/// (decisión 93).
///
/// Por qué este orden y no otro:
///
/// - El **selector de rectángulo** va por encima del widget porque si no, no se
///   puede trazar una zona de censura que pase por donde está el widget.
/// - La **burbuja** va por encima del teleprompter porque es la única de las dos
///   que refleja lo que sí va al video. Perderla de vista es peor que taparse dos
///   renglones del guion.
/// - La **superficie de dibujo** va abajo de todo lo propio. Sigue estando encima
///   de las demás apps, que es lo único que necesita.
///
/// El panel de configuración no está acá: es una ventana normal y se esconde sola
/// cuando aparece una superficie de dibujo.
enum WindowLayer {
    /// Tablero y capa de anotación.
    case dibujo
    case teleprompter
    /// Espejo de la burbuja de cámara.
    case burbuja
    case widget
    /// Tarjeta de recordatorio de atajos.
    case tarjeta
    /// Selector de rectángulo (censura y área personalizada).
    case selector
    case countdown

    var level: NSWindow.Level {
        switch self {
        case .dibujo:       return sobreFlotante(0)
        case .teleprompter: return sobreFlotante(1)
        case .burbuja:      return sobreFlotante(2)
        case .widget:       return sobreFlotante(3)
        case .tarjeta:      return sobreFlotante(4)
        // Estos dos ya viven por encima de la pila flotante entera y se dejan
        // donde estaban: el selector tapa la pantalla para elegir una zona, y el
        // countdown tiene que verse aunque haya algo en pantalla completa.
        case .selector:     return .modalPanel
        case .countdown:    return .screenSaver
        }
    }

    /// Los niveles de ventana de AppKit son enteros y admiten aritmética: un
    /// escalón arriba de `.floating` sigue estando por debajo de `.modalPanel`,
    /// que es el primer nivel del sistema por encima.
    private func sobreFlotante(_ escalones: Int) -> NSWindow.Level {
        NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + escalones)
    }
}
