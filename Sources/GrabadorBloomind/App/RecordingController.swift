import AVFoundation
import AppKit
import Carbon.HIToolbox

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

    /// La zona censurada. Vive mientras la app esté abierta y se dibuja de nuevo
    /// en cada sesión (decisión 74).
    private let redaction = RedactionSlot()
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

    func start(display: CaptureDisplay, audioMode: AudioMode, microphoneID: String?, camera: CameraCapture?) async {
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

        let url = Self.makeOutputURL(sessionName: "Prueba")
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

        do {
            let writer = try RecordingWriter(outputURL: url, pixelSize: display.pixelSize, withAudio: audioMode.hasAudio)
            self.writer = writer

            let pipeline = FramePipeline(
                converter: converter,
                compositor: FrameCompositor(pixelSize: display.pixelSize),
                cursorTrack: CursorTrackWriter(videoURL: url, pixelSize: display.pixelSize, fps: 30),
                tracker: mouseTracker,
                writer: writer,
                camera: camera,
                whiteboard: whiteboard,
                annotation: annotation
            )
            self.pipeline = pipeline
            pipeline.setBubbleFrame(bubbleFrame)
            pipeline.setBoardColor(boardColor)
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

            // Con una sola fuente el audio va directo a la pista. Con las dos,
            // pasa por el mezclador, que las suma sobre una línea de tiempo
            // común y entrega bloques ya combinados.
            if audioMode == .mixed {
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
            } else {
                capture.onMicrophone = { [writer] buffer in
                    autoreleasepool { writer.appendAudio(buffer) }
                }
                capture.onSystemAudio = { [writer] buffer in
                    autoreleasepool { writer.appendAudio(buffer) }
                }
            }

            capture.onStop = { [weak self] error in
                Task { @MainActor in
                    self?.handleUnexpectedStop(error)
                }
            }

            try await capture.start(display: display, audioMode: audioMode, microphoneID: microphoneID)

            activeMicrophoneID = audioMode.capturesMicrophone ? microphoneID : nil
            activeCameraID = camera?.device.uniqueID
            self.camera = camera
            observeDeviceDisconnection()
            recordingDisplay = display
            registry?.setRecording(true)

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

    func stop() async {
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

        Logger.shared.log("Grabación terminada")
        onStateChange?()
        if let url = writer?.outputURL {
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
        case .colorMarcador:  rotateMarkerColor()
        case .colorTablero:   toggleBoardColor()
        case .deshacer:       undoDrawing()
        case .borrar:         clearDrawing()
        case .censura:          toggleRedaction(forceDraw: false)
        case .redibujarCensura: toggleRedaction(forceDraw: true)
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
    private func recordingScreenFrame() -> NSRect? {
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

    /// Alterna el lienzo entre blanco y negro, sin cortar la grabación.
    ///
    /// Si el marcador activo quedara invisible sobre el fondo nuevo, se rota solo:
    /// pasar a tablero negro con el marcador negro dejaría dibujando en la nada.
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
    /// configuración. La hora en el nombre evita colisiones entre tomas.
    private static func makeOutputURL(sessionName: String) -> URL {
        let folder = URL(fileURLWithPath: ConfigurationStore.shared.current.outputFolder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH'h'mm"
        return folder.appendingPathComponent("\(formatter.string(from: Date())) - \(sessionName).mov")
    }
}
