import AVFoundation

/// Un micrófono disponible.
struct AudioDevice: Equatable {
    /// Identificador estable del dispositivo. Es lo que se guarda en la
    /// configuración y lo que se le pasa a ScreenCaptureKit.
    let uniqueID: String
    let name: String
}

/// Lista de micrófonos disponibles, que se refresca sola al conectar o
/// desconectar (AirPods, iPhone por Continuity con el DJI, webcams USB).
///
/// Es el patrón común con la enumeración de cámaras de la Fase 6: si cambia el
/// manejo de desconexión acá, hay que revisar allá.
final class AudioDeviceEnumerator {

    /// Se llama en el hilo principal cada vez que la lista cambia.
    var onChange: (() -> Void)?

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.onChange?()
            }
            observers.append(observer)
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    /// Micrófonos visibles en este momento.
    static func available() -> [AudioDevice] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        return session.devices.map { AudioDevice(uniqueID: $0.uniqueID, name: $0.localizedName) }
    }

    /// Busca un dispositivo por su identificador guardado. Devuelve nil si ya no
    /// está conectado, que es el caso de "los AirPods de la última sesión están
    /// en el estuche".
    static func device(withID id: String) -> AudioDevice? {
        available().first { $0.uniqueID == id }
    }

    /// Pide permiso de micrófono si hace falta. La primera vez macOS muestra su
    /// diálogo; si ya se negó antes, devuelve falso sin mostrar nada y hay que
    /// mandar al usuario a Configuración del Sistema.
    static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            Logger.shared.log("Falta el permiso de micrófono")
            return false
        }
    }
}
