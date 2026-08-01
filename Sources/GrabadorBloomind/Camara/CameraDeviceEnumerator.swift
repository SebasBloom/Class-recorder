import AVFoundation

/// Una cámara disponible.
struct CameraDevice: Equatable {
    /// Identificador estable del dispositivo, que es lo que se guarda en la
    /// configuración.
    let uniqueID: String
    let name: String
}

/// Lista de cámaras disponibles, que se refresca sola al conectar o desconectar
/// (webcam USB, iPhone por Continuity, GoPro en modo webcam).
///
/// **Es el mismo patrón que `AudioDeviceEnumerator`, a propósito.** Las dos se
/// apoyan en `wasConnected` y `wasDisconnected` de `AVCaptureDevice`. Si cambia
/// el manejo de desconexión en una, hay que revisarlo en la otra.
final class CameraDeviceEnumerator {

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

    /// Cámaras visibles en este momento.
    ///
    /// `.external` cubre webcams USB y la GoPro en modo webcam;
    /// `.continuityCamera` es el iPhone. Se piden explícitos porque la sesión de
    /// descubrimiento no los devuelve si no se nombran.
    ///
    /// La Desk View del iPhone queda **afuera** a propósito: entrega la imagen
    /// deformada en ojo de pescado porque está pensada para apuntar al escritorio,
    /// no a la cara. En la lista solo confundía (decisión 50).
    static func available() -> [CameraDevice] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        return session.devices.map { CameraDevice(uniqueID: $0.uniqueID, name: $0.localizedName) }
    }

    /// Busca una cámara por su identificador guardado. Devuelve nil si ya no está
    /// conectada, que es el caso de "el iPhone de la última sesión está
    /// bloqueado".
    static func device(withID id: String) -> CameraDevice? {
        available().first { $0.uniqueID == id }
    }

    /// Pide permiso de cámara si hace falta. La primera vez macOS muestra su
    /// diálogo; si ya se negó antes, devuelve falso sin mostrar nada y hay que
    /// mandar al usuario a Configuración del Sistema.
    static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            Logger.shared.log("Falta el permiso de cámara")
            return false
        }
    }
}
