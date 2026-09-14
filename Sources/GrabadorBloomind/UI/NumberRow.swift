import AppKit

/// Una fila para elegir un número: **etiqueta, menos, barra, campo donde se
/// escribe, más**.
///
/// Los tres caminos llevan al mismo lugar y se reflejan entre sí: arrastrar la
/// barra escribe el número, escribir el número mueve la barra, y los botones
/// mueven las dos cosas de a un paso. Pedido de Sebas el 2026-09-13: la barra
/// sola sirve para tantear, pero cuando ya sabés que querés velocidad 4.5 no hay
/// forma de clavarla (decisión 115).
///
/// Lo que se escriba se acomoda al rango: no hay forma de dejar un valor que el
/// teleprompter después no pueda usar.
@MainActor
final class NumberRow: NSStackView {

    /// Se avisa cada vez que el valor queda firme, por cualquiera de los tres
    /// caminos. No se dispara mientras se arrastra la barra.
    var onChange: ((Double) -> Void)?

    private(set) var value: Double

    private let minimo: Double
    private let maximo: Double
    private let paso: Double
    private let decimales: Int

    /// El ancho de la etiqueta, común a todas las filas.
    private static let anchoEtiqueta: CGFloat = 104

    private let barra = NSSlider()
    private let campo = NSTextField()

    init(titulo: String, minimo: Double, maximo: Double, paso: Double,
         decimales: Int, valor: Double) {
        self.minimo = minimo
        self.maximo = maximo
        self.paso = paso
        self.decimales = decimales
        self.value = min(max(valor, minimo), maximo)
        super.init(frame: .zero)

        let etiqueta = NSTextField(labelWithString: titulo)
        etiqueta.font = BloomindStyle.ui(12)
        etiqueta.textColor = BloomindStyle.muted
        // Ancho fijo y no el que le pida su palabra: "Velocidad" y "Tamaño de
        // letra" miden distinto, y sin esto cada fila arranca su barra en un
        // lugar distinto. Es la misma regla que la grilla de botones del widget
        // (decisión 102): lo que está en dos filas, en la misma columna.
        etiqueta.translatesAutoresizingMaskIntoConstraints = false
        etiqueta.widthAnchor.constraint(equalToConstant: Self.anchoEtiqueta).isActive = true
        etiqueta.lineBreakMode = .byTruncatingTail

        let menos = boton("−", ayuda: "Bajar \(titulo.lowercased())", accion: #selector(tocarMenos))
        let mas = boton("+", ayuda: "Subir \(titulo.lowercased())", accion: #selector(tocarMas))

        barra.minValue = minimo
        barra.maxValue = maximo
        barra.doubleValue = value
        // Solo al soltar: continuo escribiría config.json decenas de veces por
        // arrastre.
        barra.isContinuous = false
        barra.target = self
        barra.action = #selector(moverBarra)

        campo.font = BloomindStyle.mono(12)
        campo.alignment = .center
        campo.bezelStyle = .roundedBezel
        campo.target = self
        campo.action = #selector(escribir)
        // Confirma también al salir del campo, no solo con Enter: nadie aprieta
        // Enter antes de ir a tocar otra cosa del panel.
        campo.cell?.sendsActionOnEndEditing = true
        campo.translatesAutoresizingMaskIntoConstraints = false
        campo.widthAnchor.constraint(equalToConstant: 56).isActive = true

        setViews([etiqueta, menos, barra, campo, mas], in: .leading)
        orientation = .horizontal
        alignment = .centerY
        spacing = BloomindStyle.Space.tight
        // La barra es lo único que se estira; la etiqueta, los botones y el
        // campo conservan su tamaño.
        barra.setContentHuggingPriority(.defaultLow, for: .horizontal)
        etiqueta.setContentHuggingPriority(.required, for: .horizontal)

        mostrar()
    }

    required init?(coder: NSCoder) { fatalError("no se usa") }

    /// Apaga la fila entera mientras se está grabando: los valores de arranque
    /// se eligen antes, no con la toma corriendo (decisión 91).
    func setEnabled(_ habilitada: Bool) {
        for control in views.compactMap({ $0 as? NSControl }) {
            control.isEnabled = habilitada
        }
    }

    /// Pone el valor desde afuera, sin avisar de vuelta.
    func set(_ nuevo: Double) {
        value = acomodar(nuevo)
        mostrar()
    }

    // MARK: - Interno

    private func boton(_ signo: String, ayuda: String, accion: Selector) -> NSButton {
        let boton = NSButton(title: signo, target: self, action: accion)
        boton.bezelStyle = .rounded
        boton.font = BloomindStyle.ui(13)
        boton.toolTip = ayuda
        boton.translatesAutoresizingMaskIntoConstraints = false
        boton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        return boton
    }

    @objc private func tocarMenos() { cambiar(a: value - paso) }
    @objc private func tocarMas() { cambiar(a: value + paso) }
    @objc private func moverBarra() { cambiar(a: barra.doubleValue) }

    @objc private func escribir() {
        guard let escrito = leer(campo.stringValue) else {
            // Basura escrita: se vuelve a lo que había, en vez de dejar el campo
            // diciendo una cosa y el teleprompter usando otra.
            mostrar()
            return
        }
        cambiar(a: escrito)
    }

    /// Entiende "4.5" y "4,5": en un teclado latinoamericano la coma es lo que
    /// sale natural, y un número que no se entiende volvería al valor anterior
    /// sin decir por qué.
    ///
    /// Estática y sin aislar para poder probarla sin levantar interfaz
    /// (`./probar.sh`, bloque "teleprompter").
    nonisolated static func leer(_ texto: String) -> Double? {
        let limpio = texto.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return Double(limpio)
    }

    private func leer(_ texto: String) -> Double? { Self.leer(texto) }

    private func cambiar(a nuevo: Double) {
        let acomodado = acomodar(nuevo)
        let cambió = acomodado != value
        value = acomodado
        mostrar()
        if cambió { onChange?(value) }
    }

    /// Dentro del rango y con la precisión que corresponde: la velocidad va de a
    /// décimas y el tamaño de letra en enteros.
    nonisolated static func acomodar(_ valor: Double, minimo: Double, maximo: Double,
                                     decimales: Int) -> Double {
        let dentro = min(max(valor, minimo), maximo)
        let factor = pow(10.0, Double(decimales))
        return (dentro * factor).rounded() / factor
    }

    private func acomodar(_ valor: Double) -> Double {
        Self.acomodar(valor, minimo: minimo, maximo: maximo, decimales: decimales)
    }

    private func mostrar() {
        barra.doubleValue = value
        campo.stringValue = String(format: "%.\(decimales)f", value)
    }
}
