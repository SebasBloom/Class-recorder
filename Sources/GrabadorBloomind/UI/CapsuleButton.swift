import AppKit

/// Un botón de la cápsula del widget: ícono arriba, nombre abajo, fondo solo
/// cuando hace falta (decisión 124).
///
/// Reemplaza a `CommandButton` en el widget. Esa gramática de fondos llenos y
/// grilla de 74×46 era para una hoja de dieciocho botones sobre fondo oscuro;
/// acá quedan siete a la vista sobre blanco, y el fondo se reserva para lo que
/// tiene que verse de lejos: lo que está callando algo va en coral suave.
/// Los íconos siguen pasando por `CommandButton.icono`, que es lo que deja los
/// nombres a la misma altura (decisión 112).
@MainActor
final class CapsuleButton: NSButton {

    enum Estado {
        case normal
        /// Prendido: texto azul y nombre en negrita.
        case prendido
        /// Callando o tapando algo: fondo coral suave.
        case alerta
    }

    var estado: Estado = .normal { didSet { pintar() } }
    /// El menú de este botón está abierto.
    var abierto = false { didSet { pintar() } }
    /// Los botones de grupo llevan una flecha después del nombre.
    var conFlecha = false { didSet { pintar() } }

    private var encima = false
    private var nombre: String

    init(simbolo: String, nombre: String, ayuda: String, ancho: CGFloat? = 54) {
        self.nombre = nombre
        super.init(frame: .zero)
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 12
        imagePosition = .imageAbove
        toolTip = ayuda
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 52).isActive = true
        if let ancho {
            widthAnchor.constraint(equalToConstant: ancho).isActive = true
        }
        cambiar(simbolo: simbolo, nombre: nombre)
    }

    required init?(coder: NSCoder) { fatalError("no se usa") }

    /// Los grupos no tienen ancho fijo: lo manda su nombre, con aire a los lados.
    override var intrinsicContentSize: NSSize {
        // Lo que mide el nombre más el aire de la maqueta (7 a cada lado); el
        // tamaño propio de NSButton ya trae margen y duplicaba el aire.
        NSSize(width: max(54, ceil(attributedTitle.size().width) + 14), height: 52)
    }

    func cambiar(simbolo: String? = nil, nombre: String? = nil) {
        if let nombre { self.nombre = nombre }
        if let simbolo { image = CommandButton.icono(simbolo, self.nombre) }
        pintar()
    }

    override var isEnabled: Bool { didSet { pintar() } }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    override func mouseEntered(with event: NSEvent) { encima = true; pintar() }
    override func mouseExited(with event: NSEvent) { encima = false; pintar() }

    private func pintar() {
        let c = BloomindStyle.Claro.self
        var tinta = c.tinta
        var fondo = NSColor.clear
        switch estado {
        case .normal:   break
        case .prendido: tinta = c.azul
        case .alerta:   tinta = c.coral; fondo = c.coralSuave
        }
        if abierto {
            tinta = c.azul; fondo = c.azulSuave
        } else if encima && isEnabled && estado != .alerta {
            fondo = c.papel
        }
        if !isEnabled { tinta = tinta.withAlphaComponent(0.35) }

        layer?.backgroundColor = fondo.cgColor
        contentTintColor = tinta

        let texto = NSMutableAttributedString(string: nombre, attributes: [
            .font: BloomindStyle.ui(10, weight: estado == .prendido ? .semibold : .regular),
            .foregroundColor: tinta,
            .paragraphStyle: {
                let p = NSMutableParagraphStyle()
                p.alignment = .center
                return p
            }()
        ])
        if conFlecha {
            texto.append(NSAttributedString(string: " ⌄", attributes: [
                .font: BloomindStyle.ui(9, weight: .semibold),
                .foregroundColor: tinta,
                .baselineOffset: 2
            ]))
        }
        attributedTitle = texto
        invalidateIntrinsicContentSize()
    }
}
