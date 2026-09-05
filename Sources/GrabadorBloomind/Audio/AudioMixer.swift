import AVFoundation

/// Mezcla el micrófono y el audio del sistema en una sola pista.
///
/// Es la parte más delicada del proyecto (punto técnico 2 del plan). Tres cosas
/// la hacen difícil y las tres se resuelven acá:
///
/// 1. **Las dos fuentes llegan por separado y desalineadas.** Cada una entrega
///    bloques cuando quiere, de distinto tamaño, y el mismo instante de tiempo
///    llega en momentos distintos. Sumar "lo último de cada una" produce eco y
///    desfase.
/// 2. **Los formatos no coinciden.** El micrófono suele ser mono, el sistema
///    estéreo, y las frecuencias de muestreo pueden diferir. Sumar sin
///    homogeneizar produce ruido.
/// 3. **Las dos fuentes no valen lo mismo.** En una clase la voz manda sobre el
///    material de fondo, y medido el 2026-08-19 pasaba justo al revés: el
///    sistema entraba entre 5 y 9 dB por encima del micrófono (decisión 78).
///
/// La solución de los dos primeros es una línea de tiempo común: cada bloque se
/// escribe en la posición **absoluta** que le corresponde según su timestamp.
///
/// La del tercero es que cada fuente tenga su propio carril y que la suma ocurra
/// recién al emitir (decisión 85). Sumar de entrada haría irreversible la mezcla
/// dentro del propio mezclador, y entonces no se podría ni silenciar una fuente
/// sola ni bajar el sistema mientras se habla.
final class AudioMixer {

    enum Source {
        case microphone
        case system
    }

    /// Formato común al que se lleva todo antes de mezclar.
    static let sampleRate: Double = 48000
    static let channelCount: AVAudioChannelCount = 2

    /// Cuánto se espera antes de dar un tramo por cerrado. Es el margen para que
    /// llegue la fuente más lenta. Más corto acerca el audio al video pero
    /// arriesga perder bloques rezagados.
    private static let latency: Double = 0.25

    /// Tamaño de los carriles. Tiene que ser bastante mayor que la latencia.
    private static let bufferSeconds: Double = 4.0

    /// A partir de acá el limitador empieza a comprimir en vez de recortar.
    private static let limiterThreshold: Float = 0.7

    // MARK: - Perillas del ducking
    //
    // Las cuatro juntas y acá arriba a propósito: son lo que hay que tocar si
    // el ducking se siente brusco o perezoso, y no hay que buscarlas en el
    // medio del algoritmo. Los tiempos están en segundos.

    /// Cuánto tiene que superar el micrófono a su propio ruido de fondo para que
    /// cuente como voz. 4 son 12 dB.
    ///
    /// Es relativo y no absoluto a propósito: entre el micrófono interno del
    /// MacBook y el DJI por el iPhone hay más de 10 dB de diferencia, y un
    /// número fijo que sirve para uno deja al otro disparando con el ruido de la
    /// sala o sin disparar nunca. Medido el 2026-08-19: con umbral fijo el
    /// ducking quedó agachado el 88% de una clase.
    private static let voiceMargin: Float = 4

    /// Piso absoluto, para que en una sala mudísima cualquier crujido no cuente
    /// como voz.
    private static let duckThresholdFloor: Float = 0.010

    /// Qué tan rápido se adapta el piso de ruido **hacia arriba**. Muy lento a
    /// propósito: tiene que seguir el murmullo de la sala, no la voz. Hacia
    /// abajo sigue al instante, que es lo que lo hace enganchar rápido cuando la
    /// sala se calla.
    private static let noiseFloorRise: Double = 3.0

    /// A cuánto queda el audio del sistema mientras se habla. 0.25 son −12 dB.
    private static let duckLevel: Float = 0.25

    /// Qué tan rápido baja el sistema al empezar a hablar. Corto para no
    /// comerse la primera sílaba; demasiado corto hace un "clic" audible.
    private static let duckAttack: Double = 0.015

    /// Qué tan lento vuelve al soltar. Largo a propósito: si vuelve rápido, el
    /// sistema sube y baja entre palabra y palabra y se oye bombeando.
    private static let duckRelease: Double = 0.400

    /// Suavizado del detector de voz. El ataque corto engancha la primera
    /// sílaba, la caída larga evita que los silencios entre sílabas cuenten
    /// como "dejó de hablar".
    private static let envelopeAttack: Double = 0.005
    private static let envelopeRelease: Double = 0.150

    /// Se llama con cada bloque ya mezclado, en la misma cola en la que entró.
    private let onBlock: (CMSampleBuffer) -> Void

    private let format: AVAudioFormat
    private let capacity: Int

    /// Un carril por fuente, intercalado (izq, der, izq, der…). Se mezclan al
    /// emitir, no al escribir.
    private var micRing: [Float]
    private var systemRing: [Float]

    /// Silencio por fuente. Silenciar es ganancia cero, nunca dejar de escribir:
    /// si una fuente dejara de empujar la línea de tiempo, el tramo no se
    /// emitiría y el archivo quedaría con un hueco en vez de con silencio
    /// (decisión 81).
    private var micMuted = false
    private var systemMuted = false

    /// Posición absoluta, en frames desde el inicio, del primer frame todavía
    /// no emitido.
    private var emittedUpTo: Int = 0

    /// Posición absoluta más alta escrita por cualquiera de las dos fuentes.
    private var writtenUpTo: Int = 0

    /// Timestamp del primer bloque de cualquier fuente: el origen de la línea
    /// de tiempo común.
    private var origin: CMTime?

    /// Estado del ducking, que sobrevive entre bloques: si se reiniciara en cada
    /// uno, el sistema pegaría un salto de nivel en cada frontera de bloque.
    private var voiceEnvelope: Float = 0
    private var duckGain: Float = 1
    /// Ruido de fondo estimado del micrófono, contra el que se compara la voz.
    private var noiseFloor: Float = AudioMixer.duckThresholdFloor

    /// Cuántos frames se emitieron con el sistema agachado. Solo para el log:
    /// sirve para saber si el ducking está actuando de más o de menos sin tener
    /// que medir el archivo.
    private var duckedFrames: Int = 0
    private var emittedFrames: Int = 0

    private var converters: [String: AVAudioConverter] = [:]

    init(onBlock: @escaping (CMSampleBuffer) -> Void) {
        self.onBlock = onBlock
        self.format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: Self.channelCount,
            interleaved: true
        )!
        self.capacity = Int(Self.sampleRate * Self.bufferSeconds)
        let slots = capacity * Int(Self.channelCount)
        self.micRing = [Float](repeating: 0, count: slots)
        self.systemRing = [Float](repeating: 0, count: slots)
    }

    /// Silencia o reactiva una fuente. Se puede llamar desde el hilo principal
    /// mientras la cola de audio está escribiendo: lo peor que puede pasar es
    /// que el cambio se aplique un bloque más tarde.
    func setMuted(_ muted: Bool, for source: Source) {
        switch source {
        case .microphone: micMuted = muted
        case .system: systemMuted = muted
        }
    }

    func isMuted(_ source: Source) -> Bool {
        source == .microphone ? micMuted : systemMuted
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
        write(data, frames: frames, at: startFrame, channels: channels, into: source)

        writtenUpTo = max(writtenUpTo, startFrame + frames)
        emitCompleted()
    }

    /// Emite lo que quede pendiente. Se llama al detener la grabación.
    func flush() {
        emit(upTo: writtenUpTo)
        guard emittedFrames > 0 else { return }
        let porcentaje = Double(duckedFrames) / Double(emittedFrames) * 100
        Logger.shared.log("Mezcla cerrada: \(String(format: "%.1f", Double(emittedFrames) / Self.sampleRate))s de audio, sistema agachado el \(String(format: "%.0f", porcentaje))% del tiempo")
    }

    // MARK: - Interno

    /// Escribe un bloque ya convertido en el carril de su fuente.
    ///
    /// Las muestras anteriores a lo ya emitido se saltan: ese tramo del archivo
    /// ya se cerró y escribirlas ahí las pondría en el lugar equivocado.
    private func write(_ data: UnsafePointer<Float>, frames: Int, at startFrame: Int,
                       channels: Int, into source: Source) {
        let escribirEnMicrofono = (source == .microphone)
        for i in 0..<frames {
            let absolute = startFrame + i
            guard absolute >= emittedUpTo else { continue }
            let slot = (absolute % capacity) * channels
            for c in 0..<channels {
                let value = data[i * channels + c]
                if escribirEnMicrofono {
                    micRing[slot + c] += value
                } else {
                    systemRing[slot + c] += value
                }
            }
        }
    }

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

        // La clave describe el formato, no el objeto: `inputFormat` se construye
        // nuevo en cada bloque, así que indexar por identidad no acierta nunca y
        // termina creando un convertidor por bloque (decisión 79).
        let key = "\(asbd.pointee.mSampleRate)/\(asbd.pointee.mChannelsPerFrame)/\(asbd.pointee.mFormatFlags)/\(asbd.pointee.mBitsPerChannel)"
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

    /// Mezcla los dos carriles y emite el tramo.
    ///
    /// Acá es donde las fuentes dejan de ser independientes, y por eso acá van
    /// las tres cosas que las tratan distinto: el silencio, el ducking y el
    /// limitador, en ese orden.
    private func emit(upTo target: Int) {
        guard target > emittedUpTo, let origin else { return }

        // Nunca emitir más de lo que cabe en los carriles: si pasara, sería
        // porque una fuente se atrasó muchísimo, y es preferible perder un tramo
        // a escribir datos pisados.
        let from = max(emittedUpTo, target - capacity)
        let count = target - from
        guard count > 0 else { return }

        let channels = Int(Self.channelCount)
        var block = [Float](repeating: 0, count: count * channels)

        let attack = Self.coefficient(for: Self.duckAttack)
        let release = Self.coefficient(for: Self.duckRelease)
        let envAttack = Self.coefficient(for: Self.envelopeAttack)
        let envRelease = Self.coefficient(for: Self.envelopeRelease)
        let floorRise = Self.coefficient(for: Self.noiseFloorRise)

        for i in 0..<count {
            let slot = ((from + i) % capacity) * channels

            // El silencio se aplica acá y no al escribir: así vale para la
            // posición de la línea de tiempo y no para el momento en que llegó
            // el bloque, que no son lo mismo.
            var micLeft = micMuted ? 0 : micRing[slot]
            var micRight = micMuted ? 0 : micRing[slot + 1]
            let systemLeft = systemMuted ? 0 : systemRing[slot]
            let systemRight = systemMuted ? 0 : systemRing[slot + 1]

            // Detector de voz sobre el micrófono ya mezclado a mono: sube rápido
            // para enganchar la primera sílaba y baja lento para que los huecos
            // entre sílabas no cuenten como silencio.
            let voice = abs(micLeft + micRight) * 0.5
            let envCoef = voice > voiceEnvelope ? envAttack : envRelease
            voiceEnvelope += (voice - voiceEnvelope) * envCoef

            let umbral = max(noiseFloor * Self.voiceMargin, Self.duckThresholdFloor)

            // El ducking solo tiene sentido con las dos fuentes vivas. Con el
            // micrófono silenciado no hay voz que lo dispare, así que el sistema
            // se queda a nivel pleno solo.
            let hayVoz = voiceEnvelope > umbral
            let target: Float = hayVoz ? Self.duckLevel : 1

            // El piso de ruido persigue los silencios: baja al instante y sube
            // lentísimo, y **no sube mientras hay voz**. Sin esa última condición
            // una frase larga se va convirtiendo en "ruido de fondo", el umbral
            // la alcanza y el sistema vuelve a subir justo mientras se está
            // hablando.
            if voiceEnvelope < noiseFloor {
                noiseFloor = voiceEnvelope
            } else if !hayVoz {
                noiseFloor += (voiceEnvelope - noiseFloor) * floorRise
            }
            let duckCoef = target < duckGain ? attack : release
            duckGain += (target - duckGain) * duckCoef

            if duckGain < 0.99 { duckedFrames += 1 }

            micLeft += systemLeft * duckGain
            micRight += systemRight * duckGain

            block[i * channels] = Self.limit(micLeft)
            block[i * channels + 1] = Self.limit(micRight)

            // Limpiar al pasar: el frame ya se usó y su posición se va a
            // reciclar cuando los carriles den la vuelta.
            micRing[slot] = 0
            micRing[slot + 1] = 0
            systemRing[slot] = 0
            systemRing[slot + 1] = 0
        }

        emittedFrames += count

        let pts = CMTimeAdd(origin, CMTime(value: CMTimeValue(from), timescale: CMTimeScale(Self.sampleRate)))
        if let sampleBuffer = makeSampleBuffer(block, frames: count, at: pts) {
            onBlock(sampleBuffer)
        }
        emittedUpTo = target
    }

    /// Coeficiente de un suavizado exponencial de una constante de tiempo dada,
    /// aplicado muestra a muestra.
    private static func coefficient(for seconds: Double) -> Float {
        Float(1 - exp(-1 / (seconds * sampleRate)))
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
