-- AetherHUD minimap: Aion's round map in a gold ring with a north gem, the zone, your
-- coordinates and the time on a glass plate beneath it. The stock border, zoom buttons,
-- day/night dial and world-map button go; the mouse wheel zooms.

local A = AetherHUD
local C = A.C

local SIZE = 150

local holder, zone, coords, clock

local function Update()
	A.SetText(zone, GetMinimapZoneText and GetMinimapZoneText() or "")
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
end

local function Init()
	if not A.On("minimap") or not Minimap then
		return
	end
	holder = CreateFrame("Frame", "AetherHUDMinimap", A.root)
	holder:SetFrameStrata("LOW")
	holder:SetWidth(SIZE + 20)
	holder:SetHeight(SIZE + 44)

	-- the map itself, moved into our holder
	Minimap:SetParent(holder)
	Minimap:ClearAllPoints()
	Minimap:SetPoint("TOP", holder, "TOP", 0, -10)
	Minimap:SetWidth(SIZE)
	Minimap:SetHeight(SIZE)
	Minimap:SetFrameStrata("LOW")
	Minimap:SetFrameLevel(holder:GetFrameLevel() + 2)
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

	-- a dark disc behind, the gold ring and the north gem over it
	local disc = A.Tex(holder, "BACKGROUND", A.MEDIA .. "glow")
	disc:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
	disc:SetWidth(SIZE + 40)
	disc:SetHeight(SIZE + 40)
	disc:SetVertexColor(0, 0, 0, 0.85)
	local over = CreateFrame("Frame", nil, holder)
	over:SetAllPoints(holder)
	over:SetFrameLevel(Minimap:GetFrameLevel() + 3)
	local ring = A.Tex(over, "ARTWORK", A.MEDIA .. "ring")
	ring:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
	ring:SetWidth(SIZE * 128 / 106)
	ring:SetHeight(SIZE * 128 / 106)
	ring:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
	local glint = A.Tex(over, "OVERLAY", A.MEDIA .. "glow")
	glint:SetBlendMode("ADD")
	glint:SetPoint("CENTER", Minimap, "TOP", 0, -2)
	glint:SetWidth(70)
	glint:SetHeight(18)
	glint:SetVertexColor(C.aether[1], C.aether[2], C.aether[3], 0.45)
	local north = A.Diamond(over, 13, C.gold, "OVERLAY")
	north:SetPoint("CENTER", Minimap, "TOP", 0, -1)
	local n = A.Text(over, 8, true)
	A.Font(n, 8, true, "")
	n:SetPoint("CENTER", north, "CENTER", 0, 0)
	n:SetText("N")
	n:SetTextColor(0.15, 0.1, 0.02)
	n:SetShadowOffset(0, 0)

	-- the plate: zone, coordinates, time
	local plate = A.Panel(nil, holder, SIZE + 20, 22, { bracket = 5, noGlint = true })
	plate:SetPoint("BOTTOM", holder, "BOTTOM", 0, 0)
	zone = A.Text(plate, 10, true)
	zone:SetPoint("LEFT", plate, "LEFT", 7, 0)
	zone:SetWidth(SIZE - 70)
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
		local f = getglobal(s[1])
		if f then
			f:SetParent(over)
			f:ClearAllPoints()
			f:SetPoint("CENTER", Minimap, s[2], s[3], s[4])
			f:SetScale(0.8)
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
	Update()
	A.Every(0.5, Update)
end

A.OnInit(Init)
