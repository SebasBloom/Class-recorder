import AppKit

/// Ciclo de vida de la app. En la Fase 0 solo levanta el registro, la
/// configuración y el ícono de la barra de menú.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.openLog(named: "app")

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "sin bundle"
        Logger.shared.log("Grabador Bloomind \(version) iniciado en macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")

        ConfigurationStore.shared.load()

        // Sin esto no funciona Cmd+V en ningún campo de la app.
        EditMenu.install()

        menuBar = MenuBarController()
        Logger.shared.log("Ícono de la barra de menú listo")

        avisarSiHayGrabacionInterrumpida()
    }

    /// Si la app murió a mitad de una grabación, el archivo quedó recuperable
    /// gracias a los fragmentos periódicos (decisión 11). Lo que faltaba era
    /// avisarlo en vez de que se descubriera por casualidad.
    private func avisarSiHayGrabacionInterrumpida() {
        guard let archivo = RecoveryMarker.consumePending() else { return }

        Logger.shared.log("Se encontró una grabación que no cerró bien: \(archivo.lastPathComponent)")

        let alerta = NSAlert()
        alerta.messageText = "Quedó una grabación sin cerrar"
        alerta.informativeText = "La app se cerró mientras grababa \"\(archivo.lastPathComponent)\".\n\nEl archivo se puede reproducir hasta unos segundos antes del corte."
        alerta.addButton(withTitle: "Mostrar en el Finder")
        alerta.addButton(withTitle: "Después")
        alerta.alertStyle = .informational
        NSApp.activate(ignoringOtherApps: true)

        if alerta.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([archivo])
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.log("Grabador Bloomind cerrado")
        Logger.shared.close()
    }
}
