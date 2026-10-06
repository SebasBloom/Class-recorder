import AppKit
import AVFoundation
import UniformTypeIdentifiers

/// El panel de configuración antes de grabar, y dueño del widget durante la
/// grabación.
///
/// Desde la Fase 16 el panel es **una oración** (decisión 128): «Voy a grabar
/// la pantalla entera del Retina, con el micrófono DJI y la cámara FaceTime,
/// leyendo 3 guiones». Cada fragmento azul se toca y abre su menú; el guion
/// abre un globo con el texto, los archivos y los valores de arranque. Abajo,
/// solo lo que no cabe en la frase: la carpeta y la cuenta regresiva.
@MainActor
final class ControlWindow: NSWindowController, NSTextViewDelegate, NSPopoverDelegate {

    let recorder = RecordingController()

    /// Avisa a la barra de menú para que cambie el estado del ícono.
    var onRecordingStateChange: ((Bool, Bool) -> Void)?
    /// Los segundos grabados, una vez por segundo, para el reloj de la barra
    /// de menú.
    var onTiempo: ((Int) -> Void)?
    /// Se tocó «¿Cómo se usa?».
    var onAyuda: (() -> Void)?

    /// Muestra u oculta la tarjeta de atajos desde el botón del widget. La
    /// tarjeta y el registro de atajos viven en la barra de menú, no acá, porque
    /// tienen que existir aunque no haya ninguna grabación en curso.
    var onToggleShortcutCard: (() -> Void)?

    /// Ancho del texto del panel: 640 de ventana menos 44 de margen a cada lado.
    private static let anchoTexto: CGFloat = 552

    // MARK: - Lo elegido

    private var displays: [CaptureDisplay] = []
    private var displayIndex = 0

    private var audioMode: AudioMode = .microphone
    private let microphoneEnumerator = AudioDeviceEnumerator()
    private let levelMeter = AudioLevelMeter()
    private var microphones: [AudioDevice] = []
    private var microphoneID: String?
    /// Se pidió el permiso de micrófono y macOS dijo que no.
    private var microfonoSinPermiso = false

    private let cameraEnumerator = CameraDeviceEnumerator()
    private var cameras: [CameraDevice] = []
    /// La cámara elegida en el panel, aunque todavía se esté abriendo. La que
    /// está encendida de verdad es `camera`.
    private var camaraElegidaID: String?
    /// Cámara encendida, con su ventana espejo. Existen desde que se elige una
    /// cámara, no desde que se graba: así Sebas se encuadra antes de arrancar.
    private var camera: CameraCapture?
    private var mirror: CameraMirrorWindow?

    /// Área personalizada en coordenadas globales. Nil graba la pantalla entera.
    private var customArea: CGRect?

    /// Un problema que no sale del estado (no se pudieron listar las pantallas,
    /// la cámara no abrió). Se muestra en el pie hasta el próximo cambio.
    private var avisoTemporal: String?

    // MARK: - Vistas

    private let sentence = SentenceView(ancho: ControlWindow.anchoTexto)
    private let sessionField = NSTextField()
    private let folderLabel = NSTextField(labelWithString: "")
    private let folderButton = NSButton()
    private let countdownSwitch = NSSwitch()
    private let ayudaButton = NSButton()
    private var filaCarpeta: NSView!
    private var filaCuenta: NSView!

    private let statusDot = NSView()
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let actionButton = BloomindButton(title: "Grabar", kind: .claro)
    private let pauseButton = BloomindButton(title: "Pausar", kind: .claroSecundario)

    private let widget = RecordingWidget()

    /// El globo del guion: el texto escrito a mano, los archivos cargados y los
    /// valores de arranque del teleprompter.
    private let popoverGuion = NSPopover()
    private let scriptView = NSTextView()
    private let scriptLoadButton = NSButton()
    private let scriptClearButton = NSButton()
    private let scriptListLabel = NSTextField(labelWithString: "")
    /// Los guiones cargados, con su casilla para usarlo o no en esta clase
    /// (decisión 131). Se esconde entero cuando no hay ninguno.
    private var filaLista: NSStackView!
    private let listaGuiones = NSStackView()
    /// Velocidad y tamaño de letra de arranque del teleprompter. Se pueden
    /// arrastrar, escribir o mover de a pasos con los botones (decisión 115).
    private var speedRow: NumberRow!
    private var fontRow: NumberRow!
    /// Fondo claro u oscuro del teleprompter (decisión 135).
    private let temaSwitch = NSSwitch()

    /// El teleprompter existe solo mientras dura una grabación: al terminar se
    /// suelta, y con él se van posición, tamaño y guion editado en vivo. La
    /// velocidad y la letra no se pierden: se copian al panel en cuanto cambian
    /// (decisión 132).
    private var teleprompter: TeleprompterWindow?

    /// El widget se escondió a mano con su atajo. Vuelve solo en la grabación
    /// siguiente: cada toma arranca con el widget a la vista.
    private var widgetEscondido = false

    private var timer: Timer?
    private var startedAt: Date?
    /// Segundos ya grabados antes de la pausa en curso. El cronómetro muestra
    /// tiempo grabado, no tiempo transcurrido: durante la pausa no avanza.
    private var accumulated: TimeInterval = 0

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 460),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Grabador Bloomind"
        // Clara siempre, aunque el Mac esté en modo oscuro (decisión 123).
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = BloomindStyle.Claro.blanco
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        super.init(window: window)

        let guardado = ConfigurationStore.shared.current
        if let modo = guardado.lastAudioMode.flatMap(AudioMode.init(rawValue:)) { audioMode = modo }
        if let area = guardado.customArea {
            customArea = CGRect(x: area.x, y: area.y, width: area.width, height: area.height)
        }

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
        // Todo lo del widget va por el mismo camino que los atajos, sin lógica
        // propia: `perform(_:)` es el punto único por donde pasa todo lo que se
        // puede hacer con el teclado. La tarjeta es la excepción, porque no
        // vive acá.
        widget.onAction = { [weak self] action in
            guard let self else { return }
            if action == .tarjeta {
                self.onToggleShortcutCard?()
            } else {
                self.recorder.perform(action)
            }
        }
        widget.etiquetaDeAtajo = { [weak self] accion in self?.recorder.etiquetaDeAtajo(accion) }
        widget.onTeleprompterControl = { [weak self] control in
            self?.teleprompter?.aplicar(control)
            self?.tick()
        }
        // El atajo ⌥⌘T entra por el mismo lugar que el botón del widget.
        recorder.onTeleprompterRequested = { [weak self] in self?.toggleTeleprompter() }
        recorder.onWidgetRequested = { [weak self] in self?.toggleWidget() }
        // El subrayado del micrófono en la oración es el medidor.
        levelMeter.onLevel = { [weak self] level in
            self?.sentence.nivel = CGFloat(level)
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
        // El medidor tiene el micrófono abierto mientras la ventana está a la
        // vista, y esta ventana vive para siempre (`MenuBarController` la
        // guarda), así que su `deinit` nunca llega: sin esto el punto naranja de
        // macOS queda prendido después de cerrarla, hasta que se mate la app.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ventanaCerrada),
                                               name: NSWindow.willCloseNotification,
                                               object: window)

        Task { await loadDisplays() }
        loadMicrophones()
        loadCameras()
        refrescarOracion()
        window.center()
    }

    @objc private func ventanaCerrada() {
        popoverGuion.close()
        levelMeter.stop()
        sentence.nivel = 0
    }

    /// Al volver a mostrarse, el medidor arranca de nuevo con el micrófono
    /// elegido. Durante la grabación no, que ahí el micrófono lo tiene la
    /// captura.
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        if !recorder.isRecording { microphoneChanged() }
    }

    /// La ventana mide exactamente lo que su contenido. Se llama cada vez que la
    /// oración cambia de largo.
    ///
    /// Es la red de seguridad contra el error de agregar algo y no darse
    /// cuenta de que empujó el botón de grabar fuera de la vista, que es
    /// justamente lo que le pasaba al panel viejo en el Air.
    private func sizeWindowToFit() {
        guard let window, let contentView = window.contentView else { return }
        contentView.layoutSubtreeIfNeeded()
        let fitting = contentView.fittingSize
        guard fitting.height > 0, fitting != contentView.frame.size else { return }
        // Crece y se encoge hacia abajo: el título se queda donde estaba.
        let arriba = window.frame.maxY
        window.setContentSize(fitting)
        window.setFrameTopLeftPoint(NSPoint(x: window.frame.minX, y: arriba))
    }

    deinit {
        levelMeter.stop()
    }

    required init?(coder: NSCoder) { fatalError("no se usa") }

    // MARK: - Construcción

    private func buildLayout() {
        guard let contentView = window?.contentView else { return }
        let c = BloomindStyle.Claro.self

        let ceja = NSTextField(labelWithString: "")
        ceja.attributedStringValue = NSAttributedString(string: "GRABADOR BLOOMIND", attributes: [
            .font: BloomindStyle.ui(11, weight: .semibold),
            .kern: 1.5,
            .foregroundColor: c.pizarra
        ])

        // El nombre de la sesión es el título: se escribe directo encima.
        sessionField.font = BloomindStyle.display(30)
        sessionField.textColor = c.tinta
        sessionField.isBordered = false
        sessionField.drawsBackground = false
        sessionField.focusRingType = .none
        sessionField.placeholderAttributedString = NSAttributedString(string: "Nombre de la sesión", attributes: [
            .font: BloomindStyle.display(30), .foregroundColor: c.lineaFuerte
        ])
        sessionField.stringValue = ConfigurationStore.shared.current.lastSessionName ?? ""
        sessionField.toolTip = "El nombre del archivo. Tocalo para cambiarlo."

        sentence.onTap = { [weak self] parte, rect in self?.tocar(parte, en: rect) }

        // La ficha: lo que no cabe en la frase.
        folderLabel.font = BloomindStyle.mono(12)
        folderLabel.textColor = c.tinta
        folderLabel.lineBreakMode = .byTruncatingHead
        mostrarCarpeta(ConfigurationStore.shared.current.outputFolder)
        enlace(folderButton, "Cambiar…", #selector(chooseFolder))

        let explicacionCuenta = NSTextField(labelWithString: "3, 2, 1 antes de arrancar. No sale en el video.")
        explicacionCuenta.font = BloomindStyle.ui(13)
        explicacionCuenta.textColor = c.pizarra
        countdownSwitch.state = ConfigurationStore.shared.current.countdownEnabled ? .on : .off
        countdownSwitch.target = self
        countdownSwitch.action = #selector(countdownChanged)

        filaCarpeta = filaFicha("Se guarda en", folderLabel, folderButton)
        filaCuenta = filaFicha("Cuenta regresiva", explicacionCuenta, countdownSwitch)
        let ficha = NSStackView(views: [linea(), filaCarpeta, linea(), filaCuenta, linea()])
        ficha.orientation = .vertical
        ficha.alignment = .leading
        ficha.spacing = 0
        for fila in ficha.arrangedSubviews {
            fila.widthAnchor.constraint(equalTo: ficha.widthAnchor).isActive = true
        }

        // El pie: cómo está todo, y el botón.
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 4
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        statusDot.heightAnchor.constraint(equalToConstant: 8).isActive = true
        statusLabel.font = BloomindStyle.ui(13)
        statusLabel.textColor = c.pizarra
        statusLabel.stringValue = "Buscando pantallas…"
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        actionButton.target = self
        actionButton.action = #selector(toggleRecording)
        actionButton.heightAnchor.constraint(equalToConstant: 42).isActive = true
        pauseButton.target = self
        pauseButton.action = #selector(togglePause)
        pauseButton.isHidden = true
        pauseButton.heightAnchor.constraint(equalToConstant: 42).isActive = true

        let pie = NSStackView(views: [statusDot, statusLabel, pauseButton, actionButton])
        pie.alignment = .centerY
        pie.distribution = .fill
        pie.spacing = 8
        pie.setCustomSpacing(14, after: statusLabel)
        pie.edgeInsets = NSEdgeInsets(top: 22, left: 0, bottom: 26, right: 0)

        // El tutorial se vuelve a ver desde acá cuando se quiera (decisión 137).
        enlace(ayudaButton, "¿Cómo se usa?", #selector(tocarAyuda))
        let espaciadorCeja = NSView()
        espaciadorCeja.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let cabecera = NSStackView(views: [ceja, espaciadorCeja, ayudaButton])
        cabecera.alignment = .firstBaseline
        cabecera.distribution = .fill

        let stack = NSStackView(views: [cabecera, sessionField, sentence, ficha, pie])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.setCustomSpacing(8, after: cabecera)
        stack.setCustomSpacing(18, after: sessionField)
        stack.setCustomSpacing(26, after: sentence)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 44),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -44),
            // 30 de la barra de título transparente más el aire de la maqueta.
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 44),
            // El borde de abajo también, para que la ventana **se mida sola** por
            // su contenido.
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sessionField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            cabecera.widthAnchor.constraint(equalTo: stack.widthAnchor),
            ficha.widthAnchor.constraint(equalTo: stack.widthAnchor),
            pie.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        construirGlobo()
    }

    @objc private func tocarAyuda() { onAyuda?() }

    // MARK: - Tutorial

    /// Dónde está en la pantalla lo que el tutorial quiere iluminar.
    func marcoEnPantalla(de objetivo: ObjetivoTutorial) -> NSRect? {
        switch objetivo {
        case .titulo:  return sessionField.marcoEnPantalla
        case .carpeta: return filaCarpeta.marcoEnPantalla
        case .cuenta:  return filaCuenta.marcoEnPantalla
        case .grabar:  return actionButton.marcoEnPantalla
        case .estado:
            return [statusDot, statusLabel].compactMap(\.marcoEnPantalla).reduce(nil) { $0?.union($1) ?? $1 }
        case .frase(let parte):
            let fragmento = sentence.marcoEnPantalla(de: parte)
            // Con el globo del guion abierto, se ilumina junto: la burbuja del
            // tutorial no lo puede tapar.
            if parte == .guion, popoverGuion.isShown,
               let globo = popoverGuion.contentViewController?.view.window?.frame {
                return fragmento.map { $0.union(globo) } ?? globo
            }
            return fragmento
        case .teleprompter:
            guard let teleprompter, teleprompter.isVisible else { return nil }
            return teleprompter.frame
        case .barraDeMenu:
            return nil
        default:
            return widget.marcoEnPantalla(de: objetivo)
        }
    }

    /// Deja la pantalla lista para un paso: el panel a la vista antes de
    /// grabar, la cápsula completa mientras se graba.
    func prepararParaTutorial(_ paso: PasoTutorial) {
        if recorder.isRecording {
            if paso.objetivo != .achicar { widget.mostrarCompleto() }
        } else {
            showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Un renglón de la ficha: qué es, el valor y su acción.
    private func filaFicha(_ titulo: String, _ valor: NSView, _ accion: NSView) -> NSView {
        let etiqueta = NSTextField(labelWithString: titulo)
        etiqueta.font = BloomindStyle.ui(13)
        etiqueta.textColor = BloomindStyle.Claro.pizarra
        etiqueta.translatesAutoresizingMaskIntoConstraints = false
        etiqueta.widthAnchor.constraint(equalToConstant: 150).isActive = true
        valor.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valor.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let fila = NSStackView(views: [etiqueta, valor, accion])
        fila.alignment = .centerY
        fila.distribution = .fill
        fila.spacing = 12
        fila.edgeInsets = NSEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        return fila
    }

    private func linea() -> NSView {
        let linea = NSView()
        linea.wantsLayer = true
        linea.layer?.backgroundColor = BloomindStyle.Claro.linea.cgColor
        linea.translatesAutoresizingMaskIntoConstraints = false
        linea.heightAnchor.constraint(equalToConstant: 1).isActive = true
        linea.widthAnchor.constraint(equalToConstant: Self.anchoTexto).isActive = true
        return linea
    }

    /// Un botón con forma de enlace: texto azul, sin caja.
    private func enlace(_ boton: NSButton, _ titulo: String, _ accion: Selector) {
        boton.isBordered = false
        boton.attributedTitle = NSAttributedString(string: titulo, attributes: [
            .font: BloomindStyle.ui(13, weight: .medium),
            .foregroundColor: BloomindStyle.Claro.azul
        ])
        boton.target = self
        boton.action = accion
        boton.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func mostrarCarpeta(_ ruta: String) {
        folderLabel.stringValue = (ruta as NSString).abbreviatingWithTildeInPath
        folderLabel.toolTip = ruta
    }

    /// El globo del guion. Lleva lo que antes era media tarjeta del panel: el
    /// guion escrito a mano, los archivos cargados y los valores de arranque.
    private func construirGlobo() {
        let c = BloomindStyle.Claro.self

        let titulo = NSTextField(labelWithString: "Guiones para el teleprompter")
        titulo.font = BloomindStyle.ui(11, weight: .semibold)
        titulo.textColor = c.pizarra

        let escritoTitulo = NSTextField(labelWithString: "Escrito acá")
        escritoTitulo.font = BloomindStyle.ui(12)
        escritoTitulo.textColor = c.pizarra

        scriptView.string = ConfigurationStore.shared.current.teleprompterScript ?? ""
        scriptView.font = BloomindStyle.ui(12)
        scriptView.textColor = c.tinta
        scriptView.backgroundColor = c.papel
        scriptView.insertionPointColor = c.tinta
        scriptView.isRichText = false
        scriptView.isVerticallyResizable = true
        scriptView.autoresizingMask = [.width]
        scriptView.textContainerInset = NSSize(width: 4, height: 6)
        scriptView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        scriptView.textContainer?.widthTracksTextView = true
        scriptView.delegate = self

        let scriptScroll = NSScrollView()
        scriptScroll.documentView = scriptView
        scriptScroll.hasVerticalScroller = true
        scriptScroll.borderType = .noBorder
        scriptScroll.wantsLayer = true
        scriptScroll.layer?.cornerRadius = 6
        scriptScroll.layer?.borderWidth = 1
        scriptScroll.layer?.borderColor = c.linea.cgColor
        scriptScroll.translatesAutoresizingMaskIntoConstraints = false
        scriptScroll.heightAnchor.constraint(equalToConstant: 110).isActive = true

        enlace(scriptLoadButton, "Cargar archivos…", #selector(cargarGuionDesdeArchivo))
        scriptLoadButton.toolTip = "Traer uno o varios guiones de Word, texto o RTF"
        let formatos = NSTextField(labelWithString: "Word, texto, RTF")
        formatos.font = BloomindStyle.ui(11)
        formatos.textColor = c.pizarra
        let filaCargar = NSStackView(views: [scriptLoadButton, formatos])
        filaCargar.spacing = 8

        scriptListLabel.font = BloomindStyle.ui(12)
        scriptListLabel.textColor = c.pizarra
        enlace(scriptClearButton, "Quitar todos", #selector(quitarGuionesCargados))
        scriptClearButton.toolTip = "Sacar todos los guiones cargados de archivos"
        let espaciador = NSView()
        espaciador.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let encabezado = NSStackView(views: [scriptListLabel, espaciador, scriptClearButton])
        encabezado.alignment = .firstBaseline
        encabezado.distribution = .fill
        listaGuiones.orientation = .vertical
        listaGuiones.alignment = .leading
        listaGuiones.spacing = 4
        let filaLista = NSStackView(views: [encabezado, listaGuiones])
        filaLista.orientation = .vertical
        filaLista.alignment = .leading
        filaLista.spacing = 6
        encabezado.widthAnchor.constraint(equalTo: filaLista.widthAnchor).isActive = true
        self.filaLista = filaLista
        refrescarListaDeGuiones()

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

        let separador = NSBox()
        separador.boxType = .separator

        // El fondo del teleprompter: claro como el resto de la app, u oscuro
        // para cuidar la vista. La explicación va al lado, porque es lo único
        // que hace falta saber para elegir.
        temaSwitch.state = ConfigurationStore.shared.current.teleprompterOscuro ? .on : .off
        temaSwitch.target = self
        temaSwitch.action = #selector(cambiarTemaDelGuion)
        let temaTitulo = NSTextField(labelWithString: "Fondo oscuro")
        temaTitulo.font = BloomindStyle.ui(13)
        temaTitulo.textColor = c.tinta
        let temaExplicacion = NSTextField(wrappingLabelWithString: "Claro va con el resto de la app. Con el fondo blanco, leer una clase larga se puede poner pesado para la vista; el oscuro la cansa menos.")
        temaExplicacion.font = BloomindStyle.ui(11)
        temaExplicacion.textColor = c.pizarra
        let temaTextos = NSStackView(views: [temaTitulo, temaExplicacion])
        temaTextos.orientation = .vertical
        temaTextos.alignment = .leading
        temaTextos.spacing = 2
        temaTextos.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let filaTema = NSStackView(views: [temaTextos, temaSwitch])
        filaTema.alignment = .top
        filaTema.distribution = .fill
        filaTema.spacing = 12

        let separador2 = NSBox()
        separador2.boxType = .separator

        let stack = NSStackView(views: [titulo, escritoTitulo, scriptScroll, filaCargar, filaLista,
                                        separador, speedRow, fontRow, separador2, filaTema])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.setCustomSpacing(12, after: titulo)
        stack.setCustomSpacing(12, after: filaLista)
        stack.setCustomSpacing(12, after: separador)
        stack.setCustomSpacing(12, after: fontRow)
        stack.setCustomSpacing(12, after: separador2)
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 16, right: 16)
        for vista in [scriptScroll, filaLista, separador, speedRow!, fontRow!, separador2, filaTema] as [NSView] {
            vista.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32).isActive = true
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 380).isActive = true

        let contenido = NSViewController()
        contenido.view = stack
        popoverGuion.contentViewController = contenido
        popoverGuion.behavior = .transient
        popoverGuion.appearance = NSAppearance(named: .aqua)
        popoverGuion.delegate = self
    }

    // MARK: - La oración

    /// Vuelve a escribir la frase con lo elegido, y el pie con él.
    private func refrescarOracion() {
        let pantalla = displays.indices.contains(displayIndex) ? displays[displayIndex].name : "Retina"
        let estado = PanelSentence.Estado(
            area: customArea.map { (Int($0.width), Int($0.height)) },
            pantalla: pantalla,
            audio: audioMode,
            microfono: selectedMicrophone()?.name,
            microfonoSinPermiso: microfonoSinPermiso,
            camara: selectedCamera()?.name,
            guiones: guionesParaElTeleprompter().count)
        sentence.mostrar(PanelSentence.armar(estado))
        pintarEstado()
        sizeWindowToFit()
    }

    /// El pie dice cómo está todo antes de grabar, con lo que falta primero, y
    /// el botón dice qué hacer con eso.
    private func pintarEstado() {
        let c = BloomindStyle.Claro.self
        let falta = audioMode.capturesMicrophone && microfonoSinPermiso && !recorder.isRecording

        let texto: String
        let punto: NSColor
        if recorder.isRecording {
            let segundos = Int(accumulated + (startedAt.map { Date().timeIntervalSince($0) } ?? 0))
            let reloj = String(format: "%02d:%02d", segundos / 60, segundos % 60)
            texto = recorder.isPaused ? "En pausa · \(reloj)" : "Grabando · \(reloj)"
            punto = recorder.isPaused ? c.pizarra : c.azul
        } else if let avisoTemporal {
            texto = avisoTemporal; punto = c.coral
        } else if displays.isEmpty {
            texto = "Buscando pantallas…"; punto = c.lineaFuerte
        } else if falta {
            texto = "Sin ese permiso el video sale mudo."; punto = c.coral
        } else if audioMode.capturesMicrophone && selectedMicrophone() == nil {
            texto = "Conectá un micrófono o elegí otra forma de sonido."; punto = c.coral
        } else if audioMode.capturesMicrophone && PanelSentence.esMicrofonoDeTelefono(selectedMicrophone()?.name) {
            texto = "Los AirPods graban con calidad de teléfono."; punto = c.ambar
        } else if !audioMode.hasAudio {
            texto = "El video va a salir sin sonido."; punto = c.ambar
        } else {
            texto = "Todo listo. " + (audioMode.capturesMicrophone ? "El micrófono te está oyendo." : "Se oye el PC.")
            // El turquesa es exclusivo del éxito, y esto es justo eso.
            punto = c.turquesa
        }
        statusLabel.stringValue = texto
        statusDot.layer?.backgroundColor = punto.cgColor

        if recorder.isRecording {
            actionButton.kind = .claro
            actionButton.title = "Detener"
        } else if falta {
            actionButton.kind = .falta
            actionButton.title = "Dar permiso al micrófono"
        } else {
            actionButton.kind = .claro
            let atajo = recorder.etiquetaDeAtajo(.iniciarDetener) ?? ShortcutAction.iniciarDetener.porDefecto.etiqueta
            actionButton.title = "Grabar   \(atajo)"
        }
    }

    /// Se tocó un fragmento de la oración: abre su menú debajo de él.
    private func tocar(_ parte: PanelSentence.Parte, en rect: NSRect) {
        avisoTemporal = nil
        if parte == .guion {
            popoverGuion.show(relativeTo: rect, of: sentence, preferredEdge: .maxY)
            return
        }

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.appearance = NSAppearance(named: .aqua)
        switch parte {
        case .area:
            menu.addItem(.sectionHeader(title: "Qué parte de la pantalla"))
            menu.addItem(opcion("La pantalla entera", marcado: customArea == nil) { [weak self] in
                self?.usarPantallaEntera()
            })
            let area = customArea.map { "Otra área…   ahora \(Int($0.width))×\(Int($0.height))" } ?? "Un área…   la dibujás"
            menu.addItem(opcion(area, marcado: customArea != nil) { [weak self] in self?.chooseArea() })

        case .pantalla:
            menu.addItem(.sectionHeader(title: "Pantalla"))
            for (indice, display) in displays.enumerated() {
                let titulo = "\(display.name)   \(Int(display.pixelSize.width))×\(Int(display.pixelSize.height))"
                menu.addItem(opcion(titulo, marcado: indice == displayIndex) { [weak self] in
                    guard let self else { return }
                    self.displayIndex = indice
                    // Un área es de una pantalla: al cambiar de pantalla se
                    // vuelve a la entera, o se grabaría un rectángulo ajeno.
                    if self.customArea != nil { self.usarPantallaEntera() }
                    self.refrescarOracion()
                })
            }

        case .audio:
            if audioMode.capturesMicrophone && microfonoSinPermiso {
                menu.addItem(opcion("Dar permiso al micrófono…") { [weak self] in self?.abrirPermisoDeMicrofono() })
                menu.addItem(.separator())
            }
            menu.addItem(.sectionHeader(title: "Qué se oye"))
            let modos: [(AudioMode, String)] = [
                (.microphone, "Solo el micrófono"),
                (.mixed, "El micrófono y el sonido del PC"),
                (.system, "Solo el sonido del PC"),
                (.none, "Sin sonido")
            ]
            for (modo, titulo) in modos where AudioMode.available.contains(modo) {
                menu.addItem(opcion(titulo, marcado: audioMode == modo) { [weak self] in
                    self?.audioMode = modo
                    self?.audioModeChanged()
                })
            }
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: "Micrófono"))
            if microphones.isEmpty {
                let vacio = NSMenuItem(title: "No hay micrófonos conectados", action: nil, keyEquivalent: "")
                vacio.isEnabled = false
                menu.addItem(vacio)
            }
            for microfono in microphones {
                let nota = PanelSentence.esMicrofonoDeTelefono(microfono.name) ? "   calidad de teléfono" : ""
                menu.addItem(opcion(microfono.name + nota, marcado: microfono.uniqueID == microphoneID) { [weak self] in
                    guard let self else { return }
                    self.microphoneID = microfono.uniqueID
                    // Elegir un micrófono es querer oírlo.
                    if !self.audioMode.capturesMicrophone { self.audioMode = .microphone }
                    self.audioModeChanged()
                })
            }

        case .camara:
            menu.addItem(.sectionHeader(title: "Cámara"))
            menu.addItem(opcion("Sin cámara", marcado: camaraElegidaID == nil) { [weak self] in
                self?.camaraElegidaID = nil
                self?.cameraChanged()
            })
            for dispositivo in cameras {
                menu.addItem(opcion(dispositivo.name, marcado: dispositivo.uniqueID == camaraElegidaID) { [weak self] in
                    self?.camaraElegidaID = dispositivo.uniqueID
                    self?.cameraChanged()
                })
            }

        case .guion:
            return
        }
        menu.popUp(positioning: nil, at: NSPoint(x: rect.minX, y: rect.maxY + 2), in: sentence)
    }

    private func opcion(_ titulo: String, marcado: Bool = false, _ bloque: @escaping () -> Void) -> NSMenuItem {
        let item = MenuClosureItem(titulo: titulo, bloque: bloque)
        item.state = marcado ? .on : .off
        return item
    }

    // MARK: - Pantallas

    private func loadDisplays() async {
        do {
            displays = try await RecordingController.availableDisplays()

            // Memoria pegajosa: arranca en la última pantalla usada.
            if let last = ConfigurationStore.shared.current.lastDisplayID,
               let index = displays.firstIndex(where: { $0.scDisplay.displayID == last }) {
                displayIndex = index
            }
            Logger.shared.log("Pantallas detectadas: \(displays.count)")

        } catch {
            // Sin permiso de grabación de pantalla, la enumeración también falla.
            avisoTemporal = "No se pudieron listar las pantallas. Falta el permiso de grabar la pantalla."
            Logger.shared.log("ERROR listando pantallas: \(error.localizedDescription)")
            _ = ScreenRecordingPermission.ensureGranted()
        }
        refrescarOracion()
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
            return
        }

        // Sin permiso, el botón es «Dar permiso al micrófono»: grabar así
        // saldría mudo, que es peor que no grabar.
        if audioMode.capturesMicrophone && microfonoSinPermiso {
            abrirPermisoDeMicrofono()
            return
        }

        guard displays.indices.contains(displayIndex) else { return }
        let display = displays[displayIndex]
        let audioMode = self.audioMode
        let microphone = audioMode.capturesMicrophone ? selectedMicrophone() : nil

        popoverGuion.close()
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
        sentence.nivel = 0

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
        if countdownSwitch.state == .on {
            CountdownWindow.present(alTerminar: arrancar)
        } else {
            arrancar()
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

        // El globo es transitorio: el cuadro de elegir archivo lo cerraría por
        // debajo y quedaría flotando sin dueño.
        popoverGuion.close()
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
        refrescarOracion()

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
        refrescarOracion()
        Logger.shared.log("Guiones cargados: lista vaciada")
    }

    /// Los guiones cargados, cada uno con su casilla. Sin ninguno, la fila
    /// entera desaparece: no hay nada que contar.
    private func refrescarListaDeGuiones() {
        let guiones = ConfigurationStore.shared.current.teleprompterScripts
        filaLista.isHidden = guiones.isEmpty
        scriptListLabel.stringValue = guiones.count == 1 ? "1 cargado de archivo" : "\(guiones.count) cargados de archivos"
        listaGuiones.setViews(guiones.enumerated().map { indice, guion in
            let casilla = NSButton(checkboxWithTitle: guion.nombre, target: self, action: #selector(alternarGuion(_:)))
            casilla.font = BloomindStyle.ui(13)
            casilla.tag = indice
            casilla.state = guion.usar ? .on : .off
            casilla.toolTip = "\(guion.texto.count) caracteres. Desmarcalo para no usarlo en esta clase sin perderlo."
            casilla.isEnabled = !recorder.isRecording
            return casilla
        }, in: .top)
    }

    /// Marcar o desmarcar un guion lo mete o lo saca del teleprompter, sin
    /// borrarlo: la clase siguiente puede volver a usarlo con un toque.
    @objc private func alternarGuion(_ casilla: NSButton) {
        let indice = casilla.tag
        guard ConfigurationStore.shared.current.teleprompterScripts.indices.contains(indice) else { return }
        ConfigurationStore.shared.update { $0.teleprompterScripts[indice].usar = casilla.state == .on }
        refrescarOracion()
    }

    /// Todo lo que el teleprompter puede mostrar: lo escrito a mano en el panel,
    /// si hay algo, y después cada archivo cargado que esté marcado.
    private func guionesParaElTeleprompter() -> [(nombre: String, texto: String)] {
        var lista: [(nombre: String, texto: String)] = []
        let escrito = scriptView.string
        if !escrito.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lista.append((nombre: "Escrito", texto: escrito))
        }
        lista += ConfigurationStore.shared.current.teleprompterScripts.filter(\.usar).map {
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
        guardarGuionEscrito()
    }

    /// Cerrar el globo no siempre termina la edición del cuadro, así que se
    /// guarda también acá. Y la oración se vuelve a contar los guiones.
    func popoverDidClose(_ notification: Notification) {
        guardarGuionEscrito()
        refrescarOracion()
    }

    private func guardarGuionEscrito() {
        guard ConfigurationStore.shared.current.teleprompterScript != scriptView.string else { return }
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
            teleprompter.setVisible(!teleprompter.isVisible)
            tick()
            return
        }

        let pantalla = recorder.recordingScreenFrame()
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let ventana = TeleprompterWindow(guiones: guionesParaElTeleprompter(),
                                         velocidad: speedRow.value,
                                         tamañoLetra: fontRow.value,
                                         pantalla: pantalla,
                                         evitando: widget.isVisible ? widget.frame : nil,
                                         oscuro: ConfigurationStore.shared.current.teleprompterOscuro)
        // Cambiado desde el propio teleprompter, también queda guardado y el
        // interruptor del panel lo muestra.
        ventana.onTemaCambiado = { [weak self] oscuro in
            ConfigurationStore.shared.update { $0.teleprompterOscuro = oscuro }
            self?.temaSwitch.state = oscuro ? .on : .off
        }
        ventana.onChange = { [weak self] in
            self?.recordarValoresDelGuion()
            self?.tick()
        }
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

    @objc private func cambiarTemaDelGuion() {
        let oscuro = temaSwitch.state == .on
        ConfigurationStore.shared.update { $0.teleprompterOscuro = oscuro }
    }

    /// Lo que se ajusta del guion grabando queda como valor de arranque de la
    /// próxima vez, y el panel lo muestra (decisión 132): nadie debería tener
    /// que acordarse de con qué velocidad le gusta leer.
    private func recordarValoresDelGuion() {
        guard let teleprompter else { return }
        if teleprompter.velocidad != speedRow.value {
            speedRow.set(teleprompter.velocidad)
            ConfigurationStore.shared.update { $0.teleprompterSpeed = teleprompter.velocidad }
        }
        if teleprompter.tamañoLetra != fontRow.value {
            fontRow.set(teleprompter.tamañoLetra)
            ConfigurationStore.shared.update { $0.teleprompterFontSize = teleprompter.tamañoLetra }
        }
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

    // MARK: - Área, carpeta y cuenta regresiva

    /// Dibuja el área a grabar. El selector es el mismo que usa la censura
    /// (pieza compartida, plan sección 6).
    private func chooseArea() {
        guard displays.indices.contains(displayIndex) else { return }
        let display = displays[displayIndex]
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
                self.refrescarOracion()
            }
        }
    }

    private func usarPantallaEntera() {
        customArea = nil
        ConfigurationStore.shared.update { $0.customArea = nil }
        refrescarOracion()
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
        mostrarCarpeta(url.path)
        Logger.shared.log("Carpeta de salida cambiada")
    }

    @objc private func countdownChanged() {
        let activo = countdownSwitch.state == .on
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

    // MARK: - Micrófono

    private func selectedMicrophone() -> AudioDevice? {
        microphones.first { $0.uniqueID == microphoneID }
    }

    /// Cambió qué se oye: la frase cambia y el medidor se prende o se apaga.
    private func audioModeChanged() {
        ConfigurationStore.shared.update { $0.lastAudioMode = audioMode.rawValue }
        microphoneChanged()
        refrescarOracion()
    }

    private func loadMicrophones() {
        let previous = microphoneID ?? ConfigurationStore.shared.current.lastMicrophoneID

        microphones = AudioDeviceEnumerator.available()
        // Memoria pegajosa: vuelve al último micrófono usado si sigue conectado;
        // si no, el primero de la lista.
        if let previous, microphones.contains(where: { $0.uniqueID == previous }) {
            microphoneID = previous
        } else {
            microphoneID = microphones.first?.uniqueID
        }

        Logger.shared.log("Micrófonos detectados: \(microphones.count)")
        if !recorder.isRecording { microphoneChanged() }
        refrescarOracion()
    }

    private func microphoneChanged() {
        sentence.nivel = 0
        guard audioMode.capturesMicrophone, let microphone = selectedMicrophone() else {
            levelMeter.stop()
            return
        }
        // El permiso se pide acá y no al grabar: sin él el subrayado no se
        // movería y el medidor perdería justamente la función que tiene, que es
        // avisarte antes de arrancar.
        Task {
            let concedido = await AudioDeviceEnumerator.requestPermission()
            if microfonoSinPermiso != !concedido {
                microfonoSinPermiso = !concedido
                refrescarOracion()
            }
            guard concedido else {
                levelMeter.stop()
                return
            }
            levelMeter.start(deviceID: microphone.uniqueID)
        }
    }

    /// Si ya se negó una vez, macOS no vuelve a preguntar: hay que ir a
    /// Configuración del Sistema. Al volver, el panel lo vuelve a pedir solo.
    private func abrirPermisoDeMicrofono() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            microphoneChanged()
            return
        }
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Cámara

    /// Arranca con la última cámara usada si sigue conectada; si no, sin cámara:
    /// grabar solo la pantalla es un caso legítimo y frecuente, no una falla.
    private func loadCameras() {
        let previous = camaraElegidaID ?? ConfigurationStore.shared.current.lastCameraID

        cameras = CameraDeviceEnumerator.available()
        camaraElegidaID = cameras.contains { $0.uniqueID == previous } ? previous : nil

        Logger.shared.log("Cámaras detectadas: \(cameras.count)")

        // Si lo elegido no es lo que está encendido, se reconcilia: cubre tanto
        // "se conectó la cámara que se venía usando" como "la que estaba
        // prendida se desconectó y hay que soltarla".
        if !recorder.isRecording, camaraElegidaID != camera?.device.uniqueID {
            cameraChanged()
        }
        refrescarOracion()
    }

    private func selectedCamera() -> CameraDevice? {
        cameras.first { $0.uniqueID == camaraElegidaID }
    }

    /// Enciende o apaga la cámara y su ventana espejo. Pasa apenas se elige, sin
    /// esperar a grabar: así se encuadra antes de arrancar.
    private func cameraChanged() {
        refrescarOracion()
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
                camaraElegidaID = nil
                refrescarOracion()
                if recorder.isRecording { recorder.setCamera(nil) }
                return
            }

            guard let capture = CameraCapture(device: device) else {
                avisoTemporal = "No se pudo abrir la cámara."
                camaraElegidaID = nil
                refrescarOracion()
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
            menu.addItem(opcion("Apagar cámara") { [weak self] in
                self?.camaraElegidaID = nil
                self?.cameraChanged()
            })
            menu.addItem(.separator())
        }

        if cameras.isEmpty {
            let vacio = NSMenuItem(title: "No hay cámaras disponibles", action: nil, keyEquivalent: "")
            vacio.isEnabled = false
            menu.addItem(vacio)
        }

        // El panel y el menú del widget eligen lo mismo: uno solo manda, y es
        // `camaraElegidaID`.
        for dispositivo in cameras {
            menu.addItem(opcion(dispositivo.name, marcado: dispositivo.uniqueID == activa) { [weak self] in
                self?.camaraElegidaID = dispositivo.uniqueID
                self?.cameraChanged()
            })
        }
        return menu
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

    // MARK: - Estado de la grabación

    private func refresh() {
        let grabando = recorder.isRecording
        actionButton.isEnabled = true
        sentence.habilitada = !grabando
        sessionField.isEnabled = !grabando
        scriptView.isEditable = !grabando
        scriptLoadButton.isEnabled = !grabando
        scriptClearButton.isEnabled = !grabando
        for casilla in listaGuiones.arrangedSubviews.compactMap({ $0 as? NSButton }) { casilla.isEnabled = !grabando }
        speedRow.setEnabled(!grabando)
        fontRow.setEnabled(!grabando)
        folderButton.isEnabled = !grabando
        countdownSwitch.isEnabled = !grabando
        if grabando { popoverGuion.close() }
        // Durante la grabación el micrófono lo tiene la captura, así que el
        // medidor no puede leerlo: el subrayado se queda quieto a propósito.
        if !grabando { microphoneChanged() }

        pauseButton.isHidden = !grabando
        pauseButton.title = recorder.isPaused ? "Reanudar" : "Pausar"

        if grabando {
            if !widgetEscondido { widget.present() }
            // El panel se va del medio: el widget es lo que se usa en vivo.
            window?.orderOut(nil)
            abrirTeleprompterSiHayGuion()
        } else {
            widget.hide()
            widgetEscondido = false
            releaseTeleprompter()
        }
        onRecordingStateChange?(grabando, recorder.isPaused)

        if grabando {
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
            timer?.invalidate()
            timer = nil
            startedAt = nil
            accumulated = 0
            pintarEstado()
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
                      lienzo: recorder.boardColor,
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
        onTiempo?(seconds)
        // El panel puede volver a la vista con la grabación corriendo (al
        // salir del modo de dibujo): el pie dice el tiempo, el resto lo dice
        // el widget.
        pintarEstado()
    }
}
