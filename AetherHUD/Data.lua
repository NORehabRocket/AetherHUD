-- AetherHUD data: every module reads the run through here. Numbers are coerced (the
-- client hands some over as text), flags turned into booleans, and in demo mode a
-- sample run stands in for the real one.

local A = AetherHUD
local D = {}
A.D = D

local N, Flag = A.N, A.Flag
local EMPTY = {}

local function List(t)
	if type(t) == "table" then
		return t
	end
	return EMPTY
end

------------------------------------------------------------------------
-- Demo run
------------------------------------------------------------------------

local demoStart
local function DT()
	if not demoStart then
		demoStart = GetTime() - 412
	end
	return GetTime() - demoStart
end

local DEMO_SPELLS = {
	"Spell_Frost_FrostBolt02", "Spell_Fire_FlameBolt", "Spell_Nature_StarFall",
	"Spell_Frost_IceStorm", "Spell_Nature_WispSplode", "Spell_Frost_FrostNova",
	"Spell_Shadow_UnholyStrength",
}

local function DemoRun()
	local t = DT()
	local hpm = 2400
	local hp = math.floor(hpm * (0.55 + 0.4 * math.sin(t * 0.35)))
	return {
		t = t, ph = "playing", lvl = 17, xp = math.mod(t * 37, 4200), xpn = 4200,
		hp = hp, hpm = hpm, sh = math.mod(math.floor(t / 6), 2) == 0 and 320 or 0,
		gold = 1873, kills = 2481 + math.floor(t * 3), en = 118, el = 3, bu = 2, gu = 2, ga = 1,
		lairs = 4, bs = 3, bt = 5, nb = math.mod(600 - t, 120), nbn = "Mother Fang",
		fin = 960, left = 960 - t, endl = 0, won = 0, lives = 2, rr = 3, rrc = 150, chest = 240,
		dealt = 412300, taken = 18450, ge = 2320, bk = 2, gk = 1, ek = 12, ck = 4, owed = 1,
	}
end

local function DemoZone()
	return { zone = "elwynn", zname = "Elwynn Forest", zsub = "The Defias Uprising", diff = 1, len = 960, bt = 5,
		class = "mage", cname = "Mage", race = "Human", rname = "Human", hero = UnitName("player") or "Hero",
		mods = "100 120 100 100" }
end

local function DemoSchedule()
	return {
		{ index = 1, at = 180, name = "Hogger", final = 0, state = "dead" },
		{ index = 2, at = 360, name = "Mother Fang", final = 0, state = "up" },
		{ index = 3, at = 540, name = "Gath'Ilzogg", final = 0, state = "up" },
		{ index = 4, at = 720, name = "Morgan the Collector", final = 0, state = "due" },
		{ index = 5, at = 960, name = "Edwin VanCleef", final = 1, state = "due" },
	}
end

local function DemoDebuffs(id)
	local t = DT()
	if id == 101 then
		return {
			{ spell = 1, name = "Frostbolt", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02", stacks = 1, duration = 8, remaining = 8 - math.mod(t, 8) },
			{ spell = 2, name = "Ignite", icon = "Interface\\Icons\\Spell_Fire_Immolation", stacks = 3, duration = 4, remaining = 4 - math.mod(t, 4), dispelType = "Magic" },
			{ spell = 3, name = "Shadow Word: Pain", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", stacks = 1, duration = 18, remaining = 18 - math.mod(t, 18), dispelType = "Magic" },
		}
	end
	return {
		{ spell = 4, name = "Curse of Tongues", icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges", stacks = 1, permanent = true, dispelType = "Curse" },
	}
end

local function DemoBosses()
	local t = DT()
	local a = 0.5 + 0.45 * math.cos(t * 0.21)
	local b = 0.22 + 0.2 * math.cos(t * 0.13)
	return {
		{ id = 101, name = "Mother Fang", hp = math.floor(64000 * a), hpm = 64000, final = false, enraged = a < 0.3, debuffs = DemoDebuffs(101) },
		{ id = 102, name = "Gath'Ilzogg", hp = math.floor(81000 * b), hpm = 81000, final = false, enraged = b < 0.3, debuffs = DemoDebuffs(102) },
	}
end

local function DemoGuardians()
	local t = DT()
	return {
		{ id = 90, name = "Kobold Geomancer", hp = math.floor(9000 * (0.6 + 0.3 * math.sin(t * 0.4))), hpm = 9000, awake = true, debuffs = {} },
		{ id = 91, name = "Murloc Oracle", hp = 7000, hpm = 7000, awake = false, debuffs = {} },
	}
end

local function DemoLairs()
	local t = DT()
	return {
		{ index = 1, state = "awake", name = "Kobold Geomancer", id = 90, left = -1 },
		{ index = 2, state = "asleep", name = "Murloc Oracle", id = 91, left = -1 },
		{ index = 3, state = "empty", name = "Defias Pillager", id = 0, left = 75 - math.mod(t, 75) },
		{ index = 4, state = "empty", name = "Gnoll Brute", id = 0, left = 0 },
	}
end

local function DemoSpells()
	local t = DT()
	local out = {}
	local cds = { 2.5, 6, 4, 14, 9, 22, 120 }
	for i = 1, 7 do
		local max = cds[i]
		out[i] = { key = "demo" .. i, spell = 0, rank = math.mod(i * 3, 5) + 1, cd = max - math.mod(t + i * 1.7, max), cdmax = max,
			icon = "Interface\\Icons\\" .. DEMO_SPELLS[i] }
	end
	return out
end

local function DemoMeter(tab)
	local rows
	if tab == "heal" then
		rows = { { "Regeneration", 9200 }, { "Leech", 6100 }, { "Healing on kill", 3300 } }
	elseif tab == "boss" then
		rows = { { "Frostbolt", 41000 }, { "Blizzard", 30200 }, { "Arcane Missiles", 18800, 1 } }
	elseif tab == "taken" then
		rows = { { "boss melee", 7200 }, { "mob melee", 5400 }, { "area", 3300 }, { "boss spell", 2550 } }
	else
		rows = { { "Frostbolt", 142000 }, { "Blizzard", 98000 }, { "Arcane Explosion", 61500 }, { "Fireball", 44100 },
			{ "Frost Nova", 30500 }, { "Ignite", 21000, 1 }, { "Arcane Missiles", 15200 }, { "Stoneform", 1300 } }
	end
	local total = 0
	for i = 1, table.getn(rows) do
		total = total + rows[i][2]
	end
	local secs = math.max(1, DT())
	local lines = {}
	for i = 1, table.getn(rows) do
		local r = rows[i]
		lines[i] = { name = r[1], dmg = r[2], dps = r[2] / secs, share = r[2] / total, proc = r[3] or 0 }
	end
	return lines, total, total / secs
end

------------------------------------------------------------------------
-- Accessors
------------------------------------------------------------------------

function D.Phase()
	if A.Demo() then
		return "playing"
	end
	return AZS_GetPhase and AZS_GetPhase()
end

-- In a run: any phase but none/ready.
function D.InRun()
	local p = D.Phase()
	return p ~= nil and p ~= "ready"
end

function D.Time()
	if A.Demo() then
		return DT()
	end
	return AZS_GetRunTime and AZS_GetRunTime()
end

function D.Run()
	if A.Demo() then
		return DemoRun()
	end
	return List(AZS_RUN)
end

function D.Zone()
	if A.Demo() then
		return DemoZone()
	end
	return List(AZS_ZONE)
end

function D.Schedule()
	if A.Demo() then
		return DemoSchedule()
	end
	return List(AZS_SCHEDULE)
end

-- The zone's length; after a /reload AZS_ZONE can lack it, then the last boss's time.
function D.RunLength()
	local len = N(D.Zone().len)
	local s = D.Schedule()
	for i = 1, table.getn(s) do
		local at = N(s[i].at)
		if at > len then
			len = at
		end
	end
	if len <= 0 then
		len = 960
	end
	return len
end

function D.Upcoming()
	if A.Demo() then
		local t = DT()
		return { { index = 4, name = "Morgan the Collector", at = 720, left = 720 - t, final = false },
			{ index = 5, name = "Edwin VanCleef", at = 960, left = 960 - t, final = true } }
	end
	return AZS_GetUpcomingBosses and AZS_GetUpcomingBosses() or EMPTY
end

function D.Bosses()
	if A.Demo() then
		return DemoBosses()
	end
	return AZS_GetBosses and AZS_GetBosses() or EMPTY
end

function D.Guardians()
	if A.Demo() then
		return DemoGuardians()
	end
	return AZS_GetGuardians and AZS_GetGuardians() or EMPTY
end

function D.Debuffs(id)
	if A.Demo() then
		return DemoDebuffs(id)
	end
	return AZS_GetDebuffs and AZS_GetDebuffs(id) or EMPTY
end

function D.Lairs()
	if A.Demo() then
		return DemoLairs()
	end
	return AZS_GetLairs and AZS_GetLairs() or List(AZS_LAIRS)
end

function D.Target()
	if A.Demo() and not UnitExists("target") then
		local t = DT()
		return { kind = "guardian", id = 90, name = "Kobold Geomancer", hp = math.floor(9000 * (0.6 + 0.3 * math.sin(t * 0.4))), hpm = 9000, state = 1, elite = 1, demo = true }
	end
	return List(AZS_TARGET)
end

function D.Timers()
	if A.Demo() then
		local t = DT()
		return {
			{ name = "Second Life", icon = "Interface\\Icons\\Spell_Holy_SealOfSalvation", kind = "cooldown", duration = 90, remaining = 90 - math.mod(t, 90) },
			{ name = "Arcane Echo", icon = "Interface\\Icons\\Spell_Nature_Lightning", kind = "cooldown", duration = 12, remaining = math.max(0, 6 - math.mod(t, 12)) },
		}
	end
	return AZS_GetTimers and AZS_GetTimers() or EMPTY
end

function D.Summons()
	if A.Demo() then
		return { { key = "water_elemental", name = "Water Elemental", icon = "Interface\\Icons\\Spell_Shadow_SealOfKings", count = 1, permanent = 0, temporary = 1, remaining = 30 - math.mod(DT(), 30) } }
	end
	if AZS_GetSummonGroups then
		return (AZS_GetSummonGroups())
	end
	return EMPTY
end

-- Spells with their action slot (1-6, the racial on 12) and the wait left now.
-- AZS_SPELLS' `cd` is the wait when the line came; the run clock (which stops while you
-- choose a card or pause) counts it down from there.
local spellsStamp, spellsClock
local hook = CreateFrame("Frame")
hook:RegisterEvent("CHAT_MSG_ADDON")
hook:SetScript("OnEvent", function()
	if arg1 == "AZSSPELLS" then
		spellsStamp = AZS_SPELLS_UPDATED
		spellsClock = AZS_GetRunTime and AZS_GetRunTime()
	end
end)

function D.Spells()
	if A.Demo() then
		local list = DemoSpells()
		for i = 1, table.getn(list) do
			list[i].slot = i == 7 and 12 or i
			list[i].left = list[i].cd
		end
		return list
	end
	local raw = List(AZS_SPELLS)
	local n = table.getn(raw)
	local racial = HasAction and HasAction(12)
	local now = AZS_GetRunTime and AZS_GetRunTime()
	local elapsed = 0
	if spellsStamp == AZS_SPELLS_UPDATED and spellsClock and now then
		elapsed = math.max(0, now - spellsClock)
	elseif AZS_SPELLS_UPDATED then
		elapsed = math.max(0, GetTime() - AZS_SPELLS_UPDATED)
	end
	local out = {}
	for i = 1, n do
		local s = raw[i]
		local slot = i
		if racial and i == n then
			slot = 12
		end
		out[i] = { key = s.key, spell = N(s.spell), rank = N(s.rank), cdmax = N(s.cdmax),
			left = math.max(0, N(s.cd) - elapsed), slot = slot,
			icon = GetActionTexture and GetActionTexture(slot) }
	end
	return out
end

-- Meter tabs: dmg, heal, boss, taken. Returns lines { name, dmg, dps, share, proc }, total, rate.
function D.Meter(tab)
	if A.Demo() then
		return DemoMeter(tab)
	end
	if tab == "heal" then
		if AZS_GetHealing then
			return AZS_GetHealing()
		end
	elseif tab == "boss" then
		if AZS_GetBossMeter then
			return AZS_GetBossMeter()
		end
	elseif tab == "taken" then
		local raw = List(AZS_TAKEN)
		local total = 0
		for i = 1, table.getn(raw) do
			total = total + N(raw[i].dmg)
		end
		local secs = math.max(1, D.Time() or 1)
		local lines = {}
		for i = 1, table.getn(raw) do
			local d = N(raw[i].dmg)
			lines[i] = { name = raw[i].source, dmg = d, dps = d / secs, share = total > 0 and d / total or 0, proc = 0 }
		end
		return lines, total, total / secs
	elseif AZS_GetMeter then
		return AZS_GetMeter()
	end
	return EMPTY, 0, 0
end

-- The party meter: a line a hero { name, class, dmg, dps, share, top, topdps }; empty alone.
function D.PartyMeter()
	if A.Demo() then
		local t = math.max(1, DT())
		return { { name = "Jaina", class = "mage", dmg = 412 * t, dps = 412, share = 0.58, top = "Frostbolt", topdps = 230 },
			{ name = UnitName("player") or "You", class = "shaman", dmg = 298 * t, dps = 298, share = 0.42, top = "Chain Lightning", topdps = 180 } }
	end
	if AZS_GetPartyMeter then
		return (AZS_GetPartyMeter()) or EMPTY
	end
	return EMPTY
end

function D.Stats()
	return List(AZS_STATS)
end
