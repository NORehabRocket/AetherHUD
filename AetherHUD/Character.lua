-- AetherHUD character window (C): Aion's profile. Your worn gear in two columns and a
-- weapon row around a large portrait, four headline numbers under it, and every number
-- of the run (AZS_STATS) on the right, with what your gear adds in green. Drag items on
-- and off the sockets as on the stock pane; the other character tabs stay stock.

local A = AetherHUD
local C, D = A.C, A.D

local W, H = 560, 430
local SLOT, GAP = 36, 7
local STATS_W = 196

local LEFT = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" }
local RIGHT = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" }
local BOTTOM = { "MainHandSlot", "SecondaryHandSlot", "RangedSlot" }

local function pct(v)
	return string.format("%+.0f%%", (v or 0) * 100)
end

-- { label, value(s), gear key, gear format, only when non-zero }
local SECTIONS = {
	{ "Offense", {
		{ "Damage", function(s) return pct(s.dmg - 1) end, "gdmg", pct },
		{ "Haste", function(s) return pct(1 - s.cd) end, "gcd", pct },
		{ "Crit", function(s) return string.format("%.1f%%", s.crit * 100) end, "gcrit", pct },
		{ "Crit damage", function(s) return string.format("%.0f%%", s.cm * 100) end, "gcm", pct },
		{ "Echo", function(s) return string.format("%.0f%%", s.echo * 100) end, "gecho", pct },
		{ "Area", function(s) return pct(s.area - 1) end, "garea", pct },
		{ "Targets", function(s) return string.format("+%d", s.cnt) end, "gcnt", function(v) return string.format("+%d", v) end },
		{ "DoT stacks", function(s) return tostring(s.dots or 0) end },
		{ "DoT haste", function(s) return pct(s.doth) end },
		{ "Buff power", function(s) return pct(s.bp) end },
		{ "Vs elites", function(s) return pct(s.big) end, nil, nil, "big" },
		{ "Execute", function(s) return pct(s.exe) end, nil, nil, "exe" },
		{ "Vs controlled", function(s) return pct(s.cc) end, nil, nil, "cc" },
		{ "Vs afflicted", function(s) return pct(s.dotd) end, nil, nil, "dotd" },
		{ "Shielded", function(s) return pct(s.shd) end, nil, nil, "shd" },
		{ "Melee", function(s) return pct(s.auto) end, nil, nil, "auto" },
		{ "Pet damage", function(s) return pct(s.pet) end, nil, nil, "pet" },
	} },
	{ "Defense", {
		{ "Health", function(s) return A.Comma(s.hp) end, "ghp", function(v) return "+" .. A.Comma(v) end },
		{ "Armor", function(s) return string.format("%.0f%%", s.arm * 100) end, "garm", pct },
		{ "Regen", function(s) return string.format("%.1f/s", s.reg) end, "greg", function(v) return string.format("+%.1f", v) end },
		{ "Lifesteal", function(s) return string.format("%.1f%%", s.lch * 100) end },
		{ "Kill heal", function(s) return string.format("%.0f", s.heal) end },
		{ "Thorns", function(s) return string.format("%.0f%%", s.thn * 100) end },
		{ "Lives", function(s) return string.format("%d", s.liv) end },
	} },
	{ "Utility", {
		{ "Speed", function(s) return pct(s.spd - 1) end, "gspd", pct },
		{ "Pickup", function(s) return string.format("%.0f yd", s.pick) end, "gpick", pct },
		{ "Experience", function(s) return pct(s.xp - 1) end },
		{ "Gold", function(s) return pct(s.gold - 1) end, "ggold", pct },
		{ "Luck", function(s) return pct(s.luck) end },
	} },
}

local f, portrait, nameText, subText, levelText
local statsCol -- the stats sit on their own glass column, so their text is drawn on it
local slots = {}
local tiles = {}
local rows = {}
local heads = {}

------------------------------------------------------------------------
-- Gear sockets
------------------------------------------------------------------------

local function SlotClick()
	local id = this.inv
	if arg1 == "LeftButton" and IsShiftKeyDown() and A.InsertLink(GetInventoryItemLink("player", id)) then
		return
	end
	if arg1 == "RightButton" then
		UseInventoryItem(id)
	else
		PickupInventoryItem(id)
	end
end

local function MakeSlot(slotName)
	local id, empty = GetInventorySlotInfo(slotName)
	local s = A.Socket(f, SLOT, { frame = "slot" })
	local b = s.frame
	b.inv, b.empty, b.slotName = id, empty, slotName
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnClick", SlotClick)
	b:SetScript("OnDragStart", function()
		PickupInventoryItem(this.inv)
	end)
	b:SetScript("OnReceiveDrag", function()
		PickupInventoryItem(this.inv)
	end)
	b:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		if not GameTooltip:SetInventoryItem("player", this.inv) then
			local label = getglobal(string.upper(this.slotName)) -- e.g. HEADSLOT = "Head"
			GameTooltip:SetText(type(label) == "string" and label or this.slotName, 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	slots[slotName] = s
	return s
end

local function UpdateSlots()
	for _, s in pairs(slots) do
		local id = s.frame.inv
		local tex = GetInventoryItemTexture("player", id)
		if tex then
			s:SetIcon(tex)
			A.SetAlpha(s.icon, 1)
			local c = A.LinkColor(GetInventoryItemLink("player", id)) or C.steel
			A.SetColor(s.rim, c[1], c[2], c[3], 1)
		else
			s:SetIcon(s.frame.empty)
			A.SetAlpha(s.icon, 0.25)
			A.SetColor(s.rim, C.steel[1] * 0.6, C.steel[2] * 0.6, C.steel[3] * 0.6, 1)
		end
		local start, duration = 0, 0
		if GetInventoryItemCooldown then
			start, duration = GetInventoryItemCooldown("player", id)
		end
		if start and start > 0 and duration and duration > 1.5 then
			s:SetCooldown(start + duration - GetTime(), duration)
		else
			s:SetCooldown(0)
		end
	end
end

------------------------------------------------------------------------
-- Stats
------------------------------------------------------------------------

local function StatRow(i)
	local r = rows[i]
	if r then
		return r
	end
	r = {}
	r.label = A.Text(statsCol, 10)
	r.label:SetTextColor(C.steel[1], C.steel[2], C.steel[3])
	r.value = A.Text(statsCol, 10)
	r.gear = A.Text(statsCol, 9)
	r.gear:SetTextColor(C.good[1], C.good[2], C.good[3])
	rows[i] = r
	return r
end

local function Head(i)
	local h = heads[i]
	if h then
		return h
	end
	h = {}
	h.text = A.Text(statsCol, 10, true)
	h.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	h.rule = A.Tex(statsCol, "ARTWORK", A.MEDIA .. "line")
	h.rule:SetHeight(3)
	h.rule:SetWidth(STATS_W)
	h.rule:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.5)
	heads[i] = h
	return h
end

local function UpdateStats()
	local s = D.Stats()
	local x = W - STATS_W - 14
	local y = -38
	local n = 0
	if not s.hp then
		local h = Head(1)
		h.text:ClearAllPoints()
		h.text:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
		A.SetText(h.text, "STATS")
		A.Show(h.text, true)
		A.Show(h.rule, false)
		n = n + 1
		local r = StatRow(1)
		r.label:ClearAllPoints()
		r.label:SetPoint("TOPLEFT", f, "TOPLEFT", x, y - 18)
		A.SetText(r.label, "Your run's numbers show here once a run starts.")
		A.SetText(r.value, "")
		A.SetText(r.gear, "")
		A.Show(r.label, true)
		for i = 2, table.getn(rows) do
			A.Show(rows[i].label, false)
			A.Show(rows[i].value, false)
			A.Show(rows[i].gear, false)
		end
		for i = 2, table.getn(heads) do
			A.Show(heads[i].text, false)
			A.Show(heads[i].rule, false)
		end
		return
	end
	local ri = 0
	for si = 1, table.getn(SECTIONS) do
		local sec = SECTIONS[si]
		local h = Head(si)
		h.text:ClearAllPoints()
		h.text:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
		A.SetText(h.text, A.Spaced(sec[1]))
		h.rule:ClearAllPoints()
		h.rule:SetPoint("TOPLEFT", f, "TOPLEFT", x - 4, y - 13)
		A.Show(h.text, true)
		A.Show(h.rule, true)
		y = y - 18
		local list = sec[2]
		for k = 1, table.getn(list) do
			local def = list[k]
			local only = def[5]
			if not only or A.N(s[only]) ~= 0 then
				ri = ri + 1
				local r = StatRow(ri)
				r.label:ClearAllPoints()
				r.label:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
				A.SetText(r.label, def[1])
				local ok, v = pcall(def[2], s)
				r.value:ClearAllPoints()
				r.value:SetPoint("TOPRIGHT", f, "TOPLEFT", x + STATS_W - 44, y)
				A.SetText(r.value, ok and v or "-")
				local g = def[3] and A.N(s[def[3]]) or 0
				r.gear:ClearAllPoints()
				r.gear:SetPoint("TOPRIGHT", f, "TOPLEFT", x + STATS_W, y - 1)
				A.SetText(r.gear, g ~= 0 and def[4](g) or "")
				A.Show(r.label, true)
				A.Show(r.value, true)
				A.Show(r.gear, true)
				y = y - 13
			end
		end
		y = y - 6
	end
	for i = ri + 1, table.getn(rows) do
		A.Show(rows[i].label, false)
		A.Show(rows[i].value, false)
		A.Show(rows[i].gear, false)
	end
end

local TILES = {
	{ "HEALTH", function(s) return A.Comma(s.hp) end },
	{ "DAMAGE", function(s) return pct(s.dmg - 1) end },
	{ "HASTE", function(s) return pct(1 - s.cd) end },
	{ "CRIT", function(s) return string.format("%.1f%%", s.crit * 100) end },
}

local function UpdateHeader()
	local zone, run = D.Zone(), D.Run()
	A.SetText(nameText, zone.hero or UnitName("player") or "")
	local lvl = A.N(run.lvl)
	if lvl <= 0 then
		lvl = UnitLevel("player") or 1
	end
	A.SetText(levelText, tostring(lvl))
	local cls = zone.cname or UnitClass("player") or ""
	local race = zone.rname or UnitRace("player") or ""
	local token = zone.class
	if not token then
		local _, t = UnitClass("player")
		token = t and string.lower(t)
	end
	local cc = A.CLASS[token or ""] or C.steel
	A.SetText(subText, A.Hex(C.muted) .. "Level " .. lvl .. "  |r" .. race .. "  " .. A.Hex(cc) .. cls .. "|r")
	local s = D.Stats()
	for i = 1, table.getn(TILES) do
		local ok, v = false, nil
		if s.hp then
			ok, v = pcall(TILES[i][2], s)
		end
		A.SetText(tiles[i].value, ok and v or "-")
	end
end

local function Refresh()
	if not f or not f:IsShown() then
		return
	end
	UpdateHeader()
	UpdateSlots()
	UpdateStats()
end

------------------------------------------------------------------------

local function Init()
	if not A.On("character") then
		return
	end
	f = A.Window("character", "AetherHUDCharacter", "Character", W, H, function(fr)
		fr:SetPoint("CENTER", A.root, "CENTER", -120, 30)
	end)

	-- gear: two columns either side of the portrait, weapons beneath it
	local colTop = -40
	for i = 1, table.getn(LEFT) do
		MakeSlot(LEFT[i]).frame:SetPoint("TOPLEFT", f, "TOPLEFT", 14, colTop - (i - 1) * (SLOT + GAP))
	end
	local rightX = W - STATS_W - 28 - SLOT
	for i = 1, table.getn(RIGHT) do
		MakeSlot(RIGHT[i]).frame:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, colTop - (i - 1) * (SLOT + GAP))
	end
	local centerX = (14 + SLOT + rightX) / 2
	for i = 1, table.getn(BOTTOM) do
		MakeSlot(BOTTOM[i]).frame:SetPoint("BOTTOM", f, "BOTTOMLEFT", centerX + (i - 2) * (SLOT + 10), 16)
	end

	-- portrait in its bezel, level gem, name and line
	local pf = CreateFrame("Frame", nil, f)
	pf:SetWidth(120)
	pf:SetHeight(120)
	pf:SetPoint("TOP", f, "TOPLEFT", centerX, -42)
	local disc = A.Tex(pf, "BACKGROUND", A.MEDIA .. "glow")
	disc:SetAllPoints(pf)
	disc:SetVertexColor(0, 0, 0, 0.9)
	portrait = pf:CreateTexture(nil, "BORDER")
	portrait:SetWidth(100)
	portrait:SetHeight(100)
	portrait:SetPoint("CENTER", pf, "CENTER", 0, 0)
	local ring = A.Tex(pf, "ARTWORK", A.MEDIA .. "ring")
	ring:SetAllPoints(pf)
	ring:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
	local halo = A.Tex(pf, "OVERLAY", A.MEDIA .. "glow")
	halo:SetBlendMode("ADD")
	halo:SetWidth(60)
	halo:SetHeight(22)
	halo:SetPoint("TOP", pf, "TOP", 0, -2)
	halo:SetVertexColor(C.aether[1], C.aether[2], C.aether[3], 0.35)
	local gem = A.Diamond(pf, 30, C.gold, "OVERLAY")
	gem:SetPoint("CENTER", pf, "BOTTOM", 0, 6)
	levelText = A.Text(pf, 12)
	A.Font(levelText, 12, false, "")
	levelText:SetPoint("CENTER", gem, "CENTER", 0, 0)
	levelText:SetTextColor(0.12, 0.08, 0.02)
	levelText:SetShadowOffset(0, 0)

	nameText = A.Text(f, 16, true)
	nameText:SetPoint("TOP", pf, "BOTTOM", 0, -16)
	nameText:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	subText = A.Text(f, 10)
	subText:SetPoint("TOP", nameText, "BOTTOM", 0, -4)

	-- four headline numbers
	local tileW, tileH = 86, 34
	for i = 1, table.getn(TILES) do
		local col = math.mod(i - 1, 2)
		local row = math.floor((i - 1) / 2)
		local t = A.Panel(nil, f, tileW, tileH, { bracket = 4, noGlint = true, alpha = 0.6 })
		t:SetPoint("TOPLEFT", f, "TOPLEFT", centerX - tileW - 3 + col * (tileW + 6), -228 - row * (tileH + 6))
		local label = A.Text(t, 8, true)
		label:SetPoint("TOP", t, "TOP", 0, -5)
		label:SetText(TILES[i][1])
		label:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
		local value = A.Text(t, 13)
		value:SetPoint("BOTTOM", t, "BOTTOM", 0, 5)
		tiles[i] = { frame = t, value = value }
	end

	-- the stats column's glass
	statsCol = A.Panel(nil, f, STATS_W + 16, H - 44, { bracket = 5, noGlint = true, alpha = 0.45 })
	statsCol:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -32)

	f.OnOpen = function()
		SetPortraitTexture(portrait, "player")
		Refresh()
	end

	-- C and the stock character calls open this window; other tabs stay stock
	local stockToggle = ToggleCharacter
	ToggleCharacter = function(tab)
		if tab == nil or tab == "PaperDollFrame" then
			if CharacterFrame and CharacterFrame:IsShown() then
				HideUIPanel(CharacterFrame)
			end
			A.ToggleWindow(f)
		elseif stockToggle then
			stockToggle(tab)
		end
	end

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "UNIT_INVENTORY_CHANGED", "PLAYER_ENTERING_WORLD", "UNIT_PORTRAIT_UPDATE",
		"ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "CHAT_MSG_ADDON" }) do
		ev:RegisterEvent(e)
	end
	ev:SetScript("OnEvent", function()
		if event == "CHAT_MSG_ADDON" and arg1 ~= "AZS" and arg1 ~= "AZSRUN" then
			return
		end
		if event == "UNIT_PORTRAIT_UPDATE" and arg1 == "player" and f:IsShown() then
			SetPortraitTexture(portrait, "player")
		end
		Refresh()
	end)
end

A.OnInit(Init)
