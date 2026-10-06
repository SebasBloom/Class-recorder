# Grabador Bloomind: manual de uso

Este documento explica qué es la app, cómo instalarla y cómo usarla de principio a fin. Está escrito para usarse sin saber nada de programación. Corresponde a la versión 2 del grabador (octubre de 2026), la del diseño nuevo.

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

No aparece en el Dock. Buscá su ícono arriba a la derecha, en la barra de menú, junto al reloj. El ícono cambia según el estado: inactivo, grabando o en pausa. Desde ahí hacés todo: iniciar, detener, abrir la carpeta de grabaciones, cambiar los atajos, ver el tutorial y salir. Mientras grabás, al lado del ícono ves el tiempo corriendo con un punto azul (gris si está en pausa).

## El tutorial

La primera vez que abrís la app sale sola una guía: la pantalla se oscurece y se va iluminando cada parte, con una burbuja que te explica qué es y qué tocar. En la mitad te pide hacer una grabación de práctica, que al terminar se va sola a la Papelera, así que podés tocar todo sin miedo.

Cuando quieras repasar algo, tocá **«¿Cómo se usa?»**, arriba a la derecha del panel o en el menú del ícono. Podés hacerla entera o ir directo a la parte de grabar. Este manual cuenta lo mismo con más detalle, por si preferís leerlo.

## Antes de grabar: el panel

Al tocar «Iniciar grabación…» se abre el panel. Arriba, en letra grande, va el **nombre de la grabación**: tocalo y escribí cómo se llama (por ejemplo «Clase Supabase parte 1»). Con ese nombre se guarda el archivo.

Debajo hay **una frase que dice qué se va a grabar**, por ejemplo: «Voy a grabar la pantalla entera del Retina, con el micrófono DJI y la cámara FaceTime, leyendo 2 guiones». **Cada parte en azul se toca y abre sus opciones:**

- **«la pantalla entera»**: o la pantalla entera, o «Un área…», que te deja dibujar con el mouse el rectángulo que querés grabar.
- **El nombre de la pantalla**: si tenés más de un monitor, cuál.
- **El micrófono**: qué se oye (solo tu micrófono, tu micrófono y el sonido del computador, solo el sonido del computador, o nada) y cuál micrófono usar. Ahí aparecen todos los que el Mac vea en ese momento: el integrado, AirPods, o el iPhone si está cerca y desbloqueado (así entra el DJI Mic conectado al teléfono). **La rayita debajo del nombre del micrófono se mueve con tu voz**: miralo antes de arrancar, te salva de grabar una hora muda. Si grabás los dos audios, la app baja sola el sonido del computador mientras hablás y lo sube cuando callás.

  > **Si vas a grabar los dos audios, poneté audífonos.** Si el sonido sale por los parlantes, tu micrófono también los escucha y todo lo que suena en el computador queda grabado dos veces, con unos milisegundos de diferencia: se oye como un eco. Está medido en la Mac de Sebas: con los parlantes sonando, el micrófono captaba el video casi tan fuerte como la propia captura. Con audífonos desaparece por completo.
- **La cámara**: elegí entre las disponibles, incluida la del iPhone, o «Sin cámara». Al elegirla aparece tu cara en un recuadro: arrastralo y agrandalo desde una esquina, así va a salir en el video.
- **Los guiones**: abre un globo para el teleprompter. Podés escribir el texto ahí mismo o traer uno o varios con **«Cargar archivos…»** desde un Word, un texto o un RTF. Si tu guion está en Google Docs, bajalo primero con Archivo → Descargar → Word (.docx): la app no se conecta a internet, así que no puede ir a buscarlo sola. Cada archivo cargado tiene su casilla: desmarcalo y no se usa en esta clase, sin perderlo. Ahí también están la velocidad y el tamaño de letra con que arranca, y el interruptor **«Fondo oscuro»** (ver el teleprompter más abajo).

Debajo de la frase, la **carpeta** donde se guarda (con «Cambiar…») y el interruptor de la **cuenta regresiva** 3, 2, 1, que no queda en el video.

Abajo de todo, la app te dice si **está todo listo** (punto turquesa) o si falta algo: en ámbar lo que conviene saber (los AirPods graban con calidad de teléfono, el video va a salir sin sonido), en rojo lo que impide grabar bien. Si falta el permiso del micrófono, el botón de grabar se vuelve **«Dar permiso al micrófono»** y te lleva al lugar exacto.

La app recuerda todo lo que elegiste. La segunda vez que grabes, el panel ya viene como lo dejaste.

Tocá **Grabar**: cuenta 3, 2, 1 y arranca.

## Durante la grabación

Arriba a la derecha aparece **la cápsula**: una barra blanca con todo lo de la grabación. Se arrastra desde cualquier parte que no sea un botón. Ni la cápsula ni ninguna ventana de la app salen en el video, tranquilo.

A la izquierda está el **tiempo**, y debajo una frase que dice qué estás grabando («Grabando el tablero negro · marcador amarillo») y lo que no se ve en tu pantalla, como «sin cursor».

**Siempre a la vista**, cada uno con su nombre debajo: **Pausar**, **Detener**, **Reiniciar**, **Micrófono**, **Sonido PC** y **Cámara**.

**Cuatro botones con flechita** abren un menú chico con el atajo escrito al lado de cada cosa:

- **Qué se ve**: tu pantalla, vos en cámara completa, o el tablero.
- **Tablero**: pasar al tablero, lienzo blanco o negro, deshacer y borrar.
- **Sobre la pantalla**: el círculo del cursor, el marcador y su color, la censura y redibujar la zona censurada.
- **La flechita de Guion**: los controles del teleprompter. El botón «Guion» de al lado lo muestra y lo esconde.

**Algunos botones aparecen solos cuando sirven:** en el tablero, Lienzo, Deshacer y Borrar; con el guion a la vista, su pausa.

**Lo grave se ve grande.** Si callaste el micrófono o el sonido, o la censura está tapando algo, sale una **pastilla roja grande** debajo de la cápsula que lo dice («Micrófono mudo», «Censura puesta»). Tocala y se deshace.

**Achicar**, el último botón, deja solo el tiempo en una pastilla chiquita. Tocala y vuelve todo. Si hay una alerta, la pastilla se pone roja entera.

Los botones te siguen funcionando aunque tengas el marcador o el tablero prendidos, que es cuando el mouse está ocupado dibujando: la cápsula queda por encima. Lo único: si dibujás justo debajo de ella, no vas a ver ese pedazo del trazo en tu pantalla, aunque en el video sí queda. La movés y listo.

Si la cápsula te tapa algo justo cuando lo estás mostrando, **Opción Comando W** la esconde y la trae de vuelta. Los atajos siguen funcionando con la cápsula escondida.

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
| Mostrar u ocultar el teleprompter | Opción Comando T |
| Prender o apagar el círculo del cursor | Opción Comando A |
| Cambiar el color del marcador | Opción Comando 0 |
| Tablero blanco o negro | Opción Comando B |
| Silenciar o activar tu micrófono | Opción Comando M |
| Silenciar o activar el sonido del computador | Opción Comando S |
| Deshacer el último trazo | Opción Comando Z |
| Borrar lo dibujado en la superficie activa | Opción Comando borrar |
| Recordatorio de todos los atajos | Mantener Opción Comando H |

Si se te olvida alguno a mitad de clase, mantené presionado Opción Comando H y aparece una tarjeta con la lista completa. Se esconde al soltar y no queda en el video. Todos los atajos se pueden cambiar desde el ícono de la barra de menú, en «Atajos…».

### Los tres modos

Con los atajos 1, 2 y 3 saltás entre mostrar la pantalla, mostrarte a vos en grande, o un tablero para dibujar. El tablero puede ser blanco o negro, y se cambia en vivo con Opción Comando B. El cambio es instantáneo y la grabación no se corta ni pierde el audio. Típico flujo de clase: mostrás cómo se abre n8n en modo pantalla, saltás a cámara completa para explicar qué es, pasás al tablero para dibujar el concepto, y volvés a la pantalla a seguir con la demo.

### El círculo del cursor se puede apagar

El círculo amarillo que sigue al mouse y la ondita que sale al hacer clic se pueden apagar en mitad de la grabación con **Opción Comando A**, o desde «Sobre la pantalla» en la cápsula. Se apagan y se prenden los dos juntos.

Sirve para los tramos donde lo que importa es lo que se ve en pantalla y no dónde está el mouse: leer un documento, mostrar un diseño, dejar corriendo un video. Volvés a apretar y vuelven.

Como el círculo no está en tu pantalla sino solo en el video, la cápsula te avisa: con el círculo apagado, la frase de abajo del tiempo dice «sin cursor».

Dos cosas que conviene saber. La primera: se recuerda como lo hayas dejado, así que si lo apagás, la próxima grabación arranca apagado. La segunda: apagar el círculo **no** afecta al zoom automático de VideoFlow. El recorrido del mouse se sigue guardando igual en el archivo `.cursor.json`, así que podés grabar sin círculo y que la edición te haga el zoom lo mismo.

### Censura, para tapar cosas sensibles

Sirve para tapar en el video cosas como la dirección del VPS en el navegador.

Con **Opción Comando C**, la primera vez se oscurece la pantalla y arrastrás un rectángulo sobre lo que querés tapar. De ahí en adelante el mismo atajo tapa y destapa al instante. Para mover la zona a otro lado, **Shift Opción Comando C**.

La zona vive mientras la app esté abierta. Si la cerrás y volvés, hay que dibujarla de nuevo: es a propósito, así no queda guardado en ningún archivo qué es lo que estabas escondiendo.

**Ojo con esto, que es lo que más confunde:** la censura tapa **el video, no tu pantalla**. Vos vas a seguir viendo tu barra de direcciones normal mientras el archivo la tiene tapada. Para saber si está activa, mirá debajo de la cápsula: mientras hay algo tapado sale la pastilla roja **«Censura puesta»**. Esa es la señal, y es confiable.

### Dibujar y escribir

- **Sobre la pantalla real** (Opción Comando D): se activa una capa donde podés rayar con el mouse como marcador y hacer clic para escribir texto con el teclado. Mientras la capa está prendida, el mouse dibuja en vez de controlar la app de abajo. La apagás con el mismo atajo para seguir usando el computador, y lo que dibujaste no se borra: queda guardado y reaparece si la prendés de nuevo. Borrar es aparte, con Opción Comando borrar, a propósito.
- **En el tablero** (Opción Comando 3): lienzo entero con las mismas herramientas. Lo que dibujás en el tablero y lo que dibujás sobre la pantalla son independientes: borrar uno no toca el otro.
- El marcador tiene cinco colores (rojo, amarillo, verde, blanco, negro) y se rotan con Opción Comando 0. El color activo se ve en el puntito al lado del tiempo de la cápsula, y también en un círculo arriba a la derecha mientras estás en el tablero. Sobre el tablero se saltea solo el color que no se vería: el blanco en tablero blanco, el negro en tablero negro.

### El teleprompter, para leer el guion mientras grabás

Una ventana con tu texto pasando solo, para no perder el hilo. **No sale en el video**: la ves vos y nadie más, igual que la cápsula.

Si dejaste el guion cargado en el panel, **aparece sola al empezar a grabar**: no tenés que pedirle nada. Si el campo del guion está vacío, no aparece. En cualquier momento la prendés y la apagás con **Opción Comando T** o con el botón «Guion» de la cápsula. Funciona en los tres modos, así que la podés tener mientras mostrás la pantalla, mientras estás en cámara completa o sobre el tablero.

El texto lo dejás cargado antes de grabar, en el panel de configuración. **Podés cargar varios guiones de una** —intro, desarrollo, cierre— y cambiar entre ellos con las pestañas de arriba del teleprompter, sin parar la grabación. Y si a mitad de clase necesitás otro texto, el teleprompter tiene un botón de **editar**: lo abrís, pegás lo nuevo, volvés a leer.

**Moverlo y agrandarlo**: se arrastra como la burbuja de la cámara y se estira de las esquinas, en vivo. Arranca arriba y al centro. El texto ocupa todo el ancho del cuadro, así que para hacer las líneas más cortas o más largas se cambia el tamaño de la ventana.

**Controlarlo**, desde sus propios botones o desde la flechita de «Guion» en la cápsula: play y pausa, volver al principio, la velocidad y el tamaño de la letra. Cuando el guion se acaba, frena solo.

No hace falta aprenderse nada: arriba a la derecha el teleprompter te dice con qué tecla se le da play, y muestra la **velocidad** y el **tamaño de letra** en dos cuadritos donde podés escribir el número que quieras y Enter.

**Fondo claro u oscuro.** Viene blanco, como el resto de la app. Con el fondo blanco, leer una clase larga se puede poner pesado para la vista: el botón redondo partido de arriba a la derecha lo pasa a oscuro al instante, y también se elige con el interruptor «Fondo oscuro» del panel. Se queda como lo dejes.

Con el mouse encima del teleprompter también podés mover el texto con la rueda, o agarrarlo y arrastrarlo para ubicarte en otra parte del guion (eso pausa el avance automático). Y si esa ventana es la que tenés seleccionada, la **barra espaciadora** hace play y pausa y las **flechas arriba y abajo** cambian la velocidad. Esas teclas sueltas se desactivan solas mientras estás editando el texto, para que puedas escribir tranquilo.

Un detalle de cómo funciona: **la velocidad, la letra y el fondo se quedan como los dejes**, también para la clase siguiente, y el panel los muestra. Lo demás arranca de cero en cada grabación: dónde estaba la ventana, de qué tamaño y lo que hayas editado del guion en vivo. Es a propósito: la clase siguiente casi nunca es el mismo guion.

### Cambiar el audio y la cámara sin cortar la grabación

No todo queda congelado cuando arrancás. En mitad de la clase podés:

- **Callar tu micrófono** con Opción Comando M, para toser, atender una llamada o dejar que se oiga solo el video que estás mostrando. Volvés a apretar y sigue.
- **Callar el sonido del computador** con Opción Comando S, para que una notificación o un video de fondo no se metan en la clase.
- **Prender, cambiar o apagar la cámara** desde el botón «Cámara» de la cápsula: un toque la apaga y la prende; dejándolo apretado sale la lista de las que tengas disponibles. Podés prender la cámara aunque hayas arrancado a grabar sin ninguna: lo grabado antes queda sin burbuja y de ahí en adelante aparece.

Lo que está silenciado sale en una pastilla roja grande debajo de la cápsula, para que no se te pase. Podés dejar las dos cosas calladas a la vez si querés un tramo mudo.

Lo único que **no** se puede es al revés: si arrancaste eligiendo "solo el sonido del sistema", el micrófono no se puede sumar después. Es a propósito: la app solo abre tu micrófono si vos lo pediste antes de empezar, y no lo deja abierto "por si acaso".

### Cambiar el fondo de tu cámara

Esto no lo hace el Grabador: lo hace macOS, y funciona mejor. Si querés salir con un fondo distinto al cuarto donde estás, se prende una sola vez y sirve tanto en la burbuja como en modo cámara completa.

Con la cámara prendida, mirá la barra de menú arriba a la derecha: aparece un **ícono de video verde**. Hacele clic, buscá la opción **Background** (Fondo) y elegí una imagen. Podés usar una tuya con "Añadir imagen". Queda puesto para todas las apps que usen la cámara, no solo para el Grabador.

Dos cosas para saber de antemano: funciona con la cámara del propio Mac y con el iPhone por Continuity, **no** con cámaras externas tipo GoPro o webcam USB. Y como el cambio pasa antes de que la imagen llegue al Grabador, no le cuesta nada a la grabación.

### Pausar y reiniciar

- **Pausar** (Opción Comando P): congela la grabación. Al reanudar, el video sigue como si la pausa no hubiera existido, sin hueco.
- **Reiniciar toma** (Opción Comando R, o el botón «Reiniciar» de la cápsula): descarta lo que llevás y arranca de cero con la misma configuración, para cuando arrancaste mal y preferís repetir. Pregunta antes de hacerlo. La toma descartada no se destruye: va a la Papelera de macOS, por si te arrepentís.

## Al terminar

Detené con la cápsula, el menú del ícono o el atajo. Sale una notificación con el nombre del archivo y acceso directo a la carpeta. Por defecto todo queda en la carpeta Películas, dentro de "Grabador Bloomind", con nombres como `2026-07-26 14h30 - Clase Supabase parte 1.mov`.

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

**Dónde cambio los atajos?** En el ícono de la barra de menú, «Atajos…». Clic sobre la combinación que quieras cambiar y apretá la nueva. La app avisa si choca con otro atajo de la misma app.
