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
- **Categorías:** la lista se filtra por *Todo / Menú / Emotes / Comandos*. *Menú* son los paneles del juego; *+ Emote* añade emotes predefinidos y *+ Comando* crea una entrada con una línea de comando: comandos de otros addons (`/dbm pull 10`), emotes (`/dance`) y `/run` con tu propio código. Las entradas propias son comunes a todas las ruedas, se activan en cada una y se editan con *Editar* (nombre, icono: nombre dentro de `Interface\Icons`, ruta o ID). Los comandos de Blizzard (`/cast`, `/use`, `/macro`, `/reload`...) se rechazan: lanzarlos desde un addon contamina su interfaz.
- **Idioma:** Automático (según el idioma del juego), Español o English. Cambia la rueda, la configuración y los mensajes al momento.
- **Aspecto** (común a todas las ruedas): radio, tamaño de iconos, zona muerta, opacidad del fondo, color de acento (4 presets o selector libre), sonidos y animación. *Restaurar valores por defecto* devuelve el aspecto y las opciones de la rueda actual a los valores de fábrica; tus ruedas, entradas propias y atajos se conservan.

Paneles integrados: Personaje, Talentos, Libro de hechizos, Misiones, Mapa del mundo, Hermandad, Amigos, Bolsas (activos por defecto), Mascotas y monturas (desactivado), y Logros y Buscador de mazmorras (solo en clientes que los tienen; en WoW Forever se ocultan). Añadir otro es una entrada en el catálogo de `Core.lua`.

## Combate y errores de Blizzard

RadialHub sigue unas reglas para no contaminar (taint) la interfaz de Blizzard, que es lo que provoca errores de "valores secretos" o `ADDON_ACTION_BLOCKED` en combate:

- Los paneles del juego se abren con un clic seguro sobre su botón de Blizzard (micro menú, mochila...), nunca desde código del addon. Si tu cliente no tiene el botón de un panel, el panel no aparece. `/rh check` muestra qué botón usa cada panel y qué botones tiene tu cliente.
- En combate los paneles no se pueden elegir desde la rueda (Blizzard no deja cambiar el clic seguro en combate); emotes y comandos sí.
- La configuración no se abre en combate. Tras cambiar un atajo, haz `/reload` antes de entrar en combate.

## Notas técnicas

- Círculos con máscara redonda (`CreateMaskTexture`), animación con `OnUpdate` (solo mientras algo se mueve), ajustes en `RadialHubDB` (SavedVariables). Código en un namespace privado.
- Pruebas de la lógica con el API simulado: `lua tests/test.lua` (desde la raíz del repo). Incluyen una revisión del código que falla si se usa una API que ya contaminó la interfaz antes.

## Licencia

MIT, ver [LICENSE](LICENSE).
