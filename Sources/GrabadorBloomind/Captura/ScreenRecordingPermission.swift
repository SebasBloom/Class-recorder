import AppKit
import CoreGraphics

/// Permiso de grabación de pantalla.
///
/// macOS lo revoca cada tanto en apps que no vienen del App Store, así que esto
/// se consulta antes de cada grabación y nunca se asume concedido. Regla del
/// plan: si falta, decir exactamente cuál falta y abrir el panel correcto.
/// Nunca fallar en silencio ni cerrarse sola.
@MainActor
enum ScreenRecordingPermission {

    /// Devuelve true si se puede grabar. Si no, avisa y abre Configuración del
    /// Sistema en el panel exacto.
    static func ensureGranted() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }

        Logger.shared.log("Falta el permiso de grabación de pantalla")

        // Dispara el pedido del sistema. La primera vez muestra el diálogo de
        // macOS; después de una revocación devuelve falso sin mostrar nada, y por
        // eso igual hay que llevar al usuario al panel.
        CGRequestScreenCaptureAccess()

        let alert = NSAlert()
        alert.messageText = "Falta el permiso de grabación de pantalla"
        alert.informativeText = """
        El Grabador necesita permiso para grabar la pantalla.

        Se abre Configuración del Sistema en Privacidad y seguridad, Grabación de pantalla. Activá el Grabador Bloomind en la lista y volvé a intentar.

        Si ya lo habías dado: macOS vuelve a pedir este permiso más o menos una vez al mes en apps que no vienen del App Store. Es una regla de Apple, no un error.
        """
        alert.addButton(withTitle: "Abrir Configuración del Sistema")
        alert.addButton(withTitle: "Cancelar")
        alert.alertStyle = .warning

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
        return false
    }

    private static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
