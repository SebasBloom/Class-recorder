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

        menuBar = MenuBarController()
        Logger.shared.log("Ícono de la barra de menú listo")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.log("Grabador Bloomind cerrado")
        Logger.shared.close()
    }
}
