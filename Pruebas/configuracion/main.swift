import Foundation

// Prueba de que un config.json viejo sigue cargando. Se corre con ./probar.sh
//
// Existe por un error ya cometido: agregar un campo no opcional al struct mandó
// el config.json de Sebas a config.json.dañado y la app arrancó de fábrica. El
// archivo no se perdió (decisión 21), pero los atajos y la burbuja sí se fueron
// de la sesión sin que nadie hubiera tocado nada.
//
// El síntoma es traicionero porque aparece **una sola vez**, en la primera
// apertura después de actualizar, y de ahí en adelante todo parece normal: el
// archivo nuevo ya tiene el campo. O sea que es imposible de reproducir después.

var fallos = 0

func comprobar(_ descripcion: String, _ condicion: Bool) {
    if condicion {
        print("  ✓ \(descripcion)")
    } else {
        print("  ✗ \(descripcion)")
        fallos += 1
    }
}

print("Configuración")

// Un archivo real de antes de la Fase 14: sin los campos que vinieron después.
let viejo = """
{
  "boardColor" : "blanco",
  "bubbleFrame" : { "height" : 178, "width" : 317, "x" : 0, "y" : 8 },
  "countdownEnabled" : false,
  "lastAudioMode" : "sin-audio",
  "lastDisplayID" : 1,
  "lastSessionName" : "Plataforma Neon",
  "outputFolder" : "/Users/sebas/Movies/Grabador Bloomind",
  "shortcuts" : { },
  "widgetPosition" : { "x" : 1156, "y" : 750 }
}
"""

guard let cargado = try? JSONDecoder().decode(Configuration.self, from: Data(viejo.utf8)) else {
    print("  ✗ un config.json de la versión anterior ya no carga")
    exit(1)
}

comprobar("un archivo sin el campo nuevo carga igual", true)
comprobar("el campo nuevo toma su valor por defecto", cargado.widgetMini == false)
comprobar("el resaltado del cursor arranca prendido si no está en el archivo",
          cargado.cursorHighlightEnabled == true)
comprobar("no se pierde la cuenta regresiva apagada", cargado.countdownEnabled == false)
comprobar("no se pierde el nombre de la sesión", cargado.lastSessionName == "Plataforma Neon")
comprobar("no se pierde la burbuja", cargado.bubbleFrame?.width == 317)

// Un guion cargado antes de que se pudiera desmarcar: tiene que entrar marcado.
let guionViejo = #"{ "teleprompterScripts" : [ { "nombre" : "Intro", "texto" : "Hola" } ] }"#
if let conGuion = try? JSONDecoder().decode(Configuration.self, from: Data(guionViejo.utf8)) {
    comprobar("un guion de la versión anterior carga y queda marcado",
              conGuion.teleprompterScripts.first?.usar == true && conGuion.teleprompterScripts.first?.nombre == "Intro")
} else {
    print("  ✗ un guion de la versión anterior ya no carga")
    fallos += 1
}

// Un archivo vacío también tiene que cargar: es el caso de un reset a mano.
if let vacio = try? JSONDecoder().decode(Configuration.self, from: Data("{}".utf8)) {
    comprobar("un archivo vacío arranca con los valores por defecto",
              vacio.countdownEnabled == true && vacio.shortcuts.isEmpty)
} else {
    print("  ✗ un archivo vacío no carga")
    fallos += 1
}

// Y lo que se escribe tiene que volver a leerse idéntico.
var ida = Configuration()
ida.widgetMini = true
ida.lastSessionName = "Clase Supabase"
if let datos = try? JSONEncoder().encode(ida),
   let vuelta = try? JSONDecoder().decode(Configuration.self, from: datos) {
    comprobar("lo que se guarda se vuelve a leer igual", vuelta == ida)
} else {
    print("  ✗ la configuración no sobrevive una ida y vuelta")
    fallos += 1
}

print("")
if fallos == 0 {
    print("  Configuración: en verde.")
} else {
    print("  Configuración: \(fallos) fallo(s).")
    exit(1)
}
