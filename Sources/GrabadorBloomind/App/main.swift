import AppKit

// Arranque de la app. La política .accessory la deja fuera del Dock: vive en la
// barra de menú. El Info.plist también lo declara con LSUIElement, pero ponerlo
// acá hace que el ejecutable se comporte igual si se corre sin bundle.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
