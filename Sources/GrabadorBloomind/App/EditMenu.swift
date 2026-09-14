import AppKit

/// El menú principal invisible de la app.
///
/// La app vive en la barra de menú y no muestra menús propios, pero **igual
/// necesita un `mainMenu`**: macOS entrega Cmd+C, Cmd+V, Cmd+X, Cmd+A y Cmd+Z a
/// los campos de texto recorriendo el menú principal en busca de la combinación.
/// Sin menú no hay a quién preguntarle, y el atajo simplemente no pasa nada
/// (decisión 117).
///
/// Es el motivo por el que no se podía pegar el guion del teleprompter, y
/// afectaba por igual al nombre de la sesión y a los cuadros de texto del
/// tablero. Como la política de activación es `.accessory`, este menú no se
/// dibuja en ningún lado: existe solo para que las combinaciones lleguen.
enum EditMenu {

    static func install() {
        let principal = NSMenu()

        // El primer menú es el de la aplicación y macOS lo trata distinto:
        // tiene que existir aunque esté casi vacío.
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Salir de Grabador Bloomind",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        principal.addItem(appItem)

        let edicionItem = NSMenuItem()
        let edicion = NSMenu(title: "Edición")
        // Cada uno manda su acción al primer respondedor, que es el campo de
        // texto que tenga el cursor en ese momento.
        agregar(edicion, "Deshacer", #selector(UndoManager.undo), "z")
        agregar(edicion, "Rehacer", #selector(UndoManager.redo), "Z")
        edicion.addItem(.separator())
        agregar(edicion, "Cortar", #selector(NSText.cut(_:)), "x")
        agregar(edicion, "Copiar", #selector(NSText.copy(_:)), "c")
        agregar(edicion, "Pegar", #selector(NSText.paste(_:)), "v")
        agregar(edicion, "Seleccionar todo", #selector(NSText.selectAll(_:)), "a")
        edicionItem.submenu = edicion
        principal.addItem(edicionItem)

        NSApp.mainMenu = principal
    }

    private static func agregar(_ menu: NSMenu, _ titulo: String, _ accion: Selector, _ tecla: String) {
        let item = NSMenuItem(title: titulo, action: accion, keyEquivalent: tecla)
        // Sin target: el evento viaja por la cadena de respondedores hasta quien
        // sepa atenderlo. Es lo que hace que funcione en cualquier campo.
        item.target = nil
        menu.addItem(item)
    }
}
