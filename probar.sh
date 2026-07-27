#!/bin/bash
# Corre las pruebas automáticas del proyecto.
# Uso: ./probar.sh
set -euo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

swiftc -O \
	Sources/GrabadorBloomind/Coordenadas/CoordinateConverter.swift \
	Pruebas/main.swift \
	-o "$TMP/coordenadas"

"$TMP/coordenadas"
