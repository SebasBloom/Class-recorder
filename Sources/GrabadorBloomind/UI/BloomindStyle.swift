import AppKit

/// Identidad visual Bloomind, traducida de la guía de estilo del CLM
/// (`~/CLM Bloomind/docs/instructivo.md`, sección 5) a AppKit.
///
/// Es la misma cara de la familia de productos: CLM, whatasAPI y Bloomind
/// Oficinas. Las cuatro reglas que le dan el carácter y que no se rompen:
///
/// 1. Colores planos siempre, cero degradados.
/// 2. El turquesa es exclusivo de los momentos de éxito, no es decoración.
/// 3. Profundidad con hairlines, no con sombras pesadas.
/// 4. Aire generoso: la interfaz respira, no se apeñusca.
enum BloomindStyle {

    // MARK: - Paleta

    /// Fondo base de toda la app.
    static let deep = NSColor(hex: 0x0F1A2C)
    /// Superficies elevadas: tarjetas, paneles, modales.
    static let surface = NSColor(hex: 0x16243D)
    /// Texto principal.
    static let ink = NSColor.white
    /// Texto secundario azul gris.
    static let muted = NSColor(hex: 0x8CA3C4)
    /// Bordes y líneas finas.
    static let hairline = NSColor(hex: 0x26364F)
    /// Acento protagonista: botones primarios, enlaces, foco.
    static let lab = NSColor(hex: 0x3A7BFF)
    /// Hover e interactivo secundario.
    static let tech = NSColor(hex: 0x1F4DFF)
    /// Contenedores sutiles e informativos.
    static let sky = NSColor(hex: 0x7BC6FF)
    /// EXCLUSIVO para éxito.
    static let turquoise = NSColor(hex: 0x45D3C5)
    /// Señal funcional de error y alerta.
    static let signal = NSColor(hex: 0xF0857A)

    // MARK: - Espaciado

    /// El aire de la guía, en puntos.
    enum Space {
        static let tight: CGFloat = 8
        static let normal: CGFloat = 14
        static let loose: CGFloat = 20
        static let card: CGFloat = 24
    }

    static let cornerRadius: CGFloat = 10

    // MARK: - Tipografía

    /// Display serif para títulos y cifras. Fraunces viene en el bundle y se
    /// registra sola vía ATSApplicationFontsPath del Info.plist.
    ///
    /// Es una fuente variable: el peso y el tamaño óptico se piden por eje. El
    /// eje WONK va en 0 porque sus glifos alternos son demasiado excéntricos
    /// para una interfaz; quedan bien en un titular grande, no en un panel.
    static func display(_ size: CGFloat, weight: CGFloat = 600) -> NSFont {
        let axes: [NSNumber: Any] = [
            NSNumber(value: 0x77676874): weight,        // wght
            NSNumber(value: 0x6F70737A): Double(size),  // opsz
            NSNumber(value: 0x574F4E4B): 0.0            // WONK
        ]
        let descriptor = NSFontDescriptor(fontAttributes: [
            .name: "Fraunces",
            NSFontDescriptor.AttributeName(kCTFontVariationAttribute as String): axes
        ])
        // Georgia es el fallback de la guía, por si el archivo no llegó al bundle.
        return NSFont(descriptor: descriptor, size: size)
            ?? NSFont(name: "Georgia", size: size)
            ?? NSFont.systemFont(ofSize: size)
    }

    /// Interfaz y formularios: sans del sistema.
    static func ui(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }

    /// Datos técnicos: resoluciones, tiempos, consecutivos.
    static func mono(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    /// Eyebrow editorial: mayúsculas, chico, muy espaciado, en muted.
    static func eyebrow(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text.uppercased(), attributes: [
            .font: mono(11, weight: .medium),
            .kern: 2.0,
            .foregroundColor: muted
        ])
    }
}

extension NSColor {
    /// Los tokens de la guía están en hexadecimal; esto evita repartir números
    /// mágicos por todo el código.
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Botón plano de la identidad: sin degradado, sin sombra, esquinas medias.
///
/// AppKit no deja pintar un `NSButton` estándar de color plano sin que le meta
/// su propio brillo, así que este dibuja su fondo con una capa.
final class BloomindButton: NSButton {

    enum Kind {
        /// Acción principal: fondo lab, texto blanco.
        case primary
        /// Acción secundaria: solo borde hairline.
        case ghost
    }

    private let kind: Kind
    private var isHovered = false

    init(title: String, kind: Kind = .primary) {
        self.kind = kind
        super.init(frame: .zero)

        self.title = title
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = BloomindStyle.cornerRadius
        layer?.borderWidth = kind == .ghost ? 1 : 0

        applyColors()
    }

    required init?(coder: NSCoder) { fatalError("no se usa") }

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += BloomindStyle.Space.loose * 2
        size.height += BloomindStyle.Space.tight * 2
        return size
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        applyColors()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        applyColors()
    }

    override var isEnabled: Bool {
        didSet { applyColors() }
    }

    // El color del texto se pinta con attributedTitle, así que cada vez que
    // cambia el título hay que volver a aplicarlo o el botón queda con el texto
    // anterior.
    override var title: String {
        didSet { applyColors() }
    }

    private func applyColors() {
        let dimmed = !isEnabled

        switch kind {
        case .primary:
            layer?.backgroundColor = (isHovered ? BloomindStyle.tech : BloomindStyle.lab)
                .withAlphaComponent(dimmed ? 0.35 : 1).cgColor
            setTitleColor(BloomindStyle.ink.withAlphaComponent(dimmed ? 0.5 : 1))

        case .ghost:
            layer?.backgroundColor = NSColor.clear.cgColor
            let edge = isHovered ? BloomindStyle.ink : BloomindStyle.hairline
            layer?.borderColor = edge.withAlphaComponent(dimmed ? 0.4 : 1).cgColor
            setTitleColor((isHovered ? BloomindStyle.ink : BloomindStyle.muted)
                .withAlphaComponent(dimmed ? 0.5 : 1))
        }
    }

    private func setTitleColor(_ color: NSColor) {
        attributedTitle = NSAttributedString(string: title, attributes: [
            .font: BloomindStyle.ui(13, weight: .medium),
            .foregroundColor: color
        ])
    }
}
