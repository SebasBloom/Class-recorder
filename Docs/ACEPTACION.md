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
