import AppKit

/// Barra de nivel de audio con la identidad Bloomind.
///
/// Existe para una sola cosa: que se vea moverse algo mientras hablás, antes de
/// arrancar una clase de una hora. No pretende ser un medidor de estudio.
final class LevelBar: NSView {

    private let fill = CALayer()

    /// Nivel de 0 a 1.
    var level: CGFloat = 0 {
        didSet { updateFill() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = BloomindStyle.hairline.cgColor
        layer?.cornerRadius = 3

        fill.backgroundColor = BloomindStyle.lab.cgColor
        fill.cornerRadius = 3
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        layer?.addSublayer(fill)
    }

    required init?(coder: NSCoder) { fatalError("no se usa") }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 6)
    }

    override func layout() {
        super.layout()
        updateFill()
    }

    private func updateFill() {
        // Sin animación implícita: a 20 muestras por segundo, las transiciones
        // automáticas de Core Animation hacen que la barra se vea con retraso.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.frame = CGRect(x: 0, y: 0, width: bounds.width * max(0, min(1, level)), height: bounds.height)
        CATransaction.commit()
    }
}
