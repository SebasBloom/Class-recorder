# Grabador Bloomind: manual de uso

Este documento explica qué es la app, cómo instalarla y cómo usarla de principio a fin. Está escrito para usarse sin saber nada de programación. Corresponde a la versión 1 del grabador.

## Qué es

Una app propia de Bloomind para grabar tutoriales y clases desde el Mac. Graba la pantalla que elijas con un círculo amarillo que resalta el cursor, mezcla tu voz con el sonido del computador, muestra tu cámara en una burbuja, y tiene tablero y marcador para explicar encima de lo que estás mostrando. El video sale terminado al detener la grabación, sin edición posterior para nada de eso.

Todo funciona local. La app no se conecta a internet para nada, no sube nada a ningún lado y no manda datos a nadie. Lo que grabás queda en tu Mac y solo ahí.

## Requisitos

- Mac con chip Apple (M1, M2, M3 o más nuevo). En los Mac viejos con procesador
  Intel la app no abre. Para saberlo: menú Apple → Acerca de esta Mac; donde dice
  "Chip" tiene que aparecer un M.
- macOS 15 (Sequoia) o más nuevo.
- Espacio libre en disco: para una clase de una hora, calculá que el archivo puede pesar varios GB. La app te avisa si el espacio se está acabando.

## Instalación

Te va a llegar un archivo llamado `Grabador Bloomind.zip`. No hace falta terminal, ni cuenta de nada, ni instalar programas: son cuatro pasos y se hacen una sola vez.

1. **Descargá el zip y hacele doble clic.** Se descomprime solo y aparece `Grabador Bloomind.app` al lado.
2. **Arrastrá esa app a tu carpeta Aplicaciones.** Importante: usala desde ahí, no desde Descargas.
3. **Hacé doble clic.** La primera vez macOS te va a decir que no se puede abrir porque no viene del App Store. Es lo esperado, no está dañada.
4. **Andá a Configuración del Sistema → Privacidad y seguridad**, bajá hasta el final y vas a ver un mensaje sobre el Grabador con un botón **"Abrir de todos modos"**. Tocalo y confirmá.

De ahí en adelante abre normal con doble clic, y no vuelve a preguntar.

Un detalle que ahorra un susto: la app **no abre ninguna ventana** al arrancar. Aparece como un ícono chiquito arriba a la derecha, en la barra de menú junto al reloj. Si hiciste doble clic y "no pasó nada", mirá ahí arriba.

### Cuando llegue una versión nueva

Mismo procedimiento, pero antes **salí de la app** (ícono de la barra de menú, Salir) y reemplazá la de Aplicaciones por la nueva. Los permisos y tus atajos personalizados se mantienen, no hay que configurar nada de nuevo.

## Permisos que va a pedir

La app necesita tres permisos de macOS. Te los va pidiendo la primera vez que usás cada función, con un mensaje que dice cuál falta y te lleva al lugar exacto para activarlo:

- **Grabación de pantalla y audio del sistema**: para poder grabar lo que se ve y lo que suena.
- **Micrófono**: para tu voz.
- **Cámara**: para la burbuja con tu cara.

No pide Accesibilidad, que es el permiso más invasivo de macOS y el que deja leer todo lo que tecleás. Los atajos están hechos de una forma que no lo necesita.

Aviso importante: macOS le pide a las apps que no vienen del App Store confirmar el permiso de grabación de pantalla más o menos una vez al mes. Un día la app te va a volver a pedir ese permiso aunque ya lo habías dado. No se dañó nada, es una regla de Apple. Lo aceptás de nuevo y seguís.

## La app vive en la barra de menú

No aparece en el Dock. Buscá su ícono arriba a la derecha, en la barra de menú, junto al reloj. El ícono cambia según el estado: inactivo, grabando o en pausa. Desde ahí hacés todo: iniciar, detener, abrir la carpeta de grabaciones, preferencias y salir.

## Antes de grabar: el panel de configuración

Al tocar "Iniciar grabación" se abre un panel con todo lo que hay que decidir:

- **Qué pantalla grabar**, si tenés más de una. También podés grabar solo un pedazo de la pantalla dibujando un rectángulo.
- **Audio**: solo tu micrófono, solo el sonido del sistema, o los dos mezclados. Si elegís los dos, la app baja sola el sonido del computador mientras estás hablando y lo devuelve a su nivel cuando callás, para que tu explicación siempre quede por encima del video que estés mostrando.

  > **Si vas a grabar los dos audios, poneté audífonos.** No es una recomendación de estilo: si el sonido sale por los parlantes, tu micrófono también los escucha y todo lo que suene en el computador queda grabado dos veces, con unos milisegundos de diferencia. Se oye como un eco. Está medido en la Mac de Sebas: con los parlantes sonando, el micrófono captaba el video casi tan fuerte como la propia captura; con el volumen bajo, el mismo micrófono quedaba 40 dB más limpio. Le pasa a cualquier grabador, no es un defecto de este. Con audífonos desaparece por completo. Abajo elegís cuál micrófono usar. Ahí aparecen todos los que el Mac vea en ese momento: el integrado, AirPods, o el iPhone si está cerca y desbloqueado (así entra el DJI Mic conectado al teléfono). Hay un medidor que se mueve cuando el micrófono capta sonido: revisalo antes de arrancar, te salva de grabar una hora muda.
- **Cámara**: elegí entre las que estén disponibles, incluida la del iPhone.
- **Nombre de la sesión**: ponele nombre a la grabación (por ejemplo "Clase Supabase parte 1") para encontrarla fácil después.
- **Carpeta de destino**: dónde se guarda el video.

La app recuerda lo último que elegiste en todo. La segunda vez que grabes, el panel ya viene configurado como la vez anterior.

Al confirmar, cuenta 3, 2, 1 y arranca.

## Durante la grabación

Aparece un widget flotante chiquito que podés arrastrar a donde no moleste. Muestra el tiempo, el estado, el modo activo, un indicador cuando la censura está tapando algo y otro cuando silenciaste algún audio. Tiene botones para pausar, detener, reiniciar la toma, manejar la cámara y silenciar el micrófono o el sonido del computador. Ni el widget ni ninguna ventana de la app salen en el video, tranquilo.

Lo demás se maneja con atajos de teclado. Los importantes:

| Qué hace | Teclas |
|---|---|
| Iniciar o detener la grabación | Control Opción Comando G |
| Ver la pantalla | Opción Comando 1 |
| Verte solo a vos en cámara completa | Opción Comando 2 |
| Tablero para explicar | Opción Comando 3 |
| Pausar y reanudar | Opción Comando P |
| Reiniciar la toma | Opción Comando R |
| Tapar o destapar la censura | Opción Comando C |
| Redibujar la zona de censura | Shift Opción Comando C |
| Prender o apagar el marcador sobre la pantalla | Opción Comando D |
| Cambiar el color del marcador | Opción Comando 0 |
| Tablero blanco o negro | Opción Comando B |
| Silenciar o activar tu micrófono | Opción Comando M |
| Silenciar o activar el sonido del computador | Opción Comando S |
| Deshacer el último trazo | Opción Comando Z |
| Borrar lo dibujado en la superficie activa | Opción Comando borrar |
| Recordatorio de todos los atajos | Mantener Opción Comando H |

Si se te olvida alguno a mitad de clase, mantené presionado Opción Comando H y aparece una tarjeta con la lista completa. Se esconde al soltar y no queda en el video. Todos los atajos se pueden cambiar en Preferencias.

### Los tres modos

Con los atajos 1, 2 y 3 saltás entre mostrar la pantalla, mostrarte a vos en grande, o un tablero para dibujar. El tablero puede ser blanco o negro, y se cambia en vivo con Opción Comando B. El cambio es instantáneo y la grabación no se corta ni pierde el audio. Típico flujo de clase: mostrás cómo se abre n8n en modo pantalla, saltás a cámara completa para explicar qué es, pasás al tablero para dibujar el concepto, y volvés a la pantalla a seguir con la demo.

### Censura, para tapar cosas sensibles

Sirve para tapar en el video cosas como la dirección del VPS en el navegador.

Con **Opción Comando C**, la primera vez se oscurece la pantalla y arrastrás un rectángulo sobre lo que querés tapar. De ahí en adelante el mismo atajo tapa y destapa al instante. Para mover la zona a otro lado, **Shift Opción Comando C**.

La zona vive mientras la app esté abierta. Si la cerrás y volvés, hay que dibujarla de nuevo: es a propósito, así no queda guardado en ningún archivo qué es lo que estabas escondiendo.

**Ojo con esto, que es lo que más confunde:** la censura tapa **el video, no tu pantalla**. Vos vas a seguir viendo tu barra de direcciones normal mientras el archivo la tiene tapada. Para saber si está activa, mirá el widget: dice **▓ censura** cuando hay algo tapado. Esa es la única señal, y es confiable.

### Dibujar y escribir

- **Sobre la pantalla real** (Opción Comando D): se activa una capa donde podés rayar con el mouse como marcador y hacer clic para escribir texto con el teclado. Mientras la capa está prendida, el mouse dibuja en vez de controlar la app de abajo. La apagás con el mismo atajo para seguir usando el computador, y lo que dibujaste no se borra: queda guardado y reaparece si la prendés de nuevo. Borrar es aparte, con Opción Comando borrar, a propósito.
- **En el tablero** (Opción Comando 3): lienzo entero con las mismas herramientas. Lo que dibujás en el tablero y lo que dibujás sobre la pantalla son independientes: borrar uno no toca el otro.
- El marcador tiene cinco colores (rojo, amarillo, verde, blanco, negro) y se rotan con Opción Comando 0. El color activo se ve en el widget, y también en un círculo arriba a la derecha mientras estás en el tablero. Sobre el tablero se saltea solo el color que no se vería: el blanco en tablero blanco, el negro en tablero negro.

### Cambiar el audio y la cámara sin cortar la grabación

No todo queda congelado cuando arrancás. En mitad de la clase podés:

- **Callar tu micrófono** con Opción Comando M, para toser, atender una llamada o dejar que se oiga solo el video que estás mostrando. Volvés a apretar y sigue.
- **Callar el sonido del computador** con Opción Comando S, para que una notificación o un video de fondo no se metan en la clase.
- **Prender, cambiar o apagar la cámara** desde el botón de cámara del widget. Ahí se despliega la lista de las que tengas disponibles. Podés prender la cámara aunque hayas arrancado a grabar sin ninguna: lo grabado antes queda sin burbuja y de ahí en adelante aparece.

El widget muestra bien visible qué está silenciado, para que no se te pase. Podés dejar las dos cosas calladas a la vez si querés un tramo mudo.

Lo único que **no** se puede es al revés: si arrancaste eligiendo "solo el sonido del sistema", el micrófono no se puede sumar después. Es a propósito: la app solo abre tu micrófono si vos lo pediste antes de empezar, y no lo deja abierto "por si acaso".

### Pausar y reiniciar

- **Pausar** (Opción Comando P): congela la grabación. Al reanudar, el video sigue como si la pausa no hubiera existido, sin hueco.
- **Reiniciar toma** (Opción Comando R, o el botón del widget): descarta lo que llevás y arranca de cero con la misma configuración, para cuando arrancaste mal y preferís repetir. Pregunta antes de hacerlo. La toma descartada no se destruye: va a la Papelera de macOS, por si te arrepentís.

## Al terminar

Detené con el widget, el menú o el atajo. Sale una notificación con el nombre del archivo y acceso directo a la carpeta. Por defecto todo queda en la carpeta Películas, dentro de "Grabador Bloomind", con nombres como `2026-07-26 14h30 - Clase Supabase parte 1.mov`.

El `.mov` es el formato de video de QuickTime: se abre con doble clic igual que cualquier video, y se puede subir a YouTube, mandar por Drive o editar sin convertirlo a nada.

Junto a cada video vas a ver un archivo con el mismo nombre terminado en `.cursor.json`. No lo borres si el video va a pasar por VideoFlow: ahí está guardado el recorrido del mouse y los clics, y VideoFlow lo usa para el zoom automático en la edición. Si el video no se va a editar, se puede borrar sin problema.

## Si algo falla

- **El audio del sistema suena como con eco, o doble**: estás grabando los dos audios con los parlantes prendidos, y tu micrófono está oyendo los parlantes. **Poneté audífonos y desaparece.** Si no tenés a mano, callá tu micrófono (Opción Comando M) mientras no estés hablando.
- **Grabaste con "los dos audios" y tu voz quedó por debajo del video**: la app baja sola el sonido del computador mientras hablás y lo sube cuando callás, así que esto no debería pasarte. Si igual te queda bajo, casi siempre es el micrófono: el interno del MacBook capta flojo y lejos. Con el DJI por el iPhone la diferencia es enorme, está medida: 34 dB menos de ruido de fondo.
- **La app pide un permiso otra vez**: normal, sobre todo el de pantalla una vez al mes. Aceptalo y seguí.
- **No aparece tu micrófono o cámara en la lista**: revisá que el aparato esté prendido y conectado. Si es el iPhone, que esté cerca y desbloqueado. La lista se actualiza sola al conectar.
- **Se desconectó el micrófono o la cámara a mitad de grabación** (se acabó la batería, se bloqueó el teléfono): la app te avisa en pantalla y la grabación sigue con lo que quede. El video no se pierde.
- **Se cerró la app o se apagó el Mac a mitad de grabación**: el video no se pierde completo. El archivo queda reproducible hasta segundos antes del corte. Al volver a abrir la app, ella misma detecta que quedó una grabación interrumpida y te ofrece llevarte al archivo.
- **Aviso de espacio en disco**: liberá espacio antes de grabar. Si el disco se llega a poner crítico durante una grabación, la app la detiene sola de forma segura, guardando lo grabado hasta ahí.
- **Algo raro que no entendés**: la app guarda un registro de cada grabación en la carpeta de logs (desde el menú de la app se llega). Pasale ese archivo a Sebas o a Claude Code y con eso se diagnostica qué pasó, sin tener que repetir la falla.
- **Reset total**: si la app queda en un estado raro, cerrala y borrá el archivo de configuración en la carpeta Application Support del usuario, subcarpeta "Grabador Bloomind". Al abrirla de nuevo arranca de fábrica. Perdés los atajos personalizados y lo que hayas configurado en el panel, nada más. Los videos nunca se tocan.

## Preguntas rápidas

**Puedo usar el computador normal mientras grabo?** Sí. La grabación captura la pantalla que elegiste. Solo tené en cuenta que si el marcador está prendido, el mouse dibuja en vez de hacer clic; apagalo con Opción Comando D para volver a controlar las apps.

**Se puede grabar más de una hora?** Sí. Vigilá el aviso de espacio en disco y listo.

**El video sale ya con el círculo del cursor, la censura y los dibujos?** Sí, todo eso queda quemado en el archivo final. No hay que editarlo para eso. La edición en VideoFlow es aparte y opcional (subtítulos, cortes de silencio, zoom).

**Dónde cambio los atajos?** Menú de la app, Preferencias. Clic sobre la combinación que quieras cambiar y apretá la nueva. La app avisa si choca con otro atajo de la misma app.
