-- AetherHUD unit menus and inspect window.
--
-- Right-click the hero, target, party or pet frame for the game's own unit menu (whisper,
-- invite, trade, follow, inspect, raid marks, loot rules, leave party ...), the same menu
-- the stock frames open. Its Inspect, and every other way the game inspects someone, opens
-- Aion's profile of that hero: their worn gear around a portrait as on your character
-- window, their name, guild and class, each item by name in its quality colour, and for a
-- party member what they did this run (the party meter).

local A = AetherHUD
local C, D = A.C, A.D

------------------------------------------------------------------------
-- Unit menus
------------------------------------------------------------------------

local dropdown, menuUnit

-- Which stock menu a unit gets, as TargetFrameDropDown_Initialize decides it.
local function MenuWhich(unit)
	if UnitIsUnit(unit, "player") then
		return "SELF"
	elseif UnitIsUnit(unit, "pet") then
		return "PET"
	elseif UnitIsPlayer(unit) then
		if string.find(unit, "^party%d") or (UnitInParty and UnitInParty(unit)) then
			return "PARTY"
		end
		return "PLAYER"
	end
	return "RAID_TARGET_ICON", RAID_TARGET_ICON
end

local function MenuInit()
	if not menuUnit or not UnitExists(menuUnit) then
		return
	end
	local which, name = MenuWhich(menuUnit)
	UnitPopup_ShowMenu(dropdown, which, menuUnit, name)
end

-- The menu opens at the cursor, kept on screen.
local function PlaceAtCursor(list)
	local x, y = GetCursorPosition()
	local s = list:GetEffectiveScale()
	x, y = x / s, y / s
	local w, h = list:GetWidth() or 0, list:GetHeight() or 0
	local right = (UIParent:GetWidth() or 0) * UIParent:GetEffectiveScale() / s
	if right > 0 and x + w > right then
		x = right - w
	end
	list:ClearAllPoints()
	if y - h < 0 then
		list:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
	else
		list:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	end
end

function A.OpenUnitMenu(owner, unit)
	if not unit or not UnitExists(unit) or not UnitPopup_ShowMenu or not ToggleDropDownMenu then
		return
	end
	if not dropdown then
		dropdown = CreateFrame("Frame", "AetherHUDUnitDropDown", UIParent, "UIDropDownMenuTemplate")
		dropdown:Hide()
		UIDropDownMenu_Initialize(dropdown, MenuInit, "MENU")
	end
	local list = DropDownList1
	-- the same frame again closes the menu (the toggle below); another frame's opens anew
	if menuUnit ~= unit and list and list:IsShown() and CloseDropDownMenus then
		CloseDropDownMenus()
	end
	menuUnit = unit
	ToggleDropDownMenu(1, nil, dropdown, owner:GetName(), 0, 0)
	if list and list:IsShown() and UIDROPDOWNMENU_OPEN_MENU == "AetherHUDUnitDropDown" then
		PlaceAtCursor(list)
	end
end

-- Left-click targets, right-click opens the menu.
function A.UnitClicks(frame, unit)
	frame:EnableMouse(true)
	frame.aUnit = unit
	frame:SetScript("OnMouseUp", function()
		local u = this.aUnit
		if type(u) == "function" then
			u = u()
		end
		if arg1 == "RightButton" then
			A.OpenUnitMenu(this, u)
		elseif u and UnitExists(u) then
			TargetUnit(u)
		end
	end)
end

------------------------------------------------------------------------
-- Inspect window
------------------------------------------------------------------------

local W, H = 560, 430
local SLOT, GAP = 36, 7
local LIST_W = 196

local LEFT = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" }
local RIGHT = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" }
local BOTTOM = { "MainHandSlot", "SecondaryHandSlot", "RangedSlot" }
local ORDER = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot",
	"WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
	"Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot", "RangedSlot" }
local LABEL = {
	HeadSlot = "Head", NeckSlot = "Neck", ShoulderSlot = "Shoulder", BackSlot = "Back", ChestSlot = "Chest",
	ShirtSlot = "Shirt", TabardSlot = "Tabard", WristSlot = "Wrist", HandsSlot = "Hands", WaistSlot = "Waist",
	LegsSlot = "Legs", FeetSlot = "Feet", Finger0Slot = "Ring", Finger1Slot = "Ring", Trinket0Slot = "Trinket",
	Trinket1Slot = "Trinket", MainHandSlot = "Main hand", SecondaryHandSlot = "Off hand", RangedSlot = "Ranged",
}

local f, portrait, nameText, guildText, subText, levelText, listCol, runHead, runRule
local unit, unitName
local slots = {}
local items = {}
local tiles = {}
local runRows = {}

local function ItemName(link)
	local _, _, name = string.find(link or "", "%[(.-)%]")
	return name
end

local function SlotClick()
	local link = GetInventoryItemLink(unit, this.inv)
	if not link then
		return
	end
	if IsShiftKeyDown() and A.InsertLink(link) then
		return
	end
	if IsControlKeyDown and IsControlKeyDown() and DressUpItemLink then
		DressUpItemLink(link)
	end
end

local function SlotEnter()
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	if not (unit and GameTooltip:SetInventoryItem(unit, this.inv)) then
		GameTooltip:SetText(LABEL[this.slotName] or this.slotName, 1, 1, 1)
	end
	GameTooltip:Show()
end

local function MakeSlot(slotName)
	local id, empty = GetInventorySlotInfo(slotName)
	local s = A.Socket(f, SLOT, { frame = "slot" })
	local b = s.frame
	b.inv, b.empty, b.slotName = id, empty, slotName
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnClick", SlotClick)
	b:SetScript("OnEnter", SlotEnter)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	slots[slotName] = s
	return s
end

-- A line of the item list: slot, then the item's name in its quality colour.
local function Item(i)
	local r = items[i]
	if r then
		return r
	end
	local b = CreateFrame("Button", nil, listCol)
	b:SetWidth(LIST_W)
	b:SetHeight(13)
	b:SetPoint("TOPLEFT", listCol, "TOPLEFT", 8, -26 - (i - 1) * 13)
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnClick", SlotClick)
	b:SetScript("OnEnter", SlotEnter)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	local hl = A.Tex(b, "HIGHLIGHT")
	hl:SetAllPoints(b)
	hl:SetVertexColor(C.aether[1], C.aether[2], C.aether[3], 0.08)
	r = { button = b }
	r.slot = A.Text(b, 9)
	r.slot:SetPoint("LEFT", b, "LEFT", 0, 0)
	r.slot:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	r.name = A.Text(b, 10)
	r.name:SetPoint("LEFT", b, "LEFT", 56, 0)
	r.name:SetPoint("RIGHT", b, "RIGHT", 0, 0)
	r.name:SetJustifyH("LEFT")
	items[i] = r
	return r
end

local function RunRow(i)
	local r = runRows[i]
	if r then
		return r
	end
	r = {}
	r.label = A.Text(listCol, 10)
	r.label:SetTextColor(C.steel[1], C.steel[2], C.steel[3])
	r.value = A.Text(listCol, 10)
	runRows[i] = r
	return r
end

-- Their line on the party meter, if they are in your party.
local function MeterLine(name)
	local lines = D.PartyMeter()
	for i = 1, table.getn(lines) do
		if lines[i].name == name then
			return lines[i]
		end
	end
end

local function UpdateGear()
	local worn, n = 0, 0
	for _, s in pairs(slots) do
		local id = s.frame.inv
		local tex = GetInventoryItemTexture(unit, id)
		if tex then
			worn = worn + 1
			s:SetIcon(tex)
			A.SetAlpha(s.icon, 1)
			local c = A.LinkColor(GetInventoryItemLink(unit, id)) or C.steel
			A.SetColor(s.rim, c[1], c[2], c[3], 1)
		else
			s:SetIcon(s.frame.empty)
			A.SetAlpha(s.icon, 0.25)
			A.SetColor(s.rim, C.steel[1] * 0.6, C.steel[2] * 0.6, C.steel[3] * 0.6, 1)
		end
	end
	for i = 1, table.getn(ORDER) do
		local slotName = ORDER[i]
		local id = slots[slotName].frame.inv
		local link = GetInventoryItemLink(unit, id)
		if link then
			n = n + 1
			local r = Item(n)
			r.button.inv, r.button.slotName = id, slotName
			A.SetText(r.slot, LABEL[slotName])
			A.SetText(r.name, ItemName(link) or "?")
			A.SetTextColor(r.name, A.LinkColor(link) or C.text)
			A.Show(r.button, true)
		end
	end
	if n == 0 then
		local r = Item(1)
		r.button.inv, r.button.slotName = nil, nil
		A.SetText(r.slot, "")
		A.SetText(r.name, "Their gear shows here once it arrives.")
		A.SetTextColor(r.name, C.muted)
		A.Show(r.button, true)
		n = 1
	end
	for i = n + 1, table.getn(items) do
		A.Show(items[i].button, false)
	end
	return worn, n
end

local function UpdateRun(rows)
	local line = MeterLine(unitName)
	local y = -26 - rows * 13 - 14
	runHead:ClearAllPoints()
	runHead:SetPoint("TOPLEFT", listCol, "TOPLEFT", 8, y)
	runRule:ClearAllPoints()
	runRule:SetPoint("TOPLEFT", listCol, "TOPLEFT", 4, y - 13)
	A.Show(runHead, line ~= nil)
	A.Show(runRule, line ~= nil)
	local defs = {}
	if line then
		defs = {
			{ "Damage", A.Comma(line.dmg) },
			{ "Per second", A.Comma(line.dps) },
			{ "Party share", string.format("%.0f%%", A.N(line.share) * 100) },
		}
		if line.top and line.top ~= "" then
			table.insert(defs, { "Top spell", line.top })
			table.insert(defs, { "  per second", A.Comma(line.topdps) })
		end
	end
	y = y - 18
	for i = 1, table.getn(defs) do
		local r = RunRow(i)
		r.label:ClearAllPoints()
		r.label:SetPoint("TOPLEFT", listCol, "TOPLEFT", 8, y)
		r.value:ClearAllPoints()
		r.value:SetPoint("TOPRIGHT", listCol, "TOPLEFT", 8 + LIST_W, y)
		A.SetText(r.label, defs[i][1])
		A.SetText(r.value, defs[i][2])
		A.Show(r.label, true)
		A.Show(r.value, true)
		y = y - 13
	end
	for i = table.getn(defs) + 1, table.getn(runRows) do
		A.Show(runRows[i].label, false)
		A.Show(runRows[i].value, false)
	end
	return line
end

local function UpdateHeader(worn, line)
	A.SetText(nameText, UnitName(unit) or unitName or "")
	local lvl = UnitLevel(unit) or 0
	A.SetText(levelText, lvl > 0 and tostring(lvl) or "??")
	local cls, token = UnitClass(unit)
	local cc = A.CLASS[token and string.lower(token) or ""] or C.steel
	A.SetText(subText, A.Hex(C.muted) .. "Level " .. (lvl > 0 and lvl or "??") .. "  |r" .. (UnitRace(unit) or "")
		.. "  " .. A.Hex(cc) .. (cls or "") .. "|r")
	local guild, rank = nil, nil
	if GetGuildInfo then
		guild, rank = GetGuildInfo(unit)
	end
	A.SetText(guildText, guild and ("<" .. guild .. ">" .. (rank and rank ~= "" and (A.Hex(C.muted) .. "  " .. rank .. "|r") or "")) or "")
	A.SetText(tiles[1].value, A.Comma(UnitHealthMax(unit) or 0))
	A.SetText(tiles[2].value, worn .. " / " .. table.getn(ORDER))
	A.SetText(tiles[3].value, line and A.Short(line.dmg) or "-")
	A.SetText(tiles[4].value, line and A.Short(line.dps) or "-")
end

local function Refresh()
	if not f or not f:IsShown() or not unit then
		return
	end
	if not UnitExists(unit) or UnitName(unit) ~= unitName then
		f:Hide()
		return
	end
	local worn, rows = UpdateGear()
	local line = UpdateRun(rows)
	UpdateHeader(worn, line)
end

-- A token that keeps pointing at them: a party member's partyN rather than "target".
local function Stable(u)
	if u == "target" or u == "mouseover" then
		for i = 1, 4 do
			if UnitIsUnit(u, "party" .. i) then
				return "party" .. i
			end
		end
	end
	return u
end

function A.Inspect(u)
	if not f or not u or not UnitExists(u) then
		return false
	end
	if UnitIsUnit(u, "player") then
		if AetherHUDCharacter and not AetherHUDCharacter:IsShown() and ToggleCharacter then
			ToggleCharacter("PaperDollFrame")
		end
		return true
	end
	if not UnitIsPlayer(u) or (CanInspect and not CanInspect(u)) then
		return false
	end
	unit = Stable(u)
	unitName = UnitName(unit)
	if NotifyInspect then
		NotifyInspect(unit)
	end
	SetPortraitTexture(portrait, unit)
	if f:IsShown() then
		Refresh()
	else
		f:Show()
	end
	return true
end

local function Init()
	if not A.On("inspect") then
		return
	end
	f = A.Window("inspect", "AetherHUDInspect", "Inspect", W, H, function(fr)
		fr:SetPoint("CENTER", A.root, "CENTER", 140, 30)
	end)

	local colTop = -40
	for i = 1, table.getn(LEFT) do
		MakeSlot(LEFT[i]).frame:SetPoint("TOPLEFT", f, "TOPLEFT", 14, colTop - (i - 1) * (SLOT + GAP))
	end
	local rightX = W - LIST_W - 28 - SLOT
	for i = 1, table.getn(RIGHT) do
		MakeSlot(RIGHT[i]).frame:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, colTop - (i - 1) * (SLOT + GAP))
	end
	local centerX = (14 + SLOT + rightX) / 2
	for i = 1, table.getn(BOTTOM) do
		MakeSlot(BOTTOM[i]).frame:SetPoint("BOTTOM", f, "BOTTOMLEFT", centerX + (i - 2) * (SLOT + 10), 16)
	end

	-- portrait in its bezel, level gem, name, guild and line
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
	local gf = CreateFrame("Frame", nil, pf)
	gf:SetAllPoints(pf)
	gf:SetFrameLevel(pf:GetFrameLevel() + 2)
	local halo = A.Tex(gf, "ARTWORK", A.MEDIA .. "glow")
	halo:SetBlendMode("ADD")
	halo:SetWidth(60)
	halo:SetHeight(22)
	halo:SetPoint("TOP", pf, "TOP", 0, -2)
	halo:SetVertexColor(C.aether[1], C.aether[2], C.aether[3], 0.35)
	local gem = A.Diamond(gf, 30, C.gold, "OVERLAY")
	gem:SetPoint("CENTER", pf, "BOTTOM", 0, 6)
	levelText = A.Text(gf, 12)
	A.Font(levelText, 12, false, "")
	levelText:SetPoint("CENTER", gem, "CENTER", 0, 0)
	levelText:SetTextColor(0.12, 0.08, 0.02)
	levelText:SetShadowOffset(0, 0)

	nameText = A.Text(f, 16, true)
	nameText:SetPoint("TOP", pf, "BOTTOM", 0, -16)
	nameText:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	guildText = A.Text(f, 10)
	guildText:SetPoint("TOP", nameText, "BOTTOM", 0, -3)
	guildText:SetTextColor(C.good[1], C.good[2], C.good[3])
	subText = A.Text(f, 10)
	subText:SetPoint("TOP", guildText, "BOTTOM", 0, -3)

	local TILES = { "HEALTH", "GEAR", "RUN DAMAGE", "PER SECOND" }
	local tileW, tileH = 86, 34
	for i = 1, table.getn(TILES) do
		local col = math.mod(i - 1, 2)
		local row = math.floor((i - 1) / 2)
		local t = A.Panel(nil, f, tileW, tileH, { bracket = 4, noGlint = true, alpha = 0.6 })
		t:SetPoint("TOPLEFT", f, "TOPLEFT", centerX - tileW - 3 + col * (tileW + 6), -238 - row * (tileH + 6))
		local label = A.Text(t, 8, true)
		label:SetPoint("TOP", t, "TOP", 0, -5)
		label:SetText(TILES[i])
		label:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
		local value = A.Text(t, 13)
		value:SetPoint("BOTTOM", t, "BOTTOM", 0, 5)
		tiles[i] = { frame = t, value = value }
	end

	-- the item list and the run on their glass column
	listCol = A.Panel(nil, f, LIST_W + 16, H - 44, { bracket = 5, noGlint = true, alpha = 0.45 })
	listCol:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -32)
	local head = A.Text(listCol, 10, true)
	head:SetPoint("TOPLEFT", listCol, "TOPLEFT", 8, -6)
	head:SetText(A.Spaced("Equipment"))
	head:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	local rule = A.Tex(listCol, "ARTWORK", A.MEDIA .. "line")
	rule:SetHeight(3)
	rule:SetWidth(LIST_W)
	rule:SetPoint("TOPLEFT", listCol, "TOPLEFT", 4, -19)
	rule:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.5)
	runHead = A.Text(listCol, 10, true)
	runHead:SetText(A.Spaced("This run"))
	runHead:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	runRule = A.Tex(listCol, "ARTWORK", A.MEDIA .. "line")
	runRule:SetHeight(3)
	runRule:SetWidth(LIST_W)
	runRule:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.5)

	f.OnOpen = Refresh
	f:SetScript("OnHide", function()
		this.aS = false
		if ClearInspectPlayer then
			ClearInspectPlayer()
		end
	end)

	-- every way the game inspects (the unit menu's Inspect, /inspect, the stock frames)
	local stock = InspectUnit
	InspectUnit = function(u)
		if not A.Inspect(u) and stock then
			stock(u)
		end
	end

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "UNIT_INVENTORY_CHANGED", "UNIT_PORTRAIT_UPDATE", "UNIT_NAME_UPDATE",
		"PLAYER_TARGET_CHANGED", "PARTY_MEMBERS_CHANGED" }) do
		ev:RegisterEvent(e)
	end
	ev:SetScript("OnEvent", function()
		if not f:IsShown() then
			return
		end
		if event == "UNIT_PORTRAIT_UPDATE" and arg1 and UnitIsUnit(arg1, unit) then
			SetPortraitTexture(portrait, unit)
		end
		Refresh()
	end)
	-- gear arrives a moment after the request, and keeps changing in a run
	A.Every(0.5, function()
		if f.aS then
			Refresh()
		end
	end)
end

A.OnInit(Init)
