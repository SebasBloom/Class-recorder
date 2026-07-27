import AppKit

/// Ventana temporal de la Fase 1: elegir pantalla, iniciar y detener.
///
/// Es andamiaje para poder probar la captura. El panel de configuración de
/// verdad y el widget flotante llegan en la Fase 11 y la reemplazan, pero ya
/// lleva la identidad visual de `BloomindStyle` para que la cara del producto
/// sea la misma desde el primer día.
@MainActor
final class ControlWindow: NSWindowController {

    private let recorder = RecordingController()

    private var displays: [CaptureDisplay] = []
    private let displayPopUp = NSPopUpButton()
    private let actionButton = BloomindButton(title: "Iniciar grabación")
    private let statusLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "Grabador")
    private let eyebrowLabel = NSTextField(labelWithString: "")

    private var timer: Timer?
    private var startedAt: Date?

    init() {
        // Sin fullSizeContentView a propósito: con la barra de título transparente
        // sobre el fondo deep ya se ve como una sola pieza, y el contenido no
        // queda debajo de los botones de cerrar.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Grabador Bloomind"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = BloomindStyle.deep
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        super.init(window: window)

        buildLayout()
        recorder.onStateChange = { [weak self] in self?.refresh() }
        Task { await loadDisplays() }
    }

    required init?(coder: NSCoder) { fatalError("no se usa") }

    private func buildLayout() {
        guard let contentView = window?.contentView else { return }

        eyebrowLabel.attributedStringValue = BloomindStyle.eyebrow("Bloomind Lab")

        titleLabel.font = BloomindStyle.display(30)
        titleLabel.textColor = BloomindStyle.ink

        let displayLabel = NSTextField(labelWithString: "Pantalla")
        displayLabel.font = BloomindStyle.ui(12)
        displayLabel.textColor = BloomindStyle.muted

        displayPopUp.font = BloomindStyle.ui(13)
        displayPopUp.setContentHuggingPriority(.defaultLow, for: .horizontal)

        statusLabel.font = BloomindStyle.mono(12)
        statusLabel.textColor = BloomindStyle.muted
        statusLabel.stringValue = "Buscando pantallas…"

        // Tarjeta: superficie elevada con hairline y sin sombra.
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = BloomindStyle.surface.cgColor
        card.layer?.cornerRadius = BloomindStyle.cornerRadius
        card.layer?.borderWidth = 1
        card.layer?.borderColor = BloomindStyle.hairline.cgColor

        let cardStack = NSStackView(views: [displayLabel, displayPopUp])
        cardStack.orientation = .vertical
        cardStack.alignment = .leading
        cardStack.spacing = BloomindStyle.Space.tight
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: BloomindStyle.Space.normal),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -BloomindStyle.Space.normal),
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: BloomindStyle.Space.normal),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -BloomindStyle.Space.normal)
        ])

        let header = NSStackView(views: [eyebrowLabel, titleLabel])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2

        let stack = NSStackView(views: [header, card, actionButton, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = BloomindStyle.Space.loose
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: BloomindStyle.Space.card),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -BloomindStyle.Space.card),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: BloomindStyle.Space.card),
            card.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actionButton.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        actionButton.target = self
        actionButton.action = #selector(toggleRecording)
    }

    private func loadDisplays() async {
        do {
            displays = try await RecordingController.availableDisplays()
            displayPopUp.removeAllItems()
            for display in displays {
                displayPopUp.addItem(withTitle: "\(display.name) · \(Int(display.pixelSize.width))×\(Int(display.pixelSize.height))")
            }

            // Memoria pegajosa: arranca en la última pantalla usada.
            if let last = ConfigurationStore.shared.current.lastDisplayID,
               let index = displays.firstIndex(where: { $0.scDisplay.displayID == last }) {
                displayPopUp.selectItem(at: index)
            }

            statusLabel.stringValue = displays.count == 1 ? "1 pantalla disponible" : "\(displays.count) pantallas disponibles"
            Logger.shared.log("Pantallas detectadas: \(displays.count)")

        } catch {
            // Sin permiso de grabación de pantalla, la enumeración también falla.
            statusLabel.stringValue = "No se pudieron listar las pantallas"
            statusLabel.textColor = BloomindStyle.signal
            Logger.shared.log("ERROR listando pantallas: \(error.localizedDescription)")
            _ = ScreenRecordingPermission.ensureGranted()
        }
    }

    @objc private func toggleRecording() {
        if recorder.isRecording {
            actionButton.isEnabled = false
            Task { await recorder.stop() }
        } else {
            guard displays.indices.contains(displayPopUp.indexOfSelectedItem) else { return }
            let display = displays[displayPopUp.indexOfSelectedItem]

            ConfigurationStore.shared.update { $0.lastDisplayID = display.scDisplay.displayID }

            actionButton.isEnabled = false
            Task { await recorder.start(display: display) }
        }
    }

    private func refresh() {
        actionButton.isEnabled = true
        displayPopUp.isEnabled = !recorder.isRecording
        statusLabel.textColor = BloomindStyle.muted

        if recorder.isRecording {
            actionButton.title = "Detener"
            startedAt = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            tick()
        } else {
            actionButton.title = "Iniciar grabación"
            timer?.invalidate()
            timer = nil
            startedAt = nil
            statusLabel.stringValue = "Listo"
        }
    }

    private func tick() {
        guard let startedAt else { return }
        let seconds = Int(Date().timeIntervalSince(startedAt))
        statusLabel.stringValue = String(format: "● Grabando   %02d:%02d", seconds / 60, seconds % 60)
        // El turquesa es exclusivo del éxito; grabar en curso va en lab.
        statusLabel.textColor = BloomindStyle.lab
    }
}
