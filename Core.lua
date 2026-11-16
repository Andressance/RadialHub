-- RadialHub · Core: base de datos, catálogo de acciones, atajo y comandos.
-- Probado en WoW Forever (Interface 16001); Retail y Classic son experimentales (las opciones sin ruta se ocultan). Todo vive en el namespace privado `ns`; los únicos
-- globales son los que el cliente exige: RadialHubDB (SavedVariables), RadialHub_OnKey (Bindings.xml),
-- los textos de BINDING_*, SLASH_*, y los marcos con nombre RadialHubFrame / RadialHubConfig (para Escape).
local addonName, ns = ...

-- Hasta 4 ruedas (perfiles), cada una con su propio atajo (Bindings.xml).
ns.MAX_PROFILES = 4
ns.MAX_SLOTS = 16 -- opciones máximas activas por rueda
ns.BINDINGS, ns.LEGACY_BINDINGS = {}, {}
local secureInputs = {}
local secureCharacterSelected = {}

BINDING_HEADER_RADIALHUB = "RadialHub"
for i = 1, ns.MAX_PROFILES do
	local name = "RadialHubSecureInput" .. i
	ns.BINDINGS[i] = "CLICK " .. name .. ":LeftButton"
	ns.LEGACY_BINDINGS[i] = { "RADIALHUB_TOGGLE" .. (i == 1 and "" or i), "QUICKWHEEL_TOGGLE" .. (i == 1 and "" or i) }
	_G["BINDING_NAME_" .. ns.BINDINGS[i]] = "Abrir rueda " .. i .. " (mantener pulsada)"
	local profile = i
	local input = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
	input:SetSize(1, 1); input:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -20, -20)
	input:SetAlpha(0); input:EnableMouse(true); input:RegisterForClicks("AnyDown", "AnyUp")
	input:SetAttribute("useOnKeyDown", false)
	-- This button is only bound through CLICK ...:LeftButton, so use the exact
	-- click attributes instead of wildcard attributes.
	-- No RegisterStateDriver / SecureHandlerStateTemplate aquí: ese registro contamina SecureStateDriverManager,
	-- que es quien pagina la barra de acción (formas, etc.), y rompía las barras tras un rato de sesión.
	input:SetAttribute("type1", nil)
	secureInputs[i] = input
end

function ns.SetSecureCharacterAction(i, enabled)
	local input = secureInputs[i]
	secureCharacterSelected[i] = enabled and CharacterMicroButton ~= nil or false
	if InCombatLockdown() then return end
	input:SetAttribute("type1", secureCharacterSelected[i] and "click" or nil)
	input:SetAttribute("clickbutton1", secureCharacterSelected[i] and CharacterMicroButton or nil)
end

function ns.HasSecureCharacterAction(i) return secureCharacterSelected[i] end

local DEFAULT_KEY = "ALT-Q" -- solo se asigna una vez, a la rueda 1, y si está libre

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100RadialHub|r: " .. msg)
end

----------------------------------------------------------------------------------------------------
-- Círculos nítidos con la máscara redonda de Blizzard (mismo recurso que los retratos).
-- Sirve para el icono (path) y para discos de color (sin path = textura blanca que se tiñe con SetVertexColor).
----------------------------------------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

function ns.Circle(tex, path)
	path = path or WHITE
	tex:SetTexture(path)
	if tex.AddMaskTexture then
		if not tex.rhMask then
			local mask = tex:GetParent():CreateMaskTexture()
			mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetAllPoints(tex)
			tex:AddMaskTexture(mask)
			tex.rhMask = mask
		end
	else
		SetPortraitToTexture(tex, path) -- clientes sin máscaras
	end
end

----------------------------------------------------------------------------------------------------
-- Catálogo de acciones. Para añadir un panel basta con una entrada más.
-- Cada acción prueba, por orden, funciones del propio juego y, si no, su atajo nativo (RunBinding):
--   fn   = { "Funcion" o "Tabla.Funcion", arg1, arg2... }; vale la primera que existe y no da error.
--   bind = nombres de binding; se comprueba que existan con BINDING_NAME_<bind>.
-- /rh check muestra qué ruta usa cada entrada en tu cliente.
----------------------------------------------------------------------------------------------------
local ICON = "Interface\\Icons\\"

ns.Catalog = {
	{ id = "character",    name = "Personaje",             icon = ICON .. "INV_Shirt_White_01",        default = true,
		secureClick = "CharacterMicroButton", bind = {}, fn = {} },
	{ id = "talents",      name = "Talentos",              icon = ICON .. "Spell_Holy_ArcaneIntellect", default = true,
		bind = { "TOGGLETALENTS" },
		fn = { { "PlayerSpellsUtil.ToggleClassTalentOrSpecFrame" }, { "ToggleTalentFrame" } } },
	{ id = "spellbook",    name = "Libro de hechizos",     icon = ICON .. "INV_Misc_Book_09",          default = true,
		bind = { "TOGGLESPELLBOOK" },
		fn = { { "PlayerSpellsUtil.ToggleSpellBookFrame" }, { "ToggleSpellBook", "spell" } } },
	{ id = "quests",       name = "Misiones",              icon = ICON .. "INV_Misc_Note_01",          default = true,
		bind = { "TOGGLEQUESTLOG" },
		fn = { { "ToggleQuestLog" } } },
	{ id = "map",          name = "Mapa del mundo",        icon = ICON .. "INV_Misc_Map_01",           default = true,
		bind = { "TOGGLEWORLDMAP" },
		fn = { { "ToggleWorldMap" } } },
	{ id = "guild",        name = "Hermandad",             icon = ICON .. "INV_Shirt_GuildTabard_01",  default = true,
		bind = { "TOGGLEGUILDTAB" },
		fn = { { "ToggleGuildFrame" }, { "ToggleFriendsFrame", 3 } } },
	{ id = "friends",      name = "Amigos",                icon = ICON .. "INV_Misc_GroupLooking",     default = true,
		bind = { "TOGGLESOCIAL", "TOGGLEFRIENDSTAB" },
		fn = { { "ToggleFriendsFrame", 1 } } },
	{ id = "bags",         name = "Bolsas",                icon = ICON .. "INV_Misc_Bag_08",           default = true,
		bind = { "OPENALLBAGS" },
		fn = { { "ToggleAllBags" } } },
	{ id = "achievements", name = "Logros",                icon = ICON .. "Achievement_General",       default = true, noForever = true,
		bind = { "TOGGLEACHIEVEMENT" },
		fn = { { "ToggleAchievementFrame" } } },
	{ id = "lfd",          name = "Buscador de mazmorras", icon = ICON .. "INV_Misc_GroupLooking",     default = false, noForever = true,
		bind = { "TOGGLEGROUPFINDER", "TOGGLELFGPARENT" },
		fn = { { "PVEFrame_ToggleFrame" }, { "ToggleLFDParentFrame" } } },
	{ id = "pets",         name = "Mascotas y monturas",   icon = ICON .. "Ability_Mount_RidingHorse", default = false,
		bind = { "TOGGLEMOUNTJOURNAL", "TOGGLECOLLECTIONS", "TOGGLEPETBOOK" },
		fn = { { "ToggleCollectionsJournal" }, { "ToggleCharacter", "PetPaperDollFrame" } } },
}

-- WoW Forever no tiene todos los paneles: las entradas marcadas noForever no existen allí y se ocultan.
ns.IsForever = (WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
	or (WOW_PROJECT_FOREVER and WOW_PROJECT_ID == WOW_PROJECT_FOREVER) or false
if ns.IsForever then
	local kept = {}
	for _, entry in ipairs(ns.Catalog) do
		if not entry.noForever then kept[#kept + 1] = entry end
	end
	ns.Catalog = kept
end

ns.CatalogByID = {}
for _, entry in ipairs(ns.Catalog) do ns.CatalogByID[entry.id] = entry end

-- Colores de acento predefinidos (los usa Config.lua y el valor por defecto).
ns.Presets = {
	{ name = "Dorado",       1.00, 0.82, 0.20 },
	{ name = "Azul Arcano",  0.30, 0.60, 1.00 },
	{ name = "Esmeralda",    0.20, 0.85, 0.50 },
	{ name = "Blanco",       1.00, 1.00, 1.00 },
}

-- Categorías de la lista de opciones: integradas = "menu"; propias = "emote" o "command".
ns.Categories = { { id = "menu", name = "Menú" }, { id = "emote", name = "Emotes" }, { id = "command", name = "Comandos" } }
function ns.CatOf(entry) return entry.custom and (entry.cat or "command") or "menu" end

-- Emotes predefinidos (nombre, señal de DoEmote, icono). Se añaden como entradas propias editables.
ns.Emotes = {
	{ "Bailar", "DANCE", "INV_Misc_Note_01" },       { "Saludar", "WAVE", "INV_Misc_Note_01" },
	{ "Reír", "LAUGH", "Spell_Holy_Heal" },          { "Vitorear", "CHEER", "Ability_Warrior_BattleShout" },
	{ "Sentarse", "SIT", "INV_Misc_Note_01" },       { "Inclinarse", "BOW", "INV_Misc_Note_01" },
	{ "Besar", "KISS", "Spell_Holy_Heal" },          { "Llorar", "CRY", "INV_Misc_Note_01" },
	{ "Señalar", "POINT", "INV_Misc_Note_01" },      { "Dar las gracias", "THANK", "Spell_Holy_Heal" },
	{ "Rugir", "ROAR", "Ability_Warrior_BattleShout" }, { "Aplaudir", "APPLAUD", "Ability_Warrior_BattleShout" },
}

-- Icono de una entrada: ruta completa, ID numérico o nombre dentro de Interface\Icons.
function ns.IconPath(icon)
	if not icon or icon == "" then return ICON .. "INV_Misc_QuestionMark" end
	if tonumber(icon) then return tonumber(icon) end
	if icon:find("[\\/]") then return icon end
	return ICON .. icon
end

-- Entrada propia: emotes, /run <código Lua> y comandos de otros addons. Blizzard bloquea /cast y /use a los addons.
local function RunCommand(entry)
	if entry.emote then
		local ok, err = pcall(DoEmote, entry.emote)
		if not ok then ns.Print("Error en " .. entry.name .. ": " .. tostring(err)) end
		return
	end
	local text = strtrim(entry.command or "")
	if text == "" then ns.Print(entry.name .. ": no tiene comando (edítala en /rh)."); return end
	local cmd, code = text:match("^/(%a+)%s+(.*)$")
	local ok, err
	if cmd and (strlower(cmd) == "run" or strlower(cmd) == "script") then
		ok, err = pcall(RunScript, code)
	else
		local box = DEFAULT_CHAT_FRAME.editBox
		box:SetText(text)
		ok, err = pcall(ChatEdit_SendText, box, 0)
		box:SetText("")
	end
	if not ok then ns.Print("Error en " .. entry.name .. ": " .. tostring(err)) end
end

-- El helper seguro evita propagar taint al abrir paneles; RunBinding no ejecuta acciones protegidas desde el addon.
local function Routes(entry)
	local routes = {}
	for _, spec in ipairs(entry.fn) do
		local f = _G
		for part in spec[1]:gmatch("[^.]+") do f = type(f) == "table" and f[part] or nil end
		if type(f) == "function" then
			routes[#routes + 1] = { label = "fn " .. spec[1], run = function()
				local call = securecallfunction or securecall
				if call then call(f, unpack(spec, 2)) else f(unpack(spec, 2)) end
			end }
		end
	end
	for _, b in ipairs(entry.bind) do
		if _G["BINDING_NAME_" .. b] then
			routes[#routes + 1] = { label = "binding " .. b, run = function() RunBinding(b) end }
		end
	end
	return routes
end

-- ¿Se puede abrir en este cliente? Las entradas propias siempre; las integradas, si tienen alguna ruta.
-- Se evalúa al usarlas (no al cargar) porque algunas funciones de Blizzard se definen más tarde.
function ns.Available(entry)
	return entry.custom or (entry.secureClick and _G[entry.secureClick] ~= nil) or #Routes(entry) > 0
end

-- Prueba cada ruta hasta que una no falle; /rh debug muestra cuál se usó.
function ns.Run(entry)
	if entry.custom then return RunCommand(entry) end
	local routes, err = Routes(entry)
	for _, route in ipairs(routes) do
		local ok, e = pcall(route.run)
		if ok then
			if ns.debug then ns.Print(entry.name .. " -> " .. route.label) end
			return
		end
		err = e
	end
	if err then
		ns.Print("No se pudo abrir " .. entry.name .. ": " .. tostring(err))
	else
		ns.Print(entry.name .. " no está disponible en este cliente (/rh check para ver el detalle).")
	end
end

function ns.Check()
	for _, entry in ipairs(ns.Catalog) do
		local route = entry.secureClick and _G[entry.secureClick] and { label = "secure click " .. entry.secureClick } or Routes(entry)[1]
		ns.Print(entry.name .. ": " .. (route and route.label or "|cffff4040NO DISPONIBLE|r"))
	end
end

----------------------------------------------------------------------------------------------------
-- RadialHubDB
--   (aspecto global) radius, iconSize, deadzone, bgAlpha, accent, sound, anim
--   profiles[1..4] = { name, items = { { id, on }... } }   -- una por rueda; puede haber huecos
--   custom[id]     = { id, name, icon, command, cat, emote, custom = true }   -- entradas propias (comunes a todas las ruedas)
--   selected       = rueda que muestra la ventana de configuración
----------------------------------------------------------------------------------------------------
local defaults = {
	radius   = 110,   -- distancia de los iconos al centro
	iconSize = 52,    -- diámetro de cada icono
	deadzone = 38,    -- radio de la zona muerta central
	bgAlpha  = 0.55,  -- opacidad del fondo de la rueda
	accent   = { ns.Presets[1][1], ns.Presets[1][2], ns.Presets[1][3] },
	sound    = true,
	anim     = true,
}
local APPEARANCE = { "radius", "iconSize", "deadzone", "bgAlpha", "accent", "sound", "anim" }

function ns.Entry(id) return ns.CatalogByID[id] or ns.db.custom[id] end

-- Mantiene los items de una rueda al día: sin ids borrados, con los integrados y propios que falten al final.
local function Sync(profile, db)
	local seen, items = {}, {}
	for _, it in ipairs(profile.items) do
		if (ns.CatalogByID[it.id] or db.custom[it.id]) and not seen[it.id] then seen[it.id] = true; items[#items + 1] = it end
	end
	for _, entry in ipairs(ns.Catalog) do
		if not seen[entry.id] then items[#items + 1] = { id = entry.id, on = entry.default } end
	end
	local ids = {}
	for id in pairs(db.custom) do if not seen[id] then ids[#ids + 1] = id end end
	table.sort(ids)
	for _, id in ipairs(ids) do items[#items + 1] = { id = id, on = false } end
	profile.items = items
end

local function Fill(db)
	for k, v in pairs(defaults) do
		if db[k] == nil then db[k] = type(v) == "table" and { unpack(v) } or v end
	end
	db.custom = db.custom or {}
	if not db.profiles then -- migración desde la versión de una sola rueda (order/enabled)
		local items = {}
		for _, id in ipairs(db.order or {}) do items[#items + 1] = { id = id, on = db.enabled and db.enabled[id] or false } end
		db.profiles = { { name = "Rueda 1", items = items } }
		db.order, db.enabled = nil, nil
	end
	db.profiles[1] = db.profiles[1] or { name = "Rueda 1", items = {} }
	for i = 1, ns.MAX_PROFILES do
		if db.profiles[i] then Sync(db.profiles[i], db) end
	end
	if not (db.selected and db.profiles[db.selected]) then db.selected = 1 end
end

-- Aspecto y opciones de la rueda seleccionada vuelven a los valores de fábrica; ruedas y entradas propias se conservan.
function ns.ResetDB()
	local db = ns.db
	for _, k in ipairs(APPEARANCE) do db[k] = nil end
	db.profiles[db.selected].items = {}
	Fill(db)
end

-- Rueda i nueva como copia de la rueda src.
function ns.NewProfile(i, src)
	local items = {}
	for _, it in ipairs(src.items) do items[#items + 1] = { id = it.id, on = it.on } end
	ns.db.profiles[i] = { name = "Rueda " .. i, items = items }
end

function ns.DeleteProfile(i)
	if i == 1 then return end -- la 1 es la rueda base
	ns.db.profiles[i] = nil
	ns.ClearKey(i)
	if ns.db.selected == i then ns.db.selected = 1 end
end

-- fields = { name, icon, command, cat, emote }; se activa solo en la rueda `profile`.
function ns.AddCustom(fields, profile)
	local db = ns.db
	db.nextId = (db.nextId or 0) + 1
	local id = "c" .. db.nextId
	db.custom[id] = { id = id, name = fields.name, icon = fields.icon, command = fields.command,
		cat = fields.cat, emote = fields.emote, custom = true }
	for i = 1, ns.MAX_PROFILES do
		local p = db.profiles[i]
		if p then p.items[#p.items + 1] = { id = id, on = (i == profile) } end
	end
	return id
end

function ns.DeleteCustom(id)
	ns.db.custom[id] = nil
	for i = 1, ns.MAX_PROFILES do
		if ns.db.profiles[i] then Sync(ns.db.profiles[i], ns.db) end
	end
end

-- Entradas activas de la rueda i, en su orden (nil si esa rueda no existe).
function ns.GetActive(i)
	local p = ns.db.profiles[i]
	if not p then return nil end
	local list = {}
	for _, it in ipairs(p.items) do
		local entry = ns.Entry(it.id)
		if it.on and ns.Available(entry) and #list < ns.MAX_SLOTS then list[#list + 1] = entry end
	end
	return list
end

----------------------------------------------------------------------------------------------------
-- Atajos de teclado (SetBinding + SaveBindings; el cliente los bloquea en combate). i = nº de rueda.
----------------------------------------------------------------------------------------------------
function ns.BindKey(key, i)
	if InCombatLockdown() then ns.Print("No se puede cambiar el atajo en combate."); return false end
	local binding = ns.BINDINGS[i]
	local prev = GetBindingAction(key)
	for _, old in ipairs({ GetBindingKey(binding) }) do SetBinding(old) end
	if not SetBindingClick(key, "RadialHubSecureInput" .. i, "LeftButton") then return false end
	SaveBindings(GetCurrentBindingSet())
	if prev and prev ~= "" and prev ~= binding then
		ns.Print(GetBindingText(key, "KEY_") .. " estaba asignada a " .. (_G["BINDING_NAME_" .. prev] or prev) .. "; ahora abre la rueda " .. i .. ".")
	end
	return true
end

function ns.ClearKey(i)
	if InCombatLockdown() then ns.Print("No se puede cambiar el atajo en combate."); return end
	for _, old in ipairs({ GetBindingKey(ns.BINDINGS[i]) }) do SetBinding(old) end
	SaveBindings(GetCurrentBindingSet())
end

-- Lo llama Bindings.xml: "down" abre la rueda i, "up" ejecuta la opción apuntada.
function RadialHub_OnKey(keystate, i)
	if keystate == "down" then ns.Wheel.Open(i) else ns.Wheel.Cancel() end -- obsolete legacy binding; never invoke protected panels here
end
function QuickWheel_OnKey(keystate, i) RadialHub_OnKey(keystate, i) end -- migration alias

----------------------------------------------------------------------------------------------------
-- Eventos y comandos
----------------------------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "PLAYER_REGEN_ENABLED" then
		-- los atributos seguros no se pueden cambiar en combate: al salir, se limpia cualquier acción que quedara armada
		for i = 1, ns.MAX_PROFILES do ns.SetSecureCharacterAction(i, false) end
	elseif event == "ADDON_LOADED" and arg1 == addonName then
		RadialHubDB = RadialHubDB or {}
		ns.db = RadialHubDB
		Fill(ns.db)
	elseif event == "PLAYER_LOGIN" then
		for i = 1, ns.MAX_PROFILES do
			if not GetBindingKey(ns.BINDINGS[i]) then
				for _, legacy in ipairs(ns.LEGACY_BINDINGS[i]) do
					local key = GetBindingKey(legacy)
					if key then ns.BindKey(key, i); break end
				end
			end
		end
		if ns.db.keyInit then return end
		ns.db.keyInit = true
		local action = GetBindingAction(DEFAULT_KEY)
		if not GetBindingKey(ns.BINDINGS[1]) and (not action or action == "") and ns.BindKey(DEFAULT_KEY, 1) then
			ns.Print("listo: mantén " .. DEFAULT_KEY .. " para abrir la rueda. /rh para configurarla.")
		elseif not GetBindingKey(ns.BINDINGS[1]) then
			ns.Print("escribe /rh para asignar la tecla de la rueda.")
		end
	end
end)

-- SecureActionButtonTemplate must not have addon OnClick scripts: they taint Blizzard's action-button cooldown path.
local MOUSE_BUTTONS = { BUTTON1 = "LeftButton", BUTTON2 = "RightButton", BUTTON3 = "MiddleButton", BUTTON4 = "Button4", BUTTON5 = "Button5" }
local heldProfiles, inputMonitor = {}, CreateFrame("Frame")
local function BoundKeyDown(key)
	local base = key:match("[^-]+$")
	if not base
		or (key:find("ALT-", 1, true) ~= nil) ~= (IsAltKeyDown() and true or false)
		or (key:find("CTRL-", 1, true) ~= nil) ~= (IsControlKeyDown() and true or false)
		or (key:find("SHIFT-", 1, true) ~= nil) ~= (IsShiftKeyDown() and true or false) then return false end
	local mouseButton = MOUSE_BUTTONS[base]
	if mouseButton then return IsMouseButtonDown(mouseButton) end
	return IsKeyDown(base)
end
inputMonitor:SetScript("OnUpdate", function()
	for i = 1, ns.MAX_PROFILES do
		local down = false
		for _, key in ipairs({ GetBindingKey(ns.BINDINGS[i]) }) do
			if key and BoundKeyDown(key) then down = true; break end
		end
		if down and not heldProfiles[i] then
			heldProfiles[i] = true
			ns.Wheel.Open(i)
		elseif not down and heldProfiles[i] then
			heldProfiles[i] = nil
			if ns.HasSecureCharacterAction(i) then
				ns.SetSecureCharacterAction(i, false)
				ns.Wheel.Cancel()
			else
				ns.Wheel.Release()
			end
		end
	end
end)

SLASH_RADIALHUB1 = "/rh"
SLASH_RADIALHUB2 = "/radialhub"
SlashCmdList["RADIALHUB"] = function(msg)
	local cmd = strlower(strtrim(msg or ""))
	if cmd == "check" then ns.Check()
	elseif cmd == "debug" then
		ns.debug = not ns.debug
		ns.Print("depuración " .. (ns.debug and "activada" or "desactivada"))
	else ns.Config.Toggle() end
end
