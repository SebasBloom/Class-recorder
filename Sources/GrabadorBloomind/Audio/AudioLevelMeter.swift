import AVFoundation

/// Medidor de nivel del micrófono, para usar **antes** de grabar.
///
/// Existe por una razón muy concreta del plan: que Sebas no pierda una hora de
/// clase por haber elegido el micrófono equivocado. Con ver la barra moverse
/// mientras habla, sabe que el dispositivo capta.
///
/// Usa su propia `AVCaptureSession`, separada de la captura de la grabación. Es
/// a propósito: durante la grabación el micrófono entra por ScreenCaptureKit
/// junto con la pantalla, y levantar todo ese aparato solo para mostrar una
/// barra sería un desperdicio.
final class AudioLevelMeter: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {

    /// Nivel de 0 a 1, ya suavizado. Se entrega en el hilo principal.
    var onLevel: ((Float) -> Void)?

    private var session: AVCaptureSession?
    private let queue = DispatchQueue(label: "com.bloomind.grabador.nivel")

    /// Suavizado: sin esto la barra tiembla y no se lee. Sube rápido y baja
    /// lento, como cualquier medidor de audio decente.
    private var smoothedLevel: Float = 0

    /// El formato se registra una sola vez por sesión, para diagnóstico.
    private var didLogFormat = false

    /// Empieza a medir el dispositivo indicado. Si ya estaba midiendo otro, lo
    /// cambia.
    func start(deviceID: String) {
        stop()

        // Buscar el dispositivo por descubrimiento y no con AVCaptureDevice(uniqueID:),
        // que está en desuso y devuelve nil para algunos dispositivos nuevos.
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        guard let device = discovery.devices.first(where: { $0.uniqueID == deviceID }) else {
            Logger.shared.log("Medidor: no se encontró el micrófono \(deviceID)")
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device) else {
            Logger.shared.log("Medidor: no se pudo abrir \(device.localizedName). ¿Falta el permiso de micrófono?")
            return
        }

        let session = AVCaptureSession()
        guard session.canAddInput(input) else {
            Logger.shared.log("Medidor: la sesión no aceptó \(device.localizedName)")
            return
        }
        session.addInput(input)

        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        self.session = session
        didLogFormat = false
        // startRunning bloquea un instante; fuera del hilo principal para no
        // trabar la ventana al cambiar de micrófono.
        queue.async { session.startRunning() }
    }

    func stop() {
        guard let session else { return }
        self.session = nil
        smoothedLevel = 0
        Logger.shared.log("Medidor: micrófono liberado")
        queue.async { session.stopRunning() }
    }

    // MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        if !didLogFormat {
            didLogFormat = true
            if let asbd = Self.streamDescription(of: sampleBuffer) {
                let esFlotante = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
                Logger.shared.log("Medidor: formato \(Int(asbd.mSampleRate)) Hz, \(asbd.mChannelsPerFrame) canal(es), \(asbd.mBitsPerChannel) bits, \(esFlotante ? "flotante" : "entero")")
            }
        }

        guard let level = Self.peakLevel(of: sampleBuffer) else { return }

        // Ataque rápido, caída lenta.
        smoothedLevel = level > smoothedLevel
            ? level
            : smoothedLevel * 0.85 + level * 0.15

        let value = min(1, smoothedLevel)
        DispatchQueue.main.async { [weak self] in
            self?.onLevel?(value)
        }
    }

    // MARK: - Interno

    private static func streamDescription(of sampleBuffer: CMSampleBuffer) -> AudioStreamBasicDescription? {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format) else { return nil }
        return asbd.pointee
    }

    /// Pico de la muestra, convertido a una escala que se vea bien en una barra.
    ///
    /// El formato **no se asume**: se lee del buffer. En macOS la captura de
    /// audio entrega flotantes de 32 bits, no enteros de 16 como en otras
    /// plataformas, y dar por sentado lo segundo deja la barra muerta.
    private static func peakLevel(of sampleBuffer: CMSampleBuffer) -> Float? {
        guard let asbd = streamDescription(of: sampleBuffer),
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }

        var length = 0
        var pointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil,
                                          totalLengthOut: &length, dataPointerOut: &pointer) == noErr,
              let pointer, length > 0 else { return nil }

        let isFloat = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
        var linear: Float = 0

        if isFloat && asbd.mBitsPerChannel == 32 {
            let count = length / MemoryLayout<Float>.size
            pointer.withMemoryRebound(to: Float.self, capacity: count) { samples in
                for i in 0..<count {
                    let magnitude = abs(samples[i])
                    if magnitude > linear { linear = magnitude }
                }
            }
        } else if !isFloat && asbd.mBitsPerChannel == 16 {
            let count = length / MemoryLayout<Int16>.size
            var peak: Int16 = 0
            pointer.withMemoryRebound(to: Int16.self, capacity: count) { samples in
                for i in 0..<count {
                    let magnitude = samples[i] == Int16.min ? Int16.max : abs(samples[i])
                    if magnitude > peak { peak = magnitude }
                }
            }
            linear = Float(peak) / Float(Int16.max)
        } else {
            return nil
        }

        guard linear > 0 else { return 0 }

        // A decibelios y de vuelta a 0..1 sobre un rango de 50 dB: en lineal, la
        // voz normal casi no mueve la barra y no sirve para lo que existe.
        let decibels = 20 * log10(min(1, linear))
        return max(0, min(1, (decibels + 50) / 50))
    }
}
