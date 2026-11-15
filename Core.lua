-- QuickWheel · Core: base de datos, catálogo de acciones, atajo y comandos.
-- Cliente WoW Forever (Interface 16001, motor moderno). Todo vive en el namespace privado `ns`; los únicos
-- globales son los que el cliente exige: QuickWheelDB (SavedVariables), QuickWheel_OnKey (Bindings.xml),
-- los textos de BINDING_*, SLASH_*, y los marcos con nombre QuickWheelFrame / QuickWheelConfig (para Escape).
local addonName, ns = ...

BINDING_HEADER_QUICKWHEEL = "QuickWheel"
BINDING_NAME_QUICKWHEEL_TOGGLE = "Abrir rueda (mantener pulsada)"

local BINDING = "QUICKWHEEL_TOGGLE"
local DEFAULT_KEY = "ALT-Q" -- solo se asigna una vez y si está libre

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100QuickWheel|r: " .. msg)
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
		if not tex.qwMask then
			local mask = tex:GetParent():CreateMaskTexture()
			mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetAllPoints(tex)
			tex:AddMaskTexture(mask)
			tex.qwMask = mask
		end
	else
		SetPortraitToTexture(tex, path) -- clientes sin máscaras
	end
end

----------------------------------------------------------------------------------------------------
-- Catálogo de acciones. Para añadir un panel basta con una entrada más.
-- Cada acción usa el atajo nativo del propio juego (RunBinding), así abre el panel correcto de ESTE cliente:
--   bind = nombres de binding por orden; vale el primero que existe (se comprueba con BINDING_NAME_<bind>).
--   fn   = alternativas si no hay binding: { "Funcion" o "Tabla.Funcion", arg1, arg2... }.
-- /qw check muestra qué ruta usa cada entrada en tu cliente.
----------------------------------------------------------------------------------------------------
local ICON = "Interface\\Icons\\"

ns.Catalog = {
	{ id = "character",    name = "Personaje",             icon = ICON .. "INV_Shirt_White_01",        default = true,
		bind = { "TOGGLECHARACTER0" },
		fn = { { "ToggleCharacter", "PaperDollFrame" } } },
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
	{ id = "bags",         name = "Bolsas",                icon = ICON .. "INV_Misc_Bag_08",           default = true,
		bind = { "OPENALLBAGS" },
		fn = { { "ToggleAllBags" } } },
	{ id = "achievements", name = "Logros",                icon = ICON .. "Achievement_General",       default = true,
		bind = { "TOGGLEACHIEVEMENT" },
		fn = { { "ToggleAchievementFrame" } } },
	{ id = "lfd",          name = "Buscador de mazmorras", icon = ICON .. "INV_Misc_GroupLooking",     default = false,
		bind = { "TOGGLEGROUPFINDER", "TOGGLELFGPARENT" },
		fn = { { "PVEFrame_ToggleFrame" }, { "ToggleLFDParentFrame" } } },
	{ id = "pets",         name = "Mascotas y monturas",   icon = ICON .. "Ability_Mount_RidingHorse", default = false,
		bind = { "TOGGLEMOUNTJOURNAL", "TOGGLECOLLECTIONS", "TOGGLEPETBOOK" },
		fn = { { "ToggleCollectionsJournal" }, { "ToggleCharacter", "PetPaperDollFrame" } } },
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

-- Ruta que usará la entrada en este cliente: "binding", nombre  |  "fn", nombre, función, args  |  nil.
local function Resolve(entry)
	for _, b in ipairs(entry.bind) do
		if _G["BINDING_NAME_" .. b] then return "binding", b end
	end
	for _, spec in ipairs(entry.fn) do
		local f = _G
		for part in spec[1]:gmatch("[^.]+") do f = type(f) == "table" and f[part] or nil end
		if type(f) == "function" then return "fn", spec[1], f, spec end
	end
end

function ns.Run(entry)
	local kind, what, f, spec = Resolve(entry)
	if not kind then
		ns.Print(entry.name .. " no está disponible en este cliente (/qw check para ver el detalle).")
		return
	end
	local ok, err
	if kind == "binding" then ok, err = pcall(RunBinding, what) else ok, err = pcall(f, unpack(spec, 2)) end
	if not ok then ns.Print("No se pudo abrir " .. entry.name .. ": " .. tostring(err)) end
end

function ns.Check()
	for _, entry in ipairs(ns.Catalog) do
		local kind, what = Resolve(entry)
		ns.Print(entry.name .. ": " .. (kind and (kind .. " " .. what) or "|cffff4040NO DISPONIBLE|r"))
	end
end

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
SlashCmdList["QUICKWHEEL"] = function(msg)
	if strlower(strtrim(msg or "")) == "check" then ns.Check() else ns.Config.Toggle() end
end
