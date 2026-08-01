import AVFoundation

// Prueba del reloj propio del modo cámara.
//
// Cuando la pantalla no cambia, ScreenCaptureKit deja de mandar cuadros. En modo
// cámara eso congela la cara del video mientras el audio sigue, así que el
// pipeline emite cuadros propios con el reloj del sistema, el mismo que usa la
// captura para sus timestamps.
//
// Acá se reproduce esa secuencia contra el escritor real: un tramo de captura,
// un tramo sostenido por el reloj propio, y otro de captura. Lo que se verifica
// es lo que a ojo no se ve hasta que es tarde: que los cuadros de las dos
// fuentes caigan ordenados en la misma línea de tiempo y el archivo salga
// continuo, sin hueco y sin que el escritor aborte.

Logger.shared.openLog(named: "prueba-reloj")
let out = URL(fileURLWithPath: "reloj.mov")
try? FileManager.default.removeItem(at: out)
let w = try! RecordingWriter(outputURL: out, pixelSize: CGSize(width: 320, height: 240), withAudio: false)

var pool: CVPixelBufferPool?
CVPixelBufferPoolCreate(nil, nil, [
    kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey: 320, kCVPixelBufferHeightKey: 240,
    kCVPixelBufferIOSurfacePropertiesKey: [:]
] as CFDictionary, &pool)

func frame(at time: CMTime, tono: Int) -> CMSampleBuffer? {
    var pb: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool!, &pb) == kCVReturnSuccess, let pb else { return nil }
    CVPixelBufferLockBaseAddress(pb, [])
    memset(CVPixelBufferGetBaseAddress(pb), Int32(tono % 200), CVPixelBufferGetDataSize(pb))
    CVPixelBufferUnlockBaseAddress(pb, [])

    var fd: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pb, formatDescriptionOut: &fd)
    var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                    presentationTimeStamp: time,
                                    decodeTimeStamp: .invalid)
    var sb: CMSampleBuffer?
    CMSampleBufferCreateForImageBuffer(allocator: nil, imageBuffer: pb, dataReady: true,
                                       makeDataReadyCallback: nil, refcon: nil,
                                       formatDescription: fd!, sampleTiming: &timing, sampleBufferOut: &sb)
    return sb
}

let reloj = CMClockGetHostTimeClock()
let arranque = CMClockGetTime(reloj)

// La guarda del pipeline: nada que llegue con un timestamp ya usado entra al
// archivo. Es lo que protege del desorden al volver la captura después de un
// tramo cubierto por el reloj propio.
var ultimoEscrito = CMTime.invalid
var rechazados = 0

func escribir(_ time: CMTime, tono: Int) {
    if ultimoEscrito.isValid, time <= ultimoEscrito { rechazados += 1; return }
    guard let f = frame(at: time, tono: tono) else { return }
    ultimoEscrito = time
    w.append(f)
}

// 1 segundo de captura normal.
for n in 0..<30 {
    escribir(CMClockGetTime(reloj), tono: n)
    usleep(33_000)
}

// La captura se calla 2 segundos y el reloj propio sostiene la imagen.
let finDeCaptura = CMClockGetTime(reloj)
for n in 0..<60 {
    escribir(CMClockGetTime(reloj), tono: 100 + n)
    usleep(33_000)
}

// Vuelve la captura. Los primeros cuadros traen timestamps de antes de que el
// reloj propio dejara de emitir: tienen que rechazarse, no romper el archivo.
escribir(finDeCaptura, tono: 200)
escribir(CMTimeSubtract(CMClockGetTime(reloj), CMTime(seconds: 0.5, preferredTimescale: 600)), tono: 201)
for n in 0..<30 {
    escribir(CMClockGetTime(reloj), tono: 200 + n)
    usleep(33_000)
}

// Los cuadros llevan el reloj del sistema, así que el archivo tiene que durar lo
// que duró la secuencia de verdad, no un número inventado: el bucle de prueba
// nunca corre exactamente a 30 por segundo.
let transcurrido = CMTimeGetSeconds(CMTimeSubtract(CMClockGetTime(reloj), arranque))

let sem = DispatchSemaphore(value: 0)
w.finish { sem.signal() }
sem.wait()

let asset = AVURLAsset(url: out)
guard let reader = try? AVAssetReader(asset: asset),
      let pista = asset.tracks(withMediaType: .video).first else {
    print("  ✗ el archivo no se puede abrir: el escritor abortó")
    exit(1)
}

let salida = AVAssetReaderTrackOutput(track: pista, outputSettings: nil)
reader.add(salida)
reader.startReading()

var tiempos: [Double] = []
while let sb = salida.copyNextSampleBuffer() {
    tiempos.append(CMSampleBufferGetPresentationTimeStamp(sb).seconds)
}

let duracion = CMTimeGetSeconds(asset.duration)
let mayorHueco = zip(tiempos, tiempos.dropFirst()).map { $1 - $0 }.max() ?? 0

print(String(format: "  duración: %.2fs (la secuencia duró %.2fs)", duracion, transcurrido))
print("  cuadros en el archivo: \(tiempos.count), \(rechazados) rechazados por orden")
print(String(format: "  hueco más grande entre cuadros: %.3fs", mayorHueco))

var fallos = 0
if abs(duracion - transcurrido) > 0.4 { print("  ✗ la duración no corresponde al tiempo real"); fallos += 1 }
if tiempos.count < 110 { print("  ✗ faltan cuadros en el archivo"); fallos += 1 }
// El umbral no es 1/30: el bucle de prueba comparte la máquina con el
// codificador y da tirones. Lo que importa es que no quede un hueco visible.
if mayorHueco > 0.35 { print("  ✗ quedó un hueco: la imagen se congelaría ahí"); fallos += 1 }
if rechazados != 2 { print("  ✗ la guarda de orden rechazó \(rechazados) en vez de 2"); fallos += 1 }

print(fallos == 0 ? "\n  EL RELOJ PROPIO FUNCIONA: las dos fuentes caen ordenadas y el archivo sale continuo"
                  : "\n  ✗ FALLA")
exit(fallos == 0 ? 0 : 1)
