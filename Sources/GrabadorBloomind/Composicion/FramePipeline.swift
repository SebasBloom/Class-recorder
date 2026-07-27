import AVFoundation

/// Une todo lo que le pasa a un frame entre que sale de la captura y entra al
/// archivo: se ubica el cursor, se componen las capas y se registra el evento
/// para VideoFlow.
///
/// Vive entero en la cola de captura. Nadie más lo toca, así que no necesita
/// candados propios: el único dato compartido con el hilo principal es la
/// posición del mouse, y de eso se encarga `MouseTracker`.
final class FramePipeline {

    private let converter: CoordinateConverter
    private let compositor: FrameCompositor
    private let cursorTrack: CursorTrackWriter
    private let tracker: MouseTracker
    private let writer: RecordingWriter

    /// Timestamp del primer frame. Todo lo demás se mide desde acá.
    private var sessionStart: CMTime?

    /// Modo activo. Fijo en pantalla hasta la Fase 6.
    private var mode: CaptureMode = .pantalla

    init(converter: CoordinateConverter,
         compositor: FrameCompositor,
         cursorTrack: CursorTrackWriter,
         tracker: MouseTracker,
         writer: RecordingWriter) {
        self.converter = converter
        self.compositor = compositor
        self.cursorTrack = cursorTrack
        self.tracker = tracker
        self.writer = writer
    }

    func process(_ sampleBuffer: CMSampleBuffer) {
        // En pausa no se compone ni se registra nada: el video final no tiene
        // ese tramo, así que tampoco debe tenerlo el JSON.
        guard !writer.isPaused else { return }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if sessionStart == nil { sessionStart = presentationTime }
        guard let start = sessionStart else { return }

        // Tiempo del video final: desde el primer frame y descontando pausas.
        let elapsed = CMTimeSubtract(CMTimeSubtract(presentationTime, start), writer.pausedTotal)
        let time = max(0, elapsed.seconds)

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            writer.append(sampleBuffer)
            return
        }

        let cursor = converter.pixelPoint(fromGlobal: tracker.location)
        // Un clic en la pantalla que no se está grabando no va al video ni al
        // JSON: no existe en el material final.
        let clicks = tracker.drainClicks().compactMap {
            converter.pixelPoint(fromGlobal: $0.location)
        }

        compositor.draw(into: pixelBuffer, mode: mode, cursor: cursor, newClicks: clicks, time: time)
        cursorTrack.record(cursor: cursor, clicks: clicks, time: time)

        writer.append(sampleBuffer)
    }

    /// Cierra el archivo de cursor. El video lo cierra el escritor por su lado.
    func finish() {
        cursorTrack.finish()
    }
}
