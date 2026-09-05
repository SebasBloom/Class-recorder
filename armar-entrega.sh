#!/bin/bash
# Arma lo que se le pasa a Iván: el zip de la app y el manual en texto plano.
# Uso: ./armar-entrega.sh
#
# Compila desde cero para que el zip nunca quede atrasado respecto del código, y
# comprime con ditto (no con zip) porque es lo único que preserva la firma y los
# metadatos del bundle: un .app mal comprimido llega "dañado" a la otra Mac.
set -euo pipefail
cd "$(dirname "$0")"

NOMBRE="Grabador Bloomind"

./construir.sh

echo "==> Comprimiendo el bundle"
cd build
ditto -c -k --keepParent "${NOMBRE}.app" "${NOMBRE}.zip"

echo "==> Manual en texto plano (en Mac, un .txt abre con doble clic; un .md no siempre)"
python3 - <<'PY'
import re
from pathlib import Path

md = Path("../Docs/README-ivan.md").read_text(encoding="utf-8")
# La negrita se limpia sobre el texto completo: puede abrir al final de un renglón
# y cerrar en el siguiente.
md = re.sub(r"\*\*(.+?)\*\*", r"\1", md, flags=re.DOTALL)

def limpiar(t):
    t = re.sub(r"`([^`]+)`", r"\1", t)
    t = re.sub(r"\[(.+?)\]\((.+?)\)", r"\1 (\2)", t)
    return t.replace("```", "")

salida = []
for linea in md.split("\n"):
    titulo = re.match(r"^(#{1,6})\s+(.*)$", linea)
    if titulo:
        texto = limpiar(titulo.group(2))
        salida.append(texto)
        salida.append(("=" if len(titulo.group(1)) == 1 else "-") * len(texto))
    else:
        salida.append(limpiar(linea))

Path("Cómo instalar y usar el Grabador.txt").write_text("\n".join(salida), encoding="utf-8")
PY

echo
echo "Listo. Subí a Drive estos dos archivos de la carpeta build/:"
echo "  - ${NOMBRE}.zip"
echo "  - Cómo instalar y usar el Grabador.txt"
echo
echo "Subí el ZIP tal cual. Nunca subas el .app suelto: Drive lo trata como carpeta"
echo "y al bajarlo puede llegar sin permisos de ejecución, o sea 'dañado'."
