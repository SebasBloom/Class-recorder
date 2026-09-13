import AppKit

/// Tarjeta translúcida con los atajos activos.
///
/// Aparece mientras se mantiene apretada su combinación y desaparece al soltar.
/// Es una ventana de la app, así que queda fuera de la captura: sirve para
/// acordarse en vivo sin que quede nada de eso en el video.
@MainActor
final class ShortcutCard: NSPanel {

    private let stack = NSStackView()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = WindowLayer.tarjeta.level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        // No roba el foco: se muestra encima de lo que sea que esté pasando.
        ignoresMouseEvents = true

        let fondo = NSVisualEffectView()
        fondo.material = .hudWindow
        fondo.blendingMode = .behindWindow
        fondo.state = .active
        fondo.wantsLayer = true
        fondo.layer?.cornerRadius = BloomindStyle.cornerRadius
        fondo.layer?.masksToBounds = true

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        fondo.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: fondo.leadingAnchor, constant: BloomindStyle.Space.normal),
            stack.trailingAnchor.constraint(equalTo: fondo.trailingAnchor, constant: -BloomindStyle.Space.normal),
            stack.topAnchor.constraint(equalTo: fondo.topAnchor, constant: BloomindStyle.Space.normal),
            stack.bottomAnchor.constraint(equalTo: fondo.bottomAnchor, constant: -BloomindStyle.Space.normal)
        ])

        contentView = fondo
    }

    /// Muestra la tarjeta con los atajos que están activos en este momento.
    func show(shortcuts: [ShortcutAction: Shortcut], recording: Bool) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let titulo = NSTextField(labelWithString: recording ? "Atajos durante la grabación" : "Atajos disponibles")
        titulo.font = BloomindStyle.ui(12, weight: .semibold)
        titulo.textColor = BloomindStyle.muted
        stack.addArrangedSubview(titulo)

        for action in ShortcutAction.allCases {
            guard let shortcut = shortcuts[action] else { continue }
            guard !action.soloGrabando || recording else { continue }
            stack.addArrangedSubview(fila(action.label, shortcut.etiqueta))
        }

        // Abajo a la derecha de la pantalla donde está el mouse: donde esté
        // mirando, ahí aparece.
        let pantalla = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let visible = pantalla?.visibleFrame ?? .zero
        layoutIfNeeded()
        let size = contentView?.fittingSize ?? NSSize(width: 340, height: 200)
        setContentSize(size)
        setFrameOrigin(NSPoint(x: visible.maxX - size.width - BloomindStyle.Space.card,
                               y: visible.minY + BloomindStyle.Space.card))
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }

    private func fila(_ nombre: String, _ combinacion: String) -> NSView {
        let etiqueta = NSTextField(labelWithString: nombre)
        etiqueta.font = BloomindStyle.ui(12)
        etiqueta.textColor = BloomindStyle.ink

        let teclas = NSTextField(labelWithString: combinacion)
        teclas.font = BloomindStyle.mono(12, weight: .medium)
        teclas.textColor = BloomindStyle.sky
        teclas.alignment = .right
        teclas.setContentHuggingPriority(.required, for: .horizontal)

        let fila = NSStackView(views: [etiqueta, teclas])
        fila.orientation = .horizontal
        fila.spacing = BloomindStyle.Space.loose
        fila.distribution = .fill
        return fila
    }
}
