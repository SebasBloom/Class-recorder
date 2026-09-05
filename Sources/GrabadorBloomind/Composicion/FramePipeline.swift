import AVFoundation

/// Une todo lo que le pasa a un frame entre que sale de la captura y entra al
/// archivo: se ubica el cursor, se componen las capas y se registra el evento
/// para VideoFlow.
///
/// Vive en la cola de captura. Lo único que le llega desde el hilo principal es
/// el modo activo y dónde quedó la burbuja, y eso pasa por un candado: son dos
/// valores chiquitos que se leen una vez por frame.
final class FramePipeline {

    private let converter: CoordinateConverter
    private let compositor: FrameCompositor
    private let cursorTrack: CursorTrackWriter
    private let tracker: MouseTracker
    private let writer: RecordingWriter
    /// Mutable desde la Fase 13: la cámara se puede prender y apagar con la
    /// grabación corriendo. La lee la cola de captura 30 veces por segundo y la
    /// cambia el hilo principal, así que va bajo el mismo lock que los demás
    /// ajustes en vivo.
    private var _camera: CameraCapture?
    private let whiteboard: DrawingSurface
    private let annotation: DrawingSurface
    /// La capa de anotación se prende y se apaga; el tablero no. Cuando está
    /// apagada no se compone, pero su contenido sigue guardado.
    private var _annotationOn = false
    private var _boardColor: BoardColor = .blanco
    /// Zonas de censura ya convertidas a píxeles del frame, listas para tapar.
    private var _redactions: [(rect: CGRect, style: RedactionStyle)] = []

    /// Timestamp del primer frame. Todo lo demás se mide desde acá.
    private var sessionStart: CMTime?

    // MARK: - Reloj propio para los modos que no son pantalla
    //
    // ScreenCaptureKit deja de mandar cuadros cuando la pantalla no cambia, y los
    // cuadros "sin novedad" que manda en cambio no traen imagen: no hay nada que
    // escribir con ellos. Grabando la pantalla eso no se nota, porque repetir el
    // último cuadro de una pantalla quieta es exactamente lo correcto.
    //
    // En modo cámara completa sí se nota, y feo: el fondo del video es la cámara,
    // así que la cara queda congelada mientras el audio sigue. Pasó de verdad en
    // la prueba de la Fase 6: 41 segundos congelados.
    //
    // Por eso, en los modos cuyo fondo no es la pantalla capturada (cámara y
    // tablero), un reloj propio emite cuadros cuando la captura se queda callada.
    // En modo pantalla no corre: ahí el cuadro repetido es la respuesta correcta
    // y no hay nada que arreglar.
    //
    // En tablero hace falta por la burbuja, que sí se compone ahí según la matriz
    // 8.4: sin reloj, la cara quedaría congelada sobre un lienzo quieto.

    /// Cada cuánto emite el reloj propio, y cuánto silencio de la captura hace
    /// falta para que entre a trabajar.
    private static let syntheticInterval: Double = 1.0 / 30
    private static let stallThreshold: Double = 0.06

    private let clockQueue = DispatchQueue(label: "com.bloomind.grabador.reloj")
    private var clockTimer: DispatchSourceTimer?
    private var scratchBuffer: CVPixelBuffer?
    private var scratchFormat: CMVideoFormatDescription?

    /// Serializa composición y escritura entre la cola de captura y el reloj.
    private let frameLock = NSLock()

    private var lastRealFrameAt: CMTime = .invalid
    private var lastAppendedAt: CMTime = .invalid

    /// Cuántos cuadros puso cada fuente. Van al log **una sola vez, al cerrar**:
    /// con la pantalla quieta la captura se calla y vuelve varias veces por
    /// segundo, y anotar cada transición llenaría el log de una clase de una hora
    /// con miles de líneas que no dicen nada.
    private var realFrames = 0
    private var syntheticFrames = 0

    private let lock = NSLock()
    private var _mode: CaptureMode = .pantalla
    /// Marco de la burbuja en píxeles del frame, origen arriba. Nil si no hay
    /// cámara o si la burbuja se arrastró fuera de la pantalla que se graba.
    private var _bubbleRect: CGRect?
    /// Cambio de modo pendiente de anotar en el JSON. Se anota con el tiempo del
    /// próximo frame y no con el del clic: el JSON habla en tiempo de video.
    private var _pendingModeChange: CaptureMode?

    init(converter: CoordinateConverter,
         compositor: FrameCompositor,
         cursorTrack: CursorTrackWriter,
         tracker: MouseTracker,
         writer: RecordingWriter,
         camera: CameraCapture?,
         whiteboard: DrawingSurface,
         annotation: DrawingSurface) {
        self.converter = converter
        self.compositor = compositor
        self.cursorTrack = cursorTrack
        self.tracker = tracker
        self.writer = writer
        self._camera = camera
        self.whiteboard = whiteboard
        self.annotation = annotation

        startClock()
    }

    /// Cambia el modo de fuente. Se llama desde el hilo principal (atajo o
    /// botón); el corte se ve en el frame siguiente, que a 30 fps es instantáneo.
    func setMode(_ mode: CaptureMode) {
        lock.lock()
        if _mode != mode {
            _mode = mode
            _pendingModeChange = mode
        }
        lock.unlock()
    }

    var mode: CaptureMode {
        lock.lock()
        defer { lock.unlock() }
        return _mode
    }

    func setAnnotationOn(_ on: Bool) {
        lock.lock()
        _annotationOn = on
        lock.unlock()
    }

    func setBoardColor(_ color: BoardColor) {
        lock.lock()
        _boardColor = color
        lock.unlock()
    }

    /// Cambia la cámara que se compone, o la quita con nil. El cambio se ve en el
    /// frame siguiente.
    func setCamera(_ camera: CameraCapture?) {
        lock.lock()
        _camera = camera
        lock.unlock()
    }

    var camera: CameraCapture? {
        lock.lock()
        defer { lock.unlock() }
        return _camera
    }

    /// Recibe las zonas activas en coordenadas globales y las deja convertidas.
    /// La conversión se hace acá y no por frame: las zonas cambian cuando alguien
    /// aprieta un atajo, no treinta veces por segundo.
    func setRedactions(_ zonas: [(rect: CGRect, style: RedactionStyle)]) {
        let convertidas = zonas.compactMap { zona -> (rect: CGRect, style: RedactionStyle)? in
            guard let pixeles = converter.pixelRect(fromGlobal: zona.rect) else { return nil }
            return (pixeles, zona.style)
        }
        lock.lock()
        _redactions = convertidas
        lock.unlock()
    }

    /// Ubica la burbuja a partir del marco global de la ventana espejo.
    func setBubbleFrame(_ globalRect: CGRect?) {
        let pixels = globalRect.flatMap { converter.pixelRect(fromGlobal: $0) }
        lock.lock()
        _bubbleRect = pixels
        lock.unlock()
    }

    func process(_ sampleBuffer: CMSampleBuffer) {
        frameLock.lock()
        defer { frameLock.unlock() }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        lastRealFrameAt = presentationTime

        // En pausa no se compone ni se registra nada: el video final no tiene
        // ese tramo, así que tampoco debe tenerlo el JSON.
        guard !writer.isPaused else { return }

        // Después de un tramo cubierto por el reloj propio, los primeros cuadros
        // reales pueden traer un timestamp anterior al último ya escrito. Meterlos
        // rompería el orden y con él la grabación entera (decisión 43).
        if lastAppendedAt.isValid, presentationTime <= lastAppendedAt { return }

        if sessionStart == nil { sessionStart = presentationTime }
        guard let start = sessionStart else { return }
        lastAppendedAt = presentationTime
        realFrames += 1

        // Tiempo del video final: desde el primer frame y descontando pausas.
        let elapsed = CMTimeSubtract(CMTimeSubtract(presentationTime, start), writer.pausedTotal)
        let time = max(0, elapsed.seconds)

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            writer.append(sampleBuffer)
            return
        }

        lock.lock()
        let mode = _mode
        let bubbleRect = _bubbleRect
        let annotationOn = _annotationOn
        let boardColor = _boardColor
        let redactions = _redactions
        let modeChange = _pendingModeChange
        _pendingModeChange = nil
        lock.unlock()

        if let modeChange {
            cursorTrack.recordModeChange(to: modeChange, time: time)
        }

        let cursor = converter.pixelPoint(fromGlobal: tracker.location)
        // Un clic en la pantalla que no se está grabando no va al video ni al
        // JSON: no existe en el material final.
        let clicks = tracker.drainClicks().compactMap {
            converter.pixelPoint(fromGlobal: $0.location)
        }

        compositor.draw(into: pixelBuffer,
                        mode: mode,
                        cursor: cursor,
                        newClicks: clicks,
                        camera: camera?.latestImage,
                        bubbleRect: bubbleRect,
                        whiteboard: whiteboard,
                        boardColor: boardColor,
                        annotation: annotationOn ? annotation : nil,
                        redactions: redactions,
                        time: time)
        cursorTrack.record(cursor: cursor, clicks: clicks, time: time)

        writer.append(sampleBuffer)
    }

    /// Cierra el archivo de cursor. El video lo cierra el escritor por su lado.
    func finish() {
        clockTimer?.cancel()
        clockTimer = nil
        if syntheticFrames > 0 {
            Logger.shared.log("Cuadros escritos: \(realFrames) de la captura, \(syntheticFrames) del reloj propio con la pantalla quieta")
        }
        cursorTrack.finish()
    }

    // MARK: - Reloj propio

    private func startClock() {
        let timer = DispatchSource.makeTimerSource(queue: clockQueue)
        timer.schedule(deadline: .now() + Self.syntheticInterval,
                       repeating: Self.syntheticInterval,
                       leeway: .milliseconds(4))
        timer.setEventHandler { [weak self] in
            autoreleasepool { self?.tick() }
        }
        timer.resume()
        clockTimer = timer
    }

    /// Emite un cuadro si la captura lleva callada más de lo tolerable y el fondo
    /// del video es la cámara. El reloj es el mismo que usa ScreenCaptureKit para
    /// sus timestamps, así que los cuadros propios y los de la captura caen en la
    /// misma línea de tiempo sin corrección de deriva.
    private func tick() {
        frameLock.lock()
        defer { frameLock.unlock() }

        guard !writer.isPaused, let start = sessionStart else { return }

        lock.lock()
        let bubbleRect = _bubbleRect
        let boardColor = _boardColor
        lock.unlock()

        lock.lock()
        let mode = _mode
        lock.unlock()

        // El reloj cubre los modos cuyo fondo **no** es la pantalla capturada.
        // En modo pantalla no corre: ahí repetir el último cuadro de una pantalla
        // quieta es la respuesta correcta, no un defecto.
        switch mode {
        case .pantalla: return
        case .camara: guard camera?.latestImage != nil else { return }
        case .tablero: break
        }

        let now = CMClockGetTime(CMClockGetHostTimeClock())
        guard lastRealFrameAt.isValid,
              CMTimeGetSeconds(CMTimeSubtract(now, lastRealFrameAt)) > Self.stallThreshold else { return }
        if lastAppendedAt.isValid,
           CMTimeGetSeconds(CMTimeSubtract(now, lastAppendedAt)) < Self.syntheticInterval * 0.95 { return }

        guard let buffer = scratch() else { return }

        let elapsed = CMTimeSubtract(CMTimeSubtract(now, start), writer.pausedTotal)

        // En estos modos el fondo tapa el cuadro entero, así que no hace falta
        // arrastrar el último contenido de pantalla: el búfer se pinta completo.
        // El cursor no va: en cámara no se dibuja, y en tablero su posición la
        // pone la captura, que justamente no está mandando nada.
        compositor.draw(into: buffer,
                        mode: mode,
                        cursor: nil,
                        newClicks: [],
                        camera: camera?.latestImage,
                        bubbleRect: bubbleRect,
                        whiteboard: whiteboard,
                        boardColor: boardColor,
                        time: max(0, elapsed.seconds))

        guard let sample = sampleBuffer(from: buffer, at: now) else { return }
        lastAppendedAt = now
        syntheticFrames += 1
        writer.append(sample)
    }

    /// Búfer propio donde se pinta el cuadro emitido por el reloj. Se crea una
    /// sola vez y se reusa: uno por grabación, no uno por cuadro.
    private func scratch() -> CVPixelBuffer? {
        if let scratchBuffer { return scratchBuffer }

        let size = converter.pixelSize
        var buffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            // Respaldado por IOSurface, que es lo que espera el codificador por
            // hardware. Sin esto la escritura cuesta una copia extra por cuadro.
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]
        guard CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                                  kCVPixelFormatType_32BGRA, attributes as CFDictionary,
                                  &buffer) == kCVReturnSuccess else {
            Logger.shared.log("ERROR: no se pudo crear el búfer del reloj propio")
            return nil
        }
        scratchBuffer = buffer
        return buffer
    }

    private func sampleBuffer(from pixelBuffer: CVPixelBuffer, at time: CMTime) -> CMSampleBuffer? {
        if scratchFormat == nil {
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                         imageBuffer: pixelBuffer,
                                                         formatDescriptionOut: &scratchFormat)
        }
        guard let format = scratchFormat else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: time,
            decodeTimeStamp: .invalid
        )
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                       imageBuffer: pixelBuffer,
                                                       formatDescription: format,
                                                       sampleTiming: &timing,
                                                       sampleBufferOut: &sample) == noErr else { return nil }
        return sample
    }
}
