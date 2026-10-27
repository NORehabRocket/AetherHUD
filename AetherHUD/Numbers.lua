-- AetherHUD floating combat numbers, Aion style: your hits rise over the enemy's plate in
-- its spell school's colour, criticals burst in gold and settle, damage over time ticks
-- small, and what you take (red) or heal (green) floats beside the hero. Read from the
-- 1.12 combat log, with patterns built from the client's own (localized) GlobalStrings.

local A = AetherHUD
local C, D = A.C, A.D

local MAX = 40      -- numbers on screen at once; the oldest makes way
local BASE = 26     -- font size; numbers are scaled down from it so they stay sharp

------------------------------------------------------------------------
-- Combat log patterns
------------------------------------------------------------------------

local compiled = {}

local function Escape(ch)
	if string.find(ch, "[%^%$%(%)%%%.%[%]%*%+%-%?]") then
		return "%" .. ch
	end
	return ch
end

-- "Your %s hits %s for %d %s damage." -> a Lua pattern, and for each format argument
-- (in the English order) which capture holds it. Handles "%2$s" reordering.
function A.CompileLog(global)
	local cached = compiled[global]
	if cached ~= nil then
		return cached
	end
	local fmt = getglobal(global)
	if type(fmt) ~= "string" or fmt == "" then
		compiled[global] = false
		return false
	end
	local pat, map = "^", {}
	local arg, cap = 0, 0
	local i, len = 1, string.len(fmt)
	local endsWithArg = false
	while i <= len do
		local ch = string.sub(fmt, i, i)
		if ch == "%" then
			local _, e, pos, conv = string.find(fmt, "^%%(%d*)%$?([sd])", i)
			if e then
				arg = arg + 1
				cap = cap + 1
				map[tonumber(pos) or arg] = cap
				pat = pat .. (conv == "d" and "(%d+)" or "(.-)")
				i = e + 1
				endsWithArg = true
			else
				pat = pat .. "%%"
				i = i + 1
				if string.sub(fmt, i, i) == "%" then
					i = i + 1
				end
				endsWithArg = false
			end
		else
			pat = pat .. Escape(ch)
			i = i + 1
			endsWithArg = false
		end
	end
	if endsWithArg then
		pat = pat .. "$"
	end
	local p = { pat = pat, map = map }
	compiled[global] = p
	return p
end

-- One reusable result table per parse: the 5.0 collector pauses the game, so no garbage per hit.
local hit = {}
local caps = {}

local function Try(msg, global, fields)
	local p = A.CompileLog(global)
	if not p then
		return false
	end
	local s, _, c1, c2, c3, c4, c5 = string.find(msg, p.pat)
	if not s then
		return false
	end
	caps[1], caps[2], caps[3], caps[4], caps[5] = c1, c2, c3, c4, c5
	hit.spell, hit.target, hit.amount, hit.school, hit.source = nil, nil, nil, nil, nil
	for n = 1, table.getn(fields) do
		hit[fields[n]] = caps[p.map[n] or n]
	end
	hit.amount = tonumber(hit.amount)
	return hit.amount ~= nil
end

-- { global, fields in the English argument order, crit }
local RULES = {
	CHAT_MSG_SPELL_SELF_DAMAGE = { kind = "hit", {
		{ "SPELLLOGCRITSCHOOLSELFOTHER", { "spell", "target", "amount", "school" }, true },
		{ "SPELLLOGSCHOOLSELFOTHER", { "spell", "target", "amount", "school" } },
		{ "SPELLLOGCRITSELFOTHER", { "spell", "target", "amount" }, true },
		{ "SPELLLOGSELFOTHER", { "spell", "target", "amount" } },
	} },
	CHAT_MSG_COMBAT_SELF_HITS = { kind = "hit", {
		{ "COMBATHITCRITSCHOOLSELFOTHER", { "target", "amount", "school" }, true },
		{ "COMBATHITSCHOOLSELFOTHER", { "target", "amount", "school" } },
		{ "COMBATHITCRITSELFOTHER", { "target", "amount" }, true },
		{ "COMBATHITSELFOTHER", { "target", "amount" } },
	} },
	CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF = { kind = "hit", {
		{ "DAMAGESHIELDSELFOTHER", { "amount", "school", "target" } },
	} },
	CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE = { kind = "dot", {
		{ "PERIODICAURADAMAGESELFOTHER", { "target", "amount", "school", "spell" } },
		{ "PERIODICAURADAMAGEOTHEROTHER", { "target", "amount", "school", "source", "spell" }, false, true },
	} },
	CHAT_MSG_COMBAT_PET_HITS = { kind = "pet", {
		{ "COMBATHITCRITSCHOOLOTHEROTHER", { "source", "target", "amount", "school" }, true },
		{ "COMBATHITSCHOOLOTHEROTHER", { "source", "target", "amount", "school" } },
		{ "COMBATHITCRITOTHEROTHER", { "source", "target", "amount" }, true },
		{ "COMBATHITOTHEROTHER", { "source", "target", "amount" } },
	} },
	CHAT_MSG_SPELL_PET_DAMAGE = { kind = "pet", {
		{ "SPELLLOGCRITSCHOOLOTHEROTHER", { "source", "spell", "target", "amount", "school" }, true },
		{ "SPELLLOGSCHOOLOTHEROTHER", { "source", "spell", "target", "amount", "school" } },
		{ "SPELLLOGCRITOTHEROTHER", { "source", "spell", "target", "amount" }, true },
		{ "SPELLLOGOTHEROTHER", { "source", "spell", "target", "amount" } },
	} },
	CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS = { kind = "taken", {
		{ "COMBATHITCRITSCHOOLOTHERSELF", { "source", "amount", "school" }, true },
		{ "COMBATHITSCHOOLOTHERSELF", { "source", "amount", "school" } },
		{ "COMBATHITCRITOTHERSELF", { "source", "amount" }, true },
		{ "COMBATHITOTHERSELF", { "source", "amount" } },
	} },
	CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE = { kind = "taken", {
		{ "SPELLLOGCRITSCHOOLOTHERSELF", { "source", "spell", "amount", "school" }, true },
		{ "SPELLLOGSCHOOLOTHERSELF", { "source", "spell", "amount", "school" } },
		{ "SPELLLOGCRITOTHERSELF", { "source", "spell", "amount" }, true },
		{ "SPELLLOGOTHERSELF", { "source", "spell", "amount" } },
	} },
	CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE = { kind = "taken", {
		{ "PERIODICAURADAMAGEOTHERSELF", { "amount", "school", "source", "spell" } },
		{ "PERIODICAURADAMAGESELFSELF", { "amount", "school", "spell" } },
	} },
	CHAT_MSG_SPELL_SELF_BUFF = { kind = "heal", {
		{ "HEALEDCRITSELFSELF", { "spell", "amount" }, true },
		{ "HEALEDSELFSELF", { "spell", "amount" } },
	} },
	CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS = { kind = "heal", {
		{ "PERIODICAURAHEALSELFSELF", { "amount", "spell" } },
		{ "PERIODICAURAHEALOTHERSELF", { "amount", "source", "spell" } },
	} },
}

-- A periodic tick written as "X suffers N from Y's Z" counts when Y is yours.
local function Yours(source)
	if not source then
		return false
	end
	if source == UnitName("player") or (UnitExists("pet") and source == UnitName("pet")) then
		return true
	end
	local s = D.Summons()
	for i = 1, table.getn(s) do
		if s[i].name == source then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------
-- Look
------------------------------------------------------------------------

local SCHOOLS = { "Physical", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" }
local SCHOOL_COLOR = {
	Physical = { 1.00, 0.95, 0.84 },
	Holy = { 1.00, 0.92, 0.50 },
	Fire = { 1.00, 0.55, 0.18 },
	Nature = { 0.55, 1.00, 0.35 },
	Frost = { 0.50, 0.88, 1.00 },
	Shadow = { 0.78, 0.55, 1.00 },
	Arcane = { 1.00, 0.60, 1.00 },
}
local CRIT = { 1.00, 0.78, 0.22 }
local TAKEN = { 1.00, 0.28, 0.22 }
local HEAL = { 0.45, 1.00, 0.55 }
local PET = { 0.80, 0.84, 0.92 }

local schoolCache = {}
local function SchoolColor(name)
	if not name or name == "" then
		return SCHOOL_COLOR.Physical
	end
	local c = schoolCache[name]
	if c then
		return c
	end
	local lower = string.lower(name)
	c = SCHOOL_COLOR.Physical
	for n = 1, 7 do
		local loc = getglobal("SPELL_SCHOOL" .. (n - 1) .. "_CAP")
		if lower == string.lower(SCHOOLS[n]) or (type(loc) == "string" and lower == string.lower(loc)) then
			c = SCHOOL_COLOR[SCHOOLS[n]]
			break
		end
	end
	schoolCache[name] = c
	return c
end

-- scale (of BASE), how far it rises, how long it lives, pop = starting size for a burst
local STYLES = {
	hit = { scale = 0.6, rise = 34, life = 0.95 },
	crit = { scale = 0.92, rise = 26, life = 1.3, pop = 1.75, burst = true },
	dot = { scale = 0.46, rise = 22, life = 0.8 },
	pet = { scale = 0.5, rise = 28, life = 0.85 },
	taken = { scale = 0.64, rise = 30, life = 1.1 },
	heal = { scale = 0.6, rise = 30, life = 1.1 },
}

------------------------------------------------------------------------
-- The numbers: a fixed pool, an active list kept packed by hand (no table.getn on lists
-- that get emptied: 5.0 remembers their old length)
------------------------------------------------------------------------

local canvas
local pool, nPool, created = {}, 0, 0
local active, nActive = {}, 0

local function New()
	created = created + 1
	local f = CreateFrame("Frame", nil, canvas)
	f:SetWidth(1)
	f:SetHeight(1)
	local burst = f:CreateTexture(nil, "BACKGROUND")
	burst:SetTexture(A.MEDIA .. "glow")
	burst:SetBlendMode("ADD")
	burst:SetWidth(BASE * 4)
	burst:SetHeight(BASE * 2.4)
	burst:SetPoint("CENTER", f, "CENTER", 0, 0)
	local text = f:CreateFontString(nil, "OVERLAY")
	text:SetFont(A.FONT, BASE, "THICKOUTLINE")
	text:SetShadowColor(0, 0, 0, 0.9)
	text:SetShadowOffset(2, -2)
	text:SetPoint("CENTER", f, "CENTER", 0, 0)
	return { f = f, text = text, burst = burst }
end

local function Release(i)
	local o = active[i]
	o.f:Hide()
	o.key = nil
	for j = i, nActive - 1 do
		active[j] = active[j + 1]
	end
	active[nActive] = nil
	nActive = nActive - 1
	nPool = nPool + 1
	pool[nPool] = o
end

local function Format(o)
	local v = o.amount
	local s = v >= 100000 and A.Short(v) or A.Comma(v)
	if o.kind == "taken" then
		return "-" .. s
	elseif o.kind == "heal" then
		return "+" .. s
	end
	return s
end

local function Place(o)
	local p = o.age / o.life
	local ease = 1 - (1 - p) * (1 - p)
	local s = o.scale
	if o.pop and o.age < 0.14 then
		s = o.scale * (o.pop + (1 - o.pop) * o.age / 0.14)
	end
	if o.bump > 0 then
		s = s * (1 + o.bump)
	end
	if o.s ~= s then
		o.s = s
		o.f:SetScale(s)
	end
	local x = o.x + o.dx * ease
	local y = o.y + o.rise * ease
	o.f:ClearAllPoints()
	o.f:SetPoint("CENTER", canvas, "BOTTOMLEFT", x / s, y / s)
	local a = 1
	if o.age < 0.06 then
		a = o.age / 0.06
	elseif p > 0.7 then
		a = (1 - p) / 0.3
	end
	o.f:SetAlpha(a)
	if o.burstOn then
		local b = math.max(0, 1 - o.age / 0.35)
		o.burst:SetAlpha(b * 0.85)
	end
end

local function Spawn(x, y, amount, kind, color, key)
	-- the same spell on the same enemy a moment later adds up instead of stacking
	if key then
		for i = nActive, 1, -1 do
			local o = active[i]
			if o.key == key and o.age < 0.35 then
				o.amount = o.amount + amount
				o.dirty = true -- redrawn once per frame however many hits land
				o.age = math.min(o.age, 0.12)
				o.bump = 0.18
				return
			end
		end
	end
	local o
	if nPool > 0 then
		o = pool[nPool]
		pool[nPool] = nil
		nPool = nPool - 1
	elseif created < MAX then
		o = New()
	else
		Release(1) -- the oldest makes way
		o = pool[nPool]
		pool[nPool] = nil
		nPool = nPool - 1
	end
	local st = STYLES[kind] or STYLES.hit
	local size = A.db.numbers.size or 1
	o.kind, o.key, o.amount = kind, key, amount
	o.x, o.y = x, y
	o.dx = (math.random() - 0.5) * 30
	o.rise = st.rise
	o.life = st.life
	o.scale = st.scale * size
	o.pop = st.pop
	o.age, o.bump, o.s = 0, 0, nil
	o.text:SetText(Format(o))
	o.text:SetTextColor(color[1], color[2], color[3])
	o.burstOn = st.burst
	if st.burst then
		o.burst:SetVertexColor(color[1], color[2], color[3], 1)
		o.burst:Show()
	else
		o.burst:Hide()
	end
	nActive = nActive + 1
	active[nActive] = o
	Place(o)
	o.f:Show()
end

local function Tick(dt)
	local i = 1
	while i <= nActive do
		local o = active[i]
		o.age = o.age + dt
		if o.bump > 0 then
			o.bump = math.max(0, o.bump - dt)
		end
		if o.age >= o.life then
			Release(i)
		else
			if o.dirty then
				o.dirty = nil
				o.text:SetText(Format(o))
			end
			Place(o)
			i = i + 1
		end
	end
end

------------------------------------------------------------------------
-- Where a number goes
------------------------------------------------------------------------

local stackName, stackAt, stackN = nil, 0, 0

local function Hero()
	return UIParent:GetWidth() / 2, UIParent:GetHeight() / 2 + 30
end

local function AtEnemy(name)
	local x, y
	if A.Plates and A.Plates.Locate then
		x, y = A.Plates.Locate(name)
	end
	if x then
		y = y + 8
	else
		-- no plate up: somewhere in a ring around the hero, like the swarm itself
		local cx, cy = Hero()
		local angle = math.random() * 6.2832
		local r = 60 + math.random() * 60
		x, y = cx + math.cos(angle) * r, cy + math.sin(angle) * r * 0.6
	end
	-- several numbers on one enemy at once climb a step each
	local now = GetTime()
	if stackName == name and now - stackAt < 0.25 then
		stackN = stackN + 1
	else
		stackName, stackN = name, 0
	end
	stackAt = now
	return x, y + math.mod(stackN, 3) * 12
end

-- tag: what merges with what when the line names no spell (melee, damage shields)
local function Show(kind, crit, tag)
	local h = hit
	local color, style, key
	if kind == "taken" then
		if not A.db.numbers.taken then
			return
		end
		local cx, cy = Hero()
		Spawn(cx - 52, cy + 22, h.amount, "taken", TAKEN, "taken")
		return
	elseif kind == "heal" then
		if not A.db.numbers.heals then
			return
		end
		local cx, cy = Hero()
		Spawn(cx + 52, cy + 22, h.amount, "heal", HEAL, "heal")
		return
	end
	if not h.target or h.target == "" then
		return
	end
	local x, y = AtEnemy(h.target)
	if crit then
		style, color = "crit", CRIT
	elseif kind == "dot" then
		style, color = "dot", SchoolColor(h.school)
	elseif kind == "pet" then
		style, color = "pet", PET
	else
		style, color = "hit", SchoolColor(h.school)
	end
	-- merge key: spell + enemy + crit (strings are interned, so this costs little)
	key = (h.spell or tag or kind) .. "\031" .. h.target .. (crit and "!" or "")
	Spawn(x, y, h.amount, style, color, key)
end

local function OnCombat(ev, msg)
	local rule = RULES[ev]
	if not rule or type(msg) ~= "string" then
		return
	end
	local list = rule[1]
	for i = 1, table.getn(list) do
		local r = list[i]
		if Try(msg, r[1], r[2]) then
			if r[4] and not Yours(hit.source) then
				return
			end
			if hit.amount > 0 then
				Show(rule.kind, r[3], r[1])
			end
			return
		end
	end
end

-- Sample hits while previewing (/aether demo): a few numbers around the hero.
local demoWait = 0
local DEMO_NAMES = { "Defias Thug", "Kobold Geomancer", "Mother Fang", "Murloc Raider" }
local DEMO_SCHOOLS = { "Frost", "Fire", "Arcane", "Physical", "Shadow" }
local function DemoTick(dt)
	if not A.demo then
		return
	end
	demoWait = demoWait - dt
	if demoWait > 0 then
		return
	end
	demoWait = 0.18 + math.random() * 0.25
	hit.target = DEMO_NAMES[math.random(1, 4)]
	hit.school = DEMO_SCHOOLS[math.random(1, 5)]
	hit.spell = hit.school
	local roll = math.random()
	if roll < 0.15 then
		hit.amount = math.random(2400, 9800)
		Show("hit", true)
	elseif roll < 0.3 then
		hit.amount = math.random(40, 160)
		Show("dot")
	elseif roll < 0.38 then
		hit.amount = math.random(30, 90)
		Show("taken")
	elseif roll < 0.44 then
		hit.amount = math.random(50, 200)
		Show("heal")
	else
		hit.amount = math.random(300, 1900)
		Show("hit")
	end
end

local function Init()
	if not A.On("numbers") then
		return
	end
	canvas = CreateFrame("Frame", "AetherHUDNumbers", UIParent)
	canvas:SetAllPoints(UIParent)
	canvas:SetFrameStrata("MEDIUM")

	-- the client's own floating numbers off while ours run; the log must reach far
	-- enough for the whole swarm and include damage over time
	A.OwnCVar("CombatDamage", "0")
	A.OwnCVar("PetMeleeDamage", "0")
	A.OwnCVar("PetSpellDamage", "0")
	A.OwnCVar("CombatLogPeriodicSpells", "1")
	for _, name in ipairs({ "CombatLogRangeCreature", "CombatLogRangeHostilePlayers", "CombatLogRangeHostilePlayersPets",
		"CombatLogRangeParty", "CombatLogRangePartyPet" }) do
		local ok, cur = pcall(GetCVar, name)
		if ok and tonumber(cur) and tonumber(cur) < 200 then
			A.OwnCVar(name, "200")
		end
	end

	local ev = CreateFrame("Frame")
	for name in pairs(RULES) do
		ev:RegisterEvent(name)
	end
	ev:SetScript("OnEvent", function()
		local ok, err = pcall(OnCombat, event, arg1)
		if not ok then
			A.Error(err)
		end
	end)
	A.Every(0.025, Tick)
	A.Every(0.05, DemoTick)
end

A.OnInit(Init)
