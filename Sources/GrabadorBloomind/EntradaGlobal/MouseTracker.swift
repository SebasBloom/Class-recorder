import AppKit

/// Seguimiento global del mouse: dónde está y cuándo se hace clic.
///
/// La posición se guarda con cada evento de movimiento, no se consulta desde la
/// cola de captura: AppKit hay que tocarlo desde el hilo principal, y los frames
/// llegan en otra cola. El compositor lee la última posición conocida a través
/// de un candado, que es barato comparado con dibujar un frame.
///
/// Nota de permisos: los monitores globales de **mouse** no necesitan permiso de
/// Accesibilidad. El de teclado sí, y por eso los atajos globales llegan recién
/// en la Fase 9.
final class MouseTracker {

    /// Un clic ya ocurrido, con el momento en que pasó.
    struct Click {
        let location: CGPoint
        let timestamp: Date
    }

    private var monitors: [Any] = []
    private let lock = NSLock()

    private var _location: CGPoint = .zero
    private var _pendingClicks: [Click] = []

    /// Última posición conocida del mouse, en coordenadas globales de macOS.
    var location: CGPoint {
        lock.lock()
        defer { lock.unlock() }
        return _location
    }

    @MainActor
    func start() {
        _location = NSEvent.mouseLocation

        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: moves, handler: { [weak self] _ in
            self?.updateLocation()
        }) {
            monitors.append(monitor)
        }

        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: clicks, handler: { [weak self] _ in
            self?.registerClick()
        }) {
            monitors.append(monitor)
        }

        // Los monitores globales **no** ven los eventos que van a nuestras propias
        // ventanas. Sin estos dos locales, el círculo se quedaba clavado en el
        // último punto de afuera mientras el mouse pasaba por el control, la
        // burbuja o el widget, y en el video se veía como un círculo trabado.
        // El evento se devuelve tal cual: mirar no es interceptar.
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: moves, handler: { [weak self] event in
            self?.updateLocation()
            return event
        }) {
            monitors.append(monitor)
        }

        if let monitor = NSEvent.addLocalMonitorForEvents(matching: clicks, handler: { [weak self] event in
            self?.registerClick()
            return event
        }) {
            monitors.append(monitor)
        }

        Logger.shared.log("Seguimiento del mouse iniciado")
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        lock.lock()
        _pendingClicks.removeAll()
        lock.unlock()
        Logger.shared.log("Seguimiento del mouse detenido")
    }

    /// Devuelve los clics ocurridos desde la última consulta y los saca de la
    /// cola. El compositor los llama una vez por frame.
    func drainClicks() -> [Click] {
        lock.lock()
        defer { lock.unlock() }
        let clicks = _pendingClicks
        _pendingClicks.removeAll(keepingCapacity: true)
        return clicks
    }

    // MARK: - Interno

    private func updateLocation() {
        let point = NSEvent.mouseLocation
        lock.lock()
        _location = point
        lock.unlock()
    }

    private func registerClick() {
        let point = NSEvent.mouseLocation
        lock.lock()
        _location = point
        // Tope de seguridad: si por lo que sea nadie está consumiendo los clics,
        // no se acumulan sin límite.
        if _pendingClicks.count < 64 {
            _pendingClicks.append(Click(location: point, timestamp: Date()))
        }
        lock.unlock()
    }
}
