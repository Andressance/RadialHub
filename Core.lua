-- RadialHub · Core: base de datos, catálogo de acciones, atajo y comandos.
-- Probado en WoW Forever (Interface 16001); Retail y Classic son experimentales. Todo vive en el namespace privado `ns`.
--
-- Reglas anti-contaminación (taint). Romper cualquiera de ellas ha causado errores en combate en versiones anteriores,
-- y tests/test.lua comprueba las que se pueden comprobar leyendo el código:
--   * Los paneles de Blizzard solo se abren con un clic seguro sobre su botón (micro menú, mochila...). Nunca desde Lua.
--   * Nada de UISpecialFrames, HideUIPanel/ShowUIPanel, RunBinding, ChatEdit_*, hooksecurefunc, RegisterStateDriver.
--   * Los comandos propios solo ejecutan comandos de otros addons, emotes y /run; los de Blizzard se rechazan.
--   * Nada que toque atributos seguros, atajos o teclado se hace en combate.
local addonName, ns = ...
local L = ns.L

-- Hasta 4 ruedas (perfiles), cada una con su propio atajo (Bindings.xml).
ns.MAX_PROFILES = 4
ns.MAX_SLOTS = 16 -- opciones máximas activas por rueda
ns.BINDINGS, ns.LEGACY_BINDINGS = {}, {}
local secureInputs = {}
local armedEntry = {} -- entrada armada de verdad en el botón seguro de cada rueda (solo se cambia fuera de combate)

BINDING_HEADER_RADIALHUB = "RadialHub"
for i = 1, ns.MAX_PROFILES do
	local name = "RadialHubSecureInput" .. i
	ns.BINDINGS[i] = "CLICK " .. name .. ":LeftButton"
	ns.LEGACY_BINDINGS[i] = { "RADIALHUB_TOGGLE" .. (i == 1 and "" or i), "QUICKWHEEL_TOGGLE" .. (i == 1 and "" or i) }
	_G["BINDING_NAME_" .. ns.BINDINGS[i]] = L("Abrir rueda %d (mantener pulsada)", i)
	-- Solo se usa con CLICK ...:LeftButton, así que van atributos exactos ("type1"), no comodines.
	-- Sin RegisterStateDriver / SecureHandlerStateTemplate: contaminan SecureStateDriverManager, que pagina las barras.
	secureInputs[i] = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
end

-- Configuración protegida de los botones seguros: si el addon se carga en combate, se aplaza a la salida.
local inputsReady = false
local function SetupInputs()
	if inputsReady or InCombatLockdown() then return end
	for _, input in ipairs(secureInputs) do
		input:SetSize(1, 1); input:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -20, -20)
		input:SetAlpha(0); input:EnableMouse(true); input:RegisterForClicks("AnyDown", "AnyUp")
		input:SetAttribute("useOnKeyDown", false)
	end
	inputsReady = true
end
SetupInputs()

-- Botón de Blizzard (micro menú, mochila...) que abre la entrada con un clic seguro; nil si este cliente no lo tiene.
-- Abrir paneles desde Lua de un addon contamina la interfaz (barras, Modo edición...); el clic seguro no.
function ns.SecureButton(entry)
	if not entry.secure then return nil end
	for _, name in ipairs(entry.secure) do
		local b = _G
		for part in name:gmatch("[^.]+") do b = type(b) == "table" and b[part] or nil end -- admite "Marco.Hijo"
		if type(b) == "table" and b.Click then return b, name end
	end
end

-- Arma (o desarma con nil) la entrada que el botón seguro de la rueda i pulsará al soltar la tecla.
-- En combate los atributos seguros no se pueden cambiar: se queda como estaba (se limpia al salir de combate).
function ns.SetSecureAction(i, entry)
	if InCombatLockdown() or not inputsReady then return end
	local button = entry and ns.SecureButton(entry)
	local input = secureInputs[i]
	input:SetAttribute("type1", button and "click" or nil)
	input:SetAttribute("clickbutton1", button or nil)
	armedEntry[i] = button and entry or nil
end

function ns.ArmedAction(i) return armedEntry[i] end

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
-- Catálogo de paneles. Cada uno se abre con un clic seguro sobre el primer botón de Blizzard de `secure` que
-- exista en este cliente; si no hay ninguno, el panel no aparece. Para añadir uno basta con una entrada más.
-- /rh check muestra qué botón usa cada panel y qué botones del micro menú tiene tu cliente.
----------------------------------------------------------------------------------------------------
local ICON = "Interface\\Icons\\"

ns.Catalog = {
	{ id = "character",    name = "Personaje",             icon = ICON .. "INV_Shirt_White_01",        default = true,
		secure = { "CharacterMicroButton" } },
	{ id = "talents",      name = "Talentos",              icon = ICON .. "Spell_Holy_ArcaneIntellect", default = true,
		secure = { "TalentMicroButton", "PlayerSpellsMicroButton" } },
	{ id = "spellbook",    name = "Libro de hechizos",     icon = ICON .. "INV_Misc_Book_09",          default = true,
		secure = { "SpellbookMicroButton" } },
	{ id = "quests",       name = "Misiones",              icon = ICON .. "INV_Misc_Note_01",          default = true,
		secure = { "QuestLogMicroButton" } },
	{ id = "map",          name = "Mapa del mundo",        icon = ICON .. "INV_Misc_Map_01",           default = true,
		secure = { "WorldMapMicroButton", "MiniMapWorldMapButton", "MinimapCluster.ZoneTextButton" } },
	{ id = "guild",        name = "Hermandad",             icon = ICON .. "INV_Shirt_GuildTabard_01",  default = true,
		secure = { "GuildMicroButton" } },
	{ id = "friends",      name = "Amigos",                icon = ICON .. "INV_Misc_GroupLooking",     default = true,
		secure = { "SocialsMicroButton", "QuickJoinToastButton" } },
	{ id = "bags",         name = "Bolsas",                icon = ICON .. "INV_Misc_Bag_08",           default = true,
		secure = { "MainMenuBarBackpackButton" } },
	{ id = "achievements", name = "Logros",                icon = ICON .. "Achievement_General",       default = true, noForever = true,
		secure = { "AchievementMicroButton" } },
	{ id = "lfd",          name = "Buscador de mazmorras", icon = ICON .. "INV_Misc_GroupLooking",     default = false, noForever = true,
		secure = { "LFDMicroButton", "LFGMicroButton" } },
	{ id = "pets",         name = "Mascotas y monturas",   icon = ICON .. "Ability_Mount_RidingHorse", default = false,
		secure = { "CollectionsMicroButton" } },
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

-- Comando escrito en una entrada propia -> función a ejecutar, o nil y el motivo.
-- Sin pasar por la caja del chat (ChatEdit_SendText la contamina). Solo comandos de addons, emotes y /run:
-- los de Blizzard (secure o no) tocarían su interfaz desde código de addon.
local function EmoteToken(cmd)
	if hash_EmoteTokenList and hash_EmoteTokenList[cmd] then return hash_EmoteTokenList[cmd] end
	for i = 1, MAXEMOTEINDEX or 600 do
		local token = _G["EMOTE" .. i .. "_TOKEN"]
		if token then
			for j = 1, 10 do
				local c = _G["EMOTE" .. i .. "_CMD" .. j]
				if not c then break end
				if strupper(c) == cmd then return token end
			end
		end
	end
end

local function ResolveCommand(text)
	local cmd, rest = text:match("^(/%S+)%s*(.-)%s*$")
	if not cmd then return nil, L("debe empezar por /") end
	cmd = strupper(cmd)
	if cmd == "/RUN" or cmd == "/SCRIPT" then
		return function() RunScript(rest) end
	end
	if hash_SecureCmdList and hash_SecureCmdList[cmd] then
		return nil, L("%s es un comando protegido de Blizzard; los addons no pueden usarlo", cmd:lower())
	end
	for key, fn in pairs(SlashCmdList) do
		local i = 1
		while _G["SLASH_" .. key .. i] do
			if strupper(_G["SLASH_" .. key .. i]) == cmd then
				if issecurevariable and issecurevariable(SlashCmdList, key) then
					return nil, L("%s es un comando de Blizzard; lanzarlo desde un addon contamina su interfaz", cmd:lower())
				end
				return function() fn(rest, DEFAULT_CHAT_FRAME.editBox) end
			end
			i = i + 1
		end
	end
	local token = EmoteToken(cmd)
	if token then return function() DoEmote(token) end end
	return nil, L("no se encuentra el comando %s", cmd:lower())
end
ns.ResolveCommand = ResolveCommand

local function RunCommand(entry)
	local run, why
	if entry.emote then
		run = function() DoEmote(entry.emote) end
	else
		local text = strtrim(entry.command or "")
		if text == "" then ns.Print(L("%s: no tiene comando (edítala en /rh).", entry.name)); return end
		run, why = ResolveCommand(text)
	end
	if not run then ns.Print(entry.name .. ": " .. why .. "."); return end
	local ok, err = pcall(run)
	if not ok then ns.Print(L("Error en %s: %s", entry.name, tostring(err))) end
end

-- ¿Se puede usar en este cliente? Las entradas propias siempre; los paneles, si tienen botón de Blizzard.
-- Se evalúa al usarlas (no al cargar) porque algunos botones de Blizzard se crean más tarde.
function ns.Available(entry)
	return entry.custom or ns.SecureButton(entry) ~= nil
end

-- Solo las entradas propias se ejecutan desde Lua; los paneles los abre el clic seguro al soltar la tecla.
function ns.Run(entry)
	if entry.custom then return RunCommand(entry) end
end

function ns.Check()
	for _, entry in ipairs(ns.Catalog) do
		local _, button = ns.SecureButton(entry)
		ns.Print(button and L("%s: clic seguro en %s", L(entry.name), button)
			or L("%s: |cffff4040NO DISPONIBLE|r (no hay botón de Blizzard)", L(entry.name)))
	end
	local found = {}
	for k, v in pairs(_G) do
		if type(k) == "string" and k:find("MicroButton$") and type(v) == "table" and v.Click then found[#found + 1] = k end
	end
	table.sort(found)
	ns.Print(L("Botones del micro menú en este cliente: %s", #found > 0 and table.concat(found, ", ") or L("ninguno")))
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
		db.profiles = { { name = L("Rueda %d", 1), items = items } }
		db.order, db.enabled = nil, nil
	end
	db.profiles[1] = db.profiles[1] or { name = L("Rueda %d", 1), items = {} }
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
	ns.db.profiles[i] = { name = L("Rueda %d", i), items = items }
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
	if InCombatLockdown() then ns.Print(L("No se puede cambiar el atajo en combate.")); return false end
	local binding = ns.BINDINGS[i]
	local prev = GetBindingAction(key)
	for _, old in ipairs({ GetBindingKey(binding) }) do SetBinding(old) end
	if not SetBindingClick(key, "RadialHubSecureInput" .. i, "LeftButton") then return false end
	SaveBindings(GetCurrentBindingSet())
	ns.RefreshWatchedKeys()
	if prev and prev ~= "" and prev ~= binding then
		ns.Print(L("%s estaba asignada a %s; ahora abre la rueda %d.", GetBindingText(key, "KEY_"), _G["BINDING_NAME_" .. prev] or prev, i))
	end
	return true
end

function ns.ClearKey(i)
	if InCombatLockdown() then ns.Print(L("No se puede cambiar el atajo en combate.")); return end
	for _, old in ipairs({ GetBindingKey(ns.BINDINGS[i]) }) do SetBinding(old) end
	SaveBindings(GetCurrentBindingSet())
	ns.RefreshWatchedKeys()
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
events:RegisterEvent("UPDATE_BINDINGS")
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "UPDATE_BINDINGS" then
		if ns.RefreshWatchedKeys then ns.RefreshWatchedKeys() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- los atributos seguros no se pueden cambiar en combate: al salir, se termina la preparación pendiente
		-- y se limpia cualquier acción que quedara armada
		SetupInputs()
		for i = 1, ns.MAX_PROFILES do ns.SetSecureAction(i, nil) end
	elseif event == "ADDON_LOADED" and arg1 == addonName then
		RadialHubDB = RadialHubDB or {}
		ns.db = RadialHubDB
		ns.SetLanguage(ns.db.lang)
		Fill(ns.db)
	elseif event == "PLAYER_LOGIN" then
		ns.RefreshWatchedKeys()
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
			ns.Print(L("listo: mantén %s para abrir la rueda. /rh para configurarla.", DEFAULT_KEY))
		elseif not GetBindingKey(ns.BINDINGS[1]) then
			ns.Print(L("escribe /rh para asignar la tecla de la rueda."))
		end
	end
end)

-- SecureActionButtonTemplate must not have addon OnClick scripts: they taint Blizzard's action-button cooldown path.
local MOUSE_BUTTONS = { BUTTON1 = "LeftButton", BUTTON2 = "RightButton", BUTTON3 = "MiddleButton", BUTTON4 = "Button4", BUTTON5 = "Button5" }
-- Rendimiento: las teclas asignadas se analizan una vez (al entrar y en UPDATE_BINDINGS) y el sondeo por fotograma
-- no crea tablas ni cadenas; sin ninguna tecla asignada, el marco se oculta y no corre nada.
local heldProfiles, downNow, watched, inputMonitor = {}, {}, {}, CreateFrame("Frame")
inputMonitor:Hide()

function ns.RefreshWatchedKeys()
	wipe(watched)
	for i = 1, ns.MAX_PROFILES do
		for _, key in ipairs({ GetBindingKey(ns.BINDINGS[i]) }) do
			local base = key:match("[^-]+$")
			if base then
				watched[#watched + 1] = {
					profile = i, base = base, mouse = MOUSE_BUTTONS[base],
					alt = key:find("ALT-", 1, true) ~= nil,
					ctrl = key:find("CTRL-", 1, true) ~= nil,
					shift = key:find("SHIFT-", 1, true) ~= nil,
				}
			end
		end
	end
	if #watched > 0 or next(heldProfiles) then inputMonitor:Show() else inputMonitor:Hide() end
end

inputMonitor:SetScript("OnUpdate", function()
	local alt, ctrl, shift = IsAltKeyDown() and true or false, IsControlKeyDown() and true or false, IsShiftKeyDown() and true or false
	for i = 1, ns.MAX_PROFILES do downNow[i] = false end
	for _, w in ipairs(watched) do
		if not downNow[w.profile] and w.alt == alt and w.ctrl == ctrl and w.shift == shift then
			if w.mouse then downNow[w.profile] = IsMouseButtonDown(w.mouse) and true or false
			else downNow[w.profile] = IsKeyDown(w.base) and true or false end
		end
	end
	for i = 1, ns.MAX_PROFILES do
		local down = downNow[i]
		if down and not heldProfiles[i] then
			heldProfiles[i] = true
			ns.Wheel.Open(i)
		elseif not down and heldProfiles[i] then
			heldProfiles[i] = nil
			if ns.ArmedAction(i) then -- el clic seguro ya la abrió al soltar la tecla
				ns.SetSecureAction(i, nil)
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
		ns.Print(ns.debug and L("depuración activada") or L("depuración desactivada"))
	else ns.Config.Toggle() end
end
