# RadialHub

Menú radial rápido para **WoW Forever** (probado) y, de forma experimental, Retail y Classic: abre Personaje, Talentos, Bolsas, Mapa... sin buscar botones ni memorizar atajos.

1. **Mantén** la tecla: la rueda aparece centrada en el cursor.
2. **Mueve el ratón** hacia una opción: crece, se ilumina con el color de acento y su nombre aparece en el centro. En el centro (zona muerta) no hay nada seleccionado ("Cancelar").
3. **Suelta** la tecla (o haz clic): se abre esa ventana. Si tienes varias ruedas, aparecen dos flechas a los lados y el nombre de la rueda arriba: clic en una flecha o rueda del ratón para cambiar de rueda sin cerrar. Si sueltas en el centro, pulsas **Escape** o haces **clic derecho**, se cancela sin hacer nada. Entrar en combate con la rueda abierta también la cancela.

## Instalación

Descomprime el zip (o copia la carpeta) en `World of Warcraft/_forever_/Interface/AddOns/RadialHub` y reinicia el cliente. La carpeta debe llamarse `RadialHub`. En Retail o Classic, usa `_retail_`, `_classic_` o `_classic_era_` en lugar de `_forever_`.

Funciona nada más instalarlo: en el primer inicio asigna **ALT-Q** a la rueda 1 si esa tecla está libre (si no, te avisa para que elijas otra con `/rh`).

Las opciones que no existan en tu cliente (por ejemplo Logros en Forever o en Classic Era) se ocultan solas. Si ves un panel que no abre, escribe `/rh check`: lista la ruta que usa cada opción en tu cliente (o "NO DISPONIBLE").

## Configuración

`/rh` o `/radialhub` (también en *Opciones → AddOns → RadialHub*). La ventana se redimensiona desde la esquina inferior derecha.

- **Ruedas:** hasta 4, cada una con su nombre, sus opciones y su propia tecla (pestañas arriba; *+ Nueva* copia la rueda actual). Así puedes tener, por ejemplo, una rueda de ventanas y otra de comandos, cada una en su tecla. La rueda 1 no se puede borrar.
- **Atajo de teclado:** pulsa el botón y luego la tecla (admite ALT/CTRL/SHIFT y botones 3, 4 y 5 del ratón). *Quitar* lo desasigna. Escape cancela la captura. No se puede cambiar en combate.
- **Opciones de la rueda:** activa o desactiva cada entrada y reordénala con *Subir* / *Bajar* (máximo 16 activas por rueda). La 1ª va arriba y el resto en sentido horario. La lista tiene scroll con la rueda del ratón.
- **Categorías:** la lista se filtra por *Todo / Menú / Emotes / Comandos*. *Menú* son los paneles del juego; *+ Emote* añade emotes predefinidos (con `DoEmote`) y *+ Comando* crea una entrada con una línea de comando: scripts (`/run ...`) y comandos de otros addons. Las entradas propias son comunes a todas las ruedas, se activan en cada una y se editan con *Editar* (nombre, icono: nombre dentro de `Interface\Icons`, ruta o ID). **Limitación:** Blizzard bloquea `/cast`, `/use` y las macros a los addons, así que hechizos, objetos y macros no se pueden lanzar desde aquí.
- **Aspecto** (común a todas las ruedas): radio, tamaño de iconos, zona muerta, opacidad del fondo, color de acento (4 presets o selector libre), sonidos y animación. *Restaurar valores por defecto* devuelve el aspecto y las opciones de la rueda actual a los valores de fábrica; tus ruedas, entradas propias y atajos se conservan.

Paneles integrados: Personaje, Talentos, Libro de hechizos, Misiones, Mapa del mundo, Hermandad, Amigos, Bolsas (activos por defecto), Mascotas y monturas (desactivado), y Logros y Buscador de mazmorras (solo en clientes que los tienen; en WoW Forever se ocultan). Añadir otro es una entrada en el catálogo de `Core.lua`.

## Notas técnicas

- Cada opción usa la ruta disponible en el cliente; Personaje se activa mediante un botón seguro al soltar la tecla para evitar contaminar la interfaz protegida. `/rh check` muestra las rutas y `/rh debug` cuál se usó al soltar.
- Círculos con máscara redonda (`CreateMaskTexture`), animación con `OnUpdate`, ajustes en `RadialHubDB` (SavedVariables). Código en un namespace privado; los únicos globales son los que exige el cliente.
- Pruebas de la lógica con el API simulado: `lua tests/test.lua` (desde la raíz del repo).

## Licencia

MIT, ver [LICENSE](LICENSE).
