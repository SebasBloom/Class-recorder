import AppKit

/// Cuenta regresiva 3, 2, 1 antes de que arranque la grabación.
///
/// El archivo empieza **después** del conteo (plan, 8.9), así que estos segundos
/// no salen en el video. Es una ventana de la app, además, con lo cual tampoco
/// aparecería aunque la grabación ya estuviera corriendo.
///
/// Desde la Fase 16 es un disco blanco con la cifra en Fraunces y un anillo azul
/// que se vacía en cada segundo (decisión 123): se lee el tiempo que falta sin
/// leer el número.
@MainActor
final class CountdownWindow: NSPanel {

    private static let diametro: CGFloat = 230

    private let numero = NSTextField(labelWithString: "")
    private let anillo = CAShapeLayer()
    private var restante = 3
    private var timer: Timer?
    private var alTerminar: (() -> Void)?

    /// Muestra el conteo y llama al bloque cuando llega a cero.
    static func present(desde: Int = 3, alTerminar: @escaping () -> Void) {
        let ventana = CountdownWindow()
        ventana.restante = desde
        ventana.alTerminar = alTerminar
        ventana.arrancar()
    }

    private init() {
        let d = Self.diametro
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: d, height: d),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = WindowLayer.countdown.level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        ignoresMouseEvents = true

        let c = BloomindStyle.Claro.self
        let fondo = NSView()
        fondo.wantsLayer = true
        fondo.layer?.backgroundColor = c.blanco.cgColor
        fondo.layer?.cornerRadius = d / 2
        fondo.layer?.borderWidth = 1
        fondo.layer?.borderColor = c.tinta.withAlphaComponent(0.12).cgColor

        // El anillo de fondo, gris, y encima el azul que se va vaciando. El
        // camino arranca arriba y va en el sentido del reloj, así que vaciarlo
        // con `strokeEnd` lo come desde la punta, como una aguja.
        let camino = CGMutablePath()
        camino.addArc(center: CGPoint(x: d / 2, y: d / 2), radius: d / 2 - 5,
                      startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true)
        let base = CAShapeLayer()
        base.path = camino
        base.fillColor = nil
        base.strokeColor = c.linea.cgColor
        base.lineWidth = 3
        fondo.layer?.addSublayer(base)

        anillo.path = camino
        anillo.fillColor = nil
        anillo.strokeColor = c.azul.cgColor
        anillo.lineWidth = 3
        anillo.lineCap = .round
        anillo.frame = CGRect(x: 0, y: 0, width: d, height: d)
        fondo.layer?.addSublayer(anillo)

        numero.font = BloomindStyle.display(128, weight: 500)
        numero.textColor = c.tinta
        numero.alignment = .center
        numero.translatesAutoresizingMaskIntoConstraints = false
        fondo.addSubview(numero)

        NSLayoutConstraint.activate([
            numero.centerXAnchor.constraint(equalTo: fondo.centerXAnchor),
            // La cifra en serif lleva el peso abajo: un poco arriba del centro
            // se ve centrada.
            numero.centerYAnchor.constraint(equalTo: fondo.centerYAnchor, constant: -6)
        ])

        contentView = fondo
        centrarEnPantallaDelMouse()
    }

    private func centrarEnPantallaDelMouse() {
        let pantalla = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let marco = pantalla?.frame else { return }
        setFrameOrigin(NSPoint(x: marco.midX - Self.diametro / 2, y: marco.midY - Self.diametro / 2))
    }

    private func arrancar() {
        mostrar(restante)
        orderFrontRegardless()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        restante -= 1
        if restante > 0 {
            mostrar(restante)
            return
        }

        timer?.invalidate()
        timer = nil
        orderOut(nil)
        alTerminar?()
        alTerminar = nil
    }

    private func mostrar(_ valor: Int) {
        numero.stringValue = "\(valor)"
        let vaciar = CABasicAnimation(keyPath: "strokeEnd")
        vaciar.fromValue = 1
        vaciar.toValue = 0
        vaciar.duration = 1
        anillo.strokeEnd = 0
        anillo.add(vaciar, forKey: "vaciar")
    }
}
