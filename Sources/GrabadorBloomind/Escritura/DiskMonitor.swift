import Foundation

/// Vigila el espacio libre donde se está grabando.
///
/// Una clase de una hora en Retina pesa cerca de 2 GB (medido en la Fase 1). Que
/// el disco se llene a mitad no es hipotético, y dejar que el sistema colapse el
/// archivo sería perder la clase entera.
///
/// **Los tres umbrales viven acá y en ningún otro lado** (plan, 8.9).
final class DiskMonitor {

    /// Antes de arrancar: por debajo de esto se avisa, pero se deja grabar.
    static let umbralInicio: Int64 = 20 * 1_000_000_000
    /// Durante la grabación: por debajo de esto se avisa una vez.
    static let umbralAviso: Int64 = 10 * 1_000_000_000
    /// Punto de no retorno: se detiene la grabación de forma limpia, guardando lo
    /// grabado, en vez de esperar a que el sistema reviente el archivo.
    static let umbralCritico: Int64 = 2 * 1_000_000_000

    /// Se llama en el hilo principal cuando se cruza el umbral de aviso.
    var onAviso: ((Int64) -> Void)?
    /// Se llama en el hilo principal cuando se cruza el umbral crítico.
    var onCritico: ((Int64) -> Void)?

    private let carpeta: URL
    private var timer: Timer?
    private var yaAviso = false

    init(carpeta: URL) {
        self.carpeta = carpeta
    }

    deinit {
        timer?.invalidate()
    }

    /// Espacio libre en la carpeta de salida, o nil si no se pudo consultar.
    static func libre(en carpeta: URL) -> Int64? {
        let valores = try? carpeta.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return valores?.volumeAvailableCapacityForImportantUsage
    }

    /// En gigas, para los mensajes.
    static func gigas(_ bytes: Int64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_000_000_000)
    }

    /// Empieza a vigilar. Cada 20 segundos alcanza: entre dos chequeos una
    /// grabación escribe menos de 100 MB, muy por debajo del margen crítico.
    func start() {
        timer?.invalidate()
        yaAviso = false
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.revisar()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func revisar() {
        guard let libre = Self.libre(en: carpeta) else { return }

        if libre < Self.umbralCritico {
            Logger.shared.log("CRÍTICO: quedan \(Self.gigas(libre)) libres; se detiene la grabación para no perder lo grabado")
            stop()
            onCritico?(libre)
            return
        }

        if libre < Self.umbralAviso, !yaAviso {
            yaAviso = true
            Logger.shared.log("AVISO: quedan \(Self.gigas(libre)) libres en el disco")
            onAviso?(libre)
        }
    }
}
