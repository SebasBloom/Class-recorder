import AppKit

/// Los dos fondos del teleprompter (decisión 135): claro por defecto, igual
/// que el resto de la app, y oscuro a elección, porque leer una hora sobre un
/// bloque blanco cansa la vista.
struct TeleprompterTheme {
    let fondo: NSColor
    let barra: NSColor
    let texto: NSColor
    /// Pestañas apagadas, etiquetas y ayuda de teclas.
    let secundario: NSColor
    /// La línea de lectura, el subrayado de la pestaña y el botón prendido.
    let acento: NSColor
    let borde: NSColor
    let boton: NSColor
    let encima: NSColor
    let apariencia: NSAppearance.Name

    static let claro = TeleprompterTheme(
        fondo: BloomindStyle.Claro.blanco,
        barra: BloomindStyle.Claro.papel,
        texto: BloomindStyle.Claro.tinta,
        secundario: BloomindStyle.Claro.pizarra,
        acento: BloomindStyle.Claro.azul,
        borde: BloomindStyle.Claro.tinta.withAlphaComponent(0.16),
        boton: BloomindStyle.Claro.tinta,
        encima: BloomindStyle.Claro.tinta.withAlphaComponent(0.06),
        apariencia: .aqua)

    static let oscuro = TeleprompterTheme(
        fondo: BloomindStyle.deep,
        barra: BloomindStyle.surface,
        texto: .white,
        secundario: BloomindStyle.muted,
        acento: BloomindStyle.lab,
        borde: NSColor(white: 1, alpha: 0.08),
        boton: NSColor(hex: 0xDFE7F3),
        encima: NSColor(white: 1, alpha: 0.07),
        apariencia: .darkAqua)

    static func para(oscuro: Bool) -> TeleprompterTheme { oscuro ? .oscuro : .claro }
}
