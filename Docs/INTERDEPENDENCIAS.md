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

**Fase 7. Existe.** `Dibujo/DrawingSurface.swift` (el modelo), `Dibujo/DrawingRenderer.swift` (el dibujo) y `Dibujo/WhiteboardWindow.swift` (el espejo del tablero).

Trazos a mano alzada, cuadros de texto, paleta de colores, deshacer, borrar.

**Motor único, contenidos separados por superficie:** `DrawingSurface` es el motor y cada superficie es una instancia. Hoy existe la del tablero; la capa de anotación de la Fase 8 es otra instancia de la misma clase. Borrar una nunca toca la otra.

Consumidores actuales: `WhiteboardWindow` para mostrar y editar, `FrameCompositor` para componerlo en el video, `RecordingController` para los atajos y para limpiarlo al iniciar cada toma.

Consumidores previstos: la capa de anotación (Fase 8) y el widget (Fase 11, que muestra el color activo).

Cuidado al tocarlo:

- **`DrawingRenderer` es uno solo para el espejo y para el video, a propósito.** Si se dibujara distinto en cada lado, la diferencia aparecería recién al revisar el video.
- **`version` cambia solo cuando cambia lo terminado**, no mientras se arrastra el mouse. De eso depende la caché del compositor (decisión 57): si dejara de cambiar cuando debe, lo dibujado no saldría en el video.
- Las coordenadas van normalizadas, no en píxeles (decisión 56). Por eso esta pieza **no** consume el módulo de conversión de coordenadas.
- El modelo lo escribe el hilo principal y lo lee la cola de captura: todo pasa por el candado interno.

## Identidad visual

**Fase 1. Existe.** `UI/BloomindStyle.swift` y la fuente en `Recursos/Fuentes/`.

Paleta, espaciado, tipografía y el botón plano de la marca. Es la traducción a AppKit de la guía de estilo del CLM.

Consumidores actuales: `ControlWindow`.

Consumidores previstos: absolutamente toda la UI que venga. El panel de configuración y el widget flotante (Fase 11), la pantalla de preferencias (Fase 9), la tarjeta de atajos (Fase 9), el countdown (Fase 11) y los avisos de disco.

Cuidado al tocarlo: los colores son tokens de marca compartidos con CLM, whatasAPI y Bloomind Oficinas. No se inventan valores nuevos acá; si hace falta un color que no está, se resuelve con la guía del CLM. El turquesa es exclusivo de éxito y no se usa como decoración.

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

Cuidado al tocarlo: dibuja dentro del mismo buffer de la captura, sin crear uno nuevo por frame. No cambiar eso sin leer la decisión 28.

## Escritor del JSON de cursor

**Fase 2. Existe.** `Escritura/CursorTrackWriter.swift`.

Escribe el `<mismo nombre>.cursor.json` que VideoFlow usa para el zoom automático.

Consumidores actuales: `FramePipeline`.

Cuidado al tocarlo: las coordenadas van en píxeles del video final y los tiempos en segundos del video final, descontando pausas. VideoFlow no sabe nada de macOS, ni de escalas, ni de pausas, y así tiene que seguir.

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

**Fase 9. Pendiente.** Carpeta prevista: `EntradaGlobal/`.

El registro reasignable con su pantalla de preferencias y la detección de conflictos. Se construye encima de `HotKey`; lo que falta es traducir una combinación tecleada por el usuario a código de tecla y máscara de Carbon.

Consumidores: todos los features operables con teclado, la pantalla de preferencias y la tarjeta de recordatorio.

Hasta la Fase 9 cada fase usa atajos fijos temporales, que se migran acá cuando la pieza nace.

## Cámara

**Fase 6. Existe.** `Camara/CameraCapture.swift` y `Camara/CameraMirrorWindow.swift`.

`CameraCapture` corre la sesión a resolución completa y entrega dos cosas: la capa de previsualización para el espejo y la última imagen ya convertida para el compositor (decisión 46). `CameraMirrorWindow` es la ventana que se arrastra y se redimensiona.

Consumidores actuales: `ControlWindow`, que la enciende al elegir cámara; `FramePipeline`, que lee la imagen; `RecordingController`, que la suelta si se desconecta.

Consumidores previstos: el widget de la Fase 11 (botón de burbuja on/off) y el modo cámara completa de los atajos de la Fase 9.

Cuidado al tocarlo: la sesión vive mientras haya una cámara elegida, no solo mientras se graba. Y la proporción de la ventana espejo está clavada a la de la cámara a propósito: es lo que hace que lo que se ve en pantalla sea exactamente lo que queda en el video.

## Enumeración de dispositivos

**Fase 3 (audio) y Fase 6 (cámara). Existen.** `Audio/AudioDeviceEnumerator.swift` y `Camara/CameraDeviceEnumerator.swift`.

Listas dinámicas que se actualizan en vivo al conectar o desconectar, más el permiso del dispositivo y la resiliencia de la sección 5 del plan.

Consumidores actuales: `ControlWindow` para la lista, `RecordingController` para el permiso y para detectar la desconexión a mitad de grabación.

**La enumeración de cámaras de la Fase 6 sigue este mismo patrón.** Si cambia el manejo de desconexión acá, hay que replicarlo allá, y viceversa. Las dos se apoyan en las notificaciones `wasConnected` y `wasDisconnected` de `AVCaptureDevice`.

## Audio del micrófono

**Fase 3. Existe.** `Captura/ScreenCapture.swift` (captura) y `Audio/AudioLevelMeter.swift` (medidor).

El micrófono entra por el **mismo** `SCStream` que la pantalla, con `captureMicrophone`. Es la razón por la que el proyecto exige macOS 15.

Consumidores actuales: `RecordingController`, que enchufa el audio directo al escritor.

Consumidores previstos: la mezcla de la Fase 5, que va a sumar estas muestras con las del audio del sistema antes de escribirlas.

Cuidado al tocarlo: el medidor de nivel y la grabación **no pueden tener el micrófono a la vez**. El medidor se apaga al empezar a grabar y se vuelve a encender al terminar.

## Configuración central

**Fase 0. Existe.** `Configuracion/Configuration.swift`.

Un solo `config.json` en `~/Library/Application Support/Grabador Bloomind/`, legible a mano. Borrarlo equivale a reset de fábrica.

Consumidores actuales: `AppDelegate` (la carga al arrancar), `RecordingController` (carpeta de salida), `ControlWindow` (última pantalla usada), `MenuBarController` (abrir la carpeta).

Consumidores previstos: casi todos los módulos. Cada fase que agregue un campo lo agrega al struct `Configuration` con su valor por defecto, para que un archivo viejo siga cargando.

Cuidado: los campos son opcionales a propósito. Nulo significa "todavía no se eligió", no "vacío".

## Registro (logging)

**Fase 0. Existe.** `Registro/Logger.swift`.

Un archivo por grabación en `~/Library/Logs/Grabador Bloomind/`, más uno general mientras no hay grabación. Conserva los últimos 20.

Consumidores actuales: `AppDelegate`, `ConfigurationStore`, `RecordingController`, `ScreenCapture`, `RecordingWriter`, `ControlWindow`, `ScreenRecordingPermission`.

Consumidores previstos: todos los módulos.

Regla de privacidad: se registra el evento, nunca el contenido. "Censura permanente activada" sí; qué había en pantalla o qué se tipeó en una anotación, jamás.
