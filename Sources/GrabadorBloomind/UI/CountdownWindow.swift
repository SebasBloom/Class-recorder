import AppKit

/// Cuenta regresiva 3, 2, 1 antes de que arranque la grabación.
///
/// El archivo empieza **después** del conteo (plan, 8.9), así que estos segundos
/// no salen en el video. Es una ventana de la app, además, con lo cual tampoco
/// aparecería aunque la grabación ya estuviera corriendo.
@MainActor
final class CountdownWindow: NSPanel {

    private let numero = NSTextField(labelWithString: "")
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
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 220),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true

        let fondo = NSVisualEffectView()
        fondo.material = .hudWindow
        fondo.blendingMode = .behindWindow
        fondo.state = .active
        fondo.wantsLayer = true
        fondo.layer?.cornerRadius = 110
        fondo.layer?.masksToBounds = true

        numero.font = BloomindStyle.display(96)
        numero.textColor = BloomindStyle.ink
        numero.alignment = .center
        numero.translatesAutoresizingMaskIntoConstraints = false
        fondo.addSubview(numero)

        NSLayoutConstraint.activate([
            numero.centerXAnchor.constraint(equalTo: fondo.centerXAnchor),
            numero.centerYAnchor.constraint(equalTo: fondo.centerYAnchor)
        ])

        contentView = fondo
        centrarEnPantallaDelMouse()
    }

    private func centrarEnPantallaDelMouse() {
        let pantalla = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let marco = pantalla?.frame else { return }
        setFrameOrigin(NSPoint(x: marco.midX - 110, y: marco.midY - 110))
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
    }
}
