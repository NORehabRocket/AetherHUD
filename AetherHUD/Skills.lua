-- AetherHUD skill bar: Aion's quickbar. The six spells and the racial in beveled sockets
-- (icons from their action slots, waits from AZS_SPELLS), a gem with each spell's rank,
-- and above it the talents' and jewelry's own clocks and your summons. The stock main
-- bar is faded out underneath; its buttons keep working.

local A = AetherHUD
local C, D = A.C, A.D

local SLOT, GAP, SEP, PAD = 40, 4, 12, 8
local MINI = 18
local W = PAD + 6 * SLOT + 5 * GAP + SEP + SLOT + 8 + 2 * MINI + 4 + PAD
local H = SLOT + 2 * PAD

local f
local sockets = {}
local effects = {}
local strip

local function Hush(frame)
	if frame then
		frame:SetAlpha(0)
		if frame.EnableMouse then
			frame:EnableMouse(false)
		end
	end
end

local function FadeStockBar()
	Hush(MainMenuBar)
	Hush(MainMenuBarArtFrame)
	Hush(MainMenuExpBar)
	Hush(MainMenuBarMaxLevelBar)
	for i = 1, 12 do
		Hush(getglobal("ActionButton" .. i))
	end
	Hush(CharacterMicroButton)
	Hush(TalentMicroButton)
end

local function SlotTooltip()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	if this.demoName then
		GameTooltip:SetText(this.demoName, 1, 1, 1)
		GameTooltip:Show()
		return
	end
	if this.slot and HasAction(this.slot) then
		GameTooltip:SetAction(this.slot)
		if this.rank and this.rank > 0 then
			GameTooltip:AddLine("Rank " .. this.rank, C.gold[1], C.gold[2], C.gold[3])
		end
		GameTooltip:Show()
	end
end

local function MakeSocket(i)
	local racial = i == 7
	local s = A.Socket(f, SLOT, { frame = "slot", tint = racial and C.gold or C.steel })
	local x = PAD + (i - 1) * (SLOT + GAP)
	if racial then
		x = PAD + 6 * SLOT + 5 * GAP + SEP
	end
	s.frame:SetPoint("TOPLEFT", f, "TOPLEFT", x, -PAD)
	s.frame:SetScript("OnEnter", SlotTooltip)
	s.frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	-- rank gem in the top-left corner
	s.gem = A.Diamond(s.top, 14, racial and C.gold or C.aether, "ARTWORK")
	s.gem:SetPoint("CENTER", s.frame, "TOPLEFT", 6, -6)
	s.rank = A.Text(s.top, 8)
	A.Font(s.rank, 8, false, "")
	s.rank:SetPoint("CENTER", s.gem, "CENTER", 0, 0)
	s.rank:SetTextColor(0.05, 0.07, 0.1)
	s.rank:SetShadowOffset(0, 0)
	return s
end

local function Mini(index, icon, label, onClick)
	local b = CreateFrame("Button", nil, f)
	b:SetWidth(MINI)
	b:SetHeight(MINI)
	-- a 2 x 2 block at the bar's right end
	local col, row = math.mod(index - 1, 2), math.floor((index - 1) / 2)
	b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD - (1 - col) * (MINI + 4), -PAD - row * (MINI + 4))
	local t = A.Tex(b, "ARTWORK", icon)
	t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	t:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	A.Border(b, C.edge, 1, "OVERLAY")
	local hl = A.Tex(b, "HIGHLIGHT", A.MEDIA .. "glow")
	hl:SetBlendMode("ADD")
	hl:SetAllPoints(b)
	hl:SetVertexColor(C.aether[1], C.aether[2], C.aether[3], 0.8)
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText(label, 1, 1, 1)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return b
end

------------------------------------------------------------------------
-- Effects strip: talents' clocks and summons
------------------------------------------------------------------------

local function Effect(i)
	local e = effects[i]
	if e then
		return e
	end
	e = A.Socket(strip, 26, { timerSize = 10 })
	e.frame:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", (i - 1) * 29, 0)
	e.frame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText(this.tip or "", 1, 1, 1)
		if this.sub then
			GameTooltip:AddLine(this.sub, C.steel[1], C.steel[2], C.steel[3])
		end
		GameTooltip:Show()
	end)
	e.frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	effects[i] = e
	return e
end

local function UpdateEffects()
	local n = 0
	local summons = D.Summons()
	for i = 1, table.getn(summons) do
		local g = summons[i]
		n = n + 1
		local e = Effect(n)
		e:SetIcon(A.Icon(g.icon))
		e:SetCount(A.N(g.count))
		local left = g.remaining and A.N(g.remaining) or 0
		if left > 0 then
			A.SetText(e.timer, A.Countdown(left))
		else
			A.SetText(e.timer, "")
		end
		A.Show(e.curtain, false)
		A.BorderColor(e.rim, C.good, 1)
		e.frame.tip = g.name
		e.frame.sub = A.N(g.count) > 1 and (A.N(g.count) .. " summoned") or "Summon"
		A.Show(e.frame, true)
	end
	local timers = D.Timers()
	for i = 1, table.getn(timers) do
		local t = timers[i]
		n = n + 1
		local e = Effect(n)
		e:SetIcon(A.Icon(t.icon))
		e:SetCount(0)
		e:SetCooldown(A.N(t.remaining), A.N(t.duration))
		A.BorderColor(e.rim, A.N(t.remaining) > 0 and { 0, 0, 0 } or C.aether, 1)
		e.frame.tip = t.name
		e.frame.sub = t.kind == "summon" and "Next summon" or "Cooldown"
		A.Show(e.frame, true)
	end
	for i = n + 1, table.getn(effects) do
		A.Show(effects[i].frame, false)
	end
	A.SetWidth(strip, math.max(1, n * 29 - 3))
end

------------------------------------------------------------------------

local function Update()
	local inRun = D.InRun()
	A.Show(f, inRun or A.Demo())
	if not f.aS then
		return
	end
	local spells = D.Spells()
	local bySocket = {}
	for i = 1, table.getn(spells) do
		local s = spells[i]
		local idx = s.slot == 12 and 7 or s.slot
		if idx >= 1 and idx <= 7 then
			bySocket[idx] = s
		end
	end
	for i = 1, 7 do
		local sock = sockets[i]
		local s = bySocket[i]
		local fr = sock.frame
		if s then
			sock:SetIcon(s.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			A.SetAlpha(sock.icon, 1)
			sock:SetCooldown(s.left, s.cdmax)
			fr.slot = s.slot
			fr.rank = s.rank
			fr.demoName = A.Demo() and ("Sample spell " .. i) or nil
			local r = A.N(s.rank)
			A.SetText(sock.rank, r > 0 and tostring(r) or "")
			A.Show(sock.gem, r > 0)
		else
			-- no spell here (yet): an empty socket
			local slot = i == 7 and 12 or i
			fr.slot, fr.rank, fr.demoName = slot, nil, nil
			-- an empty socket shows its recess only (the client's missing-icon art is a red slash)
			local tex = HasAction and HasAction(slot) and GetActionTexture(slot)
			if tex then
				sock:SetIcon(tex)
			end
			A.SetAlpha(sock.icon, tex and 1 or 0)
			sock:SetCooldown(0)
			A.SetText(sock.rank, "")
			A.Show(sock.gem, false)
		end
	end
	UpdateEffects()
end

local function Tick(dt)
	for i = 1, 7 do
		sockets[i]:Tick(dt)
	end
	for i = 1, table.getn(effects) do
		effects[i]:Tick(dt)
	end
end

local function Init()
	if not A.On("skills") then
		return
	end
	FadeStockBar()

	f = A.Panel("AetherHUDSkills", A.root, W, H, { bracket = 9 })
	for i = 1, 7 do
		sockets[i] = MakeSocket(i)
	end
	-- the thin gold divider before the racial
	local div = A.Tex(f, "ARTWORK")
	div:SetWidth(1)
	div:SetHeight(SLOT - 6)
	div:SetPoint("CENTER", f, "TOPLEFT", PAD + 6 * SLOT + 5 * GAP + SEP / 2, -H / 2)
	div:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.5)

	Mini(1, "Interface\\Icons\\Ability_Warrior_DefensiveStance", "Character (C)", function()
		if ToggleCharacter then
			ToggleCharacter("PaperDollFrame")
		end
	end)
	Mini(2, "Interface\\Icons\\Spell_Holy_BlessingOfStrength", "Talents (N)", function()
		if ToggleTalentFrame then
			ToggleTalentFrame()
		end
	end)
	Mini(3, "Interface\\Icons\\INV_Box_01", "Inventory (B)", function()
		if ToggleBackpack then
			ToggleBackpack()
		end
	end)
	Mini(4, "Interface\\Icons\\Spell_Nature_WispSplode", "Game menu (Esc)", function()
		if GameMenuFrame:IsShown() then
			HideUIPanel(GameMenuFrame)
		else
			ShowUIPanel(GameMenuFrame)
		end
	end)

	strip = CreateFrame("Frame", nil, f)
	strip:SetHeight(26)
	strip:SetWidth(1)
	strip:SetPoint("BOTTOM", f, "TOP", 0, 8)

	A.RegisterMover("skills", f, "Skill bar", function(fr)
		fr:SetPoint("BOTTOM", A.root, "BOTTOM", 0, 20)
	end)
	A.Every(0.1, Update)
	A.Every(0.03, Tick)
end

A.OnInit(Init)
