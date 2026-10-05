# Brief — rediseño Grabador Bloomind (3 direcciones)

Producto: grabador de pantalla nativo de macOS (AppKit) para que Sebastián e Iván, abogados que enseñan IA, graben clases de una hora. Lo usan dando clase: todo tiene que leerse de reojo, a un metro, con la cabeza en otra parte. Cada maqueta se va a implementar después en AppKit, así que nada que AppKit no pueda hacer razonablemente (sin WebGL, sin blur de fondo como recurso principal, fuentes OFL que se puedan empaquetar).

Sebas eligió: identidad libre (que cada dirección proponga), rediseñar estructura (mismas funciones, nueva organización), todas las pantallas, 3 maquetas y elige una.

Feedback previo de Sebas: rechazó maquetas que eran "la misma pantalla con otra paleta" y todo lo que huela a IA (crema + serif + terracota; negro + un acento ácido; estilo periódico sin radios). Nada de líneas separadoras decorativas tipo `---`. Quiere composición propia, un elemento firma, íconos dibujados (SVG propios, trazo coherente, no emojis), estados reales y movimiento con intención.

## Inventario funcional (no se puede perder nada)

**Panel (antes de grabar):** pantalla (lista de pantallas: "Built-in Retina Display · 2880×1800") + elegir área / pantalla entera; modo de audio (Micrófono / Sonido del sistema / Micrófono + sistema / Sin audio); micrófono (lista, ej. "Micrófono DJI vía iPhone", "AirPods de Sebastián") con medidor de nivel en vivo; cámara (Sin cámara / FaceTime HD / iPhone de Sebastián); guion del teleprompter (texto escrito a mano + archivos cargados: "Intro", "Desarrollo", "Cierre"; cargar archivos; quitar), velocidad (0.5–10) y tamaño de letra (16–96); nombre de la sesión ("Clase 2.5 · n8n con cámara"); carpeta de salida (~/Movies/Grabador Bloomind); cuenta regresiva 3-2-1 sí/no; botón Iniciar grabación; línea de estado (errores de permisos aquí). Restricción dura: la pantalla útil es 1440×870 pt (MacBook Air 13"). El panel actual mide 938 pt y se sale: el nuevo tiene que caber con holgura.

**Widget flotante (durante la grabación):** cronómetro, estado (grabando / pausado), renglón de detalle (modo, "anotando", "censura", "sin cursor", "micrófono mudo", "SIN AUDIO"), punto con el color del marcador cuando se dibuja. Acciones: pausar/reanudar, detener, reiniciar toma (con confirmación), cámara on/off (+ menú para elegir cámara), silenciar micrófono, silenciar sonido del PC, guion on/off. Modos: pantalla, cámara completa, tablero. Tablero: color de lienzo (blanco/negro), deshacer, borrar. Comandos: resaltado de cursor, censura on/off, redibujar censura, marcador on/off, rotar color de marcador (rojo, amarillo, verde, blanco, negro), tarjeta de atajos. Teleprompter: play/pausa, al inicio, más lento, más rápido, letra −, letra +, editar/leer. Hoy son 27 botones a la vista en modo expandido: es una pared. Hay que resolverlo (agrupar, revelar por contexto, etc.) sin esconder lo que se usa a cada rato. Estados de alerta (mudo, censura) tienen que gritar; lo normal, callar. El widget flota encima de CUALQUIER cosa (hoja de Excel blanca, n8n, una presentación oscura): tiene que leerse sobre todas.

**Teleprompter:** ventana flotante, pestañas de guiones, texto grande con línea de lectura, la barra con los controles de arriba, indicaciones de teclas (espacio = play), velocidad y letra actuales, modo edición.

**Tarjeta de atajos** (se ve mientras se mantiene ⌥⌘H): 19 atajos, combinaciones alineadas en columna. Lista: Iniciar/detener ^⌥⌘G · Modo pantalla ⌥⌘1 · Modo cámara completa ⌥⌘2 · Modo tablero ⌥⌘3 · Pausar/reanudar ⌥⌘P · Capa de anotación ⌥⌘D · Resaltado del cursor ⌥⌘A · Rotar color del marcador ⌥⌘0 · Tablero blanco/negro ⌥⌘B · Deshacer último trazo ⌥⌘Z · Borrar la superficie activa ⌥⌘⌫ · Reiniciar toma ⌥⌘R · Censura on/off ⌥⌘C · Redibujar la zona censurada ⇧⌥⌘C · Silenciar micrófono ⌥⌘M · Silenciar audio del sistema ⌥⌘S · Teleprompter on/off ⌥⌘T · Mostrar/esconder el widget ⌥⌘W · Tarjeta de atajos ⌥⌘H.

**Cuenta regresiva** 3, 2, 1 centrada en la pantalla antes de arrancar (no sale en el video).

**Burbuja de cámara:** círculo arrastrable y redimensionable con la cámara en vivo.

**Selector de área:** pantalla completa oscurecida, se arrastra un rectángulo, título "Elegí el área a grabar", medidas en vivo, Enter confirma / Esc cancela.

**Barra de menú:** ícono (silueta del cerebro de Bloomind; usar un placeholder simple) con estados reposo / grabando / pausado, y su menú (Iniciar grabación…, Detener grabación, Abrir carpeta de grabaciones, Atajos…, Salir).

## Formato de la maqueta

Un solo HTML autocontenido por dirección (`direccion-a.html`, etc.), fuentes desde Google Fonts, sin otras dependencias. Un lienzo que simula el escritorio de una Mac de 1440×900 con una app real detrás (alternar fondo: hoja de cálculo blanca / editor de flujos oscuro tipo n8n / foto) para probar contraste, y encima las piezas. Un selector arriba para cambiar de escena: **Antes de grabar** (panel + burbuja), **Cuenta regresiva** (animada), **Grabando** (widget + teleprompter + burbuja), **Problemas** (pausado, micrófono mudo, censura, tablero con marcador amarillo), **Atajos** (tarjeta), **Elegir área** (selector). El widget compacto y expandido tienen que poder verse (un toggle). Hover y presionado reales en los botones. Textos en español de Colombia con voseo como el resto de la app ("Elegí", "Tocá"). Respetar `prefers-reduced-motion`.

Al inicio del HTML, un bloque de comentario con el sistema: paleta (hex con nombre), tipografías y sus roles, la composición en una frase por pieza, y el elemento firma.
