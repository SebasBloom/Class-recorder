# Grabador Bloomind: manual de uso

Este documento explica qué es la app, cómo instalarla y cómo usarla de principio a fin. Está escrito para usarse sin saber nada de programación. Corresponde a la versión 1 del grabador.

## Qué es

Una app propia de Bloomind para grabar tutoriales y clases desde el Mac. Graba la pantalla que elijas con un círculo amarillo que resalta el cursor, mezcla tu voz con el sonido del computador, muestra tu cámara en una burbuja, y tiene tablero y marcador para explicar encima de lo que estás mostrando. El video sale terminado al detener la grabación, sin edición posterior para nada de eso.

Todo funciona local. La app no se conecta a internet para nada, no sube nada a ningún lado y no manda datos a nadie. Lo que grabás queda en tu Mac y solo ahí.

## Requisitos

- macOS 15 (Sequoia) o más nuevo.
- Espacio libre en disco: para una clase de una hora, calculá que el archivo puede pesar varios GB. La app te avisa si el espacio se está acabando.

## Instalación

La app no viene del App Store, así que la primera vez macOS la bloquea por seguridad. Es normal y se resuelve una sola vez:

1. Copiá el archivo de la app (termina en .app) a tu carpeta de Aplicaciones.
2. Hacé doble clic. Va a salir un aviso diciendo que no se puede abrir.
3. Andá a Configuración del Sistema, luego Privacidad y seguridad, bajá hasta el final y tocá "Abrir de todos modos".
4. Confirmá. De ahí en adelante abre normal.

## Permisos que va a pedir

La app necesita cuatro permisos de macOS. Te los va pidiendo la primera vez que usás cada función, con un mensaje que dice cuál falta y te lleva al lugar exacto para activarlo:

- **Grabación de pantalla y audio del sistema**: para poder grabar lo que se ve y lo que suena.
- **Micrófono**: para tu voz.
- **Cámara**: para la burbuja con tu cara.
- **Accesibilidad**: para seguir la posición del mouse y que funcionen los atajos de teclado.

Aviso importante: macOS le pide a las apps que no vienen del App Store confirmar el permiso de grabación de pantalla más o menos una vez al mes. Un día la app te va a volver a pedir ese permiso aunque ya lo habías dado. No se dañó nada, es una regla de Apple. Lo aceptás de nuevo y seguís.

## La app vive en la barra de menú

No aparece en el Dock. Buscá su ícono arriba a la derecha, en la barra de menú, junto al reloj. El ícono cambia según el estado: inactivo, grabando o en pausa. Desde ahí hacés todo: iniciar, detener, abrir la carpeta de grabaciones, preferencias y salir.

## Antes de grabar: el panel de configuración

Al tocar "Iniciar grabación" se abre un panel con todo lo que hay que decidir:

- **Qué pantalla grabar**, si tenés más de una. También podés grabar solo un pedazo de la pantalla dibujando un rectángulo.
- **Audio**: solo tu micrófono, solo el sonido del sistema, o los dos mezclados. Abajo elegís cuál micrófono usar. Ahí aparecen todos los que el Mac vea en ese momento: el integrado, AirPods, o el iPhone si está cerca y desbloqueado (así entra el DJI Mic conectado al teléfono). Hay un medidor que se mueve cuando el micrófono capta sonido: revisalo antes de arrancar, te salva de grabar una hora muda.
- **Cámara**: elegí entre las que estén disponibles, incluida la del iPhone.
- **Nombre de la sesión**: ponele nombre a la grabación (por ejemplo "Clase Supabase parte 1") para encontrarla fácil después.
- **Carpeta de destino**: dónde se guarda el video.

La app recuerda lo último que elegiste en todo. La segunda vez que grabes, el panel ya viene configurado como la vez anterior.

Al confirmar, cuenta 3, 2, 1 y arranca.

## Durante la grabación

Aparece un widget flotante chiquito que podés arrastrar a donde no moleste. Muestra el tiempo, el estado, el modo activo y un indicador cuando la censura está tapando algo. Tiene botones para pausar, detener, reiniciar la toma y prender o apagar la burbuja de cámara. Ni el widget ni ninguna ventana de la app salen en el video, tranquilo.

Lo demás se maneja con atajos de teclado. Los importantes:

| Qué hace | Teclas |
|---|---|
| Iniciar o detener la grabación | Control Opción Comando G |
| Ver la pantalla | Opción Comando 1 |
| Verte solo a vos en cámara completa | Opción Comando 2 |
| Tablero blanco para explicar | Opción Comando 3 |
| Pausar y reanudar | Opción Comando P |
| Reiniciar la toma | Opción Comando R |
| Tapar o destapar la censura fija | Opción Comando C |
| Tapar o destapar la censura de esta sesión | Opción Comando X |
| Prender o apagar el marcador sobre la pantalla | Opción Comando D |
| Cambiar el color del marcador | Opción Comando 0 |
| Deshacer el último trazo | Opción Comando Z |
| Borrar lo dibujado en la superficie activa | Opción Comando Delete |
| Recordatorio de todos los atajos | Mantener Opción Comando / |

Si se te olvida alguno a mitad de clase, mantené presionado Opción Comando / y aparece una tarjeta con la lista completa. Se esconde al soltar y no queda en el video. Todos los atajos se pueden cambiar en Preferencias.

### Los tres modos

Con los atajos 1, 2 y 3 saltás entre mostrar la pantalla, mostrarte a vos en grande, o un tablero blanco. El cambio es instantáneo y la grabación no se corta ni pierde el audio. Típico flujo de clase: mostrás cómo se abre n8n en modo pantalla, saltás a cámara completa para explicar qué es, pasás al tablero para dibujar el concepto, y volvés a la pantalla a seguir con la demo.

### Censura, para tapar cosas sensibles

Sirve para tapar en el video cosas como la dirección del VPS en el navegador. Hay dos:

- **La fija** (Opción Comando C): la primera vez te deja dibujar un rectángulo sobre lo que querés tapar. Queda guardada para siempre: mañana abrís la app y el mismo atajo tapa esa misma zona sin dibujar nada. Para reubicarla, apretá Shift junto con el atajo.
- **La de sesión** (Opción Comando X): igual, pero se olvida al cerrar la app. Para tapadas de una sola vez.

La zona tapada sale en el video como un bloque sólido. En tu pantalla ves el bloque también, así sabés qué está tapado. El widget muestra un indicador cuando hay censura activa, para que nunca dudes si estás protegido o no.

### Dibujar y escribir

- **Sobre la pantalla real** (Opción Comando D): se activa una capa donde podés rayar con el mouse como marcador y hacer clic para escribir texto con el teclado. Mientras la capa está prendida, el mouse dibuja en vez de controlar la app de abajo. La apagás con el mismo atajo para seguir usando el computador, y lo que dibujaste no se borra: queda guardado y reaparece si la prendés de nuevo. Borrar es aparte, con Opción Comando Delete, a propósito.
- **En el tablero** (Opción Comando 3): lienzo blanco con las mismas herramientas. Lo que dibujás en el tablero y lo que dibujás sobre la pantalla son independientes: borrar uno no toca el otro.
- El marcador tiene cinco colores (rojo, amarillo, verde, blanco, negro) y se rotan con Opción Comando 0. El color activo se ve en el widget.

### Pausar y reiniciar

- **Pausar** (Opción Comando P): congela la grabación. Al reanudar, el video sigue como si la pausa no hubiera existido, sin hueco.
- **Reiniciar toma** (Opción Comando R): descarta lo que llevás y arranca de cero con la misma configuración, para cuando arrancaste mal y preferís repetir. La toma descartada no se destruye: va a la Papelera de macOS, por si te arrepentís.

## Al terminar

Detené con el widget, el menú o el atajo. Sale una notificación con el nombre del archivo y acceso directo a la carpeta. Por defecto todo queda en la carpeta Películas, dentro de "Grabador Bloomind", con nombres como `2026-07-26 14h30 - Clase Supabase parte 1.mov`.

El `.mov` es el formato de video de QuickTime: se abre con doble clic igual que cualquier video, y se puede subir a YouTube, mandar por Drive o editar sin convertirlo a nada.

Junto a cada video vas a ver un archivo con el mismo nombre terminado en `.cursor.json`. No lo borres si el video va a pasar por VideoFlow: ahí está guardado el recorrido del mouse y los clics, y VideoFlow lo usa para el zoom automático en la edición. Si el video no se va a editar, se puede borrar sin problema.

## Si algo falla

- **La app pide un permiso otra vez**: normal, sobre todo el de pantalla una vez al mes. Aceptalo y seguí.
- **No aparece tu micrófono o cámara en la lista**: revisá que el aparato esté prendido y conectado. Si es el iPhone, que esté cerca y desbloqueado. La lista se actualiza sola al conectar.
- **Se desconectó el micrófono o la cámara a mitad de grabación** (se acabó la batería, se bloqueó el teléfono): la app te avisa en pantalla y la grabación sigue con lo que quede. El video no se pierde.
- **Se cerró la app o se apagó el Mac a mitad de grabación**: el video no se pierde completo. El archivo queda reproducible hasta segundos antes del corte. Al volver a abrir la app, ella misma detecta que quedó una grabación interrumpida y te ofrece llevarte al archivo.
- **Aviso de espacio en disco**: liberá espacio antes de grabar. Si el disco se llega a poner crítico durante una grabación, la app la detiene sola de forma segura, guardando lo grabado hasta ahí.
- **Algo raro que no entendés**: la app guarda un registro de cada grabación en la carpeta de logs (desde el menú de la app se llega). Pasale ese archivo a Sebas o a Claude Code y con eso se diagnostica qué pasó, sin tener que repetir la falla.
- **Reset total**: si la app queda en un estado raro, cerrala y borrá el archivo de configuración en la carpeta Application Support del usuario, subcarpeta "Grabador Bloomind". Al abrirla de nuevo arranca de fábrica. Perdés los atajos personalizados y la posición de la censura fija, nada más. Los videos nunca se tocan.

## Preguntas rápidas

**Puedo usar el computador normal mientras grabo?** Sí. La grabación captura la pantalla que elegiste. Solo tené en cuenta que si el marcador está prendido, el mouse dibuja en vez de hacer clic; apagalo con Opción Comando D para volver a controlar las apps.

**Se puede grabar más de una hora?** Sí. Vigilá el aviso de espacio en disco y listo.

**El video sale ya con el círculo del cursor, la censura y los dibujos?** Sí, todo eso queda quemado en el archivo final. No hay que editarlo para eso. La edición en VideoFlow es aparte y opcional (subtítulos, cortes de silencio, zoom).

**Dónde cambio los atajos?** Menú de la app, Preferencias. Clic sobre la combinación que quieras cambiar y apretá la nueva. La app avisa si choca con otro atajo de la misma app.
