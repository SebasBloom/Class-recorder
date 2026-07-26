#!/bin/bash
# Compila el proyecto, arma el bundle "Grabador Bloomind.app" y lo firma.
# Uso: ./construir.sh
set -euo pipefail
cd "$(dirname "$0")"

NOMBRE="Grabador Bloomind"
EJECUTABLE="GrabadorBloomind"
DESTINO="build/${NOMBRE}.app"

echo "==> Compilando"
swift build -c release

echo "==> Armando el bundle"
rm -rf "$DESTINO"
mkdir -p "$DESTINO/Contents/MacOS" "$DESTINO/Contents/Resources"
cp ".build/release/${EJECUTABLE}" "$DESTINO/Contents/MacOS/${EJECUTABLE}"
cp "Recursos/Info.plist" "$DESTINO/Contents/Info.plist"

# La identidad de firma vive en .firma-identidad (fuera de git). Sin ese archivo
# se firma ad-hoc, y como macOS ata los permisos a la identidad del binario, los
# vuelve a pedir en cada recompilación. Ver Docs/FIRMA.md.
if [ -f .firma-identidad ]; then
	IDENTIDAD="$(tr -d '\n' < .firma-identidad)"
	echo "==> Firmando con: ${IDENTIDAD}"
else
	IDENTIDAD="-"
	echo "==> Firmando ad-hoc (sin certificado propio)"
	echo "    AVISO: macOS va a volver a pedir los permisos en cada recompilación."
	echo "    Para evitarlo, seguí Docs/FIRMA.md."
fi

codesign --force --sign "${IDENTIDAD}" "$DESTINO"
codesign --verify "$DESTINO"

echo "==> Listo: ${DESTINO}"
echo "    Abrilo con: open \"${DESTINO}\""
