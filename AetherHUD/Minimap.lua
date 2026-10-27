-- AetherHUD minimap: Aion's round map in a gold ring with a north gem, the zone, your
-- coordinates and the time on a glass plate beneath it. The stock border, zoom buttons,
-- day/night dial and world-map button go; the mouse wheel zooms.
--
-- The map itself stays as the game made it (its parent, layer, level and size): the client
-- draws your arrow and the map's icons along with it, and they went missing when 2.0 moved
-- the map into a frame of its own. Its whole cluster follows our frame instead.

local A = AetherHUD
local C = A.C

local SIZE, RING
local holder, spot, plate, zone, coords, clock
local cluster -- what we move: the map's own parent (MinimapCluster), else the map

-- Cut the zone to the room the plate has left, at a character's edge (names can be UTF-8).
local function FitZone(full)
	local room = plate:GetWidth() - 24 - (clock:GetStringWidth() or 0) - (coords:GetStringWidth() or 0)
	if room < 30 then
		room = 30
	end
	if zone.aFull == full and zone.aRoom == room then
		return
	end
	zone.aFull, zone.aRoom = full, room
	zone:SetText(full)
	local cut = string.len(full)
	while cut > 1 and (zone:GetStringWidth() or 0) > room do
		repeat
			cut = cut - 1
			local b = string.byte(full, cut + 1)
		until cut <= 1 or not (b and b >= 128 and b < 192)
		zone:SetText(string.sub(full, 1, cut) .. "...")
	end
end

-- The cluster takes our frame's size (only the mover's wheel changes it).
local function Follow()
	local s = holder:GetEffectiveScale() / cluster:GetParent():GetEffectiveScale()
	if math.abs((cluster:GetScale() or 1) - s) > 0.001 then
		cluster:SetScale(s)
	end
end

-- Place the cluster so that its map's centre lands on our spot.
local function Anchor()
	local point, rel, relPoint, x, y
	if Minimap.GetPoint then
		point, rel, relPoint, x, y = Minimap:GetPoint(1)
	end
	cluster:ClearAllPoints()
	if cluster == Minimap then
		Minimap:SetPoint("CENTER", spot, "CENTER", 0, 0)
	elseif point == "CENTER" and (rel == nil or rel == cluster) then
		cluster:SetPoint(relPoint or "CENTER", spot, "CENTER", -(x or 0), -(y or 0))
	else
		local mx, my = Minimap:GetCenter()
		local cx, cy = cluster:GetCenter()
		cluster:SetPoint("CENTER", spot, "CENTER", (cx or 0) - (mx or 0), (cy or 0) - (my or 0))
	end
end

local function Update()
	Follow()
	local x, y = 0, 0
	if GetPlayerMapPosition then
		x, y = GetPlayerMapPosition("player")
	end
	if x and x > 0 then
		A.SetText(coords, string.format("%d, %d", x * 100, y * 100))
	else
		A.SetText(coords, "")
	end
	A.SetText(clock, date and date("%H:%M") or "")
	FitZone(GetMinimapZoneText and GetMinimapZoneText() or "")
end

local function Init()
	if not A.On("minimap") or not Minimap then
		return
	end
	cluster = Minimap:GetParent()
	if not cluster or cluster == UIParent or not cluster:GetParent() then
		cluster = Minimap
	end
	SIZE = math.floor((Minimap:GetWidth() or 0) + 0.5)
	if SIZE < 60 then
		SIZE = 140
	end
	RING = math.floor(SIZE * 128 / 106 + 0.5)

	holder = CreateFrame("Frame", "AetherHUDMinimap", A.root)
	holder:SetFrameStrata("LOW")
	holder:SetWidth(RING)
	holder:SetHeight(RING + 28)
	spot = CreateFrame("Frame", nil, holder)
	spot:SetWidth(SIZE)
	spot:SetHeight(SIZE)
	spot:SetPoint("CENTER", holder, "TOP", 0, -RING / 2)

	if MinimapCluster then
		MinimapCluster:EnableMouse(false)
	end
	for _, name in ipairs({ "MinimapBorder", "MinimapBorderTop", "MinimapZoomIn", "MinimapZoomOut",
		"MiniMapWorldMapButton", "GameTimeFrame", "MinimapToggleButton", "MinimapZoneTextButton",
		"MinimapNorthTag", "MiniMapTrackingBorder", "MiniMapMailBorder", "MiniMapBattlefieldBorder" }) do
		A.Kill(getglobal(name))
	end
	Minimap:EnableMouseWheel(true)
	Minimap:SetScript("OnMouseWheel", function()
		local z = Minimap:GetZoom()
		if arg1 > 0 and z < Minimap:GetZoomLevels() - 1 then
			Minimap:SetZoom(z + 1)
		elseif arg1 < 0 and z > 0 then
			Minimap:SetZoom(z - 1)
		end
	end)

	-- a dark disc under the map, the gold ring and the north gem over it, in the map's layer
	local strata = Minimap:GetFrameStrata() or "LOW"
	local level = Minimap:GetFrameLevel() or 1
	local under = CreateFrame("Frame", nil, holder)
	under:SetFrameStrata(strata)
	under:SetFrameLevel(math.max(0, level - 1))
	under:SetAllPoints(holder)
	local disc = A.Tex(under, "BACKGROUND", A.MEDIA .. "glow")
	disc:SetPoint("CENTER", spot, "CENTER", 0, 0)
	disc:SetWidth(SIZE + 40)
	disc:SetHeight(SIZE + 40)
	disc:SetVertexColor(0, 0, 0, 0.85)
	local over = CreateFrame("Frame", nil, holder)
	over:SetFrameStrata(strata)
	over:SetFrameLevel(level + 3)
	over:SetAllPoints(holder)
	local ring = A.Tex(over, "BORDER", A.MEDIA .. "ring")
	ring:SetPoint("CENTER", spot, "CENTER", 0, 0)
	ring:SetWidth(RING)
	ring:SetHeight(RING)
	ring:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
	local glint = A.Tex(over, "ARTWORK", A.MEDIA .. "glow")
	glint:SetBlendMode("ADD")
	glint:SetPoint("CENTER", spot, "TOP", 0, -2)
	glint:SetWidth(70)
	glint:SetHeight(18)
	glint:SetVertexColor(C.aether[1], C.aether[2], C.aether[3], 0.45)
	local north = A.Diamond(over, 13, C.gold, "OVERLAY")
	north:SetPoint("CENTER", spot, "TOP", 0, -1)
	local n = A.Text(over, 8, true)
	A.Font(n, 8, true, "")
	n:SetPoint("CENTER", north, "CENTER", 0, 0)
	n:SetText("N")
	n:SetTextColor(0.15, 0.1, 0.02)
	n:SetShadowOffset(0, 0)

	-- pointers on the ring (Rescue.lua's downed allies): a frame over it and the ring's radius
	local pins = CreateFrame("Frame", nil, over)
	pins:SetAllPoints(over)
	pins:SetFrameLevel(over:GetFrameLevel() + 2)
	A.minimapRing = { frame = pins, spot = spot, rim = SIZE / 2 + (RING - SIZE) / 4 }

	-- the plate: zone, coordinates, time (the zone is cut, never wrapped)
	plate = A.Panel(nil, holder, RING, 22, { bracket = 5, noGlint = true })
	plate:SetPoint("BOTTOM", holder, "BOTTOM", 0, 0)
	zone = A.Text(plate, 10, true)
	zone:SetPoint("LEFT", plate, "LEFT", 7, 0)
	zone:SetJustifyH("LEFT")
	zone:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	clock = A.Text(plate, 10)
	clock:SetPoint("RIGHT", plate, "RIGHT", -7, 0)
	coords = A.Text(plate, 9)
	coords:SetPoint("RIGHT", clock, "LEFT", -8, 0)
	coords:SetTextColor(C.muted[1], C.muted[2], C.muted[3])

	-- tracking, mail and battleground icons sit on the ring
	local spots = {
		{ "MiniMapTrackingFrame", "BOTTOMLEFT", 10, 10 },
		{ "MiniMapMailFrame", "TOPRIGHT", -6, -6 },
		{ "MiniMapBattlefieldFrame", "BOTTOMRIGHT", -8, 10 },
	}
	for i = 1, table.getn(spots) do
		local s = spots[i]
		local fr = getglobal(s[1])
		if fr then
			fr:SetParent(over)
			fr:ClearAllPoints()
			fr:SetPoint("CENTER", spot, s[2], s[3], s[4])
			fr:SetScale(0.8)
		end
	end

	-- the zone is known from the world map once it points at the current zone
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:SetScript("OnEvent", function()
		if SetMapToCurrentZone and not (WorldMapFrame and WorldMapFrame:IsVisible()) then
			SetMapToCurrentZone()
		end
	end)

	A.RegisterMover("minimap", holder, "Minimap", function(fr)
		fr:SetPoint("TOPRIGHT", A.root, "TOPRIGHT", -14, -8)
	end)
	Anchor()
	Update()
	A.Every(0.5, Update)
end

A.OnInit(Init)
