import AVFoundation
import Accelerate

// Prueba aislada de la mezcla, como manda el punto 6 del protocolo del plan.
// Fuente A ("micrófono"): 440 Hz, MONO, a 44100 Hz -> obliga a remuestrear.
// Fuente B ("sistema"):  1000 Hz, ESTÉREO, a 48000 Hz.
// Se comprueba que la salida traiga las dos frecuencias, que no se pase de 1.0,
// y que dure lo que tiene que durar.

func bloque(frecuencia: Double, sampleRate: Double, canales: AVAudioChannelCount,
            frames: Int, desdeFrame: Int, amplitud: Float) -> CMSampleBuffer? {
    let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
                            channels: canales, interleaved: true)!
    let pcm = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(frames))!
    pcm.frameLength = AVAudioFrameCount(frames)
    let d = pcm.floatChannelData![0]
    for i in 0..<frames {
        let t = Double(desdeFrame + i) / sampleRate
        let v = amplitud * Float(sin(2 * .pi * frecuencia * t))
        for c in 0..<Int(canales) { d[i * Int(canales) + c] = v }
    }
    var fd: CMAudioFormatDescription?
    var asbd = fmt.streamDescription.pointee
    CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil,
                                   magicCookieSize: 0, magicCookie: nil, extensions: nil,
                                   formatDescriptionOut: &fd)
    var timing = CMSampleTimingInfo(
        duration: CMTime(value: 1, timescale: CMTimeScale(sampleRate)),
        presentationTimeStamp: CMTime(value: CMTimeValue(desdeFrame), timescale: CMTimeScale(sampleRate)),
        decodeTimeStamp: .invalid)
    var sb: CMSampleBuffer?
    CMSampleBufferCreate(allocator: nil, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil,
                         refcon: nil, formatDescription: fd, sampleCount: CMItemCount(frames),
                         sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                         sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sb)
    guard let sb else { return nil }
    CMSampleBufferSetDataBufferFromAudioBufferList(sb, blockBufferAllocator: nil,
        blockBufferMemoryAllocator: nil, flags: 0, bufferList: pcm.mutableAudioBufferList)
    return sb
}

var salida: [Float] = []
var bloquesEmitidos = 0
let mixer = AudioMixer { sb in
    bloquesEmitidos += 1
    guard let bb = CMSampleBufferGetDataBuffer(sb) else { return }
    var len = 0; var p: UnsafeMutablePointer<Int8>?
    CMBlockBufferGetDataPointer(bb, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &len, dataPointerOut: &p)
    guard let p else { return }
    let n = len / MemoryLayout<Float>.size
    p.withMemoryRebound(to: Float.self, capacity: n) { s in
        for i in stride(from: 0, to: n, by: 2) { salida.append(s[i]) }  // canal izquierdo
    }
}

// 3 segundos, bloques entrelazados de ~21 ms como en la vida real.
let segundos = 3.0
var fA = 0, fB = 0
while Double(fB) / 48000 < segundos {
    if let b = bloque(frecuencia: 440, sampleRate: 44100, canales: 1, frames: 940, desdeFrame: fA, amplitud: 0.6) {
        mixer.add(b, from: .microphone); fA += 940
    }
    if let b = bloque(frecuencia: 1000, sampleRate: 48000, canales: 2, frames: 1024, desdeFrame: fB, amplitud: 0.6) {
        mixer.add(b, from: .system); fB += 1024
    }
}
mixer.flush()

print("  bloques emitidos: \(bloquesEmitidos), frames: \(salida.count) (\(String(format: "%.2f", Double(salida.count)/48000))s de \(segundos)s)")

let pico = salida.map { abs($0) }.max() ?? 0
print(String(format: "  pico: %.4f %@", pico, pico <= 1.0 ? "✓ sin pasarse" : "✗ SE PASA DE 1.0"))

// Espectro: tienen que estar los dos tonos.
let N = 16384
guard salida.count >= N else { print("  ✗ salida muy corta"); exit(1) }
let inicio = salida.count/2 - N/2
var trozo = Array(salida[inicio..<inicio+N])
var hann = [Float](repeating: 0, count: N)
vDSP_hann_window(&hann, vDSP_Length(N), Int32(vDSP_HANN_NORM))
vDSP_vmul(trozo, 1, hann, 1, &trozo, 1, vDSP_Length(N))
let log2n = vDSP_Length(log2(Float(N)))
let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
var re = trozo, im = [Float](repeating: 0, count: N)
var mags = [Float](repeating: 0, count: N/2)
re.withUnsafeMutableBufferPointer { r in im.withUnsafeMutableBufferPointer { i in
    var sp = DSPSplitComplex(realp: r.baseAddress!, imagp: i.baseAddress!)
    vDSP_fft_zip(setup, &sp, 1, log2n, FFTDirection(FFT_FORWARD))
    vDSP_zvabs(&sp, 1, &mags, 1, vDSP_Length(N/2))
}}
vDSP_destroy_fftsetup(setup)
let hzPorBin = 48000.0 / Double(N)
func energiaCerca(_ hz: Double) -> Float {
    let b = Int(hz / hzPorBin)
    return mags[(b-3)...(b+3)].max() ?? 0
}
let total = mags.max() ?? 1
let e440 = energiaCerca(440) / total, e1000 = energiaCerca(1000) / total
print(String(format: "  tono del micrófono (440 Hz): %.2f %@", e440, e440 > 0.3 ? "✓" : "✗ AUSENTE"))
print(String(format: "  tono del sistema (1000 Hz): %.2f %@", e1000, e1000 > 0.3 ? "✓" : "✗ AUSENTE"))

let ok = pico <= 1.0 && e440 > 0.3 && e1000 > 0.3 && Double(salida.count)/48000 > segundos * 0.9
print(ok ? "\n  LA MEZCLA FUNCIONA" : "\n  LA MEZCLA FALLA")
exit(ok ? 0 : 1)
