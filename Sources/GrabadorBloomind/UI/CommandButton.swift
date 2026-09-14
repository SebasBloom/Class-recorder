import AppKit

/// La gramática de los botones de comando en vivo: **ícono arriba, nombre
/// abajo, todos del mismo tamaño, con el estado pintado en el fondo**.
///
/// Vive acá y no dentro del widget porque la usan las dos superficies que se
/// manejan con la grabación corriendo —el widget y la barra del teleprompter— y
/// tener dos gramáticas de botón en una app que se usa dando clase es
/// exactamente lo que se ve como "descuadrado" sin poder señalar qué
/// (decisión 113).
///
/// Las tres reglas que la definen, todas nacidas de un pedido de Sebas:
///
/// - **El nombre va siempre a la vista** (decisión 99): un ícono solo obliga a
///   adivinar o a esperar el tooltip, y en vivo no hay tiempo para ninguna.
/// - **Ancho, alto e ícono fijos** (decisión 102): el ancho lo manda la palabra
///   más larga y todos la acompañan, que es lo que hace la grilla.
/// - **El estado se muestra con el fondo lleno** (decisión 101): el tinte del
///   ícono cambia unos pocos píxeles y a un metro de la pantalla no se ve.
@MainActor
enum CommandButton {

    static let ancho: CGFloat = 74
    static let alto: CGFloat = 46
    /// Separación entre botones, la misma en horizontal y en vertical.
    static let separacion: CGFloat = 6

    /// Cómo se ve un botón según su estado. Es lo que responde de un vistazo la
    /// pregunta "¿esto está prendido?".
    enum Estado {
        /// Prendido y haciendo efecto ahora mismo: fondo azul de marca.
        case prendido
        /// Prendido y tapando o callando algo: fondo coral, el color de alerta.
        case alerta
        /// Disponible pero apagado.
        case apagado
    }

    /// Configura un botón con esta gramática.
    static func configurar(_ boton: NSButton, simbolo: String, nombre: String,
                           ayuda: String, target: AnyObject?, accion: Selector) {
        boton.title = nombre
        boton.font = BloomindStyle.ui(9)
        if let imagen = icono(simbolo, ayuda) {
            boton.image = imagen
            boton.imagePosition = .imageAbove
        } else {
            // Si el símbolo no existiera en esta versión de macOS, el botón
            // igual se entiende: queda el nombre.
            boton.imagePosition = .noImage
        }
        // Sin borde de sistema y con capa propia: el fondo lo pintamos nosotros,
        // que es lo único que permite mostrar prendido y apagado de un vistazo.
        // `bezelColor` se probó primero y macOS lo ignora con cualquier estilo de
        // bezel que deje poner el ícono arriba del nombre (decisión 101).
        boton.isBordered = false
        boton.wantsLayer = true
        boton.layer?.cornerRadius = 6
        boton.toolTip = ayuda
        boton.target = target
        boton.action = accion
        boton.translatesAutoresizingMaskIntoConstraints = false
        boton.widthAnchor.constraint(equalToConstant: ancho).isActive = true
        boton.heightAnchor.constraint(equalToConstant: alto).isActive = true
        pintar(boton, .apagado)
    }

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

    /// Pinta el estado de un botón.
    ///
    /// El fondo lleno es la señal, no el tinte del ícono. El título va en blanco
    /// sobre el fondo lleno para que se siga leyendo.
    static func pintar(_ boton: NSButton, _ estado: Estado) {
        // Apagado no es "sin fondo": un fondo tenue es lo que hace que se siga
        // viendo como un botón y no como texto suelto.
        let fondo: NSColor
        let tinta: NSColor
        switch estado {
        case .prendido: fondo = BloomindStyle.lab;    tinta = .white
        case .alerta:   fondo = BloomindStyle.signal; tinta = .white
        case .apagado:  fondo = NSColor(white: 1, alpha: 0.10); tinta = BloomindStyle.ink
        }
        boton.layer?.backgroundColor = fondo.cgColor
        boton.contentTintColor = tinta
        titular(boton, color: tinta)
    }

    /// El color del texto de un botón se cambia por título con atributos:
    /// `NSButton` no tiene una propiedad para eso.
    static func titular(_ boton: NSButton, color: NSColor, font: NSFont = BloomindStyle.ui(9)) {
        boton.attributedTitle = NSAttributedString(string: boton.title, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: {
                let p = NSMutableParagraphStyle()
                p.alignment = .center
                return p
            }()
        ])
    }
}
