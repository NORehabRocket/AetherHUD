-- A strict stand-in for the WoW 1.12 client's Lua environment, enough to load and drive
-- AetherHUD outside the game. Objects only have the methods 1.12 has (a call to anything
-- else fails like it would in game), Lua 5.1 conveniences that 5.0 lacks are removed,
-- and the 5.0 names (table.getn, math.mod, string.gfind) are put back.

------------------------------------------------------------------------
-- Lua 5.0 environment
------------------------------------------------------------------------

-- Lua 5.0's list length: an "n" field, else the size table.insert/remove/setn last
-- recorded (which goes stale if entries are cleared by hand), else count to the first nil.
local sizes = setmetatable({}, { __mode = "k" })
table.getn = function(t)
	if type(t.n) == "number" then
		return t.n
	end
	if sizes[t] then
		return sizes[t]
	end
	local i = 0
	while rawget(t, i + 1) ~= nil do
		i = i + 1
	end
	return i
end
table.setn = function(t, n)
	if type(t.n) == "number" then
		t.n = n
	else
		sizes[t] = n
	end
end
table.insert = function(t, a, b)
	local n = table.getn(t)
	if b == nil then
		t[n + 1] = a
	else
		for i = n, a, -1 do
			t[i + 1] = t[i]
		end
		t[a] = b
	end
	table.setn(t, n + 1)
end
table.remove = function(t, pos)
	local n = table.getn(t)
	if n <= 0 then
		return nil
	end
	pos = pos or n
	local v = t[pos]
	for i = pos, n - 1 do
		t[i] = t[i + 1]
	end
	t[n] = nil
	table.setn(t, n - 1)
	return v
end
math.randomseed(7)
math.mod = math.fmod
string.gfind = string.gmatch
getmetatable("").__index = nil -- no ("x"):upper() in 5.0
string.match = nil
string.gmatch = nil
select = nil
math.huge = nil
math.fmod = nil
table.maxn = nil
strfind, strsub, strlen, strupper, strlower, format = string.find, string.sub, string.len, string.upper, string.lower, string.format

MOCK = {
	time = 1000,
	errors = {},
	chat = {},
	frames = {},
	cvars = {
		hudClock = "1", hudBosses = "1", hudTally = "1", hudBuild = "1", hudBanners = "1",
		hudLoot = "1", hudMeter = "1", hudLevels = "1", hudFlag = "1", hudRevive = "1",
		CombatDamage = "1", PetMeleeDamage = "1", PetSpellDamage = "1", CombatLogPeriodicSpells = "0",
		CombatLogRangeCreature = "50", CombatLogRangeHostilePlayers = "50", CombatLogRangeHostilePlayersPets = "50",
		CombatLogRangeParty = "50", CombatLogRangePartyPet = "50",
		-- the game's run settings (no noSpellEffects: its options row must stay away)
		storeLevels = "0", cacheOnClick = "0",
	},
	player = { name = "Utther", hp = 1800, hpm = 2400, level = 17, class = "Mage", token = "MAGE", race = "Human", xp = 100, xpm = 1000 },
	target = nil, -- { name, hp, hpm, level, dead, player, friend, classification }
	buffs = {}, -- { texture, left, apps, harmful, dispel }
	actions = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [12] = true },
}

function GetTime()
	return MOCK.time
end

local function report(err)
	table.insert(MOCK.errors, tostring(err))
end

function geterrorhandler()
	return report
end

------------------------------------------------------------------------
-- Object model
------------------------------------------------------------------------

local methods = { Region = {}, Frame = {}, Button = {}, Texture = {}, FontString = {}, GameTooltip = {}, StatusBar = {},
	EditBox = {}, ScrollingMessageFrame = {}, Minimap = {}, MessageFrame = {} }

local function inherit(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = v
		end
	end
end

local new
MOCK.methods = methods
function MOCK.new(kind, name, parent)
	return new(kind, name, parent)
end
new = function(kind, name, parent)
	local o = {
		__kind = kind, __name = name, __parent = parent, __shown = true, __alpha = 1, __scale = 1,
		__w = 0, __h = 0, __points = {}, __scripts = {}, __events = {}, __level = 1, __strata = "MEDIUM",
	}
	setmetatable(o, { __index = methods[kind] })
	o.__children = {}
	MOCK.seq = (MOCK.seq or 0) + 1
	o.__seq = MOCK.seq
	if parent then
		table.insert(parent.__children, o)
	end
	if name then
		_G[name] = o
	end
	return o
end

local R = methods.Region
function R:SetWidth(w)
	assert(type(w) == "number" and w == w, "SetWidth wants a number")
	if MOCK.calls then MOCK.calls.SetWidth = MOCK.calls.SetWidth + 1 end
	self.__w = w
end
function R:SetHeight(h) assert(type(h) == "number", "SetHeight wants a number") self.__h = h end
function R:GetWidth()
	if self.__w == 0 and self.__all then
		return self.__all:GetWidth()
	end
	return self.__w
end
function R:GetHeight()
	if self.__h == 0 and self.__all then
		return self.__all:GetHeight()
	end
	return self.__h
end
function R:SetPoint(point, rel, relPoint, x, y)
	assert(type(point) == "string", "SetPoint: point")
	if rel ~= nil and type(rel) ~= "table" and type(rel) ~= "string" then
		error("SetPoint: bad relative frame " .. tostring(rel))
	end
	if x ~= nil then
		assert(type(x) == "number" and x == x, "SetPoint: x not a number")
	end
	if y ~= nil then
		assert(type(y) == "number" and y == y, "SetPoint: y not a number")
	end
	table.insert(self.__points, { point, rel, relPoint, x, y })
end
function R:ClearAllPoints() self.__points = {} self.__all = nil end
function R:GetPoint(i)
	local p = self.__points[i or 1]
	if p then
		return p[1], p[2], p[3], p[4], p[5]
	end
end
function R:SetAllPoints(rel) self.__all = rel or self.__parent end
local function fire(self, script)
	local fn = self.__scripts and self.__scripts[script]
	if fn then
		local prev = this
		this = self
		local ok, err = pcall(fn)
		if not ok then
			table.insert(MOCK.errors, script .. ": " .. tostring(err))
		end
		this = prev
	end
end
function R:Show()
	local was = self.__shown
	self.__shown = true
	if not was then
		fire(self, "OnShow")
	end
end
function R:Hide()
	local was = self.__shown
	self.__shown = false
	if was then
		fire(self, "OnHide")
	end
end
function R:IsShown() return self.__shown end
function R:IsVisible()
	local o = self
	while o do
		if not o.__shown then
			return false
		end
		o = o.__parent
	end
	return true
end
function R:SetAlpha(a) assert(type(a) == "number" and a == a, "SetAlpha: NaN") self.__alpha = a end
function R:GetAlpha() return self.__alpha end
function R:GetParent() return self.__parent end
function R:GetName() return self.__name end
function R:GetCenter()
	if self.__px then
		return self.__px, self.__py
	end
	return 500, 400
end
function R:GetLeft() return 400 end
function R:GetTop()
	if self.__py then
		return self.__py + 16
	end
	return 500
end
function R:GetObjectType() return self.__kind end

local F = methods.Frame
inherit(F, R)
function F:SetScale(s) assert(type(s) == "number" and s > 0, "SetScale") self.__scale = s end
function F:GetScale() return self.__scale end
function F:GetEffectiveScale() return self.__scale end
function F:SetFrameStrata(s) self.__strata = s self.__strataSet = true end
function F:GetFrameStrata() return self.__strata end
function F:SetFrameLevel(l) self.__level = l self.__levelSet = true end
-- as in the client: a frame sits one level above its parent unless it was set
function F:GetFrameLevel()
	if self.__levelSet then
		return self.__level
	end
	return self.__parent and self.__parent.GetFrameLevel and (self.__parent:GetFrameLevel() + 1) or 0
end
function F:EnableMouse() end
function F:EnableMouseWheel() end
function F:RegisterForDrag() end
function F:SetMovable() end
function F:StartMoving() end
function F:StopMovingOrSizing() end
function F:SetUserPlaced() end
function F:SetClampedToScreen() end
function F:SetParent(p)
	self.__parent = p
	table.insert(p.__children, self)
end
function F:SetID(i) self.__id = i end
function F:GetID() return self.__id or 0 end
function F:SetBackdrop() end
function F:SetBackdropColor() end
function F:SetBackdropBorderColor() end
function F:SetScript(name, fn)
	assert(fn == nil or type(fn) == "function", "SetScript wants a function")
	self.__scripts[name] = fn
	if name == "OnUpdate" then
		table.insert(MOCK.frames, self)
	end
end
function F:GetScript(name) return self.__scripts[name] end
function F:RegisterEvent(e) self.__events[e] = true table.insert(MOCK.frames, self) end
function F:UnregisterEvent(e) self.__events[e] = nil end
function F:UnregisterAllEvents() self.__events = {} end
function F:GetRegions()
	local out = {}
	for _, c in ipairs(self.__children) do
		if c.__kind == "Texture" or c.__kind == "FontString" then
			out[#out + 1] = c
		end
	end
	return unpack(out)
end
function F:GetChildren()
	local out = {}
	for _, c in ipairs(self.__children) do
		if c.__kind ~= "Texture" and c.__kind ~= "FontString" then
			out[#out + 1] = c
		end
	end
	return unpack(out)
end
function F:GetNumChildren()
	local n = 0
	for _, c in ipairs(self.__children) do
		if c.__kind ~= "Texture" and c.__kind ~= "FontString" then
			n = n + 1
		end
	end
	return n
end
function F:CreateTexture(name, layer)
	local t = new("Texture", name, self)
	t.__layer = layer
	return t
end
function F:CreateFontString(name, layer)
	local t = new("FontString", name, self)
	t.__layer = layer
	return t
end

local B = methods.Button
inherit(B, F)
function B:RegisterForClicks() end
function B:SetText(s) self.__text = s end
function B:GetNormalTexture() return nil end
function B:Click() local fn = self.__scripts.OnClick if fn then this = self arg1 = "LeftButton" fn() end end

local SB = methods.StatusBar
inherit(SB, F)
function SB:SetStatusBarTexture(path)
	assert(type(path) == "string", "SetStatusBarTexture: path")
	self.__sbtex = path
end
function SB:GetStatusBarTexture() return self.__fill end
function SB:SetStatusBarColor(r, g, b) assert(type(b) == "number") self.__sbcolor = { r, g, b } end
function SB:GetStatusBarColor() local c = self.__sbcolor or { 0, 1, 0 } return c[1], c[2], c[3], 1 end
function SB:SetMinMaxValues(lo, hi) self.__lo, self.__hi = lo, hi end
function SB:GetMinMaxValues() return self.__lo or 0, self.__hi or 1 end
function SB:SetValue(v) self.__v = v end
function SB:GetValue() return self.__v or 0 end

local T = methods.Texture
inherit(T, R)
function T:SetTexture(a, g, b, al)
	MOCK.calls.SetTexture = MOCK.calls.SetTexture + 1
	if type(a) == "number" then
		self.__tex = "color"
	else
		assert(a == nil or type(a) == "string", "SetTexture: path")
		self.__tex = a
	end
	return 1
end
function T:GetTexture() return self.__tex end
function T:SetVertexColor(r, g, b, a)
	assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "SetVertexColor: rgb")
	MOCK.calls.SetVertexColor = MOCK.calls.SetVertexColor + 1
	self.__color = { r, g, b, a or 1 }
	self.__grad = nil
end
function T:SetGradient(d, r1, g1, b1, r2, g2, b2)
	assert(d == "HORIZONTAL" or d == "VERTICAL")
	self.__grad = { d, r1, g1, b1, 1, r2, g2, b2, 1 }
end
function T:SetGradientAlpha(d, r1, g1, b1, a1, r2, g2, b2, a2)
	assert(d == "HORIZONTAL" or d == "VERTICAL", "gradient direction")
	assert(type(a2) == "number", "SetGradientAlpha needs 9 args")
	self.__grad = { d, r1, g1, b1, a1, r2, g2, b2, a2 }
	self.__color = nil
end
function T:SetTexCoord(a, b, c, d)
	assert(type(d) == "number", "SetTexCoord needs 4 numbers")
	self.__coord = { a, b, c, d }
end
function T:SetBlendMode(m)
	assert(m == "ADD" or m == "BLEND" or m == "ALPHAKEY" or m == "MOD" or m == "DISABLE")
	self.__blend = m
end

local FS = methods.FontString
inherit(FS, R)
function FS:SetFont(path, size, flags)
	assert(type(path) == "string" and type(size) == "number", "SetFont")
	self.__font = { path, size, flags }
end
function FS:GetFont() if self.__font then return self.__font[1], self.__font[2], self.__font[3] end end
MOCK.calls = { SetText = 0, SetWidth = 0, SetTexture = 0, SetVertexColor = 0 }
function FS:SetText(s)
	MOCK.calls.SetText = MOCK.calls.SetText + 1
	if s ~= nil and type(s) ~= "string" and type(s) ~= "number" then
		error("SetText: " .. type(s))
	end
	self.__text = s
end
function FS:GetText() return self.__text end
function FS:SetTextColor(r, g, b, a)
	assert(type(r) == "number", "SetTextColor")
	self.__tcolor = { r, g, b, a or 1 }
end
function FS:SetShadowColor() end
function FS:SetShadowOffset() end
function FS:SetJustifyH(j) self.__justify = j end
function FS:SetJustifyV() end
function FS:GetStringWidth() return string.len(self.__text or "") * 6 end

local GT = methods.GameTooltip
inherit(GT, F)
function GT:SetOwner(o, anchor) self.__lines = {} end
function GT:SetText(s) self.__lines = { s } end
function GT:AddLine(s) table.insert(self.__lines, s) end
function GT:AddDoubleLine(a, b) table.insert(self.__lines, tostring(a) .. " | " .. tostring(b)) end
function GT:SetAction(slot) assert(type(slot) == "number") return 1 end
function GT:SetPlayerBuff(id) assert(type(id) == "number") end
function GT:SetUnit() end

function ShowNameplates() NAMEPLATES_ON = 1 MOCK.platesShown = true end
function HideNameplates() NAMEPLATES_ON = nil MOCK.platesShown = false end

-- A client nameplate as 1.12 builds it: border, glow, name, level, skull, raid icon, bar.
function MOCK.SpawnPlate(name, value, max, x, y)
	local p = new("Frame", nil, WorldFrame)
	p.__w, p.__h, p.__px, p.__py = 120, 32, x, y
	p:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", x, y)
	local border = p:CreateTexture(nil, "BORDER")
	border:SetTexture("Interface\\Tooltips\\Nameplate-Border")
	border:SetAllPoints(p)
	local glow = p:CreateTexture(nil, "OVERLAY")
	glow:SetTexture("Interface\\Tooltips\\Nameplate-Glow")
	glow:SetAllPoints(p)
	local fs = p:CreateFontString(nil, "ARTWORK")
	fs:SetFont("Fonts\\FRIZQT__.TTF", 12)
	fs:SetText(name)
	fs:SetPoint("BOTTOM", p, "CENTER", 0, 4)
	local lvl = p:CreateFontString(nil, "ARTWORK")
	lvl:SetFont("Fonts\\FRIZQT__.TTF", 10)
	lvl:SetText("17")
	lvl:SetPoint("RIGHT", p, "RIGHT", 0, 0)
	local skull = p:CreateTexture(nil, "ARTWORK")
	skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
	skull:SetPoint("LEFT", p, "LEFT", 0, 0)
	local raid = p:CreateTexture(nil, "ARTWORK")
	raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	raid:Hide()
	local bar = new("StatusBar", nil, p)
	bar:SetMinMaxValues(0, max)
	bar:SetValue(value)
	bar:SetStatusBarColor(1, 0, 0)
	bar:SetPoint("BOTTOM", p, "BOTTOM", 0, 4)
	bar.__w, bar.__h = 100, 8
	return p
end

function CreateFrame(kind, name, parent, template)
	assert(methods[kind] and kind ~= "Region" and kind ~= "Texture" and kind ~= "FontString", "CreateFrame: unknown type " .. tostring(kind))
	return new(kind, name, parent)
end

------------------------------------------------------------------------
-- The client's frames and functions the addon touches
------------------------------------------------------------------------

UIParent = new("Frame", "UIParent")
UIParent.__w, UIParent.__h = 1365, 768
WorldFrame = new("Frame", "WorldFrame")
GameTooltip = new("GameTooltip", "GameTooltip", UIParent)
UISpecialFrames = {}
SlashCmdList = {}

DEFAULT_CHAT_FRAME = new("Frame", "ChatFrame1", UIParent)
function DEFAULT_CHAT_FRAME:AddMessage(msg) table.insert(MOCK.chat, msg) end

for _, n in ipairs({ "PlayerFrame", "TargetFrame", "ComboFrame", "BuffFrame", "TemporaryEnchantFrame", "MainMenuBar", "MainMenuBarArtFrame",
	"MainMenuExpBar", "MainMenuBarMaxLevelBar" }) do
	new("Frame", n, UIParent)
end
for i = 1, 12 do
	new("Button", "ActionButton" .. i, MainMenuBarArtFrame)
end
new("Button", "CharacterMicroButton", MainMenuBarArtFrame)
new("Button", "TalentMicroButton", MainMenuBarArtFrame)

function getglobal(n) return _G[n] end
function setglobal(n, v) _G[n] = v end
function SetCVar(k, v) MOCK.cvars[k] = tostring(v) end
function GetCVar(k) return MOCK.cvars[k] end
function ReloadUI() MOCK.reloaded = true end
function ToggleCharacter() MOCK.character = true end
function ToggleTalentFrame() MOCK.talents = true end
function TargetByName(n) MOCK.targeted = n end
function SetPortraitTexture(tex, unit)
	assert(tex and tex.__kind == "Texture", "SetPortraitTexture wants a texture")
	tex.__tex = "Portrait"
end

local function U(unit)
	if unit == "player" then
		return MOCK.player
	elseif unit == "target" then
		return MOCK.target
	elseif unit == "pet" then
		return MOCK.pet
	elseif unit == "mouseover" then
		return MOCK.mouseover
	end
	local _, _, n = string.find(unit or "", "^party(%d)$")
	if n and MOCK.party then
		return MOCK.party[tonumber(n)]
	end
end
function UnitExists(u) return U(u) ~= nil end
function UnitName(u) local d = U(u) return d and d.name end
function UnitClass(u) local d = U(u) if d then return d.class or "Warrior", d.token or "WARRIOR" end end
function UnitRace(u) local d = U(u) return d and (d.race or "Human") end
function UnitLevel(u) local d = U(u) return d and (d.level or 1) or 0 end
function UnitHealth(u) local d = U(u) return d and d.hp or 0 end
function UnitHealthMax(u) local d = U(u) return d and d.hpm or 0 end
function UnitIsPlayer(u) local d = U(u) return d and (u == "player" or d.player) and 1 or nil end
function UnitIsFriend(a, b) local d = U(b) return d and (b == "player" or d.friend) and 1 or nil end
function UnitIsDead(u) local d = U(u) return d and d.dead and 1 or nil end
function UnitIsUnit(a, b)
	local da = U(a)
	return da ~= nil and da == U(b) and 1 or nil
end
function UnitPlayerControlled(u) return UnitIsPlayer(u) end
function UnitClassification(u) local d = U(u) return d and d.classification or "normal" end
function UnitXP() return MOCK.player.xp end
function UnitXPMax() return MOCK.player.xpm end
function UnitDebuff(u, i)
	local d = U(u)
	local list = d and d.debuffs or {}
	local x = list[i]
	if x then
		return x[1], x[2], x[3]
	end
end

function HasAction(slot) return MOCK.actions[slot] and 1 or nil end
function GetActionTexture(slot)
	if MOCK.actions[slot] then
		return "Interface\\Icons\\Mock_Slot" .. slot
	end
end

-- 1.12 player auras: GetPlayerBuff(i, filter) -> id or -1
local function filtered(filter)
	local out = {}
	for _, b in ipairs(MOCK.buffs) do
		if (filter == "HARMFUL") == (b.harmful == true) then
			table.insert(out, b)
		end
	end
	return out
end
function GetPlayerBuff(i, filter)
	local list = filtered(filter)
	if list[i + 1] then
		list[i + 1].id = (filter == "HARMFUL" and 100 or 0) + i
		return list[i + 1].id, 0
	end
	return -1, 0
end
local function byId(id)
	for _, b in ipairs(MOCK.buffs) do
		if b.id == id then
			return b
		end
	end
end
function GetPlayerBuffTexture(id) local b = byId(id) return b and b.texture end
function GetPlayerBuffApplications(id) local b = byId(id) return b and b.apps or 0 end
function GetPlayerBuffTimeLeft(id) local b = byId(id) return b and b.left or 0 end
function CancelPlayerBuff(id) MOCK.cancelled = id end
function GetLocale() return MOCK.locale or "enUS" end
-- GlobalStrings (enUS) the combat log is written with
COMBATHITSELFOTHER = "You hit %s for %d."
COMBATHITCRITSELFOTHER = "You crit %s for %d."
COMBATHITSCHOOLSELFOTHER = "You hit %s for %d %s damage."
COMBATHITCRITSCHOOLSELFOTHER = "You crit %s for %d %s damage."
SPELLLOGSELFOTHER = "Your %s hits %s for %d."
SPELLLOGCRITSELFOTHER = "Your %s crits %s for %d."
SPELLLOGSCHOOLSELFOTHER = "Your %s hits %s for %d %s damage."
SPELLLOGCRITSCHOOLSELFOTHER = "Your %s crits %s for %d %s damage."
PERIODICAURADAMAGESELFOTHER = "%s suffers %d %s damage from your %s."
PERIODICAURADAMAGEOTHEROTHER = "%s suffers %d %s damage from %s's %s."
COMBATHITOTHEROTHER = "%s hits %s for %d."
COMBATHITCRITOTHEROTHER = "%s crits %s for %d."
COMBATHITSCHOOLOTHEROTHER = "%s hits %s for %d %s damage."
COMBATHITCRITSCHOOLOTHEROTHER = "%s crits %s for %d %s damage."
SPELLLOGOTHEROTHER = "%s's %s hits %s for %d."
SPELLLOGCRITOTHEROTHER = "%s's %s crits %s for %d."
SPELLLOGSCHOOLOTHEROTHER = "%s's %s hits %s for %d %s damage."
SPELLLOGCRITSCHOOLOTHEROTHER = "%s's %s crits %s for %d %s damage."
DAMAGESHIELDSELFOTHER = "You reflect %d %s damage to %s."
COMBATHITOTHERSELF = "%s hits you for %d."
COMBATHITCRITOTHERSELF = "%s crits you for %d."
COMBATHITSCHOOLOTHERSELF = "%s hits you for %d %s damage."
COMBATHITCRITSCHOOLOTHERSELF = "%s crits you for %d %s damage."
SPELLLOGOTHERSELF = "%s's %s hits you for %d."
SPELLLOGCRITOTHERSELF = "%s's %s crits you for %d."
SPELLLOGSCHOOLOTHERSELF = "%s's %s hits you for %d %s damage."
SPELLLOGCRITSCHOOLOTHERSELF = "%s's %s crits you for %d %s damage."
PERIODICAURADAMAGEOTHERSELF = "You suffer %d %s damage from %s's %s."
PERIODICAURADAMAGESELFSELF = "You suffer %d %s damage from your %s."
HEALEDSELFSELF = "Your %s heals you for %d."
HEALEDCRITSELFSELF = "Your %s critically heals you for %d."
PERIODICAURAHEALSELFSELF = "You gain %d health from %s."
PERIODICAURAHEALOTHERSELF = "You gain %d health from %s's %s."
SPELL_SCHOOL0_CAP, SPELL_SCHOOL1_CAP, SPELL_SCHOOL2_CAP, SPELL_SCHOOL3_CAP = "Physical", "Holy", "Fire", "Nature"
SPELL_SCHOOL4_CAP, SPELL_SCHOOL5_CAP, SPELL_SCHOOL6_CAP = "Frost", "Shadow", "Arcane"

function GetPlayerBuffDispelType(id) local b = byId(id) return b and b.dispel end

------------------------------------------------------------------------
-- Driving it
------------------------------------------------------------------------

local function call(frame, script, ...)
	local fn = frame.__scripts[script]
	if not fn then
		return
	end
	this = frame
	local ok, err = pcall(fn, ...)
	if not ok then
		report(script .. ": " .. tostring(err))
	end
end

function MOCK.Fire(e, a1, a2, a3, a4)
	event, arg1, arg2, arg3, arg4 = e, a1, a2, a3, a4
	local seen = {}
	for _, f in ipairs(MOCK.frames) do
		if not seen[f] and f.__events[e] then
			seen[f] = true
			event, arg1, arg2, arg3, arg4 = e, a1, a2, a3, a4
			call(f, "OnEvent")
		end
	end
end

-- The server's addon line, as the client delivers it.
function MOCK.Addon(prefix, msg)
	MOCK.Fire("CHAT_MSG_ADDON", prefix, msg, "WHISPER", "Server")
end

function MOCK.Step(dt)
	MOCK.time = MOCK.time + dt
	local seen = {}
	for _, f in ipairs(MOCK.frames) do
		if not seen[f] and f.__scripts.OnUpdate and f:IsVisible() then
			seen[f] = true
			arg1 = dt
			call(f, "OnUpdate")
		end
	end
end

function MOCK.Run(seconds, dt)
	dt = dt or 0.02
	local n = math.floor(seconds / dt + 0.5)
	for i = 1, n do
		MOCK.Step(dt)
	end
end

function MOCK.Slash(cmd, msg)
	for k, fn in pairs(SlashCmdList) do
		local i = 1
		while _G["SLASH_" .. k .. i] do
			if _G["SLASH_" .. k .. i] == cmd then
				local ok, err = pcall(fn, msg or "")
				if not ok then
					report("slash: " .. tostring(err))
				end
				return
			end
			i = i + 1
		end
	end
	report("no slash command " .. cmd)
end

-- Click / hover a scripted frame from the test.
function MOCK.Script(frame, script, a1)
	arg1 = a1
	call(frame, script)
end
