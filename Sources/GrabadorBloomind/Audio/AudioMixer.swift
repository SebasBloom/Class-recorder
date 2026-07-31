import AVFoundation

/// Suma el micrófono y el audio del sistema en una sola pista.
///
/// Es la parte más delicada del proyecto (punto técnico 2 del plan). Dos cosas
/// la hacen difícil y las dos se resuelven acá:
///
/// 1. **Las dos fuentes llegan por separado y desalineadas.** Cada una entrega
///    bloques cuando quiere, de distinto tamaño, y el mismo instante de tiempo
///    llega en momentos distintos. Sumar "lo último de cada una" produce eco y
///    desfase.
/// 2. **Los formatos no coinciden.** El micrófono suele ser mono, el sistema
///    estéreo, y las frecuencias de muestreo pueden diferir. Sumar sin
///    homogeneizar produce ruido.
///
/// La solución es una línea de tiempo común: cada bloque se escribe en la
/// posición **absoluta** que le corresponde según su timestamp, sumándose a lo
/// que ya haya ahí. Como mezclar es sumar, las dos fuentes se acumulan solas en
/// el mismo búfer sin necesidad de sincronizarlas entre sí.
final class AudioMixer {

    enum Source {
        case microphone
        case system
    }

    /// Formato común al que se lleva todo antes de sumar.
    static let sampleRate: Double = 48000
    static let channelCount: AVAudioChannelCount = 2

    /// Cuánto se espera antes de dar un tramo por cerrado. Es el margen para que
    /// llegue la fuente más lenta. Más corto acerca el audio al video pero
    /// arriesga perder bloques rezagados.
    private static let latency: Double = 0.25

    /// Tamaño del búfer circular. Tiene que ser bastante mayor que la latencia.
    private static let bufferSeconds: Double = 4.0

    /// A partir de acá el limitador empieza a comprimir en vez de recortar.
    private static let limiterThreshold: Float = 0.7

    /// Se llama con cada bloque ya mezclado, en la misma cola en la que entró.
    private let onBlock: (CMSampleBuffer) -> Void

    private let format: AVAudioFormat
    private let capacity: Int

    /// Búfer circular intercalado (izq, der, izq, der…). Las dos fuentes suman
    /// sobre él.
    private var ring: [Float]

    /// Posición absoluta, en frames desde el inicio, del primer frame todavía
    /// no emitido.
    private var emittedUpTo: Int = 0

    /// Posición absoluta más alta escrita por cualquiera de las dos fuentes.
    private var writtenUpTo: Int = 0

    /// Timestamp del primer bloque de cualquier fuente: el origen de la línea
    /// de tiempo común.
    private var origin: CMTime?

    private var converters: [ObjectIdentifier: AVAudioConverter] = [:]

    init(onBlock: @escaping (CMSampleBuffer) -> Void) {
        self.onBlock = onBlock
        self.format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: Self.channelCount,
            interleaved: true
        )!
        self.capacity = Int(Self.sampleRate * Self.bufferSeconds)
        self.ring = [Float](repeating: 0, count: capacity * Int(Self.channelCount))
    }

    /// Agrega un bloque de una fuente. Puede llamarse desde varias colas, pero
    /// siempre serializado por quien lo usa (en la app, la cola de audio).
    func add(_ sampleBuffer: CMSampleBuffer, from source: Source) {
        guard let converted = convert(sampleBuffer) else { return }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if origin == nil { origin = presentationTime }
        guard let origin else { return }

        let offset = CMTimeSubtract(presentationTime, origin).seconds
        let startFrame = Int((offset * Self.sampleRate).rounded())
        guard startFrame >= 0 else { return }

        let frames = Int(converted.frameLength)
        guard frames > 0, let data = converted.floatChannelData?[0] else { return }

        // Un bloque que llega tardísimo, después de que su tramo ya se emitió, se
        // descarta: meterlo ahora lo pondría en el lugar equivocado del archivo.
        guard startFrame + frames > emittedUpTo else { return }

        let channels = Int(Self.channelCount)
        for i in 0..<frames {
            let absolute = startFrame + i
            guard absolute >= emittedUpTo else { continue }
            let slot = (absolute % capacity) * channels
            for c in 0..<channels {
                ring[slot + c] += data[i * channels + c]
            }
        }

        writtenUpTo = max(writtenUpTo, startFrame + frames)
        emitCompleted()
    }

    /// Emite lo que quede pendiente. Se llama al detener la grabación.
    func flush() {
        emit(upTo: writtenUpTo)
    }

    // MARK: - Interno

    /// Lleva cualquier formato de entrada al formato común.
    private func convert(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription),
              let inputFormat = AVAudioFormat(streamDescription: asbd) else { return nil }

        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frames > 0,
              let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frames) else { return nil }
        input.frameLength = frames

        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer, at: 0, frameCount: Int32(frames), into: input.mutableAudioBufferList
        ) == noErr else { return nil }

        if inputFormat == format { return input }

        let key = ObjectIdentifier(inputFormat)
        let converter: AVAudioConverter
        if let existing = converters[key] {
            converter = existing
        } else {
            guard let made = AVAudioConverter(from: inputFormat, to: format) else { return nil }
            // Mono a estéreo: la misma señal a los dos canales, no un canal mudo.
            if inputFormat.channelCount == 1 {
                made.channelMap = [0, 0]
            }
            converters[key] = made
            converter = made
        }

        let ratio = format.sampleRate / inputFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(frames) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputCapacity) else { return nil }

        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return input
        }
        if let error {
            Logger.shared.log("ERROR convirtiendo audio para la mezcla: \(error.localizedDescription)")
            return nil
        }
        return output.frameLength > 0 ? output : nil
    }

    private func emitCompleted() {
        let safe = writtenUpTo - Int(Self.latency * Self.sampleRate)
        guard safe > emittedUpTo else { return }
        emit(upTo: safe)
    }

    private func emit(upTo target: Int) {
        guard target > emittedUpTo, let origin else { return }

        // Nunca emitir más de lo que cabe en el búfer circular: si pasara, sería
        // porque una fuente se atrasó muchísimo, y es preferible perder un tramo
        // a escribir datos pisados.
        let from = max(emittedUpTo, target - capacity)
        let count = target - from
        guard count > 0 else { return }

        let channels = Int(Self.channelCount)
        var block = [Float](repeating: 0, count: count * channels)

        for i in 0..<count {
            let slot = ((from + i) % capacity) * channels
            for c in 0..<channels {
                block[i * channels + c] = Self.limit(ring[slot + c])
                // Limpiar al pasar: el frame ya se usó y su posición se va a
                // reciclar cuando el búfer dé la vuelta.
                ring[slot + c] = 0
            }
        }

        let pts = CMTimeAdd(origin, CMTime(value: CMTimeValue(from), timescale: CMTimeScale(Self.sampleRate)))
        if let sampleBuffer = makeSampleBuffer(block, frames: count, at: pts) {
            onBlock(sampleBuffer)
        }
        emittedUpTo = target
    }

    /// Limitador suave: bajo el umbral no toca nada; por encima comprime con una
    /// curva en vez de recortar.
    ///
    /// Sumar dos fuentes fuertes se pasa de 1.0 y el recorte duro suena a
    /// distorsión sucia. Esto deja el pico justo por debajo del máximo.
    private static func limit(_ x: Float) -> Float {
        let magnitude = abs(x)
        guard magnitude > limiterThreshold else { return x }
        let excess = magnitude - limiterThreshold
        let room = 1.0 - limiterThreshold
        let compressed = limiterThreshold + room * tanh(excess / room)
        return x < 0 ? -compressed : compressed
    }

    private func makeSampleBuffer(_ samples: [Float], frames: Int, at pts: CMTime) -> CMSampleBuffer? {
        guard let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else { return nil }
        pcm.frameLength = AVAudioFrameCount(frames)
        samples.withUnsafeBufferPointer { source in
            pcm.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }

        var formatDescription: CMAudioFormatDescription?
        var asbd = format.streamDescription.pointee
        guard CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd,
                                             layoutSize: 0, layout: nil, magicCookieSize: 0,
                                             magicCookie: nil, extensions: nil,
                                             formatDescriptionOut: &formatDescription) == noErr else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(Self.sampleRate)),
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        guard CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
                                   makeDataReadyCallback: nil, refcon: nil,
                                   formatDescription: formatDescription, sampleCount: CMItemCount(frames),
                                   sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                                   sampleSizeEntryCount: 0, sampleSizeArray: nil,
                                   sampleBufferOut: &sampleBuffer) == noErr,
              let sampleBuffer else { return nil }

        guard CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer, blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault, flags: 0,
            bufferList: pcm.mutableAudioBufferList
        ) == noErr else { return nil }

        return sampleBuffer
    }
}
