-- Run from the repo root: lua tests/test.lua
-- Mocks just enough of the WoW API to load Core/Wheel/Config and drive them. It checks the logic
-- (polar math, profiles/DB, custom entries, open -> point -> release, config window builds), not how
-- the real client renders it.
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end -- Lua 5.1 (WoW) has atan2; 5.4 does not
unpack = unpack or table.unpack
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strlower = string.lower
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
RunBinding = function(name) calls[#calls + 1] = "binding:" .. name end
securecallfunction = function(fn, ...) return fn(...) end
RunScript = function(code) calls[#calls + 1] = "script:" .. code end
ChatEdit_SendText = function(box) calls[#calls + 1] = "chat:" .. box:GetText() end
for _, b in ipairs({ "TOGGLECHARACTER0", "TOGGLETALENTS", "TOGGLESPELLBOOK", "TOGGLEQUESTLOG", "TOGGLEWORLDMAP",
	"TOGGLEGUILDTAB", "OPENALLBAGS", "TOGGLEACHIEVEMENT", "TOGGLESOCIAL" }) do
	_G["BINDING_NAME_" .. b] = b
end

-- WoW Forever: Logros y Buscador de mazmorras no existen y se ocultan
WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 14, 14
DoEmote = function(token) calls[#calls + 1] = "emote:" .. token end

local ns = {}
for _, file in ipairs({ "Core.lua", "Wheel.lua", "Config.lua" }) do assert(loadfile(file))("RadialHub", ns) end

local function check(cond, msg) if not cond then error("FAIL: " .. msg, 2) end end
local function load(db)
	RadialHubDB = db
	local events -- Core's event frame: the first one with an OnEvent (the secure inputs come before it)
	for _, f in ipairs(frames) do if f.scripts.OnEvent then events = f; break end end
	events.scripts.OnEvent(events, "ADDON_LOADED", "RadialHub")
	return RadialHubDB
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

-- 2. fresh install
local db = load(nil)
check(#db.profiles[1].items == 9 and db.selected == 1, "profile 1 has the 9 built-ins")
CharacterMicroButton = newFrame("CharacterMicroButton")
ns.SetSecureCharacterAction(1, true)
check(RadialHubSecureInput1:GetAttribute("type1") == "click" and RadialHubSecureInput1:GetAttribute("clickbutton1") == CharacterMicroButton,
	"character uses a secure click target")
ns.SetSecureCharacterAction(1, false)
check(RadialHubSecureInput1:GetAttribute("type1") == nil, "secure character click is cleared")
-- leaving combat clears an action that was left armed (it cannot be cleared during combat)
ns.SetSecureCharacterAction(1, true)
local evFrame
for _, f in ipairs(frames) do if f.scripts.OnEvent then evFrame = f; break end end
evFrame.scripts.OnEvent(evFrame, "PLAYER_REGEN_ENABLED")
check(RadialHubSecureInput1:GetAttribute("type1") == nil, "armed character click cleared after combat")
ns.BindKey("ALT-X", 1)
check(bindingClick[1] == "ALT-X" and bindingClick[2] == "RadialHubSecureInput1", "wheel key is bound to its secure input button")
local active = ns.GetActive(1)
check(#active == 8 and active[1].id == "character" and active[8].id == "bags", "8 default entries in catalog order")
check(ns.GetActive(2) == nil, "profile 2 does not exist yet")

-- 3. migration from the single-wheel save (order/enabled), dropping a deleted id and appending new ones
db = load({ order = { "bags", "ghost", "map" }, enabled = { bags = true, map = false }, radius = 150 })
local items = db.profiles[1].items
check(db.radius == 150 and db.iconSize == 52 and not db.order and not db.enabled, "migrated, kept saved value, filled the rest")
check(items[1].id == "bags" and items[1].on and items[2].id == "map" and not items[2].on and #items == 9, "order kept, ghost dropped, missing appended")
check(items[3].on == true and items[#items].on == false, "new built-ins use their defaults")

-- 4. open -> point right -> release runs the 3rd active entry (spellbook)
db = load(nil)
cursor[1], cursor[2] = 500, 400
ns.Wheel.Open(1)
local wheel
for _, f in ipairs(frames) do if f.scripts.OnUpdate and f.scripts.OnHide then wheel = f end end
check(wheel, "wheel frame found")
cursor[1], cursor[2] = 600, 400 -- 100px to the right of the open position
wheel.scripts.OnUpdate(wheel, 0.016)
ns.Wheel.Release()
check(calls[#calls] == "binding:TOGGLESPELLBOOK", "released on slot 3 -> spellbook binding, got " .. tostring(calls[#calls]))

-- 5. release in the deadzone and Escape cancel do nothing
local n = #calls
cursor[1], cursor[2] = 500, 400
ns.Wheel.Open(1)
wheel.scripts.OnUpdate(wheel, 0.016); ns.Wheel.Release()
ns.Wheel.Open(1); wheel:Hide(); ns.Wheel.Release() -- Escape hides the frame, the later key-up must be ignored
check(#calls == n, "cancel paths run nothing")

-- 5b. left click confirms the pointed option
n = #calls
cursor[1], cursor[2] = 500, 400
ns.Wheel.Open(1); cursor[1], cursor[2] = 600, 400
wheel.scripts.OnUpdate(wheel, 0.016)
mouseDown.LeftButton = true
wheel.scripts.OnUpdate(wheel, 0.016)
mouseDown.LeftButton = nil
check(#calls == n + 1 and calls[#calls] == "binding:TOGGLESPELLBOOK", "left click runs the pointed option")

-- 5c. key-up failsafe: key seen held, then gone -> releases without the "up" event
n = #calls
cursor[1], cursor[2] = 500, 400
ns.Wheel.Open(1); cursor[1], cursor[2] = 600, 400
keyDown.Q = true
wheel.scripts.OnUpdate(wheel, 0.016)
keyDown.Q = nil
wheel.scripts.OnUpdate(wheel, 0.016)
check(#calls == n + 1 and not wheel:IsShown(), "released by polling the key")
ns.Wheel.Open(1); wheel.scripts.OnUpdate(wheel, 0.016) -- never seen held (IsKeyDown unreliable) -> stays open
check(wheel:IsShown(), "unarmed failsafe keeps the wheel open")
ns.Wheel.Cancel()

-- 6. profiles: copy, independent edits, missing wheel, delete
ns.NewProfile(2, db.profiles[1])
check(db.profiles[2].name == "Rueda 2" and #db.profiles[2].items == 9, "profile 2 is a copy")
db.profiles[2].items[1].on = false
check(#ns.GetActive(2) == 7 and #ns.GetActive(1) == 8, "profiles are independent")
ns.Wheel.Open(3)
check(printed[#printed]:find("rueda 3 no existe"), "opening a missing wheel says so")
db.selected = 2
ns.DeleteProfile(1)
check(db.profiles[1], "wheel 1 cannot be deleted")
ns.DeleteProfile(2)
check(db.profiles[2] == nil and db.selected == 1, "wheel 2 deleted, selection back to 1")

-- 6b. switching wheels while open: mouse wheel / arrows
ns.NewProfile(2, db.profiles[1])
db.profiles[2].items[1].on = false -- wheel 2: talents, spellbook, quests... (7 options)
cursor[1], cursor[2] = 500, 400
ns.Wheel.Open(1)
ns.Wheel.Switch(1)
cursor[1], cursor[2] = 600, 400
wheel.scripts.OnUpdate(wheel, 0.016)
ns.Wheel.Release()
check(calls[#calls] == "binding:TOGGLEQUESTLOG", "after switching to wheel 2, slot 3 is quests, got " .. tostring(calls[#calls]))
-- clicking the right arrow (outside the ring) switches too, and does not run anything
n = #calls
cursor[1], cursor[2] = 500, 400
ns.Wheel.Open(1)
cursor[1], cursor[2] = 500 + 174, 400
wheel.scripts.OnUpdate(wheel, 0.016)
mouseDown.LeftButton = true
wheel.scripts.OnUpdate(wheel, 0.016)
mouseDown.LeftButton = nil
check(#calls == n and wheel:IsShown(), "arrow click switches without running or closing")
cursor[1], cursor[2] = 600, 400
wheel.scripts.OnUpdate(wheel, 0.016)
ns.Wheel.Release()
check(calls[#calls] == "binding:TOGGLEQUESTLOG", "arrow click moved to wheel 2")
-- with a single wheel there is nothing to switch to
ns.DeleteProfile(2)
ns.Wheel.Open(1); ns.Wheel.Switch(1)
cursor[1], cursor[2] = 500, 400
wheel.scripts.OnUpdate(wheel, 0.016)
ns.Wheel.Cancel()

-- 6c. entries with no way to open them in this client are hidden from the wheel
BINDING_NAME_TOGGLESOCIAL = nil
check(not ns.Available(ns.CatalogByID.friends) and ns.Available(ns.CatalogByID.map), "availability follows the routes")
check(#ns.GetActive(1) == 7, "friends hidden while it has no route, got " .. #ns.GetActive(1))
BINDING_NAME_TOGGLESOCIAL = "TOGGLESOCIAL"
check(#ns.GetActive(1) == 8, "friends back once it has a route")

-- 7. custom entries: shared pool, on only in the chosen wheel, run through chat / RunScript
ns.NewProfile(2, db.profiles[1])
local id = ns.AddCustom({ name = "Bailar", icon = "INV_Misc_Note_01", command = "/dance" }, 2)
check(#db.profiles[1].items == 10 and not db.profiles[1].items[10].on and db.profiles[2].items[10].on, "custom listed everywhere, on only in wheel 2")
check(ns.GetActive(2)[#ns.GetActive(2)].id == id and #ns.GetActive(1) == 8, "custom shows in wheel 2 only")
ns.Run(db.custom[id])
check(calls[#calls] == "chat:/dance", "emote goes through the chat edit box")
local id2 = ns.AddCustom({ name = "Script", command = "/run Foo()" }, 1)
ns.Run(db.custom[id2])
check(calls[#calls] == "script:Foo()", "/run goes through RunScript")
ns.Run({ name = "Vacia", custom = true, command = "  " })
check(printed[#printed]:find("no tiene comando"), "empty command reported")
check(ns.IconPath(nil):find("QuestionMark") and ns.IconPath("Spell_Nature_Heal") == "Interface\\Icons\\Spell_Nature_Heal"
	and ns.IconPath("12345") == 12345 and ns.IconPath("Interface\\Icons\\X") == "Interface\\Icons\\X", "icon paths")
ns.DeleteCustom(id)
check(not db.custom[id] and #db.profiles[1].items == 10 and #db.profiles[2].items == 10, "custom removed from every wheel")

-- 7a. emotes use DoEmote; categories
local em = ns.AddCustom({ name = "Bailar", cat = "emote", emote = "DANCE", command = "" }, 1)
ns.Run(db.custom[em])
check(calls[#calls] == "emote:DANCE", "emote entry uses DoEmote")
check(ns.CatOf(db.custom[em]) == "emote" and ns.CatOf(db.custom[id2]) == "command" and ns.CatOf(ns.CatalogByID.map) == "menu", "categories")
ns.DeleteCustom(em)

-- 7b. slot cap
for i = 1, 20 do ns.AddCustom({ name = "x" .. i, command = "/x" }, 1) end
for _, it in ipairs(db.profiles[1].items) do it.on = true end
check(#ns.GetActive(1) == ns.MAX_SLOTS, "a wheel never exceeds MAX_SLOTS")

-- 8. reset: appearance + selected wheel's options back to defaults; wheels and customs stay
db.radius = 999; db.profiles[1].items[1].on = false; db.keyInit = true
db.selected = 1
ns.ResetDB()
check(db.radius == 110 and db.profiles[1].items[1].on and db.keyInit, "reset restores defaults, keeps keyInit")
check(db.profiles[2] and db.custom[id2] and #db.profiles[1].items == 9 + 21, "reset keeps wheels and custom entries")

-- 9. a failing action is reported, not thrown; no route says so; fallbacks
Boom = function() error("boom") end
ns.Run({ name = "X", bind = {}, fn = { { "Boom" } } })
check(printed[#printed]:find("No se pudo abrir X"), "action error printed")
check(#ns.CatalogByID.character.fn == 0 and #ns.CatalogByID.character.bind == 0,
	"character panel has no insecure ToggleCharacter fallback")
ns.Run({ name = "Y", bind = {}, fn = { { "Nope" } } })
check(printed[#printed]:find("no est"), "unavailable reported")
BINDING_NAME_TOGGLEQUESTLOG = nil
ToggleQuestLog = function() calls[#calls + 1] = "fn:ToggleQuestLog" end
ns.Run(ns.CatalogByID.quests)
check(calls[#calls] == "fn:ToggleQuestLog", "fallback to function when the binding is missing")
PlayerSpellsUtil = { ToggleClassTalentOrSpecFrame = function() calls[#calls + 1] = "fn:talents" end }
BINDING_NAME_TOGGLETALENTS = nil
ns.Run(ns.CatalogByID.talents)
check(calls[#calls] == "fn:talents", "dotted function path resolved")
ns.Check()

-- 10. the config window builds and refreshes against the mock without errors
ns.Config.Toggle()
check(RadialHubConfig, "config frame created")
for _, m in ipairs(printed) do check(not m:find("error al crear"), "config build error: " .. m) end
RadialHubConfig.scripts.OnShow(RadialHubConfig)

print("ok")
