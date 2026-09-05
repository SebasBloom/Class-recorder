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

**32. 2026-07-27 — La pista de audio es estéreo aunque el micrófono sea mono.**
Se declara AAC 48 kHz de dos canales desde la Fase 3, cuando lo único que entra es un micrófono, que casi siempre es mono.
Razón: las pistas de un `AVAssetWriter` hay que declararlas **antes** de empezar a escribir y no se pueden cambiar después. En la Fase 4 entra el audio del sistema, que sí es estéreo, y en la Fase 5 los dos comparten esta misma pista. Declararla mono ahora obligaría a rehacer el escritor dos fases más adelante.
Verificado con una prueba aislada: 200 bloques de micrófono mono float32 a 48 kHz entraron sin un solo rechazo y el archivo salió con audio estéreo de 48 kHz.

**33. 2026-07-27 — La sesión de escritura arranca con el primer buffer de cualquier pista.**
`startSession` se dispara con el primero que llegue, sea de video o de audio, y las dos pistas referencian ese mismo origen.
Razón: es el punto delicado 3 del plan. Si cada pista arrancara su propio origen, el audio y el video quedarían desfasados exactamente por la diferencia entre sus primeras llegadas, que además varía en cada grabación. Este es el mecanismo que hace que la palmada del principio y la del final calcen en la prueba de la Fase 12.

**34. 2026-07-27 — El audio tiene su propia cola, separada de la de los frames.**
Razón: el compositor dibuja sobre cada frame y puede demorarse. Si el audio esperara en la misma cola, un frame lento se traduciría en un salto audible, que es mucho más molesto que un frame perdido.

**35. 2026-07-27 — El medidor de nivel usa su propia sesión de captura, aparte de la grabación.**
`AudioLevelMeter` levanta una `AVCaptureSession` propia mientras el panel está abierto y no se está grabando; durante la grabación el micrófono entra por ScreenCaptureKit y el medidor se apaga.
Razón: mostrar una barra de nivel no justifica levantar un stream de pantalla completo, que es lo que haría falta para leer el micrófono por ScreenCaptureKit. Y los dos no pueden tener el dispositivo a la vez.
Consecuencia visible: durante la grabación la barra se queda quieta a propósito. No es un bug.

**36. 2026-07-27 — Sin permiso de micrófono se graba igual, pero mudo y avisando.**
Razón: perder una clase entera porque faltaba un permiso es peor que perder el audio de esa clase. La app avisa cuál falta, ofrece abrir el panel exacto y deja seguir. Es la regla de "nunca fallar en silencio ni cerrarse sola" aplicada a un caso donde además hay una salida razonable.

**37. 2026-07-28 — El procesamiento de audio (reducción de ruido) va en VideoFlow, no en el grabador.**
El grabador escribe el audio tal como llega del micrófono, sin reducción de ruido ni realce.
Razón: misma lógica que la decisión 6 sobre el zoom automático. En edición se puede analizar la grabación completa, medir el ruido real de la sala y quitarlo con precisión; en vivo hay que adivinar con un algoritmo que corre a ciegas y que, cuando se equivoca, se come el principio de las palabras en medio de una clase de una hora.
Contexto de la decisión: Sebas reportó que el audio sonaba peor que en Notas de voz. Se midió el mismo micrófono grabado por `AVCaptureSession` (camino clásico de macOS) contra ScreenCaptureKit, con codificación idéntica, y **el nuestro salió mejor**: mismo nivel de voz (−24.1 dBFS), ruido de fondo 6 dB más bajo (−59.3 contra −53.5) y espectros equivalentes. La diferencia percibida contra Notas de voz se atribuye al procesamiento posterior que esa app aplica, no al camino de captura.
Alternativa descartada: meter reducción de ruido en vivo en el grabador.

**38. 2026-07-28 — El medidor de nivel lee el formato del audio, no lo asume.**
Razón: la primera versión daba por sentado enteros de 16 bits y la barra nunca se movía, porque macOS entrega flotantes de 32 bits. Verificado leyendo el formato real del dispositivo: 48000 Hz, flotante de 32 bits. Ahora se lee del propio buffer y se manejan los dos casos.
Aprendizaje que aplica más allá de esto: en audio en macOS, el formato se consulta, nunca se supone.

**39. 2026-07-28 — El logo va a color en el ícono de la app y en silueta en la barra de menú.**
El ícono de la app se genera desde `Logo bloomind hr.png` (el mismo del CLM) en las diez resoluciones que pide macOS, montado sobre el cuadrado redondeado con el margen de la rejilla del sistema. El de la barra de menú es una silueta monocroma con alfa, marcada como imagen de plantilla.
Razón: macOS pide imágenes de plantilla en la barra de menú para que el ícono se adapte solo al tema claro y oscuro y a la barra teñida. Un logo a color con degradado ahí se ve como una calcomanía y no responde al tema.
Cómo se hizo la silueta: el cerebro es blanco sobre un degradado azul, así que se separa por luminancia con una transición suave entre 0.80 y 0.95 en vez de un umbral duro, que dejaría el borde dentado.
Nota para la Fase 11: los tres estados del ícono (inactivo, grabando, pausado) se construyen sobre esta misma silueta.

**40. 2026-07-28 — El selector de audio es de modo, no de dispositivo.**
La interfaz ofrece "Sin audio", "Micrófono" y "Audio del sistema" como modos, y el selector de micrófono con su barra de nivel solo aparece cuando el modo elegido usa micrófono. "Micrófono + sistema" se suma en la Fase 5, que es la que trae la mezcla.
Razón: el plan (sección 8.2) define tres modos, no una lista de dispositivos con una opción de apagado. Modelarlo como modo deja el cuarto caso listo para entrar sin rehacer la interfaz, y evita el estado sin sentido de "audio del sistema con un micrófono seleccionado".

**41. 2026-07-28 — El audio de la propia app se excluye de la captura del sistema.**
Se activa `excludesCurrentProcessAudio`.
Razón: es la decisión 3 llevada al audio. Así como ninguna ventana propia sale en el video, ningún sonido propio sale en la pista. Sin esto, un aviso del Grabador quedaría grabado dentro de la clase.
El audio del sistema no pide un permiso aparte: viaja con el de grabación de pantalla, que ya se verifica antes de arrancar.

**42. 2026-07-28 — La mezcla suma sobre una línea de tiempo común, no fuente contra fuente.**
`AudioMixer` mantiene un búfer circular donde cada bloque se escribe en la posición **absoluta** que le corresponde según su timestamp, sumándose a lo que ya esté ahí. Un tramo se da por cerrado y se emite cuando pasó el margen de latencia (0.25 s).
Razón: las dos fuentes llegan por separado, con bloques de distinto tamaño y en momentos distintos. Sumar "lo último de cada una" produce eco y desfase. Como mezclar es sumar, escribir en posiciones absolutas hace que las dos se acumulen solas sin necesidad de sincronizarlas entre sí.
Formatos: todo se lleva antes a 48 kHz estéreo flotante con `AVAudioConverter`, con mapa de canales para que un micrófono mono vaya a los dos canales y no quede uno mudo.
Saturación: limitador suave con curva `tanh` a partir de 0.7 en vez de recorte duro. Verificado aislado: dos fuentes a 0.6 (que sumadas darían 1.2) salen con pico 0.98.

**43. 2026-07-28 — Al pausar, el corte se marca después del último buffer, no encima.**
`pauseStartedAt` se fija en `último timestamp + duración de ese buffer`.
Razón: **bug real encontrado por la prueba aislada de la Fase 5.** Marcándolo en el mismo instante del último buffer, el primer frame tras reanudar caía en un timestamp ya usado, el `AVAssetWriter` pasaba a estado fallido y se perdía la grabación entera. A ojo se habría visto como "la grabación se corta al reanudar", sin ninguna pista del porqué.
Es la razón por la que el protocolo del plan manda aislar esta fase antes de integrarla.

**44. 2026-07-28 — El punto de reanudación lo fija el primer buffer que llegue, no el botón.**
`resume()` solo marca la intención; el descuento se cierra cuando entra el siguiente buffer, sea de video o de audio.
Razón: al soltar el botón todavía no se sabe cuánto duró la pausa en la línea de tiempo de la captura. Usar el reloj del sistema introduciría deriva contra el reloj de los buffers, que es el que manda en el archivo.


**45. 2026-07-31 — Los atajos globales se registran con Carbon, no con un monitor de eventos.**
`HotKey` usa `RegisterEventHotKey` de Carbon (HIToolbox).
Razón: un monitor global de teclado (`NSEvent.addGlobalMonitorForEvents`) exige permiso de Accesibilidad, porque el sistema lo trata como capaz de leer todo lo que se teclea. `RegisterEventHotKey` registra una combinación puntual con el sistema y no pide permiso. La app pide tres permisos en vez de cuatro y ninguna función queda esperando que el usuario acierte un panel de Configuración.
Alternativa descartada: pedir Accesibilidad en la Fase 6. Se descartó porque el permiso solo haría falta para leer teclas que no son nuestras, cosa que la app no necesita hacer nunca.
Nota para la Fase 9: el registro reasignable se construye encima de esta pieza; lo que falta es la traducción de una combinación tecleada por el usuario a código de tecla y máscara de Carbon.

**46. 2026-07-31 — La cámara se convierte a imagen en su propia cola, no en la del compositor.**
`CameraCapture` recibe el frame de la cámara, lo pasa a `CGImage` ahí mismo y guarda solo el último bajo candado. El compositor lee esa imagen ya lista.
Razón: la cola de captura de pantalla es la que no se puede atrasar (un atraso ahí descarta frames del video). La conversión sale de esa cola, y de paso ningún `CVPixelBuffer` de la cámara se retiene más allá de su procesamiento: en memoria vive una sola imagen a la vez, se llame la cámara 30 o 60 veces por segundo.
Alternativa descartada: pasar el `CVPixelBuffer` de la cámara al compositor y convertirlo por frame de pantalla. Se descartó porque obliga a mantener vivo un buffer de la cámara mientras lo lee otra cola, que es exactamente la clase de retención que revienta las grabaciones largas.

**47. 2026-07-31 — La burbuja es un rectángulo de esquinas redondeadas, no un círculo.**
Decidido con Sebas el 2026-07-31. El redondeo se calcula como fracción del lado corto (8%) para que la ventana espejo y la burbuja del video tengan la misma forma en cualquier tamaño.
Razón: el círculo desperdicia el encuadre de una cámara apaisada. El rectángulo muestra la escena completa que la cámara está viendo.

**48. 2026-07-31 — La ventana espejo existe desde que se elige la cámara, no desde que se graba.**
Decidido con Sebas el 2026-07-31. Elegir una cámara en la lista enciende la sesión y abre el espejo.
Razón: encuadrarse es parte de la preparación, no de la grabación. Si el espejo apareciera al arrancar, el primer minuto de cada clase se iría acomodando la burbuja con la grabación ya corriendo.
Es un `NSPanel` que no activa la app: mover la burbuja no le roba el foco a la aplicación que se está mostrando en clase.

**49. 2026-07-31 — En modo cámara completa el espejo se esconde.**
La matriz de visibilidad de la sección 8.4 dice que la burbuja no se compone en modo cámara completa; la ventana espejo se esconde con ella y vuelve al volver a pantalla.
Razón: el espejo es un espejo. Si se quedara en pantalla mostrando una burbuja que el video no tiene, mentiría sobre lo que se está grabando, que es justo lo que la decisión 3 busca evitar.

**50. 2026-07-31 — La Desk View del iPhone no aparece en la lista de cámaras.**
Se saca `.deskViewCamera` de la enumeración.
Razón: probada por Sebas el 2026-07-31. Entrega la imagen deformada en ojo de pescado porque está pensada para apuntar al escritorio, no a la cara. Como opción de burbuja o de cámara completa no sirve, y en la lista solo se presta a elegirla por error.

**51. 2026-07-31 — El seguimiento del mouse también escucha eventos locales.**
`MouseTracker` suma dos monitores locales a los dos globales.
Razón: **bug real encontrado revisando el video de la prueba 4 de la Fase 6.** Los monitores globales de AppKit no ven los eventos que van a las ventanas de la propia app. Con el mouse parado sobre el control, el círculo se quedaba clavado en el último punto de afuera mientras el puntero se movía por la pantalla, y el `.cursor.json` de esa grabación de 21 segundos salió con **un solo evento**. En el video se ve como un círculo amarillo trabado, sin ninguna pista del porqué.
Importa más con cada fase: el widget flotante de la Fase 11 va a estar en pantalla toda la grabación.

**52. 2026-07-31 — En modo cámara el video lo sostiene un reloj propio.**
`FramePipeline` corre un temporizador a 30 por segundo que, **solo en modo cámara completa**, emite un cuadro cuando la captura lleva más de 60 ms callada. Usa `CMClockGetHostTimeClock`, el mismo reloj del que salen los timestamps de ScreenCaptureKit, así que los cuadros propios y los de la captura caen en una sola línea de tiempo sin corrección de deriva.
Razón: **medido en la prueba de la Fase 6.** ScreenCaptureKit deja de mandar cuadros cuando la pantalla no cambia. Grabando la pantalla eso es correcto: repetir el último cuadro de una pantalla quieta es exactamente lo que corresponde, y por eso el reloj no corre en modo pantalla. En modo cámara el fondo del video **es** la cámara, así que la cara queda congelada mientras el audio sigue. En la grabación de 10 minutos fueron **41 segundos congelados** (t=537.5 a 578.4), con el audio continuo sin un solo hueco. El tramo coincide exactamente con el momento en que Chrome soltó sus assertions de video: mientras hubo algo animado en pantalla la captura entregó 29 fps parejos, y siete segundos después de que eso paró, se cortó.
Alternativa descartada: aceptar los cuadros marcados "sin novedad" que manda ScreenCaptureKit. **Medido y descartado:** el diagnóstico mostró "sin novedad: 8 (con imagen 0)". No traen imagen, no hay nada que escribir con ellos.
Alternativa descartada: dejar el espejo de la burbuja visible en modo cámara para que su video mantenga la pantalla cambiando. Se descartó porque es apoyarse en un efecto colateral y además contradice la decisión 49.
Detalle crítico: al volver la captura, sus primeros cuadros pueden traer un timestamp anterior al último ya escrito. Entran a un archivo desordenado y el escritor aborta la grabación entera, que es la falla de la decisión 43. Por eso el pipeline descarta todo cuadro cuyo timestamp no sea posterior al último escrito. Tiene prueba aislada en `./probar.sh`.

**53. 2026-07-31 — Cada atajo de modo se registra también en el teclado numérico.**
Opción Comando 1 y 2 se registran con el código de la fila de números y con el del numérico.
Razón: probado por Sebas el 2026-07-31. Con el teclado USB los atajos no respondían y con el del Mac sí; la causa era que estaba usando los números de la derecha, que son códigos de tecla distintos. El Mac no tiene numérico, así que el problema no aparece nunca probando en el portátil.
Cuando llegue el registro reasignable de la Fase 9 hay que conservar esta equivalencia: quien asigna "Comando 1" espera que le sirvan los dos unos del teclado.

**54. 2026-07-31 — Clic seco crea cuadro de texto; arrastrar dibuja.**
Decidido con Sebas el 2026-07-31. Apretar y soltar sin mover más de 3 puntos abre un cuadro de texto; apretar y arrastrar dibuja un trazo. Un trazo de un solo punto se descarta en el modelo.
Razón: el plan pide trazo con el mouse y cuadro de texto con un clic, sin decir cómo distinguirlos. Resolverlo por el gesto evita una tecla más que recordar en vivo, que es lo que cuenta dando clase.
Alternativa descartada: un atajo que cambia de herramienta. Más predecible, pero suma una tecla a un modo que ya tiene cinco.

**55. 2026-07-31 — El tablero se borra al iniciar cada grabación.**
Decidido con Sebas el 2026-07-31. Cambiar de modo **no** borra nada (lo pide el plan en 8.4); lo que limpia es empezar una toma nueva.
Razón: que los dibujos de una clase aparezcan en la siguiente es peor que perderlos al repetir una toma.
Ojo con la Fase 11: reiniciar toma llama a iniciar grabación, así que el tablero se va a limpiar también ahí. Es coherente con esta decisión, pero hay que decirlo en su criterio de aceptación para que no sorprenda.

**56. 2026-07-31 — Lo dibujado se guarda normalizado, no en píxeles.**
Los puntos de los trazos y el origen de los cuadros de texto van de 0 a 1 sobre el ancho y el alto de la superficie.
Razón: el mismo modelo lo dibujan la ventana espejo, que está en puntos de pantalla, y el compositor, que está en píxeles del video. Con coordenadas normalizadas los dos usan el mismo renderizador sin ninguna conversión, y no hay forma de que se desfasen entre sí. Es también la razón por la que el motor de dibujo **no** consume el módulo de conversión de coordenadas, al revés de lo que preveía `INTERDEPENDENCIAS.md`.

**57. 2026-07-31 — El compositor cachea lo terminado del tablero.**
Lo ya dibujado se pinta una vez en una imagen y se reusa mientras la versión del modelo no cambie; el trazo en curso se pinta en vivo.
Razón: una clase con doscientos trazos obligaría a repintarlos treinta veces por segundo. El compositor se atrasaría justo cuando más contenido hay, o sea al final de la clase, y los frames descartados no vuelven.
Por eso `DrawingSurface.version` cambia al terminar un trazo, deshacer o borrar, pero **no** mientras se arrastra el mouse.

**58. 2026-07-31 — El reloj propio cubre también el modo tablero.**
La condición de la decisión 52 pasa de "modo cámara" a "cualquier modo cuyo fondo no sea la pantalla capturada".
Razón: en modo tablero la burbuja de cámara sí se compone según la matriz 8.4. Con el lienzo quieto y la pantalla de atrás quieta, la captura se calla y la cara de la burbuja quedaría congelada igual que en la Fase 6. El lienzo en sí puede congelarse sin problema, la burbuja no.

**59. 2026-07-31 — El texto se corta en el borde y sigue en la línea de abajo.**
Los cuadros de texto se dibujan con `CTFramesetter` dentro del rectángulo que va desde su origen hasta el borde de la superficie, en vez de con una línea suelta.
Razón: **encontrado en el video de la prueba de la Fase 7.** Una frase larga se salía de la pantalla por la derecha y lo escrito de más se perdía, sin ningún aviso: en el espejo tampoco se veía, así que Sebas habría seguido tipeando creyendo que quedaba grabado.
El cursor de escritura pasa a calcularse desde la última línea, no desde el ancho total del texto.

**60. 2026-07-31 — Una sola ventana de dibujo para las dos superficies.**
`WhiteboardWindow` pasa a llamarse `DrawingWindow` y recibe el fondo como parámetro: lienzo blanco opaco para el tablero, transparente para la capa de anotación. El motor, el renderizado, el mouse y el teclado son idénticos.
Razón: es el "motor único" del plan llevado hasta el final. Dos ventanas casi iguales se habrían separado con el tiempo, y el primer síntoma sería que el texto se comporta distinto en el tablero que en la anotación.

**61. 2026-07-31 — Deshacer, borrar y el color actúan sobre la superficie activa.**
La superficie activa es el tablero si el modo es tablero, y la capa de anotación si está prendida y el modo es pantalla. Nunca las dos.
Razón: lo pide el plan en 8.7. La consecuencia práctica es que borrar la anotación no toca el tablero y viceversa, que es justo lo que verifica el criterio de aceptación de esta fase.
El color es la excepción: la paleta es una sola en la interfaz, así que rotarlo cambia las dos superficies a la vez.

**62. 2026-07-31 — Los espejos se repintan por evento, no por temporizador.**
Se sacó el temporizador a 30 por segundo que repintaba el espejo del tablero. La vista se repinta sola con el mouse y el teclado, y los atajos llaman al repintado explícitamente.
Razón: repintar una vista a pantalla completa treinta veces por segundo cuesta CPU todo el tiempo para no cambiar nada la mayor parte del tiempo. Es la clase de gasto que no se nota en una prueba de dos minutos y sí en una clase de una hora.

**63. 2026-07-31 — La capa de anotación no puede tener el fondo del todo transparente.**
El fondo de la ventana de anotación es negro con alfa 0.002 en vez de `.clear`.
Razón: **bug real de la primera prueba de la Fase 8.** macOS decide a qué ventana le entrega un clic según el alfa de los píxeles de la ventana no opaca: sobre un píxel completamente transparente el clic pasa de largo a la ventana de abajo. Con `.clear`, la capa se prendía y se apagaba bien según el log, pero **nunca recibía un solo evento de mouse**, así que no se dibujaba nada y en el video no aparecía nada. A ojo se veía como "la capa no funciona", sin ninguna pista de por qué.
Un alfa mínimo la vuelve sólida para el mouse y sigue siendo invisible. Y como la ventana está excluida de la captura, ese tinte no llega al video de ninguna manera.

**64. 2026-07-31 — Al mostrar un espejo de dibujo, la app se pone adelante.**
`DrawingWindow.present()` llama a `NSApp.activate`.
Razón: **medido en la prueba de la Fase 8.** El log mostró `recibe teclado: false` la primera vez que se prendió la capa y `true` en todas las siguientes. La app vive en la barra de menú, así que no es la app de adelante, y macOS le entrega el teclado solo a la que lo está. Se podía dibujar, porque el mouse va a la ventana bajo el puntero, pero lo tipeado en el primer cuadro de texto se lo quedaba la app de atrás **sin ningún aviso**.
Activar no agrega ningún efecto visible que no fuera a pasar igual: el primer trazo activa la app de todas formas, y con él la app de abajo ya se ve desactivada en el video. Lo único que cambia es que el texto deja de fallar la primera vez.

**65. 2026-07-31 — Borrar tocaba las dos superficies. Bug real, encontrado por el criterio de aceptación.**
`clearDrawing()` tenía un `annotation.clear()` de más: borrar el tablero se llevaba también la capa de anotación. Corregido para que actúe solo sobre la superficie activa.
Cómo se encontró: revisando el video de la prueba de la Fase 8. En el segundo 40 la anotación estaba sobre la pantalla; en el 45, después de haber borrado el **tablero**, había desaparecido. El log no mostraba nada raro porque la línea que se escribía era "Tablero borrado", que era cierta y a la vez incompleta.
**Por qué importa más allá del bug:** es exactamente lo que el plan maestro mandó verificar en esta fase ("comprobar que borrar la capa no tocó el contenido del tablero y viceversa"). Sin ese paso escrito de antemano, esto se descubría en una clase real, borrando media hora de anotaciones de un tecleo.
Cómo llegó ahí: una edición por reemplazo de texto que **no encontró el patrón y no hizo nada**, dejando la versión vieja de la función más una línea suelta. El reemplazo falló en silencio y no se verificó el resultado. Regla que queda: después de editar por reemplazo, se lee la función resultante, no se asume.

**66. 2026-07-31 — El tablero puede ser blanco o negro, y se alterna en vivo.**
Pedido de Sebas el 2026-07-31. **Cambia el plan maestro**, que en la sección 8.4 decía solo "lienzo blanco". Se alterna con Opción Comando B durante la grabación, sin cortar nada, y la elección se recuerda entre sesiones.
Al rotar la paleta se saltea el color que se confundiría con el fondo: el negro sobre tablero negro, el blanco sobre tablero blanco. Sobre la pantalla real no se saltea ninguno, porque ahí el fondo es lo que haya en pantalla.
Y al cambiar el fondo, si el marcador activo quedara invisible se rota solo: pasar a tablero negro con el marcador negro dejaría dibujando en la nada sin ningún aviso.

**67. 2026-07-31 — Cada atajo guarda su propia etiqueta.**
`Shortcut` guarda el código de tecla, los modificadores **y** el texto que se muestra ("⌥⌘3").
Razón: traducir un código de tecla a la letra que tiene impresa depende de la distribución de teclado activa, y hacerlo mal se ve como una pantalla de preferencias que miente. Esa cuenta se hace bien una sola vez, cuando el usuario aprieta la combinación, y de ahí en adelante se muestra lo que él mismo tecleó. De paso `config.json` queda legible a mano, que es lo que exige la decisión 4.

**68. 2026-07-31 — El registro de atajos vive en la barra de menú, no en el controlador de grabación.**
`ShortcutRegistry` lo posee `MenuBarController`, que reparte cada acción: iniciar/detener y la tarjeta las atiende él, el resto se las pasa al controlador de grabación.
Razón: el atajo de iniciar/detener tiene que funcionar aunque no haya ninguna grabación en curso **ni ventana de control abierta**, y el controlador de grabación no existe hasta que esa ventana se crea. Con el atajo, la ventana se crea al vuelo.
Consecuencia práctica: se puede iniciar y detener una clase sin tocar el mouse, que es justo lo que hacía falta cuando el tablero tapa la pantalla entera.

**69. 2026-07-31 — Las teclas equivalentes se registran junto con la principal.**
Cada acción declara sus equivalentes (los números del teclado numérico, la "Supr" de los teclados de PC) y se registran todas.
Razón: son dos tropiezos ya vividos, no una hipótesis. Los códigos son distintos y quien aprieta la tecla que tiene esperando que funcione tiene razón. Los equivalentes solo se aplican mientras la acción conserva su combinación por defecto: si el usuario reasigna, manda lo que él eligió.

**70. 2026-08-01 — Los atajos por defecto nunca usan símbolos, solo letras, números y teclas dedicadas.**
La tarjeta de atajos pasa de Opción Comando barra diagonal a **Opción Comando H**. **Cambia la tabla 8.8 del plan maestro.**
Razón: **bug real, encontrado por Sebas.** Un atajo global se registra por **posición física** de la tecla, no por el carácter que produce. En el teclado latinoamericano de Sebas la barra diagonal es Shift+7, así que Opción+Comando+/ nunca coincidía con la tecla registrada y el atajo no existía. Peor: la interfaz mostraba "⌥⌘/" cuando la tecla en esa posición está rotulada "-", o sea que la pantalla de preferencias mentía.
Las letras y los números están en la misma posición física y con el mismo rótulo en todas las distribuciones QWERTY; los símbolos no. La regla aplica a cualquier default futuro.
Ojo: esto solo afecta a los **defaults**, que llevan su etiqueta escrita a mano. Los atajos que el usuario reasigna toman la etiqueta de la tecla que él mismo apretó (decisión 67), así que ahí el problema no existe.

**71. 2026-08-01 — La zona de censura se guarda en coordenadas globales, no en píxeles del video.**
Igual que el marco de la burbuja: `RedactionSlot` guarda el rectángulo en coordenadas de macOS y el conversor lo traduce a píxeles del frame.
Razón: la zona sobrevive a cambiar de pantalla o de resolución de captura. La barra de direcciones del VPS está en el mismo lugar de la pantalla, no en el mismo píxel de un archivo.
La conversión se hace al prender o apagar, no por frame: las zonas cambian cuando alguien aprieta un atajo, no treinta veces por segundo.

**72. 2026-08-01 — El blur se hace promediando bloques sobre el propio buffer, sin CoreImage.**
`pixelate` promedia bloques de 24 píxeles directo sobre el buffer de la captura.
Razón: esto corre una vez por frame en la cola de captura, que es la que no se puede atrasar. Un filtro de CoreImage implicaría crear contextos e imágenes intermedias por frame, que es exactamente lo que la decisión 28 evita.
El bloque de 24 píxeles es lo bastante grueso para que no se lea un texto debajo. **El bloque sólido sigue siendo el default** porque es el único que garantiza que no se pueda reconstruir lo que había.

**73. 2026-08-01 — Al detener la grabación, la censura se apaga pero la zona se recuerda.**
`turnOff()` apaga la tapa sin borrar el rectángulo.
Razón: cada toma arranca sin nada tapado, que es lo predecible, pero el permanente no obliga a redibujar la zona en cada clase. Es justamente la diferencia entre los dos slots.

**74. 2026-08-01 — Una sola zona de censura, que no persiste en disco. Reemplaza los dos slots.**
Pedido de Sebas el 2026-08-01: *"no se me ocurre por qué dejar una barra de censura permanente"*. **Cambia las secciones 8.6 y 8.8 del plan maestro y deja sin efecto la decisión 5.**
Queda un solo atajo (Opción Comando C) y su variante con Shift para redibujar. La zona vive mientras la app esté abierta; al reabrir, se dibuja de nuevo.
Razón: el permanente existía por un caso hipotético (la barra de direcciones del VPS siempre en el mismo lugar) que el propio Sebas descartó al usarlo. Lo que costaba era real: dos slots, dos atajos más, dos campos en `config.json` y un rectángulo de una zona sensible guardado en disco para siempre.
De paso es más seguro por defecto: nada de lo que se tapa queda escrito en ningún archivo. Los campos `permanentRedactionRect` y `permanentRedactionStyle` desaparecen de la configuración; un `config.json` viejo que los tenga los ignora al cargar y los suelta en la próxima escritura.

**75. 2026-08-01 — La app no pide permiso de Accesibilidad. Son tres permisos, no cuatro.**
Corrige la sección 5 del plan maestro y el README de Iván, que anunciaban cuatro.
Razón: los atajos globales usan Carbon (decisión 45) y los monitores de mouse de AppKit no lo necesitan. El permiso terminó no haciendo falta para nada.
Importa más de lo que parece: Accesibilidad es el permiso más invasivo de macOS, el que deja leer todo lo que se teclea. No pedirlo es una garantía verificable para quien reciba la app, no una comodidad.

**76. 2026-08-01 — No se crean archivos temporales.**
El plan pedía "limpieza de temporales verificada" en la Fase 12. Verificado: la app escribe directo al archivo final y no usa el directorio temporal en ningún lado. No hay nada que limpiar y no se agregó código para limpiar nada.

**77. 2026-08-01 — Una grabación que no cerró bien se avisa al arrancar.**
`RecoveryMarker` deja un archivo con la ruta del video mientras se graba y lo borra al cerrar bien. Si al arrancar sigue ahí, la app avisa y ofrece abrir la carpeta.
Razón: la resistencia a fallos de la decisión 11 ya dejaba el archivo reproducible, pero nadie te lo decía. El aviso se consume al leerlo, así que aparece una sola vez y no en cada arranque.

**78. 2026-08-19 — El modo "Micrófono + sistema" no tiene un defecto de mezcla: le falta balance entre fuentes.**
Sebas reportó que el modo mixto "no funciona" mientras los modos de una sola fuente sí, y que el audio del sistema "suena como en eco y apaga mi voz".
Lo que se descartó midiendo, en seis grabaciones reales con `AudioMixer` y `ScreenCapture` instrumentados:
- **El audio del sistema llega completo** con el micrófono activo: 1.972 bloques continuos, y el mezclador escribe el 100% de las muestras que le ofrecen (1.893.120 de 1.893.120). No se descarta nada.
- **El mezclador no duplica nada.** Volcando cada fuente a su propio archivo se comparó el audio del sistema tal como entra contra el que quedó en el video: correlación 0,896 en retardo cero y **una sola copia**. Un duplicado daría un segundo pico fuerte; no existe.
- **El micrófono no capta los parlantes de forma significativa:** el rebote explica el 0,1% de su energía (correlación 0,029). No hay filtro de peine.
- **El video no repite la voz del micrófono:** sin picos de correlación de envolventes más allá de 0 ms, buscando hasta 3 segundos de retardo.
La causa real es que **el audio del sistema entra entre 5 y 9 dB por encima del micrófono, segundo a segundo, y el mezclador los suma uno a uno sin ninguna ganancia relativa.** Nunca se le puso balance. Con dos voces distintas al mismo nivel el resultado suena embarrado, que es lo que se percibe como eco. Agravante medido: el micrófono interno del MacBook Air capta bajo, entre −36 y −43 dB cuando queda solo.
Se corrige con el ducking de la decisión 86.

**78-bis. 2026-08-19 — Corrección de la decisión 78, y por qué se dejó escrita.**
La versión original de la decisión 78 afirmaba que la causa era un filtro de peine por doble captura acústica, con 13 muescas espectrales separadas 258 Hz como prueba. **Era falso**, y se corrigió el mismo día.
El error: esa medición se hizo sobre el archivo **ya mezclado**, donde las dos fuentes son inseparables, y el patrón espectral se interpretó como doble captura sin poder verificarlo. Recién al volcar cada fuente a su propio archivo se pudo correlacionar micrófono contra sistema y ver que la copia no existía.
El aprendizaje, que vale para todo el proyecto: **un archivo mezclado no sirve para diagnosticar la mezcla.** Cuando el síntoma involucra dos fuentes sumadas, el primer paso es volcarlas por separado, no analizar la suma con más ingenio. En el camino murieron tres hipótesis fuertes: que el audio del sistema no llegaba, que el limitador distorsionaba, y esta del filtro de peine. Ninguna sobrevivió a la medición correcta.
Segundo aprendizaje: "los canales L y R salen idénticos" **no** prueba que falte el audio del sistema. La voz de una videollamada es mono y da canales idénticos igual.

**79. 2026-08-19 — La caché de convertidores de audio se indexa por el formato, no por la identidad del objeto.**
`AudioMixer.convert` usaba `ObjectIdentifier(inputFormat)` como clave, pero `inputFormat` se construye nuevo en cada bloque, así que la caché no acertaba nunca: creaba un `AVAudioConverter` por bloque y los acumulaba para siempre. Medido: 9.614 convertidores en 67 segundos, del orden de 500.000 en una clase de una hora. La clave ahora describe el formato (frecuencia, canales, flags, bits) y se crean dos.
Razón: era una fuga de memoria real, encontrada de paso investigando la decisión 78, en la pieza que más presión de memoria aguanta en grabaciones largas.

**80. 2026-08-19 — El mezclador se usa siempre que la grabación tenga audio, no solo en modo mixto.**
Antes, con una sola fuente el buffer iba directo al escritor y solo el modo mixto pasaba por `AudioMixer`. Ahora todos los modos con audio pasan por el mezclador.
Razón: silenciar en vivo necesita un punto único donde aplicar la ganancia. Con la bifurcación harían falta dos mecanismos, y el de la ruta directa tendría que cortar el flujo de buffers, que deja huecos. Con una sola fuente el mezclador es su caso degenerado, ya probado desde la Fase 5.
Alternativa descartada: silenciar en la ruta directa poniendo a cero una copia del buffer. Es más código que reusar el mezclador y deja dos caminos que mantener.
Costo aceptado: los modos de una sola fuente ganan los 0,25 s de latencia del mezclador. No afecta la sincronía porque el escritor alinea por timestamp, no por orden de llegada.

**81. 2026-08-19 — Silenciar es ganancia cero, no cortar el flujo de buffers.**
Una fuente silenciada sigue entrando al mezclador y sigue empujando la línea de tiempo; lo único que cambia es que sus muestras se multiplican por cero.
Razón: si se dejara de pasar los buffers, la posición escrita más alta dejaría de avanzar mientras dure el silencio y el tramo no se emitiría, dejando un hueco en la pista de audio. Con ganancia cero el archivo tiene audio continuo de punta a punta y el tramo silenciado es silencio de verdad, no ausencia de datos.

**82. 2026-08-19 — La cámara se puede prender a mitad de grabación; una fuente de audio no.**
Es una asimetría deliberada y vale la pena entender por qué. La cámara no es una pista del archivo ni una fuente del stream de captura: se dibuja sobre cada frame, así que puede nacer y morir cuando sea. El audio es las dos cosas, y ambas se fijan antes de escribir la primera muestra (decisión 32).
Se evaluó capturar siempre las dos fuentes de audio y descartar la no elegida, lo que habría permitido encenderlas en vivo. Descartado: dejaría el micrófono abierto toda la clase, con el indicador naranja de macOS encendido, aunque el usuario haya elegido "solo sistema". Cambiar "no estoy grabando tu micrófono" por "lo grabo y lo tiro" contradice la sección 5 del plan, y Sebas graba con clientes bajo confidencialidad.

**83. 2026-08-19 — Apagar la cámara en modo cámara completa devuelve a modo pantalla.**
Razón: en ese modo el fondo del frame **es** la cámara. Apagarla sin más dejaría el video en negro y, peor, el reloj sintético del pipeline deja de correr cuando no hay imagen de cámara, así que un fondo negro quieto ni siquiera avanzaría. Volver a pantalla es lo único que deja el video utilizable.

**84. 2026-08-19 — El silencio de audio no persiste entre tomas.**
Cada toma arranca con todas las fuentes elegidas sonando.
Razón: es la misma lógica de la decisión 55 con el tablero, que arranca limpio en cada toma. Un micrófono silenciado que se hereda de la grabación anterior es exactamente la forma de perder una clase entera, y el costo de volver a apretar el botón es un segundo.

**85. 2026-08-19 — El mezclador pasa a tener un carril por fuente, no un búfer compartido.**
Hasta ahora las dos fuentes sumaban sobre el mismo búfer circular y la mezcla quedaba hecha en el momento de escribir. Ahora cada fuente escribe en su propio carril y la suma ocurre recién al emitir el bloque.
Razón: una vez sumadas, las fuentes no se pueden volver a separar, así que cualquier cosa que trate distinto a una u otra —silenciar una, bajar el video mientras se habla, un balance— es imposible con el búfer compartido. Con carriles separados las tres salen del mismo cambio y se aplican en un solo lugar, al emitir.
Costo: el doble de memoria del búfer, unos 3 MB. Irrelevante.
Alternativa descartada: aplicar la ganancia a cada bloque **antes** de sumarlo. No sirve para el ducking, porque en el momento en que entra un bloque del sistema todavía no se sabe si el micrófono va a tener voz en esa misma posición de la línea de tiempo: puede llegar después. Con carriles, esa decisión se toma al emitir, cuando ya llegaron las dos.

**86. 2026-08-19 — Ducking: el audio del sistema baja solo mientras se habla.**
Al emitir cada bloque se mide el nivel del carril del micrófono. Si hay voz, el carril del sistema se atenúa; al callar, vuelve a su nivel pleno. Ataque rápido para no comerse la primera sílaba, liberación lenta para que no bombee entre palabras. Los cuatro parámetros (umbral, atenuación, ataque, liberación) viven juntos en un solo lugar del código, como los umbrales de disco.
Razón: es el problema de la decisión 78 resuelto donde se puede resolver. Sebas da clase explicando encima de un video, y en una clase la voz del que explica manda sobre el material de fondo.
Alternativa descartada: un nivel fijo con el sistema unos dB abajo. Es más simple y predecible, pero castiga los tramos en que se muestra un video **sin** hablar encima, que también son parte de una clase. El ducking solo actúa cuando hace falta.
Elegido por Sebas el 2026-08-19 sobre las otras dos opciones que se le plantearon.

**87. 2026-08-19 — El ducking es una excepción explícita a la decisión 37, y la única.**
La decisión 37 dice que el procesamiento de audio va en VideoFlow, no en el grabador. El ducking es procesamiento y se hace igual, acá.
Razón: la decisión 9 obliga a entregar **un solo track ya mezclado**, para que Whisper transcriba limpio. Una vez sumadas, las dos fuentes no se pueden separar nunca más, así que un balance mal puesto es irreversible y VideoFlow no tiene nada que arreglar: recibe un archivo donde la voz ya quedó enterrada. Es lo contrario de la reducción de ruido, que sí se puede aplicar después sin pérdida.
Criterio general que queda: en el grabador solo va el procesamiento que **no se pueda hacer después**. Todo lo demás sigue siendo de VideoFlow. El limitador de la mezcla ya cumplía este criterio por la misma razón.


## 2026-09-05 — La entrega se arma con `armar-entrega.sh`, y el zip se hace con `ditto`

**Decisión.** Un script compila, comprime el bundle con `ditto -c -k --keepParent` y
genera el manual como `.txt` junto al zip. Es lo único que se le pasa a quien va a
usar la app.

**Razón.** Tres cosas que se hacían a mano y cada una tiene su trampa:

1. **`ditto`, no `zip`.** Es lo único que preserva la firma y los metadatos del
   bundle. Un `.app` mal comprimido llega "dañado" a la otra Mac y el mensaje no
   dice por qué. Verificado: al descomprimir el zip, `codesign --verify` responde
   "valid on disk" y "satisfies its Designated Requirement".
2. **El manual en `.txt`.** Un `.md` en macOS abre en cualquier cosa (o en nada) y
   muestra la sintaxis cruda. El `.txt` abre con doble clic en TextEdit.
3. **Compilar siempre antes de comprimir**, para que el zip no quede atrasado
   respecto del código. Ya había pasado: el zip del 20 de agosto salió de código que
   nunca se commiteó.

**Nota sobre Gatekeeper, para no diagnosticarlo dos veces.** `spctl -a -vv` sobre la
app responde `rejected`, con `origin=Bloomind Desarrollo`. **Eso es lo esperado**, no
un problema del bundle: la app está firmada con el certificado autofirmado de la
máquina que compila, no con un Developer ID notarizado. La firma es válida y estable
(por eso los permisos de macOS se dan una sola vez), pero Gatekeeper exige la
autorización manual en Privacidad y seguridad que describe el manual.

**Pendiente que puede tumbar la instalación:** el binario es `arm64` puro
(`lipo -archs` → `arm64`), así que **no corre en un Mac Intel**, y el manual solo
declara "macOS 15 o más nuevo". Hay que confirmar qué Mac tiene Iván antes de
mandarle nada; si es Intel, se compila universal.
