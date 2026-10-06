import AppKit

/// Pantalla de preferencias de atajos: la lista completa, reasignación con un
/// clic y detección de conflictos.
@MainActor
final class ShortcutsWindow: NSWindowController {

    private let registry: ShortcutRegistry
    private let stack = NSStackView()
    private let statusLabel = NSTextField(labelWithString: "")

    /// Fila que está esperando que se teclee una combinación nueva, y el monitor
    /// que la escucha. Solo hay una a la vez.
    private var capturando: (action: ShortcutAction, boton: NSButton)?
    private var monitor: Any?

    init(registry: ShortcutRegistry) {
        self.registry = registry

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Atajos"
        // Clara, como el resto de la app desde la Fase 16 (decisión 123).
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = BloomindStyle.Claro.blanco
        window.titlebarAppearsTransparent = true
        window.center()
        super.init(window: window)

        buildLayout()
        reload()
    }

    required init?(coder: NSCoder) { fatalError("no se usa") }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    private func buildLayout() {
        guard let contentView = window?.contentView else { return }

        let eyebrow = NSTextField(labelWithString: "")
        eyebrow.attributedStringValue = NSAttributedString(string: "GRABADOR BLOOMIND", attributes: [
            .font: BloomindStyle.ui(11, weight: .semibold),
            .kern: 1.5,
            .foregroundColor: BloomindStyle.Claro.pizarra
        ])

        let titulo = NSTextField(labelWithString: "Atajos")
        titulo.font = BloomindStyle.display(28)
        titulo.textColor = BloomindStyle.Claro.tinta

        let ayuda = NSTextField(wrappingLabelWithString: "Tocá una combinación y tecleá la nueva. Todas necesitan al menos un modificador. Salvo iniciar y detener, los atajos solo funcionan mientras grabás.")
        ayuda.font = BloomindStyle.ui(12)
        ayuda.textColor = BloomindStyle.Claro.pizarra

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

        statusLabel.font = BloomindStyle.ui(12)
        statusLabel.textColor = BloomindStyle.Claro.pizarra

        let restaurar = BloomindButton(title: "Restaurar por defecto", kind: .claroSecundario)
        restaurar.target = self
        restaurar.action = #selector(restaurarPorDefecto)

        let todo = NSStackView(views: [eyebrow, titulo, ayuda, stack, statusLabel, restaurar])
        todo.orientation = .vertical
        todo.alignment = .leading
        todo.spacing = BloomindStyle.Space.normal
        todo.setCustomSpacing(2, after: eyebrow)
        todo.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(todo)

        NSLayoutConstraint.activate([
            todo.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: BloomindStyle.Space.card),
            todo.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -BloomindStyle.Space.card),
            todo.topAnchor.constraint(equalTo: contentView.topAnchor, constant: BloomindStyle.Space.card),
            todo.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -BloomindStyle.Space.card),
            stack.widthAnchor.constraint(equalTo: todo.widthAnchor)
        ])
    }

    private func reload() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Por grupos, los mismos de la tarjeta y del widget.
        for action in ShortcutAction.grupos.flatMap({ grupo in ShortcutAction.allCases.filter { $0.grupo == grupo } }) {
            guard let shortcut = registry.shortcuts[action] else { continue }

            if stack.arrangedSubviews.isEmpty || ShortcutAction.allCases.first(where: { $0.grupo == action.grupo }) == action {
                let cabeza = NSTextField(labelWithString: action.grupo)
                cabeza.font = BloomindStyle.ui(11, weight: .semibold)
                cabeza.textColor = BloomindStyle.Claro.pizarra
                if let anterior = stack.arrangedSubviews.last { stack.setCustomSpacing(14, after: anterior) }
                stack.addArrangedSubview(cabeza)
            }

            let nombre = NSTextField(labelWithString: action.label)
            nombre.font = BloomindStyle.ui(13)
            nombre.textColor = BloomindStyle.Claro.tinta

            let boton = NSButton(title: shortcut.etiqueta, target: self, action: #selector(capturar(_:)))
            boton.font = BloomindStyle.mono(12, weight: .medium)
            boton.bezelStyle = .rounded
            boton.tag = ShortcutAction.allCases.firstIndex(of: action) ?? 0
            boton.setContentHuggingPriority(.required, for: .horizontal)

            let fila = NSStackView(views: [nombre, boton])
            fila.orientation = .horizontal
            fila.distribution = .fill
            fila.spacing = BloomindStyle.Space.normal
            stack.addArrangedSubview(fila)
            fila.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        window?.contentView?.layoutSubtreeIfNeeded()
        if let fitting = window?.contentView?.fittingSize, fitting.height > 0 {
            window?.setContentSize(fitting)
        }
    }

    // MARK: - Reasignar

    @objc private func capturar(_ sender: NSButton) {
        cancelarCaptura()

        let action = ShortcutAction.allCases[sender.tag]
        capturando = (action, sender)
        sender.title = "tecleá…"
        statusLabel.stringValue = "Esperando la combinación para “\(action.label)”. Escape cancela."
        statusLabel.textColor = BloomindStyle.Claro.pizarra

        // Monitor local: la ventana de preferencias está adelante, así que las
        // teclas llegan acá sin necesidad de ningún permiso.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.recibir(event)
            return nil
        }
    }

    private func recibir(_ event: NSEvent) {
        guard let (action, boton) = capturando else { return }

        if event.keyCode == 53 {                       // esc
            boton.title = registry.shortcuts[action]?.etiqueta ?? ""
            statusLabel.stringValue = ""
            cancelarCaptura()
            return
        }

        guard let shortcut = Shortcut(event: event) else {
            statusLabel.stringValue = "Esa combinación no sirve: hace falta Comando, Opción o Control."
            statusLabel.textColor = BloomindStyle.Claro.coral
            return
        }

        if let enConflicto = registry.assign(shortcut, to: action) {
            statusLabel.stringValue = "\(shortcut.etiqueta) ya la usa “\(enConflicto.label)”. Elegí otra."
            statusLabel.textColor = BloomindStyle.Claro.coral
            return
        }

        statusLabel.stringValue = "“\(action.label)” quedó en \(shortcut.etiqueta)."
        statusLabel.textColor = BloomindStyle.Claro.tinta
        cancelarCaptura()
        reload()
    }

    private func cancelarCaptura() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        capturando = nil
    }

    @objc private func restaurarPorDefecto() {
        cancelarCaptura()
        registry.resetToDefaults()
        statusLabel.stringValue = "Todos los atajos volvieron a su combinación original."
        statusLabel.textColor = BloomindStyle.Claro.pizarra
        reload()
    }
}
