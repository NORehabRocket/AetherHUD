-- AetherHUD: an Aion-styled HUD for Azeroth Survivors (WoW 1.12.1 client, Lua 5.0).
-- Core: settings, palette, cached setters, the shared update driver, movable frames and
-- hiding/restoring the game's own HUD parts.

AetherHUD = {}
local A = AetherHUD

A.VERSION = "2.0.0"
A.MEDIA = "Interface\\AddOns\\AetherHUD\\media\\"
A.FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
A.SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
A.FONT_TITLE = "Fonts\\FRIZQT__.TTF"
A.FONT = A.MEDIA .. "Roboto.ttf" -- checked at start; Arial Narrow if the client can't load it

-- Aion's palette: deep navy glass, aether cyan, Elyos gold, Asmodian violet.
A.C = {
	bg = { 0.02, 0.05, 0.09 },
	bgTop = { 0.07, 0.14, 0.22 },
	edge = { 0.20, 0.38, 0.52 },
	aether = { 0.38, 0.86, 1.00 },
	gold = { 1.00, 0.80, 0.40 },
	steel = { 0.55, 0.72, 0.86 },
	muted = { 0.56, 0.66, 0.76 },
	text = { 0.93, 0.96, 1.00 },
	hp1 = { 0.55, 0.05, 0.07 }, hp2 = { 1.00, 0.34, 0.16 },
	xp1 = { 0.95, 0.62, 0.18 }, xp2 = { 0.42, 0.90, 1.00 },
	boss1 = { 0.50, 0.04, 0.05 }, boss2 = { 0.92, 0.18, 0.12 },
	rage1 = { 0.70, 0.18, 0.00 }, rage2 = { 1.00, 0.62, 0.05 },
	guard1 = { 0.32, 0.12, 0.60 }, guard2 = { 0.72, 0.46, 1.00 },
	friend1 = { 0.08, 0.40, 0.16 }, friend2 = { 0.35, 0.90, 0.40 },
	shield = { 0.80, 0.96, 1.00 },
	good = { 0.40, 1.00, 0.55 },
	bad = { 1.00, 0.30, 0.25 },
	violet = { 0.72, 0.46, 1.00 },
	proc = { 0.35, 0.60, 1.00 },
}

A.CLASS = {
	warrior = { 0.78, 0.61, 0.43 }, paladin = { 0.96, 0.55, 0.73 }, hunter = { 0.67, 0.83, 0.45 },
	rogue = { 1.00, 0.96, 0.41 }, priest = { 1.00, 1.00, 1.00 }, shaman = { 0.00, 0.44, 0.87 },
	mage = { 0.41, 0.80, 0.94 }, warlock = { 0.58, 0.51, 0.79 }, druid = { 1.00, 0.49, 0.04 },
}

------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------

-- The game's HUD part each module stands in for. "build" (spells and jewelry) is only
-- hidden on request: the API has no jewelry, so the skill bar can't replace all of it.
A.PARTS = {
	clock = "chrono", bosses = "bosses", tally = "tally", meter = "meter", banners = "banners", build = "skills",
	loot = "loot", levels = "xp", revive = "notices",
}

-- short labels: the options window lists them in two columns
A.MODULES = {
	{ key = "chrono", label = "Run clock" },
	{ key = "bosses", label = "Boss bars" },
	{ key = "hero", label = "Hero frame" },
	{ key = "target", label = "Target frame" },
	{ key = "skills", label = "Skill bar" },
	{ key = "xp", label = "Experience bar" },
	{ key = "tally", label = "Run tally" },
	{ key = "lairs", label = "Lairs" },
	{ key = "meter", label = "Combat meter" },
	{ key = "banners", label = "Banners" },
	{ key = "vignette", label = "Low-health glow" },
	{ key = "plates", label = "Enemy plates" },
	{ key = "numbers", label = "Combat numbers" },
	{ key = "notices", label = "System messages" },
	{ key = "loot", label = "Loot notices" },
	{ key = "chat", label = "Chat" },
	{ key = "minimap", label = "Minimap" },
	{ key = "bags", label = "Inventory" },
	{ key = "character", label = "Character window" },
	{ key = "party", label = "Party and pet" },
	{ key = "skin", label = "Tooltips and menus" },
}

local DEFAULTS = {
	scale = 1,
	pos = {},
	fscale = {},
	modules = {
		chrono = true, bosses = true, hero = true, target = true, skills = true, xp = true,
		tally = true, lairs = true, meter = true, banners = true, vignette = true,
		plates = true, numbers = true, notices = true, loot = true, chat = true, minimap = true,
		bags = true, character = true, party = true, skin = true,
	},
	hideBuild = false,
	hid = {},
	cvars = {},
	meter = { tab = "dmg", rows = 8 },
	plates = { smart = true },
	numbers = { taken = true, heals = true, size = 1 },
}

local function Merge(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then
				dst[k] = {}
			end
			Merge(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function A.On(key)
	return A.db and A.db.modules[key] and true or false
end

------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------

function A.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff61dbffAether|cffffcc66HUD|r: " .. msg)
end

local reported = {}
function A.Error(err)
	err = tostring(err)
	if reported[err] then
		return
	end
	reported[err] = true
	A.Print("|cffff5544error:|r " .. err)
end

function A.N(v)
	return tonumber(v) or 0
end

-- Flags arrive as 1/0 in the tables and as booleans from the AZS_Get* functions.
function A.Flag(v)
	return v == true or v == 1 or v == "1"
end

function A.Clamp(v, lo, hi)
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	end
	return v
end

function A.Clock(s)
	s = math.floor(math.max(0, s or 0) + 0.5)
	if s >= 3600 then
		return string.format("%d:%02d:%02d", math.floor(s / 3600), math.floor(math.mod(s, 3600) / 60), math.mod(s, 60))
	end
	return string.format("%d:%02d", math.floor(s / 60), math.mod(s, 60))
end

-- Short countdown for icons: 1.4 / 12 / 2m
function A.Countdown(s)
	if s >= 60 then
		return math.ceil(s / 60) .. "m"
	elseif s >= 3 then
		return tostring(math.floor(s + 0.5))
	end
	return string.format("%.1f", s)
end

function A.Short(v)
	v = tonumber(v) or 0
	local a = math.abs(v)
	if a >= 1000000 then
		return string.format("%.2fM", v / 1000000)
	elseif a >= 100000 then
		return string.format("%.0fK", v / 1000)
	elseif a >= 10000 then
		return string.format("%.1fK", v / 1000)
	end
	return tostring(math.floor(v + 0.5))
end

function A.Comma(v)
	local s = tostring(math.floor((tonumber(v) or 0) + 0.5))
	while true do
		local k
		s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return s
end

-- "Final Boss" -> "F I N A L   B O S S": Aion's tracked-out captions.
function A.Spaced(s)
	s = string.upper(s or "")
	local out = {}
	for i = 1, string.len(s) do
		table.insert(out, string.sub(s, i, i))
	end
	return table.concat(out, " ")
end

function A.Icon(path)
	if not path or path == "" then
		return "Interface\\Icons\\INV_Misc_QuestionMark"
	end
	if not string.find(path, "\\", 1, true) then
		return "Interface\\Icons\\" .. path
	end
	return path
end

function A.Hex(c)
	return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

------------------------------------------------------------------------
-- Cached setters: this client pays for every SetText/SetWidth/SetTexture, so only
-- call through when the value really changed.
------------------------------------------------------------------------

function A.SetText(fs, s)
	if fs.aT ~= s then
		fs.aT = s
		fs:SetText(s)
	end
end

function A.SetWidth(r, w)
	if w < 0.01 then
		w = 0.01
	end
	if not r.aW or math.abs(r.aW - w) > 0.15 then
		r.aW = w
		r:SetWidth(w)
	end
end

function A.SetHeight(r, h)
	if h < 0.01 then
		h = 0.01
	end
	if not r.aH or math.abs(r.aH - h) > 0.15 then
		r.aH = h
		r:SetHeight(h)
	end
end

function A.Show(r, shown)
	if shown then
		if r.aS ~= true then
			r.aS = true
			r:Show()
		end
	elseif r.aS ~= false then
		r.aS = false
		r:Hide()
	end
end

function A.SetAlpha(r, a)
	if not r.aA or math.abs(r.aA - a) > 0.01 then
		r.aA = a
		r:SetAlpha(a)
	end
end

function A.SetColor(t, r, g, b, a)
	a = a or 1
	if t.aR ~= r or t.aG ~= g or t.aB ~= b or t.aAl ~= a then
		t.aR, t.aG, t.aB, t.aAl = r, g, b, a
		t.aGrad = nil
		t:SetVertexColor(r, g, b, a)
	end
end

function A.SetTextColor(fs, c, a)
	if fs.aC ~= c or fs.aCA ~= a then
		fs.aC, fs.aCA = c, a
		fs:SetTextColor(c[1], c[2], c[3], a or 1)
	end
end

-- Two-colour gradient (tables c1 -> c2) along "HORIZONTAL" or "VERTICAL".
function A.Gradient(t, dir, c1, c2, a1, a2)
	a1 = a1 or 1
	a2 = a2 or a1
	if t.aGrad == c1 and t.aGrad2 == c2 and t.aGradA == a1 and t.aGradA2 == a2 and t.aGradD == dir then
		return
	end
	t.aGrad, t.aGrad2, t.aGradA, t.aGradA2, t.aGradD = c1, c2, a1, a2, dir
	t.aR = nil
	if t.SetGradientAlpha then
		t:SetGradientAlpha(dir, c1[1], c1[2], c1[3], a1, c2[1], c2[2], c2[3], a2)
	else
		t:SetVertexColor((c1[1] + c2[1]) / 2, (c1[2] + c2[2]) / 2, (c1[3] + c2[3]) / 2, (a1 + a2) / 2)
	end
end

function A.SetTexture(t, path)
	if t.aTex ~= path then
		t.aTex = path
		t:SetTexture(path)
	end
end

function A.Font(fs, size, title, flags)
	fs:SetFont(title and A.FONT_TITLE or A.FONT, size, flags or "OUTLINE")
	fs:SetShadowColor(0, 0, 0, 0.8)
	fs:SetShadowOffset(1, -1)
end

function A.Text(parent, size, title, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	A.Font(fs, size, title)
	fs:SetTextColor(A.C.text[1], A.C.text[2], A.C.text[3])
	return fs
end

-- A pulse 0..1 at `speed` cycles per second, shared so everything throbs together.
function A.Pulse(speed)
	return 0.5 + 0.5 * math.sin(GetTime() * (speed or 2) * 6.2832)
end

------------------------------------------------------------------------
-- Update driver: one OnUpdate for the whole HUD, each task at its own rate.
------------------------------------------------------------------------

local tasks = {}

function A.Every(interval, fn)
	table.insert(tasks, { fn = fn, iv = interval, acc = interval })
end

local driver = CreateFrame("Frame", "AetherHUDDriver")
driver:SetScript("OnUpdate", function()
	if not A.ready then
		return
	end
	local e = arg1 or 0
	for i = 1, table.getn(tasks) do
		local t = tasks[i]
		t.acc = t.acc + e
		if t.acc >= t.iv then
			local dt = t.acc
			t.acc = 0
			local ok, err = pcall(t.fn, dt)
			if not ok then
				A.Error(err)
			end
		end
	end
end)

------------------------------------------------------------------------
-- Root and movable frames
------------------------------------------------------------------------

A.root = CreateFrame("Frame", "AetherHUDRoot", UIParent)
A.root:SetAllPoints(UIParent)
A.root:SetFrameStrata("LOW")

A.movers = {}
A.moverOrder = {}
A.unlocked = false

function A.Place(key)
	local m = A.movers[key]
	if not m then
		return
	end
	local f = m.frame
	local s = A.db.fscale[key] or 1
	f:SetScale(s)
	f:ClearAllPoints()
	local p = A.db.pos[key]
	if p and p.x and p.y then
		f:SetPoint("CENTER", A.root, "CENTER", p.x / s, p.y / s)
	else
		m.default(f)
	end
end

function A.PlaceAll()
	A.root:SetScale(A.db.scale or 1)
	for i = 1, table.getn(A.moverOrder) do
		A.Place(A.moverOrder[i])
	end
end

-- Also used by windows dragged by their title bar.
function A.SavePos(key)
	local m = A.movers[key]
	if not m then
		return
	end
	local f = m.frame
	local cx, cy = f:GetCenter()
	local rx, ry = A.root:GetCenter()
	if not cx or not rx then
		return
	end
	local s = f:GetScale()
	A.db.pos[key] = { x = cx * s - rx, y = cy * s - ry }
	A.Place(key)
end
local SavePos = A.SavePos

local function MakeOverlay(key)
	local m = A.movers[key]
	local o = CreateFrame("Button", nil, A.root)
	o:SetFrameStrata("DIALOG")
	o:SetAllPoints(m.frame)
	o:EnableMouse(true)
	o:EnableMouseWheel(true)
	o:RegisterForDrag("LeftButton")
	o:RegisterForClicks("RightButtonUp")
	local bg = o:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(A.FLAT)
	bg:SetAllPoints(o)
	bg:SetVertexColor(A.C.aether[1], A.C.aether[2], A.C.aether[3], 0.18)
	local edges = {}
	for i = 1, 4 do
		local t = o:CreateTexture(nil, "BORDER")
		t:SetTexture(A.FLAT)
		t:SetVertexColor(A.C.aether[1], A.C.aether[2], A.C.aether[3], 0.9)
		edges[i] = t
	end
	edges[1]:SetPoint("TOPLEFT", o, "TOPLEFT", 0, 0)
	edges[1]:SetPoint("TOPRIGHT", o, "TOPRIGHT", 0, 0)
	edges[1]:SetHeight(1)
	edges[2]:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", 0, 0)
	edges[2]:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 0, 0)
	edges[2]:SetHeight(1)
	edges[3]:SetPoint("TOPLEFT", o, "TOPLEFT", 0, 0)
	edges[3]:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", 0, 0)
	edges[3]:SetWidth(1)
	edges[4]:SetPoint("TOPRIGHT", o, "TOPRIGHT", 0, 0)
	edges[4]:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 0, 0)
	edges[4]:SetWidth(1)
	local label = A.Text(o, 11, true)
	label:SetPoint("CENTER", o, "CENTER", 0, 0)
	label:SetTextColor(A.C.gold[1], A.C.gold[2], A.C.gold[3])
	label:SetText(m.label)
	o:SetScript("OnDragStart", function()
		m.frame:SetMovable(true)
		m.frame:StartMoving()
	end)
	o:SetScript("OnDragStop", function()
		m.frame:StopMovingOrSizing()
		if m.frame.SetUserPlaced then
			m.frame:SetUserPlaced(false)
		end
		SavePos(key)
	end)
	o:SetScript("OnClick", function()
		A.db.pos[key] = nil
		A.db.fscale[key] = nil
		A.Place(key)
	end)
	o:SetScript("OnMouseWheel", function()
		local s = A.db.fscale[key] or 1
		s = A.Clamp(math.floor((s + arg1 * 0.05) * 100 + 0.5) / 100, 0.5, 2)
		-- keep the centre where it is while the size changes
		SavePos(key)
		A.db.fscale[key] = s
		A.Place(key)
	end)
	o:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText(m.label, A.C.gold[1], A.C.gold[2], A.C.gold[3])
		GameTooltip:AddLine("Drag to move", 1, 1, 1)
		GameTooltip:AddLine("Mouse wheel: size (" .. math.floor((A.db.fscale[key] or 1) * 100 + 0.5) .. "%)", 1, 1, 1)
		GameTooltip:AddLine("Right-click: back to default", 1, 1, 1)
		GameTooltip:Show()
	end)
	o:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	o:Hide()
	m.overlay = o
end

-- default(frame) anchors the frame at its standard place, relative to A.root.
function A.RegisterMover(key, frame, label, default)
	A.movers[key] = { frame = frame, label = label, default = default }
	table.insert(A.moverOrder, key)
	MakeOverlay(key)
	A.Place(key)
end

function A.Unlock(state)
	if state == nil then
		state = not A.unlocked
	end
	A.unlocked = state
	for _, m in pairs(A.movers) do
		if state then
			m.overlay:Show()
		else
			m.overlay:Hide()
			m.frame:SetMovable(false)
		end
	end
	if state then
		A.Print("frames unlocked: drag to move, mouse wheel to resize, right-click to reset. |cffffcc66/aether lock|r when done.")
	else
		A.Print("frames locked.")
	end
	if A.OnOptionsChanged then
		A.OnOptionsChanged()
	end
end

-- Demo data keeps every frame filled outside a run (and while frames are unlocked).
function A.Demo()
	return A.demo or A.unlocked
end

------------------------------------------------------------------------
-- The game's own HUD
------------------------------------------------------------------------

local function PartWanted(part)
	if part == "build" then
		return A.On("skills") and A.db.hideBuild
	end
	if part == "banners" and A.noBannerHook then
		return false
	end
	return A.On(A.PARTS[part])
end

-- Hide the parts our modules replace. A part whose module is off (or "build" with its
-- option off) is shown again if we hid it; `force` names a part the options window just
-- gave back, shown whoever hid it.
function A.SyncGameHud(force)
	if type(AZS_SetHudShown) ~= "function" or type(AZS_IsHudShown) ~= "function" then
		return
	end
	for part in pairs(A.PARTS) do
		if PartWanted(part) then
			if AZS_IsHudShown(part) then
				AZS_SetHudShown(part, false)
				A.db.hid[part] = true
			end
		elseif A.db.hid[part] or (force == part and not AZS_IsHudShown(part)) then
			AZS_SetHudShown(part, true)
			A.db.hid[part] = nil
		end
	end
end

-- A client setting a module needs while it runs (native combat numbers off, the combat
-- log's range): the first value we saw is kept and comes back at logout.
function A.OwnCVar(name, value)
	local ok, cur = pcall(GetCVar, name)
	if not ok or cur == nil then
		return
	end
	if A.db.cvars[name] == nil then
		A.db.cvars[name] = cur
	end
	if cur ~= value then
		pcall(SetCVar, name, value)
	end
end

-- At logout every part we hid and every setting we changed comes back, so with the addon
-- disabled the game is as it was; the next load takes them over anew.
local function RestoreGameHud()
	if not A.db then
		return
	end
	for name, value in pairs(A.db.cvars) do
		pcall(SetCVar, name, value)
	end
	A.db.cvars = {}
	if type(AZS_SetHudShown) ~= "function" then
		return
	end
	for part in pairs(A.db.hid) do
		AZS_SetHudShown(part, true)
	end
	A.db.hid = {}
end

-- Hide a stock frame for good (until /reload with the module off).
function A.Silence(frame)
	if not frame then
		return
	end
	if frame.UnregisterAllEvents then
		frame:UnregisterAllEvents()
	end
	frame:Hide()
	frame.Show = function() end
end

------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------

local inits = {}
function A.OnInit(fn)
	table.insert(inits, fn)
end

local function CheckFont()
	-- Roboto has Latin and Cyrillic only; the Chinese and Korean clients map the stock
	-- font path to their own script's font.
	local loc = GetLocale and GetLocale()
	if loc == "zhCN" or loc == "zhTW" or loc == "koKR" then
		A.FONT = A.FONT_TITLE
		return
	end
	local probe = A.root:CreateFontString(nil, "OVERLAY")
	probe:SetFont(A.FONT, 12, "OUTLINE")
	if not probe:GetFont() then
		A.FONT = "Fonts\\ARIALN.TTF"
	end
	probe:Hide()
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("VARIABLES_LOADED")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("PLAYER_LOGOUT")
local wait
boot:SetScript("OnEvent", function()
	if event == "VARIABLES_LOADED" then
		AetherHUDDB = AetherHUDDB or {}
		Merge(AetherHUDDB, DEFAULTS)
		A.db = AetherHUDDB
	elseif event == "PLAYER_LOGOUT" then
		RestoreGameHud()
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- give the game's own frames a moment to settle before we rebuild over them
		wait = 0.3
	end
end)
boot:SetScript("OnUpdate", function()
	if not wait then
		return
	end
	wait = wait - (arg1 or 0)
	if wait > 0 then
		return
	end
	wait = nil
	if not A.db then
		AetherHUDDB = AetherHUDDB or {}
		Merge(AetherHUDDB, DEFAULTS)
		A.db = AetherHUDDB
	end
	if not A.ready then
		if type(AZS_GetPhase) ~= "function" then
			A.Print("the Azeroth Survivors API is missing - AetherHUD only works inside Azeroth Survivors.")
			return
		end
		CheckFont()
		A.root:SetScale(A.db.scale or 1)
		for i = 1, table.getn(inits) do
			local ok, err = pcall(inits[i])
			if not ok then
				A.Error(err)
			end
		end
		A.ready = true
		if PhantomUI or DFRL then
			A.Print("|cffff8844another full UI (PhantomUI / SurvivorsDragonUi) is enabled too.|r Both draw over the game's HUD - disable one of them in the AddOns list.")
		end
		A.Print("v" .. A.VERSION .. " loaded. |cffffcc66/aether|r for options.")
	end
	A.SyncGameHud()
	A.PlaceAll()
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------

SLASH_AETHERHUD1 = "/aether"
SLASH_AETHERHUD2 = "/ahud"
SlashCmdList["AETHERHUD"] = function(msg)
	msg = string.lower(msg or "")
	local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
	if not A.ready then
		A.Print("not running (only inside an Azeroth Survivors world).")
		return
	end
	if cmd == "unlock" or cmd == "move" then
		A.Unlock(true)
	elseif cmd == "lock" then
		A.Unlock(false)
	elseif cmd == "demo" then
		A.demo = not A.demo
		A.Print(A.demo and "demo data on: every frame shows a sample run." or "demo data off.")
		if A.demo and A.TestBanners then
			A.TestBanners()
		end
		if A.OnOptionsChanged then
			A.OnOptionsChanged()
		end
	elseif cmd == "reset" then
		A.db.pos = {}
		A.db.fscale = {}
		A.db.scale = 1
		A.PlaceAll()
		A.Print("positions and sizes reset.")
	elseif cmd == "scale" and tonumber(rest) then
		A.db.scale = A.Clamp(tonumber(rest), 0.5, 2)
		A.PlaceAll()
		A.Print("scale " .. A.db.scale)
	elseif cmd == "help" then
		A.Print("/aether - options window")
		A.Print("/aether unlock | lock - move and resize frames")
		A.Print("/aether demo - sample data to preview the HUD outside a run")
		A.Print("/aether scale 0.9 - overall size;  /aether reset - default layout")
	elseif A.ToggleOptions then
		A.ToggleOptions()
	end
end
