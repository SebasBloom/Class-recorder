# Pasos de aceptación por fase

Cada fase cierra cuando Sebas ejecuta estos pasos usando la app y da el visto bueno. Solo entonces se hace el commit de cierre de fase.

Nada de esto requiere leer código. Si algo falla, el log de esa grabación está en la carpeta de logs, con el mismo nombre del archivo de video.

## Fase 0. Setup — VALIDADA el 2026-07-26

Ícono en la barra de menú con su menú, documentos vivos en `Docs/`, y el archivo de configuración generado al primer arranque.

## Fase 1. Captura de pantalla y escritor resistente — VALIDADA el 2026-07-26

**Antes de empezar:** si macOS te pide el permiso de "grabación de pantalla y audio del sistema", dáselo y dejá que la app se reinicie. Dice "audio del sistema" porque Apple juntó los dos permisos en uno solo; la app todavía no graba audio.

Las grabaciones salen en `Películas / Grabador Bloomind`.

### 1. Grabar la primera pantalla

Clic en el ícono de la barra de menú, "Abrir control de grabación". Elegí una pantalla, "Iniciar grabación", **dejá correr 3 minutos** moviéndote y abriendo cosas, y detené.

Al detener se abre el Finder con el archivo. Abrilo en QuickTime.

**Tiene que:** reproducir completo, verse nítido, y durar los 3 minutos.

### 2. Grabar la segunda pantalla

Lo mismo, eligiendo la otra pantalla en el selector.

**Tiene que:** salir un segundo archivo, con la otra pantalla, reproduciendo igual de bien.

### 3. Ninguna ventana de la app en el video

Revisá los dos videos anteriores.

**Tiene que:** no aparecer la ventanita de control por ningún lado, aunque la hayas tenido abierta encima mientras grababas.

### 4. Prueba de memoria

Durante una de esas grabaciones, abrí Monitor de Actividad (está en Aplicaciones, Utilidades), buscá "GrabadorBloomind" en la lista y mirá la columna de memoria al minuto 1 y otra vez al minuto 3.

**Tiene que:** ser un valor parecido en los dos momentos. Si sube sin parar, la fase está mal aunque el video se vea bien. Avisame.

### 5. Prueba de fuego: matar la app a mitad de grabación

Esta es la más importante, porque es la que protege una clase de una hora de perderse por un cuelgue.

Arrancá una grabación, dejala correr 2 minutos, y matá la app a la fuerza: en Monitor de Actividad seleccioná "GrabadorBloomind", tocá el botón de detener arriba, y elegí **"Forzar la salida"**.

Después andá a `Películas / Grabador Bloomind` y abrí ese último archivo.

**Tiene que:** reproducir hasta más o menos el momento en que la mataste, en vez de estar corrupto o no abrir. Le van a faltar hasta 5 segundos del final: eso es normal y esperado, es el último pedazo que no alcanzó a cerrarse.

Este mecanismo ya se verificó por separado matando un proceso de prueba, y funcionó. Esta prueba es para confirmarlo en la app real.

### Resultados medidos

1. **Pantalla externa:** 3m42 a 1920×1080, 80 MB. Duración del archivo igual al reloj del log.
2. **Pantalla Retina:** 3m24 a 2880×1800, 111 MB, 4.6 Mbps reales. Una clase de una hora en esa pantalla pesa cerca de 2 GB.
3. **Ventana invisible:** confirmado por Sebas, la ventana de control no aparece en ningún video.
4. **Memoria:** muestreada cada 10 segundos durante 4 minutos de una grabación de 8m41. Osciló entre 34 y 40 MB y quedó plana en 36 los últimos dos minutos y medio. Sin crecimiento.
5. **Matar la app:** `kill -9` a los 8m41 de grabación. El archivo de 197 MB quedó reproducible con 520 de los 521 segundos, o sea se perdió **1 segundo**. La estructura muestra 103 fragmentos y el índice al principio, tal como debe quedar un archivo que no alcanzó a cerrarse.

## Fase 2. Compositor, cursor, clics y JSON — VALIDADA el 2026-07-27

### 1. El círculo sigue al cursor

Grabá 2 minutos moviendo el mouse por toda la pantalla y haciendo clics en varios lados. Abrí el video.

**Tiene que:** verse un círculo amarillo semitransparente pegado al cursor, sin ir corrido ni retrasado, y una onda que se expande y se desvanece en cada clic, distinta del círculo fijo.

Si el círculo aparece corrido siempre para el mismo lado, avisame el lado: es un error de conversión de coordenadas y con ese dato lo ubico de una.

### 2. El mouse en el otro monitor

En esa misma grabación, en algún momento llevá el mouse a la otra pantalla, dejalo unos segundos y traelo de vuelta.

**Tiene que:** desaparecer el círculo del video mientras el mouse está afuera, limpiamente y sin dejar rastro pegado en el borde, y volver a aparecer al regresar.

### 3. El archivo para VideoFlow

Al lado del video tiene que haber un archivo con el mismo nombre terminado en `.cursor.json`. Abrilo con doble clic.

**Tiene que:** verse una lista de eventos con tiempos que crecen, tipos `mov` y `click`, y al menos un `fuera` correspondiente al momento en que pasaste al otro monitor.

### 4. Memoria, 10 minutos

Esta fase toca el pipeline de frames, así que la prueba de memoria es más larga que la de la Fase 1: grabá **10 minutos** usando el computador normal.

**Tiene que:** mantenerse estable la memoria entre el minuto 2 y el minuto 10. Decime y la mido yo mientras grabás, como hicimos la vez pasada.

### Resultados medidos

1. **Círculo, onda y salida al otro monitor:** confirmado por Sebas mirando el video. El círculo va pegado al cursor sin desfase, la onda del clic se distingue del círculo fijo, y el círculo desaparece limpio al pasar a la otra pantalla.
2. **JSON:** grabación de 11m13. 2386 eventos (2320 movimientos, 59 clics, 7 salidas), tiempos siempre crecientes, ninguna coordenada fuera del frame. 227 KB, que en una clase de una hora da poco más de un mega.
3. **Memoria, 10 minutos:** 68 muestras. Arrancó en 49 MB, meseta de 62 a 63 entre el minuto 2 y medio y el 5 y medio, y bajó a 36 terminando alrededor de 46. Minuto 2 contra el final: 50 contra 47 MB. Subió y volvió a bajar, que es lo contrario de una fuga.
4. **Video:** 368 MB, duración igual al reloj del log al décimo de segundo, sin errores.

## Fase 3. Micrófono — VALIDADA el 2026-07-28

Necesitás los AirPods y el iPhone con el DJI a mano.

En el control de grabación ahora hay un selector de micrófono y una barra de nivel debajo. La barra se mueve cuando hablás, **antes** de grabar. Durante la grabación se queda quieta a propósito: ahí el micrófono lo tiene la captura.

La primera vez macOS va a pedir permiso de micrófono. Dáselo.

### 1. Cinco minutos con los AirPods

Elegí los AirPods en el selector, verificá que la barra se mueve al hablar, y grabá **5 minutos** hablando.

**Tiene que:** escucharse la voz clara, y estar sincronizada con la imagen **tanto al principio como al final**. Para comprobarlo fácil: al arrancar dale una palmada frente a la pantalla, y otra antes de detener. En el video, las dos palmadas tienen que sonar exactamente cuando se ven.

### 2. El iPhone con el DJI

Con la grabación detenida, conectá el iPhone (cerca y desbloqueado).

**Tiene que:** aparecer solo en la lista de micrófonos, sin tocar nada ni reabrir la ventana.

Elegilo, verificá que la barra se mueve al hablarle al DJI, y grabá **un minuto**.

**Tiene que:** escucharse el DJI en el archivo.

### 3. Desconexión a mitad de grabación

Grabá con los AirPods puestos, y al minuto **guardalos en el estuche** sin detener la grabación.

**Tiene que:** salir un aviso visible diciendo que se desconectó el micrófono, **la grabación tiene que seguir corriendo**, y el archivo final tiene que reproducir bien, con audio hasta el momento de la desconexión y sin audio después.

Lo que no puede pasar: que la app se caiga, o que siga grabando sin avisarte.

### Resultados medidos

1. **Micrófonos y barra de nivel:** la lista se refresca sola al conectar y desconectar; el iPhone con el DJI aparece solo. La barra responde al hablar.
2. **Desconexión a mitad de grabación:** grabación con AirPods desde las 08:59:30; a las 09:00:46 se guardaron en el estuche. Quedó registrado el aviso, la grabación siguió 25 segundos más y se detuvo normal. Ni caída ni silencio sin avisar.
3. **Calidad de audio:** se comparó el mismo micrófono grabado por `AVCaptureSession` (camino clásico de macOS) contra ScreenCaptureKit, con codificación idéntica. Nuestro camino salió mejor: mismo nivel de voz (−24.1 dBFS), ruido de fondo 6 dB más bajo (−59.3 contra −53.5), espectros equivalentes y cero recorte. Ver decisión 37.

## Fase 4. Audio del sistema — VALIDADA el 2026-07-28

En el control de grabación ahora hay un selector de **Audio** con tres opciones: Sin audio, Micrófono y Audio del sistema. El selector de micrófono y su barra de nivel solo aparecen cuando elegís Micrófono.

### 1. Dos minutos de audio del sistema

Poné música o un video sonando. En el control, elegí **Audio del sistema** en el selector de audio, y grabá **2 minutos sin hablar**.

**Tiene que:** escucharse la música limpia en el archivo, y sincronizada con la imagen. Si en el video se ve el reproductor, lo que suena tiene que corresponder a lo que se ve.

### 2. Los sonidos de la app no salen

En esa misma grabación, o en una corta aparte, provocá algún sonido del sistema (subir el volumen con las teclas, por ejemplo).

**Tiene que:** grabarse el audio del sistema, pero ningún sonido que produzca el propio Grabador.

### 3. Los tres modos siguen funcionando

Tres grabaciones cortas, una por modo: Sin audio, Micrófono, Audio del sistema.

**Tiene que:** la primera salir muda, la segunda con tu voz, la tercera con el sonido del computador. Y al cerrar y reabrir la app, el selector tiene que arrancar en el último modo que usaste.

### Resultados medidos

Grabación de 2m12 en modo Audio del sistema: pico −0.9 dBFS, promedio −18.1 dBFS, espectro completo hasta 14.3 kHz, sin recorte. Es el nivel más sano de todas las grabaciones del proyecto hasta ahora.

**Hallazgo colateral sobre los AirPods como micrófono:** en la grabación con AirPods, el 99% de la energía queda **bajo 8.5 kHz**, contra 12.9 kHz del DJI por iPhone y 13.5 kHz del micrófono del Mac. Eso es la firma del perfil de manos libres de Bluetooth: al usar unos audífonos inalámbricos como entrada, el enlace baja a calidad de teléfono. No es un problema del grabador y no se puede arreglar por software. **Los AirPods sirven para escuchar, no para grabar una clase.**

## Fase 5. Mezcla y pausa real — VALIDADA el 2026-07-31

El selector de audio ahora tiene el cuarto modo: **Micrófono + sistema**. Y durante la grabación aparece un botón **Pausar** al lado de Detener.

### 1. Las dos fuentes en una sola pista

Elegí "Micrófono + sistema", poné música sonando, y grabá 2 minutos **hablando encima de la música**.

**Tiene que:** escucharse tu voz y la música al mismo tiempo, las dos claras, sin que se saturen ni suenen distorsionadas cuando coinciden fuerte.

### 2. Los cuatro modos

Cuatro grabaciones cortas, una por modo.

**Tiene que:** Sin audio muda, Micrófono con tu voz, Audio del sistema con el computador, y Micrófono + sistema con las dos.

### 3. La pausa

Grabá **3 minutos**: al minuto 1 tocá **Pausar**, esperá **30 segundos**, y tocá **Reanudar**. Seguí hasta completar y detené.

**Tiene que:** el archivo durar **2 minutos y medio**, no 3. En el punto donde pausaste no puede haber ni un hueco de silencio ni un salto de imagen, y después de reanudar el audio tiene que seguir sincronizado con la imagen.

El cronómetro de la ventana también se congela mientras está pausado: eso es a propósito, muestra tiempo grabado y no tiempo transcurrido.

## Fase 6. Cámara: burbuja y modo cámara completa — VALIDADA el 2026-07-31

En el control de grabación hay un selector nuevo de **Cámara**, que arranca en "Sin cámara". Al elegir una, aparece de inmediato la **burbuja** en tu pantalla: una ventana chiquita con tu cara, esquinas redondeadas, que flota encima de todo. La arrastrás desde adentro y la redimensionás desde los bordes.

La primera vez macOS va a pedirte permiso de cámara.

### 1. La burbuja queda donde la dejaste

Elegí tu cámara. Movela a donde quieras y ponele el tamaño que quieras. Grabá **1 minuto**, y durante la grabación **arrastrala a otra esquina y hacela más grande**.

**Tiene que:** en el video verse la burbuja exactamente donde estaba en tu pantalla y del mismo tamaño, incluida la mudanza y el cambio de tamaño en vivo. La ventana espejo, esa que arrastraste, **no puede aparecer en el video**: lo único que se ve es la burbuja compuesta.

Cerrá la app y volvé a abrirla: la burbuja tiene que volver a aparecer en el último lugar y tamaño que le dejaste.

### 2. El atajo de cámara completa

Con la cámara elegida, grabá **2 minutos**. Durante la grabación apretá **Opción + Comando + 2** para pasar a cámara completa, y **Opción + Comando + 1** para volver a pantalla. Hacelo **cuatro o cinco veces**, algunas rápidas seguidas.

**Tiene que:** el cambio ser un corte instantáneo, sin congelones, sin pantalla negra y **sin ningún salto ni corte en el audio**. En modo cámara completa se ve solo tu cámara llenando el cuadro, sin el círculo del cursor y sin la burbuja. Al volver a pantalla, todo vuelve.

El renglón de estado del control te dice en qué modo estás.

Probá el atajo con otra app adelante (el navegador, por ejemplo): tiene que funcionar igual sin que el Grabador te robe el foco.

**Y esto es lo que más quiero que mires:** en modo cámara completa, quedate **quince segundos quieto hablándole a la cámara, sin tocar el mouse ni el teclado**. Después mirá ese tramo en el video.

**Tiene que:** verse tu imagen moviéndose normal. Si en cambio se congela en un cuadro y sigue el audio, avisame: significa que macOS deja de mandar cuadros cuando la pantalla de atrás no cambia, y hay que ponerle un reloj propio a la grabación. Es el único punto de esta fase que no pude verificar sin usar la app.

### 3. El iPhone por Continuity

Repetí una grabación corta con la **cámara del iPhone** elegida en la lista.

**Tiene que:** aparecer sola en la lista al acercar el teléfono, verse nítida en la burbuja, y funcionar igual el cambio a cámara completa.

### 4. La cámara se cae a mitad de grabación

Grabando con el iPhone, **bloqueá el teléfono** o alejalo (o desconectá la webcam USB si estás con una).

**Tiene que:** aparecer un aviso visible diciendo que se desconectó la cámara, la grabación **seguir corriendo**, y el archivo final tener todo lo grabado. Si estabas en cámara completa, vuelve solo a modo pantalla en vez de quedarse congelado en el último cuadro.

Lo que no puede pasar: que la app se caiga, que se quede congelada la imagen de la cámara, o que siga como si nada sin avisar.

### 5. Memoria

Grabá **10 minutos** con la cámara prendida y varios cambios de modo. Abrí el Monitor de Actividad, buscá "Grabador Bloomind" y anotá la memoria en el minuto 2 y otra vez al final.

**Tiene que:** quedarse parecida. Si creció sin parar, la fase está mal aunque el video haya salido bien.

### Resultados medidos

1. **Burbuja y espejo:** confirmado por Sebas. La burbuja queda en el video donde está en pantalla, el arrastre y el cambio de tamaño en vivo se reflejan, y la ventana espejo no aparece en el archivo.
2. **Desconexión de cámara:** grabación con el iPhone desde las 11:59:57; la cámara se cayó a las 12:00:09.9. Quedó el aviso registrado, la grabación siguió 10 segundos más y cerró normal. Archivo de 21.6 segundos, 632 cuadros, video y audio completos.
3. **Memoria, 10 minutos:** 59 muestras cada 10 segundos. Minuto 2: 115 MB. Minuto 9: 64 MB. Bajó sostenido en vez de subir. El pico de 160 MB del último instante es el cierre del archivo.
4. **Congelamiento en modo cámara, encontrado y corregido:** en la grabación de 10 minutos el video se congeló **41 segundos** (t=537.5 a 578.4) con el audio continuo. Causa: ScreenCaptureKit deja de mandar cuadros con la pantalla quieta, y en modo cámara el espejo se esconde, así que nada la mantiene cambiando. El tramo coincide con el instante en que Chrome soltó sus bloqueos de video. Corregido con el reloj propio de la decisión 52. **Verificado después:** grabación de 67 segundos en modo cámara, cero congelamientos detectados automáticamente, hueco máximo entre cuadros de 0.083 segundos, 29 fps parejos, audio sin huecos. Con la pantalla quieta el sistema manda un cuadro por segundo y los otros 29 los pone el reloj propio.
5. **Círculo del cursor trabado, encontrado y corregido:** el `.cursor.json` de una grabación de 21 segundos salió con **un solo evento**. Los monitores globales de AppKit no ven los eventos que van a las ventanas de la propia app, así que el círculo se quedaba clavado mientras el mouse pasaba por el control. Corregido con monitores locales (decisión 51). Verificado: la grabación siguiente, de 10 minutos, salió con **3490 eventos**.

### Pendiente de verificar

Los atajos de modo en el **teclado numérico**. Se agregaron los códigos (decisión 53) pero no se probaron todavía: cuando se confirmó la causa, Sebas ya no tenía el teclado USB a mano. Los de la fila de números están probados y funcionan.

## Fase 7. Tablero — VALIDADA el 2026-07-31

Aparece un modo nuevo: **Tablero**, con **Opción + Comando + 3**. Al entrar, la pantalla que estás grabando se cubre con un lienzo blanco donde dibujás. Ese lienzo es una ventana de la app, así que **no sale en el video**: lo que se graba es el mismo dibujo compuesto en el archivo.

Los atajos del modo, todos con Opción + Comando (y todos funcionan igual con los números de la fila de arriba o los del teclado numérico):

| Acción | Atajo |
|---|---|
| Modo pantalla | 1 |
| Modo cámara completa | 2 |
| Modo tablero | 3 |
| Rotar color del marcador | 0 |
| Deshacer último trazo | Z |
| Borrar el tablero | Suprimir |

Para dibujar: **arrastrá** el mouse. Para escribir: **un clic seco**, sin mover, abre un cuadro de texto y tipeás; Esc o Enter lo cierra, y también se cierra solo si hacés clic en otro lado.

### 1. Dibujar, escribir, deshacer y borrar

Grabá **2 minutos** con cámara elegida. Durante la grabación:

- Pasá al tablero con **Opción + Comando + 3**
- Dibujá tres o cuatro trazos
- Cambiá de color con **Opción + Comando + 0** entre trazo y trazo, y fijate que el renglón de estado del control te dice qué color está activo
- Hacé un clic seco y escribí una palabra; cerrá con Esc
- Deshacé el último trazo con **Opción + Comando + Z**
- Borrá todo con **Opción + Comando + Suprimir** y dibujá algo nuevo
- Volvé a modo pantalla con **Opción + Comando + 1** y seguí usando la app de abajo con normalidad
- Detené

**Tiene que:** en el video verse el tablero blanco con todo lo que dibujaste y escribiste, en los colores que elegiste. El deshacer y el borrado tienen que verse en el momento en que los hiciste. **La ventana del lienzo no puede aparecer en el video**, y al volver a modo pantalla la app de abajo tiene que responder al mouse como siempre.

### 2. Lo dibujado sobrevive al cambio de modo

En una grabación: dibujá algo en el tablero, pasá a modo pantalla, hacé algo, y volvé al tablero.

**Tiene que:** al volver, estar todo lo que habías dibujado. Cambiar de modo nunca borra.

### 3. La burbuja sobre el tablero

Con cámara elegida, entrá al tablero y **quedate quieto 30 segundos hablándole a la cámara**, sin dibujar ni tocar nada.

**Tiene que:** verse la burbuja de la cámara sobre el lienzo blanco, y **moviéndose normal**, no congelada. El lienzo sí puede quedarse quieto, es un lienzo. Si la cara se congela, avisame.

### 4. Cada toma arranca limpia

Dibujá algo en el tablero, detené la grabación, y arrancá una toma nueva.

**Tiene que:** el tablero de la toma nueva estar en blanco. Es a propósito: los dibujos de una clase no tienen por qué aparecer en la siguiente.

### 5. La censura y las anotaciones no salen en el tablero

Todavía no existen esas dos capas (llegan en las fases 8 y 10), así que este punto no se puede probar aún. Queda anotado para cerrarlo cuando existan.

### 6. Memoria

Grabá **10 minutos** dibujando bastante en el tablero, con muchos trazos acumulados. Decime cuando arranques y yo mido.

**Tiene que:** mantenerse estable la memoria, y el video no empezar a saltar a medida que se acumulan trazos.

### Resultados medidos

1. **Composición del tablero:** confirmado en video. Lienzo blanco con los trazos en los cinco colores, la burbuja de cámara y el círculo del cursor encima, tal como manda la matriz 8.4. La ventana espejo no aparece en ningún cuadro, y al volver a modo pantalla el escritorio real vuelve limpio.
2. **Persistencia al cambiar de modo:** salió a pantalla en el segundo 42 y volvió al tablero en el 52; el cuadro del segundo 55 es idéntico al del 40, trazo por trazo. El color activo también sobrevive: los trazos rojos de un tramo posterior corresponden a la rotación anterior a haber salido.
3. **Deshacer:** entre los segundos 300 y 302 el tablero pasó de lleno a vacío **sin ninguna línea de "Tablero borrado" en el log**, o sea con deshacer repetido y no con el atajo de borrar.
4. **Borrar:** confirmado, lienzo limpio con la burbuja todavía compuesta.
5. **Memoria, 10 minutos dibujando:** 63 muestras. Minuto 2: 243 MB. Minuto 10: 186 MB. Cerró en 168. Sin tendencia creciente. El piso es más alto que en la Fase 6 porque la caché del tablero es una imagen del tamaño de la pantalla (unos 24 MB en la Retina interna); es un costo fijo que no crece con la cantidad de trazos.
6. **Video de esa prueba:** 11m09, 19507 cuadros, 29.1 fps, hueco máximo entre cuadros de 0.050 segundos, audio continuo, ningún congelamiento.
7. **Texto que se salía de la pantalla, encontrado y corregido:** una frase larga se cortaba en el borde derecho y lo escrito de más se perdía sin aviso. Corregido con corte de línea (decisión 59). **Falta verlo funcionando en video con una frase larga.**

## Fase 8. Capa de anotación sobre pantalla real — VALIDADA el 2026-07-31

Ahora podés dibujar **encima de la pantalla real**, sin pasar al tablero. Se prende y apaga con **Opción + Comando + D** durante la grabación.

Prendida, la pantalla que estás grabando queda cubierta por una capa transparente: ves todo igual, pero el mouse le pega a la capa y no a las apps de abajo. Se dibuja y se escribe igual que en el tablero (arrastrar dibuja, clic seco abre un cuadro de texto), y el color activo se ve en el círculo de la esquina de arriba a la derecha.

Apagada, la capa desaparece, el mouse vuelve a la app de abajo y **lo dibujado queda guardado** esperando a que la prendas de nuevo.

### 1. Dibujar sobre una app real

Grabá en modo pantalla con alguna app abierta. Durante la grabación:

- Prendé la capa con **Opción + Comando + D**
- Dibujá una flecha señalando algo de la app
- Hacé un clic seco al lado y escribí una palabra
- Apagá la capa con **Opción + Comando + D**

**Tiene que:** en el video verse la flecha y el texto encima de la app real. Y al apagar la capa, **el mouse tiene que volver a controlar la app de abajo**: probá hacerle clic a un botón cualquiera para confirmarlo.

### 2. Lo dibujado sobrevive

Prendé la capa de nuevo.

**Tiene que:** estar todo lo que habías dibujado, tal cual lo dejaste.

### 3. Borrar la capa no toca el tablero

Esta es la prueba central de la fase:

- Con la capa prendida, borrala con **Opción + Comando + Suprimir**
- Pasá al tablero con **Opción + Comando + 3**

**Tiene que:** el tablero seguir con todo lo que hubieras dibujado ahí antes. Borrar una superficie nunca toca la otra.

Y al revés: dibujá en el tablero, borralo, volvé a pantalla y prendé la capa.

**Tiene que:** la capa seguir con su contenido intacto.

### 4. La capa no aparece en los otros modos

Con la capa prendida y con contenido, pasá a **cámara completa** y al **tablero**.

**Tiene que:** no verse la anotación en ninguno de los dos. Al volver a modo pantalla, reaparece. Es la matriz de visibilidad del plan: la anotación existe solo sobre la pantalla real.

### Resultados medidos

1. **Dibujar y escribir sobre la pantalla real:** confirmado en video. Los trazos y el texto se componen encima de la app real, y al apagar la capa el mouse vuelve a la app de abajo.
2. **Persistencia:** apagada y prendida de nuevo, el contenido reaparece intacto (segundos 10, 11.7 y 14 de la grabación de las 21:30).
3. **Independencia de las superficies:** en la grabación de las 21:49, "Capa de anotación borrada" a las 21:49:36 estando en modo pantalla, y el tablero conservó su dibujo al entrar a las 21:49:39. Verificado en el video.
4. **La capa no aparece en los otros modos:** confirmado en video, ni en tablero ni en cámara completa.

### Bugs encontrados por estos pasos, y corregidos

1. **La capa no recibía el mouse** (decisión 63). Con el fondo completamente transparente, macOS mandaba cada clic a la ventana de abajo. La capa se prendía bien según el log y no dibujaba nada.
2. **El primer cuadro de texto se perdía** (decisión 64). La app vive en la barra de menú y no recibía el teclado hasta el primer clic; lo tipeado se lo quedaba la app de atrás sin ningún aviso.
3. **Borrar tocaba las dos superficies** (decisión 65). Borrar el tablero se llevaba también la capa de anotación. **Es el bug que este criterio de aceptación existía para encontrar**, y lo encontró.
4. **La capa se mostraba en modo cámara**, donde no se compone: una ventana invisible comiéndose el mouse sin dejar rastro en el video.
5. **La ventana de control se veía a través de la capa**, porque activar la app la traía adelante y la capa es transparente. Ahora se esconde mientras hay una superficie de dibujo a la vista.

## Fase 9. Sistema de atajos y tarjeta de recordatorio — VALIDADA el 2026-09-11

Los diez atajos sueltos de las fases anteriores ahora son un registro único, reasignable y persistente. En el menú de la barra hay una entrada nueva: **Atajos…**

Y hay dos cosas nuevas que no existían:

- **Iniciar y detener con el teclado:** **Control + Opción + Comando + G**, y funciona **siempre**, incluso sin la ventana de control abierta. Es el único atajo activo fuera de grabación
- **La tarjeta de recordatorio:** mantené apretado **Opción + Comando + H** y aparece una tarjeta translúcida con todos los atajos activos y sus teclas. Al soltar, desaparece. Es una ventana de la app, así que no sale en el video

### 1. La lista y una reasignación

Abrí **Atajos…** desde la barra de menú.

**Tiene que:** verse la lista completa de acciones con su combinación al lado.

Tocá la combinación de **Modo tablero** y tecleá una nueva, por ejemplo Opción + Comando + T.

**Tiene que:** quedar guardada al instante y verse en la lista.

### 2. Detección de conflictos

Tocá la combinación de **Modo pantalla** y tecleá una que ya esté usada, por ejemplo la de modo cámara.

**Tiene que:** avisarte cuál acción ya la usa y **no** guardarla.

Probá también una combinación sin modificadores, una letra sola.

**Tiene que:** rechazarla diciéndote que hace falta Comando, Opción o Control.

### 3. La reasignación funciona de verdad

Grabá un minuto y usá la combinación nueva que le pusiste al tablero.

**Tiene que:** entrar al tablero con la nueva, y la vieja ya no hacer nada.

### 4. La tarjeta

Durante esa grabación, mantené apretado **Opción + Comando + H**.

**Tiene que:** aparecer la tarjeta con la lista, **mostrando la combinación nueva** del tablero y no la vieja. Al soltar desaparece. Y no puede salir en el video.

Probá también la tarjeta **sin estar grabando**: tiene que mostrar solo el atajo de iniciar/detener, porque los demás no están activos.

### 5. Fuera de grabación, el sistema manda

Con la app abierta y **sin grabar**, andá al Finder y apretá **Opción + Comando + 1**.

**Tiene que:** comportarse como siempre en Finder, sin que el Grabador se meta. Fuera de grabación la app no le roba ninguna combinación al sistema salvo la de iniciar.

### 6. Iniciar y detener sin mouse

Cerrá la ventana de control. Apretá **Control + Opción + Comando + G**.

**Tiene que:** arrancar la grabación con la última configuración que usaste. Apretá de nuevo y tiene que detenerla y abrirte la carpeta con el archivo.

### 7. Restaurar

En la pantalla de atajos, tocá **Restaurar por defecto**.

**Tiene que:** volver todo a las combinaciones originales, incluida la del tablero.

### Resultados medidos

1. **La tarjeta aparece y se esconde:** confirmado por Sebas.
2. **Atajo de la tarjeta, corregido:** el default era Opción Comando barra diagonal y **no funcionaba en el teclado latinoamericano de Sebas**, donde la barra es Shift+7. Los atajos se registran por posición física de la tecla, no por el carácter. Pasó a Opción Comando H y quedó la regla de no usar símbolos en los defaults (decisión 70).

### Sin ejercitar todavía

Los pasos 1, 2, 3, 5, 6 y 7 no dejaron rastro en los logs ni en `config.json` (los atajos reasignados siguen vacíos). Faltan por probar:

- Reasignar un atajo desde la pantalla de preferencias, y que la combinación nueva funcione en una grabación
- La detección de conflictos y el rechazo de combinaciones sin modificador
- Que fuera de grabación Opción Comando 1 siga funcionando normal en Finder
- Iniciar y detener con Control Opción Comando G sin abrir la ventana de control
- Restaurar por defecto

## Fase 10. Censura — VALIDADA el 2026-08-01

Una zona que tapa en el video lo que no puede quedar grabado.

- **Opción + Comando + C** — la primera vez abre el selector para que arrastres la zona; después prende y apaga al instante
- **Shift + Opción + Comando + C** — redibujar la zona

La zona vive mientras la app esté abierta. Al reabrirla se dibuja de nuevo: nada de lo que tapás queda guardado en disco.

**Importante:** la censura tapa **el video, no tu pantalla**. Vos vas a seguir viendo la barra de direcciones normal mientras el archivo la tiene tapada. Es a propósito (decisión 3), pero significa que en pantalla no vas a notar nada: el aviso está en el renglón de estado del control, que dice **▓ Censura activa**.

### 1. Tapar la barra de direcciones

Abrí el navegador con alguna página. Grabá y durante la grabación:

- Apretá **Opción + Comando + C**
- Arrastrá sobre la barra de direcciones y soltá
- Dejá correr unos segundos
- Apretá **Opción + Comando + C** de nuevo para destapar
- Dejá correr unos segundos más y detené

**Tiene que:** en el video, la barra de direcciones estar tapada con un bloque sólido mientras estuvo activa, y legible antes y después. **El velo oscuro del selector no puede aparecer en el video**: es una ventana de la app.

### 2. Prender y apagar sin redibujar

En esa misma grabación, apretá **Opción + Comando + C** dos o tres veces seguidas.

**Tiene que:** tapar y destapar al instante, sin volver a pedirte la zona.

### 3. Redibujar

Apretá **Shift + Opción + Comando + C**.

**Tiene que:** abrir el selector de nuevo y quedarse con la zona nueva.

### 4. Al reabrir la app, se olvida

Cerrá la app entera y volvé a abrirla. Grabá y apretá **Opción + Comando + C**.

**Tiene que:** pedirte que dibujes la zona otra vez. Es a propósito: nada de lo que tapás queda escrito en disco.

### 5. El log no dice qué tapaste

Abrí el log de esa grabación.

**Tiene que:** mencionar que la censura se activó y se desactivó, y **jamás** una coordenada ni nada sobre lo que había en pantalla. Si ves números de posición ahí, es una falla de privacidad y hay que corregirla.

El log ahora también anota cada atajo que llega ("Atajo: Censura on / off") y cuántos quedaron activos al empezar a grabar. Eso es diagnóstico: si un atajo no responde, el log dice si la combinación llegó o no.

### Resultados medidos

1. **La censura tapa de verdad:** verificado en video comparando el mismo recorte antes y durante. Segundo 20 se lee la URL completa del documento; segundo 40, bloque sólido y la URL no está.
2. **El selector no sale en el video:** confirmado, ni el velo ni el instructivo aparecen.
3. **Los atajos llegan:** el log muestra 18 atajos activos durante la grabación y 1 fuera de ella, que es exactamente lo que pide el punto delicado 7 (fuera de grabación solo iniciar/detener).
4. **El log no dice qué se tapó:** registra "zona definida y activada" y "desactivada", sin una sola coordenada.

### Cambio de alcance

Los dos slots del plan se redujeron a **uno solo sin persistencia** a pedido de Sebas (decisión 74). Con eso desaparecieron un atajo, dos campos de `config.json` y el rectángulo de una zona sensible guardado en disco.

## Fase 11. Panel, widget, countdown y flujo completo — VALIDADA el 2026-09-11

### 1. El flujo completo, de punta a punta

Sin tocar nada técnico:

- Desde la barra de menú, **Iniciar grabación…**
- En el panel: elegí pantalla, audio (probá **Micrófono + sistema** con el DJI por iPhone), cámara del iPhone, escribí **"Prueba n8n"** en nombre de la sesión, y revisá la carpeta
- Dejá la cuenta regresiva activada y arrancá
- Durante la grabación: pausá y reanudá, cambiá de modo, prendé la censura, dibujá algo
- Detené

**Tiene que:** salir la cuenta 3, 2, 1 y **no aparecer en el video**; aparecer el widget y el panel irse del medio; al detener, salir una notificación con el nombre y abrirse el Finder con el archivo, llamado `AAAA-MM-DD HHhMM - Prueba n8n.mov`.

### 2. El panel se acuerda de todo

Cerrá la app, abrila y andá a Iniciar grabación.

**Tiene que:** estar todo como lo dejaste, incluido el nombre de la sesión.

### 3. Reiniciar toma

Grabá un minuto y tocá el botón de reiniciar en el widget (o **Opción + Comando + R**).

**Tiene que:** preguntarte antes; al confirmar, arrancar una toma nueva de inmediato con la misma configuración. Abrí la **Papelera**: la toma descartada tiene que estar ahí, junto con su `.cursor.json`. Nunca se borra directo.

### 4. Área personalizada

En el panel, tocá **Elegir un área…** y arrastrá un pedazo de la pantalla. Grabá un minuto.

**Tiene que:** el video tener **solo esa zona**, y medir lo que mide el recorte. Si sale corrido o del tamaño equivocado, avisame: es la parte que más dudas me da, porque es el único lugar donde macOS pide el recorte en puntos y no en píxeles.

Después tocá **Grabar pantalla entera** para volver a lo normal.

### 5. El ícono de la barra cambia

Mirá el ícono mientras grabás y mientras está pausado.

**Tiene que:** tener un punto rojo grabando, gris pausado, y limpio sin grabar. Y el menú tiene que mostrar "Detener grabación" solo cuando hay una en curso.

### 6. Grabación interrumpida

Grabá dos minutos y matá la app a la fuerza desde Monitor de Actividad.

**Tiene que:** al volver a abrirla, avisarte que quedó una grabación sin cerrar y ofrecerte mostrarla en el Finder. El archivo tiene que reproducir hasta segundos antes del corte.

Ese aviso aparece **una sola vez**: si volvés a abrir la app, ya no molesta.

## Fase 12. Endurecimiento y entrega — VALIDADA el 2026-10-05

Cerrada por uso real en vez de la prueba sintética: Sebas grabó unas diez clases con todo el flujo (cámara, cambios de modo, audio) y los logs no registran ningún error. Sebas confirmó que la toma larga y la instalación en la Mac de Iván están bien. La validación cubre también el arreglo del medidor que suelta el micrófono al cerrar el panel (commit f0f6d9b).

Lo de código ya está (aviso de grabación interrumpida, umbrales de disco, README revisado contra el comportamiento real). Lo que falta es la prueba de fuego, y esa la corrés vos.

### 1. La grabación de 60 minutos

Una clase real, o algo que se le parezca, con **todo activo**: círculo de cursor, burbuja, cambios de modo, censura, anotaciones y audio mezclado.

- **Al arrancar, dá una palmada frente a la cámara.** Y otra antes de detener
- Avisame cuando empieces y mido la memoria durante toda la hora

**Tiene que:** el archivo reproducir completo; las **dos palmadas** tener el sonido calzado con la imagen (esa es la prueba de sincronía, y la del final es la que importa); la memoria mantenerse estable entre el minuto 5 y el 55.

### 2. Los logs de esa hora

Pasame el log de esa grabación.

**Tiene que:** no tener errores inesperados, y contar la historia completa de lo que pasó.

### 3. La Mac de Iván

Copiale el `.app`, y que **siga el README solo, sin que vos le expliques nada**. Que lo autorice en Gatekeeper, dé los permisos y grabe 5 minutos.

**Tiene que:** lograrlo sin ayuda. Si se traba en algún paso, ese paso está mal escrito en el README y hay que arreglarlo. Es la prueba de verdad del manual.

## Fase 13. Controles en vivo de audio y cámara — VALIDADA el 2026-09-11

Lo que cambia: hoy todo lo que elegís en el panel queda congelado al arrancar. Desde esta fase podés silenciar el micrófono o el audio del sistema en mitad de la clase, y prender, cambiar o apagar la cámara aunque hayas empezado sin ninguna.

- **Opción + Comando + M** — silenciar y volver a activar el micrófono
- **Opción + Comando + S** — silenciar y volver a activar el audio del sistema
- **Botón de cámara en el widget** — despliega la lista de cámaras, marca la que está activa y deja apagarla

Lo único que **no** vas a poder hacer es sumar un audio que no elegiste antes de arrancar: si empezaste en "solo sistema", el micrófono no se puede encender después. Está explicado en la decisión 82 y es a propósito, para no dejar tu micrófono abierto toda la clase sin que lo hayas pedido.

### 1. El video ya no te tapa la voz

Este es el criterio que originó la fase. Poné a sonar un video con gente hablando (el de noticias de MMA sirve) y grabá en modo **Micrófono + sistema**:

- Dejá correr el video 10 segundos **sin hablar**
- Hablá encima del video otros 15 segundos, en tu tono normal de clase
- Callate y dejá el video solo otros 10 segundos
- Detené

**Tiene que:** en el primer y el tercer tramo, el video oírse a su volumen normal. En el tramo del medio, **tu voz por encima del video con claridad**, con el video audible pero abajo. Al empezar a hablar el video tiene que bajar rápido, sin comerse tu primera palabra, y al callarte tiene que volver a subir con suavidad, sin bombear ni respirar entre frase y frase.

Referencia de lo que hay hoy, para comparar: el audio del sistema entra entre 5 y 9 dB **por encima** de tu voz. Si la grabación nueva suena igual de embarrada que la de hoy, la fase falla.

### 2. Silenciar el micrófono a mitad de clase

Grabá en modo **Micrófono + sistema**, con algo sonando en el computador, y durante la grabación:

- Hablá unos 10 segundos
- Apretá **Opción + Comando + M** y seguí hablando otros 10 segundos
- Apretá **Opción + Comando + M** de nuevo y hablá 10 segundos más
- Detené

**Tiene que:** en el video, oírse tu voz en el primer y el tercer tramo y **nada de tu voz** en el del medio, mientras el sonido del computador sigue igual de parejo en los tres. El widget tiene que mostrar bien visible que el micrófono está mudo mientras lo esté.

### 3. Silenciar el audio del sistema

Misma grabación o una nueva, al revés: dejá algo sonando y apretá **Opción + Comando + S** un rato en el medio, hablando todo el tiempo.

**Tiene que:** desaparecer el sonido del computador en ese tramo y tu voz seguir sin cortes ni saltos.

### 4. El silencio total está permitido

Silenciá las dos fuentes al mismo tiempo unos segundos y volvé a activarlas.

**Tiene que:** dejarte hacerlo, mostrarlo clarísimo en el widget, y el archivo tiene que quedar con **silencio** en ese tramo, no con un hueco. Para comprobarlo: el video no puede saltar ni desincronizarse después de ese tramo. Si al volver del silencio la voz quedó corrida contra la imagen, la fase falla.

### 5. Prender la cámara habiendo arrancado sin ninguna

Arrancá una grabación **sin elegir cámara** en el panel. Durante la grabación, tocá el botón de cámara del widget y elegí una de la lista.

**Tiene que:** aparecer la burbuja en el video de ahí en adelante, sin cortar la grabación ni el audio. Lo grabado antes queda sin burbuja, que es lo correcto.

### 6. Cambiar de cámara y apagarla

Con la cámara prendida, abrí el menú y elegí otra (si tenés el iPhone por Continuity, probalo). Después abrí el menú y apagala.

**Tiene que:** cambiar de imagen en la burbuja en un segundo o dos, sin tumbar la grabación, y apagarse dejando el video normal. El audio no se puede interrumpir en ningún momento.

### 7. Apagar la cámara en modo cámara completa

Poné modo cámara completa (**Opción + Comando + 2**) y con ese modo activo apagá la cámara desde el widget.

**Tiene que:** volver solo a modo pantalla. Si el video queda en negro o congelado, la fase falla.

### 8. Los cuatro modos de audio siguen sanos

Esta fase cambia el camino del audio para **todos** los modos, no solo el mixto, así que hay que reverificar los cuatro. Grabá una toma corta en cada uno: sin audio, solo micrófono, solo sistema, micrófono + sistema.

**Tiene que:** sonar bien en los cuatro, igual que antes. En los modos de una sola fuente, el botón de la fuente que no elegiste tiene que estar deshabilitado, no ausente.

### 9. Cada toma arranca sonando

Silenciá el micrófono, detené la grabación y arrancá otra.

**Tiene que:** la toma nueva arrancar con el micrófono **activo**. El silencio no se hereda (decisión 84).

## Fase 14. Niveles de ventana y widget completo — VALIDADA el 2026-09-11

Lo que cambia: el widget pasa a tener un botón por cada cosa que hoy solo se puede hacer con un atajo, en dos tamaños que se alternan con un botón. Y se arregla algo que estaba roto sin que nadie lo hubiera reportado: con el tablero o el marcador prendidos, los botones del widget no respondían, porque la superficie de dibujo se quedaba con todos los clics de la pantalla.

Los pasos 4 a 7 son de reverificación: esta fase toca a quién le llega el mouse, así que hay que comprobar que lo que ya funcionaba sigue funcionando. **Que los botones nuevos anden no alcanza para dar la fase por buena.**

### 1. Los botones del widget con el marcador prendido

Arrancá una grabación en modo pantalla y prendé el marcador con **Opción + Comando + D**. Con el marcador prendido, tocá con el mouse los botones del widget: pausar, reanudar, y el de cambiar de color.

**Tiene que:** responder cada botón, con el marcador prendido todo el tiempo. Antes de esta fase no respondía ninguno.

Repetilo en modo tablero (**Opción + Comando + 3**), que cubre la pantalla entera.

### 2. Dibujar debajo del widget

Con el marcador prendido, dibujá un trazo que pase por debajo del widget.

**Tiene que:** verse el trazo cortado en tu pantalla, tapado por el widget, y **completo en el video**. Es el efecto secundario aceptado del arreglo, no un defecto: si el trazo tampoco está en el video, la fase falla.

### 3. El widget compacto y expandido

Tocá el botón de expandir del widget.

**Tiene que:** aparecer el resto de los botones (los tres modos, censura, marcador, colores, tablero blanco y negro, deshacer, borrar y la tarjeta de atajos), sin que el widget se salga de la pantalla ni tape lo que estás mostrando más de lo necesario.

Probá cada botón nuevo y comprobá que hace lo mismo que su atajo. Después contraelo, detené la grabación, cerrá la app, abrila y grabá de nuevo.

**Tiene que:** arrancar en el tamaño en que lo dejaste.

### 4. Reverificación: el círculo del cursor

Grabá dos minutos moviendo el mouse por toda la pantalla y haciendo clics.

**Tiene que:** el círculo seguir al cursor sin desfase y los clics mostrar su onda, igual que siempre.

### 5. Reverificación: la capa de anotación

Prendé el marcador, dibujá una flecha y escribí un texto con el teclado sobre una app real. Apagalo y volvé a prenderlo.

**Tiene que:** dibujarse el trazo, **escribirse el texto con el teclado** (este es el que más riesgo corre con este cambio), volver el mouse a la app de abajo al apagar la capa, y seguir ahí lo dibujado al prenderla de nuevo.

### 6. Reverificación: el tablero

Pasá al tablero, dibujá, escribí un cuadro de texto, cambiá el color, deshacé un trazo, borralo y volvé a modo pantalla.

**Tiene que:** funcionar todo igual que en la Fase 7, y la app de abajo tiene que volver a responder al mouse al salir del tablero.

### 7. Reverificación: la censura

Con **Opción + Comando + C** dibujá una zona de censura, y hacelo una vez **arrastrando el rectángulo por encima del widget**.

**Tiene que:** dejarte trazar la zona aunque el rectángulo pase por donde está el widget. Si el widget se come el arrastre, la fase falla. Después comprobá en el video que la zona quedó tapada mientras la censura estuvo activa.

### 8. La burbuja no se pierde

Con la cámara prendida y el tablero activo, mirá la burbuja en tu pantalla.

**Tiene que:** seguir visible por encima del tablero, no debajo.

### 9. Prender y apagar el círculo del cursor

Agregado el 2026-09-06, dentro de esta misma fase.

Grabá un minuto en modo pantalla moviendo el mouse y haciendo clics. A mitad, apretá **Opción + Comando + A**. Seguí moviéndote y haciendo clics otro rato, y volvé a apretarlo antes de terminar.

**Tiene que:** en el video, desaparecer el círculo amarillo **y** la ondita del clic en el tramo del medio, y volver los dos al final. En tu pantalla no vas a notar nada, porque el círculo nunca estuvo ahí: la señal es el botón del widget expandido, que se ve gris cuando está apagado.

Probalo también desde ese botón, no solo con el atajo.

### 10. El archivo de VideoFlow no se ve afectado

Con la grabación del paso anterior, abrí el archivo `.cursor.json` que quedó al lado del video (doble clic, se abre como texto).

**Tiene que:** tener eventos de movimiento y de clic **también en el tramo donde el círculo estuvo apagado**, con los tiempos corriendo sin huecos. Si ese tramo quedó vacío, la fase falla: el zoom automático de VideoFlow depende de esos datos y apagar el círculo no tiene que costarlo (decisión 98).

### 11. Se recuerda como lo dejaste

Apagá el círculo, detené la grabación, cerrá la app, abrila y grabá de nuevo.

**Tiene que:** arrancar con el círculo apagado. Prendelo y repetí: la grabación siguiente tiene que arrancar prendido.

### 12. Los botones se entienden sin adivinar

Agregado el 2026-09-06 a pedido de Sebas.

Expandí el widget y mirá los dieciocho botones.

**Tiene que:** leerse el nombre de cada uno debajo del dibujito, sin que ninguno quede cortado ni encimado con el de al lado, y sin que el widget se salga de la pantalla. Todos los botones tienen que medir lo mismo y quedar alineados en columnas de una fila a la otra. El compacto mide 502×158 y el expandido 502×392.

Si algún nombre no te dice lo que hace el botón, decilo: son palabras y se cambian en un renglón.

### 13. Se ve qué está prendido y qué no

Agregado el 2026-09-06 a pedido de Sebas.

Con el widget expandido, andá prendiendo y apagando cosas: la cámara, los tres modos, el círculo del cursor, el marcador, la censura, y silenciá el micrófono.

**Tiene que:** ponerse **azul** el botón de lo que quedó prendido (cámara, modo activo, cursor, marcador), **coral** el de lo que está tapando o callando (censura, micrófono o sonido en mudo), y gris lo apagado. El cambio tiene que notarse de reojo, sin acercarse a la pantalla.

En particular, apagá el círculo del cursor y mirá el widget: el botón "Cursor" tiene que quedar gris **y** la línea de estado de arriba tiene que decir **"sin cursor"**. Es el único estado que no podés comprobar mirando tu pantalla, porque el círculo solo existe en el video.

## Fase 15. Teleprompter — VALIDADA el 2026-09-16

Lo que cambia: una ventana con tu guion pasando solo mientras grabás, que **no sale en el video**. Se prende con **Opción + Comando + T** o con el botón "Guion" del widget, funciona en los tres modos, y se controla desde sus propios botones o desde la fila nueva del widget expandido.

El guion se carga antes de grabar, en el panel. Y se puede cambiar en plena grabación con el botón de editar.

Los pasos 12 y 13 son de reverificación: esta fase mete una ventana nueva en la pila y le pelea el teclado al espejo de dibujo, así que hay que comprobar que lo de antes sigue igual.

### 1. Cargar el guion en el panel

Abrí el panel de "Iniciar grabación". Abajo de la cámara hay un campo nuevo, **Guion del teleprompter**, con dos deslizadores: velocidad y tamaño de letra.

Pegá ahí un texto largo de verdad —dos o tres páginas, no tres renglones— con **Comando + V**. Esto antes no funcionaba en ningún campo de la app, así que probá pegar también en el nombre de la sesión.

Después probá el botón **Cargar archivos…**: bajá **tres** guiones tuyos de Google Docs con Archivo → Descargar → Word (.docx) y cargalos **todos juntos** en una sola vez. Tiene que aparecer debajo del cuadro la línea "3 guiones cargados" con sus nombres, y el botón Quitar que los saca todos. Probá también con un archivo que no sea texto: tiene que avisarte cuál no se pudo, sin perder los otros.

Las dos filas de abajo, **Velocidad** y **Tamaño de letra**, se manejan de tres formas y las tres tienen que quedar en el mismo número: arrastrando la barra, escribiendo directo en el campo, o con los botones **−** y **+** (la velocidad se mueve de a 0.5 y la letra de a 4). Probá también escribir algo imposible —"rápido", 999, vacío—: tiene que volver solo a un valor válido, nunca quedarse con lo que escribiste.

Cerrá la app entera y volvé a abrirla.

**Tiene que:** estar el guion ahí, con la misma velocidad y el mismo tamaño. Si tuviste que volver a pegarlo, la fase falla.

### 2. La barra del teleprompter

Mirá la barra de abajo del teleprompter, que se rehízo el 2026-09-13.

**Tiene que:** tener los mismos siete botones que la fila del widget, con los mismos nombres y el mismo tamaño: Play, Al inicio, Más lento, Más rápido, Letra −, Letra +, Editar. A la derecha, en dos renglones, **"⌥⌘T esconder · espacio play"** y "velocidad 5.0 · letra 38".

Andá a **Atajos…** en el menú de la barra, reasigná el del teleprompter a otra combinación y volvé a abrirlo. **Tiene que:** mostrar la combinación nueva, no la vieja.

Achicá la ventana del teleprompter todo lo que te deje. **Tiene que:** frenar antes de que los botones se corten, y los números de la derecha desaparecen enteros cuando ya no caben — nunca a medias.

### 3. Prenderlo y leerlo

Con el guion cargado en el panel, arrancá a grabar en modo pantalla.

**Tiene que:** aparecer el teleprompter **solo**, sin que le pidas nada. Apagalo y prendelo con **Opción + Comando + T**: tiene que responder, y una vez que lo apagaste no puede volver a aparecer solo en esa misma grabación.

Después probá lo mismo con el campo del guion **vacío**: ahí no tiene que aparecer nada al arrancar, y **Opción + Comando + T** tiene que abrirlo igual, en blanco y listo para que le pegues el texto con el botón de editar.

**Tiene que:** aparecer el teleprompter arriba y al centro de la pantalla que estás grabando, con tu texto, fondo azul oscuro y una línea fina azul cruzando por la mitad. Arriba y abajo el texto se desvanece en vez de cortarse contra el borde.

Tocá **Play**. El texto sube solo. Apretá **Pausa** y frena.

**Tiene que:** subir parejo, sin tirones ni saltos, y la primera línea del guion tiene que arrancar a la altura de la línea del medio, no pegada al borde de arriba.

### 4. Cambiar de guion sin parar la grabación

Con los tres guiones cargados, arrancá a grabar y mirá la fila de arriba del teleprompter: hay una pestaña por guion, con el nombre del archivo, más una que dice **Escrito** si dejaste texto en el cuadro del panel.

**Tiene que:** cambiar de guion al tocar su pestaña, arrancando desde el principio y con el texto empezando **en la línea de lectura**, no debajo. La pestaña activa se ve azul.

Editá un guion con el botón Editar, cambiate a otra pestaña y volvé. **Tiene que:** estar tu edición ahí, no el texto original.

Con un solo guion cargado, la fila de pestañas no tiene que aparecer.

### 5. Esconder el menú de grabación

Grabando, apretá **Opción + Comando + W**.

**Tiene que:** desaparecer el widget entero, y volver con la misma combinación. Mientras está escondido, los atajos tienen que seguir funcionando igual —probá cambiar de modo o pausar—. Al detener y arrancar otra grabación, el widget tiene que estar a la vista de nuevo.

### 6. Que no salga en el video

Este es el criterio que importa más que todos los demás juntos.

Con el teleprompter abierto y el texto corriendo, grabá un minuto: medio en modo pantalla, y cambiá a modo tablero (**Opción + Comando + 3**) con el teleprompter todavía a la vista. Detené y abrí el video.

**Tiene que:** no aparecer ni un pedazo del teleprompter en ningún cuadro, en ninguno de los dos modos. Si se ve, la fase falla y no hay nada más que revisar.

Aprovechá y probá también el modo cámara completa, que es el tercero.

### 7. Controlarlo con las teclas

Con el teleprompter a la vista, hacele clic encima para que quede seleccionado.

- **Barra espaciadora**: play y pausa.
- **Flecha arriba y flecha abajo**: más rápido y más lento, de a 0.5. El número se ve en la barra de abajo.

**Tiene que:** responder las tres teclas, y el número de velocidad tiene que quedar con un decimal limpio (5.5, 6.0), no con una cola de decimales.

### 8. Moverlo, estirarlo y manejar el texto a mano

Con la grabación corriendo:

- **Arrastrá el texto** con el mouse hacia arriba y hacia abajo. El guion se mueve con la mano y el avance automático se pausa solo.
- **Rueda del mouse** encima del texto: también mueve el guion.
- **Arrastrá la ventana** desde la barra de abajo, la de los botones. Ahí sí se mueve la ventana entera.
- **Estirala** desde una esquina o un borde.

**Tiene que:** hacer cada cosa en su lugar: sobre el texto se mueve el texto, sobre la barra se mueve la ventana. Y al agrandar o achicar la ventana, el texto tiene que seguir arrancando en la línea del medio.

Si la rueda te mueve el guion al revés de lo que esperás, decilo: es un signo menos en un renglón.

### 9. Cambiar el guion a mitad de clase

Con la grabación corriendo, tocá **Editar** en la barra del teleprompter. Escribí encima o pegá otro texto. La barra espaciadora y las flechas ahora tienen que **escribir y moverse por el texto**, no hacer play ni cambiar la velocidad. Volvé a **Leer**.

**Tiene que:** quedar el texto nuevo listo para leer desde el principio, con la grabación corriendo todo el tiempo, sin cortes.

### 10. Que frene al final y vuelva al principio

Llevá el guion hasta el final, con velocidad alta o arrastrando.

**Tiene que:** frenar solo al llegar a la última línea, sin seguir subiendo hasta dejar la pantalla en blanco. La última línea tiene que poder llegar hasta la línea del medio.

Tocá **Al inicio**: vuelve arriba de todo y queda pausado.

### 11. Los botones del widget

Expandí el widget. Abajo de "Comandos tableros" hay un grupo nuevo, **Teleprompter**, con siete botones.

**Tiene que:**
- Con el teleprompter apagado, los siete están grises y no responden. El botón **Guion** de la fila de arriba también está gris.
- Al prenderlo, el botón **Guion** se pone azul y los siete se habilitan.
- Cada uno hace lo mismo que su botón en la ventana: Play, Al inicio, Más lento, Más rápido, Letra −, Letra +, Editar.
- El de Play se pone azul y dice "Pausa" mientras el guion está subiendo.

Fijate también que el widget entero se vea **cuadrado**, que es lo que se rehizo el 2026-09-13:

- Las filas tienen **7, 6, 6 y 7 botones**, en ese orden. El borde derecho tiene que verse simétrico, no en escalera.
- Los modos de fuente y los comandos de tablero ahora **comparten fila**, cada uno con su título encima de su tramo.
- La tarjeta de **Atajos** se pasó al grupo *Comandos*: es una ayuda general, no un comando de tablero.
- Todos los dibujitos tienen que verse del mismo tamaño, y el nombre de todos los botones a la misma altura.
- El widget pasa a medir **582×140 compacto y 582×374 expandido**.
- En la cabecera, "01:15" y "GRABANDO" tienen que estar apoyados en el mismo renglón, y el botón de Más/Menos centrado contra las dos líneas.
- El renglón de estado ya no lleva emojis: dice "Pantalla · sonido mudo", con lo que está callado o tapando en **coral**.

Ninguna palabra puede quedar cortada ni encimada, todos los botones tienen que seguir alineados en columnas de una fila a la otra, y el widget no puede salirse de la pantalla.

### 12. Reverificación: los cuadros de texto del tablero

Este es el punto donde el teleprompter puede romper algo que ya andaba: los dos necesitan el teclado.

Grabando en modo tablero, con el teleprompter abierto:

1. Hacé un clic seco en el tablero: se abre un cuadro de texto. Escribí algo.
2. Sin cerrarlo, hacé clic en el teleprompter y apretá la barra espaciadora.
3. Volvé a hacer clic en el tablero y escribí de nuevo.

**Tiene que:** el paso 2 hacer play en el guion y cerrar el cuadro de texto dejando escrito lo que ya habías tipeado; el paso 3 volver a escribir en el tablero normalmente. En ningún momento se pueden perder letras ni quedar un cuadro escribiendo en el vacío.

### 13. Reverificación: el widget y el dibujo siguen respondiendo

Con el marcador prendido (**Opción + Comando + D**) y el teleprompter abierto encima:

**Tiene que:** seguir respondiendo los botones del widget, seguir pudiéndose dibujar en toda la pantalla, y el teleprompter tiene que quedar **por encima** del marcador pero **por debajo** de la burbuja de la cámara.

### 14. Cada grabación arranca de cero

Con la grabación corriendo, cambiá el guion desde el botón de editar, movelo, agrandalo y subile la velocidad. Detené la grabación.

**Tiene que:** desaparecer el teleprompter al detener. Arrancá otra grabación y prendelo de nuevo: tiene que volver con el guion del panel, la velocidad del panel, el tamaño del panel y en su posición de arranque, arriba y al centro. Nada de lo que ajustaste en la grabación anterior puede sobrevivir.

Y dentro de una misma grabación es al revés: apagalo y prendelo con Opción + Comando + T, y tiene que volver **exactamente como lo dejaste**, incluso en la parte del guion donde ibas.

## Fase 16. Rediseño visual — parte 1: el widget — VALIDADA el 2026-10-05

Lo que cambia: el widget pasa a ser una **cápsula blanca** en una sola fila. A la vista quedan el tiempo con una frase debajo, Pausar, Detener, Reiniciar, Micrófono, Sonido PC y Cámara. Todo lo demás está en cuatro botones con flechita (**Qué se ve**, **Tablero**, **Sobre la pantalla** y la flechita de **Guion**): cada uno abre un menú chico con el atajo escrito al lado. Las alertas graves salen como pastillas coral grandes debajo de la cápsula, y el botón **Achicar** la deja en solo el tiempo.

No cambia ninguna función: lo que hacía el widget lo sigue haciendo, ahora en otro lugar. Por eso el paso 7 vuelve a comprobar que todo responde con el tablero y el marcador prendidos.

Para arrancar: grabá la pantalla con micrófono, sonido del PC, cámara y un guion cargado, para que aparezca todo.

### 1. La cápsula

Arrancá la grabación y mirá arriba a la derecha.

**Tiene que:** verse una cápsula blanca de borde fino, con el tiempo en letra con serifa, un punto azul que late al lado y debajo «Grabando la pantalla». Arrastrala desde el tiempo o desde cualquier parte que no sea un botón: se mueve. Detené, volvé a grabar: aparece donde la dejaste.

### 2. Los menús de grupo

Tocá **Qué se ve**, después **Tablero**, después **Sobre la pantalla** y después la flechita al lado de **Guion**.

**Tiene que:** abrir un menú chico debajo de cada uno, con el atajo a la derecha de cada renglón (por ejemplo «Pantalla ⌥⌘1»), el modo actual con su tilde, y cerrarse solo al elegir algo o al tocar afuera. Nunca puede haber dos abiertos a la vez. Probá una acción de cada menú: cambiar a tablero, prender el marcador, apagar y prender el resaltado del cursor, poner y sacar la censura, y bajar la velocidad del guion. Cada una tiene que hacer lo mismo que su atajo.

### 3. Los botones que aparecen solos

Pasá al tablero con **Opción + Comando + 3**.

**Tiene que:** aparecer en la cápsula, sobre un fondo gris claro, **Lienzo**, **Deshacer** y **Borrar**, y desaparecer al volver a la pantalla. Con el guion a la vista tiene que estar **Pausa guion**, que se esconde al esconder el guion con **Opción + Comando + T**. La frase de abajo del tiempo dice en qué estás («Grabando el tablero negro · marcador amarillo») y, si apagás el resaltado del cursor, agrega «sin cursor».

### 4. Las alertas

Silenciá el micrófono con **Opción + Comando + M** y poné la censura con **Opción + Comando + C**.

**Tiene que:** salir debajo de la cápsula una pastilla coral grande por cada una («Micrófono mudo ⌥⌘M», «Censura puesta ⌥⌘C»), y el botón del micrófono ponerse coral y decir «Activar mic». Tocá cada pastilla: tiene que deshacer lo suyo y desaparecer. Silenciá también el sonido del PC: las dos pastillas de audio se juntan en una sola, «Sin audio».

### 5. El modo mini

Tocá **Achicar**, el último botón de la cápsula.

**Tiene que:** quedar solo una pastilla con el punto y el tiempo, en la misma esquina. Pausá: el punto pasa a dos barritas. Silenciá el micrófono: la pastilla se pone coral entera y la alerta sigue saliendo debajo. Arrastrala: se mueve sin volver a la cápsula. Tocala sin arrastrar: vuelve la cápsula completa. Dejala en mini, detené y volvé a grabar: arranca en mini.

### 6. Pausa, cámara y reiniciar

Tocá **Pausar**: tiene que decir «Reanudar» con el ícono de play (antes decía «Pausar» con ese ícono) y el tiempo quedarse quieto y más claro. Tocá **Cámara**: apaga y prende la burbuja; mantenelo presionado: sale el menú de cámaras. Tocá **Reiniciar**: pregunta antes, como siempre.

### 7. Reverificación: todo responde con el dibujo prendido

Con el tablero prendido, y después con el marcador sobre la pantalla, tocá botones de la cápsula y abrí los menús de grupo.

**Tiene que:** responder todo igual que sin dibujo, y lo que dibujes seguir saliendo en el video. Al terminar, mirá el video: la cápsula, los menús y las pastillas **no pueden aparecer en ningún cuadro**.
