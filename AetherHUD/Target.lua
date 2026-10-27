-- AetherHUD target frame: what you have targeted, tagged with what it is to the run
-- (final boss, boss, guardian, elite), its real health from AZS_TARGET and its debuffs.

local A = AetherHUD
local C, D = A.C, A.D

local W, H = 244, 50

local f, tag, name, state, lvl, bar, hpText, pctText, auras

local KINDS = {
	final = { "FINAL BOSS", A.C.gold, A.C.boss1, A.C.boss2 },
	boss = { "BOSS", A.C.bad, A.C.boss1, A.C.boss2 },
	guardian = { "GUARDIAN", A.C.violet, A.C.guard1, A.C.guard2 },
	elite = { "ELITE", A.C.gold, A.C.boss1, A.C.boss2 },
	normal = { "", A.C.muted, A.C.boss1, A.C.boss2 },
	player = { "", A.C.muted, A.C.friend1, A.C.friend2 },
	other = { "", A.C.muted, A.C.friend1, A.C.friend2 },
	dead = { "DEAD", A.C.muted, { 0.2, 0.2, 0.2 }, { 0.35, 0.35, 0.35 } },
}

local function TargetDebuffs(t)
	local id = A.N(t.id)
	if id > 0 and (t.kind == "boss" or t.kind == "final" or t.kind == "guardian") then
		return D.Debuffs(id)
	end
	local out = {}
	if not UnitExists("target") then
		return out
	end
	for i = 1, 16 do
		local icon, stacks, dispel = UnitDebuff("target", i)
		if not icon then
			break
		end
		table.insert(out, { icon = icon, stacks = stacks, dispelType = dispel })
	end
	return out
end

local function Update()
	local t = D.Target()
	local exists = UnitExists("target") or t.demo
	if not exists then
		A.Show(f, false)
		return
	end
	A.Show(f, true)
	local unitName = UnitName("target")
	local own = t.demo or (t.name and t.name == unitName)
	local kind = (own and t.kind) or (AZS_UnitKind and AZS_UnitKind("target")) or "other"
	if UnitIsPlayer("target") or (UnitIsFriend and UnitIsFriend("player", "target")) then
		kind = "other"
	end
	if UnitExists("target") and UnitIsDead("target") then
		kind = "dead"
	end
	local k = KINDS[kind] or KINDS.normal
	A.SetText(tag, k[1])
	A.SetTextColor(tag, k[2])
	A.SetText(name, own and t.name or unitName or "")
	bar:SetColors(k[3], k[4])

	local hp, hpm
	if own and A.N(t.hpm) > 0 then
		hp, hpm = A.N(t.hp), A.N(t.hpm)
	else
		hp, hpm = UnitHealth("target") or 0, UnitHealthMax("target") or 1
	end
	if hpm <= 0 then
		hpm = 1
	end
	local frac = hp / hpm
	bar:SetValue(frac)
	if hpm == 100 and not own then
		A.SetText(hpText, "")
	else
		A.SetText(hpText, A.Short(hp) .. " / " .. A.Short(hpm))
	end
	A.SetText(pctText, string.format("%.0f%%", frac * 100))

	if own and A.Flag(t.state) then
		A.SetText(state, kind == "guardian" and "AWAKE" or "ENRAGED")
		A.SetTextColor(state, kind == "guardian" and C.violet or C.rage2)
		A.SetAlpha(state, 0.5 + 0.5 * A.Pulse(1.4))
	else
		A.SetText(state, "")
	end
	local level = UnitExists("target") and UnitLevel("target")
	if level and level > 0 then
		A.SetText(lvl, "Lv " .. level)
	elseif level == -1 then
		A.SetText(lvl, "Lv ??")
	else
		A.SetText(lvl, "")
	end
	auras:Set(TargetDebuffs(t), auras.anchor)
end

local function Init()
	if not A.On("target") then
		return
	end
	A.Silence(TargetFrame)

	f = A.Panel("AetherHUDTarget", A.root, W, H)

	tag = A.Text(f, 9, true)
	tag:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
	name = A.Text(f, 12, true)
	name:SetPoint("LEFT", tag, "RIGHT", 4, 0)
	state = A.Text(f, 9, true)
	state:SetPoint("LEFT", name, "RIGHT", 6, 0)
	lvl = A.Text(f, 9)
	lvl:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
	lvl:SetTextColor(C.muted[1], C.muted[2], C.muted[3])

	bar = A.Bar(f, W - 16, 13, C.boss1, C.boss2)
	bar.frame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 9)
	local bt = CreateFrame("Frame", nil, bar.frame)
	bt:SetAllPoints(bar.frame)
	bt:SetFrameLevel(bar.frame:GetFrameLevel() + 2)
	hpText = A.Text(bt, 9)
	hpText:SetPoint("LEFT", bar.frame, "LEFT", 4, 0)
	pctText = A.Text(bt, 10)
	pctText:SetPoint("RIGHT", bar.frame, "RIGHT", -4, 0)

	auras = A.AuraRow(f, 20, 8, 3)
	auras.anchor = function(frame, i)
		frame:SetPoint("TOPLEFT", f, "BOTTOMLEFT", (i - 1) * 23, -5)
	end

	-- the stock combo points hung on the stock target frame: give them a home under ours
	if ComboFrame then
		ComboFrame:SetParent(f)
		ComboFrame:ClearAllPoints()
		ComboFrame:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 4, 4)
	end

	-- above the skill bar, near the hero: the top centre belongs to the clock and bosses
	A.RegisterMover("target", f, "Target", function(fr)
		fr:SetPoint("BOTTOM", A.root, "BOTTOM", 0, 152)
	end)

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_TARGET_CHANGED")
	ev:SetScript("OnEvent", function()
		local t = D.Target()
		local hp, hpm = UnitHealth("target") or 0, UnitHealthMax("target") or 1
		if t.name and t.name == UnitName("target") and A.N(t.hpm) > 0 then
			hp, hpm = A.N(t.hp), A.N(t.hpm)
		end
		bar:SetValue(hpm > 0 and hp / hpm or 0, true)
		Update()
	end)
	A.Every(0.1, Update)
	A.Every(0.03, function(dt)
		if f.aS then
			bar:Tick(dt)
		end
	end)
end

A.OnInit(Init)
