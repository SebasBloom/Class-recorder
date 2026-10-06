import AppKit

/// La ventana del teleprompter: el guion subiendo mientras se graba.
///
/// **Nunca aparece en el video** (decisión 89). Es una ventana propia, así que
/// el filtro de captura la excluye igual que al widget y a los espejos de
/// dibujo, y no toca el pipeline de composición ni la conversión de coordenadas.
/// Esa ausencia es la prueba de que la decisión se está cumpliendo.
///
/// Es un `NSPanel` que no activa la app, con el mismo patrón que la burbuja de
/// cámara: sin barra de título, movible por su fondo y redimensionable en vivo.
/// La diferencia es que acá el fondo que arrastra la ventana es **la barra de
/// controles**, no el área de texto: sobre el texto, arrastrar mueve el guion.
@MainActor
final class TeleprompterWindow: NSPanel, NSWindowDelegate {

    /// Lo que se puede hacer desde afuera, o sea desde los botones replicados en
    /// el widget (plan, 8.9). Son los mismos que tiene la ventana adentro.
    enum Control {
        case playPausa
        case reiniciar
        case masVelocidad
        case menosVelocidad
        case masLetra
        case menosLetra
        case editar
    }

    /// Avisa que cambió algo que el widget muestra (play, velocidad, letra).
    var onChange: (() -> Void)?
    /// Avisa que el teleprompter se quedó con el teclado, para que el cuadro de
    /// texto que estuviera abierto en el dibujo se cierre (decisión 95).
    var onFocus: (() -> Void)?

    private var motor: TeleprompterEngine
    private var reloj: Timer?
    private var ultimoTick: CFTimeInterval?

    private let scrollView = NSScrollView()
    private let texto = NSTextView()
    private let escenario = EscenarioView()

    /// Los mismos botones del widget, con la misma gramática: ícono arriba,
    /// nombre abajo, todos del mismo tamaño (decisión 113). La barra de acá y la
    /// fila del widget hacen lo mismo, así que se ven igual.
    private let play = NSButton()
    private let reiniciar = NSButton()
    private let masLento = NSButton()
    private let masRapido = NSButton()
    private let menosLetra = NSButton()
    private let masLetra = NSButton()
    private let editar = NSButton()
    /// Las teclas que sirven acá, escritas a la vista para no tener que
    /// aprendérselas (decisión 119).
    private let ayuda = NSTextField(labelWithString: "")
    /// Velocidad y tamaño de letra, debajo de la ayuda.
    /// Velocidad y letra, escritas con números (decisión 132). Se escribe el
    /// valor y Enter, o se sale del campo.
    private let campoVelocidad = NSTextField()
    private let campoLetra = NSTextField()
    private var valores: NSStackView!

    /// La combinación que prende y apaga el teleprompter, tal como está
    /// asignada hoy. Se muestra en la barra.
    var atajoParaEsconder: String? { didSet { refrescarControles() } }

    /// Estado editar: el guion se escribe en vez de leerse. Mientras está
    /// prendido, las teclas sueltas de la ventana se apagan (decisión 92).
    private(set) var editando = false

    var corriendo: Bool { motor.corriendo }
    var velocidad: Double { motor.velocidad }
    var tamañoLetra: Double { motor.tamañoLetra }
    /// El guion tal como está ahora, con lo que se haya editado en vivo.
    var guion: String { texto.string }

    /// Todos los guiones cargados, con su nombre. Se cambia entre ellos con los
    /// botones de arriba (decisión 121). Lo que se edite en vivo se guarda en su
    /// entrada, así que ir y volver no pierde los cambios.
    private var guiones: [(nombre: String, texto: String)]
    private var indiceActual = 0
    private let pestañas = NSStackView()
    private let barraPestañas = NSScrollView()

    // MARK: - Armado

    init(guiones: [(nombre: String, texto: String)], velocidad: Double,
         tamañoLetra: Double, pantalla: NSRect) {
        motor = TeleprompterEngine(velocidad: velocidad, tamañoLetra: tamañoLetra)
        // Sin ninguno cargado igual se abre: en blanco y listo para escribir el
        // guion ahí mismo con el botón de editar.
        self.guiones = guiones.isEmpty ? [(nombre: "Guion", texto: "")] : guiones

        super.init(
            contentRect: Self.marcoInicial(en: pantalla),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = WindowLayer.teleprompter.level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // El fondo que arrastra la ventana es el de la barra de controles: el
        // área de texto se queda con el arrastre para mover el guion.
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        // El ancho mínimo lo manda la barra: siete botones de la grilla más su
        // aire. Más angosta que esto, los controles se cortarían.
        minSize = NSSize(width: 7 * CommandButton.ancho + 6 * CommandButton.separacion
                                + BloomindStyle.Space.normal * 2,
                         height: 260)

        construir()
        texto.string = self.guiones[0].texto
        refrescarPestañas()
        aplicarTipografia()
        delegate = self
    }

    /// Una ventana sin barra de título no puede ser la principal por defecto, y
    /// sin serlo no recibe teclado: sin esto no habría barra espaciadora ni
    /// flechas, ni se podría escribir el guion.
    override var canBecomeKey: Bool { true }

    private func construir() {
        let fondo = NSView()
        fondo.wantsLayer = true
        fondo.layer?.backgroundColor = BloomindStyle.deep.cgColor
        fondo.layer?.cornerRadius = BloomindStyle.cornerRadius
        fondo.layer?.masksToBounds = true
        fondo.layer?.borderWidth = 1
        fondo.layer?.borderColor = BloomindStyle.hairline.cgColor

        texto.isEditable = false
        texto.isSelectable = false
        texto.drawsBackground = false
        texto.isVerticallyResizable = true
        texto.isHorizontallyResizable = false
        texto.autoresizingMask = [.width]
        texto.minSize = NSSize(width: 0, height: 0)
        // El alto lo decide el texto; el ancho lo manda la ventana. Sin estos
        // tres renglones el `NSTextView` no crece con el guion y el teleprompter
        // se queda mostrando la primera pantalla para siempre.
        texto.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        texto.textContainer?.widthTracksTextView = true
        texto.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = texto
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        // Sin rebote: el texto tiene que quedar clavado donde lo dejó el motor,
        // y un rebote elástico lo movería por su cuenta después de soltarlo.
        scrollView.verticalScrollElasticity = .none
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // El escenario va **encima** del texto y se queda con la rueda y el
        // arrastre. Es también donde viven la línea de lectura y los dos
        // degradados, que no reciben mouse.
        escenario.translatesAutoresizingMaskIntoConstraints = false
        escenario.onRueda = { [weak self] delta in self?.mover(por: -delta) }
        escenario.onArrastre = { [weak self] delta in self?.mover(por: delta) }
        escenario.onEmpezarArrastre = { [weak self] in
            // Arrastrar pausa el avance automático: se está leyendo a mano.
            self?.pausarPorMano()
        }
        escenario.onClic = { [weak self] in self?.tomarFoco() }

        let barra = construirBarra()
        construirPestañas()

        fondo.addSubview(barraPestañas)
        fondo.addSubview(scrollView)
        fondo.addSubview(escenario)
        fondo.addSubview(barra)

        NSLayoutConstraint.activate([
            barraPestañas.topAnchor.constraint(equalTo: fondo.topAnchor),
            barraPestañas.leadingAnchor.constraint(equalTo: fondo.leadingAnchor),
            barraPestañas.trailingAnchor.constraint(equalTo: fondo.trailingAnchor),
            barraPestañas.heightAnchor.constraint(equalToConstant: Self.altoPestañas),

            scrollView.topAnchor.constraint(equalTo: barraPestañas.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: fondo.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: fondo.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: barra.topAnchor),

            escenario.topAnchor.constraint(equalTo: scrollView.topAnchor),
            escenario.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            escenario.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            escenario.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            barra.leadingAnchor.constraint(equalTo: fondo.leadingAnchor),
            barra.trailingAnchor.constraint(equalTo: fondo.trailingAnchor),
            barra.bottomAnchor.constraint(equalTo: fondo.bottomAnchor),
            barra.heightAnchor.constraint(equalToConstant: Self.altoBarra)
        ])

        contentView = fondo
    }

    /// Alto de la fila de pestañas de guiones.
    private static let altoPestañas: CGFloat = 36

    /// Ancho de la columna de ayuda y valores, a la derecha de los botones.
    private static let anchoColumna: CGFloat = 200

    /// Alto de la barra: el botón más el aire de arriba y abajo.
    private static let altoBarra: CGFloat = CommandButton.alto + BloomindStyle.Space.tight * 2

    /// La fila de arriba: un botón por guion cargado.
    ///
    /// Va en un scroll horizontal para que diez guiones no obliguen a una
    /// ventana de un metro: se pasan con dos dedos. Con un solo guion la fila no
    /// se muestra, porque no hay entre qué elegir.
    private func construirPestañas() {
        pestañas.orientation = .horizontal
        pestañas.spacing = CommandButton.separacion
        pestañas.edgeInsets = NSEdgeInsets(top: 0, left: BloomindStyle.Space.normal, bottom: 0,
                                           right: BloomindStyle.Space.normal)

        barraPestañas.documentView = pestañas
        barraPestañas.drawsBackground = false
        barraPestañas.hasHorizontalScroller = false
        barraPestañas.hasVerticalScroller = false
        barraPestañas.verticalScrollElasticity = .none
        barraPestañas.translatesAutoresizingMaskIntoConstraints = false

        // Un `NSScrollView` no dimensiona solo a su contenido: sin estas tres
        // ataduras el stack se queda en tamaño cero y la fila se ve vacía. Sin
        // atar el borde derecho a propósito, que es lo que la deja crecer a lo
        // ancho y poder desplazarse.
        pestañas.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pestañas.leadingAnchor.constraint(equalTo: barraPestañas.contentView.leadingAnchor),
            pestañas.topAnchor.constraint(equalTo: barraPestañas.contentView.topAnchor),
            pestañas.bottomAnchor.constraint(equalTo: barraPestañas.contentView.bottomAnchor)
        ])
    }

    /// Rehace los botones y marca el que está a la vista.
    private func refrescarPestañas() {
        for vieja in pestañas.arrangedSubviews { pestañas.removeArrangedSubview(vieja); vieja.removeFromSuperview() }

        // Con un solo guion no hay nada que elegir y la fila desaparece: es alto
        // de pantalla que se le devuelve al texto.
        barraPestañas.isHidden = guiones.count < 2
        guard guiones.count > 1 else { return }

        for (indice, guion) in guiones.enumerated() {
            let boton = NSButton(title: guion.nombre, target: self, action: #selector(tocarPestaña(_:)))
            boton.tag = indice
            boton.isBordered = false
            boton.wantsLayer = true
            boton.layer?.cornerRadius = 6
            boton.toolTip = guion.nombre
            boton.cell?.lineBreakMode = .byTruncatingTail
            let fuente = BloomindStyle.ui(11)
            let natural = guion.nombre.size(withAttributes: [.font: fuente]).width + 24
            boton.translatesAutoresizingMaskIntoConstraints = false
            boton.widthAnchor.constraint(equalToConstant: min(max(natural, 64), 170).rounded()).isActive = true
            boton.heightAnchor.constraint(equalToConstant: 24).isActive = true

            let activo = indice == indiceActual
            boton.layer?.backgroundColor = activo ? BloomindStyle.lab.cgColor
                                                  : NSColor(white: 1, alpha: 0.10).cgColor
            CommandButton.titular(boton, color: activo ? .white : BloomindStyle.ink, font: fuente)
            pestañas.addArrangedSubview(boton)
        }
    }

    @objc private func tocarPestaña(_ boton: NSButton) {
        guard boton.tag >= 0, boton.tag < guiones.count, boton.tag != indiceActual else { return }
        cambiarA(boton.tag)
    }

    /// Cambia de guion. Antes de irse guarda lo que se haya editado del actual:
    /// volver a una pestaña tiene que traer lo que uno dejó.
    private func cambiarA(_ indice: Int) {
        guiones[indiceActual].texto = texto.string
        indiceActual = indice
        texto.string = guiones[indice].texto
        motor.reiniciar()
        detenerReloj()
        aplicarTipografia()
        colocarTexto()
        refrescarPestañas()
        refrescarControles()
        onChange?()
        Logger.shared.log("Teleprompter: guion \"\(guiones[indice].nombre)\", \(guiones[indice].texto.count) caracteres")
    }

    private func construirBarra() -> NSView {
        let barra = NSView()
        barra.wantsLayer = true
        barra.layer?.backgroundColor = BloomindStyle.surface.cgColor
        barra.translatesAutoresizingMaskIntoConstraints = false

        configurar(play, "play.fill", "Play", "Play y pausa del guion (barra espaciadora)", #selector(tocarPlay))
        configurar(reiniciar, "arrow.uturn.left", "Al inicio", "Volver al principio del guion", #selector(tocarReiniciar))
        configurar(masLento, "tortoise.fill", "Más lento", "Bajar la velocidad (flecha abajo)", #selector(tocarMenosVelocidad))
        configurar(masRapido, "hare.fill", "Más rápido", "Subir la velocidad (flecha arriba)", #selector(tocarMasVelocidad))
        configurar(menosLetra, "minus.circle", "Letra −", "Letra más chica", #selector(tocarMenosLetra))
        configurar(masLetra, "plus.circle", "Letra +", "Letra más grande", #selector(tocarMasLetra))
        configurar(editar, "pencil", "Editar", "Editar el guion", #selector(tocarEditar))

        ayuda.font = BloomindStyle.mono(9)
        ayuda.textColor = BloomindStyle.muted
        ayuda.alignment = .right

        for campo in [campoVelocidad, campoLetra] {
            campo.font = BloomindStyle.mono(11)
            campo.alignment = .center
            campo.bezelStyle = .roundedBezel
            campo.controlSize = .small
            campo.target = self
            campo.action = #selector(escribirValor(_:))
            // Confirma también al salir del campo, no solo con Enter.
            campo.cell?.sendsActionOnEndEditing = true
            campo.translatesAutoresizingMaskIntoConstraints = false
            campo.widthAnchor.constraint(equalToConstant: 42).isActive = true
        }
        campoVelocidad.toolTip = "Velocidad del guion: escribí un número y Enter"
        campoLetra.toolTip = "Tamaño de letra: escribí un número y Enter"
        let etiquetaVelocidad = NSTextField(labelWithString: "velocidad")
        let etiquetaLetra = NSTextField(labelWithString: "letra")
        for etiqueta in [etiquetaVelocidad, etiquetaLetra] {
            etiqueta.font = BloomindStyle.mono(11)
            etiqueta.textColor = BloomindStyle.muted
        }
        valores = NSStackView(views: [etiquetaVelocidad, campoVelocidad, etiquetaLetra, campoLetra])
        valores.spacing = 4
        valores.setCustomSpacing(10, after: campoVelocidad)
        // Los números son lo primero que sobra si la ventana se hace angosta:
        // los botones no se pueden perder. Pero se **esconden enteros** en vez
        // de recortarse, porque "velocidad !" a medio cortar se ve peor que no
        // estar.
        valores.setContentCompressionResistancePriority(.defaultLow - 1, for: .horizontal)
        ayuda.setContentCompressionResistancePriority(.defaultLow - 1, for: .horizontal)

        let columnaDerecha = NSStackView(views: [ayuda, valores])
        columnaDerecha.orientation = .vertical
        columnaDerecha.alignment = .trailing
        columnaDerecha.spacing = 2
        // Ancho fijo y los dos renglones truncando: apoyada solo en el
        // espaciador, la columna se desbordaba por el borde derecho de la
        // ventana y el último número salía cortado.
        columnaDerecha.translatesAutoresizingMaskIntoConstraints = false
        columnaDerecha.widthAnchor.constraint(equalToConstant: Self.anchoColumna).isActive = true
        ayuda.lineBreakMode = .byTruncatingTail

        let espaciador = NSView()
        espaciador.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let fila = NSStackView(views: [play, reiniciar, masLento, masRapido,
                                       menosLetra, masLetra, editar, espaciador, columnaDerecha])
        fila.orientation = .horizontal
        fila.alignment = .centerY
        fila.spacing = CommandButton.separacion
        fila.translatesAutoresizingMaskIntoConstraints = false
        barra.addSubview(fila)

        NSLayoutConstraint.activate([
            fila.leadingAnchor.constraint(equalTo: barra.leadingAnchor, constant: BloomindStyle.Space.normal),
            fila.trailingAnchor.constraint(equalTo: barra.trailingAnchor, constant: -BloomindStyle.Space.normal),
            fila.centerYAnchor.constraint(equalTo: barra.centerYAnchor)
        ])
        return barra
    }

    private func configurar(_ boton: NSButton, _ simbolo: String, _ nombre: String,
                            _ ayuda: String, _ accion: Selector) {
        CommandButton.configurar(boton, simbolo: simbolo, nombre: nombre,
                                 ayuda: ayuda, target: self, accion: accion)
    }

    // MARK: - Mostrar y esconder

    func setVisible(_ visible: Bool) {
        if visible {
            orderFrontRegardless()
            // El relleno es media altura del cuadro, así que hay que esperar a
            // que el layout le dé su tamaño real: calculado antes, la primera
            // línea no arrancaría en la línea de lectura sino pegada al borde.
            ocultarAyudaSiNoCabe()
            contentView?.layoutSubtreeIfNeeded()
            aplicarTipografia()
            // Sin la app adelante, macOS le da el teclado a la que sí lo está y
            // la barra espaciadora nunca llegaría. Es el mismo criterio del
            // espejo de dibujo (decisión 64): el foco lo toma la ventana que se
            // acaba de mostrar, y se recupera clickeando la app de atrás.
            tomarFoco()
            refrescarControles()
            colocarTexto()
        } else {
            motor.pausar()
            detenerReloj()
            orderOut(nil)
            onChange?()
        }
    }

    private func tomarFoco() {
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        // En estado leer el teclado lo tiene que atender la ventana, no el
        // cuadro de texto: un `NSTextView` de primer respondedor se queda con la
        // barra espaciadora para pasar de página, aunque no sea editable.
        if !editando { makeFirstResponder(nil) }
        onFocus?()
    }

    // MARK: - Controles

    /// El punto único por donde entran los controles de afuera: los botones del
    /// widget disparan exactamente lo mismo que los de la ventana.
    func aplicar(_ control: Control) {
        switch control {
        case .playPausa:      tocarPlay()
        case .reiniciar:      tocarReiniciar()
        case .masVelocidad:   tocarMasVelocidad()
        case .menosVelocidad: tocarMenosVelocidad()
        case .masLetra:       tocarMasLetra()
        case .menosLetra:     tocarMenosLetra()
        case .editar:         tocarEditar()
        }
    }

    @objc private func tocarPlay() {
        guard !editando else { return }
        motor.alternarPlay()
        if motor.corriendo { arrancarReloj() } else { detenerReloj() }
        refrescarControles()
        onChange?()
    }

    @objc private func tocarReiniciar() {
        motor.reiniciar()
        detenerReloj()
        colocarTexto()
        refrescarControles()
        onChange?()
    }

    @objc private func tocarMasVelocidad() { cambiarVelocidad(0.5) }
    @objc private func tocarMenosVelocidad() { cambiarVelocidad(-0.5) }

    private func cambiarVelocidad(_ delta: Double) {
        motor.cambiarVelocidad(delta)
        refrescarControles()
        onChange?()
    }

    /// Un número escrito en la barra. Lo que no es número vuelve a lo que
    /// había; lo que se pasa del rango queda en el borde, igual que en el
    /// panel. Al terminar, el teclado vuelve a la ventana para que la barra
    /// espaciadora y las flechas sigan andando.
    @objc private func escribirValor(_ campo: NSTextField) {
        if let valor = NumberRow.leer(campo.stringValue) {
            if campo === campoVelocidad {
                cambiarVelocidad(valor - motor.velocidad)
            } else {
                cambiarLetra(valor - motor.tamañoLetra)
            }
        }
        makeFirstResponder(nil)
        refrescarControles()
    }

    @objc private func tocarMasLetra() { cambiarLetra(4) }
    @objc private func tocarMenosLetra() { cambiarLetra(-4) }

    private func cambiarLetra(_ delta: Double) {
        motor.cambiarTamañoLetra(delta)
        aplicarTipografia()
        refrescarControles()
        onChange?()
    }

    /// Alterna entre leer y editar.
    ///
    /// Al entrar a editar el guion se frena y vuelve al principio: el texto que
    /// se está por cambiar puede quedar más corto, y dejar el offset donde
    /// estaba mostraría el final o la nada.
    @objc private func tocarEditar() {
        editando.toggle()
        motor.reiniciar()
        detenerReloj()

        texto.isEditable = editando
        texto.isSelectable = editando
        escenario.isHidden = editando

        aplicarTipografia()
        if editando {
            tomarFoco()
            texto.window?.makeFirstResponder(texto)
        } else {
            makeFirstResponder(nil)
        }
        colocarTexto()
        refrescarControles()
        onChange?()
        Logger.shared.log("Teleprompter: estado \(editando ? "editar" : "leer")")
    }

    // MARK: - Teclas sueltas

    /// Barra espaciadora y flechas, **solo** mientras esta ventana tiene el foco
    /// y **no** mientras se está editando el guion (decisión 92). Los atajos de
    /// tres modificadores del resto de la app no pasan por acá y siguen
    /// funcionando siempre.
    override func keyDown(with event: NSEvent) {
        guard !editando else { return super.keyDown(with: event) }
        switch Int(event.keyCode) {
        case 49:  tocarPlay()            // barra espaciadora
        case 126: cambiarVelocidad(0.5)  // flecha arriba
        case 125: cambiarVelocidad(-0.5) // flecha abajo
        default:  super.keyDown(with: event)
        }
    }

    // MARK: - Desplazamiento

    private func arrancarReloj() {
        detenerReloj()
        ultimoTick = CACurrentMediaTime()
        // 60 por segundo. El avance no depende de que el temporizador sea
        // puntual: cada paso mide el tiempo real transcurrido (decisión 104).
        reloj = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // Sin esto el texto se congela mientras se arrastra la ventana o se
        // mantiene apretado un botón, porque el modo de evento cambia.
        if let reloj { RunLoop.main.add(reloj, forMode: .common) }
    }

    private func detenerReloj() {
        reloj?.invalidate()
        reloj = nil
        ultimoTick = nil
    }

    private func tick() {
        let ahora = CACurrentMediaTime()
        let transcurrido = ultimoTick.map { ahora - $0 } ?? 0
        ultimoTick = ahora

        motor.avanzar(transcurrido: transcurrido, maximo: offsetMaximo)
        colocarTexto()

        if !motor.corriendo {
            // Llegó al final y frenó solo.
            detenerReloj()
            refrescarControles()
            onChange?()
        }
    }

    private func mover(por delta: CGFloat) {
        motor.posicionar(motor.offset + Double(delta), maximo: offsetMaximo)
        colocarTexto()
    }

    private func pausarPorMano() {
        guard motor.corriendo else { return }
        motor.pausar()
        detenerReloj()
        refrescarControles()
        onChange?()
    }

    /// Hasta dónde puede subir el texto: su alto menos el alto del cuadro.
    private var offsetMaximo: Double {
        Double(max(texto.frame.height - scrollView.contentView.bounds.height, 0))
    }

    /// Copia la posición del motor a la vista. Es la única dirección: la vista
    /// nunca mueve el texto por su cuenta.
    private func colocarTexto() {
        let clip = scrollView.contentView
        clip.scroll(to: NSPoint(x: 0, y: motor.offset))
        scrollView.reflectScrolledClipView(clip)
    }

    // MARK: - Aspecto

    /// Aplica tipografía, interlineado y el relleno de media altura.
    ///
    /// El relleno de arriba y de abajo es lo que hace que la **primera** línea
    /// arranque en la línea de lectura y que la **última** pueda llegar hasta
    /// ella. Al editar se quita: ahí el guion se escribe como en cualquier
    /// cuadro de texto.
    private func aplicarTipografia() {
        let fuente = BloomindStyle.display(CGFloat(motor.tamañoLetra), weight: 400)

        let parrafo = NSMutableParagraphStyle()
        // Interlineado 1.8 puesto como espacio **después** de cada renglón y no
        // como multiplicador de la caja de línea. Con el multiplicador, el aire
        // extra se agrega arriba del glifo, así que el primer renglón del guion
        // aparecía medio renglón por debajo de la línea de lectura en vez de
        // encima de ella (decisión 122). El interlineado que se ve es el mismo.
        let alturaNatural = fuente.ascender - fuente.descender + fuente.leading
        parrafo.lineSpacing = (1.8 - 1) * alturaNatural

        let atributos: [NSAttributedString.Key: Any] = [
            // Fraunces, la serif de la marca: es la cara con la que se lee, y a
            // estos tamaños se sigue leyendo cómodo de lejos.
            .font: fuente,
            .foregroundColor: BloomindStyle.ink,
            .paragraphStyle: parrafo
        ]
        texto.typingAttributes = atributos
        if let almacen = texto.textStorage {
            almacen.setAttributes(atributos, range: NSRange(location: 0, length: almacen.length))
        }
        ajustarRelleno()
    }

    private func ajustarRelleno() {
        // El layout primero: el relleno es media altura del cuadro, y calcularlo
        // con un alto viejo deja el guion arrancando debajo de la línea de
        // lectura en vez de encima. Pasa al abrir la ventana y al cambiar de
        // guion, que son los dos momentos en que el alto acaba de cambiar.
        contentView?.layoutSubtreeIfNeeded()
        let alto = scrollView.contentView.bounds.height
        let vertical = editando ? BloomindStyle.Space.normal : alto / 2
        texto.textContainerInset = NSSize(width: BloomindStyle.Space.card, height: vertical)
        texto.sizeToFit()
    }

    private func refrescarControles() {
        let corriendo = motor.corriendo
        play.image = CommandButton.icono(corriendo ? "pause.fill" : "play.fill",
                                         corriendo ? "Pausa" : "Play")
        play.title = corriendo ? "Pausa" : "Play"
        CommandButton.pintar(play, corriendo ? .prendido : .apagado)
        play.isEnabled = !editando

        editar.title = editando ? "Leer" : "Editar"
        editar.image = CommandButton.icono(editando ? "text.aligncenter" : "pencil",
                                           editando ? "Volver a leer" : "Editar el guion")
        editar.toolTip = editando ? "Volver a leer" : "Editar el guion"
        CommandButton.pintar(editar, editando ? .prendido : .apagado)

        // Con el guion abierto para editar no hay nada que correr ni que medir.
        for boton in [reiniciar, masLento, masRapido, menosLetra, masLetra] {
            boton.isEnabled = !editando
        }

        // Lo que se está escribiendo no se pisa: el refresco llega en cada
        // cuadro mientras el guion corre.
        if campoVelocidad.currentEditor() == nil {
            campoVelocidad.stringValue = String(format: "%.1f", motor.velocidad)
        }
        if campoLetra.currentEditor() == nil {
            campoLetra.stringValue = String(Int(motor.tamañoLetra))
        }
        campoVelocidad.isEnabled = !editando
        campoLetra.isEnabled = !editando
        // La combinación sale del registro de atajos: si se reasigna, acá se lee
        // la nueva. Las teclas sueltas no se nombran cuando se está editando,
        // porque justamente ahí no funcionan (decisión 92).
        if editando {
            ayuda.stringValue = atajoParaEsconder.map { "\($0) esconder" } ?? ""
        } else {
            let esconder = atajoParaEsconder.map { "\($0) esconder · " } ?? ""
            ayuda.stringValue = esconder + "espacio play"
        }
        escenario.lineaVisible = !editando
    }

    // MARK: - NSWindowDelegate

    /// Ancho a partir del cual la columna de la derecha cabe sin apretar a los
    /// botones. Por debajo se esconde entera: media ayuda cortada se lee peor
    /// que ninguna.
    private var anchoConValores: CGFloat { minSize.width + Self.anchoColumna + BloomindStyle.Space.normal }

    private func ocultarAyudaSiNoCabe() {
        let cabe = frame.width >= anchoConValores
        valores.isHidden = !cabe
        ayuda.isHidden = !cabe
    }

    func windowDidResize(_ notification: Notification) {
        ocultarAyudaSiNoCabe()
        // El relleno es media altura del cuadro, así que cambia con la ventana.
        ajustarRelleno()
        motor.posicionar(motor.offset, maximo: offsetMaximo)
        colocarTexto()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        onFocus?()
    }

    /// Arriba y al centro de la pantalla que se está grabando (plan, 8.7-bis).
    ///
    /// "Arriba" es debajo de la barra de menú, no pegado al borde físico: el
    /// marco que llega es el de la pantalla entera, y apoyado ahí el teleprompter
    /// arrancaría con su primer renglón tapado por la barra o por el notch.
    private static func marcoInicial(en pantalla: NSRect) -> NSRect {
        let util = NSScreen.screens.first { $0.frame.intersects(pantalla) }?.visibleFrame ?? pantalla
        // Más de la mitad del ancho: los siete botones de la barra ocupan 610 pt
        // y los números tienen que entrar al lado sin apretarlos.
        let ancho = (util.width * 0.56).rounded()
        let alto = (util.height * 0.32).rounded()
        return NSRect(x: util.midX - ancho / 2,
                      y: util.maxY - alto - BloomindStyle.Space.card,
                      width: ancho, height: alto)
    }
}

/// La capa que va encima del texto: se queda con la rueda y el arrastre, y
/// dibuja la línea de lectura y los dos degradados de desvanecido.
///
/// Existe para que el `NSTextView` no tenga que manejar mouse: en estado leer no
/// es editable ni seleccionable, y todo el gesto lo resuelve esta vista. Al
/// editar se esconde y los clics llegan al texto como en cualquier cuadro.
@MainActor
private final class EscenarioView: NSView {

    var onRueda: ((CGFloat) -> Void)?
    var onArrastre: ((CGFloat) -> Void)?
    var onEmpezarArrastre: (() -> Void)?
    var onClic: (() -> Void)?

    var lineaVisible = true { didSet { needsDisplay = true } }

    private var inicioY: CGFloat = 0
    private var offsetInicial: CGFloat = 0

    override func scrollWheel(with event: NSEvent) {
        onRueda?(event.scrollingDeltaY)
    }

    override func mouseDown(with event: NSEvent) {
        onClic?()
        onEmpezarArrastre?()
        inicioY = event.locationInWindow.y
        offsetInicial = 0
    }

    override func mouseDragged(with event: NSEvent) {
        // Arrastrar hacia abajo devuelve el guion hacia atrás, como agarrar el
        // papel con la mano.
        let delta = event.locationInWindow.y - inicioY
        onArrastre?(delta - offsetInicial)
        offsetInicial = delta
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let contexto = NSGraphicsContext.current?.cgContext else { return }

        // Los degradados son la única excepción a "colores planos" de la
        // identidad, y no son decoración: son lo que hace que el texto aparezca
        // y desaparezca en vez de cortarse en seco contra el borde.
        let alto = min(bounds.height * 0.25, 120)
        dibujarDesvanecido(contexto, rect: NSRect(x: 0, y: bounds.maxY - alto, width: bounds.width, height: alto), haciaArriba: true)
        dibujarDesvanecido(contexto, rect: NSRect(x: 0, y: 0, width: bounds.width, height: alto), haciaArriba: false)

        guard lineaVisible else { return }
        let margen = bounds.width * 0.08
        BloomindStyle.lab.withAlphaComponent(0.35).setFill()
        NSRect(x: margen, y: bounds.midY, width: bounds.width - margen * 2, height: 1).fill()
    }

    private func dibujarDesvanecido(_ contexto: CGContext, rect: NSRect, haciaArriba: Bool) {
        let fondo = BloomindStyle.deep
        guard let gradiente = NSGradient(starting: fondo, ending: fondo.withAlphaComponent(0)) else { return }
        contexto.saveGState()
        gradiente.draw(in: rect, angle: haciaArriba ? 270 : 90)
        contexto.restoreGState()
    }
}
