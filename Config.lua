-- RadialHub · Config: ventana de configuración (/rh): ruedas (perfiles), atajo, opciones por categorías,
-- entradas propias (emotes, comandos) y aspecto.
-- Widgets propios (botones planos, sliders, checks, lista con scroll) para un aspecto oscuro y limpio.
-- La ventana se redimensiona (esquina inferior derecha); la lista muestra tantas filas como quepan.
local addonName, ns = ...
local Config = {}
ns.Config = Config
local L = ns.L
local texts = {} -- textos fijos (clave en español) que se vuelven a traducir al cambiar de idioma

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local BD = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }

local ROW_H, POOL = 28, 16        -- alto de fila y filas máximas (POOL >= filas visibles con la ventana al máximo)
local LIST_TOP = -212             -- y de la primera fila dentro de `left`
local CHROME = 46 + 24 + 212 + 34 -- alto fijo alrededor de la lista (cabecera, pie, botones)
local MIN_W, MIN_H, MAX_W, MAX_H = 720, 520, 1100, 900

local frame, left, right, editor, picker
local keyBtn, keyHint, soundCheck, animCheck, nameBox, delBtn, countText, track, thumb
local tabs, filterTabs, rows, sliders, swatches, langButtons = {}, {}, {}, {}, {}, {}
local capturing, delArmed, offset, filter = false, false, 0, nil -- filter: nil (todo) | "menu" | "emote" | "command"

----------------------------------------------------------------------------------------------------
-- Widgets
----------------------------------------------------------------------------------------------------
local function Text(parent, size, r, g, b, text)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT, size)
	fs:SetTextColor(r, g, b)
	fs:SetJustifyH("LEFT")
	if text then
		fs.lkey = text
		fs:SetText(L(text))
		texts[#texts + 1] = fs
	end
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
	e:SetFontObject(ChatFontNormal)
	e:SetTextColor(0.95, 0.95, 0.95)
	e:SetTextInsets(6, 6, 0, 0)
	e:SetAutoFocus(false)
	e:SetMaxLetters(255)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
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
	for _, it in ipairs(p.items) do if it.on and ns.Available(ns.Entry(it.id)) then n = n + 1 end end
	return n
end

local function Visible() return max(1, min(POOL, floor((frame:GetHeight() - CHROME) / ROW_H))) end

-- Posiciones (en profile.items) de las entradas que pasan el filtro de categoría, en orden.
local function View()
	local v = {}
	for i, it in ipairs(Profile().items) do
		local entry = ns.Entry(it.id)
		if ns.Available(entry) and (not filter or ns.CatOf(entry) == filter) then v[#v + 1] = i end
	end
	return v
end

----------------------------------------------------------------------------------------------------
-- Refresco
----------------------------------------------------------------------------------------------------
local function RefreshList()
	local items = Profile().items
	local view = View()
	local n, vis = #view, Visible()
	offset = max(0, min(offset, n - vis))
	for r = 1, POOL do
		local pos = offset + r
		local idx = view[pos]
		local row = rows[r]
		if r <= vis and idx then
			local it = items[idx]
			local entry = ns.Entry(it.id)
			row.idx, row.pos, row.view, row.item = idx, pos, view, it
			ns.Circle(row.icon, ns.IconPath(entry.icon))
			row.name:SetText(L(entry.name))
			local c = entry.custom and { 0.7, 0.85, 1 } or { 0.95, 0.95, 0.95 }
			row.name:SetTextColor(it.on and c[1] or 0.45, it.on and c[2] or 0.45, it.on and c[3] or 0.5)
			row.icon:SetVertexColor(it.on and 1 or 0.4, it.on and 1 or 0.4, it.on and 1 or 0.4)
			row.check:SetChecked(it.on)
			SetEnabled(row.up, pos > 1)
			SetEnabled(row.down, pos < n)
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
	countText:SetText(L("%d/%d activas", on, ns.MAX_SLOTS))
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
			t.label:SetText(p.name ~= "" and p.name or L("Rueda %d", i))
			t:Show()
		elseif not plus then
			plus = i
			t.label:SetText(L("+ Nueva"))
			t:Show()
		else
			t:Hide()
		end
		local on = (i == sel)
		t:SetBackdropBorderColor(on and a[1] or 0.3, on and a[2] or 0.3, on and a[3] or 0.36, 1)
	end
	if not nameBox:HasFocus() then nameBox:SetText(Profile().name) end
	SetEnabled(delBtn, sel ~= 1)
	delBtn.label:SetText(delArmed and L("¿Seguro?") or L("Borrar rueda"))

	local key = GetBindingKey(ns.BINDINGS[sel])
	keyBtn.label:SetText(capturing and L("Pulsa una tecla...") or (key or L("Sin asignar")))
	keyHint:SetText(L("Tecla de la rueda %d: mantén, apunta y suelta.", sel))

	for _, ft in ipairs(filterTabs) do
		local on = (ft.cat == filter)
		ft:SetBackdropBorderColor(on and a[1] or 0.3, on and a[2] or 0.3, on and a[3] or 0.36, 1)
	end
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
	for _, b in ipairs(langButtons) do
		local on = (b.lang == (db.lang or "auto"))
		b:SetBackdropBorderColor(on and a[1] or 0.3, on and a[2] or 0.3, on and a[3] or 0.36, 1)
	end
end

----------------------------------------------------------------------------------------------------
-- Atajo: captura de tecla
----------------------------------------------------------------------------------------------------
local MODIFIER_KEYS = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, UNKNOWN = 1 }
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local function StopCapture()
	capturing = false
	if not InCombatLockdown() then keyBtn:EnableKeyboard(false) end -- en combate la ventana ya está oculta
	Refresh()
end

local function Modifiers()
	return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
end

local function Capture(key)
	StopCapture()
	if ns.BindKey(Modifiers() .. key, ns.db.selected) then
		ns.Print(L("atajo guardado. Haz /reload antes de entrar en combate para que Blizzard no arrastre el cambio."))
		Refresh()
	end
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
-- Ventanitas: editor de entradas propias y selector de emotes
----------------------------------------------------------------------------------------------------
local function Popup(w, h)
	local f = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	f:SetWidth(w); f:SetHeight(h)
	f:SetPoint("CENTER", frame, "CENTER", 0, 0)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	f:SetBackdrop(BD)
	f:SetBackdropColor(0.08, 0.08, 0.1, 1)
	f:SetBackdropBorderColor(0.4, 0.4, 0.46, 1)
	f:Hide()
	f.title = Text(f, 14, 1, 0.82, 0.2)
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
	return f
end

-- Entrada nueva (o editada) y salto a su categoría al final de la lista.
local function Added(cat)
	filter, offset = cat, 1e9
	Refresh()
end

local function BuildEditor()
	editor = Popup(430, 320)

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
		"Sirven comandos de otros addons (/dbm pull 10), emotes (/dance) y /run con tu propio código. Los comandos de Blizzard (/cast, /use, /macro, /reload...) no: lanzarlos desde un addon contamina su interfaz.")
	hint:SetWidth(398); hint:SetWordWrap(true)
	hint:SetPoint("TOPLEFT", editor, "TOPLEFT", 16, -192)

	editor.save = Flat(editor, 90, 24, "Guardar")
	editor.save:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", 16, 16)
	editor.save:SetScript("OnClick", function()
		local name = strtrim(editor.name:GetText())
		if name == "" then name = L("Sin nombre") end
		local icon, cmd = strtrim(editor.icon:GetText()), strtrim(editor.cmd:GetText())
		local cat
		if editor.id then
			local e = ns.db.custom[editor.id]
			e.name, e.icon, e.command = name, icon, cmd
			cat = filter
		else
			ns.AddCustom({ name = name, icon = icon, command = cmd, cat = "command" }, ns.db.selected)
			cat = "command"
		end
		editor:Hide()
		if editor.id then Refresh() else Added(cat) end
	end)
	local cancel = Flat(editor, 90, 24, "Cancelar")
	cancel:SetPoint("LEFT", editor.save, "RIGHT", 8, 0)
	cancel:SetScript("OnClick", function() editor:Hide() end)
	editor.del = Flat(editor, 110, 24, "Eliminar entrada")
	editor.del:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -16, 16)
	editor.del:SetScript("OnClick", function()
		if not editor.delArmed then
			editor.delArmed = true
			editor.del.label:SetText(L("¿Seguro?"))
			return
		end
		ns.DeleteCustom(editor.id)
		editor:Hide()
		Refresh()
	end)
end

local function OpenEditor(id)
	if not editor then BuildEditor() end
	if picker then picker:Hide() end
	local e = id and ns.db.custom[id]
	editor.id, editor.delArmed = id, false
	editor.title:SetText(e and L("Editar entrada") or L("Nuevo comando"))
	editor.name:SetText(e and e.name or "")
	editor.icon:SetText(e and e.icon or "")
	editor.cmd:SetText(e and e.command or "")
	editor.del.label:SetText(L("Eliminar entrada"))
	if e then editor.del:Show() else editor.del:Hide() end
	editor:Show()
end

local function OpenPicker()
	if not picker then
		picker = Popup(430, 60 + 4 * 30 + 50)
		picker.title:SetText(L("Añadir emote"))
		for i, e in ipairs(ns.Emotes) do
			local b = Flat(picker, 124, 24, e[1])
			b:SetPoint("TOPLEFT", picker, "TOPLEFT", 16 + ((i - 1) % 3) * 130, -46 - floor((i - 1) / 3) * 30)
			b:SetScript("OnClick", function()
				ns.AddCustom({ name = L(e[1]), icon = e[3], command = "", cat = "emote", emote = e[2] }, ns.db.selected)
				picker:Hide()
				Added("emote")
			end)
		end
		local close = Flat(picker, 90, 24, "Cerrar")
		close:SetPoint("BOTTOMLEFT", picker, "BOTTOMLEFT", 16, 16)
		close:SetScript("OnClick", function() picker:Hide() end)
		local hint = Text(picker, 10, 0.55, 0.55, 0.6, "Después puedes cambiar su nombre o icono con Editar.")
		hint:SetPoint("LEFT", close, "RIGHT", 12, 0)
	end
	if editor then editor:Hide() end
	picker:Show()
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
			ns.Print(L("máximo %d opciones por rueda.", ns.MAX_SLOTS))
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

	local function Move(d) -- intercambia con la vecina visible (respeta el filtro de categoría)
		local other = row.view[row.pos + d]
		if not other then return end
		local items = Profile().items
		items[row.idx], items[other] = items[other], items[row.idx]
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
	s.show = function(v) txt:SetText(L(label) .. ": " .. fmt(v)) end
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
	frame = CreateFrame("Frame", "RadialHubConfig", UIParent, "BackdropTemplate")
	frame:SetWidth(db.winW or 780); frame:SetHeight(db.winH or 600)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG") -- por encima del panel de Opciones; el selector de color (toplevel) sube al mostrarse
	frame:SetToplevel(true)
	frame:SetBackdrop(BD)
	frame:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
	frame:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
	frame:EnableMouse(true); frame:SetMovable(true); frame:SetClampedToScreen(true)
	frame:SetResizable(true)
	if frame.SetResizeBounds then frame:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H) else frame:SetMinResize(MIN_W, MIN_H); frame:SetMaxResize(MAX_W, MAX_H) end
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetScript("OnShow", function()
		if not InCombatLockdown() then frame:SetPropagateKeyboardInput(true) end
		Refresh()
	end)
	-- Escape cierra la ventana sin usar UISpecialFrames (que contamina el menú del juego y el Modo edición):
	-- el marco deja pasar todas las teclas y solo se queda Escape.
	frame:EnableKeyboard(true)
	frame:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" and not InCombatLockdown() then
			self:SetPropagateKeyboardInput(false)
			self:Hide()
		end
	end)
	frame:SetScript("OnSizeChanged", function(self) if self:IsShown() then RefreshList() end end)
	frame:SetScript("OnHide", function()
		if not InCombatLockdown() then frame:SetPropagateKeyboardInput(true) end
		if capturing then StopCapture() end
		if editor then editor:Hide() end
		if picker then picker:Hide() end
		delArmed = false
	end)
	frame:RegisterEvent("UPDATE_BINDINGS")
	frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- la ventana no se usa en combate: se cierra al entrar
	frame:SetScript("OnEvent", function(self, event)
		if event == "PLAYER_REGEN_DISABLED" then self:Hide() elseif self:IsShown() then Refresh() end
	end)
	frame:Hide()

	local title = Text(frame, 16, 1, 0.82, 0.2, "RadialHub")
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
			if InCombatLockdown() then ns.Print(L("No se puede cambiar el atajo en combate.")); return end
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
	clear:SetScript("OnClick", function()
		ns.ClearKey(ns.db.selected)
		ns.Print(L("atajo quitado. Haz /reload antes de entrar en combate para que Blizzard no arrastre el cambio."))
		Refresh()
	end)
	keyHint = Text(left, 10, 0.55, 0.55, 0.6)
	keyHint:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -144)

	-- Izquierda: opciones por categorías (lista con scroll)
	Section(left, "Opciones de la rueda", -162)
	local order = Text(left, 10, 0.55, 0.55, 0.6, "1ª arriba, luego en sentido horario")
	order:SetJustifyH("RIGHT")
	order:SetPoint("TOPRIGHT", left, "TOPRIGHT", 0, -164)
	local cats = { { nil, "Todo" } }
	for _, c in ipairs(ns.Categories) do cats[#cats + 1] = { c.id, c.name } end
	for i, c in ipairs(cats) do
		local ft = Flat(left, 74, 20, c[2])
		ft.cat = c[1]
		ft:SetPoint("TOPLEFT", left, "TOPLEFT", (i - 1) * 78, -186)
		ft:SetScript("OnClick", function() filter, offset = ft.cat, 0; Refresh() end)
		filterTabs[i] = ft
	end
	for r = 1, POOL do MakeRow(r) end
	track = left:CreateTexture(nil, "ARTWORK")
	track:SetTexture(WHITE); track:SetVertexColor(1, 1, 1, 0.08)
	track:SetWidth(4)
	track:SetPoint("TOPRIGHT", left, "TOPRIGHT", -2, LIST_TOP)
	thumb = left:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture(WHITE); thumb:SetVertexColor(1, 1, 1, 0.35)
	thumb:SetWidth(4)
	local addEmote = Flat(left, 90, 24, "+ Emote")
	addEmote:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 0, 0)
	addEmote:SetScript("OnClick", OpenPicker)
	local addCmd = Flat(left, 100, 24, "+ Comando")
	addCmd:SetPoint("LEFT", addEmote, "RIGHT", 6, 0)
	addCmd:SetScript("OnClick", function() OpenEditor(nil) end)
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

	Text(right, 12, 0.9, 0.9, 0.9, "Idioma"):SetPoint("TOPLEFT", right, "TOPLEFT", 4, -344)
	for i, opt in ipairs({ { "auto", "Automático" }, { "es", "Español" }, { "en", "English" } }) do
		local b = Flat(right, 72, 22, opt[2])
		b:SetPoint("TOPLEFT", right, "TOPLEFT", 64 + (i - 1) * 76, -340)
		b.lang = opt[1]
		b:SetScript("OnClick", function()
			ns.db.lang = opt[1] ~= "auto" and opt[1] or nil
			ns.SetLanguage(ns.db.lang)
			for _, fs in ipairs(texts) do fs:SetText(L(fs.lkey)) end
			Refresh()
		end)
		langButtons[i] = b
	end

	local reset = Flat(right, 230, 26, "Restaurar valores por defecto")
	reset:SetPoint("BOTTOM", right, "BOTTOM", 0, 0)
	reset:SetScript("OnClick", function() ns.ResetDB(); Refresh() end)
	local resetHint = Text(right, 10, 0.55, 0.55, 0.6, "Aspecto y opciones de la rueda actual.\nTus ruedas y entradas propias se conservan.")
	resetHint:SetPoint("BOTTOMLEFT", reset, "TOPLEFT", 0, 6)
end

function Config.Toggle()
	if InCombatLockdown() then ns.Print(L("la configuración no se puede abrir en combate.")); return end
	if not frame then
		local ok, err = pcall(Build)
		if not ok then -- si falla, que se vea el motivo y no quede una ventana a medias
			ns.Print(L("error al crear la ventana: %s", tostring(err)))
			if frame then frame:Hide(); frame = nil end
			return
		end
	end
	if frame:IsShown() then frame:Hide() else frame:Show() end
end

----------------------------------------------------------------------------------------------------
-- Panel de Interface Options / Settings: un acceso directo a la ventana
----------------------------------------------------------------------------------------------------
local panel = CreateFrame("Frame")
panel.name = "RadialHub"
Text(panel, 16, 1, 0.82, 0.2, "RadialHub"):SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
Text(panel, 12, 0.9, 0.9, 0.9, "Rueda radial rápida. También con /rh."):SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -44)
local open = Flat(panel, 200, 26, "Abrir configuración")
open:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -72)
-- Sin HideUIPanel: cerrar paneles de Blizzard desde un addon contamina su gestor de paneles.
-- La ventana usa la capa DIALOG, así que se ve por encima de Opciones.
open:SetScript("OnClick", function()
	if not (frame and frame:IsShown()) then Config.Toggle() end
end)
if Settings and Settings.RegisterCanvasLayoutCategory then
	Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
else
	InterfaceOptions_AddCategory(panel)
end
