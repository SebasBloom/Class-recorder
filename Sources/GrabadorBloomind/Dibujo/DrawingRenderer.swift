import CoreGraphics
import CoreText
import Foundation

/// Dibuja una superficie en un contexto.
///
/// Es **una sola implementación** para los dos destinos: la ventana espejo que
/// Sebas ve en su pantalla y el frame que va al archivo. Si cada uno dibujara por
/// su lado, tarde o temprano se verían distinto y el error aparecería recién al
/// revisar el video, cuando la clase ya pasó.
///
/// Los dos contextos tienen el origen abajo a la izquierda, y el modelo guarda
/// todo normalizado con el origen arriba, así que la conversión vive acá y una
/// sola vez.
enum DrawingRenderer {

    /// Grosor del trazo como fracción del alto. Fijo en la v1 (plan, 8.7), pero
    /// proporcional a la resolución para que se vea igual en 1080p que en Retina.
    private static let strokeWidthRatio: CGFloat = 0.005

    /// Tamaño del texto, también como fracción del alto.
    private static let fontSizeRatio: CGFloat = 0.038

    /// Fondo del tablero: lienzo blanco (plan, 8.4).
    static func fillWhiteboard(_ context: CGContext, size: CGSize) {
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
    }

    /// - Parameter caretOnLast: dibuja el cursor de escritura al final del último
    ///   cuadro de texto. Se usa solo en la ventana espejo: en el video el cursor
    ///   parpadeante no aporta nada y ensucia.
    static func draw(items: [DrawingItem],
                     liveStroke: Stroke?,
                     in context: CGContext,
                     size: CGSize,
                     caretOnLast: Bool = false) {

        context.setLineCap(.round)
        context.setLineJoin(.round)

        for (index, item) in items.enumerated() {
            switch item {
            case .stroke(let stroke):
                draw(stroke, in: context, size: size)
            case .text(let box):
                let isLast = index == items.count - 1
                draw(box, in: context, size: size, caret: caretOnLast && isLast)
            }
        }

        if let liveStroke {
            draw(liveStroke, in: context, size: size)
        }
    }

    // MARK: - Interno

    /// Normalizado con origen arriba, a coordenadas del contexto con origen abajo.
    private static func point(_ normalized: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: normalized.x * size.width,
                y: size.height - normalized.y * size.height)
    }

    private static func draw(_ stroke: Stroke, in context: CGContext, size: CGSize) {
        guard let first = stroke.points.first else { return }

        context.setStrokeColor(stroke.color.cgColor)
        context.setLineWidth(max(1, size.height * strokeWidthRatio))

        context.beginPath()
        context.move(to: point(first, in: size))
        for p in stroke.points.dropFirst() {
            context.addLine(to: point(p, in: size))
        }
        context.strokePath()
    }

    /// Dónde termina la última línea escrita, para poner el cursor ahí. Con
    /// texto que se corta en varias líneas, el final ya no es "el ancho del
    /// texto" sino el ancho de la última.
    private static func caretPosition(after frame: CTFrame, fallback: CGPoint) -> CGPoint {
        guard let lines = CTFrameGetLines(frame) as? [CTLine], let last = lines.last else {
            return fallback
        }
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        guard let lastOrigin = origins.last else { return fallback }

        let width = CGFloat(CTLineGetTypographicBounds(last, nil, nil, nil))
        return CGPoint(x: lastOrigin.x + width, y: lastOrigin.y)
    }

    private static func draw(_ box: TextBox, in context: CGContext, size: CGSize, caret: Bool) {
        let fontSize = size.height * fontSizeRatio
        let origin = point(box.origin, in: size)
        // El origen del cuadro es su esquina de arriba; el texto se dibuja desde
        // su línea base, que queda un tamaño de fuente más abajo.
        let baseline = CGPoint(x: origin.x, y: origin.y - fontSize)

        var caretAt = baseline
        if !box.text.isEmpty {
            // Las claves de CoreText y no las de AppKit a propósito: este
            // renderizador lo llama el compositor desde la cola de captura, y no
            // tiene por qué arrastrar AppKit para escribir una línea de texto.
            let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
            let attributed = NSAttributedString(string: box.text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): box.color.cgColor
            ])

            // El texto se corta en el borde y sigue en la línea de abajo. Sin
            // esto, una frase larga se sale de la pantalla por la derecha y lo
            // que se escribió de más se pierde, cosa que pasó de verdad en la
            // prueba de la Fase 7 (decisión 59).
            let margin = fontSize * 0.5
            let available = CGRect(x: origin.x,
                                   y: margin,
                                   width: max(fontSize, size.width - origin.x - margin),
                                   height: max(fontSize, origin.y - margin))

            let framesetter = CTFramesetterCreateWithAttributedString(attributed)
            let frame = CTFramesetterCreateFrame(framesetter,
                                                 CFRange(location: 0, length: 0),
                                                 CGPath(rect: available, transform: nil),
                                                 nil)
            CTFrameDraw(frame, context)
            caretAt = caretPosition(after: frame, fallback: baseline)
        }

        guard caret else { return }
        context.setFillColor(box.color.cgColor)
        context.fill(CGRect(x: caretAt.x + fontSize * 0.06,
                            y: caretAt.y - fontSize * 0.2,
                            width: max(1, fontSize * 0.06),
                            height: fontSize))
    }
}
