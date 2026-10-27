-- AetherHUD party and pet: your co-op friends as slim glass frames down the left (class
-- coloured, health with the same easing trail as yours, down/offline states; click to
-- target) and your pet beside the hero frame. Replaces the stock party and pet frames.

local A = AetherHUD
local C = A.C

local PW, PH = 196, 38

local holder
local members = {}
local pet

local function Member(i)
	local m = members[i]
	if m then
		return m
	end
	m = { unit = "party" .. i }
	local f = A.Panel(nil, holder, PW, PH, { bracket = 5 })
	f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(i - 1) * (PH + 6))
	f:EnableMouse(true)
	f.unit = m.unit
	f:SetScript("OnMouseUp", function()
		if arg1 == "LeftButton" then
			TargetUnit(this.unit)
		end
	end)
	f:SetScript("OnEnter", function()
		GameTooltip_SetDefaultAnchor(GameTooltip, this)
		GameTooltip:SetUnit(this.unit)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	m.frame = f
	m.name = A.Text(f, 11, true)
	m.name:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
	m.state = A.Text(f, 9)
	m.state:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -7)
	m.bar = A.Bar(f, PW - 16, 10, C.friend1, C.friend2)
	m.bar.frame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 7)
	members[i] = m
	return m
end

local function UpdateMember(m)
	local u = m.unit
	local _, token = UnitClass(u)
	local cc = A.CLASS[token and string.lower(token) or ""] or C.text
	A.SetText(m.name, UnitName(u) or "")
	A.SetTextColor(m.name, cc)
	local hp, max = UnitHealth(u) or 0, UnitHealthMax(u) or 1
	if max <= 0 then
		max = 1
	end
	if not UnitIsConnected(u) then
		A.SetText(m.state, "offline")
		A.SetTextColor(m.state, C.muted)
		m.bar:SetValue(0)
	elseif UnitIsDead(u) or UnitIsGhost(u) then
		A.SetText(m.state, "DOWN")
		A.SetTextColor(m.state, C.bad)
		m.bar:SetValue(0)
	else
		A.SetText(m.state, string.format("%d%%", math.floor(hp / max * 100 + 0.5)))
		A.SetTextColor(m.state, C.text)
		m.bar:SetValue(hp / max)
	end
end

local function UpdateParty()
	local n = GetNumPartyMembers and GetNumPartyMembers() or 0
	for i = 1, 4 do
		local exists = i <= n and UnitExists("party" .. i)
		if exists then
			local m = Member(i)
			UpdateMember(m)
			A.Show(m.frame, true)
		elseif members[i] then
			A.Show(members[i].frame, false)
		end
	end
end

local function UpdatePet()
	if not pet then
		return
	end
	if not UnitExists("pet") then
		A.Show(pet.frame, false)
		return
	end
	A.Show(pet.frame, true)
	A.SetText(pet.name, UnitName("pet") or "")
	local hp, max = UnitHealth("pet") or 0, UnitHealthMax("pet") or 1
	pet.bar:SetValue(max > 0 and hp / max or 0)
end

local function Tick(dt)
	for i = 1, 4 do
		local m = members[i]
		if m and m.frame.aS then
			m.bar:Tick(dt)
		end
	end
	if pet and pet.frame.aS then
		pet.bar:Tick(dt)
	end
end

local function Init()
	if not A.On("party") then
		return
	end
	for i = 1, 4 do
		A.Silence(getglobal("PartyMemberFrame" .. i))
	end
	A.Silence(PetFrame)

	holder = CreateFrame("Frame", "AetherHUDParty", A.root)
	holder:SetFrameStrata("LOW")
	holder:SetWidth(PW)
	holder:SetHeight(PH)
	A.RegisterMover("party", holder, "Party", function(fr)
		fr:SetPoint("TOPLEFT", A.root, "TOPLEFT", 22, -196)
	end)

	-- the pet: a small frame on the hero frame's right
	local pf = A.Panel("AetherHUDPet", A.root, 132, 30, { bracket = 4 })
	pf:EnableMouse(true)
	pf:SetScript("OnMouseUp", function()
		TargetUnit("pet")
	end)
	pet = { frame = pf }
	pet.name = A.Text(pf, 10, true)
	pet.name:SetPoint("TOPLEFT", pf, "TOPLEFT", 7, -5)
	pet.name:SetTextColor(C.good[1], C.good[2], C.good[3])
	pet.bar = A.Bar(pf, 118, 7, C.friend1, C.friend2)
	pet.bar.frame:SetPoint("BOTTOMLEFT", pf, "BOTTOMLEFT", 7, 6)
	pf:Hide()
	pf.aS = false
	A.RegisterMover("pet", pf, "Pet", function(fr)
		fr:SetPoint("TOPLEFT", A.root, "TOPLEFT", 304, -34)
	end)

	A.Every(0.2, UpdateParty)
	A.Every(0.2, UpdatePet)
	A.Every(0.03, Tick)
end

A.OnInit(Init)
