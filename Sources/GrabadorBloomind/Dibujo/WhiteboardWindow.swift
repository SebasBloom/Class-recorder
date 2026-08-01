import AppKit

/// Ventana espejo del tablero: cubre entera la pantalla que se está grabando.
///
/// Es donde Sebas ve y dibuja; el compositor pinta lo mismo desde el modelo sobre
/// el lienzo del archivo (decisión 3). Queda fuera de la captura porque el filtro
/// excluye la aplicación entera, así que en el video nunca aparece: lo que se ve
/// ahí es el lienzo compuesto, no esta ventana.
///
/// Mientras está arriba, el mouse le pega a ella y no a las apps de abajo, que es
/// exactamente lo que pide el plan para el modo tablero.
@MainActor
final class WhiteboardWindow: NSWindow {

    private let canvas: DrawingCanvasView

    init(surface: DrawingSurface, screenFrame: NSRect) {
        canvas = DrawingCanvasView(surface: surface)

        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Encima de todo, incluidas las apps en pantalla completa. Debajo del
        // espejo de la burbuja, que tiene que seguir viéndose sobre el tablero.
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = true
        backgroundColor = .white
        hasShadow = false
        contentView = canvas
        // Sin esto el teclado nunca llega: los cuadros de texto no se podrían
        // escribir.
        acceptsMouseMovedEvents = false
    }

    /// Una ventana sin barra de título no puede ser la principal por defecto, y
    /// sin serlo no recibe teclado.
    override var canBecomeKey: Bool { true }

    func present() {
        orderFrontRegardless()
        makeKey()
        canvas.window?.makeFirstResponder(canvas)
    }

    func hide() {
        canvas.closeTextBox()
        orderOut(nil)
    }

    /// Repinta el espejo. Lo llama un temporizador mientras el tablero está
    /// visible: el modelo cambia desde el mouse y el teclado, y así el espejo
    /// nunca queda atrasado respecto de lo que se está escribiendo en el video.
    func refresh() {
        canvas.needsDisplay = true
    }

    /// Cierra el cuadro de texto activo, si hay alguno.
    func closeTextBox() {
        canvas.closeTextBox()
    }
}

/// El lienzo: dibuja el modelo y traduce mouse y teclado a ediciones.
@MainActor
private final class DrawingCanvasView: NSView {

    /// Cuánto hay que arrastrar para que el gesto cuente como trazo. Por debajo
    /// de esto es un clic seco, que abre un cuadro de texto (decisión 54).
    private static let dragThreshold: CGFloat = 3

    private let surface: DrawingSurface
    private var mouseDownAt: CGPoint?
    private var isDrawing = false

    /// Texto que se está escribiendo. Nil significa que no hay cuadro activo, y
    /// entonces el teclado no se toca: los atajos con modificadores tienen que
    /// seguir funcionando siempre (punto delicado 7 del plan).
    private var activeText: String?

    init(surface: DrawingSurface) {
        self.surface = surface
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("no se usa") }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        DrawingRenderer.fillWhiteboard(context, size: bounds.size)
        DrawingRenderer.draw(items: surface.committedItems(),
                             liveStroke: surface.liveStroke(),
                             in: context,
                             size: bounds.size,
                             caretOnLast: activeText != nil)
        drawColorIndicator(in: context)
    }

    /// Muestra el color activo del marcador en una esquina.
    ///
    /// Va **solo acá**, en el espejo: esta ventana está excluida de la captura,
    /// así que el indicador no sale en el video. Es andamiaje hasta la Fase 11,
    /// donde el widget muestra el color como pide el plan (8.7). Sin esto, con el
    /// lienzo cubriendo la pantalla entera no hay forma de saber en qué color se
    /// está dibujando hasta que el trazo ya salió.
    private func drawColorIndicator(in context: CGContext) {
        let side: CGFloat = 26
        let margin: CGFloat = 18
        let rect = CGRect(x: bounds.maxX - side - margin,
                          y: bounds.maxY - side - margin,
                          width: side, height: side)

        context.setFillColor(surface.color.cgColor)
        context.fillEllipse(in: rect)
        // Contorno gris: sin él, el blanco desaparece sobre el lienzo y el
        // indicador dejaría de servir justo en el color donde más hace falta.
        context.setStrokeColor(CGColor(gray: 0.65, alpha: 1))
        context.setLineWidth(1.5)
        context.strokeEllipse(in: rect)
    }

    // MARK: - Mouse

    /// Del sistema de la vista (origen abajo) al del modelo (normalizado, origen
    /// arriba).
    private func normalized(_ point: CGPoint) -> CGPoint {
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        return CGPoint(x: point.x / bounds.width,
                       y: (bounds.height - point.y) / bounds.height)
    }

    override func mouseDown(with event: NSEvent) {
        closeTextBox()
        mouseDownAt = convert(event.locationInWindow, from: nil)
        isDrawing = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownAt else { return }
        let here = convert(event.locationInWindow, from: nil)

        if !isDrawing {
            guard hypot(here.x - start.x, here.y - start.y) >= Self.dragThreshold else { return }
            isDrawing = true
            surface.beginStroke(at: normalized(start))
        }

        surface.extendStroke(to: normalized(here))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { mouseDownAt = nil; isDrawing = false }

        if isDrawing {
            surface.endStroke()
        } else if let start = mouseDownAt {
            // Clic seco: abre un cuadro de texto y se empieza a tipear.
            surface.addTextBox(at: normalized(start))
            activeText = ""
        }
        needsDisplay = true
    }

    // MARK: - Teclado

    override func keyDown(with event: NSEvent) {
        // Sin cuadro activo el teclado no es nuestro: se deja pasar para que los
        // atajos del sistema y los de la app sigan andando.
        guard var text = activeText else {
            super.keyDown(with: event)
            return
        }

        // Esc y Enter cierran el cuadro.
        if event.keyCode == 53 || event.keyCode == 36 {
            closeTextBox()
            return
        }

        if event.keyCode == 51 {                    // borrar
            if !text.isEmpty { text.removeLast() }
        } else if let characters = event.characters,
                  !characters.isEmpty,
                  !event.modifierFlags.contains(.command) {
            text += characters
        }

        activeText = text
        surface.updateLastText(text)
        needsDisplay = true
    }

    func closeTextBox() {
        guard activeText != nil else { return }
        activeText = nil
        surface.dropLastTextIfEmpty()
        needsDisplay = true
    }
}
