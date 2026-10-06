import AVFoundation
import AppKit
import Carbon.HIToolbox
import UserNotifications

/// Coordina una grabación: pide el permiso, arranca la captura, arma el
/// escritor y conecta uno con otro.
///
/// En la Fase 1 el camino es directo, de la captura al archivo. Desde la Fase 2
/// el pipeline de composición se mete en el medio.
///
/// Vive en el hilo principal porque muestra avisos y actualiza la UI. Lo único
/// que corre fuera es la escritura de frames, que pasa en la cola de captura.
@MainActor
final class RecordingController {

    private(set) var isRecording = false

    private let capture = ScreenCapture()
    private let mouseTracker = MouseTracker()
    private var writer: RecordingWriter?
    private var pipeline: FramePipeline?
    private var mixer: AudioMixer?
    /// La cámara la enciende y la apaga la ventana de control; acá se guarda solo
    /// para poder soltarla si se desconecta a mitad de grabación.
    private weak var camera: CameraCapture?

    /// El tablero: su contenido y la ventana espejo donde se dibuja. El contenido
    /// vive acá y no en la ventana porque el compositor lo necesita aunque el
    /// espejo esté escondido.
    private let whiteboard = DrawingSurface()
    private var whiteboardWindow: DrawingWindow?

    /// La capa de anotación sobre la pantalla real. Es **otra instancia del mismo
    /// motor**: borrar una nunca toca la otra.
    private let annotation = DrawingSurface()
    private var annotationWindow: DrawingWindow?
    private(set) var isAnnotationOn = false

    /// Color del lienzo del tablero. Se alterna en vivo con su atajo y se recuerda
    /// entre sesiones.
    private(set) var boardColor: BoardColor = .blanco

    /// El círculo amarillo del cursor y la onda del clic. Se alternan juntos con
    /// un solo interruptor (decisión 97) y el estado se recuerda entre sesiones.
    private(set) var isCursorHighlightOn = ConfigurationStore.shared.current.cursorHighlightEnabled

    /// La zona censurada. Vive mientras la app esté abierta y se dibuja de nuevo
    /// en cada sesión (decisión 74).
    private let redaction = RedactionSlot()
    private var diskMonitor: DiskMonitor?
    /// Cómo arrancó la grabación en curso, para poder repetirla igual al
    /// reiniciar la toma.
    private var lastStartOptions: (display: CaptureDisplay, audioMode: AudioMode,
                                   microphoneID: String?, camera: CameraCapture?,
                                   sessionName: String, area: CGRect?)?
    private var rectangleSelector: RectangleSelector?

    /// Para la UI: si hay algo tapado en este momento.
    var isRedacting: Bool { redaction.activeRect != nil }
    /// La pantalla que se está grabando. El espejo del tablero tiene que cubrir
    /// esa y no la principal.
    private var recordingDisplay: CaptureDisplay?

    /// Registro central de atajos (Fase 9). Reemplaza los atajos fijos que las
    /// Fases 6, 7 y 8 fueron dejando sueltos.
    private weak var registry: ShortcutRegistry?



    var isPaused: Bool { writer?.isPaused ?? false }

    /// Modo de fuente activo. Fuera de grabación siempre vuelve a pantalla.
    private(set) var mode: CaptureMode = .pantalla

    /// Se avisa cuando cambia el modo, para esconder o mostrar el espejo de la
    /// burbuja: en cámara completa la burbuja no se compone (matriz 8.4) y dejar
    /// el espejo en pantalla confundiría.
    var onModeChange: ((CaptureMode) -> Void)?

    /// Muestra o esconde el widget de grabación. Lo atiende la ventana de
    /// control, que es la dueña del widget.
    var onWidgetRequested: (() -> Void)?

    /// Prende o apaga el teleprompter. Lo atiende la ventana de control, que es
    /// la dueña de esa ventana.
    var onTeleprompterRequested: (() -> Void)?

    /// Reiniciar toma pide confirmación, y eso lo muestra quien tenga la interfaz
    /// a mano: descartar una clase en curso no puede pasar por un tecleo suelto.
    var onRestartRequested: (() -> Void)?

    /// Se avisa cuando aparece o desaparece una superficie de dibujo, para que la
    /// ventana de control se quite del medio: la capa de anotación es
    /// transparente y cualquier ventana propia que quede detrás se ve a través.
    var onDrawingMirrorChange: ((Bool) -> Void)?

    private var isDrawingMirrorVisible = false

    /// Último marco global de la ventana espejo. Se guarda acá porque puede
    /// llegar antes de que exista el pipeline.
    private var bubbleFrame: CGRect?

    /// Micrófono y cámara en uso. Se ponen en nil si el dispositivo se desconecta
    /// a mitad de grabación, para no avisar dos veces por lo mismo.
    private var activeMicrophoneID: String?
    private var activeCameraID: String?
    private var disconnectObserver: NSObjectProtocol?

    /// Se avisa cuando el estado cambia, para que la UI se actualice.
    var onStateChange: (() -> Void)?

    static func availableDisplays() async throws -> [CaptureDisplay] {
        try await ScreenCapture.availableDisplays()
    }

    func start(display: CaptureDisplay, audioMode: AudioMode, microphoneID: String?,
               camera: CameraCapture?, sessionName: String, area: CGRect? = nil) async {
        guard !isRecording else { return }

        // Avisar del estado igual al salir por acá: si no, la UI se queda con el
        // botón deshabilitado esperando una grabación que nunca arrancó.
        guard ScreenRecordingPermission.ensureGranted() else {
            onStateChange?()
            return
        }

        var audioMode = audioMode
        var microphoneID = microphoneID
        if audioMode.capturesMicrophone, await !AudioDeviceEnumerator.requestPermission() {
            // Sin permiso se graba igual, pero sin micrófono y avisando: es
            // preferible a no grabar la clase.
            showMicrophonePermissionAlert()
            microphoneID = nil
            audioMode = audioMode == .microphone ? .none : .system
        }
        // El audio del sistema no necesita permiso propio: viaja con el de
        // grabación de pantalla, que ya se verificó arriba.

        // Cada toma arranca con el tablero limpio: los dibujos de la clase
        // anterior no tienen por qué aparecer en la siguiente (decisión 55).
        whiteboard.clear()
        annotation.clear()

        // Memoria pegajosa del color del lienzo.
        if let saved = ConfigurationStore.shared.current.boardColor {
            boardColor = saved == "negro" ? .negro : .blanco
        }

        let url = Self.makeOutputURL(sessionName: sessionName)
        Logger.shared.openLog(named: url.deletingPathExtension().lastPathComponent)

        // El nombre del micrófono va al log: sin él, al revisar una grabación
        // vieja no hay forma de saber con cuál se grabó.
        let microphoneName = microphoneID.flatMap { id in
            AudioDeviceEnumerator.device(withID: id)?.name
        } ?? "ninguno"
        Logger.shared.log("Iniciando grabación en \(display.name), audio: \(audioMode.label), micrófono: \(microphoneName), cámara: \(camera?.device.name ?? "ninguna")")

        guard let converter = CoordinateConverter(displayID: display.scDisplay.displayID) else {
            Logger.shared.log("ERROR: la pantalla elegida ya no está conectada")
            showError("Esa pantalla ya no está disponible", detail: "Volvé a abrir el control para actualizar la lista de pantallas.")
            onStateChange?()
            return
        }

        // Con área personalizada el archivo mide lo que mide el recorte, no la
        // pantalla entera.
        let recorte = area.flatMap { ScreenCapture.sourceRect(for: $0, on: display) }
        let tamañoSalida = recorte.map {
            CGSize(width: $0.width * display.scale, height: $0.height * display.scale)
        } ?? display.pixelSize

        do {
            let writer = try RecordingWriter(outputURL: url, pixelSize: tamañoSalida, withAudio: audioMode.hasAudio)
            self.writer = writer

            let pipeline = FramePipeline(
                converter: converter,
                compositor: FrameCompositor(pixelSize: tamañoSalida),
                cursorTrack: CursorTrackWriter(videoURL: url, pixelSize: tamañoSalida, fps: 30),
                tracker: mouseTracker,
                writer: writer,
                camera: camera,
                whiteboard: whiteboard,
                annotation: annotation
            )
            self.pipeline = pipeline
            pipeline.setBubbleFrame(bubbleFrame)
            pipeline.setBoardColor(boardColor)
            pipeline.setCursorHighlight(isCursorHighlightOn)
            mouseTracker.start()

            // El frame llega en la cola de captura y se procesa ahí mismo. El
            // pipeline se toma directo, no vía self: así la cola de captura nunca
            // toca el controlador, que vive en el hilo principal.
            // autoreleasepool por frame: sin esto los buffers se acumulan hasta
            // el final del ciclo de eventos.
            capture.onFrame = { [pipeline] buffer in
                autoreleasepool {
                    pipeline.process(buffer)
                }
            }

            // Todo el audio pasa por el mezclador, también con una sola fuente
            // (decisión 80). Con una sola es su caso degenerado, y tener un
            // camino único es lo que hace que silenciar y el ducking funcionen
            // igual en los cuatro modos, sin un segundo mecanismo que mantener.
            if audioMode.hasAudio {
                let mixer = AudioMixer { [writer] mixed in
                    writer.appendAudio(mixed)
                }
                self.mixer = mixer
                capture.onMicrophone = { [mixer] buffer in
                    autoreleasepool { mixer.add(buffer, from: .microphone) }
                }
                capture.onSystemAudio = { [mixer] buffer in
                    autoreleasepool { mixer.add(buffer, from: .system) }
                }
            }

            capture.onStop = { [weak self] error in
                Task { @MainActor in
                    self?.handleUnexpectedStop(error)
                }
            }

            try await capture.start(display: display, audioMode: audioMode,
                                    microphoneID: microphoneID, area: area)

            activeMicrophoneID = audioMode.capturesMicrophone ? microphoneID : nil
            activeCameraID = camera?.device.uniqueID
            self.camera = camera
            observeDeviceDisconnection()
            recordingDisplay = display
            registry?.setRecording(true)
            lastStartOptions = (display, audioMode, microphoneID, camera, sessionName, area)
            startDiskMonitor(for: url)
            RecoveryMarker.begin(outputURL: url)

            isRecording = true
            onStateChange?()

        } catch {
            Logger.shared.log("ERROR al iniciar la grabación: \(error.localizedDescription)")
            mouseTracker.stop()
            capture.onMicrophone = nil
            capture.onSystemAudio = nil
            self.mixer = nil
            self.writer = nil
            self.pipeline = nil
            showError("No se pudo iniciar la grabación", detail: error.localizedDescription)
            onStateChange?()
        }
    }

    /// La grabación en curso es la de práctica del tutorial: al detenerla se va
    /// a la Papelera, sin abrir el Finder ni avisar (decisión 137). Vive acá y
    /// no en el tutorial porque se puede detener desde cuatro lugares, y todos
    /// pasan por `stop()`.
    var tomaDePractica = false

    /// - Parameter revealInFinder: al reiniciar una toma no se abre el Finder,
    ///   porque el archivo se va a la Papelera un instante después.
    func stop(revealInFinder: Bool = true) async {
        guard isRecording else { return }
        isRecording = false

        await capture.stop()
        capture.onFrame = nil
        capture.onMicrophone = nil
        capture.onSystemAudio = nil
        // Lo que quede en el mezclador se vuelca antes de cerrar la pista.
        mixer?.flush()
        mixer = nil
        mouseTracker.stop()
        stopObservingDeviceDisconnection()
        registry?.setRecording(false)
        diskMonitor?.stop()
        diskMonitor = nil
        activeMicrophoneID = nil
        activeCameraID = nil
        setMode(.pantalla)
        closeWhiteboardWindow()
        setAnnotation(on: false)
        // La zona queda en memoria; lo que se apaga es la tapa. La próxima toma
        // de esta misma sesión arranca destapada sin obligar a redibujar.
        redaction.turnOff()
        recordingDisplay = nil

        let writer = self.writer
        let pipeline = self.pipeline
        self.writer = nil
        self.pipeline = nil

        // El JSON del cursor se cierra antes que el video: si algo falla al
        // cerrar el video, igual queda el recorrido escrito.
        pipeline?.finish()

        await withCheckedContinuation { continuation in
            guard let writer else { return continuation.resume() }
            writer.finish { continuation.resume() }
        }

        RecoveryMarker.end()
        Logger.shared.log("Grabación terminada")
        let practica = tomaDePractica
        tomaDePractica = false
        onStateChange?()

        if practica, let url = writer?.outputURL {
            Self.mandarAPapelera(url)
            Logger.shared.log("Toma de práctica del tutorial mandada a la Papelera")
            return
        }

        if revealInFinder, let url = writer?.outputURL {
            notifyFinished(url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    /// Pausa o reanuda. Congela todas las pistas de forma coherente y, al
    /// reanudar, corre los timestamps para que el archivo no quede con un hueco.
    func togglePause() {
        guard isRecording, let writer else { return }
        if writer.isPaused { writer.resume() } else { writer.pause() }
        onStateChange?()
    }

    /// Cambia el modo de fuente. El corte se ve en el frame siguiente y el
    /// cambio queda anotado en el JSON de cursor para VideoFlow.
    func setMode(_ newMode: CaptureMode) {
        guard newMode != mode else { return }
        mode = newMode
        pipeline?.setMode(newMode)
        if isRecording { Logger.shared.log("Modo de fuente: \(newMode.rawValue)") }
        updateDrawingWindows(for: newMode)
        onModeChange?(newMode)
    }

    /// Recibe el marco de la ventana espejo, en coordenadas globales. Nil apaga
    /// la burbuja.
    func setBubbleFrame(_ globalRect: CGRect?) {
        bubbleFrame = globalRect
        pipeline?.setBubbleFrame(globalRect)
    }

    /// Avisa que la cámara se cayó sola (el iPhone se bloqueó, se durmió la
    /// webcam). La grabación sigue; lo que se pierde es la imagen de la cámara.
    func reportCameraInterruption(_ name: String) {
        guard isRecording, activeCameraID != nil else { return }
        activeCameraID = nil
        Logger.shared.log("AVISO: se interrumpió la cámara (\(name)); la grabación continúa sin ella")
        showError(
            "Se interrumpió la cámara",
            detail: "\(name) dejó de entregar imagen.\n\nLa grabación sigue corriendo y el video no se pierde, pero de acá en adelante queda sin cámara."
        )
    }

    // MARK: - Interno

    /// Conecta el registro central de atajos. El dueño es la barra de menú,
    /// porque el de iniciar/detener tiene que funcionar aunque no haya grabación
    /// en curso ni ventana de control abierta.
    func attach(registry: ShortcutRegistry) {
        self.registry = registry
    }

    /// La combinación que tiene hoy una acción, para poder mostrarla en la
    /// interfaz. Sale del registro y no de una constante: los atajos son
    /// reasignables, y una ayuda que miente es peor que no tenerla.
    func etiquetaDeAtajo(_ accion: ShortcutAction) -> String? {
        registry?.shortcuts[accion]?.etiqueta
    }

    /// Ejecuta la acción de un atajo. Todo lo que se puede hacer con el teclado
    /// pasa por acá, así que agregar una acción nueva es agregar un caso.
    func perform(_ action: ShortcutAction) {
        switch action {
        case .iniciarDetener, .tarjeta: break   // los maneja la barra de menú
        case .modoPantalla:   setMode(.pantalla)
        case .modoCamara:     if camera != nil { setMode(.camara) }
        case .modoTablero:    setMode(.tablero)
        case .pausar:         togglePause()
        case .capaAnotacion:  toggleAnnotation()
        case .resaltadoCursor: toggleCursorHighlight()
        case .colorMarcador:  rotateMarkerColor()
        case .colorTablero:   toggleBoardColor()
        case .deshacer:       undoDrawing()
        case .borrar:         clearDrawing()
        case .reiniciarToma:    onRestartRequested?()
        case .censura:          toggleRedaction(forceDraw: false)
        case .redibujarCensura: toggleRedaction(forceDraw: true)
        case .silenciarMicrofono: toggleMute(.microphone)
        case .silenciarSistema:   toggleMute(.system)
        // El teleprompter no es asunto del grabador: no toca la captura ni el
        // pipeline de composición (decisión 89). La ventana la maneja quien
        // tiene la interfaz, igual que la tarjeta de atajos.
        case .teleprompter:       onTeleprompterRequested?()
        case .widget:             onWidgetRequested?()
        }
    }

    // MARK: - Cámara en vivo

    /// Cambia la cámara que se compone, o la quita con nil, con la grabación
    /// corriendo.
    ///
    /// Esto se puede hacer con la cámara y no con el audio (decisión 82) porque
    /// la cámara no es una pista del archivo ni una fuente del stream de
    /// captura: se dibuja sobre cada frame, así que puede nacer y morir cuando
    /// sea.
    func setCamera(_ camera: CameraCapture?) {
        self.camera = camera
        pipeline?.setCamera(camera)
        activeCameraID = camera?.device.uniqueID

        // En modo cámara completa el fondo del frame **es** la cámara: apagarla
        // sin más dejaría el video en negro y congelado, porque el reloj
        // sintético no corre sin imagen (decisión 83).
        if camera == nil, mode == .camara {
            setMode(.pantalla)
            Logger.shared.log("Cámara apagada en modo cámara completa: se vuelve a modo pantalla")
        }
        onStateChange?()
    }

    // MARK: - Silencio por fuente

    /// Si la fuente entró en esta grabación. Una que no se eligió antes de
    /// arrancar no se puede encender después (decisión 82), así que su botón va
    /// deshabilitado en vez de ausente.
    func capturesSource(_ source: AudioMixer.Source) -> Bool {
        guard let modo = lastStartOptions?.audioMode else { return false }
        return source == .microphone ? modo.capturesMicrophone : modo.capturesSystem
    }

    func isMuted(_ source: AudioMixer.Source) -> Bool {
        mixer?.isMuted(source) ?? false
    }

    /// Silencia o reactiva una fuente en vivo. Se permite dejar las dos mudas: el
    /// widget lo muestra bien visible y el archivo queda con silencio, no con un
    /// hueco (decisión 81).
    func toggleMute(_ source: AudioMixer.Source) {
        guard isRecording, let mixer, capturesSource(source) else { return }
        let silenciada = !mixer.isMuted(source)
        mixer.setMuted(silenciada, for: source)

        let nombre = source == .microphone ? "micrófono" : "audio del sistema"
        Logger.shared.log("\(silenciada ? "Silenciado" : "Reactivado") el \(nombre)")
        onStateChange?()
    }

    // MARK: - Disco, reinicio de toma y notificación

    /// Vigila el espacio libre mientras se graba. Con poco espacio avisa; en el
    /// umbral crítico detiene la grabación de forma limpia, que es la diferencia
    /// entre perder los últimos segundos y perder la clase entera.
    private func startDiskMonitor(for url: URL) {
        let monitor = DiskMonitor(carpeta: url.deletingLastPathComponent())
        monitor.onAviso = { [weak self] libre in
            Task { @MainActor in
                self?.showError("Queda poco espacio en el disco",
                                detail: "Quedan \(DiskMonitor.gigas(libre)) libres.\n\nLa grabación sigue, pero si el espacio baja de 2 GB la app la va a detener sola para no perder lo grabado.")
            }
        }
        monitor.onCritico = { [weak self] libre in
            Task { @MainActor in
                guard let self else { return }
                await self.stop()
                self.showError("Se detuvo la grabación por falta de espacio",
                               detail: "Quedaban \(DiskMonitor.gigas(libre)) libres.\n\nLo grabado hasta ahora quedó guardado y se puede reproducir.")
            }
        }
        monitor.start()
        diskMonitor = monitor
    }

    /// Detiene, manda la toma a la **Papelera** (nunca borrado directo, decisión
    /// 12) y arranca una toma nueva con la misma configuración.
    func restartTake() async {
        guard isRecording, let opciones = lastStartOptions else { return }
        let descartado = writer?.outputURL
        // Reiniciar la práctica sigue siendo práctica.
        let practica = tomaDePractica

        await stop(revealInFinder: false)

        if let descartado {
            Self.mandarAPapelera(descartado)
            Logger.shared.log("Toma reiniciada; la anterior quedó en la Papelera")
        }

        tomaDePractica = practica
        await start(display: opciones.display, audioMode: opciones.audioMode,
                    microphoneID: opciones.microphoneID, camera: opciones.camera,
                    sessionName: opciones.sessionName, area: opciones.area)
    }

    /// Manda una toma y su `.cursor.json` a la Papelera. Nunca borra directo
    /// (decisión 12): una toma descartada por error se recupera de ahí.
    private static func mandarAPapelera(_ video: URL) {
        let cursor = video.deletingPathExtension().appendingPathExtension("cursor.json")
        for archivo in [video, cursor] where FileManager.default.fileExists(atPath: archivo.path) {
            do {
                try FileManager.default.trashItem(at: archivo, resultingItemURL: nil)
            } catch {
                Logger.shared.log("ERROR mandando una toma a la Papelera: \(error.localizedDescription)")
            }
        }
    }

    /// Notificación al detener, con el nombre del archivo (plan, 8.9).
    ///
    /// El permiso se pide la primera vez y **si lo negás no pasa nada**: el
    /// Finder se abre igual con el archivo seleccionado, que es el acceso directo
    /// que de verdad importa. No vale la pena bloquear nada por esto.
    private func notifyFinished(_ url: URL) {
        let centro = UNUserNotificationCenter.current()
        centro.requestAuthorization(options: [.alert]) { concedido, _ in
            guard concedido else { return }

            let contenido = UNMutableNotificationContent()
            contenido.title = "Grabación lista"
            contenido.body = url.lastPathComponent

            centro.add(UNNotificationRequest(identifier: UUID().uuidString,
                                             content: contenido,
                                             trigger: nil))
        }
    }

    // MARK: - Censura

    /// Prende, apaga o redibuja la zona censurada.
    ///
    /// La primera vez de cada sesión, sin zona definida, abre el selector. De ahí
    /// en adelante el mismo atajo prende y apaga al instante; Shift fuerza el
    /// redibujado (plan, 8.6).
    private func toggleRedaction(forceDraw: Bool) {
        guard isRecording else { return }

        if forceDraw || redaction.rect == nil {
            presentRectangleSelector()
            return
        }

        redaction.toggle()
        publishRedactions()
        onStateChange?()
    }

    private func presentRectangleSelector() {
        guard rectangleSelector == nil, let frame = recordingScreenFrame() else { return }

        // El selector es una ventana de la app, así que queda fuera de la
        // captura: en el video no se ve el velo ni el instructivo, solo aparece
        // la zona ya tapada.
        rectangleSelector = RectangleSelector.present(
            on: frame,
            titulo: "Elegí la zona a tapar"
        ) { [weak self] rect in
            Task { @MainActor in
                guard let self else { return }
                self.rectangleSelector = nil
                if let rect { self.redaction.setRect(rect) }
                self.publishRedactions()
                self.onStateChange?()
            }
        }
    }

    /// Le pasa al pipeline la zona que hay que tapar ahora.
    private func publishRedactions() {
        var zonas: [(rect: CGRect, style: RedactionStyle)] = []
        if let rect = redaction.activeRect { zonas.append((rect, redaction.style)) }
        pipeline?.setRedactions(zonas)
    }

    // MARK: - Superficies de dibujo

    /// Muestra u oculta cada espejo según el modo. El contenido no se toca nunca:
    /// cambiar de modo no borra ni apaga nada (plan, 8.4). La capa de anotación
    /// sigue prendida al pasar al tablero, solo que ahí no se ve ni se compone.
    private func updateDrawingWindows(for mode: CaptureMode) {
        guard isRecording else {
            closeWhiteboardWindow()
            annotationWindow?.hide()
            return
        }

        if mode == .tablero {
            if whiteboardWindow == nil, let frame = recordingScreenFrame() {
                whiteboardWindow = DrawingWindow(surface: whiteboard,
                                                 background: .lienzo,
                                                 boardColor: boardColor,
                                                 screenFrame: frame)
            }
            annotationWindow?.hide()
            whiteboardWindow?.present()
        } else {
            closeWhiteboardWindow()
            if mode == .pantalla, isAnnotationOn {
                annotationWindow?.present()
            } else {
                annotationWindow?.hide()
            }
        }

        publishMirrorVisibility()
    }

    /// El marco de la pantalla que se está grabando, no el de la principal: lo
    /// que se dibuja y lo que sale en el video tienen que ser el mismo lugar.
    /// El marco de la pantalla que se está grabando. Lo usan el espejo de
    /// dibujo y el teleprompter, que tienen que aparecer ahí y no en la
    /// principal.
    func recordingScreenFrame() -> NSRect? {
        guard let display = recordingDisplay else { return nil }
        return NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
                == display.scDisplay.displayID
        }?.frame ?? NSScreen.main?.frame
    }

    private func closeWhiteboardWindow() {
        whiteboardWindow?.hide()
        whiteboardWindow = nil
    }

    /// Avisa si hay alguna superficie de dibujo a la vista.
    private func publishMirrorVisibility() {
        let visible = mode == .tablero || (isAnnotationOn && mode == .pantalla)
        guard visible != isDrawingMirrorVisible else { return }
        isDrawingMirrorVisible = visible
        onDrawingMirrorChange?(visible)
    }

    // MARK: - Capa de anotación

    /// Prende y apaga la capa de anotación sobre la pantalla real.
    ///
    /// Apagada, la ventana se esconde y el mouse vuelve a la app de abajo, pero
    /// **el contenido queda guardado** y reaparece al prenderla de nuevo (plan,
    /// 8.7).
    private func toggleAnnotation() {
        guard isRecording else { return }
        setAnnotation(on: !isAnnotationOn)
    }

    private func setAnnotation(on: Bool) {
        guard on != isAnnotationOn else { return }
        isAnnotationOn = on
        pipeline?.setAnnotationOn(on)

        if on {
            if annotationWindow == nil, let frame = recordingScreenFrame() {
                annotationWindow = DrawingWindow(surface: annotation,
                                                 background: .transparente,
                                                 boardColor: boardColor,
                                                 screenFrame: frame)
            }
            // Solo se muestra sobre la pantalla real. Prenderla estando en cámara
            // o en tablero deja el estado prendido, pero la ventana no aparece:
            // ahí la anotación no se compone (matriz 8.4) y una capa invisible
            // comiéndose el mouse sin dejar rastro en el video no se entiende de
            // ninguna manera.
            if mode == .pantalla {
                annotationWindow?.present()
            }
        } else {
            annotationWindow?.hide()
            annotationWindow = nil
        }

        publishMirrorVisibility()
        refreshDrawingMirror()
        Logger.shared.log("Capa de anotación \(on ? "prendida" : "apagada")")
        onStateChange?()
    }

    /// La superficie sobre la que actúan deshacer, borrar y el color: el tablero
    /// si estás en el tablero, la capa de anotación si está prendida. Nunca las
    /// dos, que es lo que pide el plan en 8.7.
    private var activeSurface: DrawingSurface? {
        if mode == .tablero { return whiteboard }
        if isAnnotationOn, mode == .pantalla { return annotation }
        return nil
    }

    private var activeMirror: DrawingWindow? {
        mode == .tablero ? whiteboardWindow : annotationWindow
    }

    private func refreshDrawingMirror() {
        activeMirror?.refresh()
    }

    /// Cierra el cuadro de texto que estuviera abierto en el dibujo. Lo llama el
    /// teleprompter al quedarse con el teclado: los dos lo necesitan y no puede
    /// ser de los dos a la vez (decisión 95).
    func closeDrawingTextBox() {
        activeMirror?.closeTextBox()
    }

    /// Alterna el lienzo entre blanco y negro, sin cortar la grabación.
    ///
    /// Si el marcador activo quedara invisible sobre el fondo nuevo, se rota solo:
    /// pasar a tablero negro con el marcador negro dejaría dibujando en la nada.
    /// Prende y apaga el resaltado del cursor: el círculo y la onda del clic van
    /// juntos, son la misma ayuda visual (decisión 97).
    ///
    /// El `.cursor.json` no se toca: sigue registrando el recorrido y los clics
    /// completos, porque VideoFlow los usa para el zoom y eso es independiente de
    /// que el círculo se vea (decisión 98).
    private func toggleCursorHighlight() {
        isCursorHighlightOn.toggle()
        ConfigurationStore.shared.update { $0.cursorHighlightEnabled = isCursorHighlightOn }
        pipeline?.setCursorHighlight(isCursorHighlightOn)
        Logger.shared.log("Resaltado del cursor \(isCursorHighlightOn ? "prendido" : "apagado")")
        onStateChange?()
    }

    private func toggleBoardColor() {
        guard isRecording else { return }
        boardColor = boardColor == .blanco ? .negro : .blanco

        ConfigurationStore.shared.update { $0.boardColor = boardColor.label }
        pipeline?.setBoardColor(boardColor)
        whiteboardWindow?.setBoardColor(boardColor)

        if whiteboard.color == boardColor.invisibleMarker {
            rotateMarkerColor()
        }

        Logger.shared.log("Tablero \(boardColor.label)")
        onStateChange?()
    }

    /// La paleta es una sola en la interfaz, así que el color se rota en las dos
    /// superficies a la vez y no depende de cuál esté activa.
    ///
    /// En el tablero se saltea el color que se confundiría con el lienzo; sobre la
    /// pantalla real no se saltea ninguno.
    private func rotateMarkerColor() {
        let invisible = mode == .tablero ? boardColor.invisibleMarker : nil
        let color = whiteboard.color.next(avoiding: invisible)
        whiteboard.setColor(color)
        annotation.setColor(color)
        Logger.shared.log("Color del marcador: \(color.label)")
        refreshDrawingMirror()
        onStateChange?()
    }

    private func undoDrawing() {
        guard let surface = activeSurface else { return }
        activeMirror?.closeTextBox()
        surface.undo()
        refreshDrawingMirror()
    }

    /// Borra **solo** la superficie activa. Nunca las dos (plan, 8.7).
    ///
    /// El `clear()` de la otra superficie acá adentro fue un bug real que borraba
    /// el tablero y la anotación de un solo golpe (decisión 65). Si alguna vez
    /// aparece de nuevo una línea que toque la superficie que no está activa, es
    /// el mismo error volviendo.
    private func clearDrawing() {
        guard let surface = activeSurface else { return }
        activeMirror?.closeTextBox()
        surface.clear()
        refreshDrawingMirror()
        Logger.shared.log(surface === whiteboard ? "Tablero borrado" : "Capa de anotación borrada")
    }

    var markerColor: MarkerColor { whiteboard.color }

    private func handleUnexpectedStop(_ error: Error) {
        guard isRecording else { return }
        Task {
            await stop()
            showError("La grabación se detuvo sola", detail: "\(error.localizedDescription)\n\nLo grabado hasta ahora quedó guardado.")
        }
    }

    /// Resiliencia de hardware (plan, sección 5): si el micrófono se cae a mitad
    /// de grabación, la grabación **sigue** con lo que quede, se avisa visible y
    /// se registra. Crashear o seguir grabando en silencio sin avisar son ambos
    /// inaceptables.
    private func observeDeviceDisconnection() {
        disconnectObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let device = notification.object as? AVCaptureDevice else { return }
            let name = device.localizedName
            let id = device.uniqueID

            Task { @MainActor [weak self] in
                guard let self else { return }

                if id == self.activeMicrophoneID {
                    self.activeMicrophoneID = nil
                    Logger.shared.log("AVISO: se desconectó el micrófono (\(name)); la grabación continúa sin audio")
                    self.showError(
                        "Se desconectó el micrófono",
                        detail: "\(name) dejó de estar disponible.\n\nLa grabación sigue corriendo y el video no se pierde, pero de acá en adelante queda sin audio."
                    )
                }

                if id == self.activeCameraID {
                    // Si estaba en cámara completa, el fondo se congelaría en el
                    // último frame: se vuelve a pantalla, que es lo único que
                    // queda vivo, y se suelta la última imagen para que la
                    // burbuja tampoco quede congelada.
                    self.setMode(.pantalla)
                    self.camera?.stop()
                    self.activeCameraID = nil
                    Logger.shared.log("AVISO: se desconectó la cámara (\(name)); la grabación continúa sin ella")
                    self.showError(
                        "Se desconectó la cámara",
                        detail: "\(name) dejó de estar disponible.\n\nLa grabación sigue corriendo y el video no se pierde, pero de acá en adelante queda sin cámara."
                    )
                }
            }
        }
    }

    private func stopObservingDeviceDisconnection() {
        if let disconnectObserver {
            NotificationCenter.default.removeObserver(disconnectObserver)
        }
        disconnectObserver = nil
    }

    private func showMicrophonePermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Falta el permiso de micrófono"
        alert.informativeText = "La grabación va a arrancar sin audio.\n\nPara grabar tu voz, activá el Grabador Bloomind en Configuración del Sistema, Privacidad y seguridad, Micrófono."
        alert.addButton(withTitle: "Abrir Configuración del Sistema")
        alert.addButton(withTitle: "Grabar sin audio")
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
            NSWorkspace.shared.open(url)
        }
    }

    private func showError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    /// `AAAA-MM-DD HHhMM - Nombre de sesión.mov`, en la carpeta de salida de la
    /// configuración. La hora en el nombre evita colisiones entre tomas, incluso
    /// al reiniciar una toma sobre la marcha.
    static func makeOutputURL(sessionName: String) -> URL {
        let folder = URL(fileURLWithPath: ConfigurationStore.shared.current.outputFolder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH'h'mm"
        // Un nombre vacío no puede dejar el archivo llamándose " - .mov".
        let limpio = sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nombre = limpio.isEmpty ? "Sin nombre" : limpio
        return folder.appendingPathComponent("\(formatter.string(from: Date())) - \(nombre).mov")
    }
}
