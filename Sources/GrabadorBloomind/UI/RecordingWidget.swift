import AppKit

/// Widget flotante durante la grabación.
///
/// Chiquito, arrastrable, siempre encima y excluido de la captura (plan, 8.9).
/// Es lo que reemplaza a tener que buscar la ventana de control: muestra tiempo,
/// estado, modo activo, si hay censura puesta y con qué color se está dibujando,
/// y tiene un botón por cada cosa que se puede hacer en vivo.
///
/// **Dos modos:** compacto con lo que se usa a cada rato, y expandido con todo.
/// El modo se recuerda en la configuración. Los atajos siguen funcionando igual:
/// los botones son una vía alternativa, nunca un reemplazo.
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
    /// Todo lo demás: cada botón dispara la misma acción que su atajo, y el
    /// ruteo lo hace `RecordingController.perform(_:)`, que ya es el punto único
    /// por donde pasa todo lo que se puede hacer con el teclado.
    var onAction: ((ShortcutAction) -> Void)?

    private let tiempo = NSTextField(labelWithString: "00:00")
    private let estado = NSTextField(labelWithString: "")
    private let detalle = NSTextField(labelWithString: "")
    private let puntoColor = NSView()

    private let pausar = NSButton()
    private let detener = NSButton()
    private let reiniciar = NSButton()
    private let burbuja = NSButton()
    private let microfono = NSButton()
    private let sistema = NSButton()
    private let alternarTamaño = NSButton()

    /// Los botones del modo expandido, uno por acción del registro de atajos.
    private var porAccion: [ShortcutAction: NSButton] = [:]
    /// Las filas que solo se ven expandido.
    private var filasExpandidas: [NSView] = []

    private var expandido = ConfigurationStore.shared.current.widgetExpanded

    /// Si hay una cámara encendida ahora mismo. No se puede leer del botón,
    /// porque el botón está siempre habilitado: sin cámara sigue sirviendo para
    /// prender una.
    private var hayCamaraPrendida = false

    /// Qué acciones van en cada fila del modo expandido, con su símbolo y el
    /// nombre que se lee debajo del ícono.
    ///
    /// Es la lista entera de lo que el registro de atajos sabe hacer, menos lo
    /// que ya tiene botón propio arriba: iniciar/detener es el botón de detener,
    /// pausar y reiniciar toma están en la fila compacta, y los dos de audio
    /// también.
    ///
    /// **Todo botón lleva su nombre a la vista** (decisión 99). El nombre es
    /// corto y propio del widget, no el `label` del registro de atajos: ese es el
    /// nombre largo y canónico que muestran las preferencias y la tarjeta, y va
    /// igual en el tooltip. Acá lo que importa es que entre en una fila y se lea
    /// de reojo en mitad de una clase.
    private static let filaModos: [(ShortcutAction, String, String)] = [
        (.modoPantalla, "display",           "Pantalla"),
        (.modoCamara,   "video.fill",        "Cám. full"),
        (.modoTablero,  "square.and.pencil", "Tablero")
    ]

    /// La fila de ayudas va partida en dos: nueve botones con nombre en una sola
    /// línea harían un widget más ancho que la pantalla útil.
    private static let filaAyudas: [(ShortcutAction, String, String)] = [
        (.resaltadoCursor,  "cursorarrow.rays",       "Cursor"),
        (.censura,          "eye.slash.fill",         "Censura"),
        (.redibujarCensura, "rectangle.dashed",       "Redibujar"),
        (.capaAnotacion,    "pencil.tip.crop.circle", "Marcador"),
        (.colorMarcador,    "paintpalette.fill",      "Color")
    ]

    private static let filaTablero: [(ShortcutAction, String, String)] = [
        (.colorTablero,     "circle.lefthalf.filled", "Lienzo"),
        (.deshacer,         "arrow.uturn.backward",   "Deshacer"),
        (.borrar,           "eraser.fill",            "Borrar"),
        (.tarjeta,          "questionmark.circle",    "Atajos")
    ]

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 96),
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

        construir()
        aplicarTamaño(manteniendoArriba: false)
        colocar()
    }

    // MARK: - Construcción

    private func construir() {
        let fondo = NSVisualEffectView()
        fondo.material = .hudWindow
        fondo.blendingMode = .behindWindow
        fondo.state = .active
        fondo.wantsLayer = true
        fondo.layer?.cornerRadius = BloomindStyle.cornerRadius
        fondo.layer?.masksToBounds = true

        tiempo.font = BloomindStyle.mono(20, weight: .medium)
        tiempo.textColor = BloomindStyle.ink

        estado.font = BloomindStyle.ui(11, weight: .semibold)
        estado.textColor = BloomindStyle.lab

        detalle.font = BloomindStyle.ui(11)
        detalle.textColor = BloomindStyle.muted

        puntoColor.wantsLayer = true
        puntoColor.layer?.cornerRadius = 5
        puntoColor.layer?.borderWidth = 1
        puntoColor.layer?.borderColor = CGColor(gray: 0.6, alpha: 1)
        puntoColor.isHidden = true
        puntoColor.translatesAutoresizingMaskIntoConstraints = false
        puntoColor.widthAnchor.constraint(equalToConstant: 10).isActive = true
        puntoColor.heightAnchor.constraint(equalToConstant: 10).isActive = true

        configurar(alternarTamaño, simbolo: "chevron.down", nombre: "Más",
                   ayuda: "Mostrar todos los botones", accion: #selector(tocarAlternarTamaño))

        let espaciador = NSView()
        espaciador.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let fila1 = NSStackView(views: [tiempo, estado, espaciador, alternarTamaño])
        fila1.orientation = .horizontal
        fila1.spacing = BloomindStyle.Space.tight
        fila1.alignment = .centerY

        let fila2 = NSStackView(views: [puntoColor, detalle])
        fila2.orientation = .horizontal
        fila2.spacing = 6
        fila2.alignment = .centerY

        configurar(pausar, simbolo: "pause.fill", nombre: "Pausar", ayuda: "Pausar", accion: #selector(tocarPausa))
        configurar(detener, simbolo: "stop.fill", nombre: "Detener", ayuda: "Detener", accion: #selector(tocarDetener))
        configurar(reiniciar, simbolo: "arrow.counterclockwise", nombre: "Reiniciar", ayuda: "Reiniciar toma", accion: #selector(tocarReiniciar))
        // "Cam on/off" y no "Cámara" a secas: el botón prende y apaga la cámara,
        // y el modo de cámara completa tiene el suyo propio abajo. Dos botones
        // llamados igual haciendo cosas distintas es peor que no ponerles nombre.
        configurar(burbuja, simbolo: "person.crop.circle", nombre: "Cam on/off", ayuda: "Cámara", accion: #selector(tocarBurbuja))
        // Mantener presionado el botón: el menú de cámaras, haya o no una prendida.
        let menuLargo = NSPressGestureRecognizer(target: self, action: #selector(mostrarMenuDeCamara))
        menuLargo.minimumPressDuration = 0.35
        burbuja.addGestureRecognizer(menuLargo)
        configurar(microfono, simbolo: "mic.fill", nombre: "Micrófono", ayuda: "Silenciar micrófono", accion: #selector(tocarMicrofono))
        configurar(sistema, simbolo: "speaker.wave.2.fill", nombre: "Sonido PC", ayuda: "Silenciar audio del sistema", accion: #selector(tocarSistema))

        let botones = NSStackView(views: [pausar, detener, reiniciar, burbuja, microfono, sistema])
        botones.orientation = .horizontal
        botones.spacing = Self.separacion

        let modos = filaDeAcciones(Self.filaModos)
        let ayudas = filaDeAcciones(Self.filaAyudas)
        let tablero = filaDeAcciones(Self.filaTablero)

        // Cada fila con su título encima: dieciocho botones seguidos son una
        // pared, y agrupados se encuentra lo que se busca sin leerlos todos
        // (decisión 100). El título del primer grupo se ve siempre, porque esa
        // fila también está en el modo compacto.
        let tituloGrabacion = titulo("Comandos de grabación")
        let tituloPantalla = titulo("Pantalla a grabar")
        let tituloComandos = titulo("Comandos")
        let tituloTablero = titulo("Comandos tableros")
        filasExpandidas = [tituloPantalla, modos, tituloComandos, ayudas, tituloTablero, tablero]

        let todo = NSStackView(views: [fila1, fila2, tituloGrabacion, botones,
                                       tituloPantalla, modos,
                                       tituloComandos, ayudas,
                                       tituloTablero, tablero])
        todo.orientation = .vertical
        todo.alignment = .leading
        todo.spacing = 4
        // Aire extra **antes** de cada título, o sea después de lo que lo precede:
        // es lo que hace que los grupos se lean como grupos y no como cuatro
        // filas seguidas. El título queda pegado a su fila, no a la de arriba.
        for anterior in [fila2, botones, modos, ayudas] {
            todo.setCustomSpacing(BloomindStyle.Space.normal, after: anterior)
        }
        todo.translatesAutoresizingMaskIntoConstraints = false
        fondo.addSubview(todo)

        NSLayoutConstraint.activate([
            todo.leadingAnchor.constraint(equalTo: fondo.leadingAnchor, constant: BloomindStyle.Space.normal),
            todo.trailingAnchor.constraint(lessThanOrEqualTo: fondo.trailingAnchor, constant: -BloomindStyle.Space.normal),
            todo.topAnchor.constraint(equalTo: fondo.topAnchor, constant: BloomindStyle.Space.tight),
            todo.bottomAnchor.constraint(equalTo: fondo.bottomAnchor, constant: -BloomindStyle.Space.tight)
        ])

        contentView = fondo
    }

    /// El título de un grupo de botones, con el estilo de marca.
    private func titulo(_ texto: String) -> NSTextField {
        let etiqueta = NSTextField(labelWithString: "")
        etiqueta.attributedStringValue = BloomindStyle.eyebrow(texto)
        return etiqueta
    }

    /// Una fila de botones, uno por acción, todos ruteados a `onAction`.
    private func filaDeAcciones(_ acciones: [(ShortcutAction, String, String)]) -> NSStackView {
        let fila = NSStackView()
        fila.orientation = .horizontal
        fila.spacing = Self.separacion

        for (accion, simbolo, nombre) in acciones {
            let boton = NSButton()
            // El nombre corto se lee en el botón; en el tooltip va la etiqueta
            // del registro, que es la misma que muestran la tarjeta de atajos y
            // la pantalla de preferencias.
            configurar(boton, simbolo: simbolo, nombre: nombre, ayuda: accion.label, accion: #selector(tocarAccion(_:)))
            boton.tag = ShortcutAction.allCases.firstIndex(of: accion) ?? 0
            porAccion[accion] = boton
            fila.addArrangedSubview(boton)
        }
        return fila
    }

    /// Ancho y alto **fijos** de todos los botones.
    ///
    /// Fijos y no mínimos: con ancho mínimo cada botón se estira lo que le pide
    /// su palabra, "Cam on/off" queda más ancho que "Pausar", y las cuatro filas
    /// dejan de alinearse entre sí. El ancho lo manda la palabra más larga y
    /// todos los demás la acompañan, que es lo que hace que se vea una grilla.
    private static let anchoBoton: CGFloat = 74
    private static let altoBoton: CGFloat = 46
    /// Separación entre botones, la misma en horizontal y en vertical.
    private static let separacion: CGFloat = 6

    /// Todos los íconos al mismo tamaño óptico. Sin esto cada símbolo del
    /// sistema trae el suyo —la goma de borrar se dibuja bastante más grande que
    /// la flecha del cursor— y la fila queda despareja aunque los botones midan
    /// todos lo mismo.
    private static let simbolo = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)

    /// Un ícono del sistema, ya emparejado.
    private static func icono(_ nombre: String, _ ayuda: String) -> NSImage? {
        NSImage(systemSymbolName: nombre, accessibilityDescription: ayuda)?
            .withSymbolConfiguration(simbolo)
    }

    /// Un botón del widget: ícono arriba, nombre abajo.
    ///
    /// **El nombre va siempre a la vista** (decisión 99). Un ícono solo obliga a
    /// adivinar o a esperar el tooltip, y en mitad de una clase no hay tiempo
    /// para ninguna de las dos cosas. Si el símbolo del sistema no existiera en
    /// esta versión de macOS, el botón igual se entiende: queda el nombre.
    private func configurar(_ boton: NSButton, simbolo: String, nombre: String, ayuda: String, accion: Selector) {
        boton.title = nombre
        boton.font = BloomindStyle.ui(9)
        if let imagen = Self.icono(simbolo, ayuda) {
            boton.image = imagen
            boton.imagePosition = .imageAbove
        } else {
            boton.imagePosition = .noImage
        }
        // Sin borde de sistema y con capa propia: el fondo del botón lo pintamos
        // nosotros, que es lo único que permite mostrar "prendido" y "apagado"
        // de un vistazo. `bezelColor` se probó primero y macOS lo ignora con
        // cualquier estilo de bezel que deje poner el ícono arriba del nombre.
        boton.isBordered = false
        boton.wantsLayer = true
        boton.layer?.cornerRadius = 6
        boton.toolTip = ayuda
        boton.target = self
        boton.action = accion
        boton.translatesAutoresizingMaskIntoConstraints = false
        boton.widthAnchor.constraint(equalToConstant: Self.anchoBoton).isActive = true
        boton.heightAnchor.constraint(equalToConstant: Self.altoBoton).isActive = true
        pintar(boton, .apagado)
    }

    /// Abajo a la derecha de la pantalla principal la primera vez; después
    /// recuerda dónde lo dejaste.
    private func colocar() {
        if let guardada = ConfigurationStore.shared.current.widgetPosition {
            let punto = NSPoint(x: guardada.x, y: guardada.y)
            if NSScreen.screens.contains(where: { $0.frame.contains(punto) }) {
                setFrameOrigin(punto)
                return
            }
        }
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        setFrameOrigin(NSPoint(x: visible.maxX - frame.width - BloomindStyle.Space.card,
                               y: visible.maxY - frame.height - BloomindStyle.Space.card))
    }

    // MARK: - Compacto y expandido

    /// Muestra u oculta las filas de más y ajusta la ventana a su contenido.
    ///
    /// Crece y se encoge **hacia abajo**: el borde de arriba se queda donde
    /// estaba. Si creciera hacia arriba, expandirlo con el widget apoyado contra
    /// el borde superior de la pantalla lo empujaría fuera de la vista.
    private func aplicarTamaño(manteniendoArriba: Bool) {
        for fila in filasExpandidas { fila.isHidden = !expandido }

        alternarTamaño.image = Self.icono(expandido ? "chevron.up" : "chevron.down", "")
        alternarTamaño.title = expandido ? "Menos" : "Más"
        alternarTamaño.toolTip = expandido ? "Dejar solo los botones de siempre" : "Mostrar todos los botones"

        guard let contenido = contentView else { return }
        contenido.layoutSubtreeIfNeeded()
        let borde = frame.maxY
        setContentSize(contenido.fittingSize)
        if manteniendoArriba {
            setFrameTopLeftPoint(NSPoint(x: frame.minX, y: borde))
        }
    }

    @objc private func tocarAlternarTamaño() {
        expandido.toggle()
        ConfigurationStore.shared.update { $0.widgetExpanded = expandido }
        aplicarTamaño(manteniendoArriba: true)
        Logger.shared.log("Widget en modo \(expandido ? "expandido" : "compacto")")
    }

    // MARK: - Estado

    /// Refresca todo lo que muestra.
    func update(segundos: Int,
                pausado: Bool,
                modo: CaptureMode,
                censura: Bool,
                anotando: Bool,
                color: MarkerColor,
                hayCamara: Bool,
                resaltadoCursor: Bool,
                audio: AudioState) {

        tiempo.stringValue = String(format: "%02d:%02d", segundos / 60, segundos % 60)
        estado.stringValue = pausado ? "❚❚ PAUSADO" : "● GRABANDO"
        // El turquesa es exclusivo del éxito: grabando va en lab, pausado en gris.
        estado.textColor = pausado ? BloomindStyle.muted : BloomindStyle.lab

        var partes: [String] = []
        switch modo {
        case .pantalla: partes.append("Pantalla")
        case .camara:   partes.append("Cámara")
        case .tablero:  partes.append("Tablero")
        }
        if anotando { partes.append("anotando") }
        if censura { partes.append("▓ censura") }
        // El círculo del cursor no se ve en la pantalla de quien graba, solo en
        // el video: sin este aviso, la única forma de saber que está apagado es
        // acordarse de haberlo apagado.
        if !resaltadoCursor { partes.append("sin cursor") }
        // El silencio va con nombre y no solo con el ícono tachado: es lo que
        // evita grabar media clase mudo sin darse cuenta.
        if audio.microfonoSilenciado && audio.sistemaSilenciado {
            partes.append("🔇 SIN AUDIO")
        } else if audio.microfonoSilenciado {
            partes.append("🔇 micrófono")
        } else if audio.sistemaSilenciado {
            partes.append("🔇 sistema")
        }
        detalle.stringValue = partes.joined(separator: " · ")

        // El punto de color solo tiene sentido cuando se está dibujando.
        let dibujando = modo == .tablero || anotando
        puntoColor.isHidden = !dibujando
        puntoColor.layer?.backgroundColor = color.cgColor

        pausar.image = Self.icono(pausado ? "play.fill" : "pause.fill",
                                  pausado ? "Reanudar" : "Pausar")
        pausar.toolTip = pausado ? "Reanudar" : "Pausar"
        // El botón de cámara nunca se deshabilita: sin cámara prendida sigue
        // sirviendo para prender una, que es justo lo que pasa cuando se arrancó
        // a grabar sin elegir ninguna (decisión 82). Un botón deshabilitado no
        // recibe clics y el menú quedaría inalcanzable justo cuando hace falta.
        hayCamaraPrendida = hayCamara
        burbuja.isEnabled = true
        burbuja.image = Self.icono(hayCamara ? "person.crop.circle" : "person.crop.circle.badge.plus", "Cámara")
        burbuja.toolTip = hayCamara
            ? "Apagar la cámara · mantené o clic derecho para elegir otra"
            : "Elegir y prender una cámara"
        pintar(burbuja, hayCamara ? .prendido : .apagado)

        // Las fuentes que no se eligieron antes de arrancar quedan deshabilitadas,
        // no ausentes: el botón no es un atajo para encenderlas (decisión 82).
        actualizar(microfono, activa: audio.capturaMicrofono, silenciada: audio.microfonoSilenciado,
                   simboloVivo: "mic.fill", simboloMudo: "mic.slash.fill",
                   ayudaViva: "Silenciar micrófono", ayudaMuda: "Activar micrófono")
        actualizar(sistema, activa: audio.capturaSistema, silenciada: audio.sistemaSilenciado,
                   simboloVivo: "speaker.wave.2.fill", simboloMudo: "speaker.slash.fill",
                   ayudaViva: "Silenciar audio del sistema", ayudaMuda: "Activar audio del sistema")

        actualizarBotonesExpandidos(modo: modo, censura: censura, anotando: anotando,
                                    dibujando: dibujando, hayCamara: hayCamara,
                                    resaltadoCursor: resaltadoCursor)
    }

    /// Estado de audio que muestra el widget.
    struct AudioState {
        let capturaMicrofono: Bool
        let capturaSistema: Bool
        let microfonoSilenciado: Bool
        let sistemaSilenciado: Bool
    }

    /// Cómo se ve un botón según su estado. Es lo que responde de un vistazo la
    /// pregunta "¿esto está prendido?" (decisión 101).
    enum EstadoBoton {
        /// Prendido y haciendo efecto ahora mismo: fondo azul de marca.
        case prendido
        /// Prendido y tapando algo: fondo coral, el color de alerta de la marca.
        case alerta
        /// Disponible pero apagado.
        case apagado
    }

    /// Pinta el estado de un botón.
    ///
    /// El fondo lleno es la señal, no el tinte del ícono: el tinte cambia unos
    /// pocos píxeles del dibujito y a un metro de la pantalla los dos estados se
    /// ven iguales, que es exactamente el problema que esto resuelve. El título
    /// va en blanco sobre el fondo lleno para que se siga leyendo.
    private func pintar(_ boton: NSButton, _ estado: EstadoBoton) {
        // Apagado no es "sin fondo": un fondo tenue es lo que hace que se siga
        // viendo como un botón y no como texto suelto.
        let fondo: NSColor
        let tinta: NSColor
        switch estado {
        case .prendido: fondo = BloomindStyle.lab;    tinta = .white
        case .alerta:   fondo = BloomindStyle.signal; tinta = .white
        case .apagado:  fondo = NSColor(white: 1, alpha: 0.10); tinta = BloomindStyle.ink
        }
        boton.layer?.backgroundColor = fondo.cgColor
        boton.contentTintColor = tinta
        titular(boton, color: tinta)
    }

    /// El color del texto de un botón se cambia por título con atributos: NSButton
    /// no tiene una propiedad para eso.
    private func titular(_ boton: NSButton, color: NSColor) {
        boton.attributedTitle = NSAttributedString(string: boton.title, attributes: [
            .font: BloomindStyle.ui(9),
            .foregroundColor: color,
            .paragraphStyle: {
                let p = NSMutableParagraphStyle()
                p.alignment = .center
                return p
            }()
        ])
    }

    /// Marca el modo activo, tiñe lo que está prendido y apaga lo que no aplica.
    ///
    /// Deshabilitar en vez de esconder: un botón que desaparece y vuelve mueve a
    /// los de al lado, y en mitad de una clase eso hace tocar el equivocado.
    private func actualizarBotonesExpandidos(modo: CaptureMode, censura: Bool,
                                             anotando: Bool, dibujando: Bool,
                                             hayCamara: Bool, resaltadoCursor: Bool) {
        for (accion, boton) in porAccion {
            boton.isEnabled = true
            pintar(boton, .apagado)

            switch accion {
            case .modoPantalla: pintar(boton, modo == .pantalla ? .prendido : .apagado)
            case .modoTablero:  pintar(boton, modo == .tablero ? .prendido : .apagado)
            case .modoCamara:
                // Sin cámara no hay modo cámara completa: el fondo del frame
                // quedaría en negro (decisión 83).
                boton.isEnabled = hayCamara
                pintar(boton, modo == .camara ? .prendido : .apagado)
                boton.toolTip = hayCamara ? accion.label : "No hay ninguna cámara prendida"
            case .censura:
                // Coral y no azul: la censura prendida está tapando algo del
                // video, y eso se mira distinto que un modo activo.
                pintar(boton, censura ? .alerta : .apagado)
                boton.toolTip = censura ? "Destapar la zona censurada" : "Tapar la zona censurada"
            case .capaAnotacion:
                pintar(boton, anotando ? .prendido : .apagado)
                boton.toolTip = anotando ? "Apagar el marcador" : "Prender el marcador sobre la pantalla"
            case .resaltadoCursor:
                // El círculo no está en la pantalla de Sebas, solo en el video,
                // así que este botón es la única forma de saber si está puesto.
                pintar(boton, resaltadoCursor ? .prendido : .apagado)
                boton.toolTip = resaltadoCursor
                    ? "Apagar el círculo del cursor y el efecto del clic"
                    : "Prender el círculo del cursor y el efecto del clic"
            case .colorTablero:
                // El lienzo solo existe en el tablero.
                boton.isEnabled = modo == .tablero
            case .deshacer, .borrar:
                // Actúan sobre la superficie de dibujo activa; sin ninguna
                // prendida no tienen sobre qué actuar.
                boton.isEnabled = dibujando
            default:
                break
            }
        }
    }

    /// Un botón de audio: prendido, mudo o deshabilitado. El símbolo tachado es
    /// lo que hace que se vea de reojo en mitad de una clase, sin leer.
    private func actualizar(_ boton: NSButton, activa: Bool, silenciada: Bool,
                            simboloVivo: String, simboloMudo: String,
                            ayudaViva: String, ayudaMuda: String) {
        boton.isEnabled = activa
        let simbolo = silenciada ? simboloMudo : simboloVivo
        let ayuda = silenciada ? ayudaMuda : ayudaViva
        boton.image = Self.icono(simbolo, ayuda)
        boton.toolTip = activa ? ayuda : "No se eligió esta fuente antes de grabar"
        // Acá el fondo lleno marca lo **silenciado**, no lo prendido: un
        // micrófono abierto es lo normal y lo que hay que ver de lejos es el que
        // está mudo.
        pintar(boton, silenciada ? .alerta : .apagado)
    }

    func present() {
        orderFrontRegardless()
    }

    func hide() {
        guardarPosicion()
        orderOut(nil)
    }

    // MARK: - Interno

    private func guardarPosicion() {
        let origen = frame.origin
        ConfigurationStore.shared.update {
            $0.widgetPosition = StoredPoint(x: origen.x, y: origen.y)
        }
    }

    @objc private func tocarPausa() { onPause?() }
    @objc private func tocarDetener() { onStop?() }

    /// Los botones del modo expandido: cada uno dispara la acción de su atajo.
    @objc private func tocarAccion(_ boton: NSButton) {
        let acciones = ShortcutAction.allCases
        guard boton.tag >= 0, boton.tag < acciones.count else { return }
        onAction?(acciones[boton.tag])
    }

    /// Con cámara prendida, el botón prende y apaga la burbuja, que es lo que se
    /// hace veinte veces en una clase. El menú, que es lo que se hace una vez,
    /// sale manteniéndolo o con clic derecho. Sin cámara prendida, el clic normal
    /// abre el menú directo: no hay burbuja que alternar todavía.
    @objc private func tocarBurbuja() {
        if hayCamaraPrendida { onToggleBubble?() } else { mostrarMenuDeCamara() }
    }

    @objc private func mostrarMenuDeCamara() {
        guard let menu = onCameraMenu?() else { return }
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: burbuja.bounds.height + 4),
                   in: burbuja)
    }
    @objc private func tocarMicrofono() { onToggleMicrophone?() }
    @objc private func tocarSistema() { onToggleSystemAudio?() }

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
