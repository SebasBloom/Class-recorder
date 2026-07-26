# Grabador Bloomind — instrucciones para Claude Code

## Antes de escribir una sola línea, en cada sesión

Leer, en este orden:

1. `plan-maestro-grabador.md` — la fuente de verdad del proyecto.
2. `Docs/DECISIONS.md` — decisiones cerradas y sus razones.
3. `Docs/INTERDEPENDENCIAS.md` — qué piezas compartidas alimentan qué features.

Si algo durante la construcción contradice el plan maestro, se detiene el trabajo y se consulta con Sebas antes de seguir.

## Protocolo de trabajo

1. **Una sola fase a la vez.** No adelantar trabajo de fases futuras aunque parezca eficiente.
2. **Antes de tocar una pieza de `INTERDEPENDENCIAS.md`**, revisar sus consumidores y avisar en el resumen de la sesión qué features quedan potencialmente afectados y deben reverificarse.
3. **Toda decisión técnica no obvia va a `DECISIONS.md` en el momento**, con fecha, razón y alternativa descartada. No al final.
4. **Al terminar la fase:** actualizar los documentos vivos, dejar por escrito los pasos de aceptación listos para que Sebas los ejecute, y esperar su validación. Con el visto bueno, commit `Fase N: descripción corta`.
5. **Nunca commitear una fase como terminada sin que Sebas haya validado sus criterios de aceptación.**
6. **Si algo se traba más de lo razonable**, sobre todo la mezcla de audio de la Fase 5, aislar el problema en un proyecto de prueba mínimo en vez de acumular intentos sobre el proyecto principal.
7. **Nunca inventar features ni cambiar comportamiento especificado sin consultar.** Los vacíos del plan se resuelven preguntando, no asumiendo.

## Reglas de seguridad y privacidad

- **Cero red.** La app no hace ninguna conexión saliente. Sin telemetría, sin chequeo de actualizaciones, sin dependencias externas. Es una garantía verificable, no una preferencia.
- **Sin paquetes de terceros.** Todo con frameworks de Apple.
- **El log registra el evento, nunca el contenido.** "Censura permanente activada" sí; qué había en pantalla o qué se tipeó en una anotación, jamás. Las posiciones de los rectángulos de censura sí van a la configuración, porque el feature las necesita.
- **Nada de contenido de pantalla se persiste** fuera del video que el usuario decidió grabar. Los temporales se limpian al cerrar.
- **Nunca destruir sin salida de emergencia.** Reiniciar toma manda el archivo a la Papelera, no lo borra. Un `config.json` ilegible se aparta, no se pisa.

## Cómo se compila

No hay Xcode. El proyecto es un paquete de Swift Package Manager:

```bash
./construir.sh          # compila, arma el bundle .app y lo firma
open "build/Grabador Bloomind.app"
```

El bundle se arma a mano en el script porque SwiftPM no sabe empacar apps de macOS. El `Info.plist` vive en `Recursos/`.

La firma sale de `.firma-identidad` (fuera de git). Sin ese archivo se firma ad-hoc y macOS vuelve a pedir los permisos en cada recompilación: ver `Docs/FIRMA.md`.

## Convenciones

- **Idiomas:** tipos, funciones y variables en inglés (convención de Swift). Comentarios, documentos, mensajes de UI y logs en español. Carpetas del proyecto en español.
- **Un archivo, una responsabilidad.** Nombres que digan qué hacen sin abrirlos. Funciones cortas.
- **Comentarios solo donde el porqué no es obvio:** la conversión de coordenadas, la mezcla de audio, el desplazamiento de timestamps en pausa.
- **Nada de lógica duplicada.** Si dos features necesitan lo mismo, se extrae a una pieza compartida y se registra en `INTERDEPENDENCIAS.md`.
- **Las carpetas de módulo nacen con su fase**, no vacías por adelantado.

## Reglas de ingeniería que aplican a toda fase

- **Memoria:** toda fase que toque el pipeline de frames incluye una prueba de memoria comparando Monitor de Actividad entre el minuto 2 y el final. Crecimiento sostenido es fallo de la fase aunque el video salga bien. Obligatorio: `autoreleasepool` por frame donde aplique, nunca retener buffers más allá de su procesamiento, y si el compositor se atrasa, descartar frames en vez de encolarlos sin límite.
- **Toda ventana de la app se excluye siempre de la captura**, sin excepciones, incluidas las creadas después de iniciar la grabación.
- **Resiliencia de hardware:** si un micrófono o cámara se cae a mitad de grabación, la grabación continúa con lo que quede, la app avisa visiblemente y lo registra. Crashear o seguir en silencio son ambos inaceptables.
- **Permisos:** si falta uno, la app dice exactamente cuál y abre el panel correcto de Configuración del Sistema. Nunca fallar en silencio ni cerrarse sola.
- **Criterios de aceptación verificables por no técnicos.** Sebas e Iván no son developers: cada fase cierra con pasos que se ejecutan usando la app, nunca leyendo código.
