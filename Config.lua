-- QuickWheel · Config: ventana de configuración (/qw), capturador de tecla y panel de Interface Options.
-- Widgets propios (botones planos, sliders, checks) para un aspecto oscuro y limpio sin plantillas con nombre.
local addonName, ns = ...
local Config = {}
ns.Config = Config

local floor = math.floor
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
local BINDING = "QUICKWHEEL_TOGGLE"
local BD = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }

local frame, keyBtn, soundCheck, animCheck
local rows, sliders, swatches = {}, {}, {}
local capturing = false

----------------------------------------------------------------------------------------------------
-- Widgets
----------------------------------------------------------------------------------------------------
local function Text(parent, size, r, g, b, text)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT, size)
	fs:SetTextColor(r, g, b)
	fs:SetJustifyH("LEFT")
	if text then fs:SetText(text) end
	return fs
end

local function Flat(parent, w, h, text)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(w); b:SetHeight(h)
	b:SetBackdrop(BD)
	b:SetBackdropColor(0.14, 0.14, 0.17, 1)
	b:SetBackdropBorderColor(0.3, 0.3, 0.36, 1)
	b.label = Text(b, 11, 0.9, 0.9, 0.9, text)
	b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
	b:SetScript("OnEnter", function(self) if self:IsEnabled() then self:SetBackdropColor(0.22, 0.22, 0.27, 1) end end)
	b:SetScript("OnLeave", function(self) self:SetBackdropColor(0.14, 0.14, 0.17, 1) end)
	return b
end

local function SetEnabled(b, on)
	if on then b:Enable() else b:Disable() end
	b.label:SetAlpha(on and 1 or 0.35)
end

local function Check(parent)
	local c = CreateFrame("CheckButton", nil, parent)
	c:SetWidth(24); c:SetHeight(24)
	c:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	c:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	c:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	c:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	return c
end

local function Section(text, x, y, w)
	local fs = Text(frame, 12, 1, 0.82, 0.2, text)
	fs:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
	local line = frame:CreateTexture(nil, "ARTWORK")
	line:SetTexture(WHITE)
	line:SetVertexColor(1, 1, 1, 0.12)
	line:SetWidth(w); line:SetHeight(1)
	line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
end

local function Slider(key, label, minV, maxV, step, fmt, y)
	local s = CreateFrame("Slider", nil, frame)
	s:SetOrientation("HORIZONTAL")
	s:SetWidth(280); s:SetHeight(16)
	s:SetPoint("TOPLEFT", frame, "TOPLEFT", 366, y)
	s:SetHitRectInsets(0, 0, -6, -6)
	s:EnableMouse(true)
	local track = s:CreateTexture(nil, "BACKGROUND")
	track:SetTexture(WHITE)
	track:SetVertexColor(1, 1, 1, 0.15)
	track:SetHeight(4)
	track:SetPoint("LEFT", s, "LEFT", 0, 0)
	track:SetPoint("RIGHT", s, "RIGHT", 0, 0)
	s:SetThumbTexture(WHITE)
	local thumb = s:GetThumbTexture()
	thumb:SetWidth(8); thumb:SetHeight(16)
	s.thumb = thumb
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	local txt = Text(frame, 11, 0.85, 0.85, 0.9)
	txt:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 5)
	s.show = function(v) txt:SetText(label .. ": " .. fmt(v)) end
	s:SetScript("OnValueChanged", function(self, v)
		v = floor(v / step + 0.5) * step
		self.show(v)
		if not self.refreshing then ns.db[key] = v end
	end)
	s.key = key
	sliders[#sliders + 1] = s
end

----------------------------------------------------------------------------------------------------
-- Atajo: captura de tecla
----------------------------------------------------------------------------------------------------
local MODIFIER_KEYS = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, UNKNOWN = 1 }
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local function Refresh()
	if not frame then return end
	local db = ns.db
	local key = GetBindingKey(BINDING)
	keyBtn.label:SetText(capturing and "Pulsa una tecla..." or (key and GetBindingText(key, "KEY_") or "Sin asignar"))

	for i, id in ipairs(db.order) do
		local row, entry = rows[i], ns.CatalogByID[id]
		SetPortraitToTexture(row.icon, entry.icon)
		row.name:SetText(entry.name)
		local on = db.enabled[id]
		row.name:SetTextColor(on and 0.95 or 0.45, on and 0.95 or 0.45, on and 0.95 or 0.5)
		row.icon:SetVertexColor(on and 1 or 0.4, on and 1 or 0.4, on and 1 or 0.4)
		row.check:SetChecked(on)
		SetEnabled(row.up, i > 1)
		SetEnabled(row.down, i < #db.order)
	end

	local a = db.accent
	for _, s in ipairs(sliders) do
		s.refreshing = true
		s:SetValue(db[s.key])
		s.refreshing = false
		s.show(db[s.key])
		s.thumb:SetVertexColor(a[1], a[2], a[3])
	end
	for _, sw in ipairs(swatches) do
		local c = sw.color
		local same = math.abs(c[1] - a[1]) + math.abs(c[2] - a[2]) + math.abs(c[3] - a[3]) < 0.01
		sw:SetBackdropBorderColor(same and 1 or 0.3, same and 1 or 0.3, same and 1 or 0.36, 1)
	end
	soundCheck:SetChecked(db.sound)
	animCheck:SetChecked(db.anim)
end

local function StopCapture()
	capturing = false
	keyBtn:EnableKeyboard(false)
	Refresh()
end

local function Modifiers()
	return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
end

local function Capture(key)
	StopCapture()
	if ns.BindKey(Modifiers() .. key) then Refresh() end
end

local function SetAccent(r, g, b)
	ns.db.accent = { r, g, b }
	Refresh()
end

local function OpenColorPicker()
	local a = ns.db.accent
	local pr, pg, pb = a[1], a[2], a[3]
	ColorPickerFrame.hasOpacity = false
	ColorPickerFrame.opacity = nil
	ColorPickerFrame.previousValues = { pr, pg, pb }
	ColorPickerFrame.func = function() SetAccent(ColorPickerFrame:GetColorRGB()) end
	ColorPickerFrame.cancelFunc = function() SetAccent(pr, pg, pb) end
	ColorPickerFrame:SetColorRGB(pr, pg, pb)
	ColorPickerFrame:Hide(); ColorPickerFrame:Show() -- Hide/Show fuerza a recargar func y colores
end

----------------------------------------------------------------------------------------------------
-- Ventana
----------------------------------------------------------------------------------------------------
local function Build()
	frame = CreateFrame("Frame", "QuickWheelConfig", UIParent)
	frame:SetWidth(680); frame:SetHeight(470)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("HIGH") -- por debajo del selector de color (DIALOG)
	frame:SetBackdrop(BD)
	frame:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
	frame:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
	frame:EnableMouse(true); frame:SetMovable(true); frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetScript("OnShow", Refresh)
	frame:SetScript("OnHide", function() if capturing then StopCapture() end end)
	frame:RegisterEvent("UPDATE_BINDINGS")
	frame:SetScript("OnEvent", Refresh)
	tinsert(UISpecialFrames, "QuickWheelConfig")
	frame:Hide()

	local title = Text(frame, 16, 1, 0.82, 0.2, "QuickWheel")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
	local ver = Text(frame, 10, 0.5, 0.5, 0.55, "v" .. (GetAddOnMetadata(addonName, "Version") or "?"))
	ver:SetPoint("LEFT", title, "RIGHT", 8, -2)
	local close = Flat(frame, 22, 22, "X")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
	close:SetScript("OnClick", function() frame:Hide() end)

	-- Izquierda: atajo + lista de opciones
	Section("Atajo de teclado", 16, -46, 310)
	keyBtn = Flat(frame, 190, 24, "")
	keyBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -70)
	keyBtn:RegisterForClicks("AnyUp")
	keyBtn:SetScript("OnClick", function(_, button)
		if capturing then
			local mouse = MOUSE_KEYS[button]
			if mouse then Capture(mouse) else StopCapture() end
		elseif button == "LeftButton" then
			if InCombatLockdown() then ns.Print("No se puede cambiar el atajo en combate."); return end
			capturing = true
			keyBtn:EnableKeyboard(true) -- en 3.3.5a el marco con teclado se queda todas las teclas
			Refresh()
		end
	end)
	keyBtn:SetScript("OnKeyDown", function(_, key)
		if not capturing then return end
		if key == "ESCAPE" then StopCapture() elseif not MODIFIER_KEYS[key] then Capture(key) end
	end)
	local clear = Flat(frame, 70, 24, "Quitar")
	clear:SetPoint("LEFT", keyBtn, "RIGHT", 8, 0)
	clear:SetScript("OnClick", function() ns.ClearKey(); Refresh() end)
	local hint = Text(frame, 10, 0.55, 0.55, 0.6, "Mantén la tecla, apunta con el ratón y suéltala para abrir.")
	hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -100)

	Section("Opciones de la rueda (orden = posición, la 1ª arriba, en sentido horario)", 16, -122, 310)
	for i = 1, #ns.Catalog do
		local row = {}
		local y = -146 - (i - 1) * 28
		row.check = Check(frame)
		row.check:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, y)
		row.check:SetScript("OnClick", function(self)
			ns.db.enabled[ns.db.order[i]] = self:GetChecked() and true or false
			Refresh()
		end)
		row.icon = frame:CreateTexture(nil, "ARTWORK")
		row.icon:SetWidth(22); row.icon:SetHeight(22)
		row.icon:SetPoint("LEFT", row.check, "RIGHT", 6, 0)
		row.name = Text(frame, 12, 1, 1, 1)
		row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
		row.up = Flat(frame, 50, 20, "Subir")
		row.up:SetPoint("TOPLEFT", frame, "TOPLEFT", 222, y - 2)
		row.down = Flat(frame, 50, 20, "Bajar")
		row.down:SetPoint("LEFT", row.up, "RIGHT", 4, 0)
		local function Move(d)
			local o = ns.db.order
			o[i], o[i + d] = o[i + d], o[i]
			Refresh()
		end
		row.up:SetScript("OnClick", function() Move(-1) end)
		row.down:SetScript("OnClick", function() Move(1) end)
		rows[i] = row
	end

	-- Derecha: aspecto
	Section("Aspecto", 356, -46, 308)
	Slider("radius",   "Radio de la rueda",  70, 200, 1, tostring, -84)
	Slider("iconSize", "Tamaño de los iconos", 32, 80, 1, tostring, -130)
	Slider("deadzone", "Zona muerta central", 20, 80, 1, tostring, -176)
	Slider("bgAlpha",  "Opacidad del fondo", 0, 1, 0.05, function(v) return floor(v * 100 + 0.5) .. "%" end, -222)

	Section("Color de acento", 356, -252, 308)
	for i, p in ipairs(ns.Presets) do
		local sw = Flat(frame, 28, 28)
		sw:SetPoint("TOPLEFT", frame, "TOPLEFT", 366 + (i - 1) * 36, -278)
		sw:SetBackdropColor(p[1], p[2], p[3], 1)
		sw.color = p
		sw:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(p.name)
			GameTooltip:Show()
		end)
		sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
		sw:SetScript("OnClick", function() SetAccent(p[1], p[2], p[3]) end)
		swatches[i] = sw
	end
	local custom = Flat(frame, 110, 28, "Personalizado...")
	custom:SetPoint("TOPLEFT", frame, "TOPLEFT", 366 + #ns.Presets * 36 + 4, -278)
	custom:SetScript("OnClick", OpenColorPicker)

	Section("Opciones", 356, -322, 308)
	soundCheck = Check(frame)
	soundCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 366, -346)
	soundCheck:SetScript("OnClick", function(self) ns.db.sound = self:GetChecked() and true or false end)
	Text(frame, 12, 0.9, 0.9, 0.9, "Sonidos"):SetPoint("LEFT", soundCheck, "RIGHT", 4, 0)
	animCheck = Check(frame)
	animCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 486, -346)
	animCheck:SetScript("OnClick", function(self) ns.db.anim = self:GetChecked() and true or false end)
	Text(frame, 12, 0.9, 0.9, 0.9, "Animación"):SetPoint("LEFT", animCheck, "RIGHT", 4, 0)

	local reset = Flat(frame, 230, 26, "Restaurar valores por defecto")
	reset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
	reset:SetScript("OnClick", function() ns.ResetDB(); Refresh() end)
end

function Config.Toggle()
	if not frame then Build() end
	if frame:IsShown() then frame:Hide() else frame:Show() end
end

----------------------------------------------------------------------------------------------------
-- Interface Options: un panel con acceso directo a la ventana
----------------------------------------------------------------------------------------------------
local panel = CreateFrame("Frame")
panel.name = "QuickWheel"
Text(panel, 16, 1, 0.82, 0.2, "QuickWheel"):SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
Text(panel, 12, 0.9, 0.9, 0.9, "Rueda radial rápida. También con /qw."):SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -44)
local open = Flat(panel, 200, 26, "Abrir configuración")
open:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -72)
open:SetScript("OnClick", function()
	HideUIPanel(InterfaceOptionsFrame) -- si no, queda por encima de nuestra ventana
	HideUIPanel(GameMenuFrame)
	if not (frame and frame:IsShown()) then Config.Toggle() end
end)
InterfaceOptions_AddCategory(panel)
