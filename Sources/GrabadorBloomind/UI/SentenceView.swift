import AppKit

/// Dibuja la oración del panel y deja tocar sus fragmentos (decisión 128).
///
/// AppKit no trae texto con zonas que abren un menú, así que es un
/// `NSTextView` de solo lectura: cada fragmento lleva un atributo propio con su
/// parte, el clic se traduce a la letra que quedó debajo, y de ahí al
/// fragmento y al rectángulo donde anclar su menú.
///
/// El subrayado del micrófono no es un subrayado de texto: es el medidor de
/// nivel, dibujado encima en cada muestra.
@MainActor
final class SentenceView: NSTextView {

    /// Se tocó un fragmento. El rectángulo está en coordenadas de esta vista,
    /// para anclar ahí el menú.
    var onTap: ((PanelSentence.Parte, NSRect) -> Void)?

    /// Nivel del micrófono, de 0 a 1.
    var nivel: CGFloat = 0 {
        didSet { if hayMedidor { needsDisplay = true } }
    }

    /// Mientras se graba la frase no se toca: los dispositivos ya están tomados.
    var habilitada = true {
        didSet { window?.invalidateCursorRects(for: self) }
    }

    private static let parteKey = NSAttributedString.Key("bloomind.parte")
    private static let medidorKey = NSAttributedString.Key("bloomind.medidor")
    private var hayMedidor = false
    private let ancho: CGFloat
    /// El texto. El maquetador lo referencia sin retenerlo, así que alguien
    /// tiene que sostenerlo: sin esto se libera apenas se crea y la vista
    /// queda en blanco.
    private let almacen = NSTextStorage()

    init(ancho: CGFloat) {
        self.ancho = ancho
        let contenedor = NSTextContainer(size: NSSize(width: ancho, height: .greatestFiniteMagnitude))
        contenedor.lineFragmentPadding = 0
        let maquetador = NSLayoutManager()
        maquetador.addTextContainer(contenedor)
        almacen.addLayoutManager(maquetador)
        super.init(frame: NSRect(x: 0, y: 0, width: ancho, height: 40), textContainer: contenedor)
        isEditable = false
        isSelectable = false
        drawsBackground = false
        textContainerInset = .zero
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: ancho).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("no se usa") }

    func mostrar(_ piezas: [PanelSentence.Pieza]) {
        let c = BloomindStyle.Claro.self
        let renglon = NSMutableParagraphStyle()
        renglon.minimumLineHeight = 27 * 1.55
        renglon.maximumLineHeight = 27 * 1.55
        let base: [NSAttributedString.Key: Any] = [
            .font: BloomindStyle.display(27, weight: 400),
            .foregroundColor: c.tinta,
            .paragraphStyle: renglon,
            .baselineOffset: 4
        ]

        let texto = NSMutableAttributedString()
        hayMedidor = false
        for pieza in piezas {
            switch pieza {
            case .texto(let t):
                texto.append(NSAttributedString(string: t, attributes: base))
            case .fragmento(let t, let parte, let estilo):
                var a = base
                a[Self.parteKey] = parte.rawValue
                switch estilo {
                case .normal, .medidor:
                    a[.font] = BloomindStyle.display(27, weight: 560)
                    a[.foregroundColor] = c.azul
                case .apagado:
                    a[.font] = BloomindStyle.display(27, weight: 450)
                    a[.foregroundColor] = c.azul
                case .falta:
                    a[.font] = BloomindStyle.display(27, weight: 560)
                    a[.foregroundColor] = c.coral
                }
                if estilo == .medidor {
                    a[Self.medidorKey] = true
                    hayMedidor = true
                } else {
                    a[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    a[.underlineColor] = estilo == .falta ? c.coral : c.azul
                }
                // Espacios que no cortan: un fragmento partido en dos renglones
                // se lee como dos cosas distintas. El de «sin permiso» sí puede
                // cortar, porque es largo a propósito.
                let sinCortes = estilo == .falta ? t : t.replacingOccurrences(of: " ", with: "\u{00A0}")
                texto.append(NSAttributedString(string: sinCortes, attributes: a))
            }
        }
        textStorage?.setAttributedString(texto)
        invalidateIntrinsicContentSize()
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        guard let maquetador = layoutManager, let contenedor = textContainer else { return .zero }
        maquetador.ensureLayout(for: contenedor)
        return NSSize(width: ancho, height: ceil(maquetador.usedRect(for: contenedor).height))
    }

    // MARK: - Fragmentos

    /// Los rectángulos de cada fragmento, con su parte. Un fragmento partido
    /// en dos renglones da dos rectángulos.
    private func fragmentos(con clave: NSAttributedString.Key) -> [(valor: Any, rect: NSRect)] {
        guard let storage = textStorage, let maquetador = layoutManager, let contenedor = textContainer else { return [] }
        var lista: [(Any, NSRect)] = []
        storage.enumerateAttribute(clave, in: NSRange(location: 0, length: storage.length)) { valor, rango, _ in
            guard let valor else { return }
            let glifos = maquetador.glyphRange(forCharacterRange: rango, actualCharacterRange: nil)
            maquetador.enumerateEnclosingRects(forGlyphRange: glifos, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                               in: contenedor) { rect, _ in
                lista.append((valor, rect))
            }
        }
        return lista
    }

    override func resetCursorRects() {
        guard habilitada else { return }
        for (_, rect) in fragmentos(con: Self.parteKey) {
            addCursorRect(rect, cursor: .pointingHand)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard habilitada else { return }
        let punto = convert(event.locationInWindow, from: nil)
        for (valor, rect) in fragmentos(con: Self.parteKey) where rect.contains(punto) {
            guard let nombre = valor as? String, let parte = PanelSentence.Parte(rawValue: nombre) else { return }
            // El menú se ancla al fragmento entero, no solo al renglón tocado.
            let entero = fragmentos(con: Self.parteKey)
                .filter { ($0.valor as? String) == nombre }
                .map(\.rect)
                .reduce(rect) { $0.union($1) }
            onTap?(parte, rect.minY == entero.minY ? rect : entero)
            return
        }
    }

    /// Dónde está un fragmento en la pantalla, para el tutorial. Si ocupa dos
    /// renglones, el rectángulo que los abarca.
    func marcoEnPantalla(de parte: PanelSentence.Parte) -> NSRect? {
        let rects = fragmentos(con: Self.parteKey)
            .filter { ($0.valor as? String) == parte.rawValue }
            .map(\.rect)
        guard let primero = rects.first, let ventana = window, ventana.isVisible else { return nil }
        let local = rects.dropFirst().reduce(primero) { $0.union($1) }
        return ventana.convertToScreen(convert(local, to: nil))
    }

    // MARK: - Medidor

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard hayMedidor else { return }
        let c = BloomindStyle.Claro.self
        for (_, rect) in fragmentos(con: Self.medidorKey) {
            // La línea fina de fondo es el subrayado en reposo; la azul gruesa
            // encima crece con la voz.
            let y = rect.maxY - 9
            c.lineaFuerte.setFill()
            NSRect(x: rect.minX, y: y, width: rect.width, height: 1.5).fill()
            c.azul.setFill()
            NSRect(x: rect.minX, y: y - 0.75, width: rect.width * max(0, min(1, nivel)), height: 3).fill()
        }
    }
}
