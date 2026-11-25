#!/usr/bin/env bash
# traducir-en-vivo.sh — traduce textos de butterdwm sin reemplazar archivos.
# Usa el diccionario acumulado sobre los archivos ya instalados. Sirve para
# cualquier version: no consulta manifest.txt ni copia payload/.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
exec python3 "$HERE/tools/traducir_en_vivo.py" "$@"
