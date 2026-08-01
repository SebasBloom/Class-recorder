import AppKit

/// Ícono y menú de la barra de menú.
///
/// En la Fase 1 el menú abre la ventana temporal de control. El menú definitivo
/// (iniciar, detener, abrir carpeta, preferencias) y los estados del ícono
/// llegan en la Fase 11.
@MainActor
final class MenuBarController {

    private let statusItem: NSStatusItem
    private var controlWindow: ControlWindow?
    private var shortcutsWindow: ShortcutsWindow?

    /// El registro de atajos vive acá, no en el controlador de grabación: el de
    /// iniciar y detener tiene que funcionar aunque no haya ninguna grabación en
    /// curso ni ventana de control abierta.
    private let registry = ShortcutRegistry()
    private let card = ShortcutCard()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // El cerebro de Bloomind en silueta. En la barra de menú macOS exige
        // imágenes de plantilla, monocromas con alfa: así el ícono se adapta solo
        // al tema claro y oscuro y a la barra teñida. El logo a color va en el
        // ícono de la app, donde sí corresponde.
        if let logo = NSImage(named: "BarraMenu") {
            logo.isTemplate = true
            logo.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = logo
        } else {
            statusItem.button?.image = NSImage(
                systemSymbolName: "record.circle",
                accessibilityDescription: "Grabador Bloomind"
            )
        }
        statusItem.button?.toolTip = "Grabador Bloomind"

        let menu = NSMenu()
        menu.addItem(withTitle: "Grabador Bloomind", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let controlItem = NSMenuItem(
            title: "Abrir control de grabación…",
            action: #selector(showControlWindow),
            keyEquivalent: ""
        )
        controlItem.target = self
        menu.addItem(controlItem)

        let folderItem = NSMenuItem(
            title: "Abrir carpeta de grabaciones",
            action: #selector(openRecordingsFolder),
            keyEquivalent: ""
        )
        folderItem.target = self
        menu.addItem(folderItem)

        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Salir",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        let shortcutsItem = NSMenuItem(
            title: "Atajos…",
            action: #selector(showShortcutsWindow),
            keyEquivalent: ""
        )
        shortcutsItem.target = self
        menu.insertItem(shortcutsItem, at: menu.index(of: folderItem) + 1)

        statusItem.menu = menu

        registry.onAction = { [weak self] action in self?.handle(action) }
        registry.onRelease = { [weak self] action in
            if action == .tarjeta { self?.card.hide() }
        }
        // Fuera de grabación solo queda registrado iniciar/detener, para no
        // robarle combinaciones al resto del sistema (punto delicado 7).
        registry.refresh()
    }

    // MARK: - Atajos

    private func handle(_ action: ShortcutAction) {
        switch action {
        case .tarjeta:
            card.show(shortcuts: registry.shortcuts,
                      recording: controlWindow?.recorder.isRecording ?? false)
        case .iniciarDetener:
            ensureControlWindow().toggleRecordingFromShortcut()
        default:
            controlWindow?.recorder.perform(action)
        }
    }

    /// La ventana de control se crea al vuelo si hace falta: el atajo de iniciar
    /// puede llegar sin que se haya abierto nunca.
    @discardableResult
    private func ensureControlWindow() -> ControlWindow {
        if let controlWindow { return controlWindow }
        let window = ControlWindow()
        window.recorder.attach(registry: registry)
        controlWindow = window
        return window
    }

    @objc private func showShortcutsWindow() {
        if shortcutsWindow == nil {
            shortcutsWindow = ShortcutsWindow(registry: registry)
        }
        NSApp.activate(ignoringOtherApps: true)
        shortcutsWindow?.showWindow(nil)
    }

    @objc private func showControlWindow() {
        let window = ensureControlWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.showWindow(nil)
    }

    @objc private func openRecordingsFolder() {
        let folder = URL(fileURLWithPath: ConfigurationStore.shared.current.outputFolder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }
}
