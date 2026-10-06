# Rediseño visual del Grabador — estado

Arrancó el 2026-10-05, con el proyecto ya terminado (las 16 fases validadas). Va por fuera de las fases originales. **Todavía no se tocó código de la app**: todo lo que hay son maquetas en HTML.

## Cómo se llegó acá

1. Una revisión visual de la app real encontró estos problemas:
   - El panel mide 938 pt y en el Air (870 útiles) se sale 68 pt por abajo, con el botón de grabar cortado.
   - El widget, la tarjeta y la cuenta regresiva usan el fondo translúcido del sistema, fuera de la paleta.
   - En pausa el botón dice "Pausar" con el ícono de play.
   - La tarjeta de atajos no alinea las combinaciones.
   - El panel mezcla botones del sistema con botones de marca.
2. Con eso Sebas pidió un rediseño para que sea "una belleza de producto". Eligió: identidad libre, rediseñar la estructura (mismas funciones), todas las pantallas, y ver tres maquetas para elegir una.
3. Se hicieron tres direcciones. El encargo común está en `BRIEF.md`:
   - **A, "Estudio de transmisión"** (`direccion-a.html`): oscura, con la luz de AL AIRE.
   - **B, "Escrito"** (`direccion-b.html`): clara; el panel es una oración.
   - **C, "Todo listo"** (`direccion-c.html`): el DESIGN.md de Bloomind puro, con la verificación que se pinta de turquesa.
4. **Sebas eligió la B.** Le gustó visualmente más que las otras, aunque Claude había votado la C.

## La dirección B y lo que se decidió sobre ella

Tiene tres versiones: `direccion-b-v1.html` (la original), `-v2` y `direccion-b.html` (la vigente, v3). Las capturas están en `capb/` (v1) y `capb2/` (v2).

- **Panel:** una oración en Fraunces. Cada fragmento azul se toca y abre su menú: «Voy a grabar la pantalla entera del Retina, con el micrófono DJI y la cámara FaceTime, leyendo 3 guiones». El subrayado del micrófono hace de medidor de nivel. Mide unos 460 pt de alto.
- **Casos difíciles de la oración** (escena «Casos»):
  - Los nombres largos se acortan con reglas, por ejemplo «los AirPods Pro», y el nombre completo va en el menú.
  - Sin permiso, la frase lo dice en coral y el botón pasa a «Dar permiso al micrófono».
  - Sin audio ni cámara queda «sin sonido y sin cámara».
  - Con un área elegida queda «un área de 1280×720 del Retina».
- **Widget:** una cápsula blanca con borde navy fino y el cronómetro en Fraunces.
  - La hoja expandida de dos columnas **se eliminó**: a Sebas le estorbaba mientras graba. En su lugar hay cuatro botones de grupo (Qué se ve, Tablero, Sobre la pantalla, Guion). Cada uno abre un menú chico de 236 pt, con el atajo a la derecha, que se cierra solo; nunca hay dos abiertos.
  - Según el contexto aparecen botones en la cápsula: Lienzo, Deshacer y Borrar en modo tablero, y la pausa del guion cuando el guion está prendido.
  - **Modo mini** (pedido de Sebas: «tocar algo y que se reduzca al tiempo»): una pastilla de 116×42 pt con el punto y el cronómetro. Se toca para volver a la cápsula completa, se arrastra y el modo queda recordado. En pausa muestra dos barras; con una alerta se pone coral entera.
  - **Alertas:** cada una es una pastilla coral grande bajo la cápsula («Sin audio ⌥⌘M», «Censura puesta ⌥⌘C»), que se ve también en modo mini. Al tocarla se deshace.
  - **Reiniciar toma se queda en la cápsula, tal cual.** Sebas lo usa mucho así.
  - **El botón de atajos sale del widget.** Sebas lo aprobó: los atajos van escritos en cada menú y la tarjeta sigue con ⌥⌘H y desde la barra de menú.
- El teleprompter queda oscuro y con la misma voz tipográfica, y se reacomoda para no quedar debajo del widget.
- **Tipografía:** Fraunces (que ya viene en la app) para la oración, el título, el cronómetro, el guion y la cuenta regresiva; la letra del sistema (SF Pro) para todo lo operativo; SF Mono para las teclas. En la maqueta Fraunces sale de Google Fonts, pero en la app ya viene empaquetada.
- **Paleta:** blanco frío #F5F8FC/#FFFFFF, navy #0F1A2C, azul de acción #1F4DFF, coral de alerta #C93C30, y turquesa #45D3C5 solo para «todo listo».

## Pendiente de decidir

- ~~El ancho de la cápsula~~: **resuelto, Sebas eligió la A** (la de la maqueta, 900 a 1216 pt). Ver decisión 124.
- **El DESIGN.md de Bloomind** (borrador) dice Inter sin serif, y la B usa Fraunces. Sebas eligió identidad libre, así que no bloquea, pero el día que se apruebe el DESIGN.md hay que conciliarlos.

## Adenda 2 escrita (2026-10-05)

Sebas aprobó retomar. Las decisiones del rediseño quedaron como la adenda 2: decisiones 123 a 128 en `Docs/DECISIONS.md` (99, 100, 102, 109, 111 y 113 marcadas como reemplazadas y la 101 como ajustada), y en el plan maestro las secciones 8.9, 8.10 y 8.13 y la Fase 16 nueva. Razón de Sebas para cambiar el widget: viéndolo en vivo no le gustó y ocupaba demasiado espacio.

## Parte 1, el widget: VALIDADA por Sebas (2026-10-05)

Nuevos `UI/CapsuleButton.swift` y `UI/RecordingWidget.swift` reescrito, con la misma interfaz hacia `ControlWindow` (más el color del lienzo y la etiqueta de cada atajo). Decisión 129. Los pasos están en `Docs/ACEPTACION.md`, «Fase 16 — parte 1». Las fotos del arnés se ven como la maqueta. Sebas corrió los pasos y todo funcionó; en la prueba salió un caso que se arregló: la cápsula abierta desde la pastilla mini contra el borde izquierdo quedaba fuera de la pantalla, y ahora se corre para quedar entera. Siguiente: parte 2, el panel.

## Parte 2, el panel: VALIDADA por Sebas (2026-10-06)

La oración vive en `UI/PanelSentence.swift` (reglas, con prueba) y `UI/SentenceView.swift` (dibujo y clic). `ControlWindow` reescrito sobre eso; el guion va en un globo. Decisión 130. Pasos en `Docs/ACEPTACION.md`, «Fase 16 — parte 2». Fotografiado con arnés: se ve como la maqueta y mide unos 415 pt de alto. En la misma parte entraron dos pedidos de Sebas: casillas para usar o no cada guion cargado (decisión 131) y velocidad y letra que se recuerdan y se escriben con números (decisión 132). Siguiente: parte 3.

## Parte 3, el resto: VALIDADA por Sebas (2026-10-06)

Teleprompter, cuenta regresiva, tarjeta de atajos y Preferencias, selector de área, borde de la burbuja e ícono de la barra con el tiempo. Decisiones 133 y 134. Pasos en `Docs/ACEPTACION.md`, «Fase 16 — parte 3». En la misma parte entró el teleprompter claro por defecto con opción oscura (decisión 135). La burbuja redonda de la maqueta no se hizo: Sebas eligió dejarla rectangular (decisión 136).

**Con esto la Fase 16 queda cerrada.** Lo que sigue fuera del rediseño: rehacer el instalador de Iván con `./armar-entrega.sh` (el de Drive se borró el 2026-10-05).

## Cómo seguir

Sebas pidió **no arrancar** hasta que retome. El plan propuesto es pasar a AppKit por pedazos, cada uno validado por Sebas antes del siguiente:

1. **Widget:** la cápsula, los menús de grupo, los botones que aparecen según el contexto, el modo mini y las alertas grandes. Es lo que se usa grabando y lo de mayor impacto.
2. **Panel:** la oración con sus fragmentos que se tocan. Hay que armar a mano el texto con zonas clicables que abren un menú, porque AppKit no lo trae. También el medidor en el subrayado.
3. **El resto:** teleprompter, tarjeta de atajos, cuenta regresiva, burbuja, selector de área y estados del ícono de la barra de menú.

Antes de tocar código, leer `plan-maestro-grabador.md`, `Docs/DECISIONS.md` (las decisiones 99 a 115 son del widget actual y este rediseño cambia varias) y `Docs/INTERDEPENDENCIAS.md`. Cada pedazo deja su decisión escrita en DECISIONS.md.

Para ver la maqueta vigente: `open -a "Google Chrome" ~/grabador-bloomind/Docs/rediseno/direccion-b.html`. La barra de abajo cambia de escena, de fondo y de modo (mini o completo).
