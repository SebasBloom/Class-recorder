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

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FALLOS=0

correr() {
	local nombre="$1"; shift
	echo ""
	echo "── $nombre"
	if ! swiftc -O "$@" -o "$TMP/$nombre" 2>&1 | head -20; then :; fi
	if [ ! -x "$TMP/$nombre" ]; then
		echo "  ✗ no compiló"; FALLOS=$((FALLOS+1)); return
	fi
	( cd "$TMP" && "./$nombre" ) || FALLOS=$((FALLOS+1))
}

FUENTES=Sources/GrabadorBloomind

correr coordenadas \
	"$FUENTES/Coordenadas/CoordinateConverter.swift" \
	Pruebas/coordenadas/main.swift

correr mezcla \
	"$FUENTES/Audio/AudioMixer.swift" \
	"$FUENTES/Registro/Logger.swift" \
	Pruebas/mezcla/main.swift

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
