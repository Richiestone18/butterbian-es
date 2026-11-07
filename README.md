# Traducción al español para butterdwm (dwm + Quickshell)

Traduce al español (es_MX) **butterdwm** de [JustAGuy Linux](https://justaguy.dev/butter/dwm):
dwm con la barra de **Quickshell**, en Debian 13. Cubre la barra, la app de red,
la ayuda de atajos (`Super+/`) y los avisos de sus scripts. Además aplica unos
arreglos para que la barra funcione bien en español.

**Versión 4**: hecha y probada sobre butterdwm `d63645d` (6 de noviembre de 2026).

## Instalación rápida

```sh
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash
```

Revisar sin cambiar nada, o deshacer:

```sh
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash -s -- --check
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash -s -- --restore
```

Al terminar, pulsa **Super+Ctrl+R** para reiniciar la barra. Si lo corriste desde
una terminal de tu propia sesión, el script la reinicia solo.

## Seguro por diseño

- **Nunca mezcla versiones.** Un archivo se reemplaza solo si es *idéntico*
  (sha256) al original en inglés de la versión de butterdwm para la que se hizo
  la traducción (`manifiesto.txt`). Si lo editaste, o tu butterdwm es otra
  versión, se queda como está y el script te avisa.
- **Respeta tus atajos.** `keybinds.conf` se traduce línea por línea: solo cambia
  las descripciones que siguen en el inglés original.
- **Respaldo primero.** Antes de tocar nada guarda `~/butterbian-es-backup-FECHA.tar.gz`,
  y `--restore` deja todo como estaba.
- **Sin sudo.** Todo se escribe en `~/.config/suckless`.
- **No reinicia la barra desde SSH.** Una barra lanzada desde SSH queda fuera de
  tu sesión gráfica. Las apps que abras desde ella (Synaptic, GParted) no podrían
  pedirte la contraseña y no abrirían. Desde SSH te pide Super+Ctrl+R.
- **No hace falta recompilar dwm.** La ayuda de atajos lee `keybinds.conf` directamente.

## Qué traduce

- **Barra** (`quickshell/`, 28 archivos): menú de comandos, lanzador, métricas,
  volumen, clima y radar, notificaciones, energía, pantallas, calendario y el
  panel de configuración, incluidos sus editores de atajos, reglas, diseño, barra y fondo.
- **App de red** (`quickshell-network/`, `Super+Shift+N`): Wi-Fi, redes conocidas,
  ping, compartir por QR, Bluetooth, Tailscale y todos los mensajes de estado.
- **Atajos** (`dwm/keybinds.conf`): las 79 descripciones de la ayuda.
- **Scripts** (`scripts/`):
  - en la ayuda, las etiquetas automáticas ("Ver etiqueta 1", "Diseño: mosaico")
    y los nombres de las teclas (Espacio, Retroceso, Subir vol…);
  - los avisos al aplicar atajos y al cambiar el tema del fondo, y la bienvenida;
  - el menú de energía de respaldo de rofi.

## Qué NO traduce (a propósito)

Algunos textos parecen interfaz, pero el programa los usa como datos. Si se
traducen, algo deja de funcionar:

- nombres de teclas que se escriben en `keybinds.conf` (`Return`, `Left`, `Prior`…);
- etiquetas de sensores (`Package id 0`, `Composite`) y la señal `kill -s KILL`;
- campos de nmcli (`IN-USE,SIGNAL`) y urgencias de notificaciones (`CRITICAL`, `LOW`);
- la categoría `Settings` de los `.desktop`, los estados de Tailscale y la salida
  de bluetoothctl y xrandr;
- los títulos de ventana que usa `rules.conf` (`Network`, `butterdwm settings`).

## Arreglos que aplica

1. **Aviso falso de batería en equipos sin pila.** El dispositivo agregado de
   UPower (`DisplayDevice`, o tipo `unknown` con 0% y sin nivel) ya no cuenta
   como batería.
2. **Reloj en español.** `Qt.formatDateTime()` ignora el locale. Ahora se usa
   `toLocaleString()`, que muestra `sáb 7 nov 2:38 p.m.`. La hora del radar del clima va igual.
3. **Calendario en español.** Meses y días en español. La semana empieza en
   domingo, como en México, con encabezados y cuadrícula alineados.
4. **Batería llena y enchufada** cuenta como "cargando" (el kernel escribe `Full`).
5. **Errores de nmcli** en rojo, digan `failed` o `falló`.
6. **Tipos de dispositivo** de UPower en español: Mouse, Teclado, Audífonos, Control…

## Requisitos

- butterdwm instalado (`~/.config/suckless`) en Debian 13.
- `bash`, `curl`, `tar`, `awk` y `sha256sum` (Debian ya los trae).
- Locale `es_MX.UTF-8` (`LANG=es_MX.UTF-8`) para que Qt dé fechas y textos en español.

## Si tu butterdwm es más nuevo

`--check` dice cuántos archivos no coinciden con la versión de este paquete.
Esos se quedan en inglés, sin romper nada, hasta que haya una versión de
butterbian-es para tu butterdwm. La carpeta `herramientas/` trae el generador
y las pruebas para hacerla.

## Notas

- `Wired connection 1` es el nombre del perfil de NetworkManager, no texto de la
  barra. Si lo quieres en español:
  `sudo nmcli connection modify "Wired connection 1" connection.id "Conexión cableada 1"`

## Historial

- **v4** (7-nov-2026): rehecha sobre butterdwm `d63645d`, con instalador por sha256.
  Corrige tres problemas de la v3:
  - 8 traducciones que rompían funciones: forzar salida, señal Wi-Fi,
    temperatura de CPU y disco, colores de notificaciones, grabar atajos, apps de
    configuración en el lanzador y nombre del monitor;
  - el bug que duplicaba `desc=` en `keybinds.conf` y rompía la compilación de dwm;
  - la mezcla de versiones (copiaba los QML de octubre sobre butterdwm más nuevos).

  Agrega lo nuevo de upstream (editores de reglas y atajos, Pomodoro, redes
  conocidas) y los textos de los scripts.
- **v3** (6-nov-2026): payload de QML traducidos y protección de `desc=` editados.

## Estructura

```
install.sh                   instalador de una línea (descarga el repo y corre el script)
traducir-butterbian-es.sh    aplicar / --check / --restore
manifiesto.txt               sha256 del original y del traducido de cada archivo
atajos.tsv                   descripciones de atajos: inglés → español
payload/suckless/            los 35 archivos traducidos
herramientas/                generador de la traducción y pruebas (ver herramientas/LEEME.md)
```

## Licencia

MIT. Los archivos de `payload/` derivan de butterdwm de
[JustAGuy Linux](https://justaguy.dev/butter/dwm), con la traducción y los
arreglos de este repo.
