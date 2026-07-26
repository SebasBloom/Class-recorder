# Interdependencias

Mapa de las piezas compartidas del proyecto, organizado por pieza y no por feature, para ver qué se puede romper al tocar cada cosa.

**Cómo se usa:** antes de modificar cualquier pieza de esta lista, se lee su entrada y se revisan todos sus consumidores. Cada vez que una pieza gana o pierde un consumidor, se actualiza acá.

**Estado:** cada pieza dice en qué fase nace. Las que dicen "pendiente" todavía no existen en el código.

## Conversión de coordenadas

**Fase 2. Pendiente.** Carpeta prevista: `Coordenadas/`.

Es la pieza más compartida del proyecto y se escribe una sola vez.

Consumidores: círculo de cursor, efecto de clic, JSON de cursor, capa de dibujo, tablero, censura, selector de rectángulo, burbuja de cámara.

Detalle crítico: origen abajo izquierda en eventos de mouse contra arriba izquierda en píxeles del frame; factor de escala Retina por display; con dos monitores cada display tiene su propio espacio de coordenadas y su propio factor de escala.

Si el círculo aparece desfasado, el bug está acá y solo acá.

## Tracking global del mouse

**Fase 2. Pendiente.** Carpeta prevista: `EntradaGlobal/`.

Posición y clics del mouse a nivel de sistema.

Consumidores: círculo de cursor, efecto de clic, JSON de cursor, y el motor de dibujo cuando hay un modo de dibujo activo.

## Motor de dibujo

**Fase 7. Pendiente.** Carpeta prevista: `Dibujo/`.

Trazos a mano alzada, cuadros de texto, paleta de colores, deshacer, borrar.

Consumidores: tablero (Fase 7) y capa de anotación sobre pantalla (Fase 8).

Regla: motor único, contenidos separados por superficie. Borrar una superficie nunca toca la otra.

## Selector de rectángulo en pantalla

**Fase 10. Pendiente.** Carpeta prevista: `UI/`.

Arrastrar para definir una zona de la pantalla.

Consumidores: slot de censura permanente, slot de censura de sesión (Fase 10), y grabación de área personalizada (Fase 11).

## Pipeline de composición de frames

**Fase 2. Pendiente.** Carpeta prevista: `Composicion/`.

Fondo según el modo activo más capas según la matriz de visibilidad de la sección 8.4 del plan.

Consume: conversión de coordenadas, tracking de mouse, motor de dibujo, censura, cámara.
Alimenta: el escritor de video.

Nace en la Fase 2 con una sola capa (el círculo), pero desde ya con la forma de la matriz completa.

## Escritor de video y audio

**Fase 1. Pendiente.** Carpeta prevista: `Escritura/`.

AVAssetWriter, fragmentos periódicos, pausa con desplazamiento de timestamps.

Lo alimentan: el pipeline de composición y las fuentes de audio.

Nace en la Fase 1 con la abstracción de sesión que contempla pausa, aunque la pausa real se implemente en la Fase 5, para no refactorizar después.

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

Consumidores actuales: `AppDelegate` (la carga al arrancar).

Consumidores previstos: casi todos los módulos. Cada fase que agregue un campo lo agrega al struct `Configuration` con su valor por defecto, para que un archivo viejo siga cargando.

Cuidado: los campos son opcionales a propósito. Nulo significa "todavía no se eligió", no "vacío".

## Registro (logging)

**Fase 0. Existe.** `Registro/Logger.swift`.

Un archivo por grabación en `~/Library/Logs/Grabador Bloomind/`, más uno general mientras no hay grabación. Conserva los últimos 20.

Consumidores actuales: `AppDelegate`, `ConfigurationStore`.

Consumidores previstos: todos los módulos.

Regla de privacidad: se registra el evento, nunca el contenido. "Censura permanente activada" sí; qué había en pantalla o qué se tipeó en una anotación, jamás.
