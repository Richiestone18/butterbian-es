# Traductor en vivo (para cualquier versión de butterdwm)

Traduce los textos de la instalación ya existente **sin copiar archivos de otra
versión**. No usa `manifest.txt` ni `payload/`: trabaja sobre
`~/.config/suckless` y sustituye únicamente cadenas de texto conocidas.

## Uso

    ./traducir-en-vivo.sh --check        # ver qué cambiaría, sin escribir nada
    ./traducir-en-vivo.sh                # traducir en sitio (crea backup)
    ./traducir-en-vivo.sh --restore      # volver al estado anterior
    ./traducir-en-vivo.sh --verbose      # mostrar cadenas no reconocidas
    ./traducir-en-vivo.sh --add ARCHIVO "texto en inglés" "texto en español"

Ejemplo para un texto nuevo que trajo una actualización:

    ./traducir-en-vivo.sh --add quickshell/Clock.qml "Brand new label" "Etiqueta nueva"
    ./traducir-en-vivo.sh

## Cómo decide qué tocar

- Usa `tools/dictionary.tsv` (diccionario acumulado) y `tools/rules_extra.tsv`.
- Sólo cambia una cadena cuando coincide con el texto en inglés conocido **y**
  con su contexto. Si editaste ese texto a mano, no coincide y se conserva.
- `tools/revert.tsv` y `tools/ignore.tsv` protegen los datos que no se traducen:
  nombres de teclas, campos de nmcli, sensores, estados de Tailscale, títulos
  que usa `rules.conf`, etc.
- No aplica los parches de código del generador: **no mete código nuevo**, sólo
  texto. Por eso sirve con cualquier versión, incluso una que aún no existe.

## Si actualizás butterdwm

1. Corré `--check`.
2. Si dice `Nada que traducir`, ya está en español.
3. Si quedaron textos nuevos, corré `--verbose`, copiá las cadenas que falten y
   agregalas con `--add`. Después volvé a correr el traductor.

El traductor no inventa traducciones: lo que no conoce lo deja como viene y lo
reporta, para que no se rompa nada.

## Respaldos

Antes de escribir guarda `~/butterbian-es-vivo-backup-FECHA.tar.gz` y anota la
ruta en `~/.local/state/traducir-en-vivo.last`. `--restore` usa ese backup.

Después de aplicar, presioná **Super+Ctrl+R** para recargar la barra (el script
no la reinicia solo cuando corre desde SSH, para no romper los diálogos de
contraseña).
