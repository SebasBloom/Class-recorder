// swift-tools-version: 6.0
import PackageDescription

// El paquete produce un ejecutable pelado. El bundle "Grabador Bloomind.app"
// (con su Info.plist y su firma) lo arma construir.sh, porque SwiftPM no sabe
// empacar apps de macOS por sí solo.
let package = Package(
    name: "GrabadorBloomind",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "GrabadorBloomind",
            path: "Sources/GrabadorBloomind",
            // Modo de lenguaje 5: el modo 6 exige anotaciones de concurrencia en
            // cada callback de AVFoundation y ScreenCaptureKit, que llegan desde
            // colas propias del sistema. Ver DECISIONS.md.
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
