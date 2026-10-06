import Foundation

// Prueba de la oración del panel (decisión 128). Se corre con ./probar.sh
//
// La frase sale de reglas y no de una plantilla fija: los nombres largos se
// acortan, los casos sin audio o sin cámara cambian la gramática. Un error acá
// no rompe nada, pero deja al panel diciendo una frase rara justo antes de
// grabar, que es lo primero que se lee.

var fallos = 0

func comprobar(_ descripcion: String, _ obtenido: String, _ esperado: String) {
    if obtenido == esperado {
        print("  ✓ \(descripcion)")
    } else {
        print("  ✗ \(descripcion)\n      salió:    «\(obtenido)»\n      esperaba: «\(esperado)»")
        fallos += 1
    }
}

func frase(_ e: PanelSentence.Estado) -> String {
    PanelSentence.armar(e).map {
        switch $0 {
        case .texto(let t): return t
        case .fragmento(let t, _, _): return t
        }
    }.joined()
}

print("Oración del panel")

comprobar("AirPods", PanelSentence.microfonoCorto("AirPods Pro de Sebastián Giraldo"), "los AirPods Pro")
comprobar("DJI por el iPhone", PanelSentence.microfonoCorto("Micrófono DJI vía iPhone"), "el micrófono DJI")
comprobar("micrófono del Mac", PanelSentence.microfonoCorto("Micrófono del MacBook Air"), "el micrófono del Mac")
comprobar("micrófono USB", PanelSentence.microfonoCorto("Blue Yeti"), "el micrófono Blue Yeti")
comprobar("pantalla Retina", PanelSentence.pantallaCorta("Pantalla integrada Retina"), "Retina")
comprobar("pantalla externa", PanelSentence.pantallaCorta("LG UltraFine 27"), "LG UltraFine 27")
comprobar("nombre muy largo", PanelSentence.pantallaCorta("Monitor de la oficina de arriba"), "Monitor de la…")
comprobar("cámara del Mac", PanelSentence.camaraCorta("Cámara FaceTime HD"), "la cámara FaceTime")
comprobar("cámara del iPhone", PanelSentence.camaraCorta("Cámara de iPhone de Sebastián"), "el iPhone")

let base = PanelSentence.Estado(area: nil, pantalla: "Pantalla integrada Retina", audio: .microphone,
                                microfono: "Micrófono DJI vía iPhone", microfonoSinPermiso: false,
                                camara: "Cámara FaceTime HD", guiones: 3)
comprobar("el caso de siempre", frase(base),
          "Voy a grabar la pantalla entera del Retina, con el micrófono DJI y la cámara FaceTime, leyendo 3 guiones.")

var mixto = base; mixto.audio = .mixed; mixto.guiones = 1
comprobar("micrófono y PC, un guion", frase(mixto),
          "Voy a grabar la pantalla entera del Retina, con el micrófono DJI y el sonido del PC, y la cámara FaceTime, leyendo 1 guion.")

var nada = base; nada.audio = .none; nada.camara = nil; nada.guiones = 0
comprobar("sin sonido y sin cámara", frase(nada),
          "Voy a grabar la pantalla entera del Retina, sin sonido y sin cámara, sin guion.")

var mudoConCamara = nada; mudoConCamara.camara = "Cámara FaceTime HD"
comprobar("sin sonido con cámara", frase(mudoConCamara),
          "Voy a grabar la pantalla entera del Retina, sin sonido y con la cámara FaceTime, sin guion.")

var area = base; area.area = (1280, 720)
comprobar("con un área", frase(area),
          "Voy a grabar un área de 1280×720 del Retina, con el micrófono DJI y la cámara FaceTime, leyendo 3 guiones.")

var sinPermiso = base; sinPermiso.microfonoSinPermiso = true
comprobar("sin permiso", frase(sinPermiso),
          "Voy a grabar la pantalla entera del Retina, con el micrófono DJI — sin permiso, tocá para darlo y la cámara FaceTime, leyendo 3 guiones.")

print("")
if fallos == 0 {
    print("  Oración: en verde.")
} else {
    print("  Oración: \(fallos) fallo(s).")
    exit(1)
}
