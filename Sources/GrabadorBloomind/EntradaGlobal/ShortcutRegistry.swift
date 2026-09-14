import Carbon.HIToolbox
import Foundation

/// Cada cosa que se puede hacer con el teclado.
///
/// El `rawValue` es lo que se guarda en `config.json`, así que no se cambia sin
/// dejar sin efecto los atajos que el usuario ya reasignó.
enum ShortcutAction: String, CaseIterable {
    case iniciarDetener = "iniciar_detener"
    case modoPantalla = "modo_pantalla"
    case modoCamara = "modo_camara"
    case modoTablero = "modo_tablero"
    case pausar = "pausar"
    case capaAnotacion = "capa_anotacion"
    case resaltadoCursor = "resaltado_cursor"
    case colorMarcador = "color_marcador"
    case colorTablero = "color_tablero"
    case deshacer = "deshacer"
    case borrar = "borrar"
    case reiniciarToma = "reiniciar_toma"
    case censura = "censura"
    case redibujarCensura = "redibujar_censura"
    case silenciarMicrofono = "silenciar_microfono"
    case silenciarSistema = "silenciar_sistema"
    case teleprompter = "teleprompter"
    case widget = "widget"
    case tarjeta = "tarjeta"

    var label: String {
        switch self {
        case .iniciarDetener: return "Iniciar / detener grabación"
        case .modoPantalla:   return "Modo pantalla"
        case .modoCamara:     return "Modo cámara completa"
        case .modoTablero:    return "Modo tablero"
        case .pausar:         return "Pausar / reanudar"
        case .capaAnotacion:  return "Capa de anotación"
        case .resaltadoCursor: return "Resaltado del cursor"
        case .colorMarcador:  return "Rotar color del marcador"
        case .colorTablero:   return "Tablero blanco / negro"
        case .deshacer:       return "Deshacer último trazo"
        case .borrar:         return "Borrar la superficie activa"
        case .reiniciarToma:        return "Reiniciar toma"
        case .censura:              return "Censura on / off"
        case .redibujarCensura:     return "Redibujar la zona censurada"
        case .silenciarMicrofono:   return "Silenciar / activar micrófono"
        case .silenciarSistema:     return "Silenciar / activar audio del sistema"
        case .teleprompter:         return "Teleprompter on / off"
        case .widget:               return "Mostrar / esconder el menú de grabación"
        case .tarjeta:        return "Tarjeta de atajos (mantener)"
        }
    }

    /// Cuándo está activo. El único permanente es iniciar/detener: fuera de
    /// grabación la app no le roba combinaciones al resto del sistema (punto
    /// delicado 7 del plan).
    var soloGrabando: Bool { self != .iniciarDetener }

    /// La combinación de la tabla 8.8 del plan.
    ///
    /// **Solo letras, números y teclas dedicadas.** Nunca símbolos: un atajo se
    /// registra por posición física de la tecla, y los símbolos cambian de lugar
    /// entre distribuciones. La barra diagonal que el plan pedía para la tarjeta
    /// es Shift+7 en un teclado latinoamericano, así que el atajo no se disparaba
    /// nunca y encima la interfaz mostraba una tecla que no era (decisión 70).
    var porDefecto: Shortcut {
        switch self {
        case .iniciarDetener: return Shortcut(tecla: kVK_ANSI_G, modificadores: controlKey | optionKey | cmdKey, etiqueta: "⌃⌥⌘G")
        case .modoPantalla:   return Shortcut(tecla: kVK_ANSI_1, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘1")
        case .modoCamara:     return Shortcut(tecla: kVK_ANSI_2, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘2")
        case .modoTablero:    return Shortcut(tecla: kVK_ANSI_3, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘3")
        case .pausar:         return Shortcut(tecla: kVK_ANSI_P, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘P")
        case .capaAnotacion:  return Shortcut(tecla: kVK_ANSI_D, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘D")
        // A de apuntador: C es censura y P es pausar, las dos iniciales obvias
        // ya estaban tomadas.
        case .resaltadoCursor: return Shortcut(tecla: kVK_ANSI_A, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘A")
        case .colorMarcador:  return Shortcut(tecla: kVK_ANSI_0, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘0")
        case .colorTablero:   return Shortcut(tecla: kVK_ANSI_B, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘B")
        case .deshacer:       return Shortcut(tecla: kVK_ANSI_Z, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘Z")
        case .borrar:         return Shortcut(tecla: kVK_Delete, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘⌫")
        // Shift más el atajo fuerza el modo dibujar aunque ya haya zona elegida
        // en esta sesión (plan, 8.6).
        case .reiniciarToma:    return Shortcut(tecla: kVK_ANSI_R, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘R")
        case .censura:          return Shortcut(tecla: kVK_ANSI_C, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘C")
        case .redibujarCensura: return Shortcut(tecla: kVK_ANSI_C, modificadores: optionKey | cmdKey | shiftKey, etiqueta: "⇧⌥⌘C")
        case .silenciarMicrofono: return Shortcut(tecla: kVK_ANSI_M, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘M")
        case .silenciarSistema:   return Shortcut(tecla: kVK_ANSI_S, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘S")
        case .teleprompter:   return Shortcut(tecla: kVK_ANSI_T, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘T")
        // W de widget. Es el único atajo que puede dejar la pantalla sin ninguna
        // referencia visible, así que conviene que sea fácil de recordar: es el
        // mismo que lo hizo desaparecer.
        case .widget:         return Shortcut(tecla: kVK_ANSI_W, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘W")
        case .tarjeta:        return Shortcut(tecla: kVK_ANSI_H, modificadores: optionKey | cmdKey, etiqueta: "⌥⌘H")
        }
    }

    /// Teclas equivalentes que se registran junto con la principal.
    ///
    /// Nace de dos tropiezos reales: los números del teclado numérico son códigos
    /// distintos a los de la fila de arriba (decisión 53), y la tecla de borrar
    /// del Mac no es la misma que la "Supr" de un teclado de PC. Quien aprieta la
    /// que tiene esperando que funcione, tiene razón.
    var equivalentes: [Int] {
        switch porDefecto.tecla {
        case kVK_ANSI_0: return [kVK_ANSI_Keypad0]
        case kVK_ANSI_1: return [kVK_ANSI_Keypad1]
        case kVK_ANSI_2: return [kVK_ANSI_Keypad2]
        case kVK_ANSI_3: return [kVK_ANSI_Keypad3]
        case kVK_Delete: return [kVK_ForwardDelete]
        default:         return []
        }
    }
}

/// Registro central de atajos: qué combinación tiene cada acción, cuáles están
/// activas en este momento, y quién avisa cuando se aprietan.
///
/// Reemplaza los atajos fijos que las Fases 6, 7 y 8 fueron dejando sueltos.
@MainActor
final class ShortcutRegistry {

    /// Se llama al apretar la combinación de una acción.
    var onAction: ((ShortcutAction) -> Void)?
    /// Se llama al soltarla. Solo lo usa la tarjeta de atajos, que se muestra
    /// mientras la combinación se mantiene presionada.
    var onRelease: ((ShortcutAction) -> Void)?

    private var hotKeys: [HotKey] = []
    private var isRecording = false

    /// La combinación de cada acción: la reasignada por el usuario si existe, y
    /// si no, la del plan.
    private(set) var shortcuts: [ShortcutAction: Shortcut] = [:]

    init() {
        load()
    }

    func load() {
        let guardados = ConfigurationStore.shared.current.shortcuts
        for action in ShortcutAction.allCases {
            shortcuts[action] = guardados[action.rawValue] ?? action.porDefecto
        }
    }

    /// Cambia una combinación y la guarda. Devuelve la acción con la que choca,
    /// si choca con alguna.
    @discardableResult
    func assign(_ shortcut: Shortcut, to action: ShortcutAction) -> ShortcutAction? {
        if let enConflicto = conflict(for: shortcut, ignoring: action) {
            return enConflicto
        }

        shortcuts[action] = shortcut
        ConfigurationStore.shared.update { $0.shortcuts[action.rawValue] = shortcut }
        Logger.shared.log("Atajo reasignado: \(action.label) → \(shortcut.etiqueta)")
        refresh()
        return nil
    }

    /// Qué acción ya usa esa combinación.
    func conflict(for shortcut: Shortcut, ignoring action: ShortcutAction) -> ShortcutAction? {
        shortcuts.first {
            $0.key != action && $0.value.tecla == shortcut.tecla
                && $0.value.modificadores == shortcut.modificadores
        }?.key
    }

    func resetToDefaults() {
        for action in ShortcutAction.allCases {
            shortcuts[action] = action.porDefecto
        }
        ConfigurationStore.shared.update { $0.shortcuts = [:] }
        Logger.shared.log("Atajos restaurados a los valores por defecto")
        refresh()
    }

    /// Registra los atajos que corresponden al estado actual.
    func setRecording(_ recording: Bool) {
        guard recording != isRecording else { return }
        isRecording = recording
        refresh()
    }

    /// Vuelve a registrar todo desde cero. Soltar los `HotKey` viejos los
    /// desregistra del sistema.
    func refresh() {
        hotKeys.removeAll()

        for action in ShortcutAction.allCases {
            guard let shortcut = shortcuts[action] else { continue }
            guard !action.soloGrabando || isRecording else { continue }

            let teclas = [shortcut.tecla] + (shortcut == action.porDefecto ? action.equivalentes : [])
            for tecla in teclas {
                hotKeys.append(HotKey(keyCode: tecla, modifiers: shortcut.modificadores,
                                      action: { [weak self] in
                                          // Queda registrado que la combinación llegó, aunque la
                                          // acción después no haga nada visible. Sin esto, "el
                                          // atajo no funciona" y "el atajo funciona pero no se ve
                                          // el efecto" se ven exactamente igual desde afuera.
                                          Logger.shared.log("Atajo: \(action.label)")
                                          self?.onAction?(action)
                                      },
                                      release: { [weak self] in self?.onRelease?(action) }))
            }
        }

        Logger.shared.log("Atajos activos: \(hotKeys.count) registrados, grabando: \(isRecording ? "sí" : "no")")
    }
}
