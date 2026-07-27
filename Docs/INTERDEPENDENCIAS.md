# Interdependencias

Mapa de las piezas compartidas del proyecto, organizado por pieza y no por feature, para ver qué se puede romper al tocar cada cosa.

**Cómo se usa:** antes de modificar cualquier pieza de esta lista, se lee su entrada y se revisan todos sus consumidores. Cada vez que una pieza gana o pierde un consumidor, se actualiza acá.

**Estado:** cada pieza dice en qué fase nace. Las que dicen "pendiente" todavía no existen en el código.

## Conversión de coordenadas

**Fase 2. Existe.** `Coordenadas/CoordinateConverter.swift`.

Es la pieza más compartida del proyecto y se escribe una sola vez.

Consumidores actuales: `FramePipeline`, que la usa para el círculo, los clics y el JSON.

Consumidores previstos: capa de dibujo, tablero, censura, selector de rectángulo y burbuja de cámara.

**Tiene la única prueba automática del proyecto** (`./probar.sh`), incluida la configuración de dos monitores con escalas distintas, que a mano es impráctica de verificar. Si se toca esta pieza, correr esa prueba antes de nada.

Detalle crítico: origen abajo izquierda en eventos de mouse contra arriba izquierda en píxeles del frame; factor de escala Retina por display; con dos monitores cada display tiene su propio espacio de coordenadas y su propio factor de escala.

Si el círculo aparece desfasado, el bug está acá y solo acá.

## Tracking global del mouse

**Fase 2. Existe.** `EntradaGlobal/MouseTracker.swift`.

Posición y clics del mouse a nivel de sistema.

Consumidores actuales: `FramePipeline`.

Consumidores previstos: el motor de dibujo, cuando haya un modo de dibujo activo (Fases 7 y 8).

Cuidado al tocarlo: la posición se guarda desde el hilo principal y se lee desde la cola de captura bajo candado. No consultar `NSEvent.mouseLocation` desde la cola de captura.

## Motor de dibujo

**Fase 7. Pendiente.** Carpeta prevista: `Dibujo/`.

Trazos a mano alzada, cuadros de texto, paleta de colores, deshacer, borrar.

Consumidores: tablero (Fase 7) y capa de anotación sobre pantalla (Fase 8).

Regla: motor único, contenidos separados por superficie. Borrar una superficie nunca toca la otra.

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

La matriz de visibilidad de la sección 8.4 está implementada tal cual en la función `isVisible(_:in:)`. Hoy solo existen las capas del círculo y el clic, y el modo siempre es `pantalla`, pero la matriz completa ya está escrita: cada fase que agregue una capa solo tiene que dibujarla, no decidir cuándo se ve.

Consume: conversión de coordenadas y tracking de mouse.
Alimenta: el escritor de video y el escritor del JSON de cursor.

Cuidado al tocarlo: dibuja dentro del mismo buffer de la captura, sin crear uno nuevo por frame. No cambiar eso sin leer la decisión 28.

## Escritor del JSON de cursor

**Fase 2. Existe.** `Escritura/CursorTrackWriter.swift`.

Escribe el `<mismo nombre>.cursor.json` que VideoFlow usa para el zoom automático.

Consumidores actuales: `FramePipeline`.

Cuidado al tocarlo: las coordenadas van en píxeles del video final y los tiempos en segundos del video final, descontando pausas. VideoFlow no sabe nada de macOS, ni de escalas, ni de pausas, y así tiene que seguir. Ya tiene el método para los eventos de cambio de modo, que se empieza a usar en la Fase 6.

## Escritor de video y audio

**Fase 1. Existe.** `Escritura/RecordingWriter.swift`.

AVAssetWriter en contenedor `.mov`, HEVC por hardware, fragmentos cada 5 segundos, y el desplazamiento de timestamps por pausa ya implementado.

Consumidores actuales: `RecordingController`, que le pasa los frames de la captura directo.

Consumidores previstos: el pipeline de composición (Fase 2, se mete en el medio) y las fuentes de audio (Fases 3 a 5).

Cuidado al tocarlo: `shouldOptimizeForNetworkUse` tiene que quedar apagado y `movieFragmentInterval` puesto, o se pierde la resistencia a fallos de la decisión 11. La perilla de calidad es `bitsPerPixel`, y vive solo acá.

La pista de audio todavía no existe: cuando llegue, el `startSession` tiene que seguir disparándose con el primer buffer que llegue de cualquier pista, no solo de video.

## Registro de acciones y atajos

**Fase 9. Pendiente.** Carpeta prevista: `EntradaGlobal/`.

Consumidores: todos los features operables con teclado, la pantalla de preferencias y la tarjeta de recordatorio.

Hasta la Fase 9 cada fase usa atajos fijos temporales, que se migran acá cuando la pieza nace.

## Enumeración de dispositivos

**Fases 3 y 6. Pendiente.** Carpetas previstas: `Audio/` y `Camara/`.

Patrón común para micrófonos (Fase 3) y cámaras (Fase 6): listas dinámicas que se actualizan en vivo al conectar o desconectar, con la resiliencia de la sección 5 del plan.

Aunque son dos módulos, comparten patrón: si cambia el manejo de desconexión en uno, se revisa el otro.

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
