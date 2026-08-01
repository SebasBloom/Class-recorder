import AVFoundation

/// Captura de la cámara con AVCaptureSession.
///
/// Corre **siempre a la resolución completa del dispositivo** (decisión 7),
/// aunque solo se vea en una burbuja chiquita: el modo cámara completa necesita
/// esa resolución y así el cambio de modo es un corte instantáneo, sin
/// reconfigurar nada.
///
/// Entrega dos cosas a la vez: una capa de previsualización para la ventana
/// espejo, y la última imagen para que el compositor la dibuje en el frame.
final class CameraCapture {

    /// Se avisa en el hilo principal si la cámara se cae sola.
    var onInterruption: (() -> Void)?

    let device: CameraDevice

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.bloomind.grabador.camara")
    private let delegate = FrameDelegate()
    private var observers: [NSObjectProtocol] = []

    /// Última imagen de la cámara, lista para dibujar. La escribe la cola de la
    /// cámara y la lee la cola de captura, bajo candado.
    ///
    /// Se convierte a `CGImage` acá y no en el compositor por dos razones: la
    /// conversión sale de la cola de captura, que es la que no se puede atrasar,
    /// y así nunca se retiene un `CVPixelBuffer` de la cámara más allá de su
    /// procesamiento. En memoria queda una sola imagen viva.
    var latestImage: CGImage? { delegate.latestImage }

    /// Capa de previsualización para la ventana espejo. Es la misma sesión, sin
    /// costo extra de captura.
    func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    /// Proporción ancho/alto de la cámara, para que la ventana espejo tenga la
    /// misma forma que la burbuja del video.
    private(set) var aspectRatio: CGFloat = 16.0 / 9.0

    init?(device: CameraDevice) {
        self.device = device

        guard let captureDevice = AVCaptureDevice(uniqueID: device.uniqueID),
              let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            Logger.shared.log("ERROR: no se pudo abrir la cámara \(device.name)")
            return nil
        }

        session.addInput(input)

        // Elegir `activeFormat` a mano manda sobre el preset de la sesión: macOS
        // pasa sola a prioridad de entrada y deja de reconfigurar la cámara. Por
        // eso el formato se fija **después** de agregar la entrada.
        if let format = Self.fullResolutionFormat(of: captureDevice) {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            try? captureDevice.lockForConfiguration()
            captureDevice.activeFormat = format
            captureDevice.unlockForConfiguration()
            aspectRatio = CGFloat(dimensions.width) / CGFloat(dimensions.height)
            Logger.shared.log("Cámara \(device.name) a \(dimensions.width)x\(dimensions.height)")
        }

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        // Si el compositor se atrasa se descartan frames de cámara en vez de
        // encolarlos: la memoria no crece y la imagen sigue siendo la última.
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(delegate, queue: queue)
        session.addOutput(output)

        observeInterruptions()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func start() {
        guard !session.isRunning else { return }
        // startRunning bloquea; fuera del hilo principal para no congelar la UI.
        queue.async { [session] in session.startRunning() }
    }

    func stop() {
        guard session.isRunning else { return }
        queue.async { [session] in session.stopRunning() }
        delegate.clear()
    }

    // MARK: - Interno

    /// El formato de mayor resolución que sostenga 30 fps. Sin el filtro de fps
    /// algunas cámaras ofrecen formatos enormes a 10 cuadros por segundo, que se
    /// verían a tirones en el video.
    private static func fullResolutionFormat(of device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        device.formats
            .filter { $0.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 30 } }
            .max { a, b in
                let da = CMVideoFormatDescriptionGetDimensions(a.formatDescription)
                let db = CMVideoFormatDescriptionGetDimensions(b.formatDescription)
                return Int(da.width) * Int(da.height) < Int(db.width) * Int(db.height)
            }
    }

    /// Resiliencia de hardware: si la cámara se cae a mitad de grabación (el
    /// iPhone se bloquea, alguien desenchufa la webcam), se avisa y la grabación
    /// sigue. La desconexión física la ve `RecordingController`; acá se atienden
    /// las interrupciones de la sesión, que es como se manifiesta el iPhone que
    /// se va.
    private func observeInterruptions() {
        let center = NotificationCenter.default
        for name in [AVCaptureSession.wasInterruptedNotification, AVCaptureSession.runtimeErrorNotification] {
            let observer = center.addObserver(forName: name, object: session, queue: .main) { [weak self] _ in
                self?.delegate.clear()
                self?.onInterruption?()
            }
            observers.append(observer)
        }
    }

    /// Recibe los frames en la cola de la cámara y guarda el último convertido.
    private final class FrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

        private let lock = NSLock()
        private var _latestImage: CGImage?

        var latestImage: CGImage? {
            lock.lock()
            defer { lock.unlock() }
            return _latestImage
        }

        func clear() {
            lock.lock()
            _latestImage = nil
            lock.unlock()
        }

        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
            autoreleasepool {
                guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

                CVPixelBufferLockBaseAddress(buffer, .readOnly)
                defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

                guard let base = CVPixelBufferGetBaseAddress(buffer),
                      let context = CGContext(
                        data: base,
                        width: CVPixelBufferGetWidth(buffer),
                        height: CVPixelBufferGetHeight(buffer),
                        bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                      ),
                      let image = context.makeImage()
                else { return }

                lock.lock()
                _latestImage = image
                lock.unlock()
            }
        }
    }
}
