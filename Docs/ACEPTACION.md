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

### Fase 2 — PENDIENTE

Círculo amarillo del cursor, efecto de clic y el `.cursor.json` para VideoFlow.
