import AppKit

/// Ventana para arrastrar y definir una zona de la pantalla.
///
/// Pieza compartida: la usan los dos slots de censura (Fase 10) y el área
/// personalizada de grabación (Fase 11).
///
/// Cubre la pantalla entera con un velo oscuro y deja ver en claro la zona que se
/// está eligiendo. Devuelve el rectángulo en **coordenadas globales**, que es lo
/// que el conversor de coordenadas sabe traducir a píxeles del video.
@MainActor
final class RectangleSelector: NSWindow {

    /// Se llama con la zona elegida, o con nil si se canceló con Escape.
    private let completion: (CGRect?) -> Void
    private let selector: SelectorView

    /// Abre el selector sobre una pantalla y espera el arrastre.
    @discardableResult
    static func present(on screenFrame: NSRect,
                        titulo: String,
                        completion: @escaping (CGRect?) -> Void) -> RectangleSelector {
        let ventana = RectangleSelector(screenFrame: screenFrame, titulo: titulo, completion: completion)
        NSApp.activate(ignoringOtherApps: true)
        ventana.orderFrontRegardless()
        ventana.makeKey()
        return ventana
    }

    private init(screenFrame: NSRect, titulo: String, completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        selector = SelectorView(titulo: titulo)

        super.init(contentRect: screenFrame, styleMask: [.borderless], backing: .buffered, defer: false)

        level = WindowLayer.selector.level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // El velo navy de la identidad (decisión 123), bastante cerrado: lo que
        // importa es que la zona elegida se vea nítida contra el resto.
        backgroundColor = BloomindStyle.Claro.tinta.withAlphaComponent(0.58)
        isOpaque = false
        hasShadow = false
        contentView = selector

        selector.onFinish = { [weak self] rect in
            guard let self else { return }
            self.orderOut(nil)
            // De coordenadas de la ventana a globales: la ventana cubre la
            // pantalla, así que alcanza con sumarle su origen.
            let global = rect.map {
                CGRect(x: $0.minX + self.frame.minX, y: $0.minY + self.frame.minY,
                       width: $0.width, height: $0.height)
            }
            self.completion(global)
        }
    }

    override var canBecomeKey: Bool { true }
}

/// La vista que dibuja el velo, el recorte en claro y el instructivo.
@MainActor
private final class SelectorView: NSView {

    /// Rectángulo mínimo para que cuente. Un clic sin arrastre no define una zona.
    private static let minimo: CGFloat = 12

    var onFinish: ((CGRect?) -> Void)?

    private let titulo: String
    private var inicio: CGPoint?
    private var actual: CGPoint?

    init(titulo: String) {
        self.titulo = titulo
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("no se usa") }

    override var acceptsFirstResponder: Bool { true }

    private var seleccion: CGRect? {
        guard let inicio, let actual else { return nil }
        let rect = CGRect(x: min(inicio.x, actual.x), y: min(inicio.y, actual.y),
                          width: abs(actual.x - inicio.x), height: abs(actual.y - inicio.y))
        return rect.width >= Self.minimo && rect.height >= Self.minimo ? rect : nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let c = BloomindStyle.Claro.self

        if let seleccion {
            // El velo lo pone el fondo de la ventana; acá se "borra" la zona
            // elegida para que se vea nítida lo que hay debajo.
            context.setBlendMode(.clear)
            context.fill(seleccion)
            context.setBlendMode(.normal)

            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(1.5)
            context.stroke(seleccion)

            // La medida, en una etiqueta navy pegada abajo a la derecha.
            let medidas = NSAttributedString(string: "\(Int(seleccion.width)) × \(Int(seleccion.height))", attributes: [
                .font: BloomindStyle.mono(12, weight: .medium),
                .foregroundColor: NSColor.white
            ])
            let tamaño = medidas.size()
            let caja = NSRect(x: seleccion.maxX - tamaño.width - 16, y: seleccion.minY - tamaño.height - 14,
                              width: tamaño.width + 16, height: tamaño.height + 6)
            c.tinta.setFill()
            NSBezierPath(roundedRect: caja, xRadius: 5, yRadius: 5).fill()
            medidas.draw(at: NSPoint(x: caja.minX + 8, y: caja.minY + 3))
        }

        dibujarRotulo()
    }

    /// El rótulo de arriba al centro: qué se está eligiendo y cómo, en una
    /// tarjeta blanca.
    private func dibujarRotulo() {
        let c = BloomindStyle.Claro.self
        let principal = NSAttributedString(string: titulo, attributes: [
            .font: BloomindStyle.display(19), .foregroundColor: c.tinta
        ])
        let ayuda = NSAttributedString(string: "Arrastrá para dibujar el rectángulo · Esc cancela", attributes: [
            .font: BloomindStyle.ui(12), .foregroundColor: c.pizarra
        ])
        let ancho = max(principal.size().width, ayuda.size().width) + 40
        let alto = principal.size().height + ayuda.size().height + 26
        let caja = NSRect(x: bounds.midX - ancho / 2, y: bounds.maxY - 26 - alto, width: ancho, height: alto)
        c.blanco.setFill()
        NSBezierPath(roundedRect: caja, xRadius: 12, yRadius: 12).fill()
        principal.draw(at: NSPoint(x: caja.midX - principal.size().width / 2, y: caja.maxY - 12 - principal.size().height))
        ayuda.draw(at: NSPoint(x: caja.midX - ayuda.size().width / 2, y: caja.minY + 12))
    }

    // MARK: - Entrada

    override func mouseDown(with event: NSEvent) {
        inicio = convert(event.locationInWindow, from: nil)
        actual = inicio
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        actual = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { inicio = nil; actual = nil }
        onFinish?(seleccion)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {           // esc
            onFinish?(nil)
        }
    }
}
