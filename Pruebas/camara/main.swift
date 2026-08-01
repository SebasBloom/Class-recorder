import CoreGraphics
import Foundation

// Prueba del recorte de la cámara. Se corre con ./probar.sh
//
// `fillRect` decide cómo entra la imagen de la cámara en un destino que no tiene
// su misma proporción: el modo cámara completa (una cámara 16:9 en una pantalla
// 16:10) y la burbuja. Si se equivoca, la cara sale estirada o descentrada, y a
// ojo se ve como "algo raro tiene el video" sin poder decir qué.

var fallos = 0

func comprobar(_ descripcion: String, _ obtenido: CGFloat, _ esperado: CGFloat) {
    if abs(obtenido - esperado) > 0.001 {
        print("  ✗ \(descripcion): se esperaba \(esperado) y llegó \(obtenido)")
        fallos += 1
    } else {
        print("  ✓ \(descripcion)")
    }
}

print("Recorte de la cámara")

// Cámara 16:9 en una pantalla 16:10: sobra ancho, se recorta por los costados.
let pantalla = CGRect(x: 0, y: 0, width: 2880, height: 1800)
let ancha = FrameCompositor.fillRect(imageSize: CGSize(width: 1920, height: 1080), in: pantalla)
comprobar("llena el alto", ancha.height, 1800)
comprobar("se pasa de ancho", ancha.width, 3200)
comprobar("el sobrante se reparte parejo", ancha.minX, -160)
comprobar("centrado vertical", ancha.minY, 0)

// La misma proporción: entra exacto, sin recorte.
let exacta = FrameCompositor.fillRect(imageSize: CGSize(width: 1280, height: 800), in: pantalla)
comprobar("proporción igual, ancho exacto", exacta.width, 2880)
comprobar("proporción igual, alto exacto", exacta.height, 1800)
comprobar("proporción igual, sin desplazamiento", exacta.minX, 0)

// Cámara vertical (el iPhone de lado) en un destino apaisado: sobra alto.
let alta = FrameCompositor.fillRect(imageSize: CGSize(width: 1080, height: 1920), in: pantalla)
comprobar("vertical, llena el ancho", alta.width, 2880)
comprobar("vertical, se pasa de alto", alta.height, 5120)
comprobar("vertical, recorte centrado", alta.minY, -1660)

// La burbuja no está en el origen: el centrado es respecto al destino, no a la
// pantalla.
let burbuja = CGRect(x: 2000, y: 1400, width: 400, height: 300)
let enBurbuja = FrameCompositor.fillRect(imageSize: CGSize(width: 1920, height: 1080), in: burbuja)
comprobar("burbuja, llena el alto", enBurbuja.height, 300)
comprobar("burbuja, centrada en su propio marco", enBurbuja.midX, burbuja.midX)

// Sin imagen no se divide por cero: se devuelve el destino tal cual.
let vacia = FrameCompositor.fillRect(imageSize: .zero, in: burbuja)
comprobar("imagen vacía no revienta", vacia.width, burbuja.width)

print(fallos == 0 ? "\nTodo bien, 0 fallos" : "\nFALLÓ: \(fallos) comprobaciones")
exit(fallos == 0 ? 0 : 1)
