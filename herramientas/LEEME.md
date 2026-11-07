# Herramientas: cómo se generó la v4 (y cómo hacer la siguiente)

Se corren desde un directorio de trabajo con esta forma:

```
trabajo/
  butterdwm-full/    clon COMPLETO de butterdwm (git clone https://codeberg.org/justaguylinux/butterdwm.git)
  butterbian-es/     este repo, en la versión anterior
  (aquí se copian los .py de herramientas/)
```

1. **`dic_v4.py`**: arma el diccionario inglés→español alineando cada archivo
   traducido de la versión anterior con su original en inglés (constante `BASE`,
   el commit de butterdwm de esa versión; `P`, la carpeta del payload). Lo aplica al
   butterdwm actual solo donde la línea coincide con el contexto original y escribe
   `v4/suckless`.
   - Primero alinea las líneas exactas. Solo dentro de los bloques que cambian
     compara la estructura.
   - Rechaza pares que cambian un glifo: las filas de layouts de `Wm.qml` son
     idénticas en estructura y se cruzarían.
2. **`v4_build.py`**: aplica el diccionario y luego cuatro listas:
   - `REVERT`: textos que son datos y se dejan en inglés;
   - `T`: traducciones de lo nuevo;
   - `P`: arreglos funcionales;
   - validación: fuera de los parches solo puede cambiar texto entre comillas.

   Revisa la lista `PROBLEMAS` que imprime al final.
3. **`v4_keybinds.py`**: descripciones de `keybinds.conf`, etiquetas automáticas
   de `scripts/keybinds` y nombres de sección en `KeybindsPane.qml` (solo al mostrarlos).
4. **`v4_scripts.py`**: avisos y menús de los scripts.
5. **`empaquetar_v4.py`**: escribe `payload/`, `manifiesto.txt` y `atajos.tsv` en el repo.
6. **`probar-v4.sh <repo> <suckless en inglés> <v4 esperada>`**: 14 pruebas sobre una
   copia temporal, sin tocar nada real. Cubre --check, aplicar, aplicar dos veces,
   --restore, ediciones del usuario y otra versión de butterdwm.

Para una versión nueva de butterdwm:

1. Pon `BASE` = el commit de la versión anterior (`d63645d`) y `P` = `butterbian-es/payload/suckless`.
2. Corre los pasos 2 a 4 y revisa `PROBLEMAS`.
3. Revisa en su contexto todo texto nuevo que el programa pueda usar como dato
   (comparaciones, comandos, campos), y agrega lo que haga falta a `REVERT`.
4. Prueba en una máquina real y revisa el log de la barra:
   `qs log -p ~/.config/suckless/quickshell | grep -iE 'error|warn'`.
