# Traducción al español para Butterbian / dwm + Quickshell

Traduce al español la barra de **Quickshell** y su **app de red** del setup
`suckless` (dwm + quickshell) de **Butterbian / JustAGuy Linux**, más el panel
de atajos de dwm. Incluye dos arreglos de paso.

Diseñado para dejarlo listo en segundos al instalar el sistema en otra máquina,
sin sobrescribir los atajos o descs que tú hayas editado.

## Instalación rápida

```sh
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh -o install.sh
chmod +x install.sh
./install.sh              # aplica la traducción
./install.sh --check      # solo compara, no escribe nada
./install.sh --restore    # deshace el último cambio
```

O en un solo paso, sin dejar el archivo:

```sh
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | sh
```

Antes de tocar nada el script guarda tu configuración actual en
`~/butterbian-es-backup-FECHA.tar.gz` y al final reinicia la barra.

## Qué traduce

- **quickshell/** (la barra): menú de comandos, métricas, volumen, clima,
  lanzador, pantallas, ajustes de barra y diseño, notificaciones, editor de
  reglas y de atajos.
- **quickshell-network/** (app de red, `Super+Shift+N`): cabecera, ping,
  pérdida de paquetes, recibiendo/enviando, IP, puerta de enlace, Wi-Fi,
  compartir por QR, Bluetooth, Tailscale y todos los mensajes de estado.
- **dwm/keybinds.conf**: descripción de **todos** los atajos, incluidos los 12
  diseños, ver/enviar/alternar etiquetas y las 18 ranuras scratch.
- Cada descripción de atajo se cambia **solo si coincide con la original**;
  si ya la editaste, se respeta tu versión.

## Arreglos que también aplica

1. **Aviso falso de batería en equipos sin pila.** UPower publica siempre un
   pseudo-dispositivo `DisplayDevice` con `percentage: 0%` y sin
   `battery-level`. La barra lo tomaba por una batería y lanzaba
   «battery low» en cualquier escritorio. Ahora se descarta, y sin lectura
   real no hay aviso.
2. **Reloj en inglés.** `Qt.formatDateTime()` ignora el locale aunque
   `LANG=es_MX.UTF-8` esté puesto, y devolvía `Fri 23 Oct 6:45 pm`. Ahora usa
   `Date.toLocaleString()/toLocaleTimeString()` y muestra
   `vie 23 oct 6:48 p.m.`.

## Cómo funciona (v3)

El script copia los archivos ya traducidos de la barra (`quickshell/` y
`quickshell-network/`) desde el `payload/` del repo, sobrescribiendo los que
ya haya. Para `dwm/keybinds.conf`, traduce las descripciones (`desc=`) de los
atajos **solo si coinciden con el inglés original** — si ya editaste un desc,
se respeta tu versión.

Así aguanta las actualizaciones de `setup-update` sin desajustarse: los
archivos de la barra se renuevan entero, y los desc de atajos solo se tocan
cuando coinciden con el original.

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
  la interfaz. Si lo quieres en español:
  `sudo nmcli connection modify "Wired connection 1" connection.id "Conexión cableada 1"`

## Estructura

```
install.sh                  instalador (curl + chmod + ./install.sh)
traducir-butterbian-es.sh   script principal (aplicar / --check / --restore)
traducir.txt                data file con las desc= de atajos (solo keybinds.conf)
payload/config/suckless/    archivos ya traducidos (quickshell, quickshell-network, dwm)
```

## Licencia

MIT. Los archivos de `payload/` derivan de la configuración de
[JustAGuy Linux](https://github.com/justaguylinux) para Butterbian, con la
traducción y los arreglos de este repo.
