import Foundation

/// El motor de desplazamiento del teleprompter: cuánto sube el texto y hasta
/// dónde. Sin AppKit adentro a propósito, para poder probarlo solo (`./probar.sh`,
/// bloque "teleprompter").
///
/// Lo único delicado de todo esto es que el texto suba **por tiempo
/// transcurrido** y no por cantidad de cuadros: la misma velocidad tiene que
/// leerse igual con la máquina libre que con la máquina rindiendo al límite en
/// mitad de una grabación, que es justo cuando el teleprompter se usa.
struct TeleprompterEngine {

    /// Los rangos del prototipo, que ya están calibrados contra el ojo humano.
    static let velocidadMinima = 0.3
    static let velocidadMaxima = 10.0
    static let letraMinima: Double = 16
    static let letraMaxima: Double = 120

    /// Un intervalo entre cuadros se cuenta como máximo 100 ms. Sin este tope,
    /// un tirón de la máquina —o la app volviendo de estar dormida— se cobraría
    /// entero de una vez y el guion pegaría un salto de varias líneas.
    static let intervaloMaximo = 0.1

    /// La velocidad multiplicada por esto son los puntos que el texto sube por
    /// segundo. Es la constante que le da la sensación de avance al original.
    static let puntosPorSegundo: Double = 40

    private(set) var velocidad: Double = 5
    private(set) var tamañoLetra: Double = 38
    /// Cuánto subió el texto, en puntos. Es la única fuente de verdad de la
    /// posición: la ventana la copia a la vista, nunca al revés.
    private(set) var offset: Double = 0
    private(set) var corriendo = false

    init(velocidad: Double = 5, tamañoLetra: Double = 38) {
        self.velocidad = Self.clamp(velocidad, Self.velocidadMinima, Self.velocidadMaxima)
        self.tamañoLetra = Self.clamp(tamañoLetra, Self.letraMinima, Self.letraMaxima).rounded()
    }

    /// Avanza el texto por el tiempo transcurrido desde el cuadro anterior.
    ///
    /// - Parameter maximo: el offset más grande posible, o sea el alto del texto
    ///   menos el alto del cuadro. Al llegar ahí frena solo: seguir subiendo
    ///   dejaría la pantalla en blanco sin que se entienda por qué.
    mutating func avanzar(transcurrido: Double, maximo: Double) {
        guard corriendo else { return }
        let dt = min(max(transcurrido, 0), Self.intervaloMaximo)
        posicionar(offset + velocidad * Self.puntosPorSegundo * dt, maximo: maximo)
        if offset >= maximo { corriendo = false }
    }

    /// Mueve el texto a mano (rueda y arrastre), siempre dentro del rango.
    mutating func posicionar(_ nuevo: Double, maximo: Double) {
        offset = Self.clamp(nuevo, 0, max(maximo, 0))
    }

    mutating func alternarPlay() { corriendo.toggle() }
    mutating func pausar() { corriendo = false }

    /// Vuelve al principio y frena. Es el botón de reiniciar y también lo que
    /// pasa al entrar a editar el guion.
    mutating func reiniciar() {
        corriendo = false
        offset = 0
    }

    mutating func cambiarVelocidad(_ delta: Double) {
        // Redondeo a un decimal: sumar 0.5 muchas veces sobre un double deja
        // valores como 7.299999 y el número de la barra se vuelve ilegible.
        velocidad = Self.clamp((velocidad + delta).rounded(toPlaces: 1),
                               Self.velocidadMinima, Self.velocidadMaxima)
    }

    mutating func cambiarTamañoLetra(_ delta: Double) {
        tamañoLetra = Self.clamp((tamañoLetra + delta).rounded(), Self.letraMinima, Self.letraMaxima)
    }

    private static func clamp(_ valor: Double, _ minimo: Double, _ maximo: Double) -> Double {
        min(max(valor, minimo), maximo)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
