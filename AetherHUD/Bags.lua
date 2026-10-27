-- AetherHUD inventory: Aion's cube. Every bag in one grid of beveled sockets rimmed in each
-- item's quality colour, with stack counts, cooldowns and locked items dimmed; the
-- equipped bags and your money underneath. Left-click picks up (or drops) an item,
-- right-click uses or equips it, Shift-click links it. B and the bag keys open it.

local A = AetherHUD
local C = A.C

local COLS, SLOT, GAP, PAD = 10, 34, 3, 12
local HEAD, FOOT = 34, 34
local BAGS = 4 -- bags 1-4 besides the backpack (0)

local QUALITY = {
	[0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
	[4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 }, [6] = { 0.9, 0.8, 0.5 },
}

local f, grid, capacity, money
local buttons = {}
local bagSlots = {}
local shown = 0
local dirty = true
local nextFull = 0

local function QualityColor(bag, slot, quality)
	if quality and QUALITY[quality] and quality ~= 1 then
		return QUALITY[quality]
	end
	return A.LinkColor(GetContainerItemLink(bag, slot))
end

------------------------------------------------------------------------
-- Item sockets
------------------------------------------------------------------------

local function OnClick()
	local bag, slot = this.bag, this.slot
	if arg1 == "RightButton" then
		UseContainerItem(bag, slot)
	elseif IsShiftKeyDown() and A.InsertLink(GetContainerItemLink(bag, slot)) then
		return
	else
		PickupContainerItem(bag, slot)
	end
end

local function OnEnter()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetBagItem(this.bag, this.slot)
	GameTooltip:Show()
end

local function Button(i)
	local s = buttons[i]
	if s then
		return s
	end
	s = A.Socket(grid, SLOT, { frame = "slot", countSize = 11 })
	local b = s.frame
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnClick", OnClick)
	b:SetScript("OnDragStart", function()
		PickupContainerItem(this.bag, this.slot)
	end)
	b:SetScript("OnReceiveDrag", function()
		PickupContainerItem(this.bag, this.slot)
	end)
	b:SetScript("OnEnter", OnEnter)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	local col = math.mod(i - 1, COLS)
	local row = math.floor((i - 1) / COLS)
	b:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (SLOT + GAP), -row * (SLOT + GAP))
	buttons[i] = s
	return s
end

------------------------------------------------------------------------
-- Equipped bags (inventory slots for bags 1-4)
------------------------------------------------------------------------

local function BagSlotId(n)
	if ContainerIDToInventoryID then
		return ContainerIDToInventoryID(n)
	end
	return 19 + n
end

local function BagSlot(n)
	local s = A.Socket(f, 22, { frame = "slot" })
	s.frame.inv = BagSlotId(n)
	s.frame:RegisterForDrag("LeftButton")
	s.frame:SetScript("OnClick", function()
		if CursorHasItem and CursorHasItem() then
			PutItemInBag(this.inv)
		else
			PickupBagFromSlot(this.inv)
		end
	end)
	s.frame:SetScript("OnReceiveDrag", function()
		PutItemInBag(this.inv)
	end)
	s.frame:SetScript("OnDragStart", function()
		PickupBagFromSlot(this.inv)
	end)
	s.frame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		if not GameTooltip:SetInventoryItem("player", this.inv) then
			GameTooltip:SetText("Bag slot", 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	s.frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return s
end

------------------------------------------------------------------------

-- Money in gold, silver and copper (1.12 font strings take no inline coin icons).
local function MoneyText()
	local m = GetMoney and GetMoney() or 0
	local g, s, c = math.floor(m / 10000), math.floor(math.mod(m, 10000) / 100), math.mod(m, 100)
	return A.Hex(C.gold) .. A.Comma(g) .. "|r" .. A.Hex(C.muted) .. "g  |r"
		.. "|cffd0d4dc" .. s .. "|r" .. A.Hex(C.muted) .. "s  |r"
		.. "|cffd88a52" .. c .. "|r" .. A.Hex(C.muted) .. "c|r"
end

local function Relayout(total)
	shown = total
	local rows = math.max(1, math.ceil(total / COLS))
	grid:SetWidth(COLS * SLOT + (COLS - 1) * GAP)
	grid:SetHeight(rows * SLOT + (rows - 1) * GAP)
	f:SetWidth(COLS * SLOT + (COLS - 1) * GAP + 2 * PAD)
	f:SetHeight(HEAD + rows * (SLOT + GAP) - GAP + FOOT + PAD)
end

local function Update()
	if not f.aS then
		return
	end
	dirty = false
	local i, used = 0, 0
	for bag = 0, BAGS do
		local n = GetContainerNumSlots(bag) or 0
		for slot = 1, n do
			i = i + 1
			local s = Button(i)
			s.frame.bag, s.frame.slot = bag, slot
			local tex, count, locked, quality = GetContainerItemInfo(bag, slot)
			if tex then
				used = used + 1
				s:SetIcon(tex)
				A.SetAlpha(s.icon, locked and 0.35 or 1)
				s:SetCount(count)
				local c = QualityColor(bag, slot, quality) or C.steel
				A.SetColor(s.rim, c[1], c[2], c[3], 1)
				local start, duration = 0, 0
				if GetContainerItemCooldown then
					start, duration = GetContainerItemCooldown(bag, slot)
				end
				if start and start > 0 and duration and duration > 1.5 then
					s:SetCooldown(start + duration - GetTime(), duration)
				else
					s:SetCooldown(0)
				end
			else
				-- hidden, not cleared: a texture without a file shows the client's red slash
				A.SetAlpha(s.icon, 0)
				s:SetCount(0)
				s:SetCooldown(0)
				A.SetColor(s.rim, C.steel[1] * 0.6, C.steel[2] * 0.6, C.steel[3] * 0.6, 1)
			end
			A.Show(s.frame, true)
		end
	end
	for k = i + 1, table.getn(buttons) do
		A.Show(buttons[k].frame, false)
	end
	if i ~= shown then
		Relayout(i)
	end
	A.SetText(capacity, used .. " / " .. i)
	A.SetText(money, MoneyText())
	for n = 1, BAGS do
		local bs = bagSlots[n]
		local tex = GetInventoryItemTexture("player", bs.frame.inv)
		bs:SetIcon(tex)
		A.SetAlpha(bs.icon, tex and 1 or 0.15)
	end
end

local function Tick(dt)
	if not f.aS then
		return
	end
	for i = 1, shown do
		buttons[i]:Tick(dt)
	end
	-- cooldown timers count down between bag events
	if dirty or GetTime() >= nextFull then
		nextFull = GetTime() + 0.5
		Update()
	end
end

------------------------------------------------------------------------
-- The stock bag functions open the cube instead (bank bags stay stock)
------------------------------------------------------------------------

local stock = {}

local function Hook()
	stock.ToggleBag = ToggleBag
	stock.IsBagOpen = IsBagOpen
	ToggleBackpack = function()
		A.ToggleWindow(f)
	end
	OpenBackpack = function()
		f:Show()
	end
	CloseBackpack = function()
		f:Hide()
	end
	OpenAllBags = function(force)
		if force then
			f:Show()
		else
			A.ToggleWindow(f)
		end
	end
	CloseAllBags = function()
		f:Hide()
	end
	ToggleBag = function(id)
		if id and id > BAGS and stock.ToggleBag then
			return stock.ToggleBag(id)
		end
		A.ToggleWindow(f)
	end
	OpenBag = function(id)
		if id and id > BAGS then
			return
		end
		f:Show()
	end
	CloseBag = function(id)
		if not id or id <= BAGS then
			f:Hide()
		end
	end
	IsBagOpen = function(id)
		if id and id > BAGS and stock.IsBagOpen then
			return stock.IsBagOpen(id)
		end
		return f:IsShown() and id or nil
	end
	for i = 1, 12 do
		local cf = getglobal("ContainerFrame" .. i)
		if cf and cf:IsShown() then
			cf:Hide()
		end
	end
end

local function Init()
	if not A.On("bags") then
		return
	end
	f = A.Window("bags", "AetherHUDBags", "Inventory", COLS * SLOT + (COLS - 1) * GAP + 2 * PAD, 260, function(fr)
		fr:SetPoint("BOTTOMRIGHT", A.root, "BOTTOMRIGHT", -280, 16)
	end)
	capacity = A.Text(f, 10)
	capacity:SetPoint("TOPRIGHT", f, "TOPRIGHT", -36, -11)
	capacity:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	grid = CreateFrame("Frame", nil, f)
	grid:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -HEAD)
	grid:SetWidth(1)
	grid:SetHeight(1)

	money = A.Text(f, 12)
	money:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 12)
	for n = 1, BAGS do
		local bs = BagSlot(n)
		bs.frame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD + (n - 1) * 25, 7)
		bagSlots[n] = bs
	end

	f.OnOpen = function()
		dirty = true
		Update()
	end
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "BAG_UPDATE", "BAG_UPDATE_COOLDOWN", "ITEM_LOCK_CHANGED", "PLAYER_MONEY",
		"UNIT_INVENTORY_CHANGED", "PLAYER_ENTERING_WORLD" }) do
		ev:RegisterEvent(e)
	end
	ev:SetScript("OnEvent", function()
		dirty = true
	end)
	Hook()
	A.Every(0.05, Tick)
end

A.OnInit(Init)
