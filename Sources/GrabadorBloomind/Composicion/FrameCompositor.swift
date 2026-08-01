import CoreGraphics
import CoreVideo
import Foundation

/// Modo de fuente del video. Define qué se ve de fondo en el frame.
///
/// En la Fase 2 solo existe `pantalla`; `camara` y `tablero` llegan en las
/// Fases 6 y 7. El enum nace ahora para que la matriz de visibilidad de la
/// sección 8.4 del plan viva en un solo lugar desde el principio.
enum CaptureMode: String {
    case pantalla
    case camara
    case tablero
}

/// Capas que se componen sobre el fondo.
enum CompositionLayer {
    case cursorCircle
    case clickEffect
    case cameraBubble
    case redaction
    case screenAnnotation
    case whiteboardContent
}

/// Matriz de visibilidad de la sección 8.4 del plan, implementada tal cual.
///
/// El estado de cada capa se conserva al cambiar de modo; esto solo decide qué
/// se dibuja en cada momento.
func isVisible(_ layer: CompositionLayer, in mode: CaptureMode) -> Bool {
    switch (layer, mode) {
    case (.cursorCircle, .pantalla), (.cursorCircle, .tablero): return true
    case (.clickEffect, .pantalla), (.clickEffect, .tablero): return true
    case (.cameraBubble, .pantalla), (.cameraBubble, .tablero): return true
    case (.redaction, .pantalla): return true
    case (.screenAnnotation, .pantalla): return true
    case (.whiteboardContent, .tablero): return true
    default: return false
    }
}

/// Dibuja las capas sobre cada frame antes de escribirlo.
///
/// Dibuja **dentro del mismo buffer** que llegó de la captura, sin crear uno
/// nuevo por frame. Esa es la diferencia entre una app que aguanta una hora y
/// una que se cae en el minuto 55.
final class FrameCompositor {

    /// Amarillo del plan (#FFD700) y sus opacidades.
    private static let circleFillAlpha: CGFloat = 0.60
    private static let circleStrokeAlpha: CGFloat = 0.85

    /// Diámetro del círculo como fracción del alto del frame, para que se vea
    /// igual de grande en 1080p que en Retina. Es la perilla del tamaño.
    private static let circleDiameterRatio: CGFloat = 0.040

    /// Duración de la onda del clic y cuánto crece respecto al círculo fijo.
    private static let rippleDuration: Double = 0.35
    private static let rippleMaxScale: CGFloat = 2.4

    /// Redondeo de la burbuja como fracción de su lado corto. Calza con las 14
    /// esquinas en puntos de la ventana espejo, para que lo que se ve en pantalla
    /// y lo que queda en el video tengan la misma forma.
    private static let bubbleCornerRatio: CGFloat = 0.08

    private let pixelSize: CGSize
    private let circleDiameter: CGFloat

    /// Ondas de clic en curso, con el momento del video en que empezaron.
    private var ripples: [(center: CGPoint, startTime: Double)] = []

    init(pixelSize: CGSize) {
        self.pixelSize = pixelSize
        self.circleDiameter = pixelSize.height * Self.circleDiameterRatio
    }

    /// Compone las capas sobre el frame.
    ///
    /// - Parameters:
    ///   - cursor: posición del cursor en píxeles del frame, o nil si el mouse
    ///     está en otra pantalla (ahí no se dibuja nada).
    ///   - newClicks: clics ocurridos desde el frame anterior, ya convertidos.
    ///   - camera: última imagen de la cámara, o nil si no hay cámara elegida.
    ///   - bubbleRect: dónde va la burbuja, en píxeles del frame y con origen
    ///     arriba. Nil si la burbuja está apagada o se arrastró a otro monitor.
    ///   - time: segundos transcurridos del video final.
    func draw(into pixelBuffer: CVPixelBuffer,
              mode: CaptureMode,
              cursor: CGPoint?,
              newClicks: [CGPoint],
              camera: CGImage?,
              bubbleRect: CGRect?,
              time: Double) {

        if isVisible(.clickEffect, in: mode) {
            for click in newClicks {
                ripples.append((center: click, startTime: time))
            }
        }
        ripples.removeAll { time - $0.startTime > Self.rippleDuration }

        let drawCursor = isVisible(.cursorCircle, in: mode) && cursor != nil
        let drawBubble = isVisible(.cameraBubble, in: mode) && camera != nil && bubbleRect != nil
        // En modo cámara completa la cámara **es** el fondo, así que se dibuja
        // aunque no haya ninguna otra capa encima.
        let drawFullCamera = mode == .camara && camera != nil

        guard drawCursor || drawBubble || drawFullCamera || !ripples.isEmpty else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer),
              let context = CGContext(
                data: base,
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              )
        else { return }

        context.setShouldAntialias(true)

        // El fondo va primero: en modo cámara completa la imagen de la cámara
        // tapa la pantalla capturada, recortada al centro para llenar el cuadro.
        if drawFullCamera, let camera {
            context.interpolationQuality = .low
            context.draw(camera, in: Self.fillRect(imageSize: CGSize(width: camera.width, height: camera.height),
                                                   in: CGRect(origin: .zero, size: pixelSize)))
        }

        // Las ondas van debajo del círculo fijo, para que el círculo siempre se
        // lea claro aunque coincidan.
        for ripple in ripples {
            drawRipple(ripple, at: time, in: context)
        }

        if drawCursor, let cursor {
            drawCursorCircle(at: cursor, in: context)
        }

        if drawBubble, let camera, let bubbleRect {
            drawCameraBubble(camera, in: bubbleRect, context: context)
        }
    }

    /// Descarta las ondas en curso. Se llama al reiniciar una toma.
    func reset() {
        ripples.removeAll()
    }

    // MARK: - Dibujo

    /// El contexto de bitmap tiene el origen abajo a la izquierda, pero la fila 0
    /// de la memoria es la de arriba de la pantalla. Esta función traduce una
    /// coordenada de píxel (origen arriba) a la del contexto.
    private func flipped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: pixelSize.height - point.y)
    }

    private func drawCursorCircle(at point: CGPoint, in context: CGContext) {
        let center = flipped(point)
        let radius = circleDiameter / 2
        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                          width: circleDiameter, height: circleDiameter)

        context.setFillColor(gold(Self.circleFillAlpha))
        context.fillEllipse(in: rect)

        context.setStrokeColor(gold(Self.circleStrokeAlpha))
        context.setLineWidth(max(1, circleDiameter * 0.08))
        context.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))
    }

    /// Onda del clic: un anillo que crece y se desvanece. Visualmente distinto
    /// del círculo fijo, como pide la sección 8.5.
    private func drawRipple(_ ripple: (center: CGPoint, startTime: Double),
                            at time: Double,
                            in context: CGContext) {
        let progress = CGFloat((time - ripple.startTime) / Self.rippleDuration)
        guard progress >= 0, progress <= 1 else { return }

        let scale = 0.7 + (Self.rippleMaxScale - 0.7) * progress
        let diameter = circleDiameter * scale
        let center = flipped(ripple.center)
        let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                          width: diameter, height: diameter)

        context.setStrokeColor(gold(0.9 * (1 - progress)))
        context.setLineWidth(max(1, circleDiameter * 0.10 * (1 - progress * 0.5)))
        context.strokeEllipse(in: rect)
    }

    /// Burbuja de cámara: rectángulo de esquinas redondeadas con la imagen
    /// dentro y una línea fina alrededor, igual que el espejo que Sebas ve.
    ///
    /// `rect` llega en píxeles con origen arriba, como todo lo que sale del
    /// conversor de coordenadas; acá se pasa al origen abajo del contexto. La
    /// imagen en sí no se voltea: `CGContext.draw` ya pone la primera fila de la
    /// imagen en la parte de arriba del rectángulo.
    private func drawCameraBubble(_ image: CGImage, in rect: CGRect, context: CGContext) {
        let target = CGRect(x: rect.minX, y: pixelSize.height - rect.maxY,
                            width: rect.width, height: rect.height)
        let radius = min(target.width, target.height) * Self.bubbleCornerRatio
        let path = CGPath(roundedRect: target, cornerWidth: radius, cornerHeight: radius, transform: nil)

        context.saveGState()
        context.addPath(path)
        context.clip()
        context.interpolationQuality = .medium
        context.draw(image, in: Self.fillRect(imageSize: CGSize(width: image.width, height: image.height),
                                              in: target))
        context.restoreGState()

        context.addPath(path)
        context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.25))
        context.setLineWidth(max(1, target.height * 0.008))
        context.strokePath()
    }

    /// Rectángulo donde dibujar una imagen para que **llene** el destino sin
    /// deformarse: se escala por el lado que falte y lo que sobra del otro se
    /// sale por los dos costados iguales, o sea recorte centrado.
    ///
    /// Es la fórmula del modo cámara completa de la sección 8.4 y de la burbuja.
    /// Vive suelta y pura para poder probarla sin cámara (`./probar.sh`).
    static func fillRect(imageSize: CGSize, in target: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return target }

        let scale = max(target.width / imageSize.width, target.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        return CGRect(x: target.midX - size.width / 2,
                      y: target.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    /// #FFD700 con la opacidad pedida.
    private func gold(_ alpha: CGFloat) -> CGColor {
        CGColor(red: 1.0, green: 215.0 / 255.0, blue: 0.0, alpha: alpha)
    }
}
