# Traducción al español para Butterbian / dwm + Quickshell

Traduce al español la barra de **Quickshell** y su **app de red** del setup
`suckless` (dwm + quickshell) de **Butterbian / JustAGuy Linux**, más el panel
de atajos de dwm. Incluye dos arreglos de paso.

Pensado para dejarlo listo en segundos al instalar el sistema en otra máquina.

## Instalación rápida

```sh
curl -fsSL https://raw.githubusercontent.com/__REPO_SLUG__/main/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

O en un solo paso, sin dejar el archivo:

```sh
curl -fsSL https://raw.githubusercontent.com/__REPO_SLUG__/main/install.sh | sh
```

Antes de tocar nada el script guarda tu configuración actual en
`~/butterbian-es-backup-FECHA.tar.gz` y al final reinicia la barra.

## Opciones

```sh
./install.sh --check     # solo compara, no escribe nada
./install.sh             # aplica la traducción
./install.sh --restore   # vuelve atrás con el último backup
./install.sh --help
```

Si prefieres el repo entero (para revisar o editar antes):

```sh
git clone https://github.com/__REPO_SLUG__.git
cd butterbian-es
./traducir-butterbian-es.sh --check
./traducir-butterbian-es.sh
```

## Qué traduce

- **quickshell/** (la barra): menú de comandos, métricas, volumen, clima,
  lanzador, pantallas, ajustes de barra y diseño, notificaciones, editor de
  reglas y de atajos.
- **quickshell-network/** (app de red, `Super+Shift+N`): cabecera, ping,
  pérdida de paquetes, recibiendo/enviando, IP, puerta de enlace, Wi-Fi,
  compartir por QR, Bluetooth, Tailscale y todos los mensajes de estado.
- **dwm/keybinds.conf**: descripción de **todos** los atajos, incluidos los 12
  diseños, ver/enviar/alternar etiquetas y las 18 ranuras scratch.

## Arreglos que también aplica

1. **Aviso falso de batería en equipos sin pila.** UPower publica siempre un
   pseudo-dispositivo `DisplayDevice` con `percentage: 0%` y sin
   `battery-level`. La barra lo tomaba por una batería y lanzaba
   «battery low» en cualquier escritorio. Ahora se descarta, y sin lectura
   real no hay aviso.
2. **Reloj en inglés.** `Qt.formatDateTime()` ignora el locale aunque
   `LANG=es_MX.UTF-8` esté puesto, y devolvía `Fri 23 Oct 6:45 pm`. Ahora usa
   `Date.toLocaleString()/toLocaleTimeString()` y muestra `vie 23 oct 6:48 p.m.`.

## Requisitos

- Debian 13 / Butterbian con dwm + quickshell y la config en
  `~/.config/suckless` (setup de JustAGuy Linux). El script se niega a
  ejecutarse si no encuentra `~/.config/suckless/quickshell`.
- `curl` y `tar`.
- Locale `es_MX.UTF-8` generado, y `LANG=es_MX.UTF-8` en `~/.xsession`.
  Si falta, el script te dice el comando exacto (`locale-gen`).
- No hace falta `sudo`: todo se escribe en `~/.config`.

## Notas

- El título interno de la ventana de red sigue siendo `Network`: dwm la flota
  y centra por ese título (`rules.conf`), así que no se traduce.
- `Wired connection 1` es el nombre del perfil de NetworkManager, no texto de
  la app. Si lo quieres en español:
  `sudo nmcli connection modify "Wired connection 1" connection.id "Conexión cableada 1"`
- Si Butterbian actualiza su versión de la config, el script reemplaza los
  archivos por la versión traducida. El backup previo te permite comparar o
  volver atrás con `--restore`.
- Para relanzar la barra a mano por SSH, exporta el locale o la fecha saldrá
  en inglés:
  `LANG=es_MX.UTF-8 LC_ALL=es_MX.UTF-8 ~/.config/suckless/scripts/bar restart`

## Estructura

```
install.sh                  instalador (curl + chmod + ./install.sh)
traducir-butterbian-es.sh   script principal (aplicar / --check / --restore)
payload/config/suckless/    archivos ya traducidos (quickshell, quickshell-network, dwm)
```

## Licencia

MIT. Los archivos de `payload/` derivan de la configuración de
[JustAGuy Linux](https://github.com/justaguylinux) para Butterbian, con la
traducción y los arreglos de este repo.
