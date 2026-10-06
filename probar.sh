#!/bin/bash
# Corre las pruebas automáticas del proyecto.
# Uso: ./probar.sh
#
# Son pocas y muy elegidas: solo las piezas donde un error es silencioso y
# aparece mucho después como un síntoma vago. El resto del proyecto se valida
# con los criterios de aceptación de Docs/ACEPTACION.md, que es lo que manda el
# plan. Sin XCTest a propósito: no viene con las Command Line Tools.
set -uo pipefail
cd "$(dirname "$0")"

# La raíz del proyecto viaja a las pruebas: alguna necesita un archivo de
# ejemplo del repo y todas corren desde un directorio temporal.
export RAIZ="$(pwd)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FALLOS=0

correr() {
	local nombre="$1"; shift
	echo ""
	echo "── $nombre"
	# La salida va a un archivo y recién ahí se recorta: recortarla con un
	# pipe a head mata al compilador apenas pasa de 20 líneas, y desde macOS 27
	# los avisos de AVFoundation solos ya pasan de 20.
	swiftc -O "$@" -o "$TMP/$nombre" > "$TMP/$nombre.log" 2>&1 || head -20 "$TMP/$nombre.log"
	if [ ! -x "$TMP/$nombre" ]; then
		echo "  ✗ no compiló"; FALLOS=$((FALLOS+1)); return
	fi
	( cd "$TMP" && "./$nombre" ) || FALLOS=$((FALLOS+1))
}

FUENTES=Sources/GrabadorBloomind

correr coordenadas \
	"$FUENTES/Coordenadas/CoordinateConverter.swift" \
	Pruebas/coordenadas/main.swift

correr camara \
	"$FUENTES/Composicion/FrameCompositor.swift" \
	"$FUENTES/Dibujo/DrawingSurface.swift" \
	"$FUENTES/Dibujo/DrawingRenderer.swift" \
	Pruebas/camara/main.swift

correr dibujo \
	"$FUENTES/Dibujo/DrawingSurface.swift" \
	Pruebas/dibujo/main.swift

correr ventanas \
	"$FUENTES/UI/WindowLevels.swift" \
	Pruebas/ventanas/main.swift

correr teleprompter \
	"$FUENTES/Teleprompter/TeleprompterEngine.swift" \
	"$FUENTES/UI/NumberRow.swift" \
	"$FUENTES/Teleprompter/ScriptFile.swift" \
	"$FUENTES/UI/BloomindStyle.swift" \
	Pruebas/teleprompter/main.swift

correr configuracion \
	"$FUENTES/Configuracion/Configuration.swift" \
	"$FUENTES/EntradaGlobal/Shortcut.swift" \
	"$FUENTES/Registro/Logger.swift" \
	Pruebas/configuracion/main.swift

correr oracion \
	"$FUENTES/UI/PanelSentence.swift" \
	"$FUENTES/Audio/AudioMode.swift" \
	Pruebas/oracion/main.swift

correr tutorial \
	"$FUENTES/Tutorial/TutorialSteps.swift" \
	"$FUENTES/UI/PanelSentence.swift" \
	"$FUENTES/Audio/AudioMode.swift" \
	Pruebas/tutorial/main.swift

correr mezcla \
	"$FUENTES/Audio/AudioMixer.swift" \
	"$FUENTES/Registro/Logger.swift" \
	Pruebas/mezcla/main.swift

correr reloj \
	"$FUENTES/Escritura/RecordingWriter.swift" \
	"$FUENTES/Registro/Logger.swift" \
	Pruebas/reloj/main.swift

correr pausa \
	"$FUENTES/Escritura/RecordingWriter.swift" \
	"$FUENTES/Registro/Logger.swift" \
	Pruebas/pausa/main.swift

echo ""
if [ "$FALLOS" -eq 0 ]; then
	echo "Todo en verde."
else
	echo "$FALLOS prueba(s) con fallos."
	exit 1
fi
