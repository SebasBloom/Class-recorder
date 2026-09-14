import AppKit
import Foundation

// Prueba del motor de desplazamiento del teleprompter. Se corre con ./probar.sh
//
// Existe porque el error que este motor puede tener es invisible mirando la
// pantalla: el texto sube, se ve bien, y lo que está mal es *cuánto* sube por
// segundo cuando la máquina va cargada. El síntoma aparece en vivo, dando clase,
// como "el guion se me escapó" o "se fue a los saltos", y no hay forma de
// reproducirlo después.

var fallos = 0

func comprobar(_ descripcion: String, _ condicion: Bool) {
    if condicion {
        print("  ✓ \(descripcion)")
    } else {
        print("  ✗ \(descripcion)")
        fallos += 1
    }
}

func casi(_ a: Double, _ b: Double, _ tolerancia: Double = 0.001) -> Bool {
    abs(a - b) < tolerancia
}

print("Motor del teleprompter")

// La velocidad por 40 son los puntos por segundo. Medio segundo a velocidad 5
// tienen que ser 100 puntos exactos, contados en cuadros que no pasen del tope.
var motor = TeleprompterEngine(velocidad: 5, tamañoLetra: 38)
motor.alternarPlay()
for _ in 0..<5 { motor.avanzar(transcurrido: 0.1, maximo: 10_000) }
comprobar("velocidad 5 sube 100 puntos en medio segundo", casi(motor.offset, 100))

// El mismo tiempo repartido en muchos cuadros da el mismo recorrido: es lo que
// significa avanzar por tiempo transcurrido y no por cantidad de cuadros.
var enPasos = TeleprompterEngine(velocidad: 5)
enPasos.alternarPlay()
for _ in 0..<50 { enPasos.avanzar(transcurrido: 0.01, maximo: 10_000) }
comprobar("cincuenta cuadros de 10 ms recorren lo mismo que uno de 500 ms",
          casi(enPasos.offset, 100))

// El tope de 100 ms: si la máquina se traba dos segundos, el texto no pega el
// salto de dos segundos.
var trabada = TeleprompterEngine(velocidad: 5)
trabada.alternarPlay()
trabada.avanzar(transcurrido: 2.0, maximo: 10_000)
comprobar("un tirón de 2 segundos se cobra como 100 ms", casi(trabada.offset, 20))

// Frenado automático al llegar al final.
var alFinal = TeleprompterEngine(velocidad: 10)
alFinal.alternarPlay()
alFinal.avanzar(transcurrido: 0.1, maximo: 30)
comprobar("no se pasa del final del guion", casi(alFinal.offset, 30))
comprobar("frena solo al llegar al final", !alFinal.corriendo)

// Parado no se mueve, por más tiempo que pase.
var quieto = TeleprompterEngine()
quieto.avanzar(transcurrido: 5, maximo: 10_000)
comprobar("en pausa no avanza", casi(quieto.offset, 0))

// Rangos de velocidad y de letra.
var rangos = TeleprompterEngine(velocidad: 5, tamañoLetra: 38)
for _ in 0..<40 { rangos.cambiarVelocidad(0.5) }
comprobar("la velocidad no pasa de 10", casi(rangos.velocidad, 10))
for _ in 0..<60 { rangos.cambiarVelocidad(-0.5) }
comprobar("la velocidad no baja de 0.3", casi(rangos.velocidad, 0.3))

// Sumar 0.5 muchas veces sobre un double deja colas de decimales, y el número
// que se muestra en la barra se vuelve ilegible.
var redondeo = TeleprompterEngine(velocidad: 0.3)
redondeo.cambiarVelocidad(0.5)
comprobar("la velocidad queda con un decimal limpio", casi(redondeo.velocidad, 0.8))

for _ in 0..<40 { rangos.cambiarTamañoLetra(4) }
comprobar("la letra no pasa de 120", casi(rangos.tamañoLetra, 120))
for _ in 0..<60 { rangos.cambiarTamañoLetra(-4) }
comprobar("la letra no baja de 16", casi(rangos.tamañoLetra, 16))

// Valores fuera de rango que vengan del panel se acomodan al entrar.
let desdeElPanel = TeleprompterEngine(velocidad: 99, tamañoLetra: 3)
comprobar("un valor de arranque fuera de rango se acomoda",
          casi(desdeElPanel.velocidad, 10) && casi(desdeElPanel.tamañoLetra, 16))

// Mover a mano nunca se sale del rango, ni hacia arriba ni hacia abajo.
var aMano = TeleprompterEngine()
aMano.posicionar(-500, maximo: 200)
comprobar("arrastrando hacia atrás no se pasa del principio", casi(aMano.offset, 0))
aMano.posicionar(9_999, maximo: 200)
comprobar("arrastrando hacia adelante no se pasa del final", casi(aMano.offset, 200))

// Reiniciar vuelve al principio y frena.
var reinicio = TeleprompterEngine(velocidad: 5)
reinicio.alternarPlay()
reinicio.avanzar(transcurrido: 0.5, maximo: 10_000)
reinicio.reiniciar()
comprobar("reiniciar vuelve al principio y frena", casi(reinicio.offset, 0) && !reinicio.corriendo)

// El campo donde se escribe la velocidad y el tamaño de letra en el panel.
// Lo que se teclea ahí no puede dejar al teleprompter con un valor que no sabe
// usar, y en un teclado latinoamericano la coma es lo que sale natural.
comprobar("entiende el punto", NumberRow.leer("4.5") == 4.5)
comprobar("entiende la coma", NumberRow.leer("4,5") == 4.5)
comprobar("aguanta espacios", NumberRow.leer("  7 ") == 7)
comprobar("rechaza lo que no es número", NumberRow.leer("rápido") == nil)
comprobar("rechaza el campo vacío", NumberRow.leer("") == nil)

comprobar("un número escrito de más se acomoda al tope",
          casi(NumberRow.acomodar(99, minimo: 0.3, maximo: 10, decimales: 1), 10))
comprobar("un número escrito de menos se acomoda al piso",
          casi(NumberRow.acomodar(-3, minimo: 16, maximo: 120, decimales: 0), 16))
comprobar("el tamaño de letra se guarda entero",
          casi(NumberRow.acomodar(38.7, minimo: 16, maximo: 120, decimales: 0), 39))
comprobar("la velocidad se guarda con un decimal",
          casi(NumberRow.acomodar(4.56, minimo: 0.3, maximo: 10, decimales: 1), 4.6))

// Traer el guion de un archivo. Se prueba con documentos escritos al vuelo, no
// con archivos de ejemplo en el repo: lo que importa es que el camino de ida y
// vuelta funcione en esta Mac, con los importadores que tenga instalados.
//
// El caso que de verdad se está cuidando es el .docx: es lo que sale de bajar un
// Google Docs, que es como Sebas tiene los guiones.
let carpeta = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("guiones-\(UUID().uuidString)")
try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: carpeta) }

let guion = "Primer párrafo del guion.\n\nSegundo párrafo, con acentos: canción, más allá."
let original = NSAttributedString(string: guion)

func escribir(_ tipo: NSAttributedString.DocumentType, _ extension_: String) -> URL? {
    let destino = carpeta.appendingPathComponent("guion.\(extension_)")
    guard let envoltorio = try? original.fileWrapper(
        from: NSRange(location: 0, length: original.length),
        documentAttributes: [.documentType: tipo]) else { return nil }
    guard (try? envoltorio.write(to: destino, options: .atomic, originalContentsURL: nil)) != nil else { return nil }
    return destino
}

// El .docx se prueba contra un archivo **de verdad**, hecho por Word, y no
// contra uno escrito acá: `fileWrapper(.officeOpenXML)` genera una carpeta de
// 192 bytes que ni el propio AppKit vuelve a abrir, así que una prueba de ida y
// vuelta daría rojo con el código bueno. Es el caso que importa, porque es lo
// que sale de bajar un Google Docs.
if let raiz = ProcessInfo.processInfo.environment["RAIZ"] {
    let word = URL(fileURLWithPath: raiz).appendingPathComponent("teleprompter_codigo_completo.docx")
    if FileManager.default.fileExists(atPath: word.path) {
        let leido = ScriptFile.texto(de: word)
        comprobar("lee un Word (.docx), que es como se baja un Google Docs",
                  (leido?.count ?? 0) > 500)
    } else {
        print("  — sin .docx de ejemplo en el repo, ese caso no se probó")
    }
} else {
    print("  — sin RAIZ en el entorno, el caso del .docx no se probó")
}

if let rtf = escribir(.rtf, "rtf") {
    comprobar("lee un RTF", ScriptFile.texto(de: rtf)?.contains("Primer párrafo") == true)
} else {
    comprobar("lee un RTF", false)
}

let plano = carpeta.appendingPathComponent("guion.txt")
try? guion.write(to: plano, atomically: true, encoding: .utf8)
comprobar("lee un texto plano", ScriptFile.texto(de: plano)?.contains("más allá") == true)

// Un archivo sin texto no puede cargarse como guion: cargar un guion vacío en
// silencio es peor que avisar que no se pudo.
let vacio = carpeta.appendingPathComponent("vacio.txt")
try? "   \n  ".write(to: vacio, atomically: true, encoding: .utf8)
comprobar("un archivo sin texto no se carga", ScriptFile.texto(de: vacio) == nil)

comprobar("el cuadro de abrir ofrece Word y texto", ScriptFile.tiposSoportados.count >= 4)

print("")
if fallos == 0 {
    print("  Motor del teleprompter: en verde.")
} else {
    print("  Motor del teleprompter: \(fallos) fallo(s).")
    exit(1)
}
