-- AetherHUD downed allies: where a party member who went down lies, so you can reach them
-- and bring them back (a revive starts when you stand next to them). A pulsing red gem on
-- the minimap's ring points at each one, their party frame gets a small compass, and a
-- plate over the skill bar names them with how far they are: in reach, close, in sight or
-- far, or how far along your revive is.
--
-- Where they are comes from the map (GetPlayerMapPosition), how far from the client's
-- interact ranges. The minimap is north-up and so are the pointers: the camera turns, and
-- an addon can't tell which way it faces.

local A = AetherHUD
local C = A.C

local RATIO = 1.5 -- a zone's map is half again as wide as it is tall, in yards
local W, ROW_H = 236, 22

local plate
local rows = {}
local pins = {}
local downByBanner = {} -- names the game announced as down

-- Bearing from you to them in radians clockwise from north, or nil while it is not known.
function A.Bearing(unit)
	if not GetPlayerMapPosition then
		return nil
	end
	local px, py = GetPlayerMapPosition("player")
	local ux, uy = GetPlayerMapPosition(unit)
	if not (px and py and ux and uy) or (px == 0 and py == 0) or (ux == 0 and uy == 0) then
		return nil
	end
	local east, north = (ux - px) * RATIO, py - uy
	if math.abs(east) < 0.00001 and math.abs(north) < 0.00001 then
		return nil
	end
	return math.atan2(east, north)
end

-- How far, by the client's interact ranges: about 10 yards (a revive's reach), 28, in sight
-- (about 100), farther.
local REACH = {
	{ "in reach", C.good },
	{ "close", C.gold },
	{ "in sight", C.aether },
	{ "far", C.muted },
}

function A.Reach(unit)
	if CheckInteractDistance and CheckInteractDistance(unit, 3) then
		return REACH[1]
	elseif CheckInteractDistance and CheckInteractDistance(unit, 4) then
		return REACH[2]
	elseif UnitIsVisible and UnitIsVisible(unit) then
		return REACH[3]
	end
	return REACH[4]
end

-- Down: dead or a ghost to the client, or announced by the game and still without health.
function A.IsDown(unit)
	if not UnitExists(unit) then
		return false
	end
	if UnitIsDead(unit) or (UnitIsGhost and UnitIsGhost(unit)) then
		return true
	end
	local name = UnitName(unit)
	if name and downByBanner[name] then
		if (UnitHealth(unit) or 0) <= 1 then
			return true
		end
		downByBanner[name] = nil
	end
	return false
end

local function Downed()
	local out = {}
	if A.Demo() then
		out[1] = { name = "Brakka", token = "warrior", bearing = 0.8 + 0.3 * math.sin(GetTime() * 0.3), reach = REACH[2] }
		return out
	end
	local n = GetNumPartyMembers and GetNumPartyMembers() or 0
	for i = 1, n do
		local u = "party" .. i
		if A.IsDown(u) then
			local _, token = UnitClass(u)
			table.insert(out, { unit = u, name = UnitName(u) or "?", token = token and string.lower(token),
				bearing = A.Bearing(u), reach = A.Reach(u) })
		end
	end
	return out
end

local function Row(i)
	local r = rows[i]
	if r then
		return r
	end
	local y = -(4 + ROW_H / 2 + (i - 1) * ROW_H)
	r = {}
	r.compass = A.Compass(plate, 16)
	r.compass.frame:SetPoint("CENTER", plate, "TOPLEFT", 16, y)
	r.name = A.Text(plate, 11, true)
	r.name:SetPoint("LEFT", plate, "TOPLEFT", 30, y)
	r.reach = A.Text(plate, 10)
	r.reach:SetPoint("RIGHT", plate, "TOPRIGHT", -9, y)
	rows[i] = r
	return r
end

-- A gem on the minimap's ring, its shadow and glow each on a layer of their own.
local function Pin(i)
	local p = pins[i]
	if p then
		return p
	end
	local ring = A.minimapRing
	p = {}
	p.shadow = A.Diamond(ring.frame, 15, { 0, 0, 0 }, "BORDER")
	p.glow = A.Tex(ring.frame, "ARTWORK", A.MEDIA .. "glow")
	p.glow:SetBlendMode("ADD")
	p.glow:SetWidth(30)
	p.glow:SetHeight(30)
	p.glow:SetVertexColor(C.bad[1], C.bad[2], C.bad[3], 1)
	p.gem = A.Diamond(ring.frame, 11, C.bad, "OVERLAY")
	pins[i] = p
	return p
end

local function PlacePin(p, bearing)
	local ring = A.minimapRing
	local x = math.floor(ring.rim * math.sin(bearing) + 0.5)
	local y = math.floor(ring.rim * math.cos(bearing) + 0.5)
	if p.x == x and p.y == y then
		return
	end
	p.x, p.y = x, y
	p.shadow:ClearAllPoints()
	p.shadow:SetPoint("CENTER", ring.spot, "CENTER", x, y)
	p.glow:ClearAllPoints()
	p.glow:SetPoint("CENTER", ring.spot, "CENTER", x, y)
	p.gem:ClearAllPoints()
	p.gem:SetPoint("CENTER", ring.spot, "CENTER", x, y)
end

local function Update()
	local list = Downed()
	local n = table.getn(list)
	local pulse = A.Pulse(1.2)
	local revive = (not A.Demo() and AZS_GetRevive and AZS_GetRevive()) or {}
	local ring = A.minimapRing
	-- this client has no rotateMinimap (asking for a CVar it lacks is an error): kept for one that does
	local ok, rot = pcall(GetCVar, "rotateMinimap")
	local rotating = ok and rot == "1"
	for i = 1, n do
		local d = list[i]
		local r = Row(i)
		local cc = A.CLASS[d.token or ""] or C.text
		A.SetText(r.name, A.Hex(cc) .. d.name .. "|r" .. A.Hex(C.muted) .. "  is down|r")
		if revive.reviving and revive.reviving == d.name then
			A.SetText(r.reach, string.format("bringing back %d%%", A.N(revive.rshare) * 100))
			A.SetTextColor(r.reach, C.good)
		else
			A.SetText(r.reach, d.reach[1])
			A.SetTextColor(r.reach, d.reach[2])
		end
		r.compass:Point(d.bearing)
		A.Show(r.compass.frame, true)
		A.Show(r.name, true)
		A.Show(r.reach, true)
		if ring then
			local p = Pin(i)
			local shown = d.bearing ~= nil and not rotating
			if shown then
				PlacePin(p, d.bearing)
				A.SetAlpha(p.glow, 0.3 + 0.7 * pulse)
			end
			A.Show(p.shadow, shown)
			A.Show(p.glow, shown)
			A.Show(p.gem, shown)
		end
	end
	for i = n + 1, table.getn(rows) do
		A.Show(rows[i].compass.frame, false)
		A.Show(rows[i].name, false)
		A.Show(rows[i].reach, false)
	end
	for i = n + 1, table.getn(pins) do
		A.Show(pins[i].shadow, false)
		A.Show(pins[i].glow, false)
		A.Show(pins[i].gem, false)
	end
	if n > 0 then
		if plate.rows ~= n then
			plate.rows = n
			plate:SetHeight(8 + n * ROW_H)
		end
		A.Show(plate, true)
		A.PanelAlert(plate, C.bad, 0.5 + 0.5 * pulse)
	else
		A.Show(plate, false)
	end
end

local function Init()
	if not A.On("rescue") then
		return
	end
	plate = A.Panel("AetherHUDRescue", A.root, W, 8 + ROW_H, { bracket = 5 })
	plate:Hide()
	plate.aS = false
	A.RegisterMover("rescue", plate, "Downed allies", function(fr)
		fr:SetPoint("BOTTOM", A.root, "BOTTOM", 0, 236)
	end)
	-- the game's "{name} is down!" banner, in case the client still counts them alive
	if type(AZS_RegisterBannerHandler) == "function" then
		AZS_RegisterBannerHandler(function(b)
			if type(b) == "table" and b.kind == "frienddown" and b.name and b.name ~= "" then
				downByBanner[b.name] = true
			end
		end)
	end
	A.Every(0.2, Update)
end

A.OnInit(Init)
