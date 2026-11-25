# butterbian-es — español para butterdwm (dwm + Quickshell)

Traduce la barra, la app de red, los atajos y los scripts de butterdwm en
Debian 13. Se usa con una línea de `curl`; no hay que clonar ni instalar nada.

Las versiones fijas cambian seguido, así que el traductor trabaja sobre lo que
ya tenés instalado, sea la versión que sea: no reemplaza archivos, no mete
código y conserva lo que hayas editado a mano.

## Uso

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

## Notas

- No necesita `sudo`: todo queda en `~/.config/suckless`.
- Backup: `~/butterbian-es-vivo-backup-FECHA.tar.gz`; la ruta se anota en
  `~/.local/state/traducir-en-vivo.last`.
- Después de aplicar, presioná **Super+Ctrl+R** para recargar la barra. Desde
  SSH no se reinicia sola, para no romper los diálogos de contraseña.
- Los textos que son datos (teclas, nmcli, sensores, estados de Tailscale y
  títulos que usa `rules.conf`) no se traducen a propósito.
- Detalle completo: `TRADUCIR-EN-VIVO.md`.
