-- AetherHUD combat meter: damage, healing, the last boss fight and damage taken, in one
-- Aion-style analysis window. Mouse wheel scrolls. Stands in for the game's "meter".

local A = AetherHUD
local C, D = A.C, A.D

local W, HEAD, ROW, PAD = 250, 24, 16, 6

local TABS = {
	{ key = "dmg", label = "DMG" },
	{ key = "heal", label = "HEAL" },
	{ key = "boss", label = "BOSS" },
	{ key = "taken", label = "TAKEN" },
}

local f, summary, empty
local tabs = {}
local rows = {}
local offset = 0

local function RowCount()
	return A.Clamp(A.db.meter.rows or 8, 3, 20)
end

local function Row(i)
	local r = rows[i]
	if r then
		return r
	end
	local fr = CreateFrame("Frame", nil, f)
	fr:SetHeight(ROW - 1)
	fr:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -HEAD - (i - 1) * ROW)
	fr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -HEAD - (i - 1) * ROW)
	fr:EnableMouse(true)
	fr:EnableMouseWheel(true)
	r = { frame = fr }
	r.bg = A.Tex(fr, "BACKGROUND")
	r.bg:SetAllPoints(fr)
	r.bg:SetVertexColor(0, 0, 0, 0.35)
	r.fill = A.Tex(fr, "BORDER", A.MEDIA .. "bar")
	r.fill:SetPoint("TOPLEFT", fr, "TOPLEFT", 0, 0)
	r.fill:SetPoint("BOTTOMLEFT", fr, "BOTTOMLEFT", 0, 0)
	r.rank = A.Text(fr, 9)
	r.rank:SetPoint("LEFT", fr, "LEFT", 3, 0)
	r.rank:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	r.name = A.Text(fr, 10)
	r.name:SetPoint("LEFT", fr, "LEFT", 18, 0)
	r.name:SetJustifyH("LEFT")
	r.value = A.Text(fr, 10)
	r.value:SetPoint("RIGHT", fr, "RIGHT", -3, 0)
	r.value:SetJustifyH("RIGHT")
	fr:SetScript("OnEnter", function()
		local l = this.line
		if not l then
			return
		end
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(l.name or "?", 1, 1, 1)
		GameTooltip:AddDoubleLine("Total", A.Comma(l.dmg), 0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:AddDoubleLine("Per second", string.format("%.1f", A.N(l.dps)), 0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:AddDoubleLine("Share", string.format("%.1f%%", A.N(l.share) * 100), 0.8, 0.8, 0.8, 1, 1, 1)
		if A.Flag(l.proc) then
			GameTooltip:AddLine("A talent's or amulet's own damage", C.proc[1], C.proc[2], C.proc[3])
		end
		GameTooltip:Show()
	end)
	fr:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	fr:SetScript("OnMouseWheel", function()
		offset = math.max(0, offset - arg1)
	end)
	rows[i] = r
	return r
end

local function SelectTab(key)
	A.db.meter.tab = key
	offset = 0
	for i = 1, table.getn(tabs) do
		local t = tabs[i]
		local on = t.key == key
		A.SetTextColor(t.text, on and C.gold or C.muted)
		A.Show(t.mark, on)
	end
end

local function Update()
	if not D.InRun() then
		A.Show(f, false)
		return
	end
	A.Show(f, true)
	local tab = A.db.meter.tab or "dmg"
	local lines, total, rate = D.Meter(tab)
	lines = lines or {}
	local n = table.getn(lines)
	local shown = RowCount()
	offset = A.Clamp(offset, 0, math.max(0, n - shown))
	A.SetText(summary, A.Short(total or 0) .. A.Hex(C.muted) .. "  " .. A.Short(rate or 0) .. "/s|r")
	local top = 0
	for i = 1, n do
		top = math.max(top, A.N(lines[i].dmg))
	end
	if top <= 0 then
		top = 1
	end
	local inner = W - 2 * PAD
	for i = 1, shown do
		local r = Row(i)
		local l = lines[i + offset]
		if l then
			local v = A.N(l.dmg)
			A.SetText(r.rank, tostring(i + offset))
			A.SetText(r.name, l.name or "?")
			A.SetText(r.value, A.Short(v) .. A.Hex(C.muted) .. string.format("  %.0f%%", A.N(l.share) * 100) .. "|r")
			A.SetWidth(r.fill, math.max(0.5, inner * v / top))
			if tab == "taken" then
				A.Gradient(r.fill, "HORIZONTAL", C.boss1, C.boss2, 0.75, 0.75)
			elseif tab == "heal" then
				A.Gradient(r.fill, "HORIZONTAL", C.friend1, C.friend2, 0.75, 0.75)
			elseif A.Flag(l.proc) then
				A.Gradient(r.fill, "HORIZONTAL", { 0.10, 0.20, 0.55 }, C.proc, 0.8, 0.8)
			else
				A.Gradient(r.fill, "HORIZONTAL", { 0.06, 0.28, 0.42 }, C.aether, 0.75, 0.75)
			end
			r.frame.line = l
			A.Show(r.frame, true)
		else
			r.frame.line = nil
			A.Show(r.frame, false)
		end
	end
	for i = shown + 1, table.getn(rows) do
		A.Show(rows[i].frame, false)
	end
	A.Show(empty, n == 0)
	A.SetHeight(f, HEAD + math.max(1, math.min(n, shown)) * ROW + PAD)
end

local function Init()
	if not A.On("meter") then
		return
	end
	f = A.Panel("AetherHUDMeter", A.root, W, HEAD + RowCount() * ROW + PAD)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function()
		offset = math.max(0, offset - arg1)
	end)

	local x = PAD
	for i = 1, table.getn(TABS) do
		local def = TABS[i]
		local b = CreateFrame("Button", nil, f)
		b:SetHeight(16)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", x, -4)
		local text = A.Text(b, 9, true)
		text:SetPoint("CENTER", b, "CENTER", 0, 1)
		text:SetText(def.label)
		local w = (text:GetStringWidth() or 40) + 8
		b:SetWidth(w)
		x = x + w
		local mark = A.Tex(b, "ARTWORK", A.MEDIA .. "line")
		mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, -2)
		mark:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, -2)
		mark:SetHeight(3)
		mark:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
		b.key = def.key
		b:SetScript("OnClick", function()
			SelectTab(this.key)
			Update()
		end)
		tabs[i] = { key = def.key, text = text, mark = mark }
	end
	summary = A.Text(f, 9)
	summary:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD - 1, -8)
	empty = A.Text(f, 10)
	empty:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -HEAD - 2)
	empty:SetText("Nothing yet.")
	empty:SetTextColor(C.muted[1], C.muted[2], C.muted[3])

	SelectTab(A.db.meter.tab or "dmg")
	A.RegisterMover("meter", f, "Combat meter", function(fr)
		fr:SetPoint("BOTTOMRIGHT", A.root, "BOTTOMRIGHT", -14, 16)
	end)
	A.Every(0.25, Update)
end

A.OnInit(Init)
