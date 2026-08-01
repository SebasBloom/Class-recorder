import Carbon.HIToolbox
import Foundation

/// Atajo global de teclado.
///
/// Usa `RegisterEventHotKey` de Carbon y no un monitor global de eventos a
/// propósito: el monitor de teclado exige permiso de Accesibilidad, y este no.
/// Son cuatro permisos los que la app pide (plan, sección 5) y este camino evita
/// pedir el cuarto para algo que el sistema ya sabe hacer.
///
/// En la Fase 6 hay dos atajos fijos para cambiar de modo. El registro central
/// reasignable de la Fase 9 se construye encima de esta pieza.
final class HotKey {

    /// Se llama en el hilo principal cuando se presiona la combinación.
    private let action: () -> Void
    /// Se llama al soltarla. Lo usa la tarjeta de atajos, que se muestra mientras
    /// la combinación se mantiene apretada.
    private let release: (() -> Void)?

    private var reference: EventHotKeyRef?
    private let id: UInt32

    private static var handler: EventHandlerRef?
    private static var nextID: UInt32 = 1

    /// El registro guarda referencias **débiles** a propósito: quien crea el
    /// atajo es su único dueño, y soltarlo tiene que desregistrarlo. Con
    /// referencias fuertes acá, `deinit` no correría nunca y los atajos de una
    /// grabación seguirían vivos después de detenerla, duplicándose en la
    /// siguiente.
    private static var registry: [UInt32: WeakHotKey] = [:]

    private final class WeakHotKey {
        weak var hotKey: HotKey?
        init(_ hotKey: HotKey) { self.hotKey = hotKey }
    }

    /// - Parameters:
    ///   - keyCode: código virtual de la tecla (`kVK_ANSI_1`, etc.).
    ///   - modifiers: máscara de Carbon (`optionKey`, `cmdKey`…).
    init(keyCode: Int, modifiers: Int, action: @escaping () -> Void, release: (() -> Void)? = nil) {
        self.action = action
        self.release = release
        self.id = Self.nextID
        Self.nextID += 1

        Self.installHandlerIfNeeded()
        Self.registry[id] = WeakHotKey(self)

        let hotKeyID = EventHotKeyID(signature: OSType(0x424C4D44), id: id)  // 'BLMD'
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                                         GetApplicationEventTarget(), 0, &reference)
        if status != noErr {
            Logger.shared.log("ERROR: no se pudo registrar un atajo global (código \(status))")
        }
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        Self.registry[id] = nil
    }

    // MARK: - Interno

    /// Un solo manejador para todos los atajos: Carbon reparte por identificador.
    private static func installHandlerIfNeeded() {
        guard handler == nil else { return }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }

            // El manejador de Carbon ya corre en el hilo principal.
            let hotKey = HotKey.registry[hotKeyID.id]?.hotKey
            if GetEventKind(event) == UInt32(kEventHotKeyReleased) {
                hotKey?.release?()
            } else {
                hotKey?.action()
            }
            return noErr
        }, 2, &eventTypes, nil, &handler)
    }
}
