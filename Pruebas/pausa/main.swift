import AVFoundation

// Prueba de la pausa: 1s grabado, 2s de pausa, 1s más.
// El archivo tiene que durar ~2s, no ~4s.
Logger.shared.openLog(named: "prueba-pausa")
let out = URL(fileURLWithPath: "pausa.mov")
try? FileManager.default.removeItem(at: out)
let w = try! RecordingWriter(outputURL: out, pixelSize: CGSize(width: 320, height: 240), withAudio: false)

// Un búfer nuevo por frame, desde una piscina, como hace la captura real.
var pool: CVPixelBufferPool?
CVPixelBufferPoolCreate(nil, nil, [
    kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey: 320, kCVPixelBufferHeightKey: 240,
    kCVPixelBufferIOSurfacePropertiesKey: [:]
] as CFDictionary, &pool)

func frame(_ n: Int) -> CMSampleBuffer? {
    var pb: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool!, &pb) == kCVReturnSuccess, let pb else { return nil }
    CVPixelBufferLockBaseAddress(pb, [])
    memset(CVPixelBufferGetBaseAddress(pb), Int32(n % 200), CVPixelBufferGetDataSize(pb))
    CVPixelBufferUnlockBaseAddress(pb, [])

    var fd: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pb, formatDescriptionOut: &fd)
    var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                    presentationTimeStamp: CMTime(value: CMTimeValue(n), timescale: 30),
                                    decodeTimeStamp: .invalid)
    var sb: CMSampleBuffer?
    CMSampleBufferCreateForImageBuffer(allocator: nil, imageBuffer: pb, dataReady: true,
                                       makeDataReadyCallback: nil, refcon: nil,
                                       formatDescription: fd!, sampleTiming: &timing, sampleBufferOut: &sb)
    return sb
}

for n in 0..<30 { if let f = frame(n) { w.append(f) }; usleep(33000) }
w.pause()
for n in 30..<90 { if let f = frame(n) { w.append(f) }; usleep(33000) }
w.resume()
for n in 90..<120 { if let f = frame(n) { w.append(f) }; usleep(33000) }

let sem = DispatchSemaphore(value: 0)
w.finish { sem.signal() }
sem.wait()
// Verificación síncrona: crear un AVAssetReader carga las pistas sin usar la
// API asíncrona, que en este proceso se queda colgada después de haber escrito.
let asset = AVURLAsset(url: out)
guard let reader = try? AVAssetReader(asset: asset) else {
    print("  ✗ el archivo no se puede abrir")
    exit(1)
}
let duracion = CMTimeGetSeconds(reader.asset.duration)
print(String(format: "  duración del archivo: %.2fs (esperado ~2.0s: 1s + 1s, sin los 2s de pausa)", duracion))
let ok = duracion > 1.7 && duracion < 2.4
print(ok ? "  LA PAUSA FUNCIONA: el hueco no queda en el archivo"
         : "  ✗ FALLA: la pausa no se descontó bien")
exit(ok ? 0 : 1)
