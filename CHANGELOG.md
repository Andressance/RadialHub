# Changelog

## 0.5.0

- Más idiomas: Deutsch, Français, Italiano y Português se pueden elegir en `/rh`. Русский, 한국어 y 中文 se usan en modo Automático cuando el juego está en ese idioma (su alfabeto solo existe en la fuente de ese cliente).
- Las traducciones son automáticas: si ves algo raro, avísanos. Lo que falte en un idioma se muestra en inglés.

## 0.4.0

- Nuevo: selector de idioma en `/rh` (Automático según el cliente, Español o English). Afecta a la rueda, la configuración y los mensajes.
- Mapa del mundo vuelve a estar disponible en WoW Forever: se abre con un clic seguro en el nombre de la zona del minimapa.

Además, todo lo de la 0.3.2 (que no llegó a publicarse): revisión completa de contaminación (taint) para que RadialHub no vuelva a provocar errores de Blizzard en combate.

- Los paneles del juego solo se abren con un clic seguro sobre su botón de Blizzard (micro menú, mochila...), como ya hacía Personaje. Abrirlos desde Lua contaminaba el estado que luego usa el Modo edición y causaba `ADDON_ACTION_BLOCKED` en `MainActionBar:SetPointBase()` al cambiar de forma en combate. Si tu cliente no tiene el botón de un panel, ese panel no aparece; `/rh check` lista los botones disponibles.
- En combate los paneles no se pueden elegir desde la rueda (Blizzard no deja cambiar el clic seguro en combate). Emotes y comandos sí funcionan.
- Los comandos propios ya no pasan por la caja del chat (la contaminaba): se ejecutan directamente los de otros addons, los emotes y `/run`. Los comandos de Blizzard (`/cast`, `/use`, `/macro`, `/reload`...) se rechazan con un aviso.
- La configuración no se abre en combate y se cierra sola al entrar en combate (nada de teclado ni atajos en combate).
- Si el addon se carga en combate, la preparación del botón seguro espera a salir de combate.
- Quitado el tooltip de los colores predefinidos (usaba el tooltip de Blizzard).
- Las pruebas revisan el código y fallan si alguien vuelve a usar una API que ya contaminó la interfaz (`UISpecialFrames`, `HideUIPanel`, `RunBinding`, `ChatEdit_*`, `RegisterStateDriver`, `Toggle*()`...).

## 0.3.1

- Corregido el error de valores secretos al entrar en el Modo edición (y otros paneles abiertos desde el menú del juego). RadialHub añadía sus ventanas a `UISpecialFrames` para cerrarlas con Escape, y eso contaminaba el menú del juego. Ahora Escape se detecta sin tocar esa lista.
- El botón de RadialHub en Opciones ya no cierra paneles de Blizzard (`HideUIPanel`), otra fuente de contaminación; la ventana de configuración se muestra por encima.

## 0.3.0

- Optimización de CPU. La detección de la tecla mantenida ya no crea tablas ni cadenas en cada fotograma: las teclas asignadas se analizan una vez (al entrar y cuando cambian los atajos) y, si no hay ninguna asignada, no se ejecuta nada.
- La rueda abierta solo redibuja mientras hay algo que animar (apertura, cambio de opción, flechas); quieta, solo comprueba el cursor. Las direcciones de los huecos se calculan una vez al abrirla.

## 0.2.8

- Eliminado el `RegisterStateDriver` y el `SecureHandlerStateTemplate` del botón seguro: contaminaban el gestor de estados de Blizzard, que también cambia la barra de acción al cambiar de forma. Era la causa probable de que, pasado un rato de sesión, aparecieran errores de valores secretos en las barras de acción y la barra no cambiara al transformarse.
- Al salir de combate se limpia cualquier acción segura que hubiera quedado armada (ya no se desarma al entrar en combate).

## 0.2.7

- El botón seguro de Personaje ahora usa atributos específicos para `LeftButton`, el clic usado por el atajo de RadialHub.

## 0.2.6

- Corregido el error de `SetCooldown` con valores secretos: el botón seguro ya no lleva un `OnClick` de addon. La pulsación mantenida se detecta desde un marco separado.

## 0.2.5

- Al entrar en combate, el manejador seguro solo desactiva la acción de abrir Personaje y conserva su destino. Esto sigue el patrón probado en WoW Forever y reduce cambios innecesarios en el botón protegido.

## 0.2.4

- Ajustado el botón seguro de Personaje para que se active al soltar la tecla, incluso cuando el cliente está configurado para ejecutar los botones al pulsarlos.
- Eliminada la ruta de respaldo que llamaba a `ToggleCharacter` desde Lua: si el clic seguro no está disponible, Personaje se oculta en vez de contaminar la interfaz de Blizzard.

## 0.2.3

- Corregido el taint al abrir Personaje: la selección se entrega a un botón seguro que se activa al soltar el mismo atajo. Se conserva el gesto de la rueda.

## 0.2.2

- Corregido que Personaje, Mapa, Hermandad, monturas y otros paneles no se abrieran en 0.2.1: se vuelven a usar las funciones del juego, a través del helper seguro del cliente.
- `RunBinding` se conserva solo como alternativa, ya que no puede ejecutar acciones protegidas desde la ruta insegura de un addon.

## 0.2.1 — Cambios desde 0.1.0

- Ampliada la compatibilidad: WoW Forever probado; interfaces de Classic y Retail incluidas, pendientes de probar.
- Hasta cuatro ruedas independientes, cada una con su propio atajo.
- Ventana de configuración redimensionable, con categorías, reordenación y hasta 16 opciones activas por rueda.
- Añadidas entradas personalizadas para emotes y comandos compatibles con addons.
- Se puede cambiar de rueda con las flechas o la rueda del ratón; clic para elegir y cancelación con Escape, clic derecho o al entrar en combate.
- Actualizados el aspecto y los efectos de la rueda, con selección visual y opciones de sonido y animación.
- Las opciones no disponibles en el cliente actual se ocultan.
- Corregida la apertura de paneles: se priorizan los atajos nativos para evitar contaminar la interfaz protegida de Blizzard.
