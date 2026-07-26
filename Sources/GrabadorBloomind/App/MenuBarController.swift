import AppKit

/// Ícono y menú de la barra de menú.
///
/// En la Fase 0 el menú tiene solo Salir. El menú definitivo (iniciar, detener,
/// abrir carpeta, preferencias) y los estados del ícono llegan en la Fase 11.
final class MenuBarController {

    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        statusItem.button?.image = NSImage(
            systemSymbolName: "record.circle",
            accessibilityDescription: "Grabador Bloomind"
        )

        let menu = NSMenu()
        menu.addItem(withTitle: "Grabador Bloomind", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Salir",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
    }
}
