import AppKit

// Prueba de la conversión de coordenadas. Se corre con ./probar.sh
//
// Es la única prueba automática del proyecto, y existe porque la conversión de
// coordenadas es la pieza más compartida: un error acá desfasa el círculo, los
// clics, el JSON, la censura y el dibujo todos a la vez, y a ojo se ve como "el
// círculo va corrido" sin decir por qué.
//
// Sin XCTest a propósito: las Command Line Tools no lo traen, solo Xcode. Con
// asertos alcanza y corre en cualquier Mac.

var fallos = 0

func comprobar(_ descripcion: String, _ obtenido: CGFloat?, _ esperado: CGFloat) {
    guard let obtenido else {
        print("  ✗ \(descripcion): se esperaba \(esperado) y no hubo punto")
        fallos += 1
        return
    }
    if abs(obtenido - esperado) > 0.001 {
        print("  ✗ \(descripcion): se esperaba \(esperado) y llegó \(obtenido)")
        fallos += 1
    } else {
        print("  ✓ \(descripcion)")
    }
}

func comprobarFuera(_ descripcion: String, _ obtenido: CGPoint?) {
    if obtenido == nil {
        print("  ✓ \(descripcion)")
    } else {
        print("  ✗ \(descripcion): se esperaba nil y llegó \(obtenido!)")
        fallos += 1
    }
}

print("Conversión de coordenadas")

// Monitor común, sin Retina, en el origen del escritorio.
// El mouse mide desde abajo (200); el frame numera desde arriba (800 - 200).
let simple = CoordinateConverter(displayFrame: CGRect(x: 0, y: 0, width: 1000, height: 800), scale: 1)
let p1 = simple.pixelPoint(fromGlobal: CGPoint(x: 100, y: 200))
comprobar("pantalla simple, eje horizontal", p1?.x, 100)
comprobar("pantalla simple, eje vertical invertido", p1?.y, 600)

// Retina: un punto son dos píxeles.
let retina = CoordinateConverter(displayFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), scale: 2)
let p2 = retina.pixelPoint(fromGlobal: CGPoint(x: 100, y: 200))
comprobar("retina, horizontal por escala", p2?.x, 200)
comprobar("retina, vertical por escala", p2?.y, 1400)
comprobar("retina, ancho del frame", retina.pixelSize.width, 2880)
comprobar("retina, alto del frame", retina.pixelSize.height, 1800)

// Segundo monitor a la derecha: hay que restarle su desplazamiento.
let segundo = CoordinateConverter(displayFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1080), scale: 1)
let p3 = segundo.pixelPoint(fromGlobal: CGPoint(x: 1540, y: 100))
comprobar("segundo monitor, resta el origen", p3?.x, 100)
comprobar("segundo monitor, vertical", p3?.y, 980)

// El mouse en la pantalla que NO se está grabando: el llamador lo registra
// como el evento "fuera" del JSON.
comprobarFuera("mouse en el otro monitor", simple.pixelPoint(fromGlobal: CGPoint(x: 1500, y: 400)))
comprobarFuera("mouse por encima del borde", simple.pixelPoint(fromGlobal: CGPoint(x: 500, y: 900)))
comprobarFuera("mouse a la izquierda del borde", simple.pixelPoint(fromGlobal: CGPoint(x: -10, y: 400)))

// Las esquinas son donde más se nota un error de uno.
let esquinas = CoordinateConverter(displayFrame: CGRect(x: 0, y: 0, width: 1000, height: 800), scale: 2)
comprobar("esquina de abajo va a la última fila", esquinas.pixelPoint(fromGlobal: CGPoint(x: 0, y: 0))?.y, 1600)
comprobar("borde de arriba va a la fila 0", esquinas.pixelPoint(fromGlobal: CGPoint(x: 0, y: 799.9))?.y, 0.2)

// Rectángulos: es como se ubica la burbuja de cámara a partir del marco de su
// ventana espejo. Un error acá pone la burbuja del video en otro lado que la que
// se ve en pantalla, que es exactamente el síntoma difuso de "no me queda donde
// la dejé".
print("\nRectángulos (burbuja)")

// Ventana de 300x200 puntos, con su esquina de abajo a 100 del piso: en píxeles
// Retina el borde de arriba queda a (800 - 100 - 200) * 2.
let burbuja = retina.pixelRect(fromGlobal: CGRect(x: 50, y: 100, width: 300, height: 200))
comprobar("burbuja, horizontal por escala", burbuja?.minX, 100)
comprobar("burbuja, borde de arriba invertido", burbuja?.minY, 1200)
comprobar("burbuja, ancho por escala", burbuja?.width, 600)
comprobar("burbuja, alto por escala", burbuja?.height, 400)

// A medio salir por el borde de abajo: se compone la parte que quedó adentro, no
// se descarta entera.
let mitad = simple.pixelRect(fromGlobal: CGRect(x: 10, y: -50, width: 100, height: 100))
comprobar("burbuja a medio salir, sigue existiendo", mitad?.width, 100)
comprobar("burbuja a medio salir, se pasa del borde", mitad?.maxY, 850)

// En el otro monitor: no se compone nada.
if simple.pixelRect(fromGlobal: CGRect(x: 2000, y: 100, width: 100, height: 100)) == nil {
    print("  ✓ burbuja en el otro monitor")
} else {
    print("  ✗ burbuja en el otro monitor: se esperaba nil")
    fallos += 1
}

print(fallos == 0 ? "\nTodo bien, 0 fallos" : "\nFALLÓ: \(fallos) comprobaciones")
exit(fallos == 0 ? 0 : 1)
