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

    /// La gramática de botón, compartida con la barra del teleprompter.
    private typealias Boton = CommandButton

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

    /// Los controles del teleprompter, con el control que dispara cada uno.
    /// No van por `ShortcutAction` porque no son atajos del registro central:
    /// sus teclas son sueltas y viven en la ventana del teleprompter
    /// (decisión 92).
    private var porControl: [(boton: NSButton, control: TeleprompterWindow.Control)] = []
    private var filaTeleprompter: NSStackView?

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
    /// **Las filas miden 7, 6, 6 y 7 botones**, en ese orden, y esa simetría no
    /// es casual: es lo que hace que el bloque se lea como un rectángulo y no
    /// como una escalera (decisión 111). Antes eran 7, 3, 5, 4 y 7, y el borde
    /// derecho quedaba dentado.
    ///
    /// Los dos grupos chicos —los tres modos de fuente y los tres de tablero—
    /// comparten fila, cada uno con su título arriba de su tramo.
    private static let filaModosYTablero: [(ShortcutAction, String, String)] = [
        (.modoPantalla, "display",           "Pantalla"),
        (.modoCamara,   "video.fill",        "Cám. full"),
        (.modoTablero,  "square.and.pencil", "Tablero"),
        (.colorTablero,     "circle.lefthalf.filled", "Lienzo"),
        (.deshacer,         "arrow.uturn.backward",   "Deshacer"),
        (.borrar,           "eraser.fill",            "Borrar")
    ]

    /// Cuántos de la fila de arriba son del primer grupo. Lo usan los dos
    /// títulos para saber dónde arranca el segundo.
    private static let columnasDeModos = 3

    /// La tarjeta de atajos vive acá y no con los del tablero: es una ayuda
    /// general, no un comando de tablero, y de paso es lo que deja las dos filas
    /// del medio parejas en seis.
    private static let filaAyudas: [(ShortcutAction, String, String)] = [
        (.resaltadoCursor,  "cursorarrow.rays",       "Cursor"),
        (.censura,          "eye.slash.fill",         "Censura"),
        (.redibujarCensura, "rectangle.dashed",       "Redibujar"),
        (.capaAnotacion,    "pencil.tip.crop.circle", "Marcador"),
        (.colorMarcador,    "paintpalette.fill",      "Color"),
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

        // Por línea de base y no por centro: el cronómetro es casi el doble de
        // grande que la palabra de al lado, y centrados por su caja "GRABANDO"
        // queda flotando a media altura del número en vez de apoyado en él.
        let fila1 = NSStackView(views: [tiempo, estado])
        fila1.orientation = .horizontal
        fila1.spacing = BloomindStyle.Space.tight
        fila1.alignment = .firstBaseline

        let fila2 = NSStackView(views: [puntoColor, detalle])
        fila2.orientation = .horizontal
        fila2.spacing = 6
        fila2.alignment = .centerY

        let textoCabecera = NSStackView(views: [fila1, fila2])
        textoCabecera.orientation = .vertical
        textoCabecera.alignment = .leading
        textoCabecera.spacing = 6

        // El botón de alternar tamaño va centrado contra las **dos** líneas, no
        // colgado de la primera: pegado arriba dejaba la cabecera con un vacío
        // en diagonal entre el cronómetro y él.
        let cabecera = NSStackView(views: [textoCabecera, espaciador, alternarTamaño])
        cabecera.orientation = .horizontal
        cabecera.alignment = .centerY
        cabecera.spacing = BloomindStyle.Space.tight

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

        // El teleprompter on/off va en la fila compacta (plan, 8.9): prenderlo y
        // apagarlo es de lo que más se hace en vivo. Es una acción del registro
        // de atajos, así que se rutea igual que los botones de abajo.
        let teleprompter = NSButton()
        configurar(teleprompter, simbolo: "text.line.first.and.arrowtriangle.forward",
                   nombre: "Guion", ayuda: ShortcutAction.teleprompter.label,
                   accion: #selector(tocarAccion(_:)))
        teleprompter.tag = ShortcutAction.allCases.firstIndex(of: .teleprompter) ?? 0
        porAccion[.teleprompter] = teleprompter

        let botones = NSStackView(views: [pausar, detener, reiniciar, burbuja, microfono, sistema, teleprompter])
        botones.orientation = .horizontal
        botones.spacing = Boton.separacion

        let modos = filaDeAcciones(Self.filaModosYTablero)
        let ayudas = filaDeAcciones(Self.filaAyudas)

        // Cada fila con su título encima: dieciocho botones seguidos son una
        // pared, y agrupados se encuentra lo que se busca sin leerlos todos
        // (decisión 100). El título del primer grupo se ve siempre, porque esa
        // fila también está en el modo compacto.
        let tituloGrabacion = titulo("Comandos de grabación")
        // Dos títulos en un renglón, cada uno arrancando en la columna de su
        // grupo: los modos de fuente y los del tablero comparten fila.
        let titulosDelMedio = dosTitulos("Pantalla a grabar", "Comandos tableros",
                                         columnasDelPrimero: Self.columnasDeModos)
        let tituloComandos = titulo("Comandos")
        let tituloTeleprompter = titulo("Teleprompter")
        let teleprompterFila = filaDeControles()
        filaTeleprompter = teleprompterFila
        filasExpandidas = [titulosDelMedio, modos, tituloComandos, ayudas,
                           tituloTeleprompter, teleprompterFila]

        let todo = NSStackView(views: [cabecera, tituloGrabacion, botones,
                                       titulosDelMedio, modos,
                                       tituloComandos, ayudas,
                                       tituloTeleprompter, teleprompterFila])
        todo.orientation = .vertical
        todo.alignment = .leading
        todo.spacing = 4
        // Aire extra **antes** de cada título, o sea después de lo que lo precede:
        // es lo que hace que los grupos se lean como grupos y no como cuatro
        // filas seguidas. El título queda pegado a su fila, no a la de arriba.
        for anterior in [cabecera, botones, modos, ayudas] {
            todo.setCustomSpacing(BloomindStyle.Space.normal, after: anterior)
        }
        todo.translatesAutoresizingMaskIntoConstraints = false
        fondo.addSubview(todo)

        NSLayoutConstraint.activate([
            cabecera.widthAnchor.constraint(equalTo: todo.widthAnchor),
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

    /// Dos títulos en el mismo renglón, el segundo arrancando justo encima de
    /// su primera columna. El ancho del primero se calcula con la misma grilla
    /// que los botones, así que si cambia el ancho del botón esto acompaña solo.
    private func dosTitulos(_ primero: String, _ segundo: String, columnasDelPrimero: Int) -> NSStackView {
        let izquierda = titulo(primero)
        izquierda.translatesAutoresizingMaskIntoConstraints = false
        izquierda.widthAnchor.constraint(
            equalToConstant: CGFloat(columnasDelPrimero) * (Boton.ancho + Boton.separacion)
        ).isActive = true

        let fila = NSStackView(views: [izquierda, titulo(segundo)])
        fila.orientation = .horizontal
        fila.alignment = .firstBaseline
        fila.spacing = 0
        return fila
    }

    /// Una fila de botones, uno por acción, todos ruteados a `onAction`.
    private func filaDeAcciones(_ acciones: [(ShortcutAction, String, String)]) -> NSStackView {
        let fila = NSStackView()
        fila.orientation = .horizontal
        fila.spacing = Boton.separacion

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

    /// Los controles del teleprompter. Son siete y quedan parejos con la fila
    /// compacta, que también tiene siete: las dos mandan el ancho del widget.
    private static let controlesTeleprompter: [(TeleprompterWindow.Control, String, String, String)] = [
        (.playPausa,      "play.fill",         "Play",     "Play y pausa del guion"),
        (.reiniciar,      "arrow.uturn.left",  "Al inicio", "Volver al principio del guion"),
        (.menosVelocidad, "tortoise.fill",     "Más lento", "Bajar la velocidad del guion"),
        (.masVelocidad,   "hare.fill",         "Más rápido", "Subir la velocidad del guion"),
        // Menos y más pelados: los símbolos de "texto más chico" y "texto más
        // grande" del sistema se dibujan los dos como una A del mismo tamaño, o
        // sea que no distinguen nada.
        (.menosLetra,     "minus.circle",      "Letra −", "Letra más chica"),
        (.masLetra,       "plus.circle",       "Letra +", "Letra más grande"),
        (.editar,         "pencil",            "Editar",   "Editar el guion")
    ]

    private func filaDeControles() -> NSStackView {
        let fila = NSStackView()
        fila.orientation = .horizontal
        fila.spacing = Boton.separacion

        for (indice, (control, simbolo, nombre, ayuda)) in Self.controlesTeleprompter.enumerated() {
            let boton = NSButton()
            configurar(boton, simbolo: simbolo, nombre: nombre, ayuda: ayuda, accion: #selector(tocarControl(_:)))
            boton.tag = indice
            porControl.append((boton, control))
            fila.addArrangedSubview(boton)
        }
        return fila
    }

    @objc private func tocarControl(_ boton: NSButton) {
        guard boton.tag >= 0, boton.tag < porControl.count else { return }
        onTeleprompterControl?(porControl[boton.tag].control)
    }


    /// Un botón del widget, con la gramática compartida de `CommandButton`.
    private func configurar(_ boton: NSButton, simbolo: String, nombre: String, ayuda: String, accion: Selector) {
        Boton.configurar(boton, simbolo: simbolo, nombre: nombre, ayuda: ayuda, target: self, accion: accion)
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

        alternarTamaño.image = Boton.icono(expandido ? "chevron.up" : "chevron.down", "")
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
                teleprompter: TeleprompterState,
                audio: AudioState) {

        tiempo.stringValue = String(format: "%02d:%02d", segundos / 60, segundos % 60)
        estado.stringValue = pausado ? "❚❚ PAUSADO" : "● GRABANDO"
        // El turquesa es exclusivo del éxito: grabando va en lab, pausado en gris.
        estado.textColor = pausado ? BloomindStyle.muted : BloomindStyle.lab

        // Sin emojis: el altavoz tachado y el bloque de censura se dibujan a
        // color y con otro trazo que los símbolos del resto de la interfaz, así
        // que ensuciaban el único renglón de texto del widget. Lo que distingue
        // un estado de alerta acá es el color coral, el mismo de los botones
        // (decisión 114).
        var partes: [(String, NSColor)] = []
        switch modo {
        case .pantalla: partes.append(("Pantalla", BloomindStyle.muted))
        case .camara:   partes.append(("Cámara", BloomindStyle.muted))
        case .tablero:  partes.append(("Tablero", BloomindStyle.muted))
        }
        if anotando { partes.append(("anotando", BloomindStyle.muted)) }
        if censura { partes.append(("censura", BloomindStyle.signal)) }
        // El círculo del cursor no se ve en la pantalla de quien graba, solo en
        // el video: sin este aviso, la única forma de saber que está apagado es
        // acordarse de haberlo apagado.
        if !resaltadoCursor { partes.append(("sin cursor", BloomindStyle.muted)) }
        // El silencio va con nombre y no solo con el ícono tachado: es lo que
        // evita grabar media clase mudo sin darse cuenta.
        if audio.microfonoSilenciado && audio.sistemaSilenciado {
            partes.append(("SIN AUDIO", BloomindStyle.signal))
        } else if audio.microfonoSilenciado {
            partes.append(("micrófono mudo", BloomindStyle.signal))
        } else if audio.sistemaSilenciado {
            partes.append(("sonido mudo", BloomindStyle.signal))
        }
        detalle.attributedStringValue = renglon(partes)

        // El punto de color solo tiene sentido cuando se está dibujando.
        let dibujando = modo == .tablero || anotando
        puntoColor.isHidden = !dibujando
        puntoColor.layer?.backgroundColor = color.cgColor

        pausar.image = Boton.icono(pausado ? "play.fill" : "pause.fill",
                                  pausado ? "Reanudar" : "Pausar")
        pausar.toolTip = pausado ? "Reanudar" : "Pausar"
        // El botón de cámara nunca se deshabilita: sin cámara prendida sigue
        // sirviendo para prender una, que es justo lo que pasa cuando se arrancó
        // a grabar sin elegir ninguna (decisión 82). Un botón deshabilitado no
        // recibe clics y el menú quedaría inalcanzable justo cuando hace falta.
        hayCamaraPrendida = hayCamara
        burbuja.isEnabled = true
        burbuja.image = Boton.icono(hayCamara ? "person.crop.circle" : "person.crop.circle.badge.plus", "Cámara")
        burbuja.toolTip = hayCamara
            ? "Apagar la cámara · mantené o clic derecho para elegir otra"
            : "Elegir y prender una cámara"
        Boton.pintar(burbuja, hayCamara ? .prendido : .apagado)

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
                                    resaltadoCursor: resaltadoCursor,
                                    teleprompter: teleprompter)

        actualizarTeleprompter(teleprompter)
    }

    /// Arma el renglón de estado con un color por parte, separadas por puntos.
    private func renglon(_ partes: [(String, NSColor)]) -> NSAttributedString {
        let texto = NSMutableAttributedString()
        for (indice, parte) in partes.enumerated() {
            if indice > 0 {
                texto.append(NSAttributedString(string: " · ", attributes: [
                    .font: BloomindStyle.ui(11), .foregroundColor: BloomindStyle.hairline
                ]))
            }
            texto.append(NSAttributedString(string: parte.0, attributes: [
                .font: BloomindStyle.ui(11), .foregroundColor: parte.1
            ]))
        }
        return texto
    }

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

    /// Los controles quedan deshabilitados mientras el teleprompter está apagado
    /// (plan, 8.9): no son una forma de prenderlo, solo de manejarlo.
    private func actualizarTeleprompter(_ estado: TeleprompterState) {
        for (boton, control) in porControl {
            boton.isEnabled = estado.visible
            switch control {
            case .playPausa:
                // El único de la fila con estado: azul mientras el guion sube.
                boton.image = Boton.icono(estado.corriendo ? "pause.fill" : "play.fill", "Play y pausa del guion")
                boton.title = estado.corriendo ? "Pausa" : "Play"
                Boton.pintar(boton, estado.corriendo ? .prendido : .apagado)
                // Con el guion abierto para editar no se puede hacer correr.
                boton.isEnabled = estado.visible && !estado.editando
            case .editar:
                boton.title = estado.editando ? "Leer" : "Editar"
                Boton.pintar(boton, estado.editando ? .prendido : .apagado)
            default:
                Boton.pintar(boton, .apagado)
            }
        }
    }

    /// Estado de audio que muestra el widget.
    struct AudioState {
        let capturaMicrofono: Bool
        let capturaSistema: Bool
        let microfonoSilenciado: Bool
        let sistemaSilenciado: Bool
    }


    /// Marca el modo activo, tiñe lo que está prendido y apaga lo que no aplica.
    ///
    /// Deshabilitar en vez de esconder: un botón que desaparece y vuelve mueve a
    /// los de al lado, y en mitad de una clase eso hace tocar el equivocado.
    private func actualizarBotonesExpandidos(modo: CaptureMode, censura: Bool,
                                             anotando: Bool, dibujando: Bool,
                                             hayCamara: Bool, resaltadoCursor: Bool,
                                             teleprompter: TeleprompterState) {
        for (accion, boton) in porAccion {
            boton.isEnabled = true
            Boton.pintar(boton, .apagado)

            switch accion {
            case .modoPantalla: Boton.pintar(boton, modo == .pantalla ? .prendido : .apagado)
            case .modoTablero:  Boton.pintar(boton, modo == .tablero ? .prendido : .apagado)
            case .modoCamara:
                // Sin cámara no hay modo cámara completa: el fondo del frame
                // quedaría en negro (decisión 83).
                boton.isEnabled = hayCamara
                Boton.pintar(boton, modo == .camara ? .prendido : .apagado)
                boton.toolTip = hayCamara ? accion.label : "No hay ninguna cámara prendida"
            case .censura:
                // Coral y no azul: la censura prendida está tapando algo del
                // video, y eso se mira distinto que un modo activo.
                Boton.pintar(boton, censura ? .alerta : .apagado)
                boton.toolTip = censura ? "Destapar la zona censurada" : "Tapar la zona censurada"
            case .capaAnotacion:
                Boton.pintar(boton, anotando ? .prendido : .apagado)
                boton.toolTip = anotando ? "Apagar el marcador" : "Prender el marcador sobre la pantalla"
            case .resaltadoCursor:
                // El círculo no está en la pantalla de Sebas, solo en el video,
                // así que este botón es la única forma de saber si está puesto.
                Boton.pintar(boton, resaltadoCursor ? .prendido : .apagado)
                boton.toolTip = resaltadoCursor
                    ? "Apagar el círculo del cursor y el efecto del clic"
                    : "Prender el círculo del cursor y el efecto del clic"
            case .teleprompter:
                // Es el único botón de la fila compacta que se pinta acá: su
                // acción vive en el registro de atajos como cualquier otra.
                Boton.pintar(boton, teleprompter.visible ? .prendido : .apagado)
                boton.toolTip = teleprompter.visible ? "Esconder el guion" : "Mostrar el guion"
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
        boton.image = Boton.icono(simbolo, ayuda)
        boton.toolTip = activa ? ayuda : "No se eligió esta fuente antes de grabar"
        // Acá el fondo lleno marca lo **silenciado**, no lo prendido: un
        // micrófono abierto es lo normal y lo que hay que ver de lejos es el que
        // está mudo.
        Boton.pintar(boton, silenciada ? .alerta : .apagado)
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
