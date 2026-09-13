import AVFoundation
import AppKit

/// Ventana espejo de la burbuja de cámara.
///
/// Es lo que Sebas ve y manipula en su pantalla física: la arrastra y la
/// redimensiona, y el compositor dibuja la burbuja del video en ese mismo lugar
/// y de ese mismo tamaño (decisión 3: los efectos se componen en el archivo, lo
/// de la pantalla es un espejo). Queda fuera de la captura porque el filtro
/// excluye la aplicación entera, así que en el video nunca aparece.
///
/// Es un `NSPanel` que no activa la app: mover la burbuja no le roba el foco a
/// la aplicación que se está mostrando en clase.
@MainActor
final class CameraMirrorWindow: NSPanel, NSWindowDelegate {

    /// Se llama con el marco de la burbuja en coordenadas globales, cada vez que
    /// se mueve o se redimensiona, y una vez al abrirse.
    var onFrameChange: ((CGRect) -> Void)?

    private static let cornerRadius: CGFloat = 14

    /// Guardar en cada evento de arrastre serían cientos de escrituras por
    /// movimiento; se espera a que la mano se quede quieta.
    private var persistTimer: Timer?

    init(previewLayer: AVCaptureVideoPreviewLayer, aspectRatio: CGFloat) {
        super.init(
            contentRect: Self.initialFrame(aspectRatio: aspectRatio),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = WindowLayer.burbuja.level
        // Visible aunque Sebas cambie de escritorio o esté mostrando una app en
        // pantalla completa: la burbuja no se puede perder a mitad de clase.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        // La proporción queda clavada a la de la cámara: así lo que se ve en el
        // espejo es exactamente lo que se compone en el video, sin recortes.
        contentAspectRatio = NSSize(width: aspectRatio, height: 1)
        minSize = NSSize(width: 120, height: 120 / aspectRatio)

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = Self.cornerRadius
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 1
        container.layer?.borderColor = BloomindStyle.hairline.cgColor
        container.layer?.backgroundColor = BloomindStyle.deep.cgColor
        contentView = container

        previewLayer.frame = container.bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        container.layer?.addSublayer(previewLayer)

        delegate = self
    }

    /// Muestra o esconde la burbuja. Al mostrarla avisa dónde quedó; al
    /// esconderla guarda la posición antes de irse.
    func setVisible(_ visible: Bool) {
        if visible {
            orderFront(nil)
            onFrameChange?(frame)
        } else {
            persistTimer?.invalidate()
            persist()
            orderOut(nil)
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) { frameChanged() }
    func windowDidResize(_ notification: Notification) { frameChanged() }

    // MARK: - Interno

    private func frameChanged() {
        onFrameChange?(frame)

        persistTimer?.invalidate()
        persistTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.persist() }
        }
    }

    /// La posición y el tamaño persisten entre sesiones: se elige una vez y
    /// arranca ahí siempre.
    private func persist() {
        let rect = frame
        ConfigurationStore.shared.update {
            $0.bubbleFrame = StoredRect(x: rect.minX, y: rect.minY,
                                        width: rect.width, height: rect.height)
        }
    }

    /// El marco guardado, o una burbuja abajo a la derecha de la pantalla
    /// principal la primera vez.
    private static func initialFrame(aspectRatio: CGFloat) -> NSRect {
        if let saved = ConfigurationStore.shared.current.bubbleFrame {
            let rect = NSRect(x: saved.x, y: saved.y, width: saved.width, height: saved.height)
            // Solo se reusa si todavía cae en alguna pantalla: si el monitor
            // donde estaba ya no está conectado, la burbuja quedaría invisible.
            if NSScreen.screens.contains(where: { $0.frame.intersects(rect) }) {
                return rect
            }
        }

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width = (screen.width * 0.22).rounded()
        let height = (width / aspectRatio).rounded()
        let margin = BloomindStyle.Space.card
        return NSRect(x: screen.maxX - width - margin,
                      y: screen.minY + margin,
                      width: width, height: height)
    }
}
