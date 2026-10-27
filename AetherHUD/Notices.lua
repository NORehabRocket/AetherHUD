-- AetherHUD notices: everything that used to pop up in the stock or game style now comes
-- through AetherHUD. Red/yellow error and info lines become Aion's system messages, the
-- zone text becomes a banner, a party revive shows as a bar, and loot ("You receive
-- loot: ...") slides in as item cards instead of the game's loot notice.

local A = AetherHUD
local C, D = A.C, A.D

------------------------------------------------------------------------
-- System messages
------------------------------------------------------------------------

local LINES, LIFE, FADE = 3, 3.5, 0.8

local sys
local lines = {} -- { text, r, g, b, age } newest first; at most LINES (kept with remove/insert)
local labels = {}

local function Redraw()
	for i = 1, LINES do
		local l = lines[i]
		local fs = labels[i]
		if l then
			A.SetText(fs, l.text)
			fs:SetTextColor(l.r, l.g, l.b)
			local left = LIFE - l.age
			A.SetAlpha(fs, left < FADE and math.max(0, left / FADE) or 1)
			A.Show(fs, true)
		else
			A.Show(fs, false)
		end
	end
end

function A.Notice(msg, r, g, b)
	if not sys or type(msg) ~= "string" or msg == "" then
		return
	end
	local top = lines[1]
	if top and top.text == msg then
		top.age = 0 -- the same message again: keep it up, don't stack it
		Redraw()
		return
	end
	table.insert(lines, 1, { text = msg, r = r or 1, g = g or 0.82, b = b or 0, age = 0 })
	while table.getn(lines) > LINES do
		table.remove(lines)
	end
	Redraw()
end

local function TickSystem(dt)
	if table.getn(lines) == 0 then
		return
	end
	for i = table.getn(lines), 1, -1 do
		lines[i].age = lines[i].age + dt
		if lines[i].age >= LIFE then
			table.remove(lines, i)
		end
	end
	Redraw()
end

-- The stock frames that printed these route here instead.
local function Route(frame)
	if not frame or frame.aRouted then
		return
	end
	frame.aRouted = true
	frame.AddMessage = function(self, msg, r, g, b)
		A.Notice(msg, r, g, b)
	end
end

------------------------------------------------------------------------
-- Party revive (the game's "revive" bar)
------------------------------------------------------------------------

local rev, revBar, revText

local function UpdateRevive()
	local r = AZS_GetRevive and AZS_GetRevive() or {}
	if type(r) ~= "table" then
		r = {}
	end
	local share, text
	if A.N(r.down) == 1 then
		share = A.N(r.share)
		if r.by and r.by ~= "" then
			text = A.Hex(C.bad) .. "YOU ARE DOWN|r  " .. r.by .. " is bringing you back"
		else
			text = A.Hex(C.bad) .. "YOU ARE DOWN|r  a friend next to you can bring you back"
		end
	elseif r.reviving and r.reviving ~= "" then
		share = A.N(r.rshare)
		text = A.Hex(C.good) .. "REVIVING|r  " .. r.reviving
	end
	if not text then
		A.Show(rev, false)
		return
	end
	A.Show(rev, true)
	A.SetText(revText, text)
	revBar:SetValue(share)
end

------------------------------------------------------------------------
-- Loot cards
------------------------------------------------------------------------

local CARD_W, CARD_H, CARDS, CARD_LIFE = 260, 42, 4, 5.5
local loot
local cards = {}  -- pool, index 1 = newest
local live = 0

local prefixes

local function Prefixes()
	if prefixes then
		return prefixes
	end
	prefixes = {}
	for _, g in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF",
		"LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF" }) do
		local f = getglobal(g)
		if type(f) == "string" then
			local p = string.find(f, "%", 1, true)
			if p and p > 1 then
				table.insert(prefixes, string.sub(f, 1, p - 1))
			end
		end
	end
	if table.getn(prefixes) == 0 then
		prefixes = { "You receive loot: ", "You receive item: ", "You create: " }
	end
	return prefixes
end

local function Card(i)
	local c = cards[i]
	if c then
		return c
	end
	c = {}
	local f = A.Panel(nil, loot, CARD_W, CARD_H, { bracket = 5 })
	c.frame = f
	c.accent = A.Tex(f, "ARTWORK")
	c.accent:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	c.accent:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	c.accent:SetWidth(3)
	c.icon = A.Socket(f, 32, { frame = "slot" })
	c.icon.frame:SetPoint("LEFT", f, "LEFT", 7, 0)
	c.name = A.Text(f, 12, true)
	c.name:SetPoint("TOPLEFT", f, "TOPLEFT", 46, -8)
	c.name:SetWidth(CARD_W - 54)
	c.name:SetJustifyH("LEFT")
	c.sub = A.Text(f, 9)
	c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
	c.sub:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	cards[i] = c
	return c
end

local function Layout()
	for i = 1, CARDS do
		local c = cards[i]
		if c and c.data then
			local slide = 0
			if c.data.age < 0.2 then
				slide = (1 - c.data.age / 0.2) * -40
			end
			c.frame:ClearAllPoints()
			c.frame:SetPoint("BOTTOMLEFT", loot, "BOTTOMLEFT", slide, (i - 1) * (CARD_H + 5))
			local left = CARD_LIFE - c.data.age
			A.SetAlpha(c.frame, left < 0.6 and math.max(0, left / 0.6) or math.min(1, c.data.age / 0.15))
			A.Show(c.frame, true)
		elseif c then
			A.Show(c.frame, false)
		end
	end
end

local function ShowCard(data)
	-- shift the stack: the newest card sits at the bottom, nearest the chat
	for i = CARDS, 2, -1 do
		local prev = cards[i - 1]
		Card(i).data = prev and prev.data
	end
	Card(1).data = data
	for i = 1, CARDS do
		local c = cards[i]
		local d = c.data
		if d then
			c.icon:SetIcon(d.icon)
			c.icon:SetCount(d.count)
			c.icon.rim:SetVertexColor(d.color[1], d.color[2], d.color[3], 1)
			c.accent:SetVertexColor(d.color[1], d.color[2], d.color[3], 1)
			A.SetText(c.name, d.name)
			c.name:SetTextColor(d.color[1], d.color[2], d.color[3])
			A.SetText(c.sub, d.sub)
		end
	end
	Layout()
end

function A.LootCard(name, icon, color, count, sub)
	if not loot then
		return
	end
	ShowCard({ name = name, icon = icon, color = color or { 1, 1, 1 }, count = count, sub = sub or "", age = 0 })
end

local function OnLoot(msg)
	if type(msg) ~= "string" then
		return
	end
	local mine = false
	local p = Prefixes()
	for i = 1, table.getn(p) do
		if string.sub(msg, 1, string.len(p[i])) == p[i] then
			mine = true
			break
		end
	end
	if not mine then
		return
	end
	local _, e, itemString, name = string.find(msg, "|H(item:[%-%d:]+)|h%[(.-)%]|h|r")
	if not e then
		return
	end
	local rest = string.sub(msg, e + 1)
	local _, _, n = string.find(rest, "^x(%d+)")
	rest = string.gsub(rest, "^x%d+", "")
	rest = string.gsub(rest, "^[%s%.]+", "")
	rest = string.gsub(rest, "[%s%.]+$", "")
	local icon
	if GetItemInfo then
		local _, _, _, _, _, _, _, _, tex = GetItemInfo(itemString)
		icon = tex
	end
	A.LootCard(name, icon, A.LinkColor(msg), tonumber(n), rest)
end

local function TickLoot(dt)
	local any = false
	for i = 1, CARDS do
		local c = cards[i]
		if c and c.data then
			c.data.age = c.data.age + dt
			if c.data.age >= CARD_LIFE then
				c.data = nil
			else
				any = true
			end
		end
	end
	if any or loot.wasBusy then
		Layout()
	end
	loot.wasBusy = any
end

------------------------------------------------------------------------

local function Init()
	if A.On("notices") then
		sys = CreateFrame("Frame", "AetherHUDNotices", A.root)
		sys:SetFrameStrata("FULLSCREEN")
		sys:SetWidth(520)
		sys:SetHeight(LINES * 17)
		for i = 1, LINES do
			local fs = A.Text(sys, 13)
			fs:SetPoint("TOP", sys, "TOP", 0, -(i - 1) * 17)
			fs:SetWidth(520)
			labels[i] = fs
		end
		Redraw()
		Route(UIErrorsFrame)
		Route(RaidWarningFrame)
		-- the stock zone text gives way to a banner
		A.Kill(ZoneTextFrame)
		A.Kill(SubZoneTextFrame)
		local ev = CreateFrame("Frame")
		ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		ev:SetScript("OnEvent", function()
			local z = GetZoneText and GetZoneText()
			if z and z ~= "" and A.PushBanner then
				A.PushBanner({ kind = "zone", text = z })
			end
		end)
		A.RegisterMover("notices", sys, "System messages", function(fr)
			fr:SetPoint("TOP", A.root, "TOP", 0, -248)
		end)
		A.Every(0.1, TickSystem)

		rev = A.Panel("AetherHUDRevive", A.root, 320, 42, { bracket = 6 })
		revText = A.Text(rev, 11, true)
		revText:SetPoint("TOP", rev, "TOP", 0, -7)
		revBar = A.Bar(rev, 300, 9, { 0.10, 0.40, 0.20 }, C.good)
		revBar.frame:SetPoint("BOTTOM", rev, "BOTTOM", 0, 8)
		rev:Hide()
		rev.aS = false
		A.RegisterMover("revive", rev, "Revive", function(fr)
			fr:SetPoint("CENTER", A.root, "CENTER", 0, -70)
		end)
		A.Every(0.1, UpdateRevive)
		A.Every(0.03, function(dt)
			if rev.aS then
				revBar:Tick(dt)
			end
		end)
	end

	if A.On("loot") then
		loot = CreateFrame("Frame", "AetherHUDLoot", A.root)
		loot:SetFrameStrata("MEDIUM")
		loot:SetWidth(CARD_W)
		loot:SetHeight(CARD_H)
		local ev = CreateFrame("Frame")
		ev:RegisterEvent("CHAT_MSG_LOOT")
		ev:RegisterEvent("CHAT_MSG_SYSTEM")
		ev:SetScript("OnEvent", function()
			local ok, err = pcall(OnLoot, arg1)
			if not ok then
				A.Error(err)
			end
		end)
		A.RegisterMover("loot", loot, "Loot", function(fr)
			fr:SetPoint("BOTTOMLEFT", A.root, "BOTTOMLEFT", 22, 236)
		end)
		A.Every(0.03, TickLoot)
	end
end

A.OnInit(Init)
