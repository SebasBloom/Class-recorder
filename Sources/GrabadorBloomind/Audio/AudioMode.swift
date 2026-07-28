import Foundation

/// Qué se graba en la pista de audio (plan, sección 8.2).
///
/// El valor en bruto es el que se guarda en `config.json`, por eso está en
/// español: ese archivo tiene que poder leerse a mano.
enum AudioMode: String, CaseIterable {
    case none = "sin-audio"
    case microphone = "microfono"
    case system = "sistema"
    /// Micrófono y sistema sumados en una sola pista. Llega en la Fase 5, que es
    /// la que trae la mezcla; hasta entonces no se ofrece en la interfaz.
    case mixed = "ambos"

    var label: String {
        switch self {
        case .none: return "Sin audio"
        case .microphone: return "Micrófono"
        case .system: return "Audio del sistema"
        case .mixed: return "Micrófono + sistema"
        }
    }

    /// Modos que la interfaz ofrece hoy.
    static var available: [AudioMode] { [.none, .microphone, .system] }

    var capturesMicrophone: Bool { self == .microphone || self == .mixed }
    var capturesSystem: Bool { self == .system || self == .mixed }
    var hasAudio: Bool { self != .none }
}
