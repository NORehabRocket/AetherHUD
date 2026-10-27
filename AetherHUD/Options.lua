-- AetherHUD options window (/aether): modules, the game's build row, size, layout.

local A = AetherHUD
local C = A.C

local W = 420
local f
local toggles = {}
local buttons = {}
local scaleText, sizeText, rowsText, notice
local pending = false

local function PartOf(module)
	for part, mod in pairs(A.PARTS) do
		if mod == module and part ~= "build" then
			return part
		end
	end
end

-- x/w: a column of the module list; without them the toggle spans the window
local function Toggle(y, label, get, set, x, w)
	local b = CreateFrame("Button", nil, f)
	b:SetHeight(18)
	if x then
		b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
		b:SetWidth(w)
	else
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
		b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, y)
	end
	local box = A.Diamond(b, 14, { 0, 0, 0 }, "ARTWORK")
	box:SetPoint("LEFT", b, "LEFT", 0, 0)
	box:SetTexture(A.MEDIA .. "diamondo")
	box:SetVertexColor(C.steel[1], C.steel[2], C.steel[3], 1)
	local gem = A.Diamond(b, 10, C.aether, "OVERLAY")
	gem:SetPoint("CENTER", box, "CENTER", 0, 0)
	local text = A.Text(b, 11)
	text:SetPoint("LEFT", box, "RIGHT", 7, 0)
	text:SetText(label)
	local hl = A.Tex(b, "HIGHLIGHT")
	hl:SetAllPoints(b)
	hl:SetVertexColor(C.aether[1], C.aether[2], C.aether[3], 0.08)
	local t = { button = b, gem = gem, text = text, get = get }
	b:SetScript("OnClick", function()
		set(not get())
		A.RefreshOptions()
	end)
	table.insert(toggles, t)
	return t
end

local function Button(label, x, y, w, onClick)
	local b = CreateFrame("Button", nil, f)
	b:SetWidth(w)
	b:SetHeight(20)
	b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
	local bg = A.Tex(b, "BACKGROUND")
	bg:SetAllPoints(b)
	A.Gradient(bg, "VERTICAL", { 0.04, 0.10, 0.16 }, { 0.10, 0.22, 0.32 }, 1, 1)
	b.edge = A.Border(b, C.edge, 1, "BORDER")
	local hl = A.Tex(b, "HIGHLIGHT", A.MEDIA .. "glow")
	hl:SetBlendMode("ADD")
	hl:SetAllPoints(b)
	hl:SetVertexColor(C.aether[1], C.aether[2], C.aether[3], 0.35)
	b.text = A.Text(b, 10, true)
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.text:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

function A.RefreshOptions()
	if not f then
		return
	end
	for i = 1, table.getn(toggles) do
		local t = toggles[i]
		local on = t.get()
		A.Show(t.gem, on)
		A.SetTextColor(t.text, on and C.text or C.muted)
	end
	A.SetText(scaleText, math.floor(A.db.scale * 100 + 0.5) .. "%")
	A.SetText(rowsText, tostring(A.db.meter.rows))
	A.SetText(sizeText, math.floor(A.db.numbers.size * 100 + 0.5) .. "%")
	A.SetText(buttons.unlock.text, A.unlocked and "Lock frames" or "Unlock frames")
	A.SetText(buttons.demo.text, A.demo and "Demo: on" or "Demo: off")
	if pending then
		A.SetText(notice, "Reload the UI to build or remove the frames you switched.")
		A.BorderColor(buttons.reload.edge, C.gold, 1)
	else
		A.SetText(notice, "")
		A.BorderColor(buttons.reload.edge, C.edge, 1)
	end
end
A.OnOptionsChanged = A.RefreshOptions

local ROW = 18

-- A "label  [-] value [+]" line; returns the value's text.
local function Stepper(y, label, onStep)
	local l = A.Text(f, 11)
	l:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y - 3)
	l:SetText(label)
	Button("-", 150, y, 22, function()
		onStep(-1)
		A.RefreshOptions()
	end)
	local value = A.Text(f, 11)
	value:SetPoint("TOPLEFT", f, "TOPLEFT", 182, y - 3)
	Button("+", 222, y, 22, function()
		onStep(1)
		A.RefreshOptions()
	end)
	return value
end

local function Build()
	local mods = A.MODULES
	f = A.Panel("AetherHUDOptions", UIParent, W, 400, { strata = "DIALOG", alpha = 0.97, bracket = 10 })
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function()
		this:StartMoving()
	end)
	f:SetScript("OnDragStop", function()
		this:StopMovingOrSizing()
	end)
	f:SetClampedToScreen(true)
	table.insert(UISpecialFrames, "AetherHUDOptions") -- Escape closes it

	local title = A.Text(f, 15, true)
	title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
	title:SetText(A.Hex(C.aether) .. "AETHER|r" .. A.Hex(C.gold) .. "HUD|r")
	local ver = A.Text(f, 9)
	ver:SetPoint("LEFT", title, "RIGHT", 8, -1)
	ver:SetText("v" .. A.VERSION)
	ver:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	Button("X", W - 34, -10, 22, function()
		f:Hide()
	end)

	local y = -40
	local half = math.ceil(table.getn(mods) / 2)
	local colW = (W - 28) / 2
	for i = 1, table.getn(mods) do
		local m = mods[i]
		local col = i > half and 1 or 0
		local rowY = y - (i - 1 - col * half) * ROW
		Toggle(rowY, m.label, function()
			return A.db.modules[m.key]
		end, function(v)
			A.db.modules[m.key] = v
			pending = true
			A.SyncGameHud(PartOf(m.key))
		end, 14 + col * colW, colW)
	end
	y = y - half * ROW
	y = y - 8
	Toggle(y, "Also hide the game's build row (spells + jewelry)", function()
		return A.db.hideBuild
	end, function(v)
		A.db.hideBuild = v
		A.SyncGameHud("build")
	end)
	y = y - ROW
	Toggle(y, "Plates: hide normal enemies at full health", function()
		return A.db.plates.smart
	end, function(v)
		A.db.plates.smart = v
	end)
	y = y - ROW
	Toggle(y, "Numbers: damage you take", function()
		return A.db.numbers.taken
	end, function(v)
		A.db.numbers.taken = v
	end)
	y = y - ROW
	Toggle(y, "Numbers: healing you get", function()
		return A.db.numbers.heals
	end, function(v)
		A.db.numbers.heals = v
	end)

	y = y - 28
	scaleText = Stepper(y, "HUD size", function(d)
		A.db.scale = A.Clamp(A.db.scale + d * 0.05, 0.5, 2)
		A.PlaceAll()
	end)
	y = y - 26
	sizeText = Stepper(y, "Number size", function(d)
		A.db.numbers.size = A.Clamp(A.db.numbers.size + d * 0.1, 0.5, 2)
	end)
	y = y - 26
	rowsText = Stepper(y, "Meter rows", function(d)
		A.db.meter.rows = A.Clamp(A.db.meter.rows + d, 3, 20)
	end)

	y = y - 34
	buttons.unlock = Button("Unlock frames", 14, y, 140, function()
		A.Unlock()
	end)
	buttons.demo = Button("Demo: off", W - 154, y, 140, function()
		A.demo = not A.demo
		if A.demo and A.TestBanners then
			A.TestBanners()
		end
		A.RefreshOptions()
	end)
	y = y - 24
	Button("Reset layout", 14, y, 140, function()
		A.db.pos = {}
		A.db.fscale = {}
		A.db.scale = 1
		A.PlaceAll()
		A.RefreshOptions()
	end)
	buttons.reload = Button("Reload UI", W - 154, y, 140, function()
		ReloadUI()
	end)
	notice = A.Text(f, 9)
	notice:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)
	notice:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	f:SetHeight(-y + 20 + 26)
	f:Hide()
end

function A.ToggleOptions()
	if not f then
		Build()
	end
	if f:IsShown() then
		f:Hide()
	else
		A.RefreshOptions()
		f:Show()
	end
end
