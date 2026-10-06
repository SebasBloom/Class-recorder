import AppKit

/// Widget flotante durante la grabación: una cápsula blanca (decisión 124).
///
/// A la vista va lo que se toca a cada rato —el cronómetro con su frase de
/// estado, pausar, detener, reiniciar, los dos audios y la cámara— y todo lo
/// demás en cuatro botones de grupo con un menú chico cada uno, con el atajo
/// escrito al lado de cada acción. Lo del tablero y la pausa del guion aparecen
/// sueltos en la cápsula solo mientras aplican.
///
/// Se achica a una pastilla con solo el cronómetro (decisión 125), y cada
/// alerta grave es una pastilla coral bajo la cápsula que se deshace al tocarla
/// (decisión 126). La esquina de arriba a la derecha es la que se queda quieta
/// cuando cambia el ancho: es la que está contra el borde de la pantalla.
///
/// Es un `NSPanel` que no activa la app: tocarle un botón no le roba el foco a lo
/// que se está mostrando en clase. Vive por encima de la superficie de dibujo
/// (`WindowLayer`), que es lo que hace que sus botones respondan también con el
/// tablero o el marcador prendidos (decisión 93).
@MainActor
final class RecordingWidget: NSPanel {

    var onPause: (() -> Void)?
    var onStop: (() -> Void)?
    var onRestart: (() -> Void)?
    var onToggleBubble: (() -> Void)?
    /// Devuelve el menú de cámaras en el momento de abrirlo, no antes: la lista
    /// cambia cuando se conecta o desconecta un aparato.
    var onCameraMenu: (() -> NSMenu?)?
    var onToggleMicrophone: (() -> Void)?
    var onToggleSystemAudio: (() -> Void)?
    /// Los controles del teleprompter replicados acá (plan, 8.9): disparan
    /// exactamente lo mismo que los botones de su propia ventana.
    var onTeleprompterControl: ((TeleprompterWindow.Control) -> Void)?
    /// Todo lo demás: cada acción dispara lo mismo que su atajo, y el ruteo lo
    /// hace `RecordingController.perform(_:)`.
    var onAction: ((ShortcutAction) -> Void)?
    /// La combinación vigente de una acción, para escribirla en los menús y las
    /// alertas. Sale del registro y no de una constante: si se reasigna desde
    /// Preferencias, el widget muestra la nueva.
    var etiquetaDeAtajo: ((ShortcutAction) -> String?)?

    // MARK: - Estado

    /// Estado del teleprompter que muestra el widget.
    struct TeleprompterState {
        /// La ventana está a la vista.
        let visible: Bool
        /// El guion está subiendo ahora mismo.
        let corriendo: Bool
        /// Se está escribiendo el guion en vez de leerlo.
        let editando: Bool

        static let apagado = TeleprompterState(visible: false, corriendo: false, editando: false)
    }

    /// Estado de audio que muestra el widget.
    struct AudioState {
        let capturaMicrofono: Bool
        let capturaSistema: Bool
        let microfonoSilenciado: Bool
        let sistemaSilenciado: Bool
    }

    /// Lo último que llegó por `update`. Los menús se arman al abrirlos con
    /// esto, así nunca muestran un estado viejo.
    private struct Foto {
        var pausado = false
        var modo: CaptureMode = .pantalla
        var censura = false
        var anotando = false
        var color: MarkerColor = .amarillo
        var lienzo: BoardColor = .blanco
        var hayCamara = false
        var resaltadoCursor = true
        var teleprompter = TeleprompterState.apagado
        var audio = AudioState(capturaMicrofono: false, capturaSistema: false,
                               microfonoSilenciado: false, sistemaSilenciado: false)

        var dibujando: Bool { modo == .tablero || anotando }
    }

    private var foto = Foto()
    private var mini = ConfigurationStore.shared.current.widgetMini

    // MARK: - Vistas

    private let columna = NSStackView()
    private let capsula = NSView()
    private let pastilla = MiniPill()
    private let alertas = NSStackView()

    private let punto = LiveDot()
    private let tiempo = NSTextField(labelWithString: "00:00")
    private let marcador = NSView()
    private let frase = NSTextField(wrappingLabelWithString: "")

    private let pausar = CapsuleButton(simbolo: "pause", nombre: "Pausar", ayuda: "Pausar")
    private let detener = CapsuleButton(simbolo: "stop", nombre: "Detener", ayuda: "Detener la grabación")
    private let reiniciar = CapsuleButton(simbolo: "arrow.counterclockwise", nombre: "Reiniciar", ayuda: "Reiniciar toma")
    private let microfono = CapsuleButton(simbolo: "mic", nombre: "Micrófono", ayuda: "Silenciar micrófono")
    private let sistema = CapsuleButton(simbolo: "speaker.wave.2", nombre: "Sonido PC", ayuda: "Silenciar audio del sistema")
    private let camara = CapsuleButton(simbolo: "person.crop.circle", nombre: "Cámara", ayuda: "Cámara")

    private let grupoVe = CapsuleButton(simbolo: "macwindow", nombre: "Qué se ve", ayuda: "Pantalla, cámara completa o tablero", ancho: nil)
    private let grupoTablero = CapsuleButton(simbolo: "square.and.pencil", nombre: "Tablero", ayuda: "Lienzo, deshacer y borrar", ancho: nil)
    private let grupoSobre = CapsuleButton(simbolo: "cursorarrow.rays", nombre: "Sobre la pantalla", ayuda: "Cursor, marcador y censura", ancho: nil)
    private let guion = CapsuleButton(simbolo: "text.alignleft", nombre: "Guion", ayuda: "Mostrar o esconder el guion")
    private let guionMenu = CapsuleButton(simbolo: "chevron.down", nombre: "", ayuda: "Controles del guion", ancho: 22)

    private let lienzo = CapsuleButton(simbolo: "circle.lefthalf.filled", nombre: "Lienzo", ayuda: "Tablero blanco o negro")
    private let deshacer = CapsuleButton(simbolo: "arrow.uturn.backward", nombre: "Deshacer", ayuda: "Deshacer el último trazo")
    private let borrar = CapsuleButton(simbolo: "eraser", nombre: "Borrar", ayuda: "Borrar todo lo dibujado")
    private let leer = CapsuleButton(simbolo: "pause", nombre: "Pausa guion", ayuda: "Play y pausa del guion", ancho: nil)
    private let achicar = CapsuleButton(simbolo: "arrow.down.right.and.arrow.up.left", nombre: "Achicar",
                                        ayuda: "Dejar solo el tiempo", ancho: 46)

    private let relojVista = NSStackView()
    private var contextoTablero = NSView()
    private var contextoGuion = NSView()

    /// Lo que se está mostrando en las alertas, para no rearmarlas cada segundo.
    private var alertasMostradas: [Alerta] = []

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 66),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = WindowLayer.widget.level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        // Clara siempre, aunque el Mac esté en modo oscuro: es la identidad de
        // la app (decisión 123), y así los menús y tooltips salen claros también.
        appearance = NSAppearance(named: .aqua)

        construir()
        aplicarMini()
        colocar()
    }

    // MARK: - Construcción

    private func construir() {
        let c = BloomindStyle.Claro.self

        capsula.wantsLayer = true
        capsula.layer?.backgroundColor = c.blanco.cgColor
        capsula.layer?.cornerRadius = 33
        capsula.layer?.borderWidth = 1
        capsula.layer?.borderColor = c.tinta.withAlphaComponent(0.72).cgColor

        tiempo.font = BloomindStyle.reloj(25)
        tiempo.textColor = c.tinta

        marcador.wantsLayer = true
        marcador.layer?.cornerRadius = 4.5
        marcador.layer?.borderWidth = 1
        marcador.layer?.borderColor = c.tinta.withAlphaComponent(0.3).cgColor
        fijar(marcador, 9, 9)

        let lineaReloj = NSStackView(views: [punto, tiempo, marcador])
        lineaReloj.spacing = 9
        lineaReloj.alignment = .centerY

        frase.font = BloomindStyle.ui(11.5)
        frase.textColor = c.pizarra
        frase.maximumNumberOfLines = 2
        frase.lineBreakMode = .byWordWrapping
        frase.cell?.truncatesLastVisibleLine = true
        frase.preferredMaxLayoutWidth = 186

        let reloj = relojVista
        reloj.setViews([lineaReloj, frase], in: .top)
        reloj.orientation = .vertical
        reloj.alignment = .leading
        reloj.spacing = 4
        fijar(reloj, 186, nil)

        pausar.target = self; pausar.action = #selector(tocarPausa)
        detener.target = self; detener.action = #selector(tocarDetener)
        reiniciar.target = self; reiniciar.action = #selector(tocarReiniciar)
        microfono.target = self; microfono.action = #selector(tocarMicrofono)
        sistema.target = self; sistema.action = #selector(tocarSistema)
        camara.target = self; camara.action = #selector(tocarCamara)
        // Mantener presionado: el menú de cámaras, haya o no una prendida.
        let menuLargo = NSPressGestureRecognizer(target: self, action: #selector(mostrarMenuDeCamara))
        menuLargo.minimumPressDuration = 0.35
        camara.addGestureRecognizer(menuLargo)

        for grupo in [grupoVe, grupoTablero, grupoSobre] {
            grupo.conFlecha = true
            grupo.target = self
            grupo.action = #selector(tocarGrupo(_:))
        }
        guion.target = self; guion.action = #selector(tocarGuion)
        guionMenu.imagePosition = .imageOnly
        guionMenu.target = self; guionMenu.action = #selector(tocarGrupo(_:))
        // El guion y su flecha se leen como un solo botón partido.
        guion.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        guionMenu.layer?.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        let partido = NSStackView(views: [guion, guionMenu])
        partido.spacing = 0

        lienzo.target = self; lienzo.action = #selector(tocarLienzo)
        deshacer.target = self; deshacer.action = #selector(tocarDeshacer)
        borrar.target = self; borrar.action = #selector(tocarBorrar)
        leer.target = self; leer.action = #selector(tocarLeer)
        contextoTablero = contexto([lienzo, deshacer, borrar])
        contextoGuion = contexto([leer])

        achicar.target = self; achicar.action = #selector(tocarAchicar)

        let fila = NSStackView(views: [
            reloj, pausar, detener, reiniciar, divisor(),
            microfono, sistema, camara, divisor(),
            grupoVe, grupoTablero, contextoTablero, grupoSobre, partido, contextoGuion,
            achicar
        ])
        fila.spacing = 4
        fila.alignment = .centerY
        fila.edgeInsets = NSEdgeInsets(top: 0, left: 22, bottom: 0, right: 8)
        fila.setCustomSpacing(6, after: reloj)
        fila.setCustomSpacing(7, after: grupoTablero)
        fila.setCustomSpacing(7, after: contextoTablero)
        fila.setCustomSpacing(7, after: partido)
        fila.setCustomSpacing(7, after: contextoGuion)
        fila.translatesAutoresizingMaskIntoConstraints = false
        capsula.addSubview(fila)
        NSLayoutConstraint.activate([
            fila.leadingAnchor.constraint(equalTo: capsula.leadingAnchor),
            fila.trailingAnchor.constraint(equalTo: capsula.trailingAnchor),
            fila.topAnchor.constraint(equalTo: capsula.topAnchor),
            fila.bottomAnchor.constraint(equalTo: capsula.bottomAnchor),
            capsula.heightAnchor.constraint(equalToConstant: 66)
        ])

        pastilla.onTap = { [weak self] in self?.ponerMini(false) }

        alertas.spacing = 8

        columna.setViews([capsula, pastilla, alertas], in: .top)
        columna.orientation = .vertical
        columna.alignment = .trailing
        columna.spacing = 8
        columna.translatesAutoresizingMaskIntoConstraints = false

        let raiz = NSView()
        raiz.addSubview(columna)
        NSLayoutConstraint.activate([
            columna.leadingAnchor.constraint(equalTo: raiz.leadingAnchor),
            columna.trailingAnchor.constraint(equalTo: raiz.trailingAnchor),
            columna.topAnchor.constraint(equalTo: raiz.topAnchor),
            columna.bottomAnchor.constraint(equalTo: raiz.bottomAnchor)
        ])
        contentView = raiz

        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: self,
                                               queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.guardarPosicion() }
        }
    }

    /// El fondo gris claro que agrupa los botones que aparecen según el
    /// contexto: así se ve que son de ese momento y no de siempre.
    private func contexto(_ botones: [NSView]) -> NSView {
        let fila = NSStackView(views: botones)
        fila.spacing = 0
        fila.wantsLayer = true
        fila.layer?.backgroundColor = BloomindStyle.Claro.papel.cgColor
        fila.layer?.cornerRadius = 13
        fila.layer?.borderWidth = 1
        fila.layer?.borderColor = BloomindStyle.Claro.linea.cgColor
        return fila
    }

    private func divisor() -> NSView {
        let linea = NSView()
        linea.wantsLayer = true
        linea.layer?.backgroundColor = BloomindStyle.Claro.linea.cgColor
        fijar(linea, 1, 30)
        return linea
    }

    private func fijar(_ vista: NSView, _ ancho: CGFloat?, _ alto: CGFloat?) {
        vista.translatesAutoresizingMaskIntoConstraints = false
        if let ancho { vista.widthAnchor.constraint(equalToConstant: ancho).isActive = true }
        if let alto { vista.heightAnchor.constraint(equalToConstant: alto).isActive = true }
    }

    // MARK: - Posición y tamaño

    /// Arriba a la derecha de la pantalla principal la primera vez; después
    /// recuerda dónde lo dejaste.
    private func colocar() {
        ajustarTamaño()
        if let guardada = ConfigurationStore.shared.current.widgetTopRight {
            let esquina = NSPoint(x: guardada.x, y: guardada.y)
            if NSScreen.screens.contains(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(esquina) }) {
                setFrameTopRight(esquina)
                return
            }
        }
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        setFrameTopRight(NSPoint(x: visible.maxX - BloomindStyle.Space.card,
                                 y: visible.maxY - BloomindStyle.Space.card))
    }

    private func setFrameTopRight(_ esquina: NSPoint) {
        setFrameOrigin(NSPoint(x: esquina.x - frame.width, y: esquina.y - frame.height))
    }

    /// La ventana mide lo que su contenido, y crece o se encoge **hacia la
    /// izquierda y hacia abajo**: la esquina de arriba a la derecha no se mueve.
    private func ajustarTamaño() {
        guard let raiz = contentView else { return }
        raiz.layoutSubtreeIfNeeded()
        let tamaño = columna.fittingSize
        guard tamaño != frame.size else { return }
        let esquina = NSPoint(x: frame.maxX, y: frame.maxY)
        var nuevo = NSRect(x: esquina.x - tamaño.width, y: esquina.y - tamaño.height,
                           width: tamaño.width, height: tamaño.height)
        // Crecer desde la esquina derecha puede sacarlo de la pantalla: pasa al
        // abrir la cápsula con la pastilla mini arrastrada contra el borde
        // izquierdo. Ahí se corre lo justo para quedar entero a la vista.
        if let visible = (screen ?? NSScreen.main)?.visibleFrame {
            nuevo.origin.x = min(max(nuevo.minX, visible.minX), visible.maxX - nuevo.width)
            nuevo.origin.y = min(max(nuevo.minY, visible.minY), visible.maxY - nuevo.height)
        }
        setFrame(nuevo, display: true)
        // La sombra de una ventana transparente sigue la forma de lo que tiene
        // pintado; sin esto se queda con la del tamaño anterior.
        invalidateShadow()
    }

    // MARK: - Tutorial

    /// Dónde está en la pantalla lo que el tutorial quiere iluminar. Achicado,
    /// cualquier cosa de la cápsula es la pastilla: es lo único que se ve.
    func marcoEnPantalla(de objetivo: ObjetivoTutorial) -> NSRect? {
        guard isVisible else { return nil }
        if mini { return pastilla.marcoEnPantalla }
        let union = { (vistas: [NSView]) -> NSRect? in
            vistas.compactMap(\.marcoEnPantalla).reduce(nil) { $0?.union($1) ?? $1 }
        }
        switch objetivo {
        case .reloj:           return relojVista.marcoEnPantalla
        case .pausar:          return pausar.marcoEnPantalla
        case .reiniciar:       return reiniciar.marcoEnPantalla
        case .detener:         return detener.marcoEnPantalla
        case .audio:           return union([microfono, sistema, alertas])
        case .camara:          return camara.marcoEnPantalla
        case .queSeVe:         return grupoVe.marcoEnPantalla
        case .tablero:         return union([grupoTablero, contextoTablero])
        case .sobreLaPantalla: return grupoSobre.marcoEnPantalla
        case .guion:           return union([guion, guionMenu, contextoGuion])
        case .achicar:         return achicar.marcoEnPantalla
        default:               return nil
        }
    }

    /// La cápsula completa, para que el tutorial pueda mostrar sus botones.
    func mostrarCompleto() {
        ponerMini(false)
    }

    // MARK: - Modo mini

    private func ponerMini(_ valor: Bool) {
        guard mini != valor else { return }
        mini = valor
        ConfigurationStore.shared.update { $0.widgetMini = valor }
        aplicarMini()
        Logger.shared.log("Widget en modo \(valor ? "mini" : "completo")")
    }

    private func aplicarMini() {
        capsula.isHidden = mini
        pastilla.isHidden = !mini
        ajustarTamaño()
    }

    // MARK: - Refresco

    /// Refresca todo lo que muestra.
    func update(segundos: Int,
                pausado: Bool,
                modo: CaptureMode,
                censura: Bool,
                anotando: Bool,
                color: MarkerColor,
                lienzo colorLienzo: BoardColor,
                hayCamara: Bool,
                resaltadoCursor: Bool,
                teleprompter: TeleprompterState,
                audio: AudioState) {

        foto = Foto(pausado: pausado, modo: modo, censura: censura, anotando: anotando,
                    color: color, lienzo: colorLienzo, hayCamara: hayCamara,
                    resaltadoCursor: resaltadoCursor, teleprompter: teleprompter, audio: audio)

        let reloj = String(format: "%02d:%02d", segundos / 60, segundos % 60)
        tiempo.stringValue = reloj
        punto.pausado = pausado
        tiempo.alphaValue = pausado ? 0.45 : 1
        frase.stringValue = textoDeEstado()

        // El punto de color solo tiene sentido cuando se está dibujando.
        marcador.isHidden = !foto.dibujando
        marcador.layer?.backgroundColor = color.cgColor

        pausar.cambiar(simbolo: pausado ? "play" : "pause", nombre: pausado ? "Reanudar" : "Pausar")
        pausar.toolTip = pausado ? "Reanudar" : "Pausar"

        // El botón de cámara nunca se deshabilita: sin cámara prendida sigue
        // sirviendo para prender una (decisión 82).
        camara.cambiar(simbolo: hayCamara ? "person.crop.circle" : "person.crop.circle.badge.plus")
        camara.estado = hayCamara ? .prendido : .normal
        camara.toolTip = hayCamara
            ? "Apagar la cámara · mantené presionado para elegir otra"
            : "Elegir y prender una cámara"

        // Las fuentes que no se eligieron antes de arrancar quedan deshabilitadas,
        // no ausentes: el botón no es un atajo para encenderlas (decisión 82).
        pintarAudio(microfono, activa: audio.capturaMicrofono, silenciada: audio.microfonoSilenciado,
                    simbolo: "mic", nombre: "Micrófono", nombreMudo: "Activar mic",
                    ayuda: "Silenciar micrófono", ayudaMuda: "Activar micrófono")
        pintarAudio(sistema, activa: audio.capturaSistema, silenciada: audio.sistemaSilenciado,
                    simbolo: "speaker.wave.2", nombre: "Sonido PC", nombreMudo: "Activar PC",
                    ayuda: "Silenciar audio del sistema", ayudaMuda: "Activar audio del sistema")

        // Lo del tablero vive en la cápsula solo mientras hay tablero; la pausa
        // del guion, solo con el guion a la vista.
        contextoTablero.isHidden = modo != .tablero
        lienzo.toolTip = colorLienzo == .negro ? "Pasar a lienzo blanco" : "Pasar a lienzo negro"
        guion.estado = teleprompter.visible ? .prendido : .normal
        guion.toolTip = teleprompter.visible ? "Esconder el guion" : "Mostrar el guion"
        contextoGuion.isHidden = !teleprompter.visible
        leer.cambiar(simbolo: teleprompter.corriendo ? "pause" : "play",
                     nombre: teleprompter.corriendo ? "Pausa guion" : "Leer guion")
        leer.estado = teleprompter.corriendo ? .prendido : .normal
        // Con el guion abierto para editar no se puede hacer correr.
        leer.isEnabled = !teleprompter.editando

        let nuevas = alertasActuales()
        if nuevas != alertasMostradas {
            alertasMostradas = nuevas
            alertas.setViews(nuevas.map(pastillaDeAlerta), in: .trailing)
        }
        pastilla.pintar(tiempo: reloj, pausado: pausado, alerta: !nuevas.isEmpty)

        ajustarTamaño()
    }

    /// La frase bajo el cronómetro: qué se está grabando y lo que no se ve en
    /// la pantalla de quien graba. Las alertas no van acá: tienen su pastilla.
    private func textoDeEstado() -> String {
        let largo: String
        let corto: String
        switch foto.modo {
        case .pantalla: largo = "la pantalla";        corto = "pantalla"
        case .camara:   largo = "la cámara completa"; corto = "cámara completa"
        case .tablero:  largo = "el tablero \(foto.lienzo.label)"; corto = "tablero \(foto.lienzo.label)"
        }
        var partes = [foto.pausado ? "En pausa · \(corto)" : "Grabando \(largo)"]
        if foto.dibujando { partes.append("marcador \(foto.color.label)") }
        // El círculo del cursor no se ve en la pantalla de quien graba, solo en
        // el video: sin este aviso, la única forma de saber que está apagado es
        // acordarse de haberlo apagado (decisión 101).
        if !foto.resaltadoCursor { partes.append("sin cursor") }
        return partes.joined(separator: " · ")
    }

    /// Un botón de audio: normal, mudo (coral) o deshabilitado.
    private func pintarAudio(_ boton: CapsuleButton, activa: Bool, silenciada: Bool,
                             simbolo: String, nombre: String, nombreMudo: String,
                             ayuda: String, ayudaMuda: String) {
        boton.isEnabled = activa
        boton.cambiar(simbolo: silenciada ? simbolo + ".slash" : simbolo,
                      nombre: silenciada ? nombreMudo : nombre)
        boton.estado = silenciada ? .alerta : .normal
        boton.toolTip = activa ? (silenciada ? ayudaMuda : ayuda) : "No se eligió esta fuente antes de grabar"
    }

    // MARK: - Alertas

    private enum Alerta: Equatable {
        case sinAudio, microfono, sistema, censura
    }

    private func alertasActuales() -> [Alerta] {
        let a = foto.audio
        var lista: [Alerta] = []
        let micCallado = !a.capturaMicrofono || a.microfonoSilenciado
        let pcCallado = !a.capturaSistema || a.sistemaSilenciado
        if (a.capturaMicrofono || a.capturaSistema) && micCallado && pcCallado {
            lista.append(.sinAudio)
        } else {
            if a.capturaMicrofono && a.microfonoSilenciado { lista.append(.microfono) }
            if a.capturaSistema && a.sistemaSilenciado { lista.append(.sistema) }
        }
        if foto.censura { lista.append(.censura) }
        return lista
    }

    private func pastillaDeAlerta(_ alerta: Alerta) -> NSView {
        let a = foto.audio
        switch alerta {
        case .sinAudio:
            let accion: ShortcutAction = a.capturaMicrofono ? .silenciarMicrofono : .silenciarSistema
            return AlertPill(simbolo: "mic.slash", texto: "Sin audio", atajo: atajo(accion)) { [weak self] in
                guard let self else { return }
                if a.capturaMicrofono && a.microfonoSilenciado { self.onToggleMicrophone?() }
                if a.capturaSistema && a.sistemaSilenciado { self.onToggleSystemAudio?() }
            }
        case .microfono:
            return AlertPill(simbolo: "mic.slash", texto: "Micrófono mudo", atajo: atajo(.silenciarMicrofono)) { [weak self] in
                self?.onToggleMicrophone?()
            }
        case .sistema:
            return AlertPill(simbolo: "speaker.slash", texto: "Sonido del PC mudo", atajo: atajo(.silenciarSistema)) { [weak self] in
                self?.onToggleSystemAudio?()
            }
        case .censura:
            return AlertPill(simbolo: "eye.slash", texto: "Censura puesta", atajo: atajo(.censura)) { [weak self] in
                self?.onAction?(.censura)
            }
        }
    }

    private func atajo(_ accion: ShortcutAction) -> String {
        etiquetaDeAtajo?(accion) ?? accion.porDefecto.etiqueta
    }

    // MARK: - Menús de grupo

    @objc private func tocarGrupo(_ boton: CapsuleButton) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.minimumWidth = 236
        menu.appearance = NSAppearance(named: .aqua)

        let f = foto
        switch boton {
        case grupoVe:
            menu.addItem(.sectionHeader(title: "Qué se ve"))
            menu.addItem(item("Pantalla", .modoPantalla, marcado: f.modo == .pantalla))
            // Sin cámara no hay modo cámara completa: el fondo del frame
            // quedaría en negro (decisión 83).
            menu.addItem(item("Cámara completa", .modoCamara, marcado: f.modo == .camara, activo: f.hayCamara))
            menu.addItem(item("Tablero", .modoTablero, marcado: f.modo == .tablero))

        case grupoTablero:
            menu.addItem(.sectionHeader(title: "Tablero"))
            if f.modo != .tablero {
                menu.addItem(item("Pasar al tablero", .modoTablero))
            }
            // El lienzo solo existe en el tablero. La acción alterna, así que
            // elegir el que ya está puesto no hace nada.
            menu.addItem(item("Lienzo blanco", .colorTablero, marcado: f.lienzo == .blanco,
                              activo: f.modo == .tablero, ejecutar: f.lienzo != .blanco))
            menu.addItem(item("Lienzo negro", .colorTablero, marcado: f.lienzo == .negro,
                              activo: f.modo == .tablero, ejecutar: f.lienzo != .negro))
            // Actúan sobre la superficie de dibujo activa; sin ninguna prendida
            // no tienen sobre qué actuar.
            menu.addItem(item("Deshacer trazo", .deshacer, activo: f.dibujando))
            menu.addItem(item("Borrar todo", .borrar, activo: f.dibujando))

        case grupoSobre:
            menu.addItem(.sectionHeader(title: "Sobre la pantalla"))
            menu.addItem(item("Resaltar cursor", .resaltadoCursor, marcado: f.resaltadoCursor))
            menu.addItem(item("Marcador", .capaAnotacion, marcado: f.anotando))
            let color = item("Cambiar color · \(f.color.label)", .colorMarcador)
            color.image = circulo(f.color)
            menu.addItem(color)
            menu.addItem(.separator())
            menu.addItem(item("Censura", .censura, marcado: f.censura))
            menu.addItem(item("Redibujar la zona", .redibujarCensura))

        case guionMenu:
            menu.addItem(.sectionHeader(title: "Guion"))
            let t = f.teleprompter
            menu.addItem(control(t.corriendo ? "Pausa" : "Leer", .playPausa, activo: t.visible && !t.editando, nota: "espacio"))
            menu.addItem(control("Volver al inicio", .reiniciar, activo: t.visible))
            menu.addItem(control("Más lento", .menosVelocidad, activo: t.visible, nota: "↓"))
            menu.addItem(control("Más rápido", .masVelocidad, activo: t.visible, nota: "↑"))
            menu.addItem(control("Letra más chica", .menosLetra, activo: t.visible))
            menu.addItem(control("Letra más grande", .masLetra, activo: t.visible))
            menu.addItem(control(t.editando ? "Volver a leer" : "Editar el guion", .editar, activo: t.visible))

        default:
            return
        }

        boton.abierto = true
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: boton.bounds.height + 8), in: boton)
        boton.abierto = false
    }

    /// Una acción del registro de atajos, con su combinación a la derecha.
    private func item(_ titulo: String, _ accion: ShortcutAction, marcado: Bool = false,
                      activo: Bool = true, ejecutar: Bool = true) -> NSMenuItem {
        let item = MenuClosureItem(titulo: titulo) { [weak self] in
            if ejecutar { self?.onAction?(accion) }
        }
        item.state = marcado ? .on : .off
        item.isEnabled = activo
        mostrarAtajo(atajo(accion), en: item)
        return item
    }

    /// Un control del teleprompter. Sus teclas no son atajos del registro sino
    /// teclas sueltas de su ventana (decisión 92), así que van como nota.
    private func control(_ titulo: String, _ control: TeleprompterWindow.Control,
                         activo: Bool, nota: String? = nil) -> NSMenuItem {
        let item = MenuClosureItem(titulo: titulo) { [weak self] in
            self?.onTeleprompterControl?(control)
        }
        item.isEnabled = activo
        if let nota { item.toolTip = "En el guion: \(nota)" }
        return item
    }

    /// Escribe la combinación a la derecha del renglón con el dibujo nativo de
    /// los menús, que la alinea en columna y la pinta bien al pasar el mouse.
    /// Una combinación que el menú no sabe dibujar (una tecla con nombre largo)
    /// va al final del título.
    private func mostrarAtajo(_ etiqueta: String, en item: NSMenuItem) {
        var mods: NSEvent.ModifierFlags = []
        var resto = Substring(etiqueta)
        while let primero = resto.first {
            switch primero {
            case "⌃": mods.insert(.control)
            case "⌥": mods.insert(.option)
            case "⇧": mods.insert(.shift)
            case "⌘": mods.insert(.command)
            default: break
            }
            guard "⌃⌥⇧⌘".contains(primero) else { break }
            resto = resto.dropFirst()
        }
        let tecla: String?
        switch resto {
        case "⌫": tecla = "\u{8}"
        case let t where t.count == 1: tecla = t.lowercased()
        default: tecla = nil
        }
        if let tecla, !mods.isEmpty {
            item.keyEquivalent = tecla
            item.keyEquivalentModifierMask = mods
        } else {
            item.title += "   \(etiqueta)"
        }
    }

    private func circulo(_ color: MarkerColor) -> NSImage {
        NSImage(size: NSSize(width: 14, height: 14), flipped: false) { rect in
            let forma = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            NSColor(cgColor: color.cgColor)?.setFill()
            forma.fill()
            BloomindStyle.Claro.tinta.withAlphaComponent(0.25).setStroke()
            forma.stroke()
            return true
        }
    }

    // MARK: - Mostrar y esconder

    func present() {
        orderFrontRegardless()
    }

    func hide() {
        guardarPosicion()
        orderOut(nil)
    }

    private func guardarPosicion() {
        let esquina = NSPoint(x: frame.maxX, y: frame.maxY)
        guard ConfigurationStore.shared.current.widgetTopRight != StoredPoint(x: esquina.x, y: esquina.y) else { return }
        ConfigurationStore.shared.update {
            $0.widgetTopRight = StoredPoint(x: esquina.x, y: esquina.y)
        }
    }

    // MARK: - Botones

    @objc private func tocarPausa() { onPause?() }
    @objc private func tocarDetener() { onStop?() }
    @objc private func tocarMicrofono() { onToggleMicrophone?() }
    @objc private func tocarSistema() { onToggleSystemAudio?() }
    @objc private func tocarGuion() { onAction?(.teleprompter) }
    @objc private func tocarLienzo() { onAction?(.colorTablero) }
    @objc private func tocarDeshacer() { onAction?(.deshacer) }
    @objc private func tocarBorrar() { onAction?(.borrar) }
    @objc private func tocarLeer() { onTeleprompterControl?(.playPausa) }
    @objc private func tocarAchicar() { ponerMini(true) }

    /// Con cámara prendida, el botón prende y apaga la burbuja, que es lo que se
    /// hace veinte veces en una clase. El menú, que es lo que se hace una vez,
    /// sale manteniéndolo presionado. Sin cámara prendida, el clic normal abre
    /// el menú directo: no hay burbuja que alternar todavía.
    @objc private func tocarCamara() {
        if foto.hayCamara { onToggleBubble?() } else { mostrarMenuDeCamara() }
    }

    @objc private func mostrarMenuDeCamara() {
        guard let menu = onCameraMenu?() else { return }
        menu.appearance = NSAppearance(named: .aqua)
        camara.abierto = true
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: camara.bounds.height + 8), in: camara)
        camara.abierto = false
    }

    /// Reiniciar toma descarta lo grabado. Manda a la Papelera, no borra
    /// (decisión 12), pero igual pregunta: es la única acción del widget que
    /// tira a la basura una clase en curso.
    /// Lo llama el botón y también el atajo, para que los dos pasen por la misma
    /// confirmación.
    func confirmRestart() {
        tocarReiniciar()
    }

    @objc private func tocarReiniciar() {
        let alerta = NSAlert()
        alerta.messageText = "¿Reiniciar la toma?"
        alerta.informativeText = "Lo grabado hasta ahora se manda a la Papelera y arranca una toma nueva con la misma configuración."
        alerta.addButton(withTitle: "Reiniciar")
        alerta.addButton(withTitle: "Seguir grabando")
        alerta.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        guard alerta.runModal() == .alertFirstButtonReturn else { return }
        onRestart?()
    }
}

// MARK: - Piezas de la cápsula

/// Un renglón de menú que ejecuta un bloque. `NSMenuItem` solo sabe de
/// target y selector, y el target es débil: el renglón se sostiene a sí mismo.
final class MenuClosureItem: NSMenuItem {
    private let bloque: () -> Void

    init(titulo: String, bloque: @escaping () -> Void) {
        self.bloque = bloque
        super.init(title: titulo, action: #selector(disparar), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("no se usa") }

    @objc private func disparar() { bloque() }
}

/// El punto del cronómetro: azul con un anillo que late mientras se graba,
/// dos barras en pausa.
@MainActor
final class LiveDot: NSView {

    var pausado = false { didSet { if pausado != oldValue { refrescar() } } }
    /// Blanco en vez de azul, para cuando va sobre coral.
    var sobreColor = false { didSet { if sobreColor != oldValue { refrescar() } } }

    private let anillo = CAShapeLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 10).isActive = true
        heightAnchor.constraint(equalToConstant: 10).isActive = true
        anillo.fillColor = nil
        anillo.lineWidth = 2
        anillo.path = CGPath(ellipseIn: CGRect(x: -4, y: -4, width: 18, height: 18), transform: nil)
        anillo.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
        layer?.addSublayer(anillo)
        refrescar()
    }

    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("no se usa") }

    private var tinta: NSColor {
        sobreColor ? .white : (pausado ? BloomindStyle.Claro.pizarra : BloomindStyle.Claro.azul)
    }

    private func refrescar() {
        anillo.strokeColor = tinta.cgColor
        anillo.removeAllAnimations()
        anillo.opacity = 0
        if !pausado {
            let escala = CABasicAnimation(keyPath: "transform.scale")
            escala.fromValue = 0.6
            escala.toValue = 1.0
            let opacidad = CABasicAnimation(keyPath: "opacity")
            opacidad.fromValue = 0.6
            opacidad.toValue = 0
            let latido = CAAnimationGroup()
            latido.animations = [escala, opacidad]
            latido.duration = 1.8
            latido.repeatCount = .infinity
            anillo.add(latido, forKey: "latido")
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        tinta.setFill()
        if pausado {
            NSBezierPath(rect: NSRect(x: 1, y: 0, width: 3, height: 10)).fill()
            NSBezierPath(rect: NSRect(x: 6, y: 0, width: 3, height: 10)).fill()
        } else {
            NSBezierPath(ovalIn: bounds).fill()
        }
    }
}

/// El widget achicado: solo el punto y el cronómetro (decisión 125). Tocarlo
/// vuelve a la cápsula; arrastrarlo mueve la ventana.
@MainActor
final class MiniPill: NSView {

    var onTap: (() -> Void)?

    private let punto = LiveDot()
    private let tiempo = NSTextField(labelWithString: "00:00")
    private var inicio: NSEvent?
    private var arrastrando = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 21
        layer?.borderWidth = 1
        toolTip = "Tocá para ver todos los controles"

        tiempo.font = BloomindStyle.reloj(23)
        let fila = NSStackView(views: [punto, tiempo])
        fila.spacing = 9
        fila.alignment = .centerY
        fila.edgeInsets = NSEdgeInsets(top: 0, left: 17, bottom: 0, right: 20)
        fila.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fila)
        NSLayoutConstraint.activate([
            fila.leadingAnchor.constraint(equalTo: leadingAnchor),
            fila.trailingAnchor.constraint(equalTo: trailingAnchor),
            fila.topAnchor.constraint(equalTo: topAnchor),
            fila.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 42)
        ])
        pintar(tiempo: "00:00", pausado: false, alerta: false)
    }

    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("no se usa") }

    /// Con una alerta se pone coral entera: se tiene que ver aun achicada.
    func pintar(tiempo texto: String, pausado: Bool, alerta: Bool) {
        let c = BloomindStyle.Claro.self
        layer?.backgroundColor = (alerta ? c.coral : c.blanco).cgColor
        layer?.borderColor = (alerta ? c.coral : c.tinta.withAlphaComponent(0.72)).cgColor
        tiempo.stringValue = texto
        tiempo.textColor = alerta ? .white : c.tinta
        tiempo.alphaValue = pausado ? (alerta ? 0.75 : 0.45) : 1
        punto.pausado = pausado
        punto.sobreColor = alerta
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        inicio = event
        arrastrando = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !arrastrando, let inicio else { return }
        arrastrando = true
        window?.performDrag(with: inicio)
    }

    override func mouseUp(with event: NSEvent) {
        if !arrastrando { onTap?() }
        inicio = nil
    }
}

/// Una alerta grave: pastilla coral con lo que pasa y su atajo, que se deshace
/// al tocarla (decisión 126).
@MainActor
final class AlertPill: NSView {

    private let accion: () -> Void
    private var encima = false

    init(simbolo: String, texto: String, atajo: String, accion: @escaping () -> Void) {
        self.accion = accion
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor
        toolTip = "Tocá para deshacer"

        let icono = NSImageView()
        icono.image = NSImage(systemSymbolName: simbolo, accessibilityDescription: texto)?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .semibold))
        icono.contentTintColor = .white

        let etiqueta = NSTextField(labelWithString: texto)
        etiqueta.font = BloomindStyle.ui(16, weight: .semibold)
        etiqueta.textColor = .white

        let tecla = NSTextField(labelWithString: atajo)
        // La del sistema y no la monoespaciada: SF Mono dibuja ⌥ y ⌘ apretados.
        tecla.font = BloomindStyle.ui(12, weight: .semibold)
        tecla.textColor = .white
        let fondoTecla = NSView()
        fondoTecla.wantsLayer = true
        fondoTecla.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.22).cgColor
        fondoTecla.layer?.cornerRadius = 12
        tecla.translatesAutoresizingMaskIntoConstraints = false
        fondoTecla.addSubview(tecla)
        NSLayoutConstraint.activate([
            tecla.leadingAnchor.constraint(equalTo: fondoTecla.leadingAnchor, constant: 8),
            tecla.trailingAnchor.constraint(equalTo: fondoTecla.trailingAnchor, constant: -8),
            tecla.centerYAnchor.constraint(equalTo: fondoTecla.centerYAnchor),
            fondoTecla.heightAnchor.constraint(equalToConstant: 24)
        ])

        let fila = NSStackView(views: [icono, etiqueta, fondoTecla])
        fila.spacing = 9
        fila.alignment = .centerY
        fila.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 8)
        fila.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fila)
        NSLayoutConstraint.activate([
            fila.leadingAnchor.constraint(equalTo: leadingAnchor),
            fila.trailingAnchor.constraint(equalTo: trailingAnchor),
            fila.topAnchor.constraint(equalTo: topAnchor),
            fila.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 40)
        ])
        pintar()
    }

    required init?(coder: NSCoder) { fatalError("no se usa") }

    private func pintar() {
        let c = BloomindStyle.Claro.self
        layer?.backgroundColor = (encima ? c.coralHundido : c.coral).cgColor
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    override func mouseEntered(with event: NSEvent) { encima = true; pintar() }
    override func mouseExited(with event: NSEvent) { encima = false; pintar() }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { accion() }
    }
}
