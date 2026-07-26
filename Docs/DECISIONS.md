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
Estado: pendiente de que Sebas lo ejecute. Mientras tanto `construir.sh` firma ad-hoc y avisa.

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
