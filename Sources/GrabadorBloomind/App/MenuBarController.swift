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

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        statusItem.button?.image = NSImage(
            systemSymbolName: "record.circle",
            accessibilityDescription: "Grabador Bloomind"
        )

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
        statusItem.menu = menu
    }

    @objc private func showControlWindow() {
        if controlWindow == nil {
            controlWindow = ControlWindow()
        }
        NSApp.activate(ignoringOtherApps: true)
        controlWindow?.showWindow(nil)
    }

    @objc private func openRecordingsFolder() {
        let folder = URL(fileURLWithPath: ConfigurationStore.shared.current.outputFolder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }
}
