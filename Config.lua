-- QuickWheel · Config: ventana de configuración (/qw): ruedas (perfiles), atajo, opciones, entradas propias y aspecto.
-- Widgets propios (botones planos, sliders, checks, lista con scroll) para un aspecto oscuro y limpio.
-- La ventana se redimensiona (esquina inferior derecha); la lista muestra tantas filas como quepan.
local addonName, ns = ...
local Config = {}
ns.Config = Config

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local BD = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }

local ROW_H, POOL = 28, 16      -- alto de fila y filas máximas (POOL >= filas visibles con la ventana al máximo)
local LIST_TOP = -200           -- y de la primera fila dentro de `left`
local CHROME = 46 + 24 + 200 + 34 -- alto fijo alrededor de la lista (cabecera, pie, botones)
local MIN_W, MIN_H, MAX_W, MAX_H = 720, 480, 1100, 900

local frame, left, right, editor
local keyBtn, keyHint, soundCheck, animCheck, nameBox, delBtn, addBtn, countText, track, thumb
local tabs, rows, sliders, swatches = {}, {}, {}, {}
local capturing, delArmed, offset = false, false, 0

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
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
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

local function Edit(parent, w)
	local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
	e:SetWidth(w); e:SetHeight(22)
	e:SetBackdrop(BD)
	e:SetBackdropColor(0.02, 0.02, 0.03, 1)
	e:SetBackdropBorderColor(0.3, 0.3, 0.36, 1)
	e:SetFont(FONT, 12)
	e:SetTextColor(0.95, 0.95, 0.95)
	e:SetTextInsets(6, 6, 0, 0)
	e:SetAutoFocus(false)
	e:SetMaxLetters(255)
	e:SetScript("OnEscapePressed", e.ClearFocus)
	e:SetScript("OnEnterPressed", e.ClearFocus)
	return e
end

-- Título de sección con línea a todo el ancho del contenedor.
local function Section(parent, text, y)
	local fs = Text(parent, 12, 1, 0.82, 0.2, text)
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetTexture(WHITE)
	line:SetVertexColor(1, 1, 1, 0.12)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y - 17)
	line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y - 17)
end

local function Profile() return ns.db.profiles[ns.db.selected] end

local function CountOn(p)
	local n = 0
	for _, it in ipairs(p.items) do if it.on then n = n + 1 end end
	return n
end

local function Visible() return max(1, min(POOL, floor((frame:GetHeight() - CHROME) / ROW_H))) end

----------------------------------------------------------------------------------------------------
-- Refresco
----------------------------------------------------------------------------------------------------
local function RefreshList()
	local db = ns.db
	local items = Profile().items
	local n, vis = #items, Visible()
	offset = max(0, min(offset, n - vis))
	for r = 1, POOL do
		local row, idx = rows[r], offset + r
		local it = items[idx]
		if r <= vis and it then
			local entry = ns.Entry(it.id)
			row.idx, row.item = idx, it
			ns.Circle(row.icon, ns.IconPath(entry.icon))
			row.name:SetText(entry.name)
			local c = entry.custom and { 0.7, 0.85, 1 } or { 0.95, 0.95, 0.95 }
			row.name:SetTextColor(it.on and c[1] or 0.45, it.on and c[2] or 0.45, it.on and c[3] or 0.5)
			row.icon:SetVertexColor(it.on and 1 or 0.4, it.on and 1 or 0.4, it.on and 1 or 0.4)
			row.check:SetChecked(it.on)
			SetEnabled(row.up, idx > 1)
			SetEnabled(row.down, idx < n)
			if entry.custom then row.edit:Show() else row.edit:Hide() end
			row:Show()
		else
			row:Hide()
		end
	end
	-- barra de scroll
	if n > vis then
		local h = vis * ROW_H
		track:SetHeight(h); track:Show()
		thumb:SetHeight(max(14, h * vis / n))
		thumb:ClearAllPoints()
		thumb:SetPoint("TOP", track, "TOP", 0, -(h - thumb:GetHeight()) * offset / (n - vis))
		thumb:Show()
	else
		track:Hide(); thumb:Hide()
	end
	local on = CountOn(Profile())
	countText:SetText(on .. "/" .. ns.MAX_SLOTS .. " en la rueda")
	countText:SetTextColor(on >= ns.MAX_SLOTS and 1 or 0.55, on >= ns.MAX_SLOTS and 0.5 or 0.55, on >= ns.MAX_SLOTS and 0.3 or 0.6)
end

local function Refresh()
	if not frame then return end
	local db = ns.db
	local a, sel = db.accent, db.selected

	-- pestañas de ruedas: las existentes + una "+" en el primer hueco libre
	local plus
	for i = 1, ns.MAX_PROFILES do
		local t, p = tabs[i], db.profiles[i]
		if p then
			t.label:SetText(p.name ~= "" and p.name or ("Rueda " .. i))
			t:Show()
		elseif not plus then
			plus = i
			t.label:SetText("+ Nueva")
			t:Show()
		else
			t:Hide()
		end
		local on = (i == sel)
		t:SetBackdropBorderColor(on and a[1] or 0.3, on and a[2] or 0.3, on and a[3] or 0.36, 1)
	end
	if not nameBox:HasFocus() then nameBox:SetText(Profile().name) end
	SetEnabled(delBtn, sel ~= 1)
	delBtn.label:SetText(delArmed and "¿Seguro?" or "Borrar rueda")

	local key = GetBindingKey(ns.BINDINGS[sel])
	keyBtn.label:SetText(capturing and "Pulsa una tecla..." or (key or "Sin asignar"))
	keyHint:SetText("Tecla de la rueda " .. sel .. ": mantén, apunta y suelta.")

	RefreshList()

	for _, s in ipairs(sliders) do
		s.refreshing = true
		s:SetValue(db[s.key])
		s.refreshing = false
		s.show(db[s.key])
		s.thumb:SetVertexColor(a[1], a[2], a[3])
	end
	for _, sw in ipairs(swatches) do
		local c = sw.color
		local same = abs(c[1] - a[1]) + abs(c[2] - a[2]) + abs(c[3] - a[3]) < 0.01
		sw:SetBackdropBorderColor(same and 1 or 0.3, same and 1 or 0.3, same and 1 or 0.36, 1)
	end
	soundCheck:SetChecked(db.sound)
	animCheck:SetChecked(db.anim)
end

----------------------------------------------------------------------------------------------------
-- Atajo: captura de tecla
----------------------------------------------------------------------------------------------------
local MODIFIER_KEYS = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, UNKNOWN = 1 }
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

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
	if ns.BindKey(Modifiers() .. key, ns.db.selected) then Refresh() end
end

local function SetAccent(r, g, b)
	ns.db.accent = { r, g, b }
	Refresh()
end

local function OpenColorPicker()
	local a = ns.db.accent
	local pr, pg, pb = a[1], a[2], a[3]
	local function apply() SetAccent(ColorPickerFrame:GetColorRGB()) end
	local function cancel() SetAccent(pr, pg, pb) end
	if ColorPickerFrame.SetupColorPickerAndShow then -- API moderna
		ColorPickerFrame:SetupColorPickerAndShow({ r = pr, g = pg, b = pb, hasOpacity = false, swatchFunc = apply, cancelFunc = cancel })
	else
		ColorPickerFrame.hasOpacity = false
		ColorPickerFrame.opacity = nil
		ColorPickerFrame.previousValues = { pr, pg, pb }
		ColorPickerFrame.func, ColorPickerFrame.cancelFunc = apply, cancel
		ColorPickerFrame:SetColorRGB(pr, pg, pb)
		ColorPickerFrame:Hide(); ColorPickerFrame:Show() -- Hide/Show fuerza a recargar func y colores
	end
end

----------------------------------------------------------------------------------------------------
-- Editor de entradas propias (nombre, icono, comando)
----------------------------------------------------------------------------------------------------
local function BuildEditor()
	editor = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	editor:SetWidth(430); editor:SetHeight(320)
	editor:SetPoint("CENTER", frame, "CENTER", 0, 0)
	editor:SetFrameStrata("DIALOG")
	editor:EnableMouse(true)
	editor:SetBackdrop(BD)
	editor:SetBackdropColor(0.08, 0.08, 0.1, 1)
	editor:SetBackdropBorderColor(0.4, 0.4, 0.46, 1)
	editor:Hide()

	editor.title = Text(editor, 14, 1, 0.82, 0.2)
	editor.title:SetPoint("TOPLEFT", editor, "TOPLEFT", 16, -14)

	local function Field(label, y, w)
		Text(editor, 11, 0.7, 0.7, 0.75, label):SetPoint("TOPLEFT", editor, "TOPLEFT", 16, y)
		local e = Edit(editor, w)
		e:SetPoint("TOPLEFT", editor, "TOPLEFT", 16, y - 16)
		return e
	end
	editor.name = Field("Nombre", -46, 398)
	editor.name:SetMaxLetters(24)
	editor.icon = Field("Icono: nombre dentro de Interface\\Icons (INV_Misc_Note_01), ruta o ID", -92, 360)
	editor.preview = editor:CreateTexture(nil, "ARTWORK")
	editor.preview:SetWidth(24); editor.preview:SetHeight(24)
	editor.preview:SetPoint("LEFT", editor.icon, "RIGHT", 14, 0)
	editor.icon:SetScript("OnTextChanged", function(self) ns.Circle(editor.preview, ns.IconPath(strtrim(self:GetText()))) end)
	editor.cmd = Field("Comando (una línea)", -138, 398)

	local hint = Text(editor, 10, 0.55, 0.55, 0.6,
		"Ejemplos: /dance  ·  /run ToggleCollectionsJournal()  ·  /dbm pull 10. Sirve cualquier emote, script (/run) o comando de otro addon. " ..
		"Blizzard bloquea /cast, /use y las macros a los addons, así que hechizos y objetos no funcionan desde aquí.")
	hint:SetWidth(398); hint:SetWordWrap(true)
	hint:SetPoint("TOPLEFT", editor, "TOPLEFT", 16, -192)

	editor.save = Flat(editor, 90, 24, "Guardar")
	editor.save:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", 16, 16)
	editor.save:SetScript("OnClick", function()
		local name = strtrim(editor.name:GetText())
		if name == "" then name = "Sin nombre" end
		local icon, cmd = strtrim(editor.icon:GetText()), strtrim(editor.cmd:GetText())
		if editor.id then
			local e = ns.db.custom[editor.id]
			e.name, e.icon, e.command = name, icon, cmd
		else
			ns.AddCustom(name, icon, cmd, ns.db.selected)
			offset = 1e9 -- salta al final de la lista, donde queda la nueva
		end
		editor:Hide()
		Refresh()
	end)
	local cancel = Flat(editor, 90, 24, "Cancelar")
	cancel:SetPoint("LEFT", editor.save, "RIGHT", 8, 0)
	cancel:SetScript("OnClick", function() editor:Hide() end)
	editor.del = Flat(editor, 110, 24, "Eliminar entrada")
	editor.del:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -16, 16)
	editor.del:SetScript("OnClick", function()
		if not editor.delArmed then
			editor.delArmed = true
			editor.del.label:SetText("¿Seguro?")
			return
		end
		ns.DeleteCustom(editor.id)
		editor:Hide()
		Refresh()
	end)
end

local function OpenEditor(id)
	if not editor then BuildEditor() end
	local e = id and ns.db.custom[id]
	editor.id, editor.delArmed = id, false
	editor.title:SetText(e and "Editar entrada" or "Nueva entrada")
	editor.name:SetText(e and e.name or "")
	editor.icon:SetText(e and e.icon or "")
	editor.cmd:SetText(e and e.command or "")
	editor.del.label:SetText("Eliminar entrada")
	if e then editor.del:Show() else editor.del:Hide() end
	editor:Show()
end

----------------------------------------------------------------------------------------------------
-- Ventana
----------------------------------------------------------------------------------------------------
local function MakeRow(r)
	local row = CreateFrame("Frame", nil, left)
	row:SetHeight(ROW_H)
	local y = LIST_TOP - (r - 1) * ROW_H
	row:SetPoint("TOPLEFT", left, "TOPLEFT", 0, y)
	row:SetPoint("TOPRIGHT", left, "TOPRIGHT", -12, y)

	row.check = Check(row)
	row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.check:SetScript("OnClick", function(self)
		local want = self:GetChecked() and true or false
		if want and CountOn(Profile()) >= ns.MAX_SLOTS then
			ns.Print("máximo " .. ns.MAX_SLOTS .. " opciones por rueda.")
			want = false
		end
		row.item.on = want
		Refresh()
	end)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(22); row.icon:SetHeight(22)
	row.icon:SetPoint("LEFT", row.check, "RIGHT", 6, 0)

	row.down = Flat(row, 50, 20, "Bajar")
	row.down:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.up = Flat(row, 50, 20, "Subir")
	row.up:SetPoint("RIGHT", row.down, "LEFT", -4, 0)
	row.edit = Flat(row, 50, 20, "Editar")
	row.edit:SetPoint("RIGHT", row.up, "LEFT", -4, 0)

	row.name = Text(row, 12, 1, 1, 1)
	row.name:SetWordWrap(false)
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
	row.name:SetPoint("RIGHT", row.edit, "LEFT", -6, 0)

	local function Move(d)
		local items = Profile().items
		local i = row.idx
		items[i], items[i + d] = items[i + d], items[i]
		Refresh()
	end
	row.up:SetScript("OnClick", function() Move(-1) end)
	row.down:SetScript("OnClick", function() Move(1) end)
	row.edit:SetScript("OnClick", function() OpenEditor(row.item.id) end)
	rows[r] = row
end

local function Slider(key, label, minV, maxV, step, fmt, y)
	local s = CreateFrame("Slider", nil, right)
	s:SetOrientation("HORIZONTAL")
	s:SetWidth(280); s:SetHeight(16)
	s:SetPoint("TOPLEFT", right, "TOPLEFT", 4, y)
	s:SetHitRectInsets(0, 0, -6, -6)
	s:EnableMouse(true)
	local trk = s:CreateTexture(nil, "BACKGROUND")
	trk:SetTexture(WHITE)
	trk:SetVertexColor(1, 1, 1, 0.15)
	trk:SetHeight(4)
	trk:SetPoint("LEFT", s, "LEFT", 0, 0)
	trk:SetPoint("RIGHT", s, "RIGHT", 0, 0)
	s:SetThumbTexture(WHITE)
	local th = s:GetThumbTexture()
	th:SetWidth(8); th:SetHeight(16)
	s.thumb = th
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	local txt = Text(right, 11, 0.85, 0.85, 0.9)
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

local function Build()
	local db = ns.db
	frame = CreateFrame("Frame", "QuickWheelConfig", UIParent, "BackdropTemplate")
	frame:SetWidth(db.winW or 780); frame:SetHeight(db.winH or 600)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("HIGH") -- por debajo del selector de color (DIALOG)
	frame:SetBackdrop(BD)
	frame:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
	frame:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
	frame:EnableMouse(true); frame:SetMovable(true); frame:SetClampedToScreen(true)
	frame:SetResizable(true)
	if frame.SetResizeBounds then frame:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H) else frame:SetMinResize(MIN_W, MIN_H); frame:SetMaxResize(MAX_W, MAX_H) end
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetScript("OnShow", Refresh)
	frame:SetScript("OnSizeChanged", function(self) if self:IsShown() then RefreshList() end end)
	frame:SetScript("OnHide", function()
		if capturing then StopCapture() end
		if editor then editor:Hide() end
		delArmed = false
	end)
	frame:RegisterEvent("UPDATE_BINDINGS")
	frame:SetScript("OnEvent", Refresh)
	tinsert(UISpecialFrames, "QuickWheelConfig")
	frame:Hide()

	local title = Text(frame, 16, 1, 0.82, 0.2, "QuickWheel")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
	local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
	local ver = Text(frame, 10, 0.5, 0.5, 0.55, "v" .. (getMeta(addonName, "Version") or "?"))
	ver:SetPoint("LEFT", title, "RIGHT", 8, -2)
	local close = Flat(frame, 22, 22, "X")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
	close:SetScript("OnClick", function() frame:Hide() end)

	-- esquina de redimensionado
	local grip = CreateFrame("Button", nil, frame)
	grip:SetWidth(16); grip:SetHeight(16)
	grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		ns.db.winW, ns.db.winH = floor(frame:GetWidth() + 0.5), floor(frame:GetHeight() + 0.5)
	end)

	-- contenedores: la derecha (aspecto) tiene ancho fijo; la izquierda ocupa el resto
	right = CreateFrame("Frame", nil, frame)
	right:SetWidth(300)
	right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -46)
	right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 24)
	left = CreateFrame("Frame", nil, frame)
	left:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -46)
	left:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -24, 0)
	left:EnableMouseWheel(true)
	left:SetScript("OnMouseWheel", function(_, delta) offset = offset - delta; RefreshList() end)

	-- Izquierda: ruedas
	Section(left, "Ruedas", 0)
	for i = 1, ns.MAX_PROFILES do
		local t = Flat(left, 86, 24, "")
		t:SetPoint("TOPLEFT", left, "TOPLEFT", (i - 1) * 90, -26)
		t.label:SetWidth(78); t.label:SetWordWrap(false)
		t:SetScript("OnClick", function()
			if not ns.db.profiles[i] then ns.NewProfile(i, Profile()) end -- "+" crea una copia de la rueda actual
			ns.db.selected, delArmed, offset = i, false, 0
			Refresh()
		end)
		tabs[i] = t
	end
	Text(left, 11, 0.7, 0.7, 0.75, "Nombre"):SetPoint("TOPLEFT", left, "TOPLEFT", 0, -62)
	nameBox = Edit(left, 170)
	nameBox:SetMaxLetters(16)
	nameBox:SetPoint("TOPLEFT", left, "TOPLEFT", 52, -58)
	nameBox:SetScript("OnTextChanged", function(self, user)
		if user then Profile().name = self:GetText(); Refresh() end
	end)
	delBtn = Flat(left, 110, 22, "Borrar rueda")
	delBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
	delBtn:SetScript("OnClick", function()
		if ns.db.selected == 1 then return end
		if not delArmed then delArmed = true; Refresh(); return end -- dos clics para borrar
		ns.DeleteProfile(ns.db.selected)
		delArmed, offset = false, 0
		Refresh()
	end)

	-- Izquierda: atajo
	Section(left, "Atajo de teclado", -92)
	keyBtn = Flat(left, 190, 24, "")
	keyBtn:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -114)
	keyBtn:RegisterForClicks("AnyUp")
	keyBtn:SetScript("OnClick", function(_, button)
		if capturing then
			local mouse = MOUSE_KEYS[button]
			if mouse then Capture(mouse) else StopCapture() end
		elseif button == "LeftButton" then
			if InCombatLockdown() then ns.Print("No se puede cambiar el atajo en combate."); return end
			capturing = true
			keyBtn:EnableKeyboard(true) -- un marco con teclado se queda todas las teclas
			Refresh()
		end
	end)
	keyBtn:SetScript("OnKeyDown", function(_, key)
		if not capturing then return end
		if key == "ESCAPE" then StopCapture() elseif not MODIFIER_KEYS[key] then Capture(key) end
	end)
	local clear = Flat(left, 70, 24, "Quitar")
	clear:SetPoint("LEFT", keyBtn, "RIGHT", 8, 0)
	clear:SetScript("OnClick", function() ns.ClearKey(ns.db.selected); Refresh() end)
	keyHint = Text(left, 10, 0.55, 0.55, 0.6)
	keyHint:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -144)

	-- Izquierda: opciones (lista con scroll)
	Section(left, "Opciones de la rueda", -162)
	Text(left, 10, 0.55, 0.55, 0.6, "La 1ª va arriba; el resto, en sentido horario."):SetPoint("TOPLEFT", left, "TOPLEFT", 0, -184)
	for r = 1, POOL do MakeRow(r) end
	track = left:CreateTexture(nil, "ARTWORK")
	track:SetTexture(WHITE); track:SetVertexColor(1, 1, 1, 0.08)
	track:SetWidth(4)
	track:SetPoint("TOPRIGHT", left, "TOPRIGHT", -2, LIST_TOP)
	thumb = left:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture(WHITE); thumb:SetVertexColor(1, 1, 1, 0.35)
	thumb:SetWidth(4)
	addBtn = Flat(left, 150, 24, "+ Añadir comando")
	addBtn:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 0, 0)
	addBtn:SetScript("OnClick", function() OpenEditor(nil) end)
	countText = Text(left, 10, 0.55, 0.55, 0.6)
	countText:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 0, 6)

	-- Derecha: aspecto
	Section(right, "Aspecto", 0)
	Slider("radius",   "Radio de la rueda",    70, 200, 1, tostring, -44)
	Slider("iconSize", "Tamaño de los iconos", 32, 80, 1, tostring, -90)
	Slider("deadzone", "Zona muerta central",  20, 80, 1, tostring, -136)
	Slider("bgAlpha",  "Opacidad del fondo",   0, 1, 0.05, function(v) return floor(v * 100 + 0.5) .. "%" end, -182)

	Section(right, "Color de acento", -210)
	for i, p in ipairs(ns.Presets) do
		local sw = Flat(right, 28, 28)
		sw:SetPoint("TOPLEFT", right, "TOPLEFT", 4 + (i - 1) * 36, -236)
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
	local custom = Flat(right, 110, 28, "Personalizado...")
	custom:SetPoint("TOPLEFT", right, "TOPLEFT", 4 + #ns.Presets * 36 + 4, -236)
	custom:SetScript("OnClick", OpenColorPicker)

	Section(right, "Opciones", -282)
	soundCheck = Check(right)
	soundCheck:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -306)
	soundCheck:SetScript("OnClick", function(self) ns.db.sound = self:GetChecked() and true or false end)
	Text(right, 12, 0.9, 0.9, 0.9, "Sonidos"):SetPoint("LEFT", soundCheck, "RIGHT", 4, 0)
	animCheck = Check(right)
	animCheck:SetPoint("TOPLEFT", right, "TOPLEFT", 124, -306)
	animCheck:SetScript("OnClick", function(self) ns.db.anim = self:GetChecked() and true or false end)
	Text(right, 12, 0.9, 0.9, 0.9, "Animación"):SetPoint("LEFT", animCheck, "RIGHT", 4, 0)

	local reset = Flat(right, 230, 26, "Restaurar valores por defecto")
	reset:SetPoint("BOTTOM", right, "BOTTOM", 0, 0)
	reset:SetScript("OnClick", function() ns.ResetDB(); Refresh() end)
	local resetHint = Text(right, 10, 0.55, 0.55, 0.6, "Aspecto y opciones de la rueda actual.\nTus ruedas y entradas propias se conservan.")
	resetHint:SetPoint("BOTTOMLEFT", reset, "TOPLEFT", 0, 6)
end

function Config.Toggle()
	if not frame then Build() end
	if frame:IsShown() then frame:Hide() else frame:Show() end
end

----------------------------------------------------------------------------------------------------
-- Panel de Interface Options / Settings: un acceso directo a la ventana
----------------------------------------------------------------------------------------------------
local panel = CreateFrame("Frame")
panel.name = "QuickWheel"
Text(panel, 16, 1, 0.82, 0.2, "QuickWheel"):SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
Text(panel, 12, 0.9, 0.9, 0.9, "Rueda radial rápida. También con /qw."):SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -44)
local open = Flat(panel, 200, 26, "Abrir configuración")
open:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -72)
open:SetScript("OnClick", function()
	-- si no, estos paneles tapan nuestra ventana (alguno puede no existir en este cliente)
	if SettingsPanel then HideUIPanel(SettingsPanel) end
	if InterfaceOptionsFrame then HideUIPanel(InterfaceOptionsFrame) end
	HideUIPanel(GameMenuFrame)
	if not (frame and frame:IsShown()) then Config.Toggle() end
end)
if Settings and Settings.RegisterCanvasLayoutCategory then
	Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
else
	InterfaceOptions_AddCategory(panel)
end
