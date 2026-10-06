import AppKit

/// Lleva el recorrido del tutorial (decisión 137): oscurece la pantalla menos
/// lo que explica, pone la burbuja al lado y avanza paso a paso.
///
/// No sabe dónde está cada cosa: se lo pregunta a quien lo usa con `ubicar`,
/// en coordenadas de pantalla, cada vez que refresca. Así sigue a la cápsula si
/// se arrastra y aparece apenas algo se vuelve visible.
@MainActor
final class TutorialController {

    /// Dónde está en la pantalla lo que hay que iluminar, o nil si no está a
    /// la vista.
    var ubicar: ((ObjetivoTutorial) -> NSRect?)?
    var estaGrabando: (() -> Bool)?
    /// Marca la próxima grabación como de práctica, o la desmarca.
    var marcarPractica: ((Bool) -> Void)?
    /// Se llama al entrar a cada paso, para dejar la pantalla lista (el panel
    /// a la vista, la cápsula completa).
    var prepararPaso: ((PasoTutorial) -> Void)?
    /// Salir en plena práctica la detiene, y con eso se va a la Papelera.
    var detenerPractica: (() -> Void)?
    /// Se terminó o se cerró: no vuelve a salir solo.
    var onTerminar: (() -> Void)?

    private(set) var activo = false
    private var indice = 0
    private var velos: [VeloWindow] = []
    private let burbuja = BurbujaWindow()
    private var reloj: Timer?
    private var ultimoObjetivo: NSRect?

    private var paso: PasoTutorial { TutorialSteps.pasos[indice] }

    init() {
        burbuja.onAnterior = { [weak self] in self?.ir(a: (self?.indice ?? 1) - 1) }
        burbuja.onSiguiente = { [weak self] in self?.ir(a: (self?.indice ?? 0) + 1) }
        burbuja.onSalir = { [weak self] in self?.terminar() }
        burbuja.onSoloGrabar = { [weak self] in self?.ir(a: TutorialSteps.indiceGrabar) }
    }

    func empezar(enGrabar: Bool = false) {
        guard !activo else { return }
        activo = true
        velos = NSScreen.screens.map { VeloWindow(pantalla: $0) }
        velos.forEach { $0.orderFrontRegardless() }
        Logger.shared.log("Tutorial abierto")
        ir(a: enGrabar ? TutorialSteps.indiceGrabar : 0)

        // En los modos comunes, para que siga refrescando mientras hay un menú
        // abierto o la pregunta de reiniciar esperando respuesta.
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refrescar() }
        }
        RunLoop.main.add(timer, forMode: .common)
        reloj = timer
    }

    /// La grabación empezó o terminó: los pasos que lo esperan avanzan solos.
    func avisarCambioDeGrabacion(grabando: Bool) {
        guard activo else { return }
        switch (paso.esperar, grabando) {
        case (.queEmpieceLaGrabacion, true):
            ir(a: indice + 1)
        case (_, false) where indice > TutorialSteps.indiceGrabar:
            // Terminó la práctica, desde el paso de detener o desde otro lado:
            // va al final.
            ir(a: TutorialSteps.pasos.count - 1)
        default:
            break
        }
    }

    func ir(a nuevo: Int) {
        guard TutorialSteps.pasos.indices.contains(nuevo) else {
            terminar()
            return
        }
        // Volver de «Grabar» antes de grabar desarma la práctica.
        if indice == TutorialSteps.indiceGrabar, nuevo < indice, !(estaGrabando?() ?? false) {
            marcarPractica?(false)
        }
        indice = nuevo
        if paso.esperar == .queEmpieceLaGrabacion { marcarPractica?(true) }
        prepararPaso?(paso)
        ultimoObjetivo = nil
        burbuja.mostrar(paso, numero: indice + 1, de: TutorialSteps.pasos.count,
                        esPrimero: indice == 0)
        refrescar()
    }

    private func terminar() {
        guard activo else { return }
        activo = false
        reloj?.invalidate()
        reloj = nil
        velos.forEach { $0.orderOut(nil) }
        velos = []
        burbuja.orderOut(nil)
        if estaGrabando?() ?? false {
            detenerPractica?()
        } else {
            marcarPractica?(false)
        }
        Logger.shared.log("Tutorial cerrado en el paso \(indice + 1) de \(TutorialSteps.pasos.count)")
        onTerminar?()
    }

    /// Vuelve a buscar dónde está todo y redibuja.
    private func refrescar() {
        guard activo else { return }
        let objetivo = paso.objetivo.flatMap { ubicar?($0) }

        // Lo que la app abre encima mientras tanto se ilumina solo, para que
        // nunca quede algo tapado esperando un clic (decisión 138).
        let abiertos = NSApp.windows.filter { ventana in
            ventana.isVisible && !(ventana is VeloWindow) && ventana !== burbuja
                && (ventana is ShortcutCard || ventana is RectangleSelector
                    || ventana === NSApp.modalWindow
                    || String(describing: type(of: ventana)).contains("Popover"))
        }.map(\.frame)

        for velo in velos {
            velo.pintar(objetivo: objetivo, abiertos: abiertos, oscurecer: paso.oscurecer)
        }

        // La burbuja se mueve solo si lo iluminado se movió de verdad: si no,
        // temblaría con cada refresco.
        if ultimoObjetivo == nil || objetivo.map({ !$0.equalTo(ultimoObjetivo!) }) ?? false {
            ultimoObjetivo = objetivo ?? .zero
            burbuja.colocar(cerca: objetivo)
        }
    }
}

// MARK: - El velo

/// Una ventana del tamaño de una pantalla que la oscurece entera menos un
/// agujero. Por el agujero pasan los clics, porque ahí no pinta nada
/// (decisión 138).
@MainActor
private final class VeloWindow: NSPanel {

    private let vista = VeloView()

    init(pantalla: NSScreen) {
        super.init(contentRect: pantalla.frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = WindowLayer.tutorialVelo.level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        setFrame(pantalla.frame, display: false)
        contentView = vista
    }

    override var canBecomeKey: Bool { false }

    func pintar(objetivo: NSRect?, abiertos: [NSRect], oscurecer: Bool) {
        let local = { (r: NSRect) in r.offsetBy(dx: -self.frame.minX, dy: -self.frame.minY) }
        vista.oscurecer = oscurecer
        vista.marco = objetivo.map(local)
        vista.abiertos = abiertos.map(local)
        vista.needsDisplay = true
    }
}

@MainActor
private final class VeloView: NSView {
    var oscurecer = true
    var marco: NSRect?
    var abiertos: [NSRect] = []

    override func draw(_ dirtyRect: NSRect) {
        guard let contexto = NSGraphicsContext.current?.cgContext else { return }
        let agujero = marco.map { NSBezierPath(roundedRect: $0.insetBy(dx: -8, dy: -8), xRadius: 12, yRadius: 12) }

        if oscurecer {
            BloomindStyle.Claro.tinta.withAlphaComponent(0.55).setFill()
            bounds.fill()
            contexto.setBlendMode(.clear)
            agujero?.fill()
            for abierto in abiertos { NSBezierPath(roundedRect: abierto.insetBy(dx: -4, dy: -4), xRadius: 10, yRadius: 10).fill() }
            contexto.setBlendMode(.normal)
        }

        // El borde azul marca lo que se explica, también cuando no se oscurece.
        if let agujero {
            BloomindStyle.Claro.azul.setStroke()
            agujero.lineWidth = 2.5
            agujero.stroke()
        }
    }

    // Lo oscuro no responde: un clic ahí no hace nada.
    override func mouseDown(with event: NSEvent) {}
}

// MARK: - La burbuja

/// La explicación de cada paso, con Anterior, Siguiente y Salir.
@MainActor
private final class BurbujaWindow: NSPanel {

    var onAnterior: (() -> Void)?
    var onSiguiente: (() -> Void)?
    var onSalir: (() -> Void)?
    var onSoloGrabar: (() -> Void)?

    private let contador = NSTextField(labelWithString: "")
    private let titulo = NSTextField(wrappingLabelWithString: "")
    private let texto = NSTextField(wrappingLabelWithString: "")
    private let esperando = NSTextField(labelWithString: "")
    private let salir = NSButton()
    private let soloGrabar = BloomindButton(title: "Solo la parte de grabar", kind: .claroSecundario)
    private let anterior = BloomindButton(title: "Anterior", kind: .claroSecundario)
    private let siguiente = BloomindButton(title: "Siguiente", kind: .claro)

    private static let ancho: CGFloat = 420

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: Self.ancho, height: 200),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = WindowLayer.tutorialBurbuja.level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        appearance = NSAppearance(named: .aqua)

        let c = BloomindStyle.Claro.self
        let fondo = NSView()
        fondo.wantsLayer = true
        fondo.layer?.backgroundColor = c.blanco.cgColor
        fondo.layer?.cornerRadius = 14
        fondo.layer?.borderWidth = 1
        fondo.layer?.borderColor = c.tinta.withAlphaComponent(0.14).cgColor

        contador.font = BloomindStyle.ui(11, weight: .semibold)
        contador.textColor = c.pizarra
        titulo.font = BloomindStyle.display(20)
        titulo.textColor = c.tinta
        texto.font = BloomindStyle.ui(13.5)
        texto.textColor = c.tinta
        esperando.font = BloomindStyle.ui(12, weight: .medium)
        esperando.textColor = c.azul

        salir.isBordered = false
        salir.attributedTitle = NSAttributedString(string: "Salir", attributes: [
            .font: BloomindStyle.ui(13), .foregroundColor: c.pizarra
        ])
        salir.target = self; salir.action = #selector(tocarSalir)
        salir.toolTip = "Cierra el tutorial. Si estás en la grabación de práctica, la detiene y la manda a la Papelera."
        soloGrabar.target = self; soloGrabar.action = #selector(tocarSoloGrabar)
        anterior.target = self; anterior.action = #selector(tocarAnterior)
        siguiente.target = self; siguiente.action = #selector(tocarSiguiente)

        let espaciador = NSView()
        espaciador.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let botones = NSStackView(views: [salir, espaciador, esperando, soloGrabar, anterior, siguiente])
        botones.alignment = .centerY
        botones.distribution = .fill
        botones.spacing = 8

        let pila = NSStackView(views: [contador, titulo, texto, botones])
        pila.orientation = .vertical
        pila.alignment = .leading
        pila.spacing = 6
        pila.setCustomSpacing(16, after: texto)
        pila.edgeInsets = NSEdgeInsets(top: 18, left: 22, bottom: 16, right: 18)
        pila.translatesAutoresizingMaskIntoConstraints = false
        fondo.addSubview(pila)
        NSLayoutConstraint.activate([
            pila.leadingAnchor.constraint(equalTo: fondo.leadingAnchor),
            pila.trailingAnchor.constraint(equalTo: fondo.trailingAnchor),
            pila.topAnchor.constraint(equalTo: fondo.topAnchor),
            pila.bottomAnchor.constraint(equalTo: fondo.bottomAnchor),
            pila.widthAnchor.constraint(equalToConstant: Self.ancho),
            titulo.widthAnchor.constraint(equalToConstant: Self.ancho - 40),
            texto.widthAnchor.constraint(equalToConstant: Self.ancho - 40),
            botones.widthAnchor.constraint(equalToConstant: Self.ancho - 40)
        ])
        titulo.preferredMaxLayoutWidth = Self.ancho - 40
        texto.preferredMaxLayoutWidth = Self.ancho - 40
        contentView = fondo
    }

    override var canBecomeKey: Bool { false }

    func mostrar(_ paso: PasoTutorial, numero: Int, de total: Int, esPrimero: Bool) {
        contador.stringValue = "\(numero) de \(total)"
        titulo.stringValue = paso.titulo
        texto.stringValue = paso.texto

        let ultimo = numero == total
        anterior.isHidden = esPrimero || ultimo
        soloGrabar.isHidden = !esPrimero
        // Los pasos que esperan algo no tienen Siguiente: avanzan solos cuando
        // pasa, y la burbuja dice qué está esperando.
        siguiente.isHidden = paso.esperar != nil
        esperando.isHidden = paso.esperar == nil
        esperando.stringValue = paso.esperar == .queEmpieceLaGrabacion ? "Esperando que grabes…" : "Esperando que detengas…"
        siguiente.title = esPrimero ? "Empezar" : (ultimo ? "Terminar" : "Siguiente")
        salir.isHidden = ultimo

        contentView?.layoutSubtreeIfNeeded()
        setContentSize(contentView?.fittingSize ?? NSSize(width: Self.ancho, height: 200))
        orderFrontRegardless()
    }

    func colocar(cerca objetivo: NSRect?) {
        let pantalla = (objetivo.flatMap { o in NSScreen.screens.first { $0.frame.intersects(o) } } ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        // Lejos del borde azul, que va 8 puntos afuera de lo iluminado.
        let origen = TutorialSteps.ubicarBurbuja(tamaño: frame.size,
                                                 objetivo: objetivo?.insetBy(dx: -8, dy: -8),
                                                 pantalla: pantalla)
        setFrameOrigin(origen)
    }

    @objc private func tocarAnterior() { onAnterior?() }
    @objc private func tocarSiguiente() { onSiguiente?() }
    @objc private func tocarSalir() { onSalir?() }
    @objc private func tocarSoloGrabar() { onSoloGrabar?() }
}

extension NSView {
    /// Dónde está esta vista en la pantalla, o nil si no se ve.
    var marcoEnPantalla: NSRect? {
        guard let ventana = window, ventana.isVisible, !isHiddenOrHasHiddenAncestor else { return nil }
        return ventana.convertToScreen(convert(bounds, to: nil))
    }
}
