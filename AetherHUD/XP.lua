-- AetherHUD experience bar: Aion's long gold-to-aether strip along the bottom, cut into
-- tenths, with level, percent and progress on it, a flare at each level-up and a gem
-- counting the choices still waiting.

local A = AetherHUD
local C, D = A.C, A.D

local W, H = 600, 12

local f, bar, lvlText, pctText, numText, flare, owedGem, owedText
local lastLevel, flareLeft = nil, 0

local function Update()
	if not D.InRun() then
		A.Show(f, false)
		return
	end
	local run = D.Run()
	local lvl, xp, xpn = A.N(run.lvl), A.N(run.xp), A.N(run.xpn)
	if xpn <= 0 then
		xp, xpn = UnitXP("player") or 0, UnitXPMax("player") or 1
		if xpn <= 0 then
			A.Show(f, false)
			return
		end
	end
	A.Show(f, true)
	local frac = A.Clamp(xp / xpn, 0, 1)
	if lastLevel and lvl > lastLevel then
		bar:SetValue(frac, true)
		flareLeft = 0.9
	else
		bar:SetValue(frac, lastLevel == nil)
	end
	lastLevel = lvl
	A.SetText(lvlText, "LV " .. lvl)
	A.SetText(pctText, string.format("%.1f%%", frac * 100))
	A.SetText(numText, A.Comma(xp) .. " / " .. A.Comma(xpn))

	local owed = A.N(run.owed)
	if owed > 0 then
		A.Show(owedGem, true)
		A.SetText(owedText, tostring(owed))
		A.SetAlpha(owedGem, 0.55 + 0.45 * A.Pulse(1.2))
	else
		A.Show(owedGem, false)
		A.SetText(owedText, "")
	end

	-- stored level-ups (the game's "Level Up!" button): open them one by one
	local stored = A.Demo() and 2 or A.N(AZS_GetStoredLevels and AZS_GetStoredLevels())
	if stored > 0 then
		A.SetText(f.levelText, "LEVEL UP  x" .. stored)
		A.SetAlpha(f.levelGlow, 0.35 + 0.5 * A.Pulse(1))
		A.Show(f.levelButton, true)
	else
		A.Show(f.levelButton, false)
	end
end

local function Tick(dt)
	if not f.aS then
		return
	end
	bar:Tick(dt)
	if flareLeft > 0 then
		flareLeft = math.max(0, flareLeft - dt)
		A.SetAlpha(flare, flareLeft / 0.9)
		A.Show(flare, true)
	else
		A.Show(flare, false)
	end
end

local function Init()
	if not A.On("xp") then
		return
	end
	f = CreateFrame("Frame", "AetherHUDXP", A.root)
	f:SetFrameStrata("LOW")
	f:SetWidth(W)
	f:SetHeight(H)
	f:EnableMouse(true)

	bar = A.Bar(f, W, H, C.xp1, C.xp2)
	bar.frame:SetPoint("CENTER", f, "CENTER", 0, 0)
	A.Border(bar.frame, C.edge, 0.9, "OVERLAY")

	local over = CreateFrame("Frame", nil, bar.frame)
	over:SetAllPoints(bar.frame)
	over:SetFrameLevel(bar.frame:GetFrameLevel() + 2)
	for i = 1, 9 do
		local tick = A.Tex(over, "BACKGROUND")
		tick:SetWidth(1)
		tick:SetPoint("TOP", over, "TOPLEFT", W * i / 10, 0)
		tick:SetPoint("BOTTOM", over, "BOTTOMLEFT", W * i / 10, 0)
		tick:SetVertexColor(0, 0, 0, 0.55)
	end
	lvlText = A.Text(over, 9, true)
	lvlText:SetPoint("LEFT", over, "LEFT", 6, 0)
	lvlText:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	pctText = A.Text(over, 9)
	pctText:SetPoint("CENTER", over, "CENTER", 0, 0)
	numText = A.Text(over, 9)
	numText:SetPoint("RIGHT", over, "RIGHT", -6, 0)
	numText:SetTextColor(C.muted[1], C.muted[2], C.muted[3])

	flare = A.Tex(over, "OVERLAY", A.MEDIA .. "line")
	flare:SetBlendMode("ADD")
	flare:SetPoint("LEFT", over, "LEFT", -40, 0)
	flare:SetPoint("RIGHT", over, "RIGHT", 40, 0)
	flare:SetHeight(H * 3)
	flare:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
	flare:Hide()

	owedGem = A.Diamond(over, 18, C.gold, "OVERLAY")
	owedGem:SetPoint("LEFT", over, "RIGHT", 6, 0)
	owedText = A.Text(over, 9)
	A.Font(owedText, 9, false, "")
	owedText:SetPoint("CENTER", owedGem, "CENTER", 0, 0)
	owedText:SetTextColor(0.12, 0.08, 0.02)
	owedText:SetShadowOffset(0, 0)

	f:SetScript("OnEnter", function()
		local run = D.Run()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText("Level " .. A.N(run.lvl), C.gold[1], C.gold[2], C.gold[3])
		GameTooltip:AddDoubleLine("Experience", A.Comma(run.xp) .. " / " .. A.Comma(run.xpn), 0.8, 0.8, 0.8, 1, 1, 1)
		if A.N(run.owed) > 0 then
			GameTooltip:AddLine(A.N(run.owed) .. " choice(s) waiting (level-ups and caches)", C.gold[1], C.gold[2], C.gold[3])
		end
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local lb = A.GlassButton(f, "", 128, 22, function()
		if AZS_OpenStoredLevels and not A.Demo() then
			AZS_OpenStoredLevels()
		end
	end)
	lb:SetPoint("LEFT", f, "RIGHT", 32, 0)
	A.BorderColor(lb.aEdge, C.gold, 1)
	lb.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	local glow = A.Tex(lb, "BACKGROUND", A.MEDIA .. "glow")
	glow:SetBlendMode("ADD")
	glow:SetPoint("TOPLEFT", lb, "TOPLEFT", -24, 14)
	glow:SetPoint("BOTTOMRIGHT", lb, "BOTTOMRIGHT", 24, -14)
	glow:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
	f.levelButton, f.levelText, f.levelGlow = lb, lb.text, glow
	lb:Hide()
	lb.aS = false

	A.RegisterMover("xp", f, "Experience", function(fr)
		fr:SetPoint("BOTTOM", A.root, "BOTTOM", 0, 6)
	end)
	A.Every(0.1, Update)
	A.Every(0.03, Tick)
end

A.OnInit(Init)
