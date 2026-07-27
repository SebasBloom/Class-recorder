# Plan Maestro: Grabador Bloomind (nombre de trabajo)

Documento de construcción para Claude Code. Léelo completo antes de escribir la primera línea de código. Este plan es la fuente de verdad del proyecto: si algo durante la construcción contradice este documento, se detiene el trabajo y se consulta con Sebas antes de seguir.

---

## 1. Contexto y objetivo

Vas a construir una app nativa de macOS para grabar tutoriales y clases tipo webinar de hasta una hora o más. La usan dos personas, Sebas e Iván, del equipo de Bloomind Lab. Ninguno de los dos es developer, así que todo lo que produzcas tiene que poder verificarse y operarse sin leer código.

La app graba la pantalla con un círculo amarillo que resalta el cursor, mezcla micrófono y audio del sistema, compone una burbuja de cámara, permite censurar zonas sensibles en vivo (Sebas muestra su VPS en clase y la dirección no puede quedar en el video), tiene un tablero para explicar conceptos, una capa para dibujar sobre la pantalla real, y cambia entre modos con atajos de teclado sin cortar la grabación. El archivo sale terminado, sin paso de edición para los efectos en vivo. La edición posterior (subtítulos, cortes de silencio) la hace otra herramienta del equipo llamada VideoFlow, que es un proyecto separado y no se toca aquí.

Es una app autónoma de verdad: sin Chrome, sin extensiones, sin servidor, sin internet. Se instala local en las dos Macs del equipo.

## 2. Requisitos del entorno

- macOS 15 Sequoia o superior en ambas Macs (la de Sebas y la de Iván). Es requisito duro porque la captura de micrófono nativa dentro de ScreenCaptureKit existe desde Sequoia. Verificar en Fase 0 antes de seguir.
- Xcode NO es necesario. El proyecto se construye con Swift Package Manager sobre las Command Line Tools de Apple, y un script (`construir.sh`) arma el bundle `.app` y lo firma. Ver la decisión correspondiente en `Docs/DECISIONS.md`. Si algún día se instala Xcode, abre el `Package.swift` directamente sin migrar nada.
- Certificado de firma autofirmado en el Llavero del desarrollador. Sin él, cada recompilación cambia la identidad del binario y macOS vuelve a pedir los cuatro permisos. El paso a paso está en `Docs/FIRMA.md`.
- Uso interno, sin App Store: la app se distribuye sin firma de Developer ID. Al abrirla por primera vez en otra Mac, Gatekeeper la bloquea y se autoriza desde Configuración del Sistema, Privacidad y seguridad, "Abrir de todos modos". Es el flujo esperado, no un fallo.
- Aviso conocido de Sequoia: el permiso de grabación de pantalla para apps fuera del App Store se reautoriza aproximadamente cada mes. Es comportamiento del sistema operativo. La app debe manejarlo con un mensaje claro cuando pase, nunca fallando en silencio.

## 3. Stack

- Swift con AppKit. Se necesita control fino de NSStatusItem, ventanas overlay, event taps y niveles de ventana que SwiftUI no maneja bien solo. Se puede usar SwiftUI embebido para pantallas simples (preferencias, panel) si simplifica, pero la estructura de ventanas es AppKit.
- ScreenCaptureKit para captura de pantalla, audio del sistema y micrófono.
- AVFoundation (AVCaptureSession para cámara, AVAssetWriter para escribir el archivo).
- Core Graphics para toda la composición sobre los frames.
- Sin dependencias externas. Cero paquetes de terceros. Todo con frameworks de Apple. Esto elimina riesgos de supply chain y mantiene el proyecto entendible.

Convención de idiomas: tipos, funciones y variables en inglés (convención de Swift). Comentarios, documentos, mensajes de UI y logs en español. Carpetas del proyecto en español.

## 4. Decisiones ya tomadas (semilla de DECISIONS.md)

Estas decisiones ya se discutieron y cerraron con Sebas. En Fase 0 las copias a `Docs/DECISIONS.md` como primeras entradas. No se reabren sin hablar con él.

1. **App nativa Swift, no Electron ni extensión de navegador.** Razón: tiene que censurar y dibujar sobre cualquier app (terminal, editores, todo el escritorio), no solo pestañas de Chrome. Alternativa descartada: extensión de Chrome, limitada al navegador.
2. **Grabador y VideoFlow son dos herramientas separadas.** Razón: mundos tecnológicos distintos (Swift nativo vs Python), fusionarlos es la peor relación esfuerzo resultado. Alternativa descartada: empacar Python dentro de la app de Mac, queda como opción futura si dos íconos resultan incómodos.
3. **Efectos compuestos en el archivo, no en la pantalla real.** El círculo, la burbuja, la censura y el contenido de dibujo se dibujan sobre cada frame antes de escribirlo. Lo que Sebas ve en su pantalla física son ventanas espejo propias, excluidas de la captura. Razón: el archivo sale terminado y ninguna ventana propia contamina el video. Regla derivada: **toda ventana de la app se excluye siempre de la captura, sin excepciones.** Lo que deba aparecer en el video se compone desde el modelo de datos.
4. **Censura con bloque sólido opaco por defecto, no blur.** Razón: un difuminado débil puede dejar adivinar texto corto y predecible como una IP. El blur queda como estilo opcional para contenido menos sensible.
5. **Dos slots de censura, permanente y de sesión.** El permanente persiste en disco entre sesiones (caso: barra de direcciones con el VPS). El de sesión vive solo en memoria y muere al cerrar la app.
6. **El zoom automático al clic NO va en el grabador.** Va en VideoFlow como paso de edición, porque en edición el algoritmo puede mirar adelante y atrás en el tiempo antes de decidir. El grabador solo exporta un archivo JSON con posiciones de cursor, clics y cambios de modo, sincronizado con el video.
7. **La cámara captura a resolución completa todo el tiempo**, aunque solo se muestre en burbuja chiquita. Razón: el modo cámara completa necesita esa resolución, y así el cambio de modo es instantáneo.
8. **Cambio de modo con corte directo, sin transiciones**, en v1.
9. **Micrófono y sistema mezclados en un solo track de audio** cuando se eligen ambos. Razón: VideoFlow transcribe con Whisper y necesita un audio único y limpio.
10. **HEVC con codificación por hardware para video, AAC 48 kHz para audio.** Razón: una hora a resolución Retina en H.264 pesa demasiado; HEVC en Apple Silicon es eficiente y ffmpeg y Whisper lo leen sin problema.
11. **Archivo resistente a fallos desde la Fase 1**: se escribe con fragmentos periódicos de modo que si el proceso muere a mitad de grabación, lo grabado hasta el último fragmento sigue siendo reproducible. Nunca un archivo que solo es válido si se cierra bien.
12. **Reiniciar toma manda la toma descartada a la Papelera del sistema, nunca borrado directo.** Razón: red de seguridad barata, coherente con la regla del equipo de nunca destruir información sin salida de emergencia.
13. **Colores del marcador: paleta corta fija que se rota con un atajo** (rojo, amarillo, verde, blanco, negro), en vez de un selector de color con el mouse que rompe la continuidad de la clase. Blanco y negro incluidos porque las herramientas que graba Sebas mezclan temas claros y oscuros.
14. **Cero red.** La app no hace ninguna conexión saliente. Sin telemetría, sin chequeo de actualizaciones, nada. Es una garantía de confidencialidad verificable, no una preferencia.

Formato de cada entrada nueva en DECISIONS.md: fecha, decisión, razón, alternativa descartada y por qué. Toda decisión técnica no obvia que tomes durante la construcción se registra ahí en el momento, no al final.

## 5. Reglas transversales de ingeniería

Aplican a todas las fases sin excepción.

**Documentos vivos.** Tres archivos en `Docs/` que se mantienen al día en cada fase: `DECISIONS.md` (decisiones y razones), `INTERDEPENDENCIAS.md` (qué piezas compartidas alimentan qué features, ver sección 6), y el `README.md` de usuario para Iván (ya existe una primera versión escrita, la actualizas solo si algo del comportamiento final cambia durante la construcción, avisando a Sebas del cambio).

**Git.** Repositorio desde Fase 0. Un commit por fase terminada y validada, con mensaje `Fase N: descripción corta`. Commits intermedios dentro de una fase están bien si son puntos de trabajo coherentes. Nunca commitear una fase como terminada sin que Sebas haya validado sus criterios de aceptación.

**Código limpio.** Nombres de archivo, tipo y función que digan qué hacen sin abrirlos. Un archivo, una responsabilidad. Funciones cortas. Comentarios solo donde el porqué no es obvio (la conversión de coordenadas, la mezcla de audio, el desplazamiento de timestamps en pausa). Nada de lógica duplicada: si dos features necesitan lo mismo, se extrae a una pieza compartida y se registra en INTERDEPENDENCIAS.md.

**Seguridad y privacidad.** Cero conexiones de red. El log nunca registra contenido sensible: se loguea "censura permanente activada", jamás qué había en pantalla ni texto tipeado en anotaciones. Las posiciones de los rectángulos de censura sí se guardan en la configuración (es necesario para el feature), el contenido de pantalla jamás se persiste fuera del video que el usuario decidió grabar. Archivos temporales se limpian al cerrar. Todo corre con permisos de usuario normal.

**Logging.** Un archivo de log por grabación en `~/Library/Logs/Grabador Bloomind/`, con timestamps: inicio, dispositivos seleccionados, cambios de modo, activaciones de censura (el evento, no el contenido), desconexiones de hardware, avisos de disco y memoria, errores, fin. Conservar los últimos 20 logs, borrar los más viejos. El log existe para que un fallo a mitad de una clase de una hora se pueda diagnosticar después sin reproducirlo en vivo.

**Configuración central.** Un solo archivo `config.json` en `~/Library/Application Support/Grabador Bloomind/`, legible a mano. Guarda: atajos asignados, último display, último modo de audio y dispositivo de micrófono, última cámara, posición y tamaño de la burbuja, rectángulo de censura permanente, carpeta de salida, countdown activado o no, posición del widget. Borrar ese archivo equivale a reset de fábrica y la app debe arrancar bien sin él, regenerándolo con defaults.

**Criterios de aceptación verificables por no técnicos.** Cada fase cierra con pasos que Sebas ejecuta usando la app, nunca leyendo código. "Abrí, grabá 2 minutos, movete entre pantallas, el archivo reproduce bien" sí. "Verificar que la función X retorna Y" no.

**Estabilidad de memoria.** Toda fase que toque el pipeline de frames incluye una prueba de memoria: grabar varios minutos con lo construido hasta el momento activo, comparar la memoria de la app en Monitor de Actividad entre el minuto 2 y el final. Deben ser valores parecidos y estables. Crecimiento sostenido es fallo de la fase aunque el video salga bien. Técnicas obligatorias: autoreleasepool por frame donde aplique, nunca retener buffers de frames más allá de su procesamiento, y si el compositor se atrasa, descartar frames en vez de encolarlos sin límite.

**Resiliencia de hardware.** El equipo usa DJI Mic Mini vía iPhone (Continuity), AirPods, GoPro en modo webcam. Todos se desconectan solos (batería, bloqueo del teléfono, Bluetooth). Regla: si un dispositivo de audio o cámara se cae a mitad de grabación, la grabación continúa con lo que quede disponible, la app muestra un aviso visible y lo registra en el log. Crashear o seguir grabando en silencio sin avisar son ambos inaceptables.

**Permisos con mensajes claros.** La app necesita cuatro permisos: Grabación de pantalla y audio del sistema, Micrófono, Cámara, Accesibilidad. Si falta alguno al intentar usar la función que lo requiere, la app dice exactamente cuál falta y abre el panel correcto de Configuración del Sistema. Nunca fallar en silencio ni cerrarse sola.

## 6. Piezas compartidas (semilla de INTERDEPENDENCIAS.md)

Este es el mapa inicial. Está organizado por pieza compartida, no por feature, porque así se ve qué se puede romper al tocar cada cosa. En Fase 0 lo copias a `Docs/INTERDEPENDENCIAS.md` y lo mantienes al día: cada vez que una pieza gane o pierda un consumidor, se actualiza. Antes de modificar cualquier pieza de esta lista, lees su entrada y revisas todos sus consumidores.

- **Conversión de coordenadas** (módulo único, escrito una sola vez): la usan el círculo de cursor, el efecto de clic, el JSON de cursor, la capa de dibujo, el tablero, la censura, el selector de rectángulo y la burbuja. Es la pieza más compartida del proyecto. Detalle crítico: origen abajo izquierda en eventos de mouse vs arriba izquierda en píxeles del frame, factor de escala Retina por display, y con dos monitores cada display tiene su propio espacio de coordenadas y su propio factor de escala.
- **Tracking global del mouse** (posición y clics): alimenta círculo, efecto de clic, JSON de cursor, y el dibujo cuando los modos de dibujo están activos.
- **Motor de dibujo** (trazos, cuadros de texto, colores, deshacer, borrar): lo usan el tablero y la capa de anotación sobre pantalla. Contenidos separados por superficie, motor único.
- **Selector de rectángulo en pantalla** (arrastrar para definir una zona): lo usan los dos slots de censura y la grabación de área personalizada.
- **Pipeline de composición de frames** (fondo según modo más capas según matriz de visibilidad): consume todo lo anterior y alimenta al escritor de video.
- **Escritor de video y audio** (AVAssetWriter, fragmentos, pausa con desplazamiento de timestamps): lo alimentan el pipeline de composición y las fuentes de audio.
- **Registro de acciones y atajos**: lo consumen todos los features operables con teclado, la pantalla de preferencias y la tarjeta de recordatorio.
- **Configuración central**: la leen y escriben casi todos los módulos.
- **Enumeración de dispositivos** (patrón común para micrófonos y cámaras): listas dinámicas que se actualizan en vivo al conectar o desconectar, con la resiliencia de la sección 5.

## 7. Puntos técnicos delicados

Léelos completos antes de cada fase que los toque.

1. **Coordenadas.** Ya descrito en la sección 6. Todo pasa por el módulo único. Si el círculo aparece desfasado, el bug está ahí y solo ahí.
2. **Mezcla de audio.** Combinar las muestras PCM de sistema y micrófono en un solo track es la parte más delicada del proyecto. Homogeneizar sample rates antes de sumar, sumar con headroom o limitador suave para no saturar. Probarla aislada. Si la Fase 5 se traba, se aísla en un proyecto de prueba mínimo antes de seguir integrando.
3. **Sincronización.** El AVAssetWriter arranca su sesión con el timestamp del primer buffer que llegue, de cualquier track, y todos los tracks referencian ese origen. Con pausa: al reanudar se desplazan los timestamps de todos los tracks por la duración de la pausa, para que el archivo no tenga huecos. El JSON de cursor usa el mismo reloj del video final (descontando pausas), así VideoFlow no necesita saber nada de la pausa.
4. **Memoria del pipeline.** Ya descrito en la sección 5. Es la causa clásica de la app que se cae en el minuto 55.
5. **Fragmentos.** Configurar el escritor para producir fragmentos periódicos (por ejemplo cada pocos segundos). Verificable matando el proceso a la fuerza a mitad de grabación: el archivo debe reproducir hasta cerca del punto de la muerte.
6. **Exclusión de ventanas propias.** El filtro de captura excluye todas las ventanas de la app, y esa exclusión debe cubrir ventanas creadas después de iniciar la grabación (el espejo del tablero se abre a mitad de sesión, por ejemplo).
7. **Atajos globales y captura de teclado.** Los atajos de grabación se registran globales solo mientras se graba, para no robarle combinaciones al sistema el resto del tiempo. El único global permanente mientras la app corre es iniciar/detener. En modos de dibujo, el teclado solo se captura mientras un cuadro de texto está activo; los atajos con modificadores siguen funcionando siempre.
8. **Cambio de dispositivos en caliente.** Enumeraciones dinámicas y manejo del evento de desconexión sin detener la grabación.

## 8. Especificación funcional completa

### 8.1 Captura

- Selector de display (Sebas tiene dos pantallas). Se elige antes de grabar, en el panel.
- Grabación de área personalizada: opción de arrastrar un rectángulo dentro de un display y grabar solo eso. Usa el selector de rectángulo compartido. El video de salida tiene las dimensiones del área elegida.
- Resolución nativa del display (o del área), 30 fps, cursor del sistema visible en la captura.
- El fondo de pantalla se sigue capturando en todos los modos aunque no se esté mostrando, para que el regreso al modo pantalla sea instantáneo.

### 8.2 Audio

- Tres modos: solo micrófono, solo sistema, ambos mezclados en un solo track. Los tres funcionan de forma independiente.
- Sub selector de dispositivo de micrófono: lista dinámica de todo lo disponible (integrado, USB, Bluetooth, iPhone por Continuity, que es como entra el DJI Mic Mini). La lista se refresca en vivo al conectar o desconectar dispositivos.
- Indicador de nivel de audio en el panel antes de grabar, mostrando en vivo que el dispositivo elegido capta sonido. Existe para no perder una hora por un micrófono mal seleccionado.
- El audio nunca se interrumpe por cambios de modo de video.

### 8.3 Cámara

- Sub selector de cámara: lista dinámica (integrada, webcams USB, iPhone por Continuity, GoPro en modo webcam). Mismo patrón que micrófonos.
- Captura siempre a la resolución completa del dispositivo.
- Burbuja: se compone en el frame, arrastrable y redimensionable durante la grabación (la interacción es sobre una ventana espejo excluida de la captura; la posición y tamaño se reflejan en la composición). Posición y tamaño persisten en configuración.
- Botón para apagar y prender la burbuja en el widget.

### 8.4 Modos de fuente y matriz de visibilidad

Tres modos que definen el fondo del frame: Pantalla (la captura), Cámara completa (la cámara recortada al centro para llenar el cuadro), Tablero (lienzo blanco). El cambio es con atajo, instantáneo, corte directo. Las fuentes siguen corriendo de fondo en todos los modos.

Matriz de visibilidad de capas (esto se implementa tal cual, no se improvisa):

| Capa | Pantalla | Cámara completa | Tablero |
|---|---|---|---|
| Círculo de cursor | Sí | No | Sí |
| Efecto de clic | Sí | No | Sí |
| Burbuja de cámara | Sí | No | Sí |
| Censura (ambos slots) | Sí | No | No |
| Capa de anotación de pantalla | Sí, si está prendida | No | No |
| Contenido del tablero | No | No | Sí |

El estado de cada capa (censura prendida, anotaciones existentes) se conserva al cambiar de modo; la matriz solo define qué se compone en cada momento.

### 8.5 Cursor, clics y JSON para VideoFlow

- Círculo amarillo #FFD700, semitransparente (relleno entre 55 y 65 por ciento de opacidad, borde algo más opaco), tamaño proporcional a la resolución.
- Efecto de clic: animación breve tipo onda al hacer clic, visualmente distinta del círculo fijo.
- En modo Pantalla, si el mouse se va al monitor no grabado, el círculo desaparece del video y el JSON registra el evento de salida.
- Junto a cada video se escribe `<mismo nombre>.cursor.json` con este esquema:

```json
{
  "version": 1,
  "video": { "ancho": 3456, "alto": 2234, "fps": 30 },
  "eventos": [
    { "t": 0.033, "tipo": "mov", "x": 1200, "y": 800 },
    { "t": 1.500, "tipo": "click", "x": 1300, "y": 850 },
    { "t": 45.200, "tipo": "fuera" },
    { "t": 120.000, "tipo": "modo", "valor": "camara" }
  ]
}
```

Coordenadas en píxeles del video final (ya convertidas, VideoFlow no necesita saber nada de macOS). Tiempos en segundos del video final, descontando pausas y countdown. Movimientos muestreados a la cadencia del frame. Los eventos de modo permiten que VideoFlow sepa qué segmentos son de pantalla y aplique el zoom automático solo ahí.

### 8.6 Censura en vivo

- Dos slots independientes: Permanente (persiste en disco, caso barra de direcciones del VPS) y De sesión (solo en memoria, muere al cerrar la app).
- Comportamiento por slot: la primera vez que se usa su atajo sin rectángulo definido, entra en modo dibujar (arrastrás el rectángulo y queda fijado). De ahí en adelante el mismo atajo prende y apaga la tapa al instante. Modificador Shift junto al atajo fuerza el modo dibujar aunque ya exista posición guardada.
- Estilo: bloque sólido opaco por defecto. Blur disponible como opción por slot en preferencias, para contenido menos sensible.
- El widget muestra un indicador visible de censura activa, para saber sin adivinar si la zona está tapada.
- El log registra activaciones y desactivaciones como eventos, jamás posiciones ni contenido.

### 8.7 Dibujo: tablero y capa de anotación

- Motor de dibujo compartido: trazos a mano alzada con el mouse, cuadros de texto con el teclado (clic crea el cuadro, se tipea, Esc o clic afuera lo cierra), color activo de la paleta, deshacer último trazo, borrar superficie.
- Paleta: rojo, amarillo, verde, blanco, negro. Un atajo rota el color. El widget muestra el color activo cuando un modo de dibujo está prendido.
- Grosor de trazo fijo en v1, proporcional a la resolución.
- **Tablero**: tercera fuente de video. Al activarlo se muestra una ventana espejo a pantalla completa sobre el monitor grabado (excluida de la captura) donde Sebas ve y dibuja; el compositor dibuja el mismo contenido desde el modelo de datos sobre el lienzo del archivo. El mouse interactúa con el espejo, no con las apps de abajo.
- **Capa de anotación sobre pantalla real**: un atajo la prende y apaga. Prendida: ventana transparente (excluida de la captura) sobre el monitor grabado donde se dibuja y escribe; el contenido se compone en el frame; el mouse va a la capa, no a la app de abajo. Apagada: la ventana se oculta, el mouse vuelve a la app real, y el contenido queda guardado, listo para reaparecer al prenderla de nuevo.
- Borrar es siempre una acción deliberada con su atajo, y borra únicamente la superficie de dibujo activa en ese momento (tablero si estás en el tablero, capa si la capa está prendida). Nunca borra ambas. Sin confirmación, porque interrumpiría la clase, pero con deshacer disponible.

### 8.8 Atajos de teclado

Sistema central: registro único de acciones, cada una con su combinación. Pantalla de preferencias con la lista completa, clic sobre una combinación y tecleo de la nueva para reasignar, con detección de conflictos entre atajos propios. Todo persiste en la configuración.

Defaults propuestos (todos reasignables; al implementar, verificar que no choquen con atajos del sistema activos):

| Acción | Atajo por defecto | Activo |
|---|---|---|
| Iniciar / detener grabación | Control Opción Comando G | Siempre que la app corre |
| Modo Pantalla | Opción Comando 1 | Durante grabación |
| Modo Cámara completa | Opción Comando 2 | Durante grabación |
| Modo Tablero | Opción Comando 3 | Durante grabación |
| Pausar / reanudar | Opción Comando P | Durante grabación |
| Reiniciar toma | Opción Comando R | Durante grabación |
| Censura permanente on/off | Opción Comando C | Durante grabación |
| Censura de sesión on/off | Opción Comando X | Durante grabación |
| Redibujar censura (cualquier slot) | Shift más el atajo del slot | Durante grabación |
| Capa de anotación on/off | Opción Comando D | Durante grabación |
| Rotar color del marcador | Opción Comando 0 | Durante grabación |
| Deshacer último trazo | Opción Comando Z | Modos de dibujo |
| Borrar superficie de dibujo activa | Opción Comando Delete | Modos de dibujo |
| Tarjeta de atajos (mantener presionado) | Opción Comando barra diagonal | Durante grabación |

- La tarjeta de atajos: mientras se mantiene presionada la combinación, aparece una tarjeta translúcida en una esquina con la lista de atajos activos y sus teclas. Al soltar desaparece. Es una ventana propia: excluida de la captura, invisible en el video.
- Fuera de grabación no se registra ningún atajo global salvo iniciar/detener, para no robarle combinaciones al resto del sistema.

### 8.9 Control de grabación

- Cuenta regresiva 3, 2, 1 antes de arrancar (configurable on/off). El archivo empieza después del conteo.
- Widget flotante durante la grabación: pequeño, arrastrable, siempre encima, excluido de la captura. Muestra tiempo transcurrido, estado (grabando o pausado), modo activo, indicador de censura activa, color del marcador cuando aplica. Botones: pausar/reanudar, detener, reiniciar toma, burbuja on/off.
- Pausar congela todos los tracks coherentemente; reanudar es inmediato, sin conteo.
- Reiniciar toma: detiene, manda el archivo actual a la Papelera, arranca una toma nueva de inmediato con la misma configuración. El nombre de archivo incluye la hora de inicio, así que nunca colisiona.
- Al detener: notificación con el nombre del archivo y acceso directo a la carpeta.
- Aviso de espacio en disco: antes de arrancar, si hay menos de 20 GB libres se avisa. Durante la grabación se monitorea; con menos de 10 GB aviso visible, con menos de 2 GB la app detiene la grabación de forma limpia guardando lo grabado, en vez de dejar que el sistema colapse el archivo. Umbrales configurables en el código en un solo lugar.

### 8.10 Panel de configuración pre grabación

Aparece al iniciar una grabación (o desde el menu bar). Contiene: display o área personalizada, modo de audio y dispositivo de micrófono con su indicador de nivel en vivo, cámara, nombre de la sesión, carpeta de salida, countdown on/off. Todo con memoria pegajosa: cada campo recuerda el último valor usado y arranca ahí. Elegir una vez, grabar muchas.

### 8.11 Menu bar

La app vive en la barra de menú, sin ícono en el Dock (LSUIElement). Ícono con estados distinguibles: inactivo, grabando, pausado. Menú: Iniciar grabación (abre el panel), Detener, Abrir carpeta de grabaciones, Preferencias (atajos y opciones), Salir.

### 8.12 Archivos de salida

- Carpeta por defecto `~/Movies/Grabador Bloomind/`, cambiable en el panel.
- Nombre: `AAAA-MM-DD HHhMM - Nombre de sesión.mov` y su `.cursor.json` gemelo.
- Video HEVC por hardware, audio AAC 48 kHz, contenedor QuickTime (`.mov`) con fragmentos periódicos. Se eligió `.mov` sobre `.mp4` porque la recuperación de un archivo truncado a la fuerza es notoriamente más confiable en el contenedor QuickTime, y la resistencia a fallos es requisito desde la Fase 1 (decisión 11). QuickTime, ffmpeg y Whisper leen `.mov` con HEVC sin diferencia alguna respecto a `.mp4`, así que VideoFlow no se ve afectado.

### 8.13 Identidad visual

Toda la interfaz de la app sigue la identidad Bloomind, la misma de CLM, whatasAPI y Bloomind Oficinas. La guía canónica es la sección 5 de `~/CLM Bloomind/docs/instructivo.md`, y en este proyecto está traducida a AppKit en `UI/BloomindStyle.swift`.

Resumen operativo: tema oscuro sobre Azul Profundo `#0F1A2C`, superficies elevadas `#16243D`, texto blanco con secundario `#8CA3C4`, acento Azul Lab `#3A7BFF` con hover `#1F4DFF`, turquesa `#45D3C5` **exclusivo** para éxito, coral `#F0857A` para error y alerta, hairlines `#26364F`. Tipografía display Fraunces (vendorizada en el bundle), sans del sistema para interfaz y monoespaciada para datos técnicos.

Las cuatro reglas que no se rompen: colores planos sin degradados, profundidad con hairlines y no con sombras, aire generoso, y el turquesa reservado para el éxito.

Aplica a todo lo visible: panel de configuración, widget flotante, preferencias, tarjeta de atajos, countdown y avisos. No aplica a lo que se compone dentro del video, que se rige por la sección 8.5 (el círculo amarillo del cursor es `#FFD700` y no cambia).

## 9. Fases de construcción

Regla general: una fase a la vez. Cada fase termina cuando Sebas ejecuta sus criterios de aceptación y da el visto bueno. Solo entonces se hace el commit de cierre de fase y se arranca la siguiente. Si una fase revela que algo del plan no funciona como se pensó, se detiene, se documenta en DECISIONS.md la situación y se consulta con Sebas.

### Fase 0. Setup

Crear el proyecto Swift Package Manager (Swift, AppKit, macOS 15 mínimo) con su script de construcción del bundle `.app`. Git init con .gitignore apropiado para Swift y macOS. Info.plist con las descripciones de uso de micrófono y cámara y LSUIElement. Estructura de carpetas según los módulos de la sección 6 (App, Captura, Audio, Camara, Composicion, Coordenadas, EntradaGlobal, Dibujo, Censura, Escritura, Configuracion, UI, Registro, Docs). Crear `Docs/DECISIONS.md` con las 14 decisiones de la sección 4, `Docs/INTERDEPENDENCIAS.md` con la sección 6, y copiar el README de Iván al repo. Crear el módulo de configuración central (leer, escribir, defaults si el archivo no existe). Crear el módulo de logging. Crear `CLAUDE.md` en la raíz con: instrucción de leer DECISIONS.md e INTERDEPENDENCIAS.md al inicio de cada sesión, el protocolo de la sección 10 resumido, y las reglas de seguridad (cero red, nada sensible en logs). Verificar que ambas Macs corren macOS 15 o superior.

Aceptación (Sebas): el proyecto compila y corre mostrando un ícono en la barra de menú con un menú de Salir. En la carpeta del proyecto están los tres documentos con su contenido. Existe el archivo de configuración tras el primer arranque.

### Fase 1. Captura de pantalla y escritor resistente

Enumerar displays y capturar el elegido (elección temporal por código o ventana simple, el panel llega en Fase 11). Configuración de captura según 8.1. Escritor de video con fragmentos periódicos desde ya, diseñado con la abstracción de sesión que contempla pausa (la pausa real se implementa en Fase 5, pero la interfaz nace aquí para no refactorizar). Exclusión de todas las ventanas propias en el filtro de captura, incluyendo las creadas después de iniciar. Iniciar y detener desde una ventana temporal.

Aceptación: grabar 3 minutos de cada una de las dos pantallas por separado; ambos archivos reproducen bien en QuickTime. Grabar 2 minutos y forzar el cierre de la app desde Monitor de Actividad a mitad de grabación: el archivo resultante reproduce hasta cerca del momento del cierre. La ventana temporal de la app no aparece en ningún video.

### Fase 2. Compositor, cursor, clics y JSON

Módulo único de conversión de coordenadas (con soporte de dos monitores y factores de escala distintos). Tracking global de mouse. Pipeline de composición de capas sobre el frame (diseñado desde ya para la matriz de la sección 8.4, aunque por ahora solo exista la capa del círculo). Círculo amarillo según 8.5. Efecto de clic. Escritura del `.cursor.json` sincronizado.

Aceptación: grabar moviendo el mouse por toda la pantalla y haciendo clics; el círculo sigue el cursor sin desfase perceptible y los clics muestran su efecto. Mover el mouse al segundo monitor: el círculo desaparece del video limpiamente. Junto al video aparece el archivo `.cursor.json` y al abrirlo se ven eventos con números que crecen en el tiempo. Prueba de memoria de 10 minutos según la regla de la sección 5.

### Fase 3. Micrófono

Enumeración dinámica de dispositivos de entrada (la lista se refresca al conectar y desconectar). Captura del micrófono elegido vía ScreenCaptureKit y escritura sincronizada con el video. Indicador de nivel de audio consultable (UI mínima temporal; se integra al panel en Fase 11). Resiliencia: desconexión del dispositivo a mitad de grabación deja el video corriendo y avisa.

Aceptación: grabar 5 minutos hablando con los AirPods; voz y video sincronizados al inicio y al final. Conectar el iPhone y verificar que aparece en la lista como micrófono, elegirlo y grabar un minuto con el DJI. A mitad de una grabación con AirPods, guardarlos en el estuche: la app avisa visiblemente, la grabación continúa y el archivo final reproduce bien.

### Fase 4. Audio del sistema

Captura del audio del sistema como modo independiente (solo sistema, sin micrófono).

Aceptación: grabar 2 minutos con música sonando y sin hablar; el archivo tiene el audio del sistema limpio y sincronizado.

### Fase 5. Mezcla y pausa real

Mezcla de micrófono y sistema en un solo track según el punto delicado 2. Selector interno de los tres modos de audio funcionando (UI mínima temporal). Implementación real de pausar y reanudar con desplazamiento de timestamps en todos los tracks. Si la mezcla se traba, aislarla en un proyecto de prueba mínimo antes de seguir.

Aceptación: grabar hablando mientras suena música; ambos se escuchan claros, sin saturación, en un solo audio. Probar los tres modos de audio en tres grabaciones cortas. En una grabación de 3 minutos, pausar al minuto 1 por 30 segundos y reanudar: el archivo final dura 2 minutos y medio aproximadamente, sin hueco ni salto de audio, y la sincronización se mantiene después de la pausa.

### Fase 6. Cámara: burbuja y modo cámara completa

Enumeración dinámica de cámaras. Captura a resolución completa. Burbuja compuesta, arrastrable y redimensionable vía ventana espejo, con persistencia de posición y tamaño. Modo Cámara completa con recorte centrado y cambio por atajo (atajos fijos temporales, el sistema central llega en Fase 9). Resiliencia a desconexión de cámara.

Aceptación: grabar con la burbuja visible, arrastrarla y cambiarle el tamaño en vivo; todo queda reflejado en el video y la ventana espejo no aparece. Cambiar a cámara completa y volver con el atajo varias veces: cortes instantáneos, sin congelones ni saltos de audio. Probar con la cámara del iPhone por Continuity. Apagar la cámara a mitad de grabación: aviso visible y la grabación sigue.

### Fase 7. Tablero

Motor de dibujo compartido (trazos, cuadros de texto, paleta con rotación de color, deshacer, borrar). Tablero como tercera fuente con su ventana espejo a pantalla completa sobre el monitor grabado. Círculo de cursor y burbuja compuestos también en modo tablero según la matriz. Implementación de la matriz de visibilidad completa de la sección 8.4.

Aceptación: en una grabación, pasar de pantalla a tablero con el atajo, dibujar trazos, cambiar de color, escribir un cuadro de texto con el teclado, deshacer un trazo, borrar el tablero, volver a modo pantalla y seguir usando la app de abajo con normalidad. Todo lo dibujado aparece en el video; la ventana espejo no. La censura y la capa de anotación no aparecen en el tablero.

### Fase 8. Capa de anotación sobre pantalla real

Capa con el mismo motor de dibujo, sobre el monitor grabado, con el comportamiento de prender, apagar con persistencia de contenido, y borrado independiente del tablero.

Aceptación: grabando en modo pantalla, prender la capa, dibujar una flecha y escribir un texto sobre una app real, apagar la capa y comprobar que el mouse vuelve a controlar la app de abajo, prender de nuevo y comprobar que el dibujo sigue ahí, borrarlo con el atajo de borrar. Verificar que borrar la capa no tocó el contenido del tablero de la fase anterior y viceversa.

### Fase 9. Sistema de atajos y tarjeta de recordatorio

Registro central de acciones. Migración de todos los atajos fijos temporales al sistema central con los defaults de la tabla 8.8. Pantalla de preferencias con reasignación y detección de conflictos. Persistencia. Tarjeta translúcida de recordatorio al mantener presionada su combinación. Atajos globales solo durante grabación salvo iniciar/detener.

Aceptación: abrir preferencias, ver la lista completa con sus combinaciones, reasignar el atajo de modo tablero a otra combinación, usarlo en una grabación y verlo reflejado en la tarjeta de recordatorio. Intentar asignar una combinación ya usada por otra acción: la app lo señala. Con la app corriendo sin grabar, verificar que Opción Comando 1 sigue funcionando normal en Finder.

### Fase 10. Censura

Los dos slots según 8.6, sobre el selector de rectángulo compartido (que nace aquí y en la Fase 11 reutiliza el área personalizada). Indicador de censura activa en una UI mínima (el widget definitivo llega en Fase 11). Bloque sólido por defecto, blur como opción en preferencias. Silencio total sobre contenido en logs.

Aceptación: primera pulsación del atajo permanente abre el modo dibujar; tapar la barra de direcciones del navegador; verificar en el video que la zona queda con bloque sólido mientras estuvo activa y destapada cuando se apagó. Cerrar la app, reabrirla, grabar de nuevo: el atajo permanente tapa la misma zona sin redibujar. El slot de sesión, tras cerrar la app, pide dibujar de nuevo. Shift más el atajo permite reposicionar. Revisar el log de la grabación: menciona activaciones, jamás coordenadas.

### Fase 11. Panel, widget, countdown y flujo completo

Panel de configuración pre grabación completo según 8.10, con memoria pegajosa, indicador de nivel de audio integrado y área personalizada (reutilizando el selector de rectángulo). Widget flotante definitivo según 8.9. Countdown. Reiniciar toma con Papelera. Avisos de disco con los tres umbrales. Menu bar definitivo con estados. Notificación al detener.

Aceptación: flujo completo de punta a punta sin tocar nada técnico: abrir desde el menu bar, configurar en el panel (pantalla, ambos audios con el DJI, cámara del iPhone, nombre "Prueba n8n", carpeta), countdown, grabar usando pausa, cambio de modos, censura y dibujo desde el widget y los atajos, reiniciar una toma y comprobar que la descartada quedó en la Papelera, detener y llegar al archivo desde la notificación. Cerrar la app, reabrirla, iniciar de nuevo: el panel recuerda todo lo elegido. Grabar un área personalizada y verificar que el video tiene solo esa zona.

### Fase 12. Endurecimiento y entrega

Prueba de fuego: una grabación real de 60 minutos con todo activo (círculo, burbuja, cambios de modo, censura, anotaciones, mezcla de audio). Verificación de memoria entre minuto 5 y minuto 55. Verificación de sincronización de audio al inicio y al final (dar una palmada frente a la cámara al arrancar y otra antes de terminar; en el archivo, sonido e imagen de ambas palmadas deben calzar). Detección de grabación interrumpida: si la app se abre y encuentra una grabación que no cerró bien, avisa que existe un archivo recuperable y ofrece abrir su carpeta. Revisión de logs de la prueba larga. Limpieza de temporales verificada. Exportar el `.app`, pasarlo a la Mac de Iván, seguir el README para autorizarlo en Gatekeeper y dar los permisos, y grabar 5 minutos allá. Revisión final del README contra el comportamiento real, actualizando lo que haya cambiado.

Aceptación: el archivo de una hora reproduce completo, con audio sincronizado en ambas palmadas, y la memoria se mantuvo estable. En la Mac de Iván, la app se instaló y grabó siguiendo solo el README, sin ayuda de nadie.

## 10. Protocolo de trabajo por sesión

1. Al comenzar cada sesión de Claude Code: leer `CLAUDE.md`, `Docs/DECISIONS.md` y `Docs/INTERDEPENDENCIAS.md`.
2. Trabajar en una sola fase. No adelantar trabajo de fases futuras aunque parezca eficiente.
3. Antes de tocar una pieza listada en INTERDEPENDENCIAS.md, revisar sus consumidores y avisar en el resumen de la sesión qué features quedan potencialmente afectados y deben reverificarse.
4. Toda decisión técnica no obvia va a DECISIONS.md en el momento.
5. Al terminar la fase: actualizar los documentos vivos, dejar por escrito los pasos de aceptación listos para que Sebas los ejecute, y esperar su validación. Con el visto bueno, commit de cierre de fase.
6. Si algo se traba más de lo razonable, especialmente la mezcla de audio, aislar el problema en un proyecto de prueba mínimo en vez de acumular intentos sobre el proyecto principal.
7. Nunca inventar features ni cambiar comportamiento especificado sin consultar. El plan es la fuente de verdad; los vacíos del plan se resuelven preguntando, no asumiendo.

## 11. Definición de terminado

El proyecto está terminado cuando la Fase 12 pasa completa: la grabación de una hora sobrevive con memoria estable y audio sincronizado, la app corre en la Mac de Iván instalada solo con el README, los tres documentos vivos reflejan la realidad del código, y el repositorio tiene un commit limpio por cada fase validada.

## 12. Cómo arrancar

Mensaje inicial sugerido para Claude Code, parado en la carpeta donde vivirá el proyecto y con este documento y el README de Iván dentro:

"Lee completo el archivo plan-maestro-grabador.md de esta carpeta. Es la fuente de verdad del proyecto. Cuando lo hayas leído, confirma que entendiste el protocolo de trabajo de la sección 10 y ejecuta la Fase 0. No avances a la Fase 1: al terminar la Fase 0 me entregas los pasos de aceptación para que yo los verifique."
