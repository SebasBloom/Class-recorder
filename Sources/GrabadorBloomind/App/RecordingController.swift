import AVFoundation
import AppKit

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

    /// Se avisa cuando el estado cambia, para que la UI se actualice.
    var onStateChange: (() -> Void)?

    static func availableDisplays() async throws -> [CaptureDisplay] {
        try await ScreenCapture.availableDisplays()
    }

    func start(display: CaptureDisplay) async {
        guard !isRecording else { return }

        // Avisar del estado igual al salir por acá: si no, la UI se queda con el
        // botón deshabilitado esperando una grabación que nunca arrancó.
        guard ScreenRecordingPermission.ensureGranted() else {
            onStateChange?()
            return
        }

        let url = Self.makeOutputURL(sessionName: "Prueba")
        Logger.shared.openLog(named: url.deletingPathExtension().lastPathComponent)
        Logger.shared.log("Iniciando grabación en \(display.name)")

        guard let converter = CoordinateConverter(displayID: display.scDisplay.displayID) else {
            Logger.shared.log("ERROR: la pantalla elegida ya no está conectada")
            showError("Esa pantalla ya no está disponible", detail: "Volvé a abrir el control para actualizar la lista de pantallas.")
            onStateChange?()
            return
        }

        do {
            let writer = try RecordingWriter(outputURL: url, pixelSize: display.pixelSize)
            self.writer = writer

            let pipeline = FramePipeline(
                converter: converter,
                compositor: FrameCompositor(pixelSize: display.pixelSize),
                cursorTrack: CursorTrackWriter(videoURL: url, pixelSize: display.pixelSize, fps: 30),
                tracker: mouseTracker,
                writer: writer
            )
            self.pipeline = pipeline
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

            capture.onStop = { [weak self] error in
                Task { @MainActor in
                    self?.handleUnexpectedStop(error)
                }
            }

            try await capture.start(display: display)

            isRecording = true
            onStateChange?()

        } catch {
            Logger.shared.log("ERROR al iniciar la grabación: \(error.localizedDescription)")
            mouseTracker.stop()
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
        mouseTracker.stop()

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

    // MARK: - Interno

    private func handleUnexpectedStop(_ error: Error) {
        guard isRecording else { return }
        Task {
            await stop()
            showError("La grabación se detuvo sola", detail: "\(error.localizedDescription)\n\nLo grabado hasta ahora quedó guardado.")
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
