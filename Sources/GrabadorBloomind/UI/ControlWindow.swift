import AppKit
import UniformTypeIdentifiers

/// Ventana temporal de la Fase 1: elegir pantalla, iniciar y detener.
///
/// Es andamiaje para poder probar la captura. El panel de configuración de
/// verdad y el widget flotante llegan en la Fase 11 y la reemplazan, pero ya
/// lleva la identidad visual de `BloomindStyle` para que la cara del producto
/// sea la misma desde el primer día.
@MainActor
final class ControlWindow: NSWindowController, NSTextViewDelegate {

    let recorder = RecordingController()

    /// Avisa a la barra de menú para que cambie el estado del ícono.
    var onRecordingStateChange: ((Bool, Bool) -> Void)?

    /// Muestra u oculta la tarjeta de atajos desde el botón del widget. La
    /// tarjeta y el registro de atajos viven en la barra de menú, no acá, porque
    /// tienen que existir aunque no haya ninguna grabación en curso.
    var onToggleShortcutCard: (() -> Void)?

    private var displays: [CaptureDisplay] = []
    private let displayPopUp = NSPopUpButton()

    private let audioModePopUp = NSPopUpButton()
    private let microphoneEnumerator = AudioDeviceEnumerator()
    private let levelMeter = AudioLevelMeter()
    private var microphones: [AudioDevice] = []
    private let microphonePopUp = NSPopUpButton()
    private let levelBar = LevelBar()

    private let cameraEnumerator = CameraDeviceEnumerator()
    private var cameras: [CameraDevice] = []
    private let cameraPopUp = NSPopUpButton()
    /// Cámara encendida, con su ventana espejo. Existen desde que se elige una
    /// cámara en la lista, no desde que se graba: así Sebas se encuadra antes de
    /// arrancar.
    private var camera: CameraCapture?
    private var mirror: CameraMirrorWindow?

    private let areaButton = NSButton()
    private let areaLabel = NSTextField(labelWithString: "")
    /// Área personalizada en coordenadas globales. Nil graba la pantalla entera.
    private var customArea: CGRect?

    private let sessionField = NSTextField()
    private let folderLabel = NSTextField(labelWithString: "")
    private let folderButton = NSButton()
    private let countdownCheck = NSButton(checkboxWithTitle: "Cuenta regresiva 3, 2, 1", target: nil, action: nil)

    private let widget = RecordingWidget()

    /// La fila que lista los guiones cargados. Se esconde cuando no hay ninguno.
    private var filaLista: NSStackView!

    /// El teleprompter existe solo mientras dura una grabación: al terminar se
    /// suelta, y con él se van posición, tamaño, velocidad, letra y guion en
    /// vivo. Los valores de arranque salen siempre del panel (decisión 91).
    private var teleprompter: TeleprompterWindow?

    /// El widget se escondió a mano con su atajo. Vuelve solo en la grabación
    /// siguiente: cada toma arranca con el widget a la vista.
    private var widgetEscondido = false

    private let scriptView = NSTextView()
    private let scriptLoadButton = NSButton()
    private let scriptClearButton = NSButton()
    private let scriptListLabel = NSTextField(labelWithString: "")
    /// Velocidad y tamaño de letra de arranque del teleprompter. Se pueden
    /// arrastrar, escribir o mover de a pasos con los botones (decisión 115).
    private var speedRow: NumberRow!
    private var fontRow: NumberRow!

    private let actionButton = BloomindButton(title: "Iniciar grabación")
    private let pauseButton = BloomindButton(title: "Pausar", kind: .ghost)
    private let statusLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "Grabador")
    private let eyebrowLabel = NSTextField(labelWithString: "")

    private var microphoneLabel: NSTextField?

    private var timer: Timer?
    private var startedAt: Date?
    /// Segundos ya grabados antes de la pausa en curso. El cronómetro muestra
    /// tiempo grabado, no tiempo transcurrido: durante la pausa no avanza.
    private var accumulated: TimeInterval = 0

    init() {
        // Sin fullSizeContentView a propósito: con la barra de título transparente
        // sobre el fondo deep ya se ve como una sola pieza, y el contenido no
        // queda debajo de los botones de cerrar.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 400),
            styleMask: [.titled, .closable, .resizable],
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

        widget.onPause = { [weak self] in self?.recorder.togglePause() }
        widget.onStop = { [weak self] in
            self?.actionButton.isEnabled = false
            Task { await self?.recorder.stop() }
        }
        widget.onRestart = { [weak self] in
            Task { await self?.recorder.restartTake() }
        }
        // El atajo pasa por la misma confirmación que el botón del widget.
        recorder.onRestartRequested = { [weak self] in self?.widget.confirmRestart() }
        widget.onToggleBubble = { [weak self] in self?.toggleBubble() }
        widget.onCameraMenu = { [weak self] in self?.cameraMenu() }
        widget.onToggleMicrophone = { [weak self] in self?.recorder.toggleMute(.microphone) }
        widget.onToggleSystemAudio = { [weak self] in self?.recorder.toggleMute(.system) }
        // Los botones del modo expandido van todos por el mismo camino que los
        // atajos, sin lógica propia: `perform(_:)` es el punto único por donde
        // pasa todo lo que se puede hacer con el teclado. La tarjeta es la
        // excepción, porque no vive acá.
        widget.onAction = { [weak self] action in
            guard let self else { return }
            if action == .tarjeta {
                self.onToggleShortcutCard?()
            } else {
                self.recorder.perform(action)
            }
        }
        widget.onTeleprompterControl = { [weak self] control in
            self?.teleprompter?.aplicar(control)
            self?.tick()
        }
        // El atajo ⌥⌘T entra por el mismo lugar que el botón del widget.
        recorder.onTeleprompterRequested = { [weak self] in self?.toggleTeleprompter() }
        recorder.onWidgetRequested = { [weak self] in self?.toggleWidget() }
        levelMeter.onLevel = { [weak self] level in
            self?.levelBar.level = CGFloat(level)
        }
        microphoneEnumerator.onChange = { [weak self] in
            // La lista se refresca sola al conectar o desconectar: AirPods,
            // iPhone por Continuity con el DJI, micrófonos USB.
            self?.loadMicrophones()
        }
        cameraEnumerator.onChange = { [weak self] in
            self?.loadCameras()
        }
        recorder.onDrawingMirrorChange = { [weak self] visible in
            // Con la capa de anotación, que es transparente, esta ventana se vería
            // a través del lienzo y estorbaría justo donde se está dibujando.
            // Vuelve sola al salir del modo de dibujo.
            if visible { self?.window?.orderOut(nil) } else { self?.showWindow(nil) }
        }
        recorder.onModeChange = { [weak self] mode in
            // En cámara completa la burbuja no se compone (matriz 8.4): el
            // espejo se esconde para que la pantalla diga la verdad.
            self?.mirror?.setVisible(mode != .camara)
            self?.tick()
        }
        Task { await loadDisplays() }
        loadMicrophones()
        loadCameras()
        sizeWindowToFit()
    }

    /// Ajusta la ventana al alto exacto de su contenido y le prohíbe encogerse
    /// por debajo. Se llama cada vez que aparece o desaparece una fila.
    ///
    /// Es la red de seguridad contra el error de agregar un control y no darse
    /// cuenta de que empujó los botones fuera de la vista.
    private func sizeWindowToFit() {
        guard let window, let contentView = window.contentView else { return }

        contentView.layoutSubtreeIfNeeded()
        let fitting = contentView.fittingSize
        guard fitting.height > 0 else { return }

        window.contentMinSize = fitting
        if window.contentView!.frame.height < fitting.height {
            window.setContentSize(fitting)
        }
    }

    deinit {
        levelMeter.stop()
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

        let audioModeLabel = NSTextField(labelWithString: "Audio")
        audioModeLabel.font = BloomindStyle.ui(12)
        audioModeLabel.textColor = BloomindStyle.muted

        audioModePopUp.font = BloomindStyle.ui(13)
        audioModePopUp.target = self
        audioModePopUp.action = #selector(audioModeChanged)
        for mode in AudioMode.available { audioModePopUp.addItem(withTitle: mode.label) }
        if let saved = ConfigurationStore.shared.current.lastAudioMode,
           let mode = AudioMode(rawValue: saved),
           let index = AudioMode.available.firstIndex(of: mode) {
            audioModePopUp.selectItem(at: index)
        } else {
            audioModePopUp.selectItem(at: AudioMode.available.firstIndex(of: .microphone) ?? 0)
        }

        let microphoneLabel = NSTextField(labelWithString: "Micrófono")
        microphoneLabel.font = BloomindStyle.ui(12)
        microphoneLabel.textColor = BloomindStyle.muted

        microphonePopUp.font = BloomindStyle.ui(13)
        microphonePopUp.target = self
        microphonePopUp.action = #selector(microphoneChanged)
        microphonePopUp.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let cameraLabel = NSTextField(labelWithString: "Cámara")
        cameraLabel.font = BloomindStyle.ui(12)
        cameraLabel.textColor = BloomindStyle.muted

        cameraPopUp.font = BloomindStyle.ui(13)
        cameraPopUp.target = self
        cameraPopUp.action = #selector(cameraChanged)
        cameraPopUp.setContentHuggingPriority(.defaultLow, for: .horizontal)

        areaButton.bezelStyle = .rounded
        areaButton.font = BloomindStyle.ui(12)
        areaButton.target = self
        areaButton.action = #selector(chooseArea)

        areaLabel.font = BloomindStyle.mono(11)
        areaLabel.textColor = BloomindStyle.muted

        if let guardada = ConfigurationStore.shared.current.customArea {
            customArea = CGRect(x: guardada.x, y: guardada.y, width: guardada.width, height: guardada.height)
        }
        refreshAreaLabels()

        let scriptLabel = NSTextField(labelWithString: "Guion del teleprompter")
        scriptLabel.font = BloomindStyle.ui(12)
        scriptLabel.textColor = BloomindStyle.muted

        scriptLoadButton.title = "Cargar archivos…"
        scriptLoadButton.bezelStyle = .rounded
        scriptLoadButton.font = BloomindStyle.ui(12)
        scriptLoadButton.toolTip = "Traer uno o varios guiones de Word, texto o RTF"
        scriptLoadButton.target = self
        scriptLoadButton.action = #selector(cargarGuionDesdeArchivo)

        scriptClearButton.title = "Quitar"
        scriptClearButton.bezelStyle = .rounded
        scriptClearButton.font = BloomindStyle.ui(12)
        scriptClearButton.toolTip = "Sacar todos los guiones cargados de archivos"
        scriptClearButton.target = self
        scriptClearButton.action = #selector(quitarGuionesCargados)

        scriptListLabel.font = BloomindStyle.ui(11)
        scriptListLabel.textColor = BloomindStyle.muted
        scriptListLabel.lineBreakMode = .byTruncatingTail

        let espaciadorGuion = NSView()
        espaciadorGuion.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let filaGuion = NSStackView(views: [scriptLabel, espaciadorGuion, scriptLoadButton])
        filaGuion.orientation = .horizontal
        filaGuion.alignment = .centerY
        filaGuion.spacing = BloomindStyle.Space.tight

        let espaciadorLista = NSView()
        espaciadorLista.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let filaLista = NSStackView(views: [scriptListLabel, espaciadorLista, scriptClearButton])
        filaLista.orientation = .horizontal
        filaLista.alignment = .centerY
        filaLista.spacing = BloomindStyle.Space.tight
        self.filaLista = filaLista
        refrescarListaDeGuiones()

        scriptView.string = ConfigurationStore.shared.current.teleprompterScript ?? ""
        scriptView.font = BloomindStyle.ui(12)
        scriptView.textColor = BloomindStyle.ink
        scriptView.backgroundColor = BloomindStyle.deep
        scriptView.isRichText = false
        scriptView.isVerticallyResizable = true
        scriptView.autoresizingMask = [.width]
        scriptView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        scriptView.textContainer?.widthTracksTextView = true
        scriptView.delegate = self

        let scriptScroll = NSScrollView()
        scriptScroll.documentView = scriptView
        scriptScroll.hasVerticalScroller = true
        scriptScroll.borderType = .lineBorder
        scriptScroll.drawsBackground = true
        scriptScroll.backgroundColor = BloomindStyle.deep
        scriptScroll.translatesAutoresizingMaskIntoConstraints = false
        scriptScroll.heightAnchor.constraint(equalToConstant: 88).isActive = true

        speedRow = NumberRow(titulo: "Velocidad",
                             minimo: TeleprompterEngine.velocidadMinima,
                             maximo: TeleprompterEngine.velocidadMaxima,
                             paso: 0.5, decimales: 1,
                             valor: ConfigurationStore.shared.current.teleprompterSpeed)
        speedRow.onChange = { valor in
            ConfigurationStore.shared.update { $0.teleprompterSpeed = valor }
        }

        fontRow = NumberRow(titulo: "Tamaño de letra",
                            minimo: TeleprompterEngine.letraMinima,
                            maximo: TeleprompterEngine.letraMaxima,
                            paso: 4, decimales: 0,
                            valor: ConfigurationStore.shared.current.teleprompterFontSize)
        fontRow.onChange = { valor in
            ConfigurationStore.shared.update { $0.teleprompterFontSize = valor }
        }

        let sessionLabel = NSTextField(labelWithString: "Nombre de la sesión")
        sessionLabel.font = BloomindStyle.ui(12)
        sessionLabel.textColor = BloomindStyle.muted

        sessionField.font = BloomindStyle.ui(13)
        sessionField.placeholderString = "Clase de n8n"
        sessionField.stringValue = ConfigurationStore.shared.current.lastSessionName ?? ""
        sessionField.bezelStyle = .roundedBezel

        let folderTitle = NSTextField(labelWithString: "Carpeta de salida")
        folderTitle.font = BloomindStyle.ui(12)
        folderTitle.textColor = BloomindStyle.muted

        folderLabel.font = BloomindStyle.mono(11)
        folderLabel.textColor = BloomindStyle.sky
        folderLabel.lineBreakMode = .byTruncatingHead
        folderLabel.stringValue = ConfigurationStore.shared.current.outputFolder

        folderButton.title = "Cambiar…"
        folderButton.bezelStyle = .rounded
        folderButton.font = BloomindStyle.ui(12)
        folderButton.target = self
        folderButton.action = #selector(chooseFolder)

        countdownCheck.font = BloomindStyle.ui(12)
        countdownCheck.contentTintColor = BloomindStyle.ink
        countdownCheck.state = ConfigurationStore.shared.current.countdownEnabled ? .on : .off
        countdownCheck.target = self
        countdownCheck.action = #selector(countdownChanged)

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

        let cardStack = NSStackView(views: [
            displayLabel, displayPopUp, areaButton, areaLabel,
            audioModeLabel, audioModePopUp,
            microphoneLabel, microphonePopUp, levelBar,
            cameraLabel, cameraPopUp,
            filaGuion, scriptScroll, filaLista, speedRow, fontRow,
            sessionLabel, sessionField,
            folderTitle, folderLabel, folderButton,
            countdownCheck
        ])
        cardStack.orientation = .vertical
        cardStack.alignment = .leading
        cardStack.spacing = BloomindStyle.Space.tight
        cardStack.setCustomSpacing(BloomindStyle.Space.normal, after: areaLabel)
        cardStack.setCustomSpacing(BloomindStyle.Space.normal, after: audioModePopUp)
        cardStack.setCustomSpacing(BloomindStyle.Space.normal, after: levelBar)
        cardStack.setCustomSpacing(BloomindStyle.Space.normal, after: cameraPopUp)
        cardStack.setCustomSpacing(BloomindStyle.Space.normal, after: fontRow)
        cardStack.setCustomSpacing(BloomindStyle.Space.normal, after: sessionField)
        cardStack.setCustomSpacing(BloomindStyle.Space.normal, after: folderButton)
        self.microphoneLabel = microphoneLabel
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: BloomindStyle.Space.normal),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -BloomindStyle.Space.normal),
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: BloomindStyle.Space.normal),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -BloomindStyle.Space.normal),
            displayPopUp.widthAnchor.constraint(equalTo: cardStack.widthAnchor),
            audioModePopUp.widthAnchor.constraint(equalTo: cardStack.widthAnchor),
            microphonePopUp.widthAnchor.constraint(equalTo: cardStack.widthAnchor),
            levelBar.widthAnchor.constraint(equalTo: cardStack.widthAnchor),
            cameraPopUp.widthAnchor.constraint(equalTo: cardStack.widthAnchor),
            filaGuion.widthAnchor.constraint(equalTo: cardStack.widthAnchor),
            filaLista.widthAnchor.constraint(equalTo: cardStack.widthAnchor),
            scriptScroll.widthAnchor.constraint(equalTo: cardStack.widthAnchor),
            speedRow.widthAnchor.constraint(equalTo: cardStack.widthAnchor),
            fontRow.widthAnchor.constraint(equalTo: cardStack.widthAnchor),
            sessionField.widthAnchor.constraint(equalTo: cardStack.widthAnchor),
            folderLabel.widthAnchor.constraint(equalTo: cardStack.widthAnchor)
        ])

        let header = NSStackView(views: [eyebrowLabel, titleLabel])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2

        pauseButton.target = self
        pauseButton.action = #selector(togglePause)
        pauseButton.isHidden = true

        let buttons = NSStackView(views: [actionButton, pauseButton])
        buttons.orientation = .horizontal
        buttons.spacing = BloomindStyle.Space.tight
        buttons.distribution = .fillEqually

        let stack = NSStackView(views: [header, card, buttons, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = BloomindStyle.Space.loose
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: BloomindStyle.Space.card),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -BloomindStyle.Space.card),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: BloomindStyle.Space.card),
            // El borde de abajo también, para que la ventana **se mida sola** por
            // su contenido. Sin esto el alto queda clavado en el que se le puso
            // al crearla, y cada fila nueva empuja los botones fuera de la vista:
            // fue exactamente lo que pasó al agregar el selector de cámara.
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -BloomindStyle.Space.card),
            card.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor)
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

    @objc private func togglePause() {
        recorder.togglePause()
    }

    /// Lo llama el atajo global de iniciar/detener.
    func toggleRecordingFromShortcut() {
        toggleRecording()
    }

    @objc private func toggleRecording() {
        if recorder.isRecording {
            actionButton.isEnabled = false
            Task { await recorder.stop() }
        } else {
            guard displays.indices.contains(displayPopUp.indexOfSelectedItem) else { return }
            let display = displays[displayPopUp.indexOfSelectedItem]
            let audioMode = selectedAudioMode()
            let microphone = audioMode.capturesMicrophone ? selectedMicrophone() : nil

            let sessionName = sessionField.stringValue
            ConfigurationStore.shared.update {
                $0.lastDisplayID = display.scDisplay.displayID
                $0.lastAudioMode = audioMode.rawValue
                $0.lastMicrophoneID = microphone?.uniqueID
                $0.lastCameraID = camera?.device.uniqueID
                $0.lastSessionName = sessionName
                $0.teleprompterScript = self.scriptView.string
                $0.teleprompterSpeed = self.speedRow.value
                $0.teleprompterFontSize = self.fontRow.value
            }

            guard checkDiskBeforeStarting() else {
                actionButton.isEnabled = true
                return
            }

            // El medidor suelta el micrófono antes de que lo tome la captura.
            levelMeter.stop()
            levelBar.level = 0

            actionButton.isEnabled = false
            let arrancar = { [weak self] in
                guard let self else { return }
                Task {
                    await self.recorder.start(display: display, audioMode: audioMode,
                                              microphoneID: microphone?.uniqueID,
                                              camera: self.camera, sessionName: sessionName,
                                              area: self.customArea)
                }
            }

            // El archivo empieza después del conteo, así que el 3, 2, 1 no sale
            // en el video (plan, 8.9).
            if countdownCheck.state == .on {
                CountdownWindow.present(alTerminar: arrancar)
            } else {
                arrancar()
            }
        }
    }

    // MARK: - Teleprompter

    /// Trae el guion de un archivo: Word, texto plano, Markdown, RTF o
    /// OpenDocument (decisión 118).
    ///
    /// Un documento de Google Docs no se puede leer directo —eso pediría red y
    /// una cuenta, y la app no toca la red (decisión 14)—, así que el camino es
    /// bajarlo con Archivo → Descargar → Word (.docx) y cargar ese archivo. Lo
    /// dice el propio cuadro de elegir archivo, que es donde hace falta saberlo.
    @objc private func cargarGuionDesdeArchivo() {
        let panel = NSOpenPanel()
        panel.message = "Elegí uno o varios archivos con guiones. Un Google Docs se baja primero con Archivo → Descargar → Word (.docx)."
        panel.prompt = "Cargar"
        // Varios de una: en una clase suele haber intro, desarrollo y cierre en
        // archivos separados, y se elige entre ellos desde el teleprompter
        // (decisión 121).
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = ScriptFile.tiposSoportados

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        var cargados: [StoredScript] = ConfigurationStore.shared.current.teleprompterScripts
        var fallados: [String] = []

        for url in panel.urls {
            guard let texto = ScriptFile.texto(de: url) else {
                fallados.append(url.lastPathComponent)
                Logger.shared.log("ERROR: no se pudo leer el guion de \(url.lastPathComponent)")
                continue
            }
            let nombre = url.deletingPathExtension().lastPathComponent
            // Cargar dos veces el mismo archivo lo reemplaza en su lugar, en vez
            // de dejar dos pestañas con el mismo nombre.
            if let yaEstaba = cargados.firstIndex(where: { $0.nombre == nombre }) {
                cargados[yaEstaba].texto = texto
            } else {
                cargados.append(StoredScript(nombre: nombre, texto: texto))
            }
            Logger.shared.log("Guion cargado de \(url.lastPathComponent): \(texto.count) caracteres")
        }

        ConfigurationStore.shared.update { $0.teleprompterScripts = cargados }
        refrescarListaDeGuiones()

        guard !fallados.isEmpty else { return }
        let alerta = NSAlert()
        alerta.messageText = fallados.count == 1 ? "No se pudo leer ese archivo" : "No se pudieron leer algunos archivos"
        alerta.informativeText = fallados.joined(separator: ", ")
            + "\n\nSi es un Google Docs, bajalo con Archivo → Descargar → Word (.docx). Si es un PDF o una imagen escaneada, copiá el texto a mano: de ahí no se puede sacar."
        alerta.alertStyle = .warning
        alerta.runModal()
    }

    @objc private func quitarGuionesCargados() {
        ConfigurationStore.shared.update { $0.teleprompterScripts = [] }
        refrescarListaDeGuiones()
        Logger.shared.log("Guiones cargados: lista vaciada")
    }

    /// La línea que dice qué guiones hay cargados. Sin ninguno, la fila entera
    /// desaparece: no hay nada que contar.
    private func refrescarListaDeGuiones() {
        let guiones = ConfigurationStore.shared.current.teleprompterScripts
        filaLista.isHidden = guiones.isEmpty
        guard !guiones.isEmpty else { return }
        let nombres = guiones.map(\.nombre).joined(separator: " · ")
        scriptListLabel.stringValue = guiones.count == 1
            ? "1 guion cargado: \(nombres)"
            : "\(guiones.count) guiones cargados: \(nombres)"
    }

    /// Todo lo que el teleprompter puede mostrar: lo escrito a mano en el panel,
    /// si hay algo, y después cada archivo cargado.
    private func guionesParaElTeleprompter() -> [(nombre: String, texto: String)] {
        var lista: [(nombre: String, texto: String)] = []
        let escrito = scriptView.string
        if !escrito.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lista.append((nombre: "Escrito", texto: escrito))
        }
        lista += ConfigurationStore.shared.current.teleprompterScripts.map {
            (nombre: $0.nombre, texto: $0.texto)
        }
        return lista
    }

    /// El guion se guarda al salir del cuadro, no en cada tecla: es un texto
    /// largo y escribirlo entero en disco cincuenta veces por renglón no tiene
    /// sentido. Guardarlo solo al arrancar la grabación tampoco: el que escribe
    /// el guion y cierra la app sin grabar lo perdería.
    func textDidEndEditing(_ notification: Notification) {
        guard (notification.object as? NSTextView) === scriptView else { return }
        ConfigurationStore.shared.update { $0.teleprompterScript = scriptView.string }
    }

    /// Prende y apaga el teleprompter. La ventana se crea la primera vez que se
    /// prende en esta grabación y se conserva apagada y prendida, con lo que se
    /// haya movido y ajustado; se suelta al terminar la grabación.
    private func toggleTeleprompter() {
        guard recorder.isRecording else {
            // Queda escrito que la orden llegó y no hizo nada: sin esto, "el
            // teleprompter no sale" y "el atajo no llega" se ven igual desde
            // afuera.
            Logger.shared.log("Teleprompter: se pidió prenderlo sin grabación en curso")
            return
        }

        if let teleprompter {
            if teleprompter.isVisible {
                teleprompter.setVisible(false)
            } else {
                teleprompter.setVisible(true)
            }
            tick()
            return
        }

        let pantalla = recorder.recordingScreenFrame()
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let ventana = TeleprompterWindow(guiones: guionesParaElTeleprompter(),
                                         velocidad: speedRow.value,
                                         tamañoLetra: fontRow.value,
                                         pantalla: pantalla)
        ventana.onChange = { [weak self] in self?.tick() }
        // El teclado no puede ser de los dos a la vez: al pasar el foco al
        // teleprompter, el cuadro de texto abierto en el dibujo se cierra
        // (decisión 95).
        ventana.onFocus = { [weak self] in self?.recorder.closeDrawingTextBox() }
        // La combinación que lo esconde, escrita en su propia barra: nadie
        // debería tener que acordarse de un atajo que se usa dos veces por clase.
        ventana.atajoParaEsconder = recorder.etiquetaDeAtajo(.teleprompter)
        teleprompter = ventana
        ventana.setVisible(true)
        Logger.shared.log("Teleprompter abierto: \(ventana.guion.count) caracteres de guion, velocidad \(ventana.velocidad), letra \(Int(ventana.tamañoLetra))")
        tick()
    }

    /// Esconde y muestra el widget con su atajo (decisión 120).
    ///
    /// La decisión de esconderlo se respeta hasta que se vuelva a pedir: sin la
    /// bandera, el primer cambio de estado de la grabación lo haría reaparecer,
    /// porque `refresh()` lo muestra cada vez que algo cambia.
    private func toggleWidget() {
        guard recorder.isRecording else {
            Logger.shared.log("Widget: se pidió esconderlo sin grabación en curso")
            return
        }
        widgetEscondido.toggle()
        if widgetEscondido { widget.hide() } else { widget.present() }
        Logger.shared.log("Widget \(widgetEscondido ? "escondido" : "a la vista")")
    }

    /// Si hay guion cargado en el panel, el teleprompter aparece **solo** al
    /// arrancar la grabación (decisión 116). Con el campo vacío no aparece: no
    /// hay nada que leer.
    ///
    /// Una sola vez por grabación: si después se apaga con su atajo, la ventana
    /// sigue existiendo escondida y no vuelve a asomarse sola.
    private func abrirTeleprompterSiHayGuion() {
        guard teleprompter == nil else { return }
        guard !guionesParaElTeleprompter().isEmpty else {
            Logger.shared.log("Teleprompter: no arranca solo porque no hay ningún guion cargado")
            return
        }
        toggleTeleprompter()
    }

    /// Al terminar la grabación el teleprompter se va entero: la toma siguiente
    /// arranca con lo que diga el panel, no con el guion de la anterior
    /// (decisión 91).
    private func releaseTeleprompter() {
        guard let teleprompter else { return }
        teleprompter.setVisible(false)
        teleprompter.close()
        self.teleprompter = nil
        Logger.shared.log("Teleprompter cerrado y reiniciado")
    }

    // MARK: - Panel

    /// Define o borra el área personalizada. El selector es el mismo que usa la
    /// censura (pieza compartida, plan sección 6).
    @objc private func chooseArea() {
        if customArea != nil {
            customArea = nil
            ConfigurationStore.shared.update { $0.customArea = nil }
            refreshAreaLabels()
            return
        }

        guard displays.indices.contains(displayPopUp.indexOfSelectedItem) else { return }
        let display = displays[displayPopUp.indexOfSelectedItem]
        let frame = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
                == display.scDisplay.displayID
        }?.frame ?? NSScreen.main?.frame ?? .zero

        RectangleSelector.present(on: frame, titulo: "Elegí el área a grabar") { [weak self] rect in
            Task { @MainActor in
                guard let self, let rect else { return }
                self.customArea = rect
                ConfigurationStore.shared.update {
                    $0.customArea = StoredRect(x: rect.minX, y: rect.minY,
                                               width: rect.width, height: rect.height)
                }
                self.refreshAreaLabels()
            }
        }
    }

    private func refreshAreaLabels() {
        if let area = customArea {
            areaButton.title = "Grabar pantalla entera"
            areaLabel.stringValue = "Área: \(Int(area.width)) × \(Int(area.height))"
        } else {
            areaButton.title = "Elegir un área…"
            areaLabel.stringValue = "Se graba la pantalla entera"
        }
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Usar esta carpeta"
        panel.directoryURL = URL(fileURLWithPath: ConfigurationStore.shared.current.outputFolder)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        ConfigurationStore.shared.update { $0.outputFolder = url.path }
        folderLabel.stringValue = url.path
        Logger.shared.log("Carpeta de salida cambiada")
    }

    @objc private func countdownChanged() {
        let activo = countdownCheck.state == .on
        ConfigurationStore.shared.update { $0.countdownEnabled = activo }
    }

    /// Aviso de espacio antes de arrancar (plan, 8.9). Con poco espacio se avisa
    /// pero se deja grabar: la decisión es de Sebas, no de la app.
    private func checkDiskBeforeStarting() -> Bool {
        let carpeta = URL(fileURLWithPath: ConfigurationStore.shared.current.outputFolder)
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)

        guard let libre = DiskMonitor.libre(en: carpeta), libre < DiskMonitor.umbralInicio else { return true }

        Logger.shared.log("AVISO antes de arrancar: quedan \(DiskMonitor.gigas(libre)) libres")
        let alerta = NSAlert()
        alerta.messageText = "Queda poco espacio en el disco"
        alerta.informativeText = "Hay \(DiskMonitor.gigas(libre)) libres. Una clase de una hora ocupa cerca de 2 GB.\n\nSi el disco se llena a mitad, la app detiene la grabación sola para no perder lo grabado."
        alerta.addButton(withTitle: "Grabar igual")
        alerta.addButton(withTitle: "Cancelar")
        alerta.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        return alerta.runModal() == .alertFirstButtonReturn
    }

    private func selectedAudioMode() -> AudioMode {
        let index = audioModePopUp.indexOfSelectedItem
        return AudioMode.available.indices.contains(index) ? AudioMode.available[index] : .none
    }

    private func selectedMicrophone() -> AudioDevice? {
        let index = microphonePopUp.indexOfSelectedItem
        return microphones.indices.contains(index) ? microphones[index] : nil
    }

    /// El selector de micrófono y su medidor solo tienen sentido si el modo usa
    /// micrófono. Con audio del sistema o sin audio, se apagan.
    @objc private func audioModeChanged() {
        let usesMicrophone = selectedAudioMode().capturesMicrophone
        microphoneLabel?.isHidden = !usesMicrophone
        microphonePopUp.isHidden = !usesMicrophone
        levelBar.isHidden = !usesMicrophone
        sizeWindowToFit()
        microphoneChanged()
    }

    private func loadMicrophones() {
        let previous = selectedMicrophone()?.uniqueID ?? ConfigurationStore.shared.current.lastMicrophoneID

        microphones = AudioDeviceEnumerator.available()
        microphonePopUp.removeAllItems()
        for microphone in microphones {
            microphonePopUp.addItem(withTitle: microphone.name)
        }

        // Memoria pegajosa: vuelve al último micrófono usado si sigue conectado.
        if let previous, let index = microphones.firstIndex(where: { $0.uniqueID == previous }) {
            microphonePopUp.selectItem(at: index)
        }

        Logger.shared.log("Micrófonos detectados: \(microphones.count)")
        if !recorder.isRecording { audioModeChanged() }
    }

    /// La lista arranca con "Sin cámara": grabar solo la pantalla es un caso
    /// legítimo y frecuente, no una falla.
    private func loadCameras() {
        let previous = selectedCamera()?.uniqueID ?? ConfigurationStore.shared.current.lastCameraID

        cameras = CameraDeviceEnumerator.available()
        cameraPopUp.removeAllItems()
        cameraPopUp.addItem(withTitle: "Sin cámara")
        for camera in cameras {
            cameraPopUp.addItem(withTitle: camera.name)
        }

        // Memoria pegajosa: vuelve a la última cámara usada si sigue conectada.
        if let previous, let index = cameras.firstIndex(where: { $0.uniqueID == previous }) {
            cameraPopUp.selectItem(at: index + 1)
        }

        Logger.shared.log("Cámaras detectadas: \(cameras.count)")

        // Si lo que quedó seleccionado no es lo que está encendido, se reconcilia:
        // cubre tanto "se conectó la cámara que se venía usando" como "la que
        // estaba prendida se desconectó y hay que soltarla".
        if !recorder.isRecording, selectedCamera()?.uniqueID != camera?.device.uniqueID {
            cameraChanged()
        }
    }

    /// El índice 0 es "Sin cámara"; de ahí en adelante van los dispositivos.
    private func selectedCamera() -> CameraDevice? {
        let index = cameraPopUp.indexOfSelectedItem - 1
        return cameras.indices.contains(index) ? cameras[index] : nil
    }

    /// Enciende o apaga la cámara y su ventana espejo. Pasa apenas se elige en la
    /// lista, sin esperar a grabar: así se encuadra antes de arrancar.
    @objc private func cameraChanged() {
        // Al **cambiar** de cámara no se le avisa al grabador del cierre: sería
        // un "te quedaste sin cámara" falso, y en modo cámara completa lo haría
        // saltar a modo pantalla en el medio del cambio (decisión 83).
        let vaAQuedarSinCamara = selectedCamera() == nil
        closeCamera(avisandoAlGrabador: vaAQuedarSinCamara)

        guard let device = selectedCamera() else {
            ConfigurationStore.shared.update { $0.lastCameraID = nil }
            return
        }

        Task {
            guard await CameraDeviceEnumerator.requestPermission() else {
                showCameraPermissionAlert()
                cameraPopUp.selectItem(at: 0)
                if recorder.isRecording { recorder.setCamera(nil) }
                return
            }

            guard let capture = CameraCapture(device: device) else {
                statusLabel.stringValue = "No se pudo abrir la cámara"
                statusLabel.textColor = BloomindStyle.signal
                cameraPopUp.selectItem(at: 0)
                // Acá sí se avisa: el cambio falló y quedamos sin ninguna.
                if recorder.isRecording { recorder.setCamera(nil) }
                return
            }

            capture.onInterruption = { [weak self] in
                self?.recorder.reportCameraInterruption(device.name)
            }
            capture.start()
            camera = capture

            let mirror = CameraMirrorWindow(previewLayer: capture.makePreviewLayer(),
                                            aspectRatio: capture.aspectRatio)
            mirror.onFrameChange = { [weak self] rect in
                self?.recorder.setBubbleFrame(rect)
            }
            mirror.setVisible(true)
            self.mirror = mirror

            // Con la grabación corriendo hay que avisarle al pipeline, que es
            // quien compone la burbuja en cada frame.
            if recorder.isRecording { recorder.setCamera(capture) }

            ConfigurationStore.shared.update { $0.lastCameraID = device.uniqueID }
        }
    }

    /// Prende y apaga la burbuja desde el widget, sin soltar la cámara: apagarla
    /// y volver a prenderla en mitad de una clase tiene que ser instantáneo.
    private func toggleBubble() {
        guard let mirror else { return }
        let visible = mirror.isVisible
        mirror.setVisible(!visible)
        recorder.setBubbleFrame(visible ? nil : mirror.frame)
    }

    /// El menú del botón de cámara del widget: apagar la que está prendida y
    /// elegir cualquiera de las disponibles, también con la grabación corriendo
    /// y aunque se haya arrancado sin ninguna (decisión 82).
    private func cameraMenu() -> NSMenu {
        loadCameras()
        let menu = NSMenu()
        let activa = camera?.device.uniqueID

        if camera != nil {
            let apagar = NSMenuItem(title: "Apagar cámara", action: #selector(elegirCamaraDelWidget(_:)), keyEquivalent: "")
            apagar.target = self
            apagar.tag = -1
            menu.addItem(apagar)
            menu.addItem(.separator())
        }

        if cameras.isEmpty {
            let vacio = NSMenuItem(title: "No hay cámaras disponibles", action: nil, keyEquivalent: "")
            vacio.isEnabled = false
            menu.addItem(vacio)
        }

        for (indice, dispositivo) in cameras.enumerated() {
            let item = NSMenuItem(title: dispositivo.name, action: #selector(elegirCamaraDelWidget(_:)), keyEquivalent: "")
            item.target = self
            item.tag = indice
            item.state = dispositivo.uniqueID == activa ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    @objc private func elegirCamaraDelWidget(_ sender: NSMenuItem) {
        // El popup del panel y el menú del widget eligen lo mismo, así que se
        // mantienen sincronizados: uno solo manda, y es la lista de cámaras.
        cameraPopUp.selectItem(at: sender.tag + 1)
        cameraChanged()
    }

    private func closeCamera(avisandoAlGrabador: Bool = true) {
        mirror?.setVisible(false)
        mirror = nil
        camera?.stop()
        camera = nil
        if avisandoAlGrabador, recorder.isRecording { recorder.setCamera(nil) }
        recorder.setBubbleFrame(nil)
    }

    private func showCameraPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Falta el permiso de cámara"
        alert.informativeText = "Para usar la burbuja, activá el Grabador Bloomind en Configuración del Sistema, Privacidad y seguridad, Cámara."
        alert.addButton(withTitle: "Abrir Configuración del Sistema")
        alert.addButton(withTitle: "Seguir sin cámara")
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func microphoneChanged() {
        levelBar.level = 0
        guard selectedAudioMode().capturesMicrophone, let microphone = selectedMicrophone() else {
            levelMeter.stop()
            return
        }
        // El permiso se pide acá y no al grabar: sin él la barra no se movería y
        // el medidor perdería justamente la función que tiene, que es avisarte
        // antes de arrancar.
        Task {
            guard await AudioDeviceEnumerator.requestPermission() else {
                levelMeter.stop()
                statusLabel.stringValue = "Falta el permiso de micrófono"
                statusLabel.textColor = BloomindStyle.signal
                return
            }
            levelMeter.start(deviceID: microphone.uniqueID)
        }
    }

    private func refresh() {
        actionButton.isEnabled = true
        displayPopUp.isEnabled = !recorder.isRecording
        audioModePopUp.isEnabled = !recorder.isRecording
        microphonePopUp.isEnabled = !recorder.isRecording
        cameraPopUp.isEnabled = !recorder.isRecording
        areaButton.isEnabled = !recorder.isRecording
        sessionField.isEnabled = !recorder.isRecording
        scriptView.isEditable = !recorder.isRecording
        scriptLoadButton.isEnabled = !recorder.isRecording
        scriptClearButton.isEnabled = !recorder.isRecording
        speedRow.setEnabled(!recorder.isRecording)
        fontRow.setEnabled(!recorder.isRecording)
        folderButton.isEnabled = !recorder.isRecording
        // Durante la grabación el micrófono lo tiene la captura, así que el
        // medidor no puede leerlo: la barra se queda quieta a propósito.
        if !recorder.isRecording { audioModeChanged() }
        statusLabel.textColor = BloomindStyle.muted

        pauseButton.isHidden = !recorder.isRecording
        pauseButton.title = recorder.isPaused ? "Reanudar" : "Pausar"

        if recorder.isRecording {
            if !widgetEscondido { widget.present() }
            // El panel se va del medio: el widget es lo que se usa en vivo.
            window?.orderOut(nil)
            abrirTeleprompterSiHayGuion()
        } else {
            widget.hide()
            widgetEscondido = false
            releaseTeleprompter()
        }
        onRecordingStateChange?(recorder.isRecording, recorder.isPaused)

        if recorder.isRecording {
            actionButton.title = "Detener"

            if recorder.isPaused {
                // Congelar el cronómetro: lo corrido hasta acá se guarda y no
                // sigue sumando mientras dure la pausa.
                if let startedAt { accumulated += Date().timeIntervalSince(startedAt) }
                startedAt = nil
            } else if startedAt == nil {
                startedAt = Date()
            }

            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.tick() }
                }
            }
            tick()
        } else {
            actionButton.title = "Iniciar grabación"
            timer?.invalidate()
            timer = nil
            startedAt = nil
            accumulated = 0
            statusLabel.stringValue = "Listo"
        }
    }

    private func tick() {
        let running = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        let seconds = Int(accumulated + running)

        widget.update(segundos: seconds,
                      pausado: recorder.isPaused,
                      modo: recorder.mode,
                      censura: recorder.isRedacting,
                      anotando: recorder.isAnnotationOn,
                      color: recorder.markerColor,
                      hayCamara: camera != nil,
                      resaltadoCursor: recorder.isCursorHighlightOn,
                      teleprompter: RecordingWidget.TeleprompterState(
                          visible: teleprompter?.isVisible ?? false,
                          corriendo: teleprompter?.corriendo ?? false,
                          editando: teleprompter?.editando ?? false),
                      audio: RecordingWidget.AudioState(
                          capturaMicrofono: recorder.capturesSource(.microphone),
                          capturaSistema: recorder.capturesSource(.system),
                          microfonoSilenciado: recorder.isMuted(.microphone),
                          sistemaSilenciado: recorder.isMuted(.system)))
        var texto = String(format: "%02d:%02d", seconds / 60, seconds % 60)
        // El modo activo y el color del marcador van en el mismo renglón: son la
        // única señal de en qué estado está hasta que llegue el widget (Fase 11).
        switch recorder.mode {
        case .pantalla: if camera != nil { texto += "   Pantalla" }
        case .camara:   texto += "   Cámara completa"
        case .tablero:  texto += "   Tablero \(recorder.boardColor.label) · marcador \(recorder.markerColor.label)"
        }
        if recorder.isAnnotationOn, recorder.mode == .pantalla {
            texto += "   Anotando · marcador \(recorder.markerColor.label)"
        }
        // Indicador de censura activa (plan, 8.6): saber sin adivinar si la zona
        // está tapada. El widget definitivo llega en la Fase 11.
        if recorder.isRedacting {
            texto += "   ▓ Censura activa"
        }

        if recorder.isPaused {
            statusLabel.stringValue = "❚❚ Pausado   \(texto)"
            statusLabel.textColor = BloomindStyle.muted
        } else {
            statusLabel.stringValue = "● Grabando   \(texto)"
            // El turquesa es exclusivo del éxito; grabar en curso va en lab.
            statusLabel.textColor = BloomindStyle.lab
        }
    }
}
