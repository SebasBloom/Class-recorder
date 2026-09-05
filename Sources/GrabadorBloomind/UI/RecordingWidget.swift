import AppKit

/// Widget flotante durante la grabación.
///
/// Chiquito, arrastrable, siempre encima y excluido de la captura (plan, 8.9).
/// Es lo que reemplaza a tener que buscar la ventana de control: muestra tiempo,
/// estado, modo activo, si hay censura puesta y con qué color se está dibujando,
/// y tiene los botones de las acciones que se usan en vivo.
///
/// Es un `NSPanel` que no activa la app: tocarle un botón no le roba el foco a lo
/// que se está mostrando en clase.
@MainActor
final class RecordingWidget: NSPanel {

    var onPause: (() -> Void)?
    var onStop: (() -> Void)?
    var onRestart: (() -> Void)?
    var onToggleBubble: (() -> Void)?
    /// Devuelve el menú de cámaras en el momento de abrirlo, no antes: la lista
    /// cambia cuando se conecta o desconecta un aparato.
    var onCameraMenu: (() -> NSMenu?)?
    var onToggleMicrophone: (() -> Void)?
    var onToggleSystemAudio: (() -> Void)?

    private let tiempo = NSTextField(labelWithString: "00:00")
    private let estado = NSTextField(labelWithString: "")
    private let detalle = NSTextField(labelWithString: "")
    private let puntoColor = NSView()

    private let pausar = NSButton()
    private let detener = NSButton()
    private let reiniciar = NSButton()
    private let burbuja = NSButton()
    private let microfono = NSButton()
    private let sistema = NSButton()

    /// Si hay una cámara encendida ahora mismo. No se puede leer del botón,
    /// porque el botón está siempre habilitado: sin cámara sigue sirviendo para
    /// prender una.
    private var hayCamaraPrendida = false

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 96),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true

        construir()
        colocar()
    }

    // MARK: - Construcción

    private func construir() {
        let fondo = NSVisualEffectView()
        fondo.material = .hudWindow
        fondo.blendingMode = .behindWindow
        fondo.state = .active
        fondo.wantsLayer = true
        fondo.layer?.cornerRadius = BloomindStyle.cornerRadius
        fondo.layer?.masksToBounds = true

        tiempo.font = BloomindStyle.mono(20, weight: .medium)
        tiempo.textColor = BloomindStyle.ink

        estado.font = BloomindStyle.ui(11, weight: .semibold)
        estado.textColor = BloomindStyle.lab

        detalle.font = BloomindStyle.ui(11)
        detalle.textColor = BloomindStyle.muted

        puntoColor.wantsLayer = true
        puntoColor.layer?.cornerRadius = 5
        puntoColor.layer?.borderWidth = 1
        puntoColor.layer?.borderColor = CGColor(gray: 0.6, alpha: 1)
        puntoColor.isHidden = true
        puntoColor.translatesAutoresizingMaskIntoConstraints = false
        puntoColor.widthAnchor.constraint(equalToConstant: 10).isActive = true
        puntoColor.heightAnchor.constraint(equalToConstant: 10).isActive = true

        let fila1 = NSStackView(views: [tiempo, estado])
        fila1.orientation = .horizontal
        fila1.spacing = BloomindStyle.Space.tight
        fila1.alignment = .centerY

        let fila2 = NSStackView(views: [puntoColor, detalle])
        fila2.orientation = .horizontal
        fila2.spacing = 6
        fila2.alignment = .centerY

        configurar(pausar, simbolo: "pause.fill", ayuda: "Pausar", accion: #selector(tocarPausa))
        configurar(detener, simbolo: "stop.fill", ayuda: "Detener", accion: #selector(tocarDetener))
        configurar(reiniciar, simbolo: "arrow.counterclockwise", ayuda: "Reiniciar toma", accion: #selector(tocarReiniciar))
        configurar(burbuja, simbolo: "person.crop.circle", ayuda: "Cámara", accion: #selector(tocarBurbuja))
        // Mantener presionado el botón: el menú de cámaras, haya o no una prendida.
        let menuLargo = NSPressGestureRecognizer(target: self, action: #selector(mostrarMenuDeCamara))
        menuLargo.minimumPressDuration = 0.35
        burbuja.addGestureRecognizer(menuLargo)
        configurar(microfono, simbolo: "mic.fill", ayuda: "Silenciar micrófono", accion: #selector(tocarMicrofono))
        configurar(sistema, simbolo: "speaker.wave.2.fill", ayuda: "Silenciar audio del sistema", accion: #selector(tocarSistema))

        let botones = NSStackView(views: [pausar, detener, reiniciar, burbuja, microfono, sistema])
        botones.orientation = .horizontal
        botones.spacing = 4

        let todo = NSStackView(views: [fila1, fila2, botones])
        todo.orientation = .vertical
        todo.alignment = .leading
        todo.spacing = 6
        todo.translatesAutoresizingMaskIntoConstraints = false
        fondo.addSubview(todo)

        NSLayoutConstraint.activate([
            todo.leadingAnchor.constraint(equalTo: fondo.leadingAnchor, constant: BloomindStyle.Space.normal),
            todo.trailingAnchor.constraint(lessThanOrEqualTo: fondo.trailingAnchor, constant: -BloomindStyle.Space.normal),
            todo.topAnchor.constraint(equalTo: fondo.topAnchor, constant: BloomindStyle.Space.tight),
            todo.bottomAnchor.constraint(equalTo: fondo.bottomAnchor, constant: -BloomindStyle.Space.tight)
        ])

        contentView = fondo
    }

    private func configurar(_ boton: NSButton, simbolo: String, ayuda: String, accion: Selector) {
        boton.image = NSImage(systemSymbolName: simbolo, accessibilityDescription: ayuda)
        boton.bezelStyle = .texturedRounded
        boton.imagePosition = .imageOnly
        boton.toolTip = ayuda
        boton.target = self
        boton.action = accion
    }

    /// Abajo a la derecha de la pantalla principal la primera vez; después
    /// recuerda dónde lo dejaste.
    private func colocar() {
        if let guardada = ConfigurationStore.shared.current.widgetPosition {
            let punto = NSPoint(x: guardada.x, y: guardada.y)
            if NSScreen.screens.contains(where: { $0.frame.contains(punto) }) {
                setFrameOrigin(punto)
                return
            }
        }
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        setFrameOrigin(NSPoint(x: visible.maxX - frame.width - BloomindStyle.Space.card,
                               y: visible.maxY - frame.height - BloomindStyle.Space.card))
    }

    // MARK: - Estado

    /// Refresca todo lo que muestra.
    func update(segundos: Int,
                pausado: Bool,
                modo: CaptureMode,
                censura: Bool,
                anotando: Bool,
                color: MarkerColor,
                hayCamara: Bool,
                audio: AudioState) {

        tiempo.stringValue = String(format: "%02d:%02d", segundos / 60, segundos % 60)
        estado.stringValue = pausado ? "❚❚ PAUSADO" : "● GRABANDO"
        // El turquesa es exclusivo del éxito: grabando va en lab, pausado en gris.
        estado.textColor = pausado ? BloomindStyle.muted : BloomindStyle.lab

        var partes: [String] = []
        switch modo {
        case .pantalla: partes.append("Pantalla")
        case .camara:   partes.append("Cámara")
        case .tablero:  partes.append("Tablero")
        }
        if anotando { partes.append("anotando") }
        if censura { partes.append("▓ censura") }
        // El silencio va con nombre y no solo con el ícono tachado: es lo que
        // evita grabar media clase mudo sin darse cuenta.
        if audio.microfonoSilenciado && audio.sistemaSilenciado {
            partes.append("🔇 SIN AUDIO")
        } else if audio.microfonoSilenciado {
            partes.append("🔇 micrófono")
        } else if audio.sistemaSilenciado {
            partes.append("🔇 sistema")
        }
        detalle.stringValue = partes.joined(separator: " · ")

        // El punto de color solo tiene sentido cuando se está dibujando.
        let dibujando = modo == .tablero || anotando
        puntoColor.isHidden = !dibujando
        puntoColor.layer?.backgroundColor = color.cgColor

        pausar.image = NSImage(systemSymbolName: pausado ? "play.fill" : "pause.fill",
                               accessibilityDescription: pausado ? "Reanudar" : "Pausar")
        pausar.toolTip = pausado ? "Reanudar" : "Pausar"
        // El botón de cámara nunca se deshabilita: sin cámara prendida sigue
        // sirviendo para prender una, que es justo lo que pasa cuando se arrancó
        // a grabar sin elegir ninguna (decisión 82). Un botón deshabilitado no
        // recibe clics y el menú quedaría inalcanzable justo cuando hace falta.
        hayCamaraPrendida = hayCamara
        burbuja.isEnabled = true
        burbuja.image = NSImage(systemSymbolName: hayCamara ? "person.crop.circle" : "person.crop.circle.badge.plus",
                                accessibilityDescription: "Cámara")
        burbuja.toolTip = hayCamara
            ? "Burbuja on/off · mantené o clic derecho para elegir cámara"
            : "Elegir cámara"
        burbuja.contentTintColor = hayCamara ? nil : BloomindStyle.muted

        // Las fuentes que no se eligieron antes de arrancar quedan deshabilitadas,
        // no ausentes: el botón no es un atajo para encenderlas (decisión 82).
        actualizar(microfono, activa: audio.capturaMicrofono, silenciada: audio.microfonoSilenciado,
                   simboloVivo: "mic.fill", simboloMudo: "mic.slash.fill",
                   ayudaViva: "Silenciar micrófono", ayudaMuda: "Activar micrófono")
        actualizar(sistema, activa: audio.capturaSistema, silenciada: audio.sistemaSilenciado,
                   simboloVivo: "speaker.wave.2.fill", simboloMudo: "speaker.slash.fill",
                   ayudaViva: "Silenciar audio del sistema", ayudaMuda: "Activar audio del sistema")
    }

    /// Estado de audio que muestra el widget.
    struct AudioState {
        let capturaMicrofono: Bool
        let capturaSistema: Bool
        let microfonoSilenciado: Bool
        let sistemaSilenciado: Bool
    }

    /// Un botón de audio: prendido, mudo o deshabilitado. El símbolo tachado es
    /// lo que hace que se vea de reojo en mitad de una clase, sin leer.
    private func actualizar(_ boton: NSButton, activa: Bool, silenciada: Bool,
                            simboloVivo: String, simboloMudo: String,
                            ayudaViva: String, ayudaMuda: String) {
        boton.isEnabled = activa
        let simbolo = silenciada ? simboloMudo : simboloVivo
        let ayuda = silenciada ? ayudaMuda : ayudaViva
        boton.image = NSImage(systemSymbolName: simbolo, accessibilityDescription: ayuda)
        boton.toolTip = activa ? ayuda : "No se eligió esta fuente antes de grabar"
        boton.contentTintColor = silenciada ? BloomindStyle.signal : nil
    }

    func present() {
        orderFrontRegardless()
    }

    func hide() {
        guardarPosicion()
        orderOut(nil)
    }

    // MARK: - Interno

    override func setFrameOrigin(_ point: NSPoint) {
        super.setFrameOrigin(point)
    }

    private func guardarPosicion() {
        let origen = frame.origin
        ConfigurationStore.shared.update {
            $0.widgetPosition = StoredPoint(x: origen.x, y: origen.y)
        }
    }

    @objc private func tocarPausa() { onPause?() }
    @objc private func tocarDetener() { onStop?() }
    /// Con cámara prendida, el botón prende y apaga la burbuja, que es lo que se
    /// hace veinte veces en una clase. El menú, que es lo que se hace una vez,
    /// sale manteniéndolo o con clic derecho. Sin cámara prendida, el clic normal
    /// abre el menú directo: no hay burbuja que alternar todavía.
    @objc private func tocarBurbuja() {
        if hayCamaraPrendida { onToggleBubble?() } else { mostrarMenuDeCamara() }
    }

    @objc private func mostrarMenuDeCamara() {
        guard let menu = onCameraMenu?() else { return }
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: burbuja.bounds.height + 4),
                   in: burbuja)
    }
    @objc private func tocarMicrofono() { onToggleMicrophone?() }
    @objc private func tocarSistema() { onToggleSystemAudio?() }

    /// Reiniciar toma descarta lo grabado. Manda a la Papelera, no borra
    /// (decisión 12), pero igual pregunta: es la única acción del widget que
    /// tira a la basura una clase en curso.
    /// Lo llama el botón y también el atajo, para que los dos pasen por la misma
    /// confirmación.
    func confirmRestart() {
        tocarReiniciar()
    }

    @objc private func tocarReiniciar() {
        let alerta = NSAlert()
        alerta.messageText = "¿Reiniciar la toma?"
        alerta.informativeText = "Lo grabado hasta ahora se manda a la Papelera y arranca una toma nueva con la misma configuración."
        alerta.addButton(withTitle: "Reiniciar")
        alerta.addButton(withTitle: "Seguir grabando")
        alerta.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        guard alerta.runModal() == .alertFirstButtonReturn else { return }
        onRestart?()
    }
}
