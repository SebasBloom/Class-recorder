import AppKit

/// Conversión de coordenadas: del espacio del mouse al espacio de píxeles del
/// frame que se está grabando.
///
/// Es la pieza más compartida del proyecto (ver `INTERDEPENDENCIAS.md`) y se
/// escribe una sola vez. Si el círculo aparece desfasado, el bug está acá.
///
/// Hay tres diferencias que hay que salvar y son la fuente de todos los errores
/// de este tipo:
///
/// 1. **Origen distinto.** macOS ubica el mouse con el origen abajo a la
///    izquierda; los píxeles de un frame se numeran desde arriba a la izquierda.
///    Hay que invertir el eje vertical.
/// 2. **Puntos contra píxeles.** En una pantalla Retina un punto son dos
///    píxeles. El mouse se reporta en puntos, el archivo se escribe en píxeles.
/// 3. **Cada pantalla tiene su propio espacio.** Con dos monitores, el
///    escritorio es un plano continuo donde cada pantalla ocupa un rectángulo, y
///    cada una puede tener un factor de escala distinto.
struct CoordinateConverter {

    /// Rectángulo de la pantalla grabada dentro del escritorio, en puntos y con
    /// origen abajo a la izquierda.
    let displayFrame: CGRect

    /// Píxeles por punto de esa pantalla. 2 en Retina, 1 en un monitor común.
    let scale: CGFloat

    /// Tamaño del frame en píxeles.
    var pixelSize: CGSize {
        CGSize(width: displayFrame.width * scale, height: displayFrame.height * scale)
    }

    /// Construcción directa, sin consultar el sistema. Existe para poder probar
    /// la conversión con pantallas inventadas, incluidas configuraciones de dos
    /// monitores que no se pueden reproducir a mano en cada prueba.
    init(displayFrame: CGRect, scale: CGFloat) {
        self.displayFrame = displayFrame
        self.scale = scale
    }

    /// Construye el conversor para la pantalla que se va a grabar.
    /// Devuelve nil si esa pantalla ya no está conectada.
    init?(displayID: CGDirectDisplayID) {
        guard let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
        }) else { return nil }

        displayFrame = screen.frame
        scale = screen.backingScaleFactor
    }

    /// Convierte una posición global del mouse a píxeles del frame.
    ///
    /// Devuelve nil si el mouse está fuera de la pantalla grabada: ese es el caso
    /// de "el mouse se fue al otro monitor", y el llamador lo trata como el
    /// evento `fuera` del JSON.
    func pixelPoint(fromGlobal point: CGPoint) -> CGPoint? {
        guard displayFrame.contains(point) else { return nil }

        // A coordenadas locales de la pantalla, todavía con origen abajo.
        let localX = point.x - displayFrame.minX
        let localYFromBottom = point.y - displayFrame.minY

        // Invertir el eje vertical y pasar a píxeles.
        let localYFromTop = displayFrame.height - localYFromBottom

        return CGPoint(x: localX * scale, y: localYFromTop * scale)
    }

    /// Convierte un rectángulo global (el marco de una ventana espejo) a píxeles
    /// del frame, con origen arriba a la izquierda.
    ///
    /// A diferencia del punto del cursor, acá **no** se exige que entre entero en
    /// la pantalla: la burbuja se puede arrastrar hasta salirse a medias por un
    /// borde, y en el video se ve la parte que quedó adentro. Devuelve nil solo
    /// si el rectángulo no toca la pantalla grabada en absoluto, que es "la
    /// burbuja se fue al otro monitor" y ahí no se compone nada.
    func pixelRect(fromGlobal rect: CGRect) -> CGRect? {
        guard displayFrame.intersects(rect) else { return nil }

        let localX = rect.minX - displayFrame.minX
        // El borde de arriba del rectángulo (maxY con origen abajo) es el que
        // marca la fila inicial cuando se numera desde arriba.
        let localTop = displayFrame.height - (rect.maxY - displayFrame.minY)

        return CGRect(x: localX * scale, y: localTop * scale,
                      width: rect.width * scale, height: rect.height * scale)
    }
}
