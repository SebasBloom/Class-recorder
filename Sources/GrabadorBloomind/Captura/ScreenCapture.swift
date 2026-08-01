import ScreenCaptureKit
import AppKit

/// Una pantalla disponible para grabar, con lo que hace falta para mostrarla en
/// una lista y para configurar la captura.
struct CaptureDisplay {
    let scDisplay: SCDisplay
    let name: String
    /// Tamaño en píxeles reales, no en puntos: en una Retina son distintos y el
    /// archivo se escribe en píxeles.
    let pixelSize: CGSize
    /// Píxeles por punto. Hace falta para el área personalizada, que se define en
    /// puntos y se graba en píxeles.
    let scale: CGFloat
}

/// Captura de pantalla con ScreenCaptureKit.
///
/// Regla innegociable (decisión 3): todas las ventanas de la app quedan fuera de
/// la captura. Acá se logra excluyendo la aplicación entera y no ventanas sueltas,
/// que es lo que hace que también queden fuera las que se abran después de
/// arrancar la grabación.
final class ScreenCapture: NSObject, SCStreamOutput, SCStreamDelegate {

    /// Se llama con cada frame, en la cola de captura.
    var onFrame: ((CMSampleBuffer) -> Void)?

    /// Se llama con cada bloque de audio del micrófono, en la cola de audio.
    var onMicrophone: ((CMSampleBuffer) -> Void)?

    /// Se llama con cada bloque de audio del sistema, en la cola de audio.
    var onSystemAudio: ((CMSampleBuffer) -> Void)?

    /// Se llama si el stream se cae solo.
    var onStop: ((Error) -> Void)?

    private var stream: SCStream?
    private let outputQueue = DispatchQueue(label: "com.bloomind.grabador.captura")
    // Cola aparte para el audio: si el compositor se demora con un frame, el
    // audio no tiene por qué esperarlo.
    private let audioQueue = DispatchQueue(label: "com.bloomind.grabador.microfono")

    /// Lista las pantallas disponibles.
    static func availableDisplays() async throws -> [CaptureDisplay] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        return content.displays.map { display in
            let screen = NSScreen.screens.first {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
            }
            let scale = screen?.backingScaleFactor ?? 1
            let name = screen?.localizedName ?? "Pantalla \(display.displayID)"

            return CaptureDisplay(
                scDisplay: display,
                name: name,
                pixelSize: CGSize(width: CGFloat(display.width) * scale,
                                  height: CGFloat(display.height) * scale),
                scale: scale
            )
        }
    }

    /// - Parameters:
    ///   - audioMode: qué fuentes de audio se capturan.
    ///   - microphoneID: identificador del micrófono, solo si el modo lo usa.
    /// - Parameter area: zona de la pantalla a grabar, en coordenadas globales.
    ///   Nil graba la pantalla entera.
    func start(display: CaptureDisplay, audioMode: AudioMode, microphoneID: String?,
               area: CGRect? = nil) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Excluir la app entera, no ventanas puntuales: así el widget, el espejo
        // del tablero y la tarjeta de atajos quedan fuera aunque se abran a mitad
        // de grabación.
        let ownApplications = content.applications.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }

        let filter = SCContentFilter(
            display: display.scDisplay,
            excludingApplications: ownApplications,
            exceptingWindows: []
        )

        let configuration = SCStreamConfiguration()

        if let area, let recorte = Self.sourceRect(for: area, on: display) {
            // sourceRect va en **puntos** de la pantalla con origen arriba, no en
            // píxeles: es la única parte del proyecto donde ScreenCaptureKit no
            // habla en píxeles.
            configuration.sourceRect = recorte
            configuration.width = Int(recorte.width * display.scale)
            configuration.height = Int(recorte.height * display.scale)
        } else {
            configuration.width = Int(display.pixelSize.width)
            configuration.height = Int(display.pixelSize.height)
        }
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.showsCursor = true
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        // Cola corta: si el compositor se atrasa se descartan frames en vez de
        // acumularlos, que es lo que revienta la memoria en grabaciones largas.
        configuration.queueDepth = 5

        // El micrófono entra por el mismo stream que la pantalla. Es la razón por
        // la que el proyecto exige macOS 15: antes de Sequoia esto no existía.
        if audioMode.capturesMicrophone, let microphoneID {
            configuration.captureMicrophone = true
            configuration.microphoneCaptureDeviceID = microphoneID
        }

        if audioMode.capturesSystem {
            configuration.capturesAudio = true
            // Los sonidos de la propia app no entran al video. Sin esto, un aviso
            // del Grabador quedaría grabado en la clase.
            configuration.excludesCurrentProcessAudio = true
        }

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        if audioMode.capturesMicrophone, microphoneID != nil {
            try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: audioQueue)
        }
        if audioMode.capturesSystem {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        }
        try await stream.startCapture()
        self.stream = stream

        Logger.shared.log("Captura iniciada: \(display.name), \(configuration.width)x\(configuration.height) a 30 fps, excluyendo \(ownApplications.count) app(s) propia(s), audio: \(audioMode.label)")
    }

    func stop() async {
        guard let stream else { return }
        self.stream = nil
        try? await stream.stopCapture()
        Logger.shared.log("Captura detenida")
    }

    /// Convierte el área global a la que espera ScreenCaptureKit: puntos de la
    /// pantalla, origen arriba a la izquierda.
    static func sourceRect(for area: CGRect, on display: CaptureDisplay) -> CGRect? {
        guard let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
                == display.scDisplay.displayID
        }) else { return nil }

        let marco = screen.frame
        let recorte = CGRect(x: area.minX - marco.minX,
                             y: marco.height - (area.maxY - marco.minY),
                             width: area.width, height: area.height)
            .intersection(CGRect(origin: .zero, size: marco.size))

        guard !recorte.isNull, recorte.width >= 16, recorte.height >= 16 else { return nil }
        // Ancho y alto pares: un tamaño impar rompe el codificador de video.
        return CGRect(x: recorte.minX.rounded(), y: recorte.minY.rounded(),
                      width: (recorte.width / 2).rounded() * 2,
                      height: (recorte.height / 2).rounded() * 2)
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }

        if type == .microphone {
            onMicrophone?(sampleBuffer)
            return
        }

        if type == .audio {
            onSystemAudio?(sampleBuffer)
            return
        }

        guard type == .screen else { return }

        // ScreenCaptureKit manda frames "sin novedad" cuando la pantalla no
        // cambió. Escribirlos igual mantiene el ritmo del archivo; los que no
        // traen imagen sí se descartan.
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: raw)
        else { return }

        guard status == .complete else { return }

        onFrame?(sampleBuffer)
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Logger.shared.log("ERROR: la captura se detuvo sola: \(error.localizedDescription)")
        onStop?(error)
    }
}
