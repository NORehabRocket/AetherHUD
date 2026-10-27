-- AetherHUD boss bars: every boss alive and every awake guardian, stacked under the
-- chronometer in Aion's target style, with their debuffs counting down beside them.
-- Click a bar to target that boss. Stands in for the game's "bosses".

local A = AetherHUD
local C, D = A.C, A.D

local W, H, GAP = 360, 36, 5
local MAX = 5

local holder
local pills = {}

local function Pill(i)
	local p = pills[i]
	if p then
		return p
	end
	p = {}
	local f = A.Panel(nil, holder, W, H, { bracket = 6 })
	f:SetPoint("TOP", holder, "TOP", 0, -(i - 1) * (H + GAP))
	f:EnableMouse(true)
	f:SetScript("OnMouseUp", function()
		if this.unitName and TargetByName then
			TargetByName(this.unitName, true)
		end
	end)
	p.frame = f

	p.tag = A.Text(f, 9, true)
	p.tag:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
	p.name = A.Text(f, 12, true)
	p.name:SetPoint("LEFT", p.tag, "RIGHT", 5, 0)
	p.rage = A.Text(f, 9, true)
	p.rage:SetPoint("LEFT", p.name, "RIGHT", 6, 0)
	p.rage:SetTextColor(C.rage2[1], C.rage2[2], C.rage2[3])
	p.pct = A.Text(f, 12)
	p.pct:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -5)

	p.bar = A.Bar(f, W - 16, 11, C.boss1, C.boss2)
	p.bar.frame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 6)
	local bt = CreateFrame("Frame", nil, p.bar.frame)
	bt:SetAllPoints(p.bar.frame)
	bt:SetFrameLevel(p.bar.frame:GetFrameLevel() + 2)
	p.hp = A.Text(bt, 9)
	p.hp:SetPoint("RIGHT", p.bar.frame, "RIGHT", -4, 0)

	p.glow = A.Tex(f, "BACKGROUND", A.MEDIA .. "glow")
	p.glow:SetBlendMode("ADD")
	p.glow:SetPoint("TOPLEFT", f, "TOPLEFT", -24, 18)
	p.glow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 24, -18)
	p.glow:SetVertexColor(C.rage2[1], C.rage2[2], C.rage2[3], 1)
	p.glow:SetAlpha(0)

	p.auras = A.AuraRow(f, 20, 7, 3)
	p.auras.anchor = function(frame, n)
		frame:SetPoint("LEFT", f, "RIGHT", 6 + (n - 1) * 23, 4)
	end
	pills[i] = p
	return p
end

local function Collect()
	local list = {}
	local bosses = D.Bosses()
	-- the final boss leads, the others keep their spawn order
	for pass = 1, 2 do
		for i = 1, table.getn(bosses) do
			local b = bosses[i]
			local final = A.Flag(b.final)
			if (pass == 1) == final then
				table.insert(list, { id = b.id, name = b.name, hp = b.hp, hpm = b.hpm, final = final,
					enraged = A.Flag(b.enraged), debuffs = b.debuffs, kind = final and "final" or "boss" })
			end
		end
	end
	local guardians = D.Guardians()
	for i = 1, table.getn(guardians) do
		local g = guardians[i]
		if A.Flag(g.awake) then
			table.insert(list, { id = g.id, name = g.name, hp = g.hp, hpm = g.hpm, debuffs = g.debuffs, kind = "guardian" })
		end
	end
	return list
end

local TAGS = {
	final = { "FINAL BOSS", A.C.gold },
	boss = { "BOSS", A.C.bad },
	guardian = { "GUARDIAN", A.C.violet },
}

local function Update(dt)
	if not D.InRun() then
		A.Show(holder, false)
		return
	end
	A.Show(holder, true)
	local list = Collect()
	local n = math.min(table.getn(list), MAX)
	local pulse = A.Pulse(1.4)
	for i = 1, n do
		local u = list[i]
		local p = Pill(i)
		local fresh = p.id ~= u.id
		p.id = u.id
		p.frame.unitName = u.name
		local tag = TAGS[u.kind]
		A.SetText(p.tag, tag[1])
		A.SetTextColor(p.tag, tag[2])
		A.SetText(p.name, u.name or "")
		local hp, hpm = A.N(u.hp), A.N(u.hpm)
		if hpm <= 0 then
			hpm = 1
		end
		local frac = hp / hpm
		A.SetText(p.pct, string.format("%.0f%%", frac * 100))
		A.SetText(p.hp, A.Short(hp) .. " / " .. A.Short(hpm))
		p.bar:SetValue(frac, fresh)
		if u.kind == "guardian" then
			p.bar:SetColors(C.guard1, C.guard2)
		elseif u.enraged then
			p.bar:SetColors(C.rage1, C.rage2)
		else
			p.bar:SetColors(C.boss1, C.boss2)
		end
		if u.enraged then
			A.SetText(p.rage, "ENRAGED")
			A.SetAlpha(p.rage, 0.5 + 0.5 * pulse)
			A.SetAlpha(p.glow, 0.25 + 0.35 * pulse)
			A.PanelAlert(p.frame, C.rage2, 0.6 + 0.4 * pulse)
		else
			A.SetText(p.rage, "")
			A.SetAlpha(p.glow, 0)
			A.PanelAlert(p.frame, nil)
		end
		p.auras:Set(u.debuffs or D.Debuffs(u.id), p.auras.anchor)
		A.Show(p.frame, true)
	end
	for i = n + 1, table.getn(pills) do
		pills[i].id = nil
		A.Show(pills[i].frame, false)
	end
end

local function Tick(dt)
	for i = 1, table.getn(pills) do
		local p = pills[i]
		if p.frame.aS then
			p.bar:Tick(dt)
		end
	end
end

local function Init()
	if not A.On("bosses") then
		return
	end
	holder = CreateFrame("Frame", "AetherHUDBosses", A.root)
	holder:SetWidth(W)
	holder:SetHeight(H)
	holder:SetFrameStrata("LOW")
	A.RegisterMover("bosses", holder, "Boss bars", function(fr)
		fr:SetPoint("TOP", A.root, "TOP", 0, -82)
	end)
	A.Every(0.1, Update)
	A.Every(0.03, Tick)
end

A.OnInit(Init)
