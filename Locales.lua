-- RadialHub · Locales: textos en español (la clave) e inglés. ns.L("texto", ...) traduce y aplica string.format.
-- El idioma se elige en /rh (Automático según el cliente, Español o English).
local addonName, ns = ...

local EN = {
	-- paneles, categorías y emotes
	["Personaje"] = "Character", ["Talentos"] = "Talents", ["Libro de hechizos"] = "Spellbook", ["Misiones"] = "Quests",
	["Mapa del mundo"] = "World Map", ["Hermandad"] = "Guild", ["Amigos"] = "Friends", ["Bolsas"] = "Bags",
	["Logros"] = "Achievements", ["Buscador de mazmorras"] = "Dungeon Finder", ["Mascotas y monturas"] = "Pets & Mounts",
	["Todo"] = "All", ["Menú"] = "Menu", ["Comandos"] = "Commands",
	["Bailar"] = "Dance", ["Saludar"] = "Wave", ["Reír"] = "Laugh", ["Vitorear"] = "Cheer", ["Sentarse"] = "Sit",
	["Inclinarse"] = "Bow", ["Besar"] = "Kiss", ["Llorar"] = "Cry", ["Señalar"] = "Point", ["Dar las gracias"] = "Thank",
	["Rugir"] = "Roar", ["Aplaudir"] = "Applaud",
	-- atajos y comandos
	["Abrir rueda %d (mantener pulsada)"] = "Open wheel %d (hold)",
	["Rueda %d"] = "Wheel %d",
	["debe empezar por /"] = "must start with /",
	["%s es un comando protegido de Blizzard; los addons no pueden usarlo"] = "%s is a protected Blizzard command; addons can't use it",
	["%s es un comando de Blizzard; lanzarlo desde un addon contamina su interfaz"] = "%s is a Blizzard command; running it from an addon taints its UI",
	["no se encuentra el comando %s"] = "command %s not found",
	["%s: no tiene comando (edítala en /rh)."] = "%s: it has no command (edit it in /rh).",
	["Error en %s: %s"] = "Error in %s: %s",
	["%s: clic seguro en %s"] = "%s: secure click on %s",
	["%s: |cffff4040NO DISPONIBLE|r (no hay botón de Blizzard)"] = "%s: |cffff4040NOT AVAILABLE|r (no Blizzard button)",
	["Botones del micro menú en este cliente: %s"] = "Micro menu buttons on this client: %s",
	["ninguno"] = "none",
	["No se puede cambiar el atajo en combate."] = "Key bindings can't be changed in combat.",
	["%s estaba asignada a %s; ahora abre la rueda %d."] = "%s was bound to %s; it now opens wheel %d.",
	["listo: mantén %s para abrir la rueda. /rh para configurarla."] = "ready: hold %s to open the wheel. /rh to configure it.",
	["escribe /rh para asignar la tecla de la rueda."] = "type /rh to set the wheel key.",
	["depuración activada"] = "debug on", ["depuración desactivada"] = "debug off",
	-- rueda
	["Cancelar"] = "Cancel",
	["la rueda %d no existe. Créala en /rh."] = "wheel %d doesn't exist. Create it in /rh.",
	["la rueda %d no tiene opciones activas. Usa /rh para activarlas."] = "wheel %d has no active options. Use /rh to enable some.",
	["soltar: %s"] = "release: %s", ["nada seleccionado"] = "nothing selected",
	["%s: en combate no se puede abrir desde la rueda."] = "%s: can't be opened from the wheel in combat.",
	["%s: suelta la tecla de la rueda para abrirlo."] = "%s: release the wheel key to open it.",
	-- configuración
	["%d/%d activas"] = "%d/%d active", ["+ Nueva"] = "+ New", ["¿Seguro?"] = "Sure?", ["Borrar rueda"] = "Delete wheel",
	["Pulsa una tecla..."] = "Press a key...", ["Sin asignar"] = "Not set",
	["Tecla de la rueda %d: mantén, apunta y suelta."] = "Wheel %d key: hold, point and release.",
	["atajo guardado. Haz /reload antes de entrar en combate para que Blizzard no arrastre el cambio."] =
		"key saved. Do a /reload before entering combat so Blizzard doesn't carry the change over.",
	["atajo quitado. Haz /reload antes de entrar en combate para que Blizzard no arrastre el cambio."] =
		"key cleared. Do a /reload before entering combat so Blizzard doesn't carry the change over.",
	["Nombre"] = "Name",
	["Icono: nombre dentro de Interface\\Icons (INV_Misc_Note_01), ruta o ID"] = "Icon: name inside Interface\\Icons (INV_Misc_Note_01), path or ID",
	["Comando (una línea)"] = "Command (one line)",
	["Sirven comandos de otros addons (/dbm pull 10), emotes (/dance) y /run con tu propio código. Los comandos de Blizzard (/cast, /use, /macro, /reload...) no: lanzarlos desde un addon contamina su interfaz."] =
		"Other addons' commands (/dbm pull 10), emotes (/dance) and /run with your own code work. Blizzard commands (/cast, /use, /macro, /reload...) don't: running them from an addon taints its UI.",
	["Guardar"] = "Save", ["Sin nombre"] = "Unnamed", ["Eliminar entrada"] = "Delete entry",
	["Editar entrada"] = "Edit entry", ["Nuevo comando"] = "New command", ["Añadir emote"] = "Add emote", ["Cerrar"] = "Close",
	["Después puedes cambiar su nombre o icono con Editar."] = "You can change its name or icon later with Edit.",
	["máximo %d opciones por rueda."] = "at most %d options per wheel.",
	["Bajar"] = "Down", ["Subir"] = "Up", ["Editar"] = "Edit",
	["Ruedas"] = "Wheels", ["Atajo de teclado"] = "Key binding", ["Quitar"] = "Clear",
	["Opciones de la rueda"] = "Wheel options", ["1ª arriba, luego en sentido horario"] = "1st on top, then clockwise",
	["+ Comando"] = "+ Command",
	["Aspecto"] = "Appearance", ["Radio de la rueda"] = "Wheel radius", ["Tamaño de los iconos"] = "Icon size",
	["Zona muerta central"] = "Center dead zone", ["Opacidad del fondo"] = "Background opacity",
	["Color de acento"] = "Accent color", ["Personalizado..."] = "Custom...",
	["Opciones"] = "Options", ["Sonidos"] = "Sounds", ["Animación"] = "Animation",
	["Idioma"] = "Language", ["Automático"] = "Auto",
	["Restaurar valores por defecto"] = "Restore defaults",
	["Aspecto y opciones de la rueda actual.\nTus ruedas y entradas propias se conservan."] =
		"Appearance and the current wheel's options.\nYour wheels and custom entries are kept.",
	["la configuración no se puede abrir en combate."] = "settings can't be opened in combat.",
	["error al crear la ventana: %s"] = "error creating the window: %s",
	["Rueda radial rápida. También con /rh."] = "Quick radial wheel. Also with /rh.",
	["Abrir configuración"] = "Open settings",
}
ns.EN = EN

ns.lang = (GetLocale and GetLocale():sub(1, 2) == "es") and "es" or "en"

function ns.L(text, ...)
	if ns.lang == "en" and EN[text] then text = EN[text] end
	if select("#", ...) > 0 then return text:format(...) end
	return text
end

-- "auto" (según el cliente), "es" o "en".
function ns.SetLanguage(choice)
	if choice == "es" or choice == "en" then
		ns.lang = choice
	else
		ns.lang = (GetLocale and GetLocale():sub(1, 2) == "es") and "es" or "en"
	end
	for i = 1, ns.MAX_PROFILES or 0 do
		_G["BINDING_NAME_" .. ns.BINDINGS[i]] = ns.L("Abrir rueda %d (mantener pulsada)", i)
	end
end
