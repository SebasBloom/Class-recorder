# Interdependencias

Mapa de las piezas compartidas del proyecto, organizado por pieza y no por feature, para ver qué se puede romper al tocar cada cosa.

**Cómo se usa:** antes de modificar cualquier pieza de esta lista, se lee su entrada y se revisan todos sus consumidores. Cada vez que una pieza gana o pierde un consumidor, se actualiza acá.

**Estado:** cada pieza dice en qué fase nace. Las que dicen "pendiente" todavía no existen en el código.

## Conversión de coordenadas

**Fase 2. Existe.** `Coordenadas/CoordinateConverter.swift`.

Es la pieza más compartida del proyecto y se escribe una sola vez.

Consumidores actuales: `FramePipeline`, que la usa para el círculo, los clics, el JSON y la burbuja de cámara.

Consumidores previstos: censura y selector de rectángulo. El motor de dibujo **no** la usa: guarda todo normalizado (decisión 56).

Tiene dos conversiones, no una: `pixelPoint(fromGlobal:)` para el cursor y `pixelRect(fromGlobal:)` para el marco de una ventana espejo. La de rectángulos **no** exige que entre entero en la pantalla, porque la burbuja se puede arrastrar a medias fuera del borde y en el video se ve la parte que quedó adentro.

**Tiene prueba automática** (`./probar.sh`), incluida la configuración de dos monitores con escalas distintas, que a mano es impráctica de verificar. Si se toca esta pieza, correr esa prueba antes de nada.

Detalle crítico: origen abajo izquierda en eventos de mouse contra arriba izquierda en píxeles del frame; factor de escala Retina por display; con dos monitores cada display tiene su propio espacio de coordenadas y su propio factor de escala.

Si el círculo aparece desfasado, el bug está acá y solo acá.

## Tracking global del mouse

**Fase 2. Existe.** `EntradaGlobal/MouseTracker.swift`.

Posición y clics del mouse a nivel de sistema.

Consumidores actuales: `FramePipeline`.

Consumidores previstos: el motor de dibujo, cuando haya un modo de dibujo activo (Fases 7 y 8).

Cuidado al tocarlo: la posición se guarda desde el hilo principal y se lee desde la cola de captura bajo candado. No consultar `NSEvent.mouseLocation` desde la cola de captura.

## Motor de dibujo

**Fases 7 y 8. Existe.** `Dibujo/DrawingSurface.swift` (el modelo), `Dibujo/DrawingRenderer.swift` (el dibujo) y `Dibujo/DrawingWindow.swift` (el espejo, con fondo de lienzo o transparente).

Trazos a mano alzada, cuadros de texto, paleta de colores, deshacer, borrar.

**Motor único, contenidos separados por superficie:** `DrawingSurface` es el motor y cada superficie es una instancia. Existen dos: el tablero y la capa de anotación sobre la pantalla real. Borrar una nunca toca la otra. La ventana también es una sola clase, cambiando solo el fondo (decisión 60).

Deshacer, borrar y el color actúan sobre la **superficie activa**: el tablero si el modo es tablero, la anotación si está prendida y el modo es pantalla (decisión 61). El color es la excepción, porque la paleta es una sola en la interfaz y se iguala en las dos.

Consumidores actuales: `WhiteboardWindow` para mostrar y editar, `FrameCompositor` para componerlo en el video, `RecordingController` para los atajos y para limpiarlo al iniciar cada toma.

Consumidores previstos: el widget (Fase 11, que muestra el color activo).

`DrawingWindow` participa además de la pieza **Niveles y orden de ventanas**, y desde la Fase 14 va **debajo** de todas las ventanas propias: es lo que hace que los botones del widget respondan mientras se dibuja. Cualquier cambio de su nivel o de su `present()` se lee primero allá.

Cuidado al tocarlo:

- **`DrawingRenderer` es uno solo para el espejo y para el video, a propósito.** Si se dibujara distinto en cada lado, la diferencia aparecería recién al revisar el video.
- **`version` cambia solo cuando cambia lo terminado**, no mientras se arrastra el mouse. De eso depende la caché del compositor (decisión 57): si dejara de cambiar cuando debe, lo dibujado no saldría en el video.
- Las coordenadas van normalizadas, no en píxeles (decisión 56). Por eso esta pieza **no** consume el módulo de conversión de coordenadas.
- El modelo lo escribe el hilo principal y lo lee la cola de captura: todo pasa por el candado interno.

## Gramática de botón de comando

**Fase 15. Existe.** `UI/CommandButton.swift`.

El tamaño fijo (74×46), el ícono encajado en su cuadro de 20×20, el nombre siempre a la vista y el pintado de estado —azul prendido, coral callando o tapando, gris apagado—. Es lo que hace que todo lo que se toca con la grabación corriendo se vea como una sola cosa.

Consumidores: el widget de grabación y la barra del teleprompter.

Cuidado al tocarla: el ancho del botón decide el ancho del widget (siete columnas) y el ancho mínimo de la ventana del teleprompter. Cambiarlo mueve las dos. Y los íconos que cambian en vivo tienen que volver a pasar por `CommandButton.icono`, o vuelven al tamaño de fábrica y desparejan la fila (decisión 102).

## Identidad visual

**Fase 1. Existe.** `UI/BloomindStyle.swift` y la fuente en `Recursos/Fuentes/`.

Paleta, espaciado, tipografía y el botón plano de la marca. Es la traducción a AppKit de la guía de estilo del CLM.

Consumidores actuales: `ControlWindow`.

Consumidores previstos: absolutamente toda la UI que venga. El panel de configuración y el widget flotante (Fase 11), la pantalla de preferencias (Fase 9), la tarjeta de atajos (Fase 9), el countdown (Fase 11) y los avisos de disco.

Cuidado al tocarlo: los colores son tokens de marca compartidos con CLM, whatasAPI y Bloomind Oficinas. No se inventan valores nuevos acá; si hace falta un color que no está, se resuelve con la guía del CLM. El turquesa es exclusivo de éxito y no se usa como decoración.

Consumidor previsto nuevo: el teleprompter (adenda 1), que **no** hereda la paleta del prototipo web del que sale su comportamiento.

## Niveles y orden de ventanas

**Fase 14. Existe.** `UI/WindowLevels.swift`.

Quién queda encima de quién entre las ventanas propias y, como consecuencia directa, **quién recibe el clic**: macOS entrega el evento a la ventana que esté más arriba en ese punto de la pantalla.

El orden, de abajo hacia arriba, y todo declarado en el enum `WindowLayer`:

| Ventana | Archivo | Capa |
|---|---|---|
| Espejo de dibujo (tablero y anotación) | `Dibujo/DrawingWindow.swift` | `.dibujo` |
| Teleprompter | `Teleprompter/TeleprompterWindow.swift` | `.teleprompter` |
| Espejo de la burbuja | `Camara/CameraMirrorWindow.swift` | `.burbuja` |
| Widget de grabación | `UI/RecordingWidget.swift` | `.widget` |
| Tarjeta de atajos | `UI/ShortcutCard.swift` | `.tarjeta` |
| Selector de rectángulo | `UI/RectangleSelector.swift` | `.selector` |
| Countdown | `UI/CountdownWindow.swift` | `.countdown` |

De dónde viene: antes de la Fase 14 las cinco ventanas que existían se ponían `.floating` cada una en su archivo, y con todas en el mismo nivel el orden efectivo lo decidía quién se hubiera mostrado último. Como `DrawingWindow.present()` activa la app y se hace ventana principal, la superficie de dibujo terminaba arriba y, cubriendo la pantalla entera, **se quedaba con todos los clics**: los botones del widget no respondían con el tablero o el marcador prendidos (decisión 93).

El panel de configuración no está acá: es una ventana normal y ya se esconde sola cuando aparece una superficie de dibujo.

Consumidores: las siete ventanas de la tabla.

**Tiene prueba automática** (`./probar.sh`, bloque "ventanas"), que comprueba que la pila esté estrictamente ordenada y que nadie empate con nadie. Si se toca esta pieza, correrla: el error que produce no se ve mirando la pantalla, se ve como "el botón no hace nada, a veces".

Cuidado al tocarla: es la pieza que decide a quién le llega el mouse. Cambiarla obliga a reverificar, con la grabación corriendo y a ojo sobre el video, que siguen funcionando **el círculo del cursor, la capa de anotación, el tablero y la censura**, y no solo lo que se estaba agregando. Dos trampas ya escritas en el código que un cambio de niveles puede despertar: la capa de anotación necesita un alfa mínimo para recibir clics (decisión 63), y el espejo de dibujo necesita ser la ventana con el teclado para que los cuadros de texto reciban lo que se tipea (decisión 64).

## Teleprompter

**Fase 15. Existe.** `Teleprompter/TeleprompterEngine.swift` y `Teleprompter/TeleprompterWindow.swift`.

El motor de desplazamiento y su ventana. Ayuda de lectura para el operador; nunca entra al video.

Están partidos a propósito (decisión 103): el motor no importa AppKit y lleva toda la lógica —posición, velocidad, tamaño de letra, el tope de 100 ms por cuadro y el frenado al final—; la ventana solo copia la posición del motor a la vista. **La vista nunca mueve el texto por su cuenta**: la rueda y el arrastre le piden al motor.

**Tiene prueba automática** (`./probar.sh`, bloque "teleprompter"). Si se toca el motor, correrla.

Consume: el registro de acciones y atajos (su acción de prender y apagar), la configuración central (guion, velocidad y tamaño de arranque), la identidad visual y la pieza de niveles de ventana.

**No consume el pipeline de composición ni la conversión de coordenadas**, y esa ausencia es la garantía de la decisión 89: si algún día aparece un `import` del compositor acá, alguien está por meter el teleprompter en el video.

Consumidores: el widget, que replica sus controles en el grupo *Teleprompter* del modo expandido, y `ControlWindow`, que es la dueña de la ventana: la crea al prenderla, la conserva prendida y apagada mientras dura la grabación, y la **suelta entera** al terminar (decisión 110). `RecordingController` solo rutea la acción `teleprompter` hacia afuera, porque el teleprompter no es asunto suyo.

Cuidado con el foco: esta ventana y el espejo de dibujo se pelean el teclado y no puede ser de los dos a la vez. Se lo queda la última clickeada, y al tomarlo el teleprompter cierra el cuadro de texto que estuviera abierto en el dibujo (decisión 95), llamando a `RecordingController.closeDrawingTextBox()`.

Cuidado al tocarlo: el avance va por tiempo transcurrido entre cuadros y no por cantidad de cuadros; si se cambia a contar cuadros, la velocidad pasa a depender de cuánto esté rindiendo la máquina y el mismo guion tarda distinto cada vez.

## Selector de rectángulo en pantalla

**Fase 10. Pendiente.** Carpeta prevista: `UI/`.

Arrastrar para definir una zona de la pantalla.

Consumidores: slot de censura permanente, slot de censura de sesión (Fase 10), y grabación de área personalizada (Fase 11).

## Captura de pantalla

**Fase 1. Existe.** `Captura/ScreenCapture.swift` y `Captura/ScreenRecordingPermission.swift`.

Enumeración de pantallas con su tamaño en píxeles reales, y el stream de ScreenCaptureKit a 30 fps con el cursor visible.

Consumidores actuales: `RecordingController`.

Consumidores previstos: el pipeline de composición (Fase 2) y las fuentes de audio, porque el micrófono y el audio del sistema entran por el mismo `SCStream` (Fases 3 y 4).

Cuidado al tocarlo: el filtro excluye la **aplicación entera**, no ventanas sueltas. Esa es la única forma de que las ventanas que nacen a mitad de grabación queden fuera del video. No cambiarlo a una lista de ventanas.

## Pipeline de composición de frames

**Fase 2. Existe.** `Composicion/FrameCompositor.swift` y `Composicion/FramePipeline.swift`.

`FrameCompositor` dibuja las capas; `FramePipeline` une todo lo que le pasa a un frame entre la captura y el archivo.

La matriz de visibilidad de la sección 8.4 está implementada tal cual en la función `isVisible(_:in:)`. Hoy existen las capas del círculo, el clic, la burbuja de cámara y el contenido del tablero, y los tres modos; la matriz completa ya está escrita: cada fase que agregue una capa solo tiene que dibujarla, no decidir cuándo se ve.

`fillRect(imageSize:in:)` es el recorte centrado que usan la burbuja y el modo cámara completa. Vive suelta y pura, y tiene prueba automática en `./probar.sh`.

Consume: conversión de coordenadas, tracking de mouse y la cámara.
Alimenta: el escritor de video y el escritor del JSON de cursor.

**Consumidor nuevo desde la Fase 14:** el interruptor del resaltado del cursor. Está implementado en `FramePipeline`, que le pasa al compositor `cursor` en nil y la lista de clics vacía cuando está apagado. **`FrameCompositor` no sabe que este feature existe**, y así conviene que siga: la capa se apaga cortándole la entrada, no agregándole condiciones.

Cuidado al tocarlo: dibuja dentro del mismo buffer de la captura, sin crear uno nuevo por frame. No cambiar eso sin leer la decisión 28.

## Escritor del JSON de cursor

**Fase 2. Existe.** `Escritura/CursorTrackWriter.swift`.

Escribe el `<mismo nombre>.cursor.json` que VideoFlow usa para el zoom automático.

Consumidores actuales: `FramePipeline`.

Cuidado al tocarlo: las coordenadas van en píxeles del video final y los tiempos en segundos del video final, descontando pausas. VideoFlow no sabe nada de macOS, ni de escalas, ni de pausas, y así tiene que seguir.

**El interruptor del resaltado del cursor (Fase 14) no lo afecta a propósito** (decisión 98): con el círculo apagado, esta pieza sigue recibiendo la posición y los clics completos. El día que alguien "optimice" dejando de calcular el cursor cuando el resaltado está apagado, el zoom automático de VideoFlow se queda sin datos y nadie se entera hasta la edición.

Desde la Fase 6 escribe también los eventos de cambio de modo (`{"tipo": "modo", "valor": "camara"}`). El cambio se anota con el tiempo del frame siguiente y no con el del atajo: el JSON habla en tiempo de video, no en tiempo de reloj.

## Escritor de video y audio

**Fase 1. Existe.** `Escritura/RecordingWriter.swift`.

AVAssetWriter en contenedor `.mov`, HEVC por hardware, fragmentos cada 5 segundos, y el desplazamiento de timestamps por pausa ya implementado.

Consumidores actuales: `RecordingController`, que le pasa los frames de la captura directo.

Consumidores previstos: el pipeline de composición (Fase 2, se mete en el medio) y las fuentes de audio (Fases 3 a 5).

Cuidado al tocarlo: `shouldOptimizeForNetworkUse` tiene que quedar apagado y `movieFragmentInterval` puesto, o se pierde la resistencia a fallos de la decisión 11. La perilla de calidad es `bitsPerPixel`, y vive solo acá.

La pista de audio todavía no existe: cuando llegue, el `startSession` tiene que seguir disparándose con el primer buffer que llegue de cualquier pista, no solo de video.

## Atajos globales

**Fase 6. Existe.** `EntradaGlobal/HotKey.swift`.

Registra una combinación con el sistema vía Carbon (`RegisterEventHotKey`), sin permiso de Accesibilidad (decisión 45).

Consumidores actuales: `RecordingController`, con los dos atajos fijos de modo (Opción Comando 1 y 2), registrados solo mientras se graba.

Consumidores previstos: el registro central de la Fase 9, y con él todos los features operables con teclado.

Cuidado al tocarlo: el manejador de Carbon es uno solo para toda la app y reparte por identificador. La instancia hay que retenerla: al soltarla se desregistra el atajo, que es justamente cómo se apagan al detener la grabación.

## Registro de acciones y atajos

**Fase 9. Existe.** `EntradaGlobal/ShortcutRegistry.swift` y `EntradaGlobal/Shortcut.swift`.

El registro reasignable con su pantalla de preferencias y la detección de conflictos, construido encima de `HotKey`.

Consumidores: todos los features operables con teclado, la pantalla de preferencias, la tarjeta de recordatorio y, desde la adenda 1, el widget, que muestra un botón por cada acción del registro.

**Consumidores nuevos:** la Fase 14 suma la acción `resaltadoCursor` (⌥⌘A) y el teleprompter suma `teleprompter` (⌥⌘T). Agregar una acción es agregar un caso al enum `ShortcutAction` con su etiqueta y su combinación; el `rawValue` es lo que se guarda en `config.json`, así que no se cambia después.

Cuidado nuevo desde la adenda 1: las teclas sueltas del teleprompter (espacio y flechas) **no pasan por acá**. Son eventos de la ventana enfocada, activos solo mientras el teleprompter tiene el foco y apagados mientras se edita el guion (decisión 92). Meterlas al registro las volvería globales y romperían la escritura en cualquier app.

Hasta la Fase 9 cada fase usó atajos fijos temporales, ya migrados acá.

## Cámara

**Fase 6. Existe.** `Camara/CameraCapture.swift` y `Camara/CameraMirrorWindow.swift`.

`CameraCapture` corre la sesión a resolución completa y entrega dos cosas: la capa de previsualización para el espejo y la última imagen ya convertida para el compositor (decisión 46). `CameraMirrorWindow` es la ventana que se arrastra y se redimensiona.

Consumidores actuales: `ControlWindow`, que la enciende al elegir cámara; `FramePipeline`, que lee la imagen; `RecordingController`, que la suelta si se desconecta; el widget, con su botón de burbuja on/off.

Consumidores previstos: el menú de cámara del widget en la Fase 13, que puede **crear** una `CameraCapture` con la grabación ya corriendo.

Cuidado al tocarlo: la sesión vive mientras haya una cámara elegida, no solo mientras se graba. Y la proporción de la ventana espejo está clavada a la de la cámara a propósito: es lo que hace que lo que se ve en pantalla sea exactamente lo que queda en el video.

`CameraMirrorWindow` participa de la pieza **Niveles y orden de ventanas**, y es además el patrón que copia la ventana del teleprompter: panel sin barra de título que no activa la app, arrastrable por el fondo, redimensionable, con la posición guardada al quedarse quieta la mano.

Sobre los fondos virtuales: no se construyen, se usa el reemplazo de fondo nativo de macOS Sequoia, que actúa antes de que la imagen llegue a la app (decisión 94). Esta pieza no tiene nada que hacer al respecto.

Cuidado nuevo desde la Fase 13: `FramePipeline` guardaba la cámara como constante, fijada al construirse. Al poder prenderla y apagarla en vivo pasa a ser mutable bajo el mismo lock que los demás ajustes en vivo (`setBoardColor`, `setAnnotationOn`, `setBubbleFrame`). Todo lo que lea la cámara desde la cola de captura tiene que hacerlo por ese lock: la cola de frames corre 30 veces por segundo y el cambio llega desde el hilo principal.

## Enumeración de dispositivos

**Fase 3 (audio) y Fase 6 (cámara). Existen.** `Audio/AudioDeviceEnumerator.swift` y `Camara/CameraDeviceEnumerator.swift`.

Listas dinámicas que se actualizan en vivo al conectar o desconectar, más el permiso del dispositivo y la resiliencia de la sección 5 del plan.

Consumidores actuales: `ControlWindow` para la lista, `RecordingController` para el permiso y para detectar la desconexión a mitad de grabación.

**La enumeración de cámaras de la Fase 6 sigue este mismo patrón.** Si cambia el manejo de desconexión acá, hay que replicarlo allá, y viceversa. Las dos se apoyan en las notificaciones `wasConnected` y `wasDisconnected` de `AVCaptureDevice`.

## Audio del micrófono

**Fase 3. Existe.** `Captura/ScreenCapture.swift` (captura) y `Audio/AudioLevelMeter.swift` (medidor).

El micrófono entra por el **mismo** `SCStream` que la pantalla, con `captureMicrophone`. Es la razón por la que el proyecto exige macOS 15.

Consumidores actuales: `RecordingController`, que enchufa el audio a la mezcla.

Cuidado al tocarlo: el medidor de nivel y la grabación **no pueden tener el micrófono a la vez**. El medidor se apaga al empezar a grabar y se vuelve a encender al terminar.

## Mezcla de audio

**Fase 5. Existe.** `Audio/AudioMixer.swift`.

Búfer circular sobre una línea de tiempo común: cada bloque se escribe en la posición absoluta que le corresponde según su timestamp y se suma a lo que ya haya ahí. Un tramo se emite cuando pasó el margen de latencia de 0,25 s. Todo se lleva antes a 48 kHz estéreo flotante.

Consumidores actuales: `RecordingController`, solo en modo "Micrófono + sistema".

**Cambios de la Fase 13**, los tres en esta misma pieza:
- Pasa a **un carril por fuente**, con la suma al emitir en vez de sobre un búfer compartido (decisión 85). Sin esto no se puede tratar distinto a una fuente que a la otra.
- Pasa a ser el **camino único de todo el audio**, también en los modos de una sola fuente (decisión 80).
- Aplica el **silencio en vivo** con ganancia cero (decisión 81) y el **ducking** del sistema mientras se habla (decisión 86). Los dos se aplican en el mismo punto: al emitir, cuando ya llegaron las dos fuentes.

Cuidado al tocarlo: es la pieza más delicada del proyecto y ahora la atraviesan los cuatro modos, así que **cualquier cambio obliga a reverificar los cuatro**, no solo el mixto. Dos trampas ya pisadas: la caché de convertidores tiene que indexarse por el formato y no por la identidad del objeto (decisión 79), y silenciar nunca puede hacerse cortando el flujo de buffers, porque la posición escrita más alta deja de avanzar y el tramo no se emite (decisión 81).

## Configuración central

**Fase 0. Existe.** `Configuracion/Configuration.swift`.

Un solo `config.json` en `~/Library/Application Support/Grabador Bloomind/`, legible a mano. Borrarlo equivale a reset de fábrica.

Consumidores actuales: `AppDelegate` (la carga al arrancar), `RecordingController` (carpeta de salida), `ControlWindow` (última pantalla usada), `MenuBarController` (abrir la carpeta).

Consumidores previstos: casi todos los módulos. Cada fase que agregue un campo lo agrega al struct `Configuration` con su valor por defecto, para que un archivo viejo siga cargando.

**Campos nuevos:** el modo del widget (compacto o expandido) y el resaltado del cursor, los dos de la Fase 14; el guion del teleprompter con su velocidad y su tamaño de letra de arranque, de la Fase 15. Lo que **no** va acá es el estado en vivo del teleprompter —posición, tamaño, velocidad y guion mientras se graba—: eso vive en memoria y muere con la grabación (decisión 91).

Cuidado: los campos son opcionales a propósito. Nulo significa "todavía no se eligió", no "vacío".

**Cuidado nuevo desde la Fase 14:** la lectura es tolerante a propósito (`init(from:)` propio con `decodeIfPresent`). Un campo que no está en el archivo toma su valor por defecto en vez de invalidar la configuración entera. Sin eso, agregar un campo manda a `config.json.dañado` la configuración de quien venía usando la app y la hace arrancar de fábrica, una sola vez y sin forma de reproducirlo después (decisión 96). **Tiene prueba automática** (`./probar.sh`, bloque "configuracion"): si se toca la decodificación, correrla.

## Registro (logging)

**Fase 0. Existe.** `Registro/Logger.swift`.

Un archivo por grabación en `~/Library/Logs/Grabador Bloomind/`, más uno general mientras no hay grabación. Conserva los últimos 20.

Consumidores actuales: `AppDelegate`, `ConfigurationStore`, `RecordingController`, `ScreenCapture`, `RecordingWriter`, `ControlWindow`, `ScreenRecordingPermission`.

Consumidores previstos: todos los módulos.

Regla de privacidad: se registra el evento, nunca el contenido. "Censura permanente activada" sí; qué había en pantalla o qué se tipeó en una anotación, jamás.
