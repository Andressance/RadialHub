-- QuickWheel · Core: base de datos, catálogo de acciones, atajo y comandos.
-- WoW 3.3.5a (Lua 5.1). Todo vive en el namespace privado `ns`; los únicos globales son los que
-- el cliente exige: QuickWheelDB (SavedVariables), QuickWheel_OnKey (Bindings.xml), los textos de
-- BINDING_*, SLASH_*, y los marcos con nombre QuickWheelFrame / QuickWheelConfig (para cerrar con Escape).
local addonName, ns = ...

BINDING_HEADER_QUICKWHEEL = "QuickWheel"
BINDING_NAME_QUICKWHEEL_TOGGLE = "Abrir rueda (mantener pulsada)"

local BINDING = "QUICKWHEEL_TOGGLE"
local DEFAULT_KEY = "ALT-Q" -- libre en la interfaz por defecto; solo se asigna una vez y si está libre

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100QuickWheel|r: " .. msg)
end

----------------------------------------------------------------------------------------------------
-- Catálogo de acciones. Para añadir un panel basta con una entrada más (id único, nombre, icono, run).
-- default = activo en una instalación nueva.
----------------------------------------------------------------------------------------------------
local ICON = "Interface\\Icons\\"

ns.Catalog = {
	{ id = "character",    name = "Personaje",             icon = ICON .. "INV_Shirt_White_01",       default = true,
		run = function() ToggleCharacter("PaperDollFrame") end },
	{ id = "talents",      name = "Talentos",              icon = ICON .. "Spell_Holy_ArcaneIntellect", default = true,
		run = function() ToggleTalentFrame() end },
	{ id = "spellbook",    name = "Libro de hechizos",     icon = ICON .. "INV_Misc_Book_09",         default = true,
		run = function() ToggleSpellBook(BOOKTYPE_SPELL) end },
	{ id = "quests",       name = "Misiones",              icon = ICON .. "INV_Misc_Note_01",         default = true,
		run = function() ToggleQuestLog() end },
	{ id = "map",          name = "Mapa del mundo",        icon = ICON .. "INV_Misc_Map_01",          default = true,
		run = function() ToggleWorldMap() end },
	{ id = "guild",        name = "Hermandad",             icon = ICON .. "INV_Shirt_GuildTabard_01", default = true,
		run = function() ToggleFriendsFrame(3) end },
	{ id = "bags",         name = "Bolsas",                icon = ICON .. "INV_Misc_Bag_08",          default = true,
		run = function() if IsBagOpen(0) then CloseAllBags() else OpenAllBags() end end },
	{ id = "achievements", name = "Logros",                icon = ICON .. "Achievement_General",      default = true,
		run = function() ToggleAchievementFrame() end },
	{ id = "lfd",          name = "Buscador de mazmorras", icon = ICON .. "INV_Misc_GroupLooking",    default = false,
		run = function() ToggleLFDParentFrame() end },
	{ id = "pets",         name = "Mascotas y monturas",   icon = ICON .. "Ability_Mount_RidingHorse", default = false,
		run = function() ToggleCharacter("PetPaperDollFrame") end },
}

ns.CatalogByID = {}
for _, entry in ipairs(ns.Catalog) do ns.CatalogByID[entry.id] = entry end

-- Colores de acento predefinidos (los usa Config.lua y el valor por defecto).
ns.Presets = {
	{ name = "Dorado",       1.00, 0.82, 0.20 },
	{ name = "Azul Arcano",  0.30, 0.60, 1.00 },
	{ name = "Esmeralda",    0.20, 0.85, 0.50 },
	{ name = "Blanco",       1.00, 1.00, 1.00 },
}

----------------------------------------------------------------------------------------------------
-- QuickWheelDB
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

-- Rellena huecos y sincroniza order/enabled con el catálogo (ids nuevos al final, ids borrados fuera).
local function Fill(db)
	for k, v in pairs(defaults) do
		if db[k] == nil then db[k] = type(v) == "table" and { unpack(v) } or v end
	end
	db.enabled = db.enabled or {}
	local seen, order = {}, {}
	for _, id in ipairs(db.order or {}) do
		if ns.CatalogByID[id] and not seen[id] then seen[id] = true; order[#order + 1] = id end
	end
	for _, entry in ipairs(ns.Catalog) do
		if not seen[entry.id] then order[#order + 1] = entry.id end
		if db.enabled[entry.id] == nil then db.enabled[entry.id] = entry.default end
	end
	db.order = order
end

function ns.ResetDB()
	local keyInit = ns.db.keyInit -- el atajo por defecto solo se intenta una vez en la vida de la instalación
	wipe(ns.db)
	ns.db.keyInit = keyInit
	Fill(ns.db)
end

-- Entradas del catálogo activas, en el orden elegido por el jugador.
function ns.GetActive()
	local list = {}
	for _, id in ipairs(ns.db.order) do
		if ns.db.enabled[id] then list[#list + 1] = ns.CatalogByID[id] end
	end
	return list
end

function ns.Run(entry)
	local ok, err = pcall(entry.run)
	if not ok then ns.Print("No se pudo abrir " .. entry.name .. ": " .. tostring(err)) end
end

----------------------------------------------------------------------------------------------------
-- Atajo de teclado (SetBinding + SaveBindings; el cliente lo bloquea en combate)
----------------------------------------------------------------------------------------------------
function ns.BindKey(key)
	if InCombatLockdown() then ns.Print("No se puede cambiar el atajo en combate."); return false end
	local prev = GetBindingAction(key)
	for _, old in ipairs({ GetBindingKey(BINDING) }) do SetBinding(old) end
	if not SetBinding(key, BINDING) then return false end
	SaveBindings(GetCurrentBindingSet())
	if prev and prev ~= "" and prev ~= BINDING then
		ns.Print(GetBindingText(key, "KEY_") .. " estaba asignada a " .. (_G["BINDING_NAME_" .. prev] or prev) .. "; ahora abre la rueda.")
	end
	return true
end

function ns.ClearKey()
	if InCombatLockdown() then ns.Print("No se puede cambiar el atajo en combate."); return end
	for _, old in ipairs({ GetBindingKey(BINDING) }) do SetBinding(old) end
	SaveBindings(GetCurrentBindingSet())
end

-- Lo llama Bindings.xml: "down" abre la rueda, "up" ejecuta la opción apuntada.
function QuickWheel_OnKey(keystate)
	if keystate == "down" then ns.Wheel.Open() else ns.Wheel.Release() end
end

----------------------------------------------------------------------------------------------------
-- Eventos y comandos
----------------------------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		QuickWheelDB = QuickWheelDB or {}
		ns.db = QuickWheelDB
		Fill(ns.db)
	elseif event == "PLAYER_LOGIN" and not ns.db.keyInit then
		ns.db.keyInit = true
		local action = GetBindingAction(DEFAULT_KEY)
		if not GetBindingKey(BINDING) and (not action or action == "") and ns.BindKey(DEFAULT_KEY) then
			ns.Print("listo: mantén " .. DEFAULT_KEY .. " para abrir la rueda. /qw para configurarla.")
		elseif not GetBindingKey(BINDING) then
			ns.Print("escribe /qw para asignar la tecla de la rueda.")
		end
	end
end)

SLASH_QUICKWHEEL1 = "/qw"
SLASH_QUICKWHEEL2 = "/quickwheel"
SlashCmdList["QUICKWHEEL"] = function() ns.Config.Toggle() end
