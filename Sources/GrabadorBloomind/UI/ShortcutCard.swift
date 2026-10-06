import AppKit

/// Tarjeta con los atajos activos, agrupados como en el widget.
///
/// Aparece mientras se mantiene apretada su combinación y desaparece al soltar.
/// Es una ventana de la app, así que queda fuera de la captura: sirve para
/// acordarse en vivo sin que quede nada de eso en el video.
///
/// Desde la Fase 16 es una tarjeta blanca y opaca (decisión 123): la de antes
/// usaba el fondo translúcido del sistema, que toma el color de lo que tenga
/// detrás y en una hoja de cálculo se perdía.
@MainActor
final class ShortcutCard: NSPanel {

    private let stack = NSStackView()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 100),
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
        appearance = NSAppearance(named: .aqua)
        // No roba el foco: se muestra encima de lo que sea que esté pasando.
        ignoresMouseEvents = true

        let fondo = NSView()
        fondo.wantsLayer = true
        fondo.layer?.backgroundColor = BloomindStyle.Claro.blanco.cgColor
        fondo.layer?.cornerRadius = 14
        fondo.layer?.borderWidth = 1
        fondo.layer?.borderColor = BloomindStyle.Claro.tinta.withAlphaComponent(0.16).cgColor

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        fondo.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: fondo.leadingAnchor, constant: 26),
            stack.trailingAnchor.constraint(equalTo: fondo.trailingAnchor, constant: -26),
            stack.topAnchor.constraint(equalTo: fondo.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(equalTo: fondo.bottomAnchor, constant: -18),
            stack.widthAnchor.constraint(equalToConstant: 378)
        ])

        contentView = fondo
    }

    /// Muestra la tarjeta con los atajos que están activos en este momento.
    func show(shortcuts: [ShortcutAction: Shortcut], recording: Bool) {
        let c = BloomindStyle.Claro.self
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let titulo = NSTextField(labelWithString: "Atajos")
        titulo.font = BloomindStyle.display(24)
        titulo.textColor = c.tinta
        stack.addArrangedSubview(titulo)

        let sub = NSTextField(labelWithString: recording ? "Los que funcionan mientras grabás." : "Fuera de grabación solo funciona iniciar y detener.")
        sub.font = BloomindStyle.ui(12)
        sub.textColor = c.pizarra
        stack.addArrangedSubview(sub)
        stack.setCustomSpacing(6, after: sub)

        for grupo in ShortcutAction.grupos {
            let acciones = ShortcutAction.allCases.filter {
                $0.grupo == grupo && shortcuts[$0] != nil && (!$0.soloGrabando || recording)
            }
            guard !acciones.isEmpty else { continue }

            let cabeza = NSTextField(labelWithString: grupo)
            cabeza.font = BloomindStyle.ui(11, weight: .semibold)
            cabeza.textColor = c.pizarra
            stack.addArrangedSubview(cabeza)
            stack.setCustomSpacing(12, after: stack.arrangedSubviews[stack.arrangedSubviews.count - 2])

            for accion in acciones {
                let renglon = fila(accion.label, shortcuts[accion]!.etiqueta)
                stack.addArrangedSubview(renglon)
                renglon.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
        }

        // Abajo a la derecha de la pantalla donde está el mouse: donde esté
        // mirando, ahí aparece.
        let pantalla = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let visible = pantalla?.visibleFrame ?? .zero
        layoutIfNeeded()
        let size = contentView?.fittingSize ?? NSSize(width: 430, height: 200)
        setContentSize(size)
        setFrameOrigin(NSPoint(x: visible.maxX - size.width - 40, y: visible.minY + 36))
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }

    /// Un renglón: el nombre a la izquierda y las teclas a la derecha, cada
    /// una en su cajita, alineadas en columna (decisión 133).
    private func fila(_ nombre: String, _ combinacion: String) -> NSView {
        let etiqueta = NSTextField(labelWithString: nombre)
        etiqueta.font = BloomindStyle.ui(13)
        etiqueta.textColor = BloomindStyle.Claro.tinta
        etiqueta.lineBreakMode = .byTruncatingTail
        etiqueta.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let espaciador = NSView()
        espaciador.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let fila = NSStackView(views: [etiqueta, espaciador, Self.teclas(combinacion)])
        fila.alignment = .centerY
        fila.distribution = .fill
        fila.spacing = 12
        fila.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return fila
    }

    /// Las teclas de una combinación, una cajita por tecla: «⌥» «⌘» «3».
    static func teclas(_ combinacion: String) -> NSView {
        var piezas: [String] = []
        var resto = Substring(combinacion)
        while let primero = resto.first, "⌃⌥⇧⌘".contains(primero) {
            piezas.append(String(primero))
            resto = resto.dropFirst()
        }
        if !resto.isEmpty { piezas.append(String(resto)) }

        let fila = NSStackView(views: piezas.map { tecla in
            let texto = NSTextField(labelWithString: tecla)
            // La del sistema y no la monoespaciada: SF Mono dibuja ⌥, ⌘ y ⌫
            // apretados o raros.
            texto.font = BloomindStyle.ui(11.5, weight: .medium)
            texto.textColor = BloomindStyle.Claro.tinta
            texto.alignment = .center
            let caja = NSView()
            caja.wantsLayer = true
            caja.layer?.backgroundColor = BloomindStyle.Claro.papel.cgColor
            caja.layer?.borderColor = BloomindStyle.Claro.lineaFuerte.cgColor
            caja.layer?.borderWidth = 1
            caja.layer?.cornerRadius = 4
            texto.translatesAutoresizingMaskIntoConstraints = false
            caja.addSubview(texto)
            NSLayoutConstraint.activate([
                texto.leadingAnchor.constraint(equalTo: caja.leadingAnchor, constant: 5),
                texto.trailingAnchor.constraint(equalTo: caja.trailingAnchor, constant: -5),
                texto.centerYAnchor.constraint(equalTo: caja.centerYAnchor),
                caja.heightAnchor.constraint(equalToConstant: 20),
                caja.widthAnchor.constraint(greaterThanOrEqualToConstant: 20)
            ])
            return caja
        })
        fila.spacing = 3
        fila.setContentHuggingPriority(.required, for: .horizontal)
        return fila
    }
}
