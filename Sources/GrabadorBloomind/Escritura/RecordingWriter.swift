import AVFoundation

/// Escribe el archivo de salida.
///
/// Video HEVC por hardware en contenedor QuickTime (`.mov`) con fragmentos
/// periódicos: si el proceso muere a mitad de grabación, lo grabado hasta el
/// último fragmento sigue siendo reproducible (decisiones 10, 11 y 15).
final class RecordingWriter {

    enum WriterError: LocalizedError {
        case cannotCreateWriter(String)
        case cannotAddVideoInput
        case cannotAddAudioInput

        var errorDescription: String? {
            switch self {
            case .cannotCreateWriter(let detail): return "No se pudo crear el archivo de salida: \(detail)"
            case .cannotAddVideoInput: return "No se pudo preparar la pista de video."
            case .cannotAddAudioInput: return "No se pudo preparar la pista de audio."
            }
        }
    }

    /// Cada cuánto se cierra un fragmento. Más corto pierde menos ante un fallo,
    /// más largo pesa un poco menos. Cinco segundos es el punto de la Fase 1.
    private static let fragmentInterval = CMTime(seconds: 5, preferredTimescale: 600)

    /// Bits por píxel para HEVC. El contenido de pantalla comprime muy bien, así
    /// que este valor es bajo a propósito. Es la perilla para ajustar calidad
    /// contra tamaño de archivo, y vive solo acá.
    private static let bitsPerPixel = 0.09

    let outputURL: URL

    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private var audioInput: AVAssetWriterInput?

    private var didStartSession = false

    // Abstracción de pausa. La pausa real se usa desde la Fase 5, pero el
    // desplazamiento de timestamps nace acá para no rehacer el escritor después:
    // al reanudar, todos los buffers se corren hacia atrás por la duración de la
    // pausa, así el archivo no queda con un hueco.
    private(set) var isPaused = false
    /// Duración total pausada hasta ahora. El pipeline la usa para calcular el
    /// tiempo del video final, que es el que ve VideoFlow.
    private(set) var pausedTotal: CMTime = .zero
    private var pauseStartedAt: CMTime?

    /// - Parameter withAudio: si es falso no se crea la pista de audio. Las
    ///   pistas hay que declararlas antes de empezar a escribir, así que esto se
    ///   decide al iniciar la grabación y no se puede cambiar después.
    init(outputURL: URL, pixelSize: CGSize, withAudio: Bool) throws {
        self.outputURL = outputURL

        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        } catch {
            throw WriterError.cannotCreateWriter(error.localizedDescription)
        }

        // Fragmentos periódicos. shouldOptimizeForNetworkUse tiene que quedar en
        // falso: mueve el índice al principio del archivo al cerrar, que es justo
        // lo que no sirve si el proceso muere antes de cerrar.
        writer.movieFragmentInterval = Self.fragmentInterval
        writer.shouldOptimizeForNetworkUse = false

        let pixels = Double(pixelSize.width * pixelSize.height)
        let bitRate = Int(pixels * 30.0 * Self.bitsPerPixel)

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(pixelSize.width),
            AVVideoHeightKey: Int(pixelSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoExpectedSourceFrameRateKey: 30
            ]
        ])
        videoInput.expectsMediaDataInRealTime = true

        guard writer.canAdd(videoInput) else { throw WriterError.cannotAddVideoInput }
        writer.add(videoInput)

        if withAudio {
            // AAC 48 kHz según la decisión 10. Estéreo aunque el micrófono sea
            // mono: desde la Fase 4 entra el audio del sistema, que sí lo es, y
            // en la Fase 5 los dos comparten esta misma pista.
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128_000
            ])
            input.expectsMediaDataInRealTime = true
            guard writer.canAdd(input) else { throw WriterError.cannotAddAudioInput }
            writer.add(input)
            audioInput = input
        }

        guard writer.startWriting() else {
            throw WriterError.cannotCreateWriter(writer.error?.localizedDescription ?? "razón desconocida")
        }

        Logger.shared.log("Escritor listo: \(Int(pixelSize.width))x\(Int(pixelSize.height)), \(bitRate / 1_000_000) Mbps, fragmentos cada \(Int(Self.fragmentInterval.seconds))s, audio: \(withAudio ? "sí" : "no")")
    }

    /// Agrega un frame de video. Descarta en silencio mientras está en pausa o si
    /// el escritor todavía no puede recibir datos: encolar frames sin límite es
    /// la causa clásica de la app que se cae en el minuto 55.
    func append(_ sampleBuffer: CMSampleBuffer) {
        append(sampleBuffer, to: videoInput)
    }

    /// Agrega un bloque de audio. No hace nada si la grabación se inició sin
    /// pista de audio.
    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        guard let audioInput else { return }
        append(sampleBuffer, to: audioInput)
    }

    /// Camino común de las dos pistas.
    ///
    /// La sesión arranca con el **primer buffer que llegue de cualquier pista**,
    /// y todas las pistas referencian ese mismo origen. Si cada una arrancara su
    /// propio origen, el audio y el video quedarían desfasados por la diferencia
    /// entre sus primeras llegadas.
    private func append(_ sampleBuffer: CMSampleBuffer, to input: AVAssetWriterInput) {
        guard writer.status == .writing else { return }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if !didStartSession {
            writer.startSession(atSourceTime: presentationTime)
            didStartSession = true
            Logger.shared.log("Sesión de escritura iniciada")
        }

        guard !isPaused, input.isReadyForMoreMediaData else { return }

        if pausedTotal == .zero {
            input.append(sampleBuffer)
        } else if let shifted = shiftedBuffer(sampleBuffer, by: pausedTotal) {
            input.append(shifted)
        }
    }

    func pause(at time: CMTime) {
        guard !isPaused else { return }
        isPaused = true
        pauseStartedAt = time
        Logger.shared.log("Grabación pausada")
    }

    func resume(at time: CMTime) {
        guard isPaused, let start = pauseStartedAt else { return }
        pausedTotal = CMTimeAdd(pausedTotal, CMTimeSubtract(time, start))
        pauseStartedAt = nil
        isPaused = false
        Logger.shared.log("Grabación reanudada; pausa acumulada \(String(format: "%.1f", pausedTotal.seconds))s")
    }

    func finish(completion: @escaping () -> Void) {
        guard writer.status == .writing else {
            Logger.shared.log("El escritor no estaba escribiendo al detener (estado \(writer.status.rawValue))")
            completion()
            return
        }
        videoInput.markAsFinished()
        audioInput?.markAsFinished()
        writer.finishWriting {
            if let error = self.writer.error {
                Logger.shared.log("ERROR al cerrar el archivo: \(error.localizedDescription)")
            } else {
                Logger.shared.log("Archivo cerrado: \(self.outputURL.lastPathComponent)")
            }
            completion()
        }
    }

    /// Corre un buffer hacia atrás en el tiempo por la duración acumulada de las
    /// pausas.
    private func shiftedBuffer(_ buffer: CMSampleBuffer, by offset: CMTime) -> CMSampleBuffer? {
        var count: CMItemCount = 0
        guard CMSampleBufferGetSampleTimingInfoArray(buffer, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count) == noErr else { return nil }

        var timings = [CMSampleTimingInfo](repeating: .invalid, count: count)
        guard CMSampleBufferGetSampleTimingInfoArray(buffer, entryCount: count, arrayToFill: &timings, entriesNeededOut: nil) == noErr else { return nil }

        for i in 0..<count {
            timings[i].presentationTimeStamp = CMTimeSubtract(timings[i].presentationTimeStamp, offset)
            if timings[i].decodeTimeStamp.isValid {
                timings[i].decodeTimeStamp = CMTimeSubtract(timings[i].decodeTimeStamp, offset)
            }
        }

        var result: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: buffer,
            sampleTimingEntryCount: count,
            sampleTimingArray: &timings,
            sampleBufferOut: &result
        ) == noErr else { return nil }

        return result
    }
}
