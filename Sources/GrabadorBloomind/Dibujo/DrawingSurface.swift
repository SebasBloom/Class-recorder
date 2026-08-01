import CoreGraphics
import Foundation

/// Colores del marcador (plan, sección 8.7). Un atajo los rota.
enum MarkerColor: Int, CaseIterable {
    case rojo, amarillo, verde, blanco, negro

    var cgColor: CGColor {
        switch self {
        case .rojo:     return CGColor(red: 0.93, green: 0.22, blue: 0.18, alpha: 1)
        case .amarillo: return CGColor(red: 1.0, green: 215.0 / 255.0, blue: 0.0, alpha: 1)
        case .verde:    return CGColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1)
        case .blanco:   return CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        case .negro:    return CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        }
    }

    var label: String {
        switch self {
        case .rojo: return "rojo"
        case .amarillo: return "amarillo"
        case .verde: return "verde"
        case .blanco: return "blanco"
        case .negro: return "negro"
        }
    }

    var next: MarkerColor {
        MarkerColor(rawValue: (rawValue + 1) % MarkerColor.allCases.count) ?? .rojo
    }
}

/// Un trazo a mano alzada.
///
/// Los puntos van **normalizados** (0 a 1 sobre el ancho y el alto de la
/// superficie), no en píxeles ni en puntos de pantalla. Así el mismo modelo
/// sirve para la ventana espejo, que está en puntos, y para el frame del video,
/// que está en píxeles, sin pasar por ninguna conversión y sin poder desfasarse
/// entre los dos.
struct Stroke {
    var points: [CGPoint]
    var color: MarkerColor
}

/// Un cuadro de texto. El origen es la esquina de arriba a la izquierda,
/// normalizado igual que los trazos.
struct TextBox {
    var origin: CGPoint
    var text: String
    var color: MarkerColor
}

/// Lo dibujado, en el orden en que se dibujó. Deshacer saca el último, sea del
/// tipo que sea.
enum DrawingItem {
    case stroke(Stroke)
    case text(TextBox)
}

/// Una superficie de dibujo: el modelo de lo que hay dibujado encima.
///
/// **Motor único, contenidos separados por superficie.** Esta clase es el motor;
/// el tablero (Fase 7) y la capa de anotación sobre la pantalla real (Fase 8) son
/// dos instancias distintas. Borrar una nunca toca la otra.
///
/// La escribe el hilo principal (el mouse y el teclado) y la lee la cola de
/// captura (el compositor), así que todo pasa por un candado. Lo terminado y lo
/// que se está dibujando ahora se piden por separado a propósito: ver `version`.
final class DrawingSurface {

    private let lock = NSLock()
    private var _items: [DrawingItem] = []
    private var _liveStroke: Stroke?
    private var _version = 0

    /// Color activo del marcador. Es compartido entre superficies porque la
    /// paleta es una sola en la interfaz.
    private var _color: MarkerColor = .rojo

    /// Cambia con cada trazo terminado, deshacer o borrado, **no** mientras se
    /// está dibujando. El compositor la usa para saber si puede reusar su dibujo
    /// cacheado: sin esto tendría que repintar cientos de trazos en cada frame.
    var version: Int {
        lock.lock(); defer { lock.unlock() }
        return _version
    }

    var color: MarkerColor {
        lock.lock(); defer { lock.unlock() }
        return _color
    }

    var isEmpty: Bool {
        lock.lock(); defer { lock.unlock() }
        return _items.isEmpty && _liveStroke == nil
    }

    /// Lo ya terminado. El arreglo se copia por valor, que en Swift no cuesta
    /// nada hasta que alguien lo modifique.
    func committedItems() -> [DrawingItem] {
        lock.lock(); defer { lock.unlock() }
        return _items
    }

    /// El trazo en curso, que cambia con cada movimiento del mouse.
    func liveStroke() -> Stroke? {
        lock.lock(); defer { lock.unlock() }
        return _liveStroke
    }

    // MARK: - Edición

    func beginStroke(at point: CGPoint) {
        lock.lock()
        _liveStroke = Stroke(points: [point], color: _color)
        lock.unlock()
    }

    func extendStroke(to point: CGPoint) {
        lock.lock()
        _liveStroke?.points.append(point)
        lock.unlock()
    }

    /// Cierra el trazo en curso. Un trazo de un solo punto se descarta: eso no
    /// fue un trazo, fue un clic seco, y el clic seco crea un cuadro de texto.
    func endStroke() {
        lock.lock()
        if let stroke = _liveStroke, stroke.points.count > 1 {
            _items.append(.stroke(stroke))
            _version += 1
        }
        _liveStroke = nil
        lock.unlock()
    }

    func addTextBox(at origin: CGPoint) {
        lock.lock()
        _items.append(.text(TextBox(origin: origin, text: "", color: _color)))
        _version += 1
        lock.unlock()
    }

    /// Reescribe el texto del último cuadro. Se llama con cada tecla mientras el
    /// cuadro está activo.
    func updateLastText(_ text: String) {
        lock.lock()
        if case .text(var box)? = _items.last {
            box.text = text
            _items[_items.count - 1] = .text(box)
            _version += 1
        }
        lock.unlock()
    }

    /// Descarta el último cuadro de texto si quedó vacío. Se llama al cerrarlo:
    /// abrir un cuadro y arrepentirse no debe dejar basura invisible que después
    /// deshacer tenga que sacar a ciegas.
    func dropLastTextIfEmpty() {
        lock.lock()
        if case .text(let box)? = _items.last, box.text.isEmpty {
            _items.removeLast()
            _version += 1
        }
        lock.unlock()
    }

    func undo() {
        lock.lock()
        if !_items.isEmpty {
            _items.removeLast()
            _version += 1
        }
        lock.unlock()
    }

    /// Borra la superficie entera. Es una acción deliberada con su atajo y no
    /// pide confirmación, porque un diálogo en mitad de una clase interrumpe más
    /// de lo que protege. Deshacer no la revierte.
    func clear() {
        lock.lock()
        _items.removeAll()
        _liveStroke = nil
        _version += 1
        lock.unlock()
    }

    /// Fija el color sin rotar. La paleta es una sola en la interfaz, así que al
    /// rotarla en una superficie hay que igualar la otra.
    func setColor(_ color: MarkerColor) {
        lock.lock()
        _color = color
        lock.unlock()
    }

    @discardableResult
    func rotateColor() -> MarkerColor {
        lock.lock(); defer { lock.unlock() }
        _color = _color.next
        return _color
    }
}
