import AppKit

// Prueba del orden de las ventanas propias. Se corre con ./probar.sh
//
// Existe porque un error acá es del tipo que no se ve al mirar la pantalla: las
// ventanas se siguen viendo casi igual y lo que cambia es **a quién le llega el
// clic**. El síntoma que produce es "el botón no hace nada", a veces, en un modo
// determinado, que es lo más caro de diagnosticar en vivo en mitad de una clase.
//
// Lo que se comprueba es lo que dice la decisión 93: que la pila esté
// estrictamente ordenada y que nadie empate con nadie.

var fallos = 0

func comprobar(_ descripcion: String, _ condicion: Bool) {
    if condicion {
        print("  ✓ \(descripcion)")
    } else {
        print("  ✗ \(descripcion)")
        fallos += 1
    }
}

// De abajo hacia arriba, tal como lo especifica la Fase 14 del plan maestro.
let pila: [(String, WindowLayer)] = [
    ("superficie de dibujo", .dibujo),
    ("teleprompter", .teleprompter),
    ("burbuja", .burbuja),
    ("widget", .widget),
    ("tarjeta de atajos", .tarjeta),
    ("selector de rectángulo", .selector),
    ("countdown", .countdown)
]

print("Orden de ventanas")

for (anterior, siguiente) in zip(pila, pila.dropFirst()) {
    comprobar("\(siguiente.0) por encima de \(anterior.0)",
              siguiente.1.level.rawValue > anterior.1.level.rawValue)
}

// El widget por encima del dibujo es el punto entero de la decisión 93: es lo
// que hace que sus botones respondan con el tablero o el marcador prendidos.
comprobar("el widget recibe los clics antes que la superficie de dibujo",
          WindowLayer.widget.level.rawValue > WindowLayer.dibujo.level.rawValue)

// La superficie de dibujo tiene que seguir por encima de las demás apps, o el
// tablero quedaría debajo de lo que se está mostrando.
comprobar("la superficie de dibujo sigue encima de las apps ajenas",
          WindowLayer.dibujo.level.rawValue >= NSWindow.Level.floating.rawValue)

// Toda la pila flotante tiene que quedar por debajo del selector, que se pone
// en un nivel del sistema: si alguien agrega escalones de más, el selector deja
// de estar arriba y no se puede censurar una zona debajo del widget.
comprobar("la pila flotante no alcanza al selector",
          WindowLayer.tarjeta.level.rawValue < WindowLayer.selector.level.rawValue)

print("")
if fallos == 0 {
    print("  Orden de ventanas: en verde.")
} else {
    print("  Orden de ventanas: \(fallos) fallo(s).")
    exit(1)
}
