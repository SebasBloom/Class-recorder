# Decisiones del proyecto

Registro de toda decisión técnica no obvia, con su razón y la alternativa descartada. Se escribe en el momento en que se toma, no al final. Las decisiones 1 a 14 vienen cerradas desde el plan maestro y no se reabren sin hablar con Sebas.

## Decisiones de partida (plan maestro, sección 4)

**1. App nativa Swift, no Electron ni extensión de navegador.**
Razón: tiene que censurar y dibujar sobre cualquier app (terminal, editores, todo el escritorio), no solo pestañas de Chrome.
Alternativa descartada: extensión de Chrome, limitada al navegador.

**2. Grabador y VideoFlow son dos herramientas separadas.**
Razón: mundos tecnológicos distintos (Swift nativo vs Python); fusionarlos es la peor relación esfuerzo/resultado.
Alternativa descartada: empacar Python dentro de la app de Mac. Queda como opción futura si dos íconos resultan incómodos.

**3. Efectos compuestos en el archivo, no en la pantalla real.**
El círculo, la burbuja, la censura y el dibujo se pintan sobre cada frame antes de escribirlo. Lo que Sebas ve en su pantalla son ventanas espejo propias, excluidas de la captura.
Razón: el archivo sale terminado y ninguna ventana propia contamina el video.
Regla derivada: toda ventana de la app se excluye siempre de la captura, sin excepciones. Lo que deba aparecer en el video se compone desde el modelo de datos.

**4. Censura con bloque sólido opaco por defecto, no blur.**
Razón: un difuminado débil puede dejar adivinar texto corto y predecible como una IP.
Alternativa descartada: blur por defecto. Queda como estilo opcional por slot.

**5. Dos slots de censura, permanente y de sesión.**
El permanente persiste en disco (caso: barra de direcciones con el VPS). El de sesión vive solo en memoria y muere al cerrar la app.

**6. El zoom automático al clic NO va en el grabador.**
Razón: en edición el algoritmo puede mirar adelante y atrás en el tiempo antes de decidir; en vivo, no.
El grabador solo exporta el `.cursor.json` con posiciones, clics y cambios de modo.

**7. La cámara captura a resolución completa todo el tiempo**, aunque solo se muestre en burbuja chiquita.
Razón: el modo cámara completa necesita esa resolución y así el cambio de modo es instantáneo.

**8. Cambio de modo con corte directo, sin transiciones**, en v1.

**9. Micrófono y sistema mezclados en un solo track de audio** cuando se eligen ambos.
Razón: VideoFlow transcribe con Whisper y necesita un audio único y limpio.

**10. HEVC con codificación por hardware para video, AAC 48 kHz para audio.**
Razón: una hora a resolución Retina en H.264 pesa demasiado; HEVC en Apple Silicon es eficiente y ffmpeg y Whisper lo leen sin problema.

**11. Archivo resistente a fallos desde la Fase 1**: se escribe con fragmentos periódicos, de modo que si el proceso muere a mitad de grabación lo grabado hasta el último fragmento sigue siendo reproducible.
Alternativa descartada: un archivo que solo es válido si se cierra bien.

**12. Reiniciar toma manda la toma descartada a la Papelera del sistema, nunca borrado directo.**
Razón: red de seguridad barata, coherente con la regla del equipo de nunca destruir información sin salida de emergencia.

**13. Colores del marcador: paleta corta fija que se rota con un atajo** (rojo, amarillo, verde, blanco, negro).
Razón: un selector de color con el mouse rompe la continuidad de la clase. Blanco y negro incluidos porque las herramientas que graba Sebas mezclan temas claros y oscuros.

**14. Cero red.** La app no hace ninguna conexión saliente. Sin telemetría, sin chequeo de actualizaciones, nada.
Razón: es una garantía de confidencialidad verificable, no una preferencia.

## Decisiones tomadas durante la construcción

**15. 2026-07-26 — Contenedor `.mov` en vez de `.mp4`.**
El archivo de salida es `.mov` (contenedor QuickTime) con video HEVC y audio AAC, en vez de `.mp4`.
Razón: la decisión 11 exige que un archivo truncado a la fuerza siga siendo reproducible, y la recuperación de fragmentos truncados es notoriamente más confiable en el contenedor QuickTime que en MP4. Se cambió por adelantado en vez de esperar a que fallara la prueba de la Fase 1.
Alternativa descartada: `.mp4`, que era lo que decía el plan original. Se descartó porque el riesgo de recuperación no compensa nada: QuickTime, ffmpeg y Whisper leen `.mov` con HEVC exactamente igual, así que VideoFlow no se ve afectado y para Iván el archivo se abre con doble clic lo mismo.
Impacto documental: se actualizó la sección 8.12 del plan maestro y la mención de la extensión en el README de Iván.

**16. 2026-07-26 — Swift Package Manager sobre Command Line Tools, sin Xcode.**
El proyecto se compila con `swift build` y un script (`construir.sh`) arma el bundle `.app` con su Info.plist y lo firma.
Razón: Xcode no estaba instalado en la Mac de Sebas y ocupa más de 20 GB de los 42 GB libres que había, en una máquina que va a producir archivos de video de varios GB por clase y cuya propia app avisa al bajar de 20 GB libres. Se verificó que el SDK de las Command Line Tools (macOS 26.5) trae ScreenCaptureKit completo, incluido `captureMicrophone` (macOS 15+), que es la API que sostiene toda la Fase 3.
Alternativa descartada: instalar Xcode. No se pierde nada: si algún día se instala, abre el `Package.swift` directamente sin migrar el proyecto. Lo único que no se tiene es Instruments para perfilar memoria, y el plan ya especifica las pruebas de memoria con Monitor de Actividad.

**17. 2026-07-26 — Certificado autofirmado propio para la firma de código.**
Las compilaciones se firman con un certificado autofirmado del Llavero, no ad-hoc. El nombre de la identidad vive en `.firma-identidad`, fuera de git.
Razón: macOS ata los permisos de TCC (pantalla, micrófono, cámara, accesibilidad) a la identidad del binario. Con firma ad-hoc la identidad cambia en cada recompilación y el sistema vuelve a pedir los cuatro permisos, en un proyecto de 12 fases donde casi todos los criterios de aceptación implican grabar pantalla.
Detalle del entorno: en macOS 26 ya no existe Acceso a Llaveros, así que el certificado se crea por terminal. El paso a paso está en `Docs/FIRMA.md`.
Estado: hecho el 2026-07-26. El certificado se llama "Bloomind Desarrollo" y se verificó que el requisito designado del bundle queda idéntico entre compilaciones, que es lo que hace que los permisos no se reseteen. Nota: el paso de confianza con `sudo` que se creía necesario resultó innecesario; el detalle está en `Docs/FIRMA.md`.

**18. 2026-07-26 — Modo de lenguaje Swift 5, no Swift 6.**
Razón: el modo 6 exige anotaciones de aislamiento de concurrencia en cada callback de AVFoundation y ScreenCaptureKit, que llegan desde colas propias del sistema. Eso convierte cada fase del pipeline de captura en una pelea con el verificador en vez de con el problema real.
Alternativa descartada: modo 6 estricto. Se puede reconsiderar en la Fase 12 si el proyecto queda estable, pero no es un objetivo.

**19. 2026-07-26 — Las carpetas de módulo nacen con su fase, no todas vacías en la Fase 0.**
Solo existen `App/`, `Configuracion/` y `Registro/`, que son las que tienen código. `Captura/`, `Audio/`, `Camara/`, `Composicion/`, `Coordenadas/`, `EntradaGlobal/`, `Dibujo/`, `Censura/`, `Escritura/` y `UI/` se crean cuando su fase las llena.
Razón: git no versiona carpetas vacías, así que dejarlas creadas obliga a inventar archivos de relleno que no hacen nada. El mapa de módulos vive en `INTERDEPENDENCIAS.md`, que es donde se consulta.
Alternativa descartada: diez carpetas con archivos `.gitkeep`.

**20. 2026-07-26 — El README de Iván vive solo en `Docs/README-ivan.md`.**
Razón: es un documento vivo que se actualiza en cada fase donde cambie el comportamiento. Tenerlo en dos rutas garantiza que en algún momento diverjan y que Iván lea el equivocado.
Alternativa descartada: copiarlo a la raíz además de a `Docs/`, como sugería la Fase 0.

**21. 2026-07-26 — Un `config.json` ilegible se aparta, no se pisa.**
Si el archivo de configuración no se puede decodificar, se renombra a `config.json.dañado` y se arranca con los valores por defecto.
Razón: coherente con la decisión 12. Un archivo corrupto puede tener la posición de la censura permanente y los atajos personalizados; destruirlo en silencio para arrancar limpio es exactamente lo que el equipo no hace.

**22. 2026-07-26 — La captura excluye la aplicación entera, no ventanas sueltas.**
El filtro de ScreenCaptureKit se arma con `excludingApplications`, pasándole la app propia, en vez de listar ventanas en `exceptingWindows`.
Razón: la regla derivada de la decisión 3 exige que la exclusión cubra también las ventanas que nacen a mitad de grabación (el espejo del tablero, la tarjeta de atajos, el widget). Una lista de ventanas se arma al iniciar y queda vieja; excluir la aplicación entera cubre todo lo que abra después, para siempre y sin mantenimiento.
Alternativa descartada: enumerar ventanas y mantener la lista al día durante la grabación. Más código y una fuga garantizada el día que alguien agregue una ventana nueva y olvide registrarla.

**23. 2026-07-26 — Ante atraso, se descartan frames; nunca se encolan.**
La cola de la captura es corta (`queueDepth = 5`) y el escritor descarta el frame si la pista todavía no está lista para recibir datos.
Razón: es la regla de memoria de la sección 5 del plan llevada al código. Encolar sin límite es exactamente la causa de la app que se cae en el minuto 55 de una clase de una hora. Un frame perdido a 30 fps no se nota; un crash a los 55 minutos arruina la clase.

**24. 2026-07-26 — `shouldOptimizeForNetworkUse` apagado a propósito.**
Razón: esa opción mueve el índice del archivo al principio cuando se cierra, y un archivo cuyo índice solo existe si el cierre fue limpio es justo lo que la decisión 11 prohíbe. Con fragmentos periódicos y sin esa optimización, un archivo truncado sigue siendo reproducible.

**25. 2026-07-26 — La calidad de video se controla con una sola perilla, bits por píxel.**
El bitrate se calcula como ancho × alto × 30 fps × `bitsPerPixel`, con `bitsPerPixel = 0.09` definido en un solo lugar de `RecordingWriter`.
Razón: el valor correcto depende de la resolución de cada pantalla, así que un bitrate fijo estaría mal en una de las dos Macs. El contenido de pantalla comprime muy bien en HEVC, de ahí que el valor sea bajo. Si un video sale pixelado o si los archivos pesan de más, se toca ese número y nada más.

**26. 2026-07-26 — Identidad visual Bloomind, con Fraunces vendorizada en el bundle.**
La app adopta la guía de estilo de la sección 5 de `~/CLM Bloomind/docs/instructivo.md`: tema oscuro Azul Profundo `#0F1A2C`, superficies `#16243D`, acento Azul Lab `#3A7BFF`, turquesa `#45D3C5` exclusivo para éxito, coral `#F0857A` para error, colores planos sin degradados, hairlines en vez de sombras y aire generoso. Traducida a AppKit en `UI/BloomindStyle.swift`.
Razón: es la cara común de la familia de productos Bloomind (CLM, whatasAPI, Oficinas) y Sebas la quiere en todo, incluida la ventana previa a grabar. Tener los tokens en un solo módulo desde ahora evita que el panel y el widget de la Fase 11 nazcan con otro aspecto y haya que unificarlos después.
Sobre la tipografía: Fraunces es una fuente variable y en los proyectos web vive como `.woff2`, que macOS no puede cargar. Se trajo el `.ttf` variable oficial del repositorio de Google Fonts (licencia SIL Open Font, la copia de la licencia va al lado del archivo en `Recursos/Fuentes/`) y se vendoriza en el bundle, registrándose vía `ATSApplicationFontsPath`. Esto no rompe la decisión 14: la regla de cero red es sobre la app corriendo, y el archivo viaja dentro del bundle.
Detalle técnico: el peso se pide por eje de variación, porque la instancia por defecto del archivo es Black y resulta demasiado pesada para una interfaz. El eje WONK va en 0 porque sus glifos alternos son excéntricos de más para un panel.
Alternativa descartada: usar solo la fuente del sistema hasta que el manual de marca Bloomind defina la tipografía oficial. Sebas prefirió la fidelidad con los otros productos, asumiendo que si el manual define otra fuente se cambia en una sola línea de `BloomindStyle`.

**27. 2026-07-26 — Cómo se verifica de verdad la resistencia a fallos (y cómo NO).**
Verificado con una prueba aislada: la resistencia a fallos de la decisión 11 **funciona**. Se mató un proceso escritor con `kill -9` a los 20 segundos y el archivo quedó legible hasta el segundo 15, o sea se perdió solo el último fragmento incompleto.
El detalle que importa para no volver a equivocarse: **un archivo que se cerró bien NO se ve fragmentado.** AVAssetWriter escribe fragmentos (`moof`) mientras graba, pero al llamar `finishWriting()` consolida todo en un `.mov` clásico con el índice `moov` al final. Un archivo matado a mitad, en cambio, queda con el `moov` al principio seguido de una cadena de `moof`, y es reproducible.
Consecuencia práctica: **truncar a mano un archivo terminado no prueba nada** y da un falso negativo, porque le estás cortando el índice a un archivo ya consolidado. La única prueba válida es matar el proceso durante la grabación y abrir el archivo que quedó.
Costo conocido: se pierde hasta un intervalo de fragmento, hoy 5 segundos. Si alguna vez se quiere perder menos, se baja `fragmentInterval` en `RecordingWriter`, a costa de un archivo levemente más pesado.

**28. 2026-07-26 — Las capas se dibujan dentro del mismo buffer de la captura.**
El compositor pinta el círculo y las ondas directamente sobre el `CVPixelBuffer` que llegó de ScreenCaptureKit, con un `CGContext` montado sobre su memoria, en vez de crear un buffer nuevo por frame.
Razón: a 30 fps durante una hora son 108.000 frames. Crear y destruir un buffer de pantalla completa en cada uno es exactamente la presión de memoria que la regla de la sección 5 del plan manda evitar. Se verificó que los buffers respaldados por IOSurface, que son los que entrega la captura, aceptan que se escriba sobre ellos.
Alternativa descartada: componer en un buffer aparte y copiar. Más limpio en teoría, pero paga una copia de pantalla completa por frame sin ganar nada.

**29. 2026-07-26 — La posición del mouse se guarda con cada evento, no se consulta por frame.**
`MouseTracker` actualiza la última posición conocida desde los eventos globales de movimiento, en el hilo principal, y el compositor la lee bajo un candado desde la cola de captura.
Razón: AppKit hay que tocarlo desde el hilo principal, y los frames llegan en otra cola. Consultar `NSEvent.mouseLocation` desde la cola de captura funcionaría casi siempre y fallaría raro.
Nota de permisos: los monitores globales de mouse **no** necesitan Accesibilidad. El de teclado sí, y por eso los atajos globales llegan recién en la Fase 9.

**30. 2026-07-26 — El JSON del cursor solo escribe cuando la posición cambia.**
El muestreo sigue siendo a la cadencia del frame, como pide la sección 8.5, pero si el mouse está quieto no se repite la misma coordenada frame tras frame.
Razón: en una clase de una hora, escribir un evento por frame son más de 100.000 entradas y varios MB de JSON, la mayoría idénticos entre sí. VideoFlow no pierde nada: una coordenada que no cambió no aporta información para decidir un zoom.
Alternativa descartada: un evento por frame siempre. Se descartó por tamaño, no por precisión.

**31. 2026-07-26 — Las pruebas automáticas van con asertos, sin XCTest.**
La única suite del proyecto es `Pruebas/main.swift`, que se corre con `./probar.sh`.
Razón: XCTest viene con Xcode, no con las Command Line Tools, así que un `swift test` normal no compila en esta máquina (decisión 16). Con asertos y un script de tres líneas alcanza y corre en cualquier Mac.
Qué se prueba y qué no: solo la conversión de coordenadas, porque es la pieza más compartida y un error ahí desfasa el círculo, los clics, el JSON, la censura y el dibujo todos a la vez, apareciendo como un síntoma vago. El resto del proyecto se valida con los criterios de aceptación, que es lo que manda el plan.

