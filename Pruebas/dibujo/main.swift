import CoreGraphics
import Foundation

// Prueba del motor de dibujo. Se corre con ./probar.sh
//
// Lo que se verifica es lo que falla en silencio y aparece después como "el
// tablero se comporta raro": que un clic seco no deje un trazo invisible de un
// punto, que deshacer no se coma lo que no debe, y sobre todo que la versión
// cambie **solo** cuando cambia lo terminado. De esa versión depende la caché del
// compositor: si no cambiara cuando debe, lo dibujado no aparecería en el video;
// si cambiara de más, se repintaría todo en cada cuadro.

var fallos = 0

func comprobar(_ descripcion: String, _ condicion: Bool) {
    if condicion {
        print("  ✓ \(descripcion)")
    } else {
        print("  ✗ \(descripcion)")
        fallos += 1
    }
}

print("Motor de dibujo")

let s = DrawingSurface()
comprobar("arranca vacía", s.isEmpty)
comprobar("arranca en rojo", s.color == .rojo)

// Un trazo de verdad: se apretó y se arrastró.
let v0 = s.version
s.beginStroke(at: CGPoint(x: 0.1, y: 0.1))
comprobar("el trazo en curso no cuenta como terminado", s.version == v0)
comprobar("el trazo en curso se ve", s.liveStroke() != nil)
s.extendStroke(to: CGPoint(x: 0.2, y: 0.2))
s.endStroke()
comprobar("al terminar, la versión cambia", s.version == v0 + 1)
comprobar("quedó un ítem", s.committedItems().count == 1)
comprobar("ya no hay trazo en curso", s.liveStroke() == nil)

// Clic seco: un solo punto. No es un trazo y no debe quedar nada.
let v1 = s.version
s.beginStroke(at: CGPoint(x: 0.5, y: 0.5))
s.endStroke()
comprobar("el clic seco no deja trazo", s.committedItems().count == 1)
comprobar("el clic seco no cambia la versión", s.version == v1)

// Cuadro de texto.
s.addTextBox(at: CGPoint(x: 0.3, y: 0.3))
s.updateLastText("hola")
comprobar("el texto quedó guardado", {
    if case .text(let box)? = s.committedItems().last { return box.text == "hola" }
    return false
}())

// Un cuadro vacío que se cierra sin escribir nada se descarta, para que deshacer
// no tenga que sacar a ciegas algo que no se ve.
s.addTextBox(at: CGPoint(x: 0.4, y: 0.4))
comprobar("el cuadro nuevo entra", s.committedItems().count == 3)
s.dropLastTextIfEmpty()
comprobar("el cuadro vacío se descarta al cerrarlo", s.committedItems().count == 2)

// Y uno con texto no se descarta.
s.dropLastTextIfEmpty()
comprobar("el cuadro con texto sobrevive", s.committedItems().count == 2)

// Deshacer saca el último, sea trazo o texto.
s.undo()
comprobar("deshacer sacó el texto", s.committedItems().count == 1)
comprobar("deshacer dejó el trazo", {
    if case .stroke? = s.committedItems().first { return true }
    return false
}())

// Deshacer sobre una superficie vacía no revienta ni deja versiones falsas.
s.undo()
let vacia = s.version
s.undo()
comprobar("deshacer de más no rompe", s.committedItems().isEmpty)
comprobar("deshacer sobre vacío no cambia la versión", s.version == vacia)

// La paleta rota y vuelve al principio.
let colores = (0..<6).map { _ in s.rotateColor() }
comprobar("la paleta rota los cinco colores", Array(colores.prefix(5)) == [.amarillo, .verde, .blanco, .negro, .rojo])
comprobar("y vuelve a empezar", colores[5] == .amarillo)

// Borrar deja todo limpio, incluido el trazo en curso.
s.beginStroke(at: CGPoint(x: 0.1, y: 0.1))
s.extendStroke(to: CGPoint(x: 0.9, y: 0.9))
s.endStroke()
s.beginStroke(at: CGPoint(x: 0.2, y: 0.2))
s.clear()
comprobar("borrar deja la superficie vacía", s.isEmpty)
comprobar("borrar también se lleva el trazo en curso", s.liveStroke() == nil)

print(fallos == 0 ? "\nTodo bien, 0 fallos" : "\nFALLÓ: \(fallos) comprobaciones")
exit(fallos == 0 ? 0 : 1)
