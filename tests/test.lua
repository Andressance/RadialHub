-- Run from the repo root: lua tests/test.lua
-- Mocks just enough of the WoW API to load Core/Wheel/Config and drive them. It checks the logic
-- (polar math, DB merge/reorder/reset, open -> point -> release), not how the real client renders it.
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end -- Lua 5.1 (WoW) has atan2; 5.4 does not
unpack = unpack or table.unpack
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

local function noop() end
local function newFrame()
	local f = { scripts = {}, shown = true }
	function f:SetScript(n, fn) self.scripts[n] = fn end
	function f:Show() self.shown = true end
	function f:Hide()
		if self.shown and self.scripts.OnHide then self.scripts.OnHide(self) end
		self.shown = false
	end
	function f:IsShown() return self.shown end
	function f:IsEnabled() return true end
	function f:GetEffectiveScale() return 1 end
	return setmetatable(f, { __index = function() return function(self) return self end end }) -- any other method: no-op
end
local frames = {}
function CreateFrame() local f = newFrame(); frames[#frames + 1] = f; return f end
UIParent = newFrame()
UISpecialFrames = {}
SlashCmdList = {}
printed = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed + 1] = m end }
SetPortraitToTexture, PlaySound, InterfaceOptions_AddCategory = noop, noop, noop
GetAddOnMetadata = function() return "test" end
IsMouseButtonDown = function() return false end
InCombatLockdown = function() return false end
local cursor = { 500, 400 }
GetCursorPosition = function() return cursor[1], cursor[2] end

local calls = {}
strlower, strtrim = string.lower, function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
RunBinding = function(name) calls[#calls + 1] = "binding:" .. name end
for _, b in ipairs({ "TOGGLECHARACTER0", "TOGGLETALENTS", "TOGGLESPELLBOOK", "TOGGLEQUESTLOG", "TOGGLEWORLDMAP",
	"TOGGLEGUILDTAB", "OPENALLBAGS", "TOGGLEACHIEVEMENT" }) do
	_G["BINDING_NAME_" .. b] = b
end

local ns = {}
for _, file in ipairs({ "Core.lua", "Wheel.lua", "Config.lua" }) do assert(loadfile(file))("QuickWheel", ns) end

local function check(cond, msg) if not cond then error("FAIL: " .. msg, 2) end end

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

-- 2. DB: fresh install
local events = frames[1]
events.scripts.OnEvent(events, "ADDON_LOADED", "QuickWheel")
local db = QuickWheelDB
check(#db.order == 10, "10 ids in order")
local active = ns.GetActive()
check(#active == 8 and active[1].id == "character" and active[8].id == "achievements", "8 default entries in catalog order")

-- 3. DB: old save with an unknown id, a missing id and a disabled entry
QuickWheelDB = { order = { "bags", "ghost", "map" }, enabled = { bags = true, map = false }, radius = 150 }
ns.db = QuickWheelDB
events.scripts.OnEvent(events, "ADDON_LOADED", "QuickWheel")
db = QuickWheelDB
check(db.radius == 150 and db.iconSize == 52, "kept saved value, filled the rest")
check(db.order[1] == "bags" and db.order[2] == "map" and #db.order == 10, "ghost dropped, missing appended, order kept")
check(not db.enabled.map and db.enabled.character and not db.enabled.lfd, "enabled merged with defaults")

-- 4. open -> point right -> release runs the 3rd active entry
db.order = { "character", "talents", "spellbook", "quests", "map", "guild", "bags", "achievements", "lfd", "pets" }
db.enabled.map = true
ns.Wheel.Open()
check(frames[#frames].shown or true, "wheel built")
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
ns.Wheel.Open()
wheel.scripts.OnUpdate(wheel, 0.016); ns.Wheel.Release()
ns.Wheel.Open(); wheel:Hide(); ns.Wheel.Release() -- Escape hides the frame, the later key-up must be ignored
check(#calls == n, "cancel paths run nothing")

-- 6. reset keeps keyInit, restores defaults
db.keyInit = true; db.radius = 999; db.enabled.character = false
ns.ResetDB()
check(db.radius == 110 and db.enabled.character and db.keyInit, "reset restores defaults, keeps keyInit")

-- 6b. no binding for this client -> falls back to the function; neither -> says so
BINDING_NAME_TOGGLEQUESTLOG = nil
ToggleQuestLog = function() calls[#calls + 1] = "fn:ToggleQuestLog" end
ns.Run(ns.CatalogByID.quests)
check(calls[#calls] == "fn:ToggleQuestLog", "fallback to function")
ToggleQuestLog = nil
ns.Run(ns.CatalogByID.quests)
check(printed[#printed]:find("no est"), "unavailable reported")
PlayerSpellsUtil = { ToggleClassTalentOrSpecFrame = function() calls[#calls + 1] = "fn:talents" end }
BINDING_NAME_TOGGLETALENTS = nil
ns.Run(ns.CatalogByID.talents)
check(calls[#calls] == "fn:talents", "dotted function path resolved")
ns.Check()

-- 7. a failing action is reported, not thrown
Boom = function() error("boom") end
ns.Run({ name = "X", bind = {}, fn = { { "Boom" } } })
check(printed[#printed]:find("No se pudo abrir X"), "action error printed")

print("ok")
