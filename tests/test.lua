-- Run from the repo root: lua tests/test.lua
-- Mocks just enough of the WoW API to load Core/Wheel/Config and drive them. It checks the logic
-- (polar math, profiles/DB, custom entries, open -> point -> release, config window builds), not how
-- the real client renders it.
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end -- Lua 5.1 (WoW) has atan2; 5.4 does not
unpack = unpack or table.unpack
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strlower, strupper = string.lower, string.upper
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function noop() end
local function newFrame(name)
	local f = { scripts = {}, shown = true, name = name, text = "" }
	function f:SetScript(n, fn) self.scripts[n] = fn end
	function f:Show() self.shown = true end
	function f:Hide()
		if self.shown and self.scripts.OnHide then self.scripts.OnHide(self) end
		self.shown = false
	end
	function f:IsShown() return self.shown end
	function f:IsEnabled() return true end
	function f:GetEffectiveScale() return 1 end
	function f:GetHeight() return 600 end
	function f:GetWidth() return 780 end
	function f:HasFocus() return false end
	function f:GetChecked() return false end
	function f:SetText(t) self.text = t end
	function f:GetText() return self.text end
	function f:SetAttribute(k, v) -- rawget: a missing field would hit the no-op __index below
		local a = rawget(self, "attributes")
		if not a then a = {}; self.attributes = a end
		a[k] = v
	end
	function f:GetAttribute(k) local a = rawget(self, "attributes"); return a and a[k] end
	if name then _G[name] = f end
	return setmetatable(f, { __index = function() return function(self) return self end end }) -- any other method: no-op
end
local frames = {}
function CreateFrame(_, name) local f = newFrame(name); frames[#frames + 1] = f; return f end
UIParent = newFrame()
UISpecialFrames = {}
SlashCmdList = {}
printed = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed + 1] = m end, editBox = newFrame() }
SetPortraitToTexture, PlaySound, InterfaceOptions_AddCategory = noop, noop, noop
GetAddOnMetadata = function() return "test" end
local mouseDown, keyDown = {}, {}
IsMouseButtonDown = function(b) return mouseDown[b] or false end
IsKeyDown = function(k) return keyDown[k] or false end
GetBindingKey = function() return "ALT-Q" end
GetBindingAction = function() return "" end
InCombatLockdown = function() return false end
SetBinding, SaveBindings, GetCurrentBindingSet = function() return true end, noop, function() return 1 end
local bindingClick
SetBindingClick = function(key, name, button) bindingClick = { key, name, button }; return true end
RegisterStateDriver = noop
local cursor = { 500, 400 }
GetCursorPosition = function() return cursor[1], cursor[2] end

local calls = {}
RunScript = function(code) calls[#calls + 1] = "script:" .. code end
DoEmote = function(token) calls[#calls + 1] = "emote:" .. token end
-- slash commands: one from an addon, one from Blizzard (secure variable) and a protected one
SlashCmdList.DBM = function(msg) calls[#calls + 1] = "dbm:" .. msg end
SLASH_DBM1 = "/dbm"
SlashCmdList.MACRO = function() calls[#calls + 1] = "macro" end
SLASH_MACRO1 = "/macro"
issecurevariable = function(_, key) return key == "MACRO" end
hash_SecureCmdList = { ["/CAST"] = noop }
hash_EmoteTokenList = { ["/DANCE"] = "DANCE" }

-- Blizzard buttons the panels click; the map one is missing in this "client" to test hiding
local BUTTONS = { "CharacterMicroButton", "TalentMicroButton", "SpellbookMicroButton", "QuestLogMicroButton",
	"GuildMicroButton", "SocialsMicroButton", "MainMenuBarBackpackButton", "CollectionsMicroButton" }
for _, name in ipairs(BUTTONS) do newFrame(name) end

-- WoW Forever: Logros y Buscador de mazmorras no existen y se ocultan
WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 14, 14

local ns = {}
GetLocale = function() return "esES" end
for _, file in ipairs({ "Locales.lua", "Core.lua", "Wheel.lua", "Config.lua" }) do assert(loadfile(file))("RadialHub", ns) end

local function check(cond, msg) if not cond then error("FAIL: " .. msg, 2) end end
local function eventFrame() -- Core's event frame: the first one with an OnEvent (the secure inputs come before it)
	for _, f in ipairs(frames) do if f.scripts.OnEvent then return f end end
end
local function load(db)
	RadialHubDB = db
	local events = eventFrame()
	events.scripts.OnEvent(events, "ADDON_LOADED", "RadialHub")
	return RadialHubDB
end
local input = RadialHubSecureInput1
local function armed() return input:GetAttribute("type1") == "click" and input:GetAttribute("clickbutton1") end

-- 0. static taint audit: the code must not use any API that has tainted Blizzard's UI before
local FORBIDDEN = { "UISpecialFrames", "HideUIPanel", "ShowUIPanel", "RunBinding", "ChatEdit_", "hooksecurefunc",
	"HookScript", "RegisterStateDriver", "SecureHandler", "securecall", "RunMacro", "CastSpell", "UseAction", "SetCVar",
	"Toggle%u%a*%(" }
for _, file in ipairs({ "Core.lua", "Wheel.lua", "Config.lua" }) do
	local n = 0
	for line in io.lines(file) do
		n = n + 1
		local code = line:gsub("%-%-.*$", "") -- comments may name them
		for _, bad in ipairs(FORBIDDEN) do
			check(not code:find(bad), file .. ":" .. n .. " uses " .. bad .. " (taints Blizzard's UI)")
		end
	end
end

-- 1. polar math: 8 slots, #1 on top, clockwise
local at = ns.Wheel.SliceAt
check(at(0, 100, 8, 30) == 1, "up -> 1")
check(at(100, 0, 8, 30) == 3, "right -> 3")
check(at(0, -100, 8, 30) == 5, "down -> 5")
check(at(-100, 0, 8, 30) == 7, "left -> 7")
check(at(70, 70, 8, 30) == 2, "up-right diagonal -> 2")
check(at(-1, 100, 8, 30) == 1, "just left of up still -> 1 (wraps)")
check(at(10, 10, 8, 30) == nil, "inside deadzone -> nil")
check(at(0, 100, 1, 30) == 1 and at(0, -100, 1, 30) == 1, "single slot")
check(at(0, 100, 0, 30) == nil, "no slots")

check(ns.IsForever and not ns.CatalogByID.achievements and not ns.CatalogByID.lfd and #ns.Catalog == 9, "Forever hides noForever entries")

-- 2. fresh install; panels are available only when their Blizzard button exists
local db = load(nil)
check(#db.profiles[1].items == 9 and db.selected == 1, "profile 1 has the 9 built-ins")
check(not ns.Available(ns.CatalogByID.map) and ns.Available(ns.CatalogByID.quests), "map hidden: no button in this client")
local active = ns.GetActive(1)
check(#active == 7 and active[1].id == "character" and active[7].id == "bags", "7 default panels (map hidden), got " .. #active)
check(ns.GetActive(2) == nil, "profile 2 does not exist yet")
ns.SetSecureAction(1, ns.CatalogByID.character)
check(armed() == CharacterMicroButton, "character uses a secure click on its micro button")
ns.SetSecureAction(1, nil)
check(input:GetAttribute("type1") == nil, "secure click cleared")
ns.SetSecureAction(1, ns.CatalogByID.map)
check(input:GetAttribute("type1") == nil, "nothing armed for a panel without a button")
ns.BindKey("ALT-X", 1)
check(bindingClick[1] == "ALT-X" and bindingClick[2] == "RadialHubSecureInput1", "wheel key is bound to its secure input button")

-- 3. migration from the single-wheel save (order/enabled), dropping a deleted id and appending new ones
db = load({ order = { "bags", "ghost", "map" }, enabled = { bags = true, map = false }, radius = 150 })
local items = db.profiles[1].items
check(db.radius == 150 and db.iconSize == 52 and not db.order and not db.enabled, "migrated, kept saved value, filled the rest")
check(items[1].id == "bags" and items[1].on and items[2].id == "map" and not items[2].on and #items == 9, "order kept, ghost dropped, missing appended")

-- 4. a panel is never opened from Lua: pointing arms the secure input, releasing does not call anything
db = load(nil)
check(ns.Run(ns.CatalogByID.quests) == nil and #calls == 0, "Run never opens a panel")
cursor[1], cursor[2] = 500, 400
ns.Wheel.Open(1)
local wheel
for _, f in ipairs(frames) do if f.scripts.OnUpdate and f.scripts.OnHide then wheel = f end end
check(wheel, "wheel frame found")
cursor[1], cursor[2] = 600, 400 -- right: slot 3 of 7 (spellbook)
wheel.scripts.OnUpdate(wheel, 0.016)
check(armed() == SpellbookMicroButton, "pointing at spellbook arms its micro button")
cursor[1], cursor[2] = 500, 400 -- back to the deadzone: disarmed
wheel.scripts.OnUpdate(wheel, 0.016)
check(input:GetAttribute("type1") == nil, "deadzone disarms")
ns.Wheel.Cancel()
check(#calls == 0, "no Lua calls at all")

-- 5. Escape (polled) and a later key-up do nothing
ns.Wheel.Open(1)
keyDown.ESCAPE = true
wheel.scripts.OnUpdate(wheel, 0.016)
keyDown.ESCAPE = nil
check(not wheel:IsShown(), "Escape cancels the wheel")
ns.Wheel.Release()
check(#calls == 0 and #UISpecialFrames == 0, "nothing runs; UISpecialFrames untouched")

-- 5b. a left click on a panel does not open it from Lua (the key release does it securely)
cursor[1], cursor[2] = 500, 400
ns.Wheel.Open(1); cursor[1], cursor[2] = 600, 400
wheel.scripts.OnUpdate(wheel, 0.016)
mouseDown.LeftButton = true
wheel.scripts.OnUpdate(wheel, 0.016)
mouseDown.LeftButton = nil
check(#calls == 0 and wheel:IsShown() and armed() == SpellbookMicroButton, "left click on a panel keeps the wheel armed")
ns.Wheel.Cancel()

-- 6. profiles: copy, independent edits, missing wheel, delete
ns.NewProfile(2, db.profiles[1])
check(db.profiles[2].name == "Rueda 2" and #db.profiles[2].items == 9, "profile 2 is a copy")
db.profiles[2].items[1].on = false
check(#ns.GetActive(2) == 6 and #ns.GetActive(1) == 7, "profiles are independent")
ns.Wheel.Open(3)
check(printed[#printed]:find("rueda 3 no existe"), "opening a missing wheel says so")
db.selected = 2
ns.DeleteProfile(1)
check(db.profiles[1], "wheel 1 cannot be deleted")
ns.DeleteProfile(2)
check(db.profiles[2] == nil and db.selected == 1, "wheel 2 deleted, selection back to 1")

-- 6b. switching wheels while open (arrows / mouse wheel) re-arms for the new wheel
ns.NewProfile(2, db.profiles[1])
db.profiles[2].items[1].on = false -- wheel 2: talents, spellbook, quests... (6 options)
cursor[1], cursor[2] = 500, 400
ns.Wheel.Open(1)
ns.Wheel.Switch(1)
cursor[1], cursor[2] = 600, 330 -- down-right: slot 3 of 6 (quests)
wheel.scripts.OnUpdate(wheel, 0.016)
check(armed() == QuestLogMicroButton, "after switching to wheel 2, down-right is quests")
ns.Wheel.Cancel()
check(input:GetAttribute("type1") == nil, "cancel disarms")
cursor[1], cursor[2] = 500, 400
ns.Wheel.Open(1)
cursor[1], cursor[2] = 500 + 174, 400 -- the right arrow, outside the ring
wheel.scripts.OnUpdate(wheel, 0.016)
mouseDown.LeftButton = true
wheel.scripts.OnUpdate(wheel, 0.016)
mouseDown.LeftButton = nil
check(#calls == 0 and wheel:IsShown(), "arrow click switches without running or closing")
ns.Wheel.Cancel()
ns.DeleteProfile(2)

-- 7. custom entries: addon commands, emotes and /run; Blizzard commands are refused
local function custom(command) return ns.AddCustom({ name = command, command = command }, 1) end
ns.Run(db.custom[custom("/dbm pull 10")])
check(calls[#calls] == "dbm:pull 10", "addon command runs its handler")
ns.Run(db.custom[custom("/run Foo()")])
check(calls[#calls] == "script:Foo()", "/run goes through RunScript")
ns.Run(db.custom[custom("/dance")])
check(calls[#calls] == "emote:DANCE", "emote command uses DoEmote")
local n = #calls
ns.Run(db.custom[custom("/cast Fireball")])
check(#calls == n and printed[#printed]:find("protegido"), "protected command refused")
ns.Run(db.custom[custom("/macro")])
check(#calls == n and printed[#printed]:find("comando de Blizzard"), "Blizzard command refused")
ns.Run(db.custom[custom("/nope")])
check(#calls == n and printed[#printed]:find("no se encuentra"), "unknown command reported")
ns.Run({ name = "Vacia", custom = true, command = "  " })
check(printed[#printed]:find("no tiene comando"), "empty command reported")
local em = ns.AddCustom({ name = "Saludar", cat = "emote", emote = "WAVE", command = "" }, 1)
ns.Run(db.custom[em])
check(calls[#calls] == "emote:WAVE", "emote entry uses DoEmote")
check(ns.CatOf(db.custom[em]) == "emote" and ns.CatOf(ns.CatalogByID.map) == "menu", "categories")
check(ns.IconPath(nil):find("QuestionMark") and ns.IconPath("Spell_Nature_Heal") == "Interface\\Icons\\Spell_Nature_Heal"
	and ns.IconPath("12345") == 12345 and ns.IconPath("Interface\\Icons\\X") == "Interface\\Icons\\X", "icon paths")
local before = #db.profiles[1].items
ns.DeleteCustom(em)
check(not db.custom[em] and #db.profiles[1].items == before - 1, "custom removed from every wheel")

-- 7b. a custom entry runs from the wheel on release or click (it is not a panel)
for _, it in ipairs(db.profiles[1].items) do it.on = false end
local dbmId = custom("/dbm version")
for _, it in ipairs(db.profiles[1].items) do if it.id == dbmId then it.on = true end end
cursor[1], cursor[2] = 500, 400
ns.Wheel.Open(1); cursor[1], cursor[2] = 500, 500
wheel.scripts.OnUpdate(wheel, 0.016)
check(input:GetAttribute("type1") == nil, "custom entries never arm the secure input")
ns.Wheel.Release()
check(calls[#calls] == "dbm:version", "custom entry runs on release")

-- 7c. slot cap
for i = 1, 20 do custom("/dbm x" .. i) end
for _, it in ipairs(db.profiles[1].items) do it.on = true end
check(#ns.GetActive(1) == ns.MAX_SLOTS, "a wheel never exceeds MAX_SLOTS")

-- 8. reset: appearance + selected wheel's options back to defaults; wheels and customs stay
db.radius = 999; db.keyInit = true
ns.ResetDB()
check(db.radius == 110 and db.profiles[1].items[1].on and db.keyInit, "reset restores defaults, keeps keyInit")
check(db.custom[dbmId], "reset keeps custom entries")

-- 9. combat: nothing protected is touched; panels say so instead of opening; config refuses to open
InCombatLockdown = function() return true end
ns.SetSecureAction(1, ns.CatalogByID.character)
check(input:GetAttribute("type1") == nil, "no secure attribute changes in combat")
cursor[1], cursor[2] = 500, 400
ns.Wheel.Open(1); cursor[1], cursor[2] = 600, 330
wheel.scripts.OnUpdate(wheel, 0.016)
n = #calls
ns.Wheel.Release()
check(#calls == n and printed[#printed]:find("en combate"), "in combat a panel says so, no Lua")
ns.Config.Toggle()
check(printed[#printed]:find("no se puede abrir en combate") and not RadialHubConfig, "config refuses to open in combat")
check(not ns.BindKey("ALT-Z", 1), "no key changes in combat")
InCombatLockdown = function() return false end
-- leaving combat clears anything left armed
ns.SetSecureAction(1, ns.CatalogByID.character)
eventFrame().scripts.OnEvent(eventFrame(), "PLAYER_REGEN_ENABLED")
check(input:GetAttribute("type1") == nil, "armed click cleared after combat")

-- 10. the config window builds, refreshes, and closes itself when combat starts
ns.Config.Toggle()
check(RadialHubConfig, "config frame created")
for _, m in ipairs(printed) do check(not m:find("error al crear"), "config build error: " .. m) end
RadialHubConfig.scripts.OnShow(RadialHubConfig)
RadialHubConfig.scripts.OnEvent(RadialHubConfig, "PLAYER_REGEN_DISABLED")
check(not RadialHubConfig:IsShown(), "config closes when combat starts")
ns.Check()

-- 11. key polling: opens on the bound key, releases on let go, and allocates nothing per frame when idle
local altDown = false
IsAltKeyDown = function() return altDown end
IsControlKeyDown = function() return false end
IsShiftKeyDown = function() return false end
ns.RefreshWatchedKeys() -- every wheel is bound to ALT-Q in this mock
local monitor
for _, f in ipairs(frames) do if f.scripts.OnUpdate and f ~= wheel then monitor = f end end
check(monitor, "key monitor frame found")
ns.ResetDB()
cursor[1], cursor[2] = 500, 400
altDown, keyDown.Q = true, true
monitor.scripts.OnUpdate(monitor, 0.016)
check(wheel:IsShown(), "holding ALT-Q opens the wheel")
cursor[1], cursor[2] = 550, 300 -- slot 4 of 7: quests
wheel.scripts.OnUpdate(wheel, 0.016)
check(armed() == QuestLogMicroButton, "quests armed")
n = #calls
altDown, keyDown.Q = false, nil
monitor.scripts.OnUpdate(monitor, 0.016) -- the CLICK binding did the secure click on key-up
check(not wheel:IsShown() and input:GetAttribute("type1") == nil and #calls == n, "letting go: closed, disarmed, no Lua")
collectgarbage("collect"); collectgarbage("stop")
local kb = collectgarbage("count")
for _ = 1, 10000 do monitor.scripts.OnUpdate(monitor, 0.016) end
local grown = collectgarbage("count") - kb
collectgarbage("restart")
check(grown < 1, "idle polling allocates nothing (grew " .. grown .. " KB over 10000 frames)")

-- 12. every user-facing literal has an English translation; switching language changes texts live
local NOT_TRANSLATED = { ["RadialHub"] = true, ["X"] = true, ["+ Emote"] = true, ["Emotes"] = true, ["Español"] = true,
	["English"] = true, ["<"] = true, [">"] = true, [""] = true, ["KEY_"] = true }
local keys = {}
for _, file in ipairs({ "Core.lua", "Wheel.lua", "Config.lua" }) do
	local src = io.open(file):read("a")
	for _, pat in ipairs({ '[^%w_]L%("(.-)"', 'Text%([^\n]-, "(.-)"%)', 'Flat%([^\n]-, "(.-)"%)', 'Section%(%w+, "(.-)"',
		'Field%("(.-)"', 'Slider%("%w+",%s*"(.-)"' }) do
		for k in src:gmatch(pat) do keys[k] = file end
	end
end
for _, entry in ipairs(ns.Catalog) do keys[entry.name] = "catalog" end
for _, c in ipairs(ns.Categories) do keys[c.name] = "categories" end
for _, e in ipairs(ns.Emotes) do keys[e[1]] = "emotes" end
local count = 0
for k, where in pairs(keys) do
	k = k:gsub("\\n", "\n"):gsub("\\\\", "\\") -- source escapes -> real text
	if not NOT_TRANSLATED[k] and not k:find("^%%") and not k:find('"') then -- '"': an expression, not a literal
		check(ns.EN[k], "missing English for '" .. k .. "' (" .. where .. ")")
		count = count + 1
	end
end
check(count > 60, "translation scan found too few strings: " .. count)
ns.SetLanguage("en")
check(ns.L("Personaje") == "Character" and ns.L("la rueda %d no existe. Créala en /rh.", 3) == "wheel 3 doesn't exist. Create it in /rh.", "English texts")
check(_G["BINDING_NAME_" .. ns.BINDINGS[1]] == "Open wheel 1 (hold)", "binding names follow the language")
ns.Wheel.Open(9)
check(printed[#printed]:find("wheel 9 doesn't exist"), "prints use the language")
ns.SetLanguage("es")
check(ns.L("Personaje") == "Personaje", "back to Spanish")

-- 13. the map opens through the zone text button of the minimap (a child key, not a global)
MinimapCluster = { ZoneTextButton = newFrame() }
check(ns.Available(ns.CatalogByID.map) and select(2, ns.SecureButton(ns.CatalogByID.map)) == "MinimapCluster.ZoneTextButton", "map via MinimapCluster.ZoneTextButton")
ns.SetSecureAction(1, ns.CatalogByID.map)
check(armed() == MinimapCluster.ZoneTextButton, "map arms the zone text button")
ns.SetSecureAction(1, nil)

print("ok")
