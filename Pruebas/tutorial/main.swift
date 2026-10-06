import Foundation

// Prueba del tutorial (decisión 137). Se corre con ./probar.sh
//
// Dos cosas que fallan en silencio y que solo se verían haciendo el recorrido
// entero: una burbuja que queda medio afuera de la pantalla, y una lista de
// pasos que pide detener antes de haber pedido grabar.

var fallos = 0

func comprobar(_ descripcion: String, _ condicion: Bool) {
    if condicion {
        print("  ✓ \(descripcion)")
    } else {
        print("  ✗ \(descripcion)")
        fallos += 1
    }
}

print("Tutorial")

let pantalla = CGRect(x: 0, y: 0, width: 1470, height: 900)
let burbuja = CGSize(width: 420, height: 220)

func adentro(_ origen: CGPoint) -> Bool {
    pantalla.contains(CGRect(origin: origen, size: burbuja))
}

// Sin nada iluminado, al centro.
let centro = TutorialSteps.ubicarBurbuja(tamaño: burbuja, objetivo: nil, pantalla: pantalla)
comprobar("sin objetivo va al centro", abs(centro.x + burbuja.width / 2 - pantalla.midX) < 1)

// La cápsula arriba a la derecha: la burbuja va debajo y no se sale por la derecha.
let capsula = CGRect(x: 500, y: 810, width: 946, height: 66)
let bajoCapsula = TutorialSteps.ubicarBurbuja(tamaño: burbuja, objetivo: capsula, pantalla: pantalla)
comprobar("debajo de la cápsula", bajoCapsula.y + burbuja.height <= capsula.minY)
comprobar("entera en la pantalla con la cápsula", adentro(bajoCapsula))

// Un botón pegado abajo: la burbuja va arriba.
let abajo = CGRect(x: 700, y: 20, width: 120, height: 42)
let sobreBoton = TutorialSteps.ubicarBurbuja(tamaño: burbuja, objetivo: abajo, pantalla: pantalla)
comprobar("encima de un botón pegado abajo", sobreBoton.y >= abajo.maxY)
comprobar("entera en la pantalla con un botón abajo", adentro(sobreBoton))

// Algo que ocupa casi todo el alto: va al costado y entera.
let alto = CGRect(x: 100, y: 40, width: 600, height: 820)
let costado = TutorialSteps.ubicarBurbuja(tamaño: burbuja, objetivo: alto, pantalla: pantalla)
comprobar("al costado de algo muy alto", costado.x >= alto.maxX)
comprobar("entera en la pantalla con algo muy alto", adentro(costado))

// El orden de los pasos.
let pasos = TutorialSteps.pasos
let empieza = pasos.firstIndex { $0.esperar == .queEmpieceLaGrabacion }
let termina = pasos.firstIndex { $0.esperar == .queTermineLaGrabacion }
comprobar("hay un paso que espera que se grabe", empieza != nil)
comprobar("el de detener viene después del de grabar", (empieza ?? .max) < (termina ?? -1))
comprobar("«Solo la parte de grabar» salta al paso de grabar", TutorialSteps.indiceGrabar == empieza)
comprobar("después de detener queda el paso final", termina == pasos.count - 2)
comprobar("ningún texto vacío", pasos.allSatisfy { !$0.titulo.isEmpty && !$0.texto.isEmpty })

print("")
if fallos == 0 {
    print("  Tutorial: en verde.")
} else {
    print("  Tutorial: \(fallos) fallo(s).")
    exit(1)
}
