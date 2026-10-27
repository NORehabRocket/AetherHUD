-- AetherHUD enemy plates: the client's nameplates (WorldFrame children wearing the stock
-- Nameplate-Border) re-dressed in Aion's style. A slim glass bar under the name, gold
-- trim for elites, violet for guardians, red for bosses; a gold gem and halo mark your
-- target. Full-health fodder can stay hidden until it is hit, so a swarm doesn't bury
-- the screen. Also tells the floating numbers where each enemy is.

local A = AetherHUD
local C, D = A.C, A.D

local BORDER = "Interface\\Tooltips\\Nameplate-Border"
local PW, PH = 84, 5

local STYLE = {
	normal = { name = { 0.93, 0.89, 0.82 }, bar = { 0.86, 0.16, 0.12 }, w = 1 },
	elite = { name = A.C.gold, bar = { 1.00, 0.56, 0.10 }, trim = A.C.gold, w = 1.15 },
	guardian = { name = A.C.violet, bar = A.C.guard2, trim = A.C.violet, w = 1.25 },
	boss = { name = { 1.00, 0.46, 0.36 }, bar = A.C.boss2, trim = A.C.bad, w = 1.5 },
	final = { name = A.C.gold, bar = { 1.00, 0.30, 0.08 }, trim = A.C.gold, w = 1.6 },
}

local plates = {} -- plate frame -> its data
local known = 0
local kinds, guardianMax = {}, {}
local kindsStamp

local P = {}
A.Plates = P

------------------------------------------------------------------------
-- What each name is to the run (from AZS_UNITS: bosses, guardians, elites)
------------------------------------------------------------------------

local function RefreshKinds()
	local stamp = AZS_UNITS_UPDATED
	if stamp == kindsStamp then
		return
	end
	kindsStamp = stamp
	kinds, guardianMax = {}, {}
	local units = type(AZS_UNITS) == "table" and AZS_UNITS or {}
	for i = 1, table.getn(units) do
		local u = units[i]
		local name, k = u.name, u.kind
		if name then
			if k == "final" or k == "boss" then
				kinds[name] = k
			elseif k == "guardian" then
				guardianMax[name] = A.N(u.hpm)
				if not kinds[name] then
					kinds[name] = "guardian"
				end
			elseif k == "elite" and kinds[name] ~= "final" and kinds[name] ~= "boss" then
				-- a guardian is the same creature as the elites of its type: elite unless proven
				kinds[name] = "elite"
			end
		end
	end
end

------------------------------------------------------------------------
-- Dressing a plate
------------------------------------------------------------------------

local function ApplyKind(d, kind)
	d.kind = kind
	local s = STYLE[kind] or STYLE.normal
	d.name:SetTextColor(s.name[1], s.name[2], s.name[3])
	d.cr, d.cg, d.cb = s.bar[1], s.bar[2], s.bar[3]
	d.bar:SetStatusBarColor(d.cr, d.cg, d.cb)
	d.bar:SetWidth(PW * s.w)
	if s.trim then
		A.BorderColor(d.trim, s.trim, 0.95)
		for i = 1, 4 do
			A.Show(d.trim[i], true)
		end
	else
		for i = 1, 4 do
			A.Show(d.trim[i], false)
		end
	end
end

local function Adopt(plate)
	local d = { plate = plate }
	local regions = { plate:GetRegions() }
	for i = 1, table.getn(regions) do
		local r = regions[i]
		local t = r:GetObjectType()
		if t == "Texture" then
			local path = string.lower(r:GetTexture() or "")
			if string.find(path, "raidtargeting", 1, true) then
				d.raid = r
			else
				-- border, aggro glow, skull, elite dragon: our plate draws its own
				r:SetAlpha(0)
			end
		elseif t == "FontString" then
			if not d.name then
				d.name = r
			elseif not d.level then
				d.level = r
			end
		end
	end
	local kids = { plate:GetChildren() }
	for i = 1, table.getn(kids) do
		if kids[i]:GetObjectType() == "StatusBar" then
			d.bar = kids[i]
			break
		end
	end
	if not d.name or not d.bar then
		return nil
	end

	local bar = d.bar
	bar:SetStatusBarTexture(A.MEDIA .. "bar")
	bar:ClearAllPoints()
	bar:SetPoint("CENTER", plate, "CENTER", 0, -3)
	bar:SetWidth(PW)
	bar:SetHeight(PH)

	local back = CreateFrame("Frame", nil, plate)
	back:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
	back:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
	back:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
	local bg = A.Tex(back, "BACKGROUND")
	bg:SetAllPoints(back)
	bg:SetVertexColor(0.01, 0.03, 0.06, 0.85)
	A.Border(back, { 0, 0, 0 }, 1, "BORDER")
	d.trim = A.Border(back, C.gold, 0.95, "ARTWORK", back, -1)
	d.halo = A.Tex(back, "BACKGROUND", A.MEDIA .. "glow")
	d.halo:SetBlendMode("ADD")
	d.halo:SetPoint("TOPLEFT", back, "TOPLEFT", -18, 12)
	d.halo:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", 18, -12)
	d.halo:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.55)
	d.halo:Hide()

	local over = CreateFrame("Frame", nil, plate)
	over:SetAllPoints(plate)
	over:SetFrameLevel(bar:GetFrameLevel() + 2)
	local glint = A.Tex(over, "ARTWORK", A.MEDIA .. "line")
	glint:SetBlendMode("ADD")
	glint:SetPoint("LEFT", bar, "TOPLEFT", 2, 0)
	glint:SetPoint("RIGHT", bar, "TOPRIGHT", -2, 0)
	glint:SetHeight(3)
	glint:SetVertexColor(1, 1, 1, 0.45)

	d.name:SetFont(A.FONT_TITLE, 10, "OUTLINE")
	d.name:SetShadowOffset(1, -1)
	d.name:ClearAllPoints()
	d.name:SetPoint("BOTTOM", bar, "TOP", 0, 4)
	if d.level then
		d.level:SetAlpha(0)
	end
	if d.raid then
		d.raid:ClearAllPoints()
		d.raid:SetWidth(14)
		d.raid:SetHeight(14)
		d.raid:SetPoint("RIGHT", d.name, "LEFT", -3, 0)
	end

	d.marker = A.Diamond(over, 11, C.gold, "OVERLAY")
	d.marker:SetPoint("BOTTOM", d.name, "TOP", 0, 1)
	d.marker:Hide()
	d.pct = A.Text(over, 8)
	d.pct:SetPoint("LEFT", bar, "RIGHT", 4, 0)

	ApplyKind(d, "normal")
	return d
end

-- New plates are added to WorldFrame's children at the end: look only when the count moves.
local function Discover()
	local count = WorldFrame:GetNumChildren() or 0
	if count == known then
		return
	end
	local from = known + 1
	if count < known then
		from = 1
	end
	known = count
	local kids = { WorldFrame:GetChildren() }
	for i = from, table.getn(kids) do
		local f = kids[i]
		if f and not plates[f] and not f:GetName() then
			local first = f:GetRegions()
			if first and first.GetObjectType and first:GetObjectType() == "Texture" and first:GetTexture() == BORDER then
				local d = Adopt(f)
				if d then
					plates[f] = d
				end
			end
		end
	end
end

------------------------------------------------------------------------

local function Frac(d)
	local v = d.bar:GetValue() or 0
	local lo, hi = d.bar:GetMinMaxValues()
	lo, hi = lo or 0, hi or 1
	if hi <= lo then
		return 1, v, hi
	end
	return A.Clamp((v - lo) / (hi - lo), 0, 1), v, hi
end

local function Update()
	Discover()
	RefreshKinds()
	local now = GetTime()
	local smart = A.db.plates.smart
	-- your target: the plate with its name whose health matches it
	local tName, tFrac, tHp
	if UnitExists("target") and not UnitIsPlayer("target") then
		tName = UnitName("target")
		local m = UnitHealthMax("target") or 0
		tFrac = m > 0 and (UnitHealth("target") or 0) / m or nil
		local t = AZS_TARGET
		if type(t) == "table" and t.name == tName and A.N(t.hpm) > 0 then
			tHp, tFrac = A.N(t.hp), A.N(t.hp) / A.N(t.hpm)
		end
	end
	local marked = false
	for plate, d in pairs(plates) do
		if plate:IsShown() then
			local name = d.name:GetText() or ""
			if name ~= d.lastName then
				-- the client reuses plates for other enemies
				d.lastName, d.frac, d.hitAt = name, nil, nil
			end
			local frac, v, hi = Frac(d)
			if d.frac and frac < d.frac - 0.0001 then
				d.hitAt = now
			end
			d.frac = frac
			local kind = kinds[name] or "normal"
			if kind == "elite" and guardianMax[name] and hi == guardianMax[name] then
				kind = "guardian"
			end
			if kind ~= d.kind then
				ApplyKind(d, kind)
			end
			-- the client recolours bars by reaction now and then: keep ours
			if d.bar.GetStatusBarColor then
				local r, g, b = d.bar:GetStatusBarColor()
				if r and (math.abs(r - d.cr) > 0.02 or math.abs(g - d.cg) > 0.02 or math.abs(b - d.cb) > 0.02) then
					d.bar:SetStatusBarColor(d.cr, d.cg, d.cb)
				end
			end

			local isTarget = false
			if not marked and tName == name and tFrac then
				if tHp and hi > 100 then
					isTarget = math.abs(v - tHp) < 1
				else
					isTarget = math.abs(tFrac - frac) < 0.015
				end
				marked = isTarget
			end
			if isTarget ~= d.isTarget then
				d.isTarget = isTarget
				A.Show(d.marker, isTarget)
				A.Show(d.halo, isTarget)
			end
			if isTarget or kind ~= "normal" then
				A.SetText(d.pct, string.format("%d%%", math.floor(frac * 100 + 0.5)))
			else
				A.SetText(d.pct, "")
			end

			-- fodder at full health stays out of sight until it is hit
			local want = 1
			if smart and kind == "normal" and not isTarget and frac >= 0.999 then
				want = 0
			end
			if plate:GetAlpha() ~= want then
				plate:SetAlpha(want)
				if plate.EnableMouse then
					plate:EnableMouse(want > 0)
				end
			end
		end
	end
end

-- Where to float a number for a hit on `name`: above the plate of that name that just
-- lost health, else the one nearest the hero. nil when no such plate is up.
function P.Locate(name)
	if not name then
		return nil
	end
	local now = GetTime()
	local ui = UIParent:GetEffectiveScale()
	local cx, cy = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
	local bx, by, best
	for plate, d in pairs(plates) do
		if d.lastName == name and plate:IsShown() then
			local x, y = plate:GetCenter()
			if x then
				local s = plate:GetEffectiveScale() / ui
				x, y = x * s, (plate:GetTop() or y) * s
				local dx, dy = x - cx, y - cy
				local score = dx * dx + dy * dy
				if d.hitAt and now - d.hitAt < 0.4 then
					score = score - 1e9 -- just lost health: surely the one
				end
				if not best or score < best then
					best, bx, by = score, x, y
				end
			end
		end
	end
	return bx, by
end

local function Init()
	if not A.On("plates") then
		return
	end
	-- plates only exist while the client shows them (V toggles them)
	if not NAMEPLATES_ON and ShowNameplates then
		ShowNameplates()
	end
	A.Every(0.1, Update)
end

A.OnInit(Init)
