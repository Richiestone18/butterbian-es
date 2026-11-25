# butterbian-es — español para butterdwm (dwm + Quickshell)

Traduce la barra, la app de red, los atajos y los scripts de butterdwm en
Debian 13. Todo se hace con una línea de `curl`; no hay que clonar ni instalar
nada.

## Forma 1: traductor en vivo (cualquier versión, sin reemplazar archivos)

Es la que conviene cuando actualizaste butterdwm y volvió a salir texto en
inglés. Traduce los archivos ya instalados: no copia archivos de otra versión,
no mete código y conserva lo que hayas editado a mano.

Comprobar sin escribir nada:

```sh
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install-live.sh | bash -s -- --check
```

Traducir en sitio (crea backup antes):

```sh
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install-live.sh | bash
```

Ver qué cadenas nuevas no conoce:

```sh
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install-live.sh | bash -s -- --verbose
```

Enseñarle un texto nuevo y volver a correrlo:

```sh
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install-live.sh | bash -s -- --add quickshell/Clock.qml "Brand new label" "Etiqueta nueva"
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install-live.sh | bash
```

Deshacer el último cambio:

```sh
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install-live.sh | bash -s -- --restore
```

## Forma 2: paquete de versión fija (v9, butterdwm `e3f9958`)

Instalar o actualizar:

```sh
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash
```

Comprobar o deshacer:

```sh
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash -s -- --check
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash -s -- --restore
```

Este instalador sólo reemplaza un archivo si es idéntico al original de esa
versión. Si tu butterdwm es más nuevo, usa la Forma 1.

## Notas

- No necesita `sudo`: todo queda en `~/.config/suckless`.
- Backups: `~/butterbian-es-vivo-backup-FECHA.tar.gz` (forma 1) y
  `~/butterbian-es-backup-FECHA.tar.gz` (forma 2).
- Después de aplicar, presioná **Super+Ctrl+R** para recargar la barra. Desde
  SSH no se reinicia sola, para no romper los diálogos de contraseña.
- Los textos que son datos (teclas, nmcli, sensores, estados de Tailscale y
  títulos que usa `rules.conf`) no se traducen a propósito.
- Detalle completo del traductor en vivo: `TRADUCIR-EN-VIVO.md`.
