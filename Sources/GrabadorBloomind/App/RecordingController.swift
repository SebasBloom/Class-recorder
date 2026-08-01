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
    private var whiteboardWindow: WhiteboardWindow?
    /// Repinta el espejo mientras el tablero está a la vista. El modelo cambia
    /// desde el mouse y el teclado, y el espejo tiene que mostrar lo mismo que
    /// está entrando al video.
    private var whiteboardRefresh: Timer?
    /// La pantalla que se está grabando. El espejo del tablero tiene que cubrir
    /// esa y no la principal.
    private var recordingDisplay: CaptureDisplay?

    /// Atajos fijos de la Fase 6 para cambiar de modo. Se registran solo mientras
    /// se graba, para no robarle combinaciones al sistema el resto del tiempo
    /// (punto delicado 7). El registro reasignable llega en la Fase 9.
    private var hotKeys: [HotKey] = []

    var isPaused: Bool { writer?.isPaused ?? false }

    /// Modo de fuente activo. Fuera de grabación siempre vuelve a pantalla.
    private(set) var mode: CaptureMode = .pantalla

    /// Se avisa cuando cambia el modo, para esconder o mostrar el espejo de la
    /// burbuja: en cámara completa la burbuja no se compone (matriz 8.4) y dejar
    /// el espejo en pantalla confundiría.
    var onModeChange: ((CaptureMode) -> Void)?

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
                whiteboard: whiteboard
            )
            self.pipeline = pipeline
            pipeline.setBubbleFrame(bubbleFrame)
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
            registerModeHotKeys(display: display, hasCamera: camera != nil)

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
        hotKeys.removeAll()
        activeMicrophoneID = nil
        activeCameraID = nil
        setMode(.pantalla)
        closeWhiteboardWindow()
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
        updateWhiteboardWindow(for: newMode)
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

    /// Atajos fijos temporales: los defaults de la sección 8.8 del plan. En la
    /// Fase 9 se vuelven reasignables.
    ///
    /// Cada modo se registra **dos veces**, con el número de la fila de arriba y
    /// con el del teclado numérico: son códigos de tecla distintos, y en un
    /// teclado completo el numérico es el que queda más a mano (decisión 53).
    ///
    /// El de cámara completa solo se registra si hay cámara: sin ella el modo no
    /// tendría nada que mostrar.
    private func registerModeHotKeys(display: CaptureDisplay, hasCamera: Bool) {
        hotKeys.removeAll()

        let modifiers = optionKey | cmdKey
        var bindings: [(keys: [Int], mode: CaptureMode)] = [
            ([kVK_ANSI_1, kVK_ANSI_Keypad1], .pantalla),
            ([kVK_ANSI_3, kVK_ANSI_Keypad3], .tablero)
        ]
        if hasCamera {
            bindings.append(([kVK_ANSI_2, kVK_ANSI_Keypad2], .camara))
        }

        hotKeys = bindings.flatMap { binding in
            binding.keys.map { key in
                HotKey(keyCode: key, modifiers: modifiers) { [weak self] in
                    Task { @MainActor in self?.setMode(binding.mode) }
                }
            }
        }

        // Atajos de dibujo. Solo tienen efecto sobre la superficie activa, que
        // en esta fase es el tablero; la capa de anotación llega en la Fase 8.
        hotKeys.append(HotKey(keyCode: kVK_ANSI_0, modifiers: modifiers) { [weak self] in
            Task { @MainActor in self?.rotateMarkerColor() }
        })
        hotKeys.append(HotKey(keyCode: kVK_ANSI_Z, modifiers: modifiers) { [weak self] in
            Task { @MainActor in self?.undoDrawing() }
        })
        hotKeys.append(HotKey(keyCode: kVK_Delete, modifiers: modifiers) { [weak self] in
            Task { @MainActor in self?.clearDrawing() }
        })

        self.recordingDisplay = display
    }

    // MARK: - Tablero

    /// Muestra o esconde el espejo del tablero según el modo. El contenido no se
    /// toca: cambiar de modo nunca borra lo dibujado (plan, 8.4).
    private func updateWhiteboardWindow(for mode: CaptureMode) {
        guard mode == .tablero, isRecording else {
            closeWhiteboardWindow()
            return
        }

        if whiteboardWindow == nil, let display = recordingDisplay {
            // Cubre exactamente la pantalla que se graba, no la principal: el
            // tablero del video y el de la mano tienen que ser el mismo.
            let frame = NSScreen.screens.first {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
                    == display.scDisplay.displayID
            }?.frame ?? NSScreen.main?.frame ?? .zero

            whiteboardWindow = WhiteboardWindow(surface: whiteboard, screenFrame: frame)
        }

        whiteboardWindow?.present()
        whiteboardRefresh?.invalidate()
        whiteboardRefresh = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.whiteboardWindow?.refresh() }
        }
    }

    private func closeWhiteboardWindow() {
        whiteboardRefresh?.invalidate()
        whiteboardRefresh = nil
        whiteboardWindow?.hide()
        whiteboardWindow = nil
    }

    private func rotateMarkerColor() {
        let color = whiteboard.rotateColor()
        Logger.shared.log("Color del marcador: \(color.label)")
        onStateChange?()
    }

    private func undoDrawing() {
        guard mode == .tablero else { return }
        whiteboardWindow?.closeTextBox()
        whiteboard.undo()
        whiteboardWindow?.refresh()
    }

    /// Borra **solo** la superficie activa. Nunca las dos (plan, 8.7).
    private func clearDrawing() {
        guard mode == .tablero else { return }
        whiteboardWindow?.closeTextBox()
        whiteboard.clear()
        whiteboardWindow?.refresh()
        Logger.shared.log("Tablero borrado")
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
