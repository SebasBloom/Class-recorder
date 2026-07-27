import Foundation

/// Escribe el archivo `<mismo nombre>.cursor.json` que acompaña a cada video.
///
/// VideoFlow lo usa para el zoom automático en edición (decisión 6). Por eso las
/// coordenadas van en píxeles del video final y los tiempos en segundos del
/// video final: VideoFlow no necesita saber nada de macOS, ni de pausas, ni de
/// factores de escala.
final class CursorTrackWriter {

    private let outputURL: URL
    private let videoWidth: Int
    private let videoHeight: Int
    private let fps: Int

    private var events: [[String: Any]] = []

    /// Última posición registrada, para no escribir un evento por frame cuando el
    /// mouse está quieto.
    private var lastPoint: CGPoint?
    private var isOutside = false

    init(videoURL: URL, pixelSize: CGSize, fps: Int) {
        // "clase.mov" -> "clase.cursor.json"
        outputURL = videoURL.deletingPathExtension().appendingPathExtension("cursor.json")
        videoWidth = Int(pixelSize.width)
        videoHeight = Int(pixelSize.height)
        self.fps = fps
    }

    /// Registra lo ocurrido en un frame. Se llama una vez por frame.
    ///
    /// - Parameter cursor: posición en píxeles del video, o nil si el mouse está
    ///   en otra pantalla.
    func record(cursor: CGPoint?, clicks: [CGPoint], time: Double) {
        if let cursor {
            if isOutside {
                isOutside = false
            }
            // Solo se escribe cuando la posición cambió de verdad. El muestreo
            // sigue siendo a la cadencia del frame; esto solo evita repetir miles
            // de veces la misma coordenada cuando el mouse está quieto, que en
            // una clase de una hora son megas de JSON inútil.
            if lastPoint.map({ Int($0.x) != Int(cursor.x) || Int($0.y) != Int(cursor.y) }) ?? true {
                append(["t": rounded(time), "tipo": "mov",
                        "x": Int(cursor.x.rounded()), "y": Int(cursor.y.rounded())])
                lastPoint = cursor
            }
        } else if !isOutside {
            // El mouse se fue a la pantalla que no se está grabando.
            isOutside = true
            lastPoint = nil
            append(["t": rounded(time), "tipo": "fuera"])
        }

        for click in clicks {
            append(["t": rounded(time), "tipo": "click",
                    "x": Int(click.x.rounded()), "y": Int(click.y.rounded())])
        }
    }

    /// Registra un cambio de modo. Se usa desde la Fase 6, cuando existen los
    /// modos; VideoFlow los necesita para aplicar el zoom solo en los tramos de
    /// pantalla.
    func recordModeChange(to mode: CaptureMode, time: Double) {
        append(["t": rounded(time), "tipo": "modo", "valor": mode.rawValue])
    }

    /// Escribe el archivo. Se llama al cerrar la grabación.
    func finish() {
        let payload: [String: Any] = [
            "version": 1,
            "video": ["ancho": videoWidth, "alto": videoHeight, "fps": fps],
            "eventos": events
        ]

        do {
            let data = try JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .withoutEscapingSlashes]
            )
            try data.write(to: outputURL, options: .atomic)
            Logger.shared.log("Archivo de cursor escrito: \(outputURL.lastPathComponent), \(events.count) eventos")
        } catch {
            Logger.shared.log("ERROR escribiendo el archivo de cursor: \(error.localizedDescription)")
        }
    }

    // MARK: - Interno

    private func append(_ event: [String: Any]) {
        events.append(event)
    }

    /// Milisegundos alcanzan de sobra y el archivo queda legible a ojo.
    private func rounded(_ time: Double) -> Double {
        (time * 1000).rounded() / 1000
    }
}
