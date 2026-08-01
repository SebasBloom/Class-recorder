import CoreGraphics
import Foundation

/// La zona censurada: dónde tapa, si está tapando ahora y con qué estilo.
///
/// **No persiste.** La zona vive mientras la app esté abierta y se dibuja de
/// nuevo en cada sesión (decisión 74). Es lo más seguro por defecto: nada de lo
/// que se tapa queda registrado en disco.
///
/// La zona se guarda en **coordenadas globales de macOS**, igual que el marco de
/// la burbuja, y el conversor la traduce a píxeles del video. Así la misma zona
/// sirve aunque cambie la resolución de captura.
///
/// La escribe el hilo principal y la lee la cola de captura: todo bajo candado.
final class RedactionSlot {

    private let lock = NSLock()
    private var _rect: CGRect?
    private var _isOn = false
    private var _style: RedactionStyle = .bloque

    /// Zona definida, o nil si todavía no se dibujó ninguna.
    var rect: CGRect? {
        lock.lock(); defer { lock.unlock() }
        return _rect
    }

    var isOn: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isOn
    }

    var style: RedactionStyle {
        lock.lock(); defer { lock.unlock() }
        return _style
    }

    /// La zona que hay que tapar **ahora**: nil si está apagada o sin zona
    /// definida. Es lo único que el compositor necesita saber.
    var activeRect: CGRect? {
        lock.lock(); defer { lock.unlock() }
        return _isOn ? _rect : nil
    }

    /// Fija la zona y prende la tapa.
    func setRect(_ rect: CGRect) {
        lock.lock()
        _rect = rect
        _isOn = true
        lock.unlock()
        // El log registra el evento, nunca la posición ni lo que había debajo.
        Logger.shared.log("Censura: zona definida y activada")
    }

    /// Prende o apaga la tapa. Devuelve el estado nuevo, o nil si no hay zona
    /// definida todavía: ahí el llamador tiene que abrir el selector.
    @discardableResult
    func toggle() -> Bool? {
        lock.lock()
        guard _rect != nil else { lock.unlock(); return nil }
        _isOn.toggle()
        let estado = _isOn
        lock.unlock()

        Logger.shared.log("Censura \(estado ? "activada" : "desactivada")")
        return estado
    }

    func setStyle(_ style: RedactionStyle) {
        lock.lock()
        _style = style
        lock.unlock()
        Logger.shared.log("Censura: estilo \(style.rawValue)")
    }

    /// Apaga la tapa sin olvidar la zona. Se llama al terminar la grabación: la
    /// próxima toma arranca destapada, pero sin obligar a redibujar.
    func turnOff() {
        lock.lock()
        let estaba = _isOn
        _isOn = false
        lock.unlock()
        if estaba { Logger.shared.log("Censura desactivada") }
    }
}
