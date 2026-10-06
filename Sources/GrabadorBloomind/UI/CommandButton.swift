import AppKit

/// Los íconos de los botones en vivo, todos encajados en el mismo cuadro.
///
/// Fue la gramática de botón compartida del widget y del teleprompter
/// (decisión 113). Desde la Fase 16 cada uno tiene la suya —`CapsuleButton` y
/// `BarraBoton`— y de esta pieza queda lo que los dos siguen necesitando: que
/// ningún ícono se dibuje más grande que su vecino (decisión 112).
@MainActor
enum CommandButton {

    /// El cuadro donde entra cualquier ícono, del que ninguno se sale.
    private static let cuadro = NSSize(width: 20, height: 20)

    private static let simbolo = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)

    /// Un ícono del sistema, encajado y centrado en el mismo cuadro que todos
    /// los demás.
    ///
    /// Igualar el `pointSize` no alcanza: ese tamaño es el de la caja
    /// tipográfica, no el del dibujo que la llena. La tortuga y la liebre de los
    /// controles de velocidad son anchas y se comían el botón; el micrófono es
    /// alto y angosto; el cuadrado de detener llenaba una fracción.
    ///
    /// Lo que más se nota al arreglarlo: **el nombre de todos los botones queda
    /// a la misma altura**. AppKit apila el ícono y el título y centra el
    /// conjunto, así que un ícono más alto empuja su palabra hacia abajo, y esa
    /// diferencia de dos o tres píxeles entre botones vecinos es justo lo que se
    /// lee como descuadrado (decisión 112).
    static func icono(_ nombre: String, _ ayuda: String) -> NSImage? {
        guard let base = NSImage(systemSymbolName: nombre, accessibilityDescription: ayuda)?
            .withSymbolConfiguration(simbolo) else { return nil }

        let original = base.size
        guard original.width > 0, original.height > 0 else { return base }
        // Solo se achica lo que se sale del cuadro. Agrandar los chiquitos —el
        // cuadrado de detener, las barras de pausa— los dejaría pesando más que
        // el resto, que es el error opuesto.
        let escala = min(cuadro.width / original.width, cuadro.height / original.height, 1)
        let tamaño = NSSize(width: (original.width * escala).rounded(),
                            height: (original.height * escala).rounded())

        let encajado = NSImage(size: cuadro, flipped: false) { _ in
            base.draw(in: NSRect(x: ((cuadro.width - tamaño.width) / 2).rounded(),
                                 y: ((cuadro.height - tamaño.height) / 2).rounded(),
                                 width: tamaño.width, height: tamaño.height))
            return true
        }
        // Sin esto deja de tomar el color del botón y los estados se pierden.
        encajado.isTemplate = true
        return encajado
    }
}
