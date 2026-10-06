import CoreGraphics
import Foundation

/// Lo que el tutorial puede iluminar.
enum ObjetivoTutorial: Equatable {
    // El panel.
    case titulo
    case frase(PanelSentence.Parte)
    case carpeta
    case cuenta
    case estado
    case grabar
    // La cápsula, grabando.
    case reloj
    case pausar
    case reiniciar
    case audio
    case camara
    case queSeVe
    case tablero
    case sobreLaPantalla
    case guion
    case achicar
    case detener
    // El resto.
    case teleprompter
    case barraDeMenu
}

/// Un paso del recorrido (decisión 137).
///
/// Los textos le hablan a alguien que nunca vio la app: qué es, qué hacer y
/// qué va a pasar, sin una sola palabra técnica.
struct PasoTutorial {
    let titulo: String
    let texto: String
    /// Nil: la burbuja va al centro, sin iluminar nada.
    let objetivo: ObjetivoTutorial?
    /// Falso donde hay que poder tocar toda la pantalla, como al dibujar en el
    /// tablero: ahí solo se marca el borde (decisión 138).
    var oscurecer = true
    /// El paso avanza solo cuando pasa esto, y no tiene botón Siguiente.
    var esperar: Espera?

    enum Espera {
        case queEmpieceLaGrabacion
        case queTermineLaGrabacion
    }
}

enum TutorialSteps {

    /// El primer paso de la parte de grabar: «Solo la parte de grabar» salta
    /// hasta acá.
    static var indiceGrabar: Int { pasos.firstIndex { $0.objetivo == .grabar } ?? 0 }

    static let pasos: [PasoTutorial] = [
        PasoTutorial(
            titulo: "Bienvenido al Grabador",
            texto: "Te muestro todo en unos minutos. Primero vemos qué se elige antes de grabar, y después hacemos una grabación de práctica de verdad.\n\nLa práctica se va sola a la Papelera cuando termina, así que tocá lo que quieras sin miedo. Si te perdés, «Anterior» vuelve un paso y «Salir» lo cierra.",
            objetivo: nil),
        PasoTutorial(
            titulo: "El nombre de la clase",
            texto: "Tocá acá y escribí cómo se llama lo que vas a grabar, por ejemplo «Clase 3 de n8n». Con ese nombre se guarda el video.",
            objetivo: .titulo),
        PasoTutorial(
            titulo: "Todo lo azul se toca",
            texto: "Esta frase dice qué se va a grabar, y cada parte en azul abre sus opciones.\n\nEsta elige si grabás la pantalla entera o solo un pedazo: con «Un área…» dibujás con el mouse el rectángulo que querés.",
            objetivo: .frase(.area)),
        PasoTutorial(
            titulo: "Cuál pantalla",
            texto: "Si tenés más de un monitor conectado, acá elegís cuál se graba.",
            objetivo: .frase(.pantalla)),
        PasoTutorial(
            titulo: "Qué se oye",
            texto: "Acá elegís el micrófono, y si también se graba el sonido del computador.\n\nHablá un poco: la rayita azul debajo del nombre del micrófono se mueve con tu voz. Si no se mueve, ese micrófono no te está oyendo y el video saldría mudo.\n\nSi grabás el sonido del computador, ponete audífonos: con los parlantes queda un eco.",
            objetivo: .frase(.audio)),
        PasoTutorial(
            titulo: "Tu cámara",
            texto: "Elegí una cámara y aparece tu cara en un recuadro en la pantalla. Arrastralo a donde quieras y agrandalo desde una esquina: así, en ese lugar y de ese tamaño, va a salir en el video.",
            objetivo: .frase(.camara)),
        PasoTutorial(
            titulo: "El guion",
            texto: "Si vas a leer algo mientras grabás, tocá acá. Podés escribir el texto, traerlo de un Word, elegir la velocidad y el tamaño de la letra, y si lo querés con fondo oscuro, que cansa menos la vista.\n\nEl guion solo lo ves vos: nunca sale en el video.",
            objetivo: .frase(.guion)),
        PasoTutorial(
            titulo: "Dónde se guarda",
            texto: "Los videos se guardan en esta carpeta. Con «Cambiar…» elegís otra.",
            objetivo: .carpeta),
        PasoTutorial(
            titulo: "La cuenta regresiva",
            texto: "Con este interruptor prendido, antes de arrancar sale un 3, 2, 1 para que te acomodes. La cuenta no queda en el video.",
            objetivo: .cuenta),
        PasoTutorial(
            titulo: "¿Está todo listo?",
            texto: "Acá abajo la app te dice si todo está bien. Si falta algo, como un permiso o un micrófono, lo dice acá en rojo, y el botón de al lado te lleva a arreglarlo.",
            objetivo: .estado),
        PasoTutorial(
            titulo: "Hacé la grabación de práctica",
            texto: "Tocá «Grabar». Esta es de práctica: cuando la termines se va sola a la Papelera.\n\nApenas arranque, te sigo mostrando lo que aparece mientras grabás.",
            objetivo: .grabar,
            esperar: .queEmpieceLaGrabacion),
        PasoTutorial(
            titulo: "Estás grabando",
            texto: "Este es el control de la grabación. Acá ves el tiempo y, debajo, qué se está grabando.\n\nNinguna ventana de la app sale en el video: ni esta, ni el guion, ni estas explicaciones. Arrastralo de cualquier parte que no sea un botón para ponerlo donde no moleste.",
            objetivo: .reloj),
        PasoTutorial(
            titulo: "Pausar",
            texto: "Tocá «Pausar». El tiempo se detiene y lo que pase durante la pausa no queda en el video. Tocá «Reanudar» para seguir.",
            objetivo: .pausar),
        PasoTutorial(
            titulo: "Empezar de nuevo",
            texto: "Si te equivocaste, «Reiniciar» manda lo grabado a la Papelera y arranca otra grabación igual. Antes de hacerlo te pregunta. Ahora no hace falta que lo toques.",
            objetivo: .reiniciar),
        PasoTutorial(
            titulo: "Callar el micrófono o el sonido",
            texto: "Tocá «Micrófono». Queda callado y abajo aparece un aviso rojo grande, para que no se te olvide. Tocá el aviso y vuelve a oírse.\n\nLa grabación no se corta: esa parte queda en silencio.",
            objetivo: .audio),
        PasoTutorial(
            titulo: "La cámara",
            texto: "Prende y apaga el recuadro de tu cara. Si lo dejás apretado un momento, elegís otra cámara.",
            objetivo: .camara),
        PasoTutorial(
            titulo: "Qué se ve en el video",
            texto: "Tocá «Qué se ve»: ahí cambiás entre tu pantalla, vos en cámara completa, o un tablero para explicar dibujando. Al lado de cada opción está su atajo de teclado.",
            objetivo: .queSeVe),
        PasoTutorial(
            titulo: "El tablero",
            texto: "Tocá «Tablero» y después «Pasar al tablero». Dibujá algo con el mouse.\n\nMientras estás en el tablero aparecen al lado «Lienzo» (blanco o negro), «Deshacer» y «Borrar». Para volver a tu pantalla: «Qué se ve» y «Pantalla».",
            objetivo: .tablero,
            oscurecer: false),
        PasoTutorial(
            titulo: "Sobre la pantalla",
            texto: "Acá están tres ayudas:\n\n• El marcador, para rayar encima de lo que mostrás.\n• El círculo amarillo que sigue al mouse en el video, para que se vea dónde estás señalando.\n• La censura: tapa una parte de la pantalla, por ejemplo una contraseña, para que no salga en el video. La primera vez te pide dibujar qué tapar.",
            objetivo: .sobreLaPantalla,
            oscurecer: false),
        PasoTutorial(
            titulo: "El guion",
            texto: "Muestra y esconde el texto que vas a leer. La flechita de al lado tiene sus controles.",
            objetivo: .guion),
        PasoTutorial(
            titulo: "Leyendo el guion",
            texto: "El texto sube solo. Con la barra espaciadora lo pausás, y con las flechas lo hacés más rápido o más lento. Arriba a la derecha escribís la velocidad y el tamaño de la letra, y el circulito lo pasa a fondo oscuro. Lo que dejes queda para la próxima.\n\nSi no cargaste un guion, no aparece: está en el paso del panel.",
            objetivo: .teleprompter),
        PasoTutorial(
            titulo: "Achicar",
            texto: "Tocá «Achicar»: queda solo el tiempo, para que no estorbe. Tocalo y vuelve todo.",
            objetivo: .achicar),
        PasoTutorial(
            titulo: "Arriba también",
            texto: "Mientras grabás, al lado del ícono de la app en la barra de arriba ves el tiempo. Desde ese ícono también podés detener la grabación.",
            objetivo: .barraDeMenu),
        PasoTutorial(
            titulo: "Los atajos",
            texto: "Todo se puede hacer también con el teclado. Mantené apretadas Opción + Comando + H y sale la lista de atajos. Soltalas y se va.",
            objetivo: nil),
        PasoTutorial(
            titulo: "Terminá la práctica",
            texto: "Tocá «Detener». Como es de práctica, este video se va solo a la Papelera.",
            objetivo: .detener,
            esperar: .queTermineLaGrabacion),
        PasoTutorial(
            titulo: "¡Listo!",
            texto: "Ya sabés usar el Grabador. Cuando grabes de verdad, al detener se abre la carpeta con tu video.\n\nPara repasar algo, tocá «¿Cómo se usa?» arriba a la derecha del panel, o en el menú del ícono de la barra de arriba.",
            objetivo: nil)
    ]

    /// Dónde va la burbuja: debajo de lo iluminado si entra, si no arriba, si
    /// no al costado, y siempre entera dentro de la pantalla. Sin nada
    /// iluminado, al centro.
    ///
    /// Coordenadas de pantalla de macOS: el origen está abajo, así que
    /// «debajo» es restar.
    static func ubicarBurbuja(tamaño: CGSize, objetivo: CGRect?, pantalla: CGRect,
                              separacion: CGFloat = 16) -> CGPoint {
        guard let o = objetivo else {
            return CGPoint(x: pantalla.midX - tamaño.width / 2, y: pantalla.midY - tamaño.height / 2)
        }
        var origen: CGPoint
        if o.minY - separacion - tamaño.height >= pantalla.minY {
            origen = CGPoint(x: o.midX - tamaño.width / 2, y: o.minY - separacion - tamaño.height)
        } else if o.maxY + separacion + tamaño.height <= pantalla.maxY {
            origen = CGPoint(x: o.midX - tamaño.width / 2, y: o.maxY + separacion)
        } else if o.maxX + separacion + tamaño.width <= pantalla.maxX {
            origen = CGPoint(x: o.maxX + separacion, y: o.midY - tamaño.height / 2)
        } else {
            origen = CGPoint(x: o.minX - separacion - tamaño.width, y: o.midY - tamaño.height / 2)
        }
        origen.x = min(max(origen.x, pantalla.minX + 12), pantalla.maxX - tamaño.width - 12)
        origen.y = min(max(origen.y, pantalla.minY + 12), pantalla.maxY - tamaño.height - 12)
        return origen
    }
}
