# QuickWheel

Menú radial rápido para **WoW Forever** (Interface 16001): abre Personaje, Talentos, Bolsas, Mapa... sin buscar botones ni memorizar atajos.

1. **Mantén** la tecla: la rueda aparece centrada en el cursor.
2. **Mueve el ratón** hacia una opción: crece, se ilumina con el color de acento y su nombre aparece en el centro. En el centro (zona muerta) no hay nada seleccionado ("Cancelar").
3. **Suelta** la tecla: se abre esa ventana. Si sueltas en el centro, pulsas **Escape** o haces **clic derecho**, se cancela sin hacer nada. Entrar en combate con la rueda abierta también la cancela.

## Instalación

Copia la carpeta a `World of Warcraft/_forever_/Interface/AddOns/QuickWheel` (el nombre de la carpeta debe ser `QuickWheel`) y reinicia el cliente. Si ves un panel que no abre, escribe `/qw check`: lista la ruta que usa cada opción en tu cliente (o "NO DISPONIBLE").

Funciona nada más instalarlo: en el primer inicio asigna **ALT-Q** si esa tecla está libre (si no, te avisa para que elijas otra con `/qw`).

## Configuración

`/qw` o `/quickwheel` (también en *Interface Options → AddOns → QuickWheel*):

- **Atajo de teclado:** pulsa el botón y luego la tecla (admite ALT/CTRL/SHIFT y botones 3, 4 y 5 del ratón). *Quitar* lo desasigna. Escape cancela la captura. No se puede cambiar en combate.
- **Opciones de la rueda:** activa o desactiva cada panel y reordénalo con *Subir* / *Bajar*. La 1ª opción va arriba y el resto en sentido horario.
- **Aspecto:** radio, tamaño de iconos, zona muerta, opacidad del fondo, color de acento (4 presets o selector libre), sonidos y animación. *Restaurar valores por defecto* no toca el atajo.

Paneles disponibles: Personaje, Talentos, Libro de hechizos, Misiones, Mapa del mundo, Hermandad, Bolsas, Logros (activos por defecto), Buscador de mazmorras y Mascotas y monturas (desactivados por defecto). Añadir otro es una línea en el catálogo de `Core.lua`.

## Notas técnicas

- Cada opción lanza el atajo nativo del propio juego (`RunBinding`), así abre el panel correcto de tu cliente; si ese atajo no existe, prueba funciones alternativas (ver el catálogo en `Core.lua`).
- Círculos con máscara redonda (`CreateMaskTexture`), animación con `OnUpdate`, ajustes en `QuickWheelDB` (SavedVariables). Código en un namespace privado; los únicos globales son los que exige el cliente.
- Pruebas de la lógica con el API simulado: `lua tests/test.lua` (desde la raíz del repo).

## Licencia

MIT, ver [LICENSE](LICENSE).
