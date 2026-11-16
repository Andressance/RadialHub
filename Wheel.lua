-- RadialHub · Wheel: geometría polar, modal en el cursor, animación (lerp en OnUpdate) y ejecución al soltar.
-- Círculos nítidos con máscara redonda (ns.Circle): iconos, aros y fondos son discos (WHITE8X8 teñido o icono).
local addonName, ns = ...
local Wheel = {}
ns.Wheel = Wheel

local sqrt, cos, sin, atan2, floor, min, max, abs, pi = math.sqrt, math.cos, math.sin, math.atan2, math.floor, math.min, math.max, math.abs, math.pi
local TWO_PI = pi * 2
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local SOUND_TICK = SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115               -- al cambiar de opción
local SOUND_PICK = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856      -- al activar una
local DOTS = 18         -- discos solapados que forman el rayo hacia la opción apuntada
local OPEN_TIME = 0.12  -- segundos de la animación de apertura

-- Ángulo (radianes, convención matemática) del hueco i de n: el 1 arriba y el resto en sentido horario.
local function SlotAngle(i, n) return pi / 2 - (i - 1) * TWO_PI / n end

-- Hueco apuntado por el desplazamiento (dx, dy) desde el centro; nil dentro de la zona muerta.
function Wheel.SliceAt(dx, dy, n, dead)
	if n < 1 or dx * dx + dy * dy < dead * dead then return nil end
	local a = (pi / 2 - atan2(dy, dx)) % TWO_PI -- ángulo en sentido horario desde arriba
	return floor(a / (TWO_PI / n) + 0.5) % n + 1
end

local function Lerp(a, b, t) return a + (b - a) * t end

local frame, bg, coreRing, coreDisc, label, title, dots, slots, arrows
local active, selected = false, nil -- rueda abierta (tecla mantenida) / hueco apuntado
local list, db = {}, nil
local profileIdx, multi = 1, false  -- rueda mostrada y si hay otras ruedas a las que cambiar
local inputProfile = 1              -- rueda cuyo botón seguro recibió el atajo mantenido
local arrowX, hoverArrow = 0, nil   -- distancia horizontal de las flechas y la que está bajo el cursor
local ox, oy = 0, 0                -- centro de la rueda en coordenadas de UIParent
local R, S, dead = 0, 0, 0         -- radio, tamaño de icono, zona muerta (ya acotados)
local ar, ag, ab = 1, 1, 1         -- color de acento
local openT, ia, indA = 0, 0, 0    -- progreso de apertura, ángulo e intensidad del indicador
local armed, wasClick = false, false -- failsafe de tecla soltada / clic izquierdo previo
local heldKeys = {}                -- teclas físicas del atajo (sin modificadores) para saber si sigue pulsado
local secureCharacterSelected = false
local slotCos, slotSin = {}, {}    -- dirección de cada hueco (se calcula en Layout, no en cada fotograma)
local dirty = true                 -- hay algo que animar o redibujar; si no, OnUpdate solo mira el cursor

local MOUSE = { BUTTON1 = "LeftButton", BUTTON2 = "RightButton", BUTTON3 = "MiddleButton", BUTTON4 = "Button4", BUTTON5 = "Button5" }

-- ¿Sigue pulsada alguna tecla del atajo? nil si este cliente no puede saberlo.
local function KeyHeld()
	if #heldKeys == 0 then return nil end
	for _, k in ipairs(heldKeys) do
		if MOUSE[k] then
			if IsMouseButtonDown(MOUSE[k]) then return true end
		elseif IsKeyDown(k) then
			return true
		end
	end
	return false
end

local function Disc(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer)
	ns.Circle(t)
	t:SetVertexColor(r, g, b, a or 1)
	return t
end

local function SizeDisc(t, d) t:SetWidth(d); t:SetHeight(d) end

local function OnUpdate(_, dt)
	dt = min(dt, 0.05)
	if IsMouseButtonDown("RightButton") then Wheel.Cancel() return end

	-- Failsafe: si el cliente no entrega el "up" (p. ej. se soltó ALT antes que la tecla), lo detectamos aquí.
	-- Solo se arma tras ver la tecla pulsada, así que si IsKeyDown no sirve no molesta.
	local held = KeyHeld()
	if held then armed = true elseif held == false and armed then Wheel.Release() return end

	-- Cursor relativo al centro de la rueda y flecha de cambio de rueda bajo él (si hay otras ruedas).
	local cx, cy = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	local dx, dy = cx / scale - ox, cy / scale - oy
	local prevHover = hoverArrow
	hoverArrow = nil
	if multi then
		for _, a in ipairs(arrows) do
			local ax = a.dir * arrowX
			if (dx - ax) ^ 2 + dy ^ 2 <= 18 * 18 then hoverArrow = a end
		end
	end

	-- Clic izquierdo: cambia de rueda sobre una flecha; si no, confirma la opción apuntada (o cancela en el centro).
	local click = IsMouseButtonDown("LeftButton")
	if click and not wasClick then
		if hoverArrow then
			wasClick = true
			Wheel.Switch(hoverArrow.dir)
		elseif selected then
			Wheel.Release()
		else
			Wheel.Cancel()
		end
		return
	end
	wasClick = click

	local anim, n = db.anim, #list
	if hoverArrow ~= prevHover then dirty = true end

	-- Selección
	local idx = not hoverArrow and Wheel.SliceAt(dx, dy, n, dead) or nil
	local secureCharacter = idx and list[idx].id == "character" or false
	if secureCharacter ~= secureCharacterSelected then
		secureCharacterSelected = secureCharacter
		ns.SetSecureCharacterAction(inputProfile, secureCharacter)
	end
	if idx ~= selected then
		selected = idx
		dirty = true
		if idx then
			if db.sound then PlaySound(SOUND_TICK) end
			label:SetText(list[idx].name)
			label:SetTextColor(1, 1, 1)
		else
			label:SetText("Cancelar")
			label:SetTextColor(0.5, 0.5, 0.55)
		end
	end

	-- Rendimiento: con la rueda quieta (sin animación pendiente) no se toca ninguna textura.
	if not dirty then return end
	local settled = true
	openT = anim and min(1, openT + dt / OPEN_TIME) or 1
	if openT < 1 then settled = false end
	local e = 1 - (1 - openT) ^ 3 -- ease-out
	frame:SetAlpha(e)

	-- Iconos: el apuntado crece, se tiñe de acento y brilla.
	local k = min(1, dt * 16)
	local r = R * (0.55 + 0.45 * e)
	for i = 1, n do
		local b = slots[i]
		local target = (i == selected) and 1 or 0
		local h = anim and Lerp(b.h, target, k) or target
		if abs(target - h) < 0.005 then h = target end
		if h ~= target then settled = false end
		b.h = h
		local sc = 1 + 0.25 * h
		b:SetScale(sc)
		b:SetPoint("CENTER", frame, "CENTER", slotCos[i] * r / sc, slotSin[i] * r / sc)
		b.ring:SetVertexColor(Lerp(0.32, ar, h), Lerp(0.32, ag, h), Lerp(0.36, ab, h), 0.9 + 0.1 * h)
		local v = Lerp(0.65, 1, h)
		b.icon:SetVertexColor(v, v, v)
		b.glow:SetVertexColor(ar, ag, ab, 0.3 * h)
	end

	-- Indicador direccional: puntos desde la zona muerta hacia el hueco activo (giro por el arco corto).
	if selected then
		local ta = SlotAngle(selected, n)
		if indA < 0.02 or not anim then
			ia = ta
		else
			local d = (ta - ia + pi) % TWO_PI - pi
			if abs(d) < 0.002 then ia = ta else ia = ia + d * min(1, dt * 14); settled = false end
		end
	end
	local indT = selected and 1 or 0
	indA = anim and Lerp(indA, indT, min(1, dt * 14)) or indT
	if abs(indT - indA) < 0.005 then indA = indT else settled = false end
	local r0 = dead + 4
	local r1 = max(r0 + 12, R * e - S * 0.625 - 2)
	for j = 1, DOTS do
		local f = (j - 0.5) / DOTS
		local d = dots[j]
		local rr = Lerp(r0, r1, f)
		d:SetPoint("CENTER", frame, "CENTER", cos(ia) * rr, sin(ia) * rr)
		d:SetVertexColor(ar, ag, ab, indA * 0.9 * f * f) -- se apaga hacia el centro
	end
	coreRing:SetVertexColor(ar, ag, ab, 0.55 + 0.45 * indA) -- el aro central se enciende al apuntar
	if multi then
		for _, a in ipairs(arrows) do
			local hot = (a == hoverArrow)
			a.ring:SetVertexColor(hot and ar or 0.32, hot and ag or 0.32, hot and ab or 0.36, hot and 1 or 0.9)
			a.text:SetTextColor(hot and 1 or 0.7, hot and 1 or 0.7, hot and 1 or 0.7)
		end
	end
	dirty = not settled
end

local function EnsureSlots(n)
	while #slots < n do
		local b = CreateFrame("Frame", nil, frame)
		b.h = 0
		b.ring = Disc(b, "BACKGROUND", 1, 1, 1, 1)
		b.dark = Disc(b, "BORDER", 0.05, 0.05, 0.07, 0.95)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.glow = Disc(b, "OVERLAY", 1, 1, 1, 0)
		b.glow:SetBlendMode("ADD")
		for _, t in ipairs({ b.ring, b.dark, b.icon, b.glow }) do t:SetPoint("CENTER", b, "CENTER", 0, 0) end
		slots[#slots + 1] = b
	end
end

local function Build()
	if frame then return end
	frame = CreateFrame("Frame", "RadialHubFrame", UIParent)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetWidth(1); frame:SetHeight(1) -- solo ancla: todo lo demás se centra en él
	frame:Hide()
	tinsert(UISpecialFrames, "RadialHubFrame") -- Escape cierra (y OnHide cancela)

	bg       = Disc(frame, "BACKGROUND", 0, 0, 0, 1)
	coreRing = Disc(frame, "BORDER", 1, 1, 1, 1)
	coreDisc = Disc(frame, "ARTWORK", 0.04, 0.04, 0.06, 0.96)
	for _, t in ipairs({ bg, coreRing, coreDisc }) do t:SetPoint("CENTER", frame, "CENTER", 0, 0) end

	label = frame:CreateFontString(nil, "OVERLAY")
	label:SetFont(FONT, 13, "OUTLINE")
	label:SetWordWrap(true)
	label:SetJustifyH("CENTER")
	label:SetPoint("CENTER", frame, "CENTER", 0, 0)

	local dotFrame = CreateFrame("Frame", nil, frame)
	dots = {}
	for j = 1, DOTS do
		dots[j] = Disc(dotFrame, "ARTWORK", 1, 1, 1, 0)
		dots[j]:SetBlendMode("ADD")
		SizeDisc(dots[j], 3 + 7 * (j - 0.5) / DOTS) -- rayo que se ensancha hacia la opción
	end

	slots = {} -- se crean al abrir, según las opciones de la rueda (EnsureSlots)

	-- Flechas para cambiar de rueda sin cerrar (clic o rueda del ratón) y nombre de la rueda actual.
	arrows = {}
	for _, dir in ipairs({ -1, 1 }) do
		local a = { dir = dir }
		a.ring = Disc(frame, "BORDER", 1, 1, 1, 1)
		a.dark = Disc(frame, "ARTWORK", 0.05, 0.05, 0.07, 0.95)
		a.text = frame:CreateFontString(nil, "OVERLAY")
		a.text:SetFont(FONT, 16, "OUTLINE")
		a.text:SetText(dir < 0 and "<" or ">")
		arrows[#arrows + 1] = a
	end
	title = frame:CreateFontString(nil, "OVERLAY")
	title:SetFont(FONT, 11, "OUTLINE")

	-- Captura el ratón mientras la rueda está abierta: el clic no atraviesa al mundo y la rueda del ratón cambia de rueda.
	local catcher = CreateFrame("Frame", nil, frame)
	catcher:SetAllPoints(UIParent)
	catcher:EnableMouse(true)
	catcher:EnableMouseWheel(true)
	catcher:SetScript("OnMouseWheel", function(_, delta) Wheel.Switch(delta > 0 and -1 or 1) end)

	frame:SetScript("OnUpdate", OnUpdate)
	frame:SetScript("OnHide", function() active, selected = false, nil end)
	frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- entrar en combate cancela la rueda abierta
	frame:SetScript("OnEvent", function() Wheel.Cancel() end)
end

-- Dimensiones y contenido de la rueda `profile` (ya validada: existe y tiene opciones).
local function Layout(profile)
	list = ns.GetActive(profile)
	profileIdx = profile
	EnsureSlots(#list)

	S = db.iconSize
	R = db.radius
	dead = max(10, min(db.deadzone, R - S * 0.65 - 10)) -- siempre queda sitio para el indicador
	ar, ag, ab = db.accent[1], db.accent[2], db.accent[3]

	local bgR = R + S * 0.625 + 10
	SizeDisc(bg, 2 * bgR)
	bg:SetVertexColor(0, 0, 0, db.bgAlpha)
	SizeDisc(coreRing, 2 * dead + 4)
	coreRing:SetVertexColor(ar, ag, ab, 0.55)
	SizeDisc(coreDisc, 2 * dead)
	label:SetWidth(max(2 * dead - 8, 60))
	label:SetText("Cancelar")
	label:SetTextColor(0.5, 0.5, 0.55)

	for i = 1, #list do
		local a = SlotAngle(i, #list)
		slotCos[i], slotSin[i] = cos(a), sin(a)
	end
	dirty = true
	for i, b in ipairs(slots) do
		local entry = list[i]
		if entry then
			b:SetWidth(S); b:SetHeight(S)
			SizeDisc(b.ring, S); SizeDisc(b.dark, S - 4); SizeDisc(b.icon, S - 8); SizeDisc(b.glow, S - 4)
			if b.entry ~= entry then ns.Circle(b.icon, ns.IconPath(entry.icon)); b.entry = entry end
			b.h = 0
			b:Show()
		else
			b:Hide()
		end
	end

	-- flechas y título solo si hay otra rueda con opciones a la que cambiar
	multi = false
	for i = 1, ns.MAX_PROFILES do
		local others = i ~= profile and ns.GetActive(i)
		if others and #others > 0 then multi = true end
	end
	arrowX = bgR + 22
	for _, a in ipairs(arrows) do
		if multi then
			SizeDisc(a.ring, 32); SizeDisc(a.dark, 28)
			a.ring:ClearAllPoints(); a.dark:ClearAllPoints(); a.text:ClearAllPoints()
			a.ring:SetPoint("CENTER", frame, "CENTER", a.dir * arrowX, 0)
			a.dark:SetPoint("CENTER", frame, "CENTER", a.dir * arrowX, 0)
			a.text:SetPoint("CENTER", frame, "CENTER", a.dir * arrowX, 1)
			a.ring:Show(); a.dark:Show(); a.text:Show()
		else
			a.ring:Hide(); a.dark:Hide(); a.text:Hide()
		end
	end
	if multi then
		local name = ns.db.profiles[profile].name
		title:ClearAllPoints()
		title:SetPoint("CENTER", frame, "CENTER", 0, bgR + 12)
		title:SetText(name ~= "" and name or ("Rueda " .. profile))
		title:SetTextColor(ar, ag, ab)
		title:Show()
	else
		title:Hide()
	end
	selected, indA = nil, 0
end

-- Tecla pulsada: coloca la rueda centrada en el cursor.
function Wheel.Open(profile)
	if active then return end
	profile = profile or 1
	db = ns.db
	local entries = ns.GetActive(profile)
	if not entries then ns.Print("la rueda " .. profile .. " no existe. Créala en /rh."); return end
	if #entries == 0 then ns.Print("la rueda " .. profile .. " no tiene opciones activas. Usa /rh para activarlas."); return end
	inputProfile = profile
	secureCharacterSelected = false
	ns.SetSecureCharacterAction(inputProfile, false)
	Build()
	Layout(profile)

	local cx, cy = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	ox, oy = cx / scale, cy / scale
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ox, oy)
	frame:SetAlpha(0)
	heldKeys = {}
	for _, key in ipairs({ GetBindingKey(ns.BINDINGS[profile]) }) do
		local base = key:match("[^-]+$") -- quita ALT-/CTRL-/SHIFT-
		if base and base ~= "" and (MOUSE[base] or IsKeyDown) then heldKeys[#heldKeys + 1] = base end
	end
	armed, wasClick = false, IsMouseButtonDown("LeftButton")
	openT, active = db.anim and 0 or 1, true
	frame:Show()
end

-- Cambia a la siguiente (dir = 1) o anterior (dir = -1) rueda con opciones, sin cerrar ni mover la rueda.
function Wheel.Switch(dir)
	if not active or not multi then return end
	for step = 1, ns.MAX_PROFILES - 1 do
		local j = (profileIdx - 1 + dir * step) % ns.MAX_PROFILES + 1
		local entries = ns.GetActive(j)
		if entries and #entries > 0 then
			secureCharacterSelected = false
			ns.SetSecureCharacterAction(inputProfile, false)
			Layout(j)
			openT = db.anim and 0.4 or 1 -- pequeño "florecimiento" al cambiar
			if db.sound then PlaySound(SOUND_TICK) end
			return
		end
	end
end

-- Tecla soltada: abre la opción apuntada (si la hay) y cierra la rueda.
function Wheel.Release()
	if not active then return end
	local entry = selected and list[selected]
	if ns.debug then ns.Print("soltar: " .. (entry and entry.name or "nada seleccionado")) end
	frame:Hide()
	if entry then
		if db.sound then PlaySound(SOUND_PICK) end
		if entry.id == "character" then return end -- solo se abre por el clic seguro; nunca llamar ToggleCharacter desde Lua
		-- un instante después: algunos paneles (bolsas con Bagnon) no se abren si se llama justo al soltar la tecla
		if C_Timer and C_Timer.After then C_Timer.After(0.05, function() ns.Run(entry) end) else ns.Run(entry) end
	end
end

function Wheel.Cancel()
	secureCharacterSelected = false
	ns.SetSecureCharacterAction(inputProfile, false)
	if active then frame:Hide() end
end
