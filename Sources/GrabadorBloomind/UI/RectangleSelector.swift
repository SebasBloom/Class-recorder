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

        level = .modalPanel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = NSColor(white: 0, alpha: 0.35)
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

        if let seleccion {
            // El velo lo pone el fondo de la ventana; acá se "borra" la zona
            // elegida para que se vea nítida lo que hay debajo.
            context.setBlendMode(.clear)
            context.fill(seleccion)
            context.setBlendMode(.normal)

            context.setStrokeColor(BloomindStyle.lab.cgColor)
            context.setLineWidth(2)
            context.stroke(seleccion)

            let medidas = "\(Int(seleccion.width)) × \(Int(seleccion.height))"
            dibujar(medidas, en: CGPoint(x: seleccion.minX, y: seleccion.maxY + 8), tamaño: 12)
        }

        dibujar(titulo, en: CGPoint(x: bounds.midX - 220, y: bounds.midY), tamaño: 17)
        dibujar("Arrastrá para elegir la zona. Escape cancela.",
                en: CGPoint(x: bounds.midX - 220, y: bounds.midY - 26), tamaño: 13)
    }

    private func dibujar(_ texto: String, en punto: CGPoint, tamaño: CGFloat) {
        let atributos: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: tamaño, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        NSAttributedString(string: texto, attributes: atributos).draw(at: punto)
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
