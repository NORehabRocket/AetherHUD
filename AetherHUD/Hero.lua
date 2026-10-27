-- AetherHUD hero frame: round portrait in a gold bezel, level gem, health with shield and
-- a trail for damage just taken, extra lives as diamonds, and the hero's buffs and
-- debuffs underneath. Also the red screen-edge warning at low health.

local A = AetherHUD
local C, D = A.C, A.D

local W, H = 272, 66

local f, portrait, ring, gem, level, name, sub, bar, hpText, pctText
local lives = {}
local livesMore
local buffs, debuffs
local vignette

------------------------------------------------------------------------
-- Health
------------------------------------------------------------------------

local function Health()
	local run = D.Run()
	local hp, hpm = A.N(run.hp), A.N(run.hpm)
	if hpm <= 0 then
		hp, hpm = UnitHealth("player") or 0, UnitHealthMax("player") or 1
	end
	if hpm <= 0 then
		hpm = 1
	end
	return hp, hpm, A.N(run.sh)
end

local function UpdatePortrait()
	if portrait then
		SetPortraitTexture(portrait, "player")
	end
end

------------------------------------------------------------------------
-- Buffs: the hero's auras are real ones, read straight from the client.
------------------------------------------------------------------------

local function ReadAuras(filter, max)
	local out = {}
	if A.Demo() then
		if filter == "HELPFUL" then
			local t = GetTime()
			return {
				{ icon = "Interface\\Icons\\Spell_Holy_SealOfSalvation", name = "Divine Favor", remaining = 20 - math.mod(t, 20), stacks = 1 },
				{ icon = "Interface\\Icons\\Ability_Rogue_Sprint", name = "Swiftness", remaining = 8 - math.mod(t, 8), stacks = 3 },
				{ icon = "Interface\\Icons\\Spell_Nature_Lightning", name = "Arcane Surge", permanent = true },
			}
		end
		return {}
	end
	if not GetPlayerBuff then
		return out
	end
	for i = 0, 31 do
		local id = GetPlayerBuff(i, filter)
		if not id or id < 0 then
			break
		end
		local left = GetPlayerBuffTimeLeft and GetPlayerBuffTimeLeft(id) or 0
		table.insert(out, {
			id = id,
			icon = GetPlayerBuffTexture(id),
			stacks = GetPlayerBuffApplications and GetPlayerBuffApplications(id) or 1,
			remaining = left,
			permanent = left <= 0,
			dispelType = filter == "HARMFUL" and GetPlayerBuffDispelType and GetPlayerBuffDispelType(id) or nil,
		})
		if table.getn(out) >= max then
			break
		end
	end
	return out
end

local AURA = 24

local function AuraRow(rowIndex, max)
	local row = A.AuraRow(f, AURA, max, 3)
	row.anchor = function(frame, i)
		-- from the portrait's right edge, clear of the level gem on its bezel
		frame:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 68 + (i - 1) * (AURA + 3), -6 - (rowIndex - 1) * (AURA + 16))
	end
	return row
end

-- Tooltips come from the client for real auras; right-click cancels a buff, as on the
-- stock buff frame this replaces.
local function HookTooltips(row, cancel)
	for i = 1, table.getn(row.sockets) do
		local s = row.sockets[i]
		if not s.hooked then
			s.hooked = true
			if cancel then
				s.frame:RegisterForClicks("RightButtonUp")
				s.frame:SetScript("OnClick", function()
					if this.buffId and CancelPlayerBuff and not A.Demo() then
						CancelPlayerBuff(this.buffId)
					end
				end)
			end
			s.frame:SetScript("OnEnter", function()
				GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
				if this.buffId and GameTooltip.SetPlayerBuff then
					GameTooltip:SetPlayerBuff(this.buffId)
				elseif this.tip then
					GameTooltip:SetText(this.tip, 1, 1, 1)
				end
				GameTooltip:Show()
			end)
		end
	end
end

local function UpdateAuras()
	local helpful = ReadAuras("HELPFUL", 16)
	local n = buffs:Set(helpful, buffs.anchor)
	for i = 1, n do
		buffs.sockets[i].frame.buffId = helpful[i].id
	end
	HookTooltips(buffs, true)
	local harmful = ReadAuras("HARMFUL", 8)
	-- the debuff row moves up when there are no buffs
	local rowY = n > 0 and 2 or 1
	if debuffs.row ~= rowY then
		debuffs.row = rowY
		for i = 1, table.getn(debuffs.sockets) do
			debuffs.sockets[i].placed = nil
			debuffs.sockets[i].frame:ClearAllPoints()
		end
		debuffs.anchor = function(frame, i)
			frame:SetPoint("TOPLEFT", f, "BOTTOMLEFT", (i - 1) * (AURA + 3), -6 - (rowY - 1) * (AURA + 16))
		end
	end
	local m = debuffs:Set(harmful, debuffs.anchor)
	for i = 1, m do
		debuffs.sockets[i].frame.buffId = harmful[i].id
		if not harmful[i].dispelType then
			A.BorderColor(debuffs.sockets[i].rim, C.bad, 1)
		end
	end
	HookTooltips(debuffs)
end

------------------------------------------------------------------------

-- Red screen edges below 35% health, throbbing faster below 20%.
local function MakeVignette()
	local holder = CreateFrame("Frame", "AetherHUDVignette", A.root)
	holder:SetFrameStrata("BACKGROUND")
	holder:SetAllPoints(UIParent)
	local t = A.Tex(holder, "BACKGROUND", A.MEDIA .. "vignette")
	t:SetAllPoints(holder)
	t:SetVertexColor(0.85, 0.05, 0.03, 1)
	t:Hide()
	t.aS = false
	return t
end

local function UpdateVignette(frac, pulse)
	if not vignette then
		return
	end
	if D.InRun() and frac < 0.35 then
		local strength = (0.35 - frac) / 0.35
		A.SetAlpha(vignette, (0.25 + 0.45 * strength) * (0.6 + 0.4 * pulse))
		A.Show(vignette, true)
	else
		A.Show(vignette, false)
	end
end

local function Update()
	local hp, hpm, sh = Health()
	local frac = hp / hpm
	bar:SetValue(frac)
	bar:SetExtra(sh / hpm)
	local text = A.Comma(hp) .. " / " .. A.Comma(hpm)
	if sh > 0 then
		text = text .. A.Hex(C.shield) .. "  +" .. A.Comma(sh) .. "|r"
	end
	A.SetText(hpText, text)
	A.SetText(pctText, string.format("%.0f%%", frac * 100))

	local run, zone = D.Run(), D.Zone()
	local lvl = A.N(run.lvl)
	if lvl <= 0 then
		lvl = UnitLevel("player") or 1
	end
	A.SetText(level, tostring(lvl))
	A.SetText(name, zone.hero or UnitName("player") or "")
	local cls = zone.class
	if not cls then
		local _, token = UnitClass("player")
		cls = token and string.lower(token)
	end
	local cc = A.CLASS[cls or ""] or C.steel
	local cname = zone.cname or UnitClass("player") or ""
	local rname = zone.rname or UnitRace("player") or ""
	A.SetText(sub, A.Hex(cc) .. cname .. "|r" .. A.Hex(C.muted) .. "  " .. rname .. "|r")

	-- lives as diamonds
	local n = A.N(run.lives)
	for i = 1, table.getn(lives) do
		A.Show(lives[i], i <= n)
	end
	if n > table.getn(lives) then
		A.SetText(livesMore, "+" .. (n - table.getn(lives)))
	else
		A.SetText(livesMore, "")
	end

	-- low health: the frame's hairline and the screen edges glow red
	local low = D.InRun() and frac < 0.35
	local pulse = A.Pulse(frac < 0.2 and 1.6 or 1)
	if low then
		A.PanelAlert(f, C.bad, 0.5 + 0.5 * pulse)
	else
		A.PanelAlert(f, nil)
	end
	UpdateVignette(frac, pulse)
end

local function Tooltip()
	GameTooltip:SetOwner(f, "ANCHOR_BOTTOMRIGHT")
	local zone = D.Zone()
	GameTooltip:SetText(zone.hero or UnitName("player") or "Hero", C.gold[1], C.gold[2], C.gold[3])
	local s = D.Stats()
	local function pct(v)
		return string.format("%+.0f%%", (v or 0) * 100)
	end
	local rows = {
		{ "Damage", s.dmg and pct(s.dmg - 1) },
		{ "Haste", s.cd and pct(1 - s.cd) },
		{ "Crit", s.crit and string.format("%.1f%%", s.crit * 100) },
		{ "Crit damage", s.cm and string.format("%.0f%%", s.cm * 100) },
		{ "Armor", s.arm and string.format("%.0f%%", s.arm * 100) },
		{ "Regen", s.reg and string.format("%.1f/s", s.reg) },
		{ "Area", s.area and pct(s.area - 1) },
		{ "Targets", s.cnt and string.format("+%d", s.cnt) },
		{ "Echo", s.echo and string.format("%.0f%%", s.echo * 100) },
		{ "Speed", s.spd and pct(s.spd - 1) },
		{ "Lifesteal", s.lch and string.format("%.1f%%", s.lch * 100) },
		{ "Kill heal", s.heal and string.format("%.0f", s.heal) },
		{ "Luck", s.luck and pct(s.luck) },
	}
	local any = false
	for i = 1, table.getn(rows) do
		if rows[i][2] then
			GameTooltip:AddDoubleLine(rows[i][1], rows[i][2], C.steel[1], C.steel[2], C.steel[3], 1, 1, 1)
			any = true
		end
	end
	if not any then
		GameTooltip:AddLine("Stats show once a run starts.", 0.7, 0.7, 0.7)
	end
	GameTooltip:Show()
end

local function Tick(dt)
	bar:Tick(dt)
	for i = 1, table.getn(buffs.sockets) do
		buffs.sockets[i]:Tick(dt)
	end
end

local function Init()
	if A.On("vignette") then
		vignette = MakeVignette()
	end
	if not A.On("hero") then
		-- the low-health glow works without the hero frame too
		if vignette then
			A.Every(0.1, function()
				local hp, hpm = Health()
				UpdateVignette(hp / hpm, A.Pulse(1))
			end)
		end
		return
	end
	A.Silence(PlayerFrame)
	-- the buff rows under the hero frame take the stock buff frame's place
	A.Silence(BuffFrame)
	A.Silence(TemporaryEnchantFrame)

	f = A.Panel("AetherHUDHero", A.root, W, H)
	A.UnitClicks(f, "player")
	f:SetScript("OnEnter", Tooltip)
	f:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- portrait in its bezel, overhanging the panel's left edge
	local pf = CreateFrame("Frame", nil, f)
	pf:SetWidth(72)
	pf:SetHeight(72)
	pf:SetPoint("CENTER", f, "LEFT", 30, 0)
	pf:SetFrameLevel(f:GetFrameLevel() + 3)
	local disc = A.Tex(pf, "BACKGROUND", A.MEDIA .. "glow")
	disc:SetVertexColor(0, 0, 0, 0.9)
	disc:SetAllPoints(pf)
	portrait = pf:CreateTexture(nil, "BORDER")
	portrait:SetWidth(60)
	portrait:SetHeight(60)
	portrait:SetPoint("CENTER", pf, "CENTER", 0, 0)
	ring = A.Tex(pf, "ARTWORK", A.MEDIA .. "ring")
	ring:SetWidth(72)
	ring:SetHeight(72)
	ring:SetPoint("CENTER", pf, "CENTER", 0, 0)
	ring:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
	local glint = A.Tex(pf, "OVERLAY", A.MEDIA .. "glow")
	glint:SetBlendMode("ADD")
	glint:SetWidth(30)
	glint:SetHeight(14)
	glint:SetPoint("TOP", pf, "TOP", 0, -2)
	glint:SetVertexColor(C.aether[1], C.aether[2], C.aether[3], 0.35)

	-- level gem on the bezel
	local gf = CreateFrame("Frame", nil, pf)
	gf:SetAllPoints(pf)
	gf:SetFrameLevel(pf:GetFrameLevel() + 2)
	local gemShadow = A.Diamond(gf, 28, { 0, 0, 0 }, "ARTWORK")
	gemShadow:SetPoint("CENTER", pf, "BOTTOMLEFT", 12, 12)
	gem = A.Diamond(gf, 24, C.gold, "OVERLAY")
	gem:SetPoint("CENTER", pf, "BOTTOMLEFT", 12, 12)
	level = A.Text(gf, 11)
	A.Font(level, 11, false, "")
	level:SetPoint("CENTER", gem, "CENTER", 0, 0)
	level:SetTextColor(0.12, 0.08, 0.02)
	level:SetShadowOffset(0, 0)

	name = A.Text(f, 13, true)
	name:SetPoint("TOPLEFT", f, "TOPLEFT", 72, -7)
	name:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	sub = A.Text(f, 9)
	sub:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -49)

	bar = A.Bar(f, W - 80, 14, C.hp1, C.hp2)
	bar.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 72, -26)
	local bt = CreateFrame("Frame", nil, bar.frame)
	bt:SetAllPoints(bar.frame)
	bt:SetFrameLevel(bar.frame:GetFrameLevel() + 2)
	hpText = A.Text(bt, 10)
	hpText:SetPoint("LEFT", bar.frame, "LEFT", 5, 0)
	pctText = A.Text(bt, 10)
	pctText:SetPoint("RIGHT", bar.frame, "RIGHT", -4, 0)

	local livesLabel = A.Text(f, 8, true)
	livesLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 72, -48)
	livesLabel:SetText("LIVES")
	livesLabel:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	for i = 1, 6 do
		local d = A.Diamond(f, 11, C.aether, "ARTWORK")
		d:SetPoint("LEFT", livesLabel, "RIGHT", 4 + (i - 1) * 11, 0)
		lives[i] = d
	end
	livesMore = A.Text(f, 9)
	livesMore:SetPoint("LEFT", lives[6], "RIGHT", 3, 0)

	buffs = AuraRow(1, 16)
	debuffs = AuraRow(2, 8)
	debuffs.row = 2

	A.RegisterMover("hero", f, "Hero", function(fr)
		fr:SetPoint("TOPLEFT", A.root, "TOPLEFT", 22, -16)
	end)

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:RegisterEvent("UNIT_PORTRAIT_UPDATE")
	ev:RegisterEvent("UNIT_MODEL_CHANGED")
	ev:SetScript("OnEvent", function()
		if event == "PLAYER_ENTERING_WORLD" or arg1 == "player" then
			UpdatePortrait()
		end
	end)
	UpdatePortrait()
	local hp, hpm = Health()
	bar:SetValue(hp / hpm, true)

	A.Every(0.1, Update)
	A.Every(0.25, UpdateAuras)
	A.Every(0.03, Tick)
end

A.OnInit(Init)
