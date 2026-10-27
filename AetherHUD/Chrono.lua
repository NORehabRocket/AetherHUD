-- AetherHUD chronometer: the run clock, a timeline with every boss of the zone as a
-- diamond on it, and the next boss's countdown. Stands in for the game's "clock".

local A = AetherHUD
local C, D = A.C, A.D

local W, H = 380, 68
local TRACK_W = 340

local f, title, clock, total, phaseTag, nextLine, track, fill, spark, pins
local markers = {}

local PHASES = {
	paused = { "PAUSED", A.C.gold },
	choosing = { "CHOOSING", A.C.aether },
	dead = { "FALLEN", A.C.bad },
	victory = { "VICTORY", A.C.gold },
}

local function Marker(i)
	local m = markers[i]
	if m then
		return m
	end
	-- one layer each: the client draws textures that share a layer in no fixed order, so a
	-- shadow beside its gem in OVERLAY flickered over it
	m = {}
	m.shadow = A.Diamond(pins, 16, { 0, 0, 0 }, "BORDER")
	m.glow = A.Tex(pins, "ARTWORK", A.MEDIA .. "glow")
	m.glow:SetBlendMode("ADD")
	m.glow:SetWidth(30)
	m.glow:SetHeight(30)
	m.gem = A.Diamond(pins, 12, C.steel, "OVERLAY")
	markers[i] = m
	return m
end

local function PlaceMarker(m, x, size)
	if m.x == x and m.size == size then
		return
	end
	m.x, m.size = x, size
	m.shadow:ClearAllPoints()
	m.shadow:SetPoint("CENTER", track, "LEFT", x, 0)
	m.shadow:SetWidth(size + 4)
	m.shadow:SetHeight(size + 4)
	m.gem:ClearAllPoints()
	m.gem:SetPoint("CENTER", track, "LEFT", x, 0)
	m.gem:SetWidth(size)
	m.gem:SetHeight(size)
	m.glow:ClearAllPoints()
	m.glow:SetPoint("CENTER", track, "LEFT", x, 0)
end

local function Update()
	local phase = D.Phase()
	if not D.InRun() then
		A.Show(f, false)
		return
	end
	A.Show(f, true)
	local run, zone = D.Run(), D.Zone()
	local t = D.Time() or 0
	local len = D.RunLength()
	local endless = A.Flag(run.endl)

	-- the zone line only changes once a run: rebuild it only then (less garbage for 5.0's GC)
	local zname, zsub = zone.zname or "", zone.zsub or ""
	if title.zname ~= zname or title.zsub ~= zsub then
		title.zname, title.zsub = zname, zsub
		local head = A.Hex(C.steel) .. string.upper(zname) .. "|r"
		if zsub ~= "" then
			head = head .. A.Hex(C.muted) .. "  \194\183  " .. zsub .. "|r"
		end
		A.SetText(title, head)
	end

	A.SetText(clock, A.Clock(t))
	if endless then
		A.SetTextColor(clock, C.violet)
		A.SetText(total, A.Hex(C.violet) .. "ENDLESS|r")
	else
		A.SetTextColor(clock, C.text)
		A.SetText(total, "/ " .. A.Clock(len))
	end

	local ph = PHASES[phase or ""]
	if ph then
		A.SetText(phaseTag, ph[1])
		A.SetTextColor(phaseTag, ph[2])
		A.SetAlpha(phaseTag, 0.55 + 0.45 * A.Pulse(0.8))
	else
		A.SetText(phaseTag, "")
	end

	-- timeline
	local frac = A.Clamp(t / len, 0, 1)
	A.SetWidth(fill, math.max(0.5, TRACK_W * frac))
	A.Show(spark, frac > 0 and frac < 1)

	local sched = D.Schedule()
	local n = table.getn(sched)
	local pulse = A.Pulse(1.6)
	for i = 1, n do
		local b = sched[i]
		local m = Marker(i)
		local final = A.Flag(b.final)
		local x = TRACK_W * A.Clamp(A.N(b.at) / len, 0, 1)
		PlaceMarker(m, x, final and 16 or 12)
		local state = b.state
		if state == "dead" then
			A.SetColor(m.gem, 0.35, 0.40, 0.46, 0.9)
			A.SetAlpha(m.glow, 0)
		elseif state == "up" then
			A.SetColor(m.gem, C.bad[1], C.bad[2], C.bad[3], 1)
			A.SetColor(m.glow, C.bad[1], C.bad[2], C.bad[3], 1)
			A.SetAlpha(m.glow, 0.35 + 0.65 * pulse)
		elseif final then
			A.SetColor(m.gem, C.gold[1], C.gold[2], C.gold[3], 1)
			A.SetColor(m.glow, C.gold[1], C.gold[2], C.gold[3], 1)
			A.SetAlpha(m.glow, 0.45)
		else
			A.SetColor(m.gem, C.steel[1], C.steel[2], C.steel[3], 1)
			A.SetAlpha(m.glow, 0)
		end
		A.Show(m.gem, true)
		A.Show(m.shadow, true)
		A.Show(m.glow, state == "up" or (final and state ~= "dead"))
	end
	for i = n + 1, table.getn(markers) do
		A.Show(markers[i].gem, false)
		A.Show(markers[i].shadow, false)
		A.Show(markers[i].glow, false)
	end

	-- next boss
	local up = D.Upcoming()
	local nb = up[1]
	local name, left
	if nb and nb.name then
		name, left = nb.name, A.N(nb.left)
	elseif A.N(run.nb) >= 0 and run.nb ~= nil then
		name, left = (run.nbn ~= "" and run.nbn) or "Boss", A.N(run.nb)
	end
	if phase == "victory" then
		A.SetText(nextLine, A.Hex(C.gold) .. "VICTORY|r")
	elseif name then
		local soon = left <= 10
		local tc = soon and C.bad or C.aether
		local label = (nb and A.Flag(nb.final)) and "FINAL" or "NEXT"
		A.SetText(nextLine, A.Hex(C.muted) .. label .. "  |r" .. A.Hex(C.text) .. name .. "  |r" .. A.Hex(tc) .. A.Clock(left) .. "|r")
		A.SetAlpha(nextLine, soon and (0.5 + 0.5 * pulse) or 1)
		A.PanelAlert(f, soon and C.bad or nil, 0.6 + 0.4 * pulse)
	elseif A.Flag(run.won) then
		A.SetText(nextLine, A.Hex(C.gold) .. "Final boss defeated|r")
		A.SetAlpha(nextLine, 1)
	else
		A.SetText(nextLine, "")
	end
	if not (name and left <= 10) then
		A.PanelAlert(f, nil)
	end
end

local MODS = { "Enemy density", "Enemy health", "Enemy damage", "Enemy speed" }

local function Tooltip()
	local zone = D.Zone()
	GameTooltip:SetOwner(f, "ANCHOR_BOTTOM")
	GameTooltip:SetText(zone.zname or "Azeroth Survivors", C.gold[1], C.gold[2], C.gold[3])
	if zone.zsub and zone.zsub ~= "" then
		GameTooltip:AddLine(zone.zsub, C.steel[1], C.steel[2], C.steel[3])
	end
	if zone.diff then
		GameTooltip:AddDoubleLine("Difficulty", string.format("x%.2f", A.N(zone.diff)), 0.8, 0.8, 0.8, 1, 1, 1)
	end
	if type(zone.mods) == "string" then
		local i = 0
		for v in string.gfind(zone.mods, "%d+") do
			i = i + 1
			if MODS[i] and v ~= "100" then
				GameTooltip:AddDoubleLine(MODS[i], v .. "%", 0.8, 0.8, 0.8, 1, 0.6, 0.4)
			end
		end
	end
	local sched = D.Schedule()
	if table.getn(sched) > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Boss timeline: a diamond for each boss at the time it comes", C.steel[1], C.steel[2], C.steel[3])
		GameTooltip:AddLine("grey = to come, red glow = alive now, dim = slain, gold = final boss", C.muted[1], C.muted[2], C.muted[3])
		for i = 1, table.getn(sched) do
			local b = sched[i]
			local r, g, bl = 0.75, 0.82, 0.9
			if b.state == "dead" then
				r, g, bl = 0.45, 0.45, 0.45
			elseif b.state == "up" then
				r, g, bl = 1, 0.35, 0.3
			elseif A.Flag(b.final) then
				r, g, bl = 1, 0.8, 0.4
			end
			local state = b.state == "dead" and "slain" or b.state == "up" and "alive" or A.Clock(A.N(b.at))
			GameTooltip:AddDoubleLine(b.name or "?", state, r, g, bl, r, g, bl)
		end
	end
	GameTooltip:Show()
end

local function Init()
	if not A.On("chrono") then
		return
	end
	f = A.Panel("AetherHUDChrono", A.root, W, H)
	f:EnableMouse(true)
	f:SetScript("OnEnter", Tooltip)
	f:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	title = A.Text(f, 9, true)
	title:SetPoint("TOP", f, "TOP", 0, -6)

	clock = A.Text(f, 22)
	clock:SetPoint("TOP", f, "TOP", -14, -17)
	total = A.Text(f, 10)
	total:SetPoint("BOTTOMLEFT", clock, "BOTTOMRIGHT", 5, 3)
	total:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	phaseTag = A.Text(f, 10, true)
	phaseTag:SetPoint("RIGHT", clock, "LEFT", -12, 0)

	track = CreateFrame("Frame", nil, f)
	track:SetWidth(TRACK_W)
	track:SetHeight(5)
	track:SetPoint("TOP", f, "TOP", 0, -45)
	local bg = A.Tex(track, "BACKGROUND")
	bg:SetAllPoints(track)
	bg:SetVertexColor(0, 0, 0, 0.6)
	A.Border(track, C.edge, 0.7, "BORDER", track, -1)
	fill = A.Tex(track, "ARTWORK", A.MEDIA .. "bar")
	fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
	fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
	A.Gradient(fill, "HORIZONTAL", { 0.10, 0.35, 0.55 }, C.aether, 0.9, 1)
	spark = A.Tex(track, "OVERLAY", A.SPARK)
	spark:SetBlendMode("ADD")
	spark:SetWidth(10)
	spark:SetHeight(16)
	spark:SetPoint("CENTER", fill, "RIGHT", 0, 0)
	pins = CreateFrame("Frame", nil, track)
	pins:SetAllPoints(track)
	pins:SetFrameLevel(track:GetFrameLevel() + 2)

	nextLine = A.Text(f, 10)
	nextLine:SetPoint("TOP", track, "BOTTOM", 0, -6)

	A.RegisterMover("chrono", f, "Chronometer", function(fr)
		fr:SetPoint("TOP", A.root, "TOP", 0, -6)
	end)
	A.Every(0.1, Update)
end

A.OnInit(Init)
