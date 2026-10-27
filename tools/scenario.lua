-- Drives AetherHUD through a run in the mock client and checks what it shows.
-- CHECK(name, ok, detail) records results; the harness prints them.

RESULTS = {}
local function CHECK(name, ok, detail)
	table.insert(RESULTS, { name = name, ok = ok and true or false, detail = detail and tostring(detail) or "" })
end

local function text(fs)
	return fs and fs.__text or nil
end

-- every descendant of `frame` (frames and regions) for which pred(o) is true
local function find(frame, pred, out)
	out = out or {}
	for _, c in ipairs(frame.__children or {}) do
		if pred(c) then
			table.insert(out, c)
		end
		find(c, pred, out)
	end
	return out
end

local function shownTexts(frame)
	local out = {}
	for _, fs in ipairs(find(frame, function(o) return o.__kind == "FontString" end)) do
		if fs:IsVisible() and fs.__text and fs.__text ~= "" then
			table.insert(out, fs.__text)
		end
	end
	return out
end

local function hasText(frame, needle)
	for _, s in ipairs(shownTexts(frame)) do
		if string.find(s, needle, 1, true) then
			return true
		end
	end
	return false
end

local function errorsSoFar()
	return table.getn(MOCK.errors)
end

------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------

MOCK.Fire("VARIABLES_LOADED")
MOCK.Fire("PLAYER_ENTERING_WORLD")
MOCK.Run(0.6)
CHECK("boots", AetherHUD.ready, "ready flag")
local loaded = false
for _, m in ipairs(MOCK.chat) do
	if string.find(m, "loaded", 1, true) then
		loaded = true
	end
end
CHECK("prints its load line", loaded)
CHECK("hides the game's clock", MOCK.cvars.hudClock == "0", MOCK.cvars.hudClock)
CHECK("hides the game's boss bars", MOCK.cvars.hudBosses == "0")
CHECK("hides the game's tally", MOCK.cvars.hudTally == "0")
CHECK("hides the game's meter", MOCK.cvars.hudMeter == "0")
CHECK("hides the game's banners", MOCK.cvars.hudBanners == "0")
CHECK("leaves the game's build row", MOCK.cvars.hudBuild == "1")
CHECK("takes over the game's loot notice", MOCK.cvars.hudLoot == "0")
CHECK("takes over the game's level-up button", MOCK.cvars.hudLevels == "0")
CHECK("takes over the game's revive bar", MOCK.cvars.hudRevive == "0")
CHECK("leaves the game's minimap flag", MOCK.cvars.hudFlag == "1")
CHECK("silences the stock player frame", not PlayerFrame:IsShown())
CHECK("fades the stock main bar", MainMenuBar.__alpha == 0)

MOCK.Run(1)
CHECK("chronometer hidden out of a run", not AetherHUDChrono:IsShown())
CHECK("skill bar hidden out of a run", not AetherHUDSkills:IsShown())

------------------------------------------------------------------------
-- A run
------------------------------------------------------------------------

MOCK.target = { name = "Hogger II", hp = 99, hpm = 100, level = -1, classification = "worldboss" }
MOCK.buffs = {
	{ texture = "Interface\\Icons\\Spell_Holy_MagicalSentry", left = 300, apps = 1 },
	{ texture = "Interface\\Icons\\Spell_Nature_Lightning", left = 0, apps = 2 },
	{ texture = "Interface\\Icons\\Spell_Shadow_Curse", left = 5, apps = 1, harmful = true, dispel = "Curse" },
}
MOCK.Addon("AZSZONE", "zone=elwynn;zname=Elwynn Forest;zsub=The Defias Uprising;diff=1;len=960;bt=5;class=mage;cname=Mage;race=Human;rname=Human;hero=Utther;gender=0;map=12;mods=100 120 100 100")
local RUN = "t=250.5;ph=playing;lvl=9;xp=300;xpn=1000;hp=1500;hpm=2400;sh=200;gold=340;kills=812;en=95;el=2;bu=1;gu=2;ga=1;lairs=3;bs=2;bt=5;nb=8;nbn=Mother Fang;fin=960;left=709;endl=0;won=0;lives=2;rr=3;rrc=150;chest=240;dealt=50000;taken=3000;ge=900;bk=1;gk=0;ek=4;ck=2;owed=1"
MOCK.Addon("AZSRUN", RUN)
MOCK.Addon("AZSBOSSES", "1,180,Hogger,0,dead;2,258,Mother Fang,0,due;3,540,Gath'Ilzogg,0,due;4,720,Morgan,0,due;5,960,Edwin VanCleef,1,due")
MOCK.Addon("AZSUNITS", "boss,812,Hogger II,52000,52500,1;guardian,90,Kobold Geomancer,300,900,1;guardian,91,Murloc Oracle,900,900,0;elite,95,Defias Thug,100,400,0")
MOCK.Addon("AZSDEBUFFS", "812,116,1,8,256.0,0,Magic,Interface\\Icons\\Spell_Frost_FrostBolt02,Frostbolt;812,172,3,-1,-1,1,,Interface\\Icons\\Spell_Shadow_AbominationExplosion,Corruption")
MOCK.Addon("AZSTGT", "kind=boss;id=812;name=Hogger II;hp=52000;hpm=52500;state=1;elite=1")
MOCK.Fire("PLAYER_TARGET_CHANGED")
MOCK.Addon("AZSSPELLS", "frostbolt,116,3,1.5,2.5;blizzard,10,2,0,8;arcane_explosion,1449,1,0.4,1.2;stoneform,20594,1,30,120")
MOCK.actions = { [1] = true, [2] = true, [3] = true, [12] = true }
MOCK.Addon("AZSBUFFS", "1459,300;12042,8")
MOCK.Addon("AZSMETER", "Frostbolt,30000,120,0.6,0;Blizzard,15000,60,0.3,0;Ignite,5000,20,0.1,1")
MOCK.Addon("AZSHEAL", "Regeneration,800,3.2,0.7,0;Leech,342,1.4,0.3,0")
MOCK.Addon("AZSBOSSDMG", "")
MOCK.Addon("AZSLAIRS", "1,awake,Kobold Geomancer,90,-1,1,2,3,0.4,0.5,1;2,asleep,Murloc Oracle,91,-1,1,2,3,0.6,0.5,0;3,empty,Gnoll Brute,0,45,1,2,3,0.2,0.8,0")
MOCK.Addon("AZSTAKEN", "boss melee,1200;mob melee,800;area,300")
MOCK.Addon("AZS", "hp=2400;dmg=1.35;cd=0.85;crit=0.12;cm=1.5;arm=0.2;reg=3.5;area=1.2;cnt=1;echo=0.05;spd=1.1;pick=6;xp=1;luck=0.1;gold=1;heal=4;lch=0.02;thn=0;liv=2;bp=0;dots=1;doth=0;big=0;exe=0;cc=0;dotd=0;shd=0;auto=0;pet=0")
MOCK.Addon("AZSTIMERS", "Second Life,Interface\\Icons\\Spell_Holy_SealOfSalvation,cooldown,300,90")
MOCK.Addon("AZSPETS", "5001,510,water_elemental,pet,280,45,Interface\\Icons\\Spell_Shadow_SealOfKings,Water Elemental")
MOCK.Addon("AZSBANNER", "id=1;kind=boss;boss=1;name=Hogger II;text=Hogger II approaches!")
MOCK.Run(1.0)

CHECK("chronometer shows in a run", AetherHUDChrono:IsVisible())
CHECK("clock runs from the server's time", hasText(AetherHUDChrono, "4:1"), table.concat(shownTexts(AetherHUDChrono), " / "))
CHECK("zone in the chronometer", hasText(AetherHUDChrono, "ELWYNN FOREST"))
CHECK("next boss and countdown", hasText(AetherHUDChrono, "Mother Fang"), table.concat(shownTexts(AetherHUDChrono), " / "))
CHECK("boss bar: name", hasText(AetherHUDBosses, "Hogger II"), table.concat(shownTexts(AetherHUDBosses), " / "))
CHECK("boss bar: enraged tag", hasText(AetherHUDBosses, "ENRAGED"))
CHECK("boss bar: awake guardian", hasText(AetherHUDBosses, "Kobold Geomancer"))
CHECK("boss bar: sleeping guardian left out", not hasText(AetherHUDBosses, "Murloc Oracle"))
CHECK("boss bar: health", hasText(AetherHUDBosses, "52.0K / 52.5K"))
CHECK("boss bar: debuff stacks", hasText(AetherHUDBosses, "3"))
CHECK("target: AZS health, not percent", hasText(AetherHUDTarget, "52.0K / 52.5K"), table.concat(shownTexts(AetherHUDTarget), " / "))
CHECK("target: kind tag", hasText(AetherHUDTarget, "BOSS"))
CHECK("hero: health and shield", hasText(AetherHUDHero, "1,500 / 2,400") and hasText(AetherHUDHero, "+200"), table.concat(shownTexts(AetherHUDHero), " / "))
CHECK("hero: level gem", hasText(AetherHUDHero, "9"))
CHECK("hero: class and race", hasText(AetherHUDHero, "Mage") and hasText(AetherHUDHero, "Human"))
CHECK("hero: buff with stacks", hasText(AetherHUDHero, "2"))
CHECK("meter: top line", hasText(AetherHUDMeter, "Frostbolt"), table.concat(shownTexts(AetherHUDMeter), " / "))
CHECK("tally: kills", hasText(AetherHUDTally, "812"), table.concat(shownTexts(AetherHUDTally), " / "))
CHECK("tally: next cache", hasText(AetherHUDTally, "240"))
CHECK("lairs: held count", hasText(AetherHUDLairs, "2 / 3 held"), table.concat(shownTexts(AetherHUDLairs), " / "))
CHECK("lairs: refill countdown", hasText(AetherHUDLairs, "0:4"))
CHECK("xp: level", hasText(AetherHUDXP, "LV 9"), table.concat(shownTexts(AetherHUDXP), " / "))
CHECK("xp: owed choices gem", hasText(AetherHUDXP, "1"))
CHECK("banner shows the game's text", AetherHUDBanner:IsVisible() and hasText(AetherHUDBanner, "Hogger II approaches!"), table.concat(shownTexts(AetherHUDBanner), " / "))
CHECK("skill bar shows", AetherHUDSkills:IsVisible())
CHECK("skill bar: racial on cooldown", hasText(AetherHUDSkills, "29"), table.concat(shownTexts(AetherHUDSkills), " / "))
CHECK("skill bar: talent clock above the bar", hasText(AetherHUDSkills, "49"))

-- the run's clock stops while choosing: the spell countdown must stop with it
-- (the server's clock has reached 251.5 by now)
MOCK.Addon("AZSRUN", (string.gsub(string.gsub(RUN, "ph=playing", "ph=choosing"), "t=250.5", "t=251.5")))
MOCK.Run(0.15) -- one refresh after the line
local before = table.concat(shownTexts(AetherHUDSkills), "|")
MOCK.Run(2)
local after = table.concat(shownTexts(AetherHUDSkills), "|")
CHECK("cooldowns pause while choosing", before == after, before .. "  ->  " .. after)
CHECK("phase tag while choosing", hasText(AetherHUDChrono, "CHOOSING"))

for _, ph in ipairs({ "paused", "dead", "victory", "playing" }) do
	MOCK.Addon("AZSRUN", (string.gsub(RUN, "ph=playing", "ph=" .. ph)))
	MOCK.Run(0.5)
end
CHECK("phases cycle without errors", errorsSoFar() == 0, MOCK.errors[1])

-- low health: red screen edges
MOCK.Addon("AZSRUN", (string.gsub(RUN, "hp=1500", "hp=300")))
MOCK.Run(0.5)
local vig = find(AetherHUDVignette, function(o) return o.__kind == "Texture" end)[1]
CHECK("low-health vignette", vig and vig:IsVisible())
MOCK.Addon("AZSRUN", RUN)
MOCK.Run(0.3)
CHECK("vignette clears", vig and not vig:IsVisible())

-- endless mode: no schedule left, the next boss comes from AZS_RUN
MOCK.Addon("AZSBOSSES", "1,180,Hogger,0,dead;2,258,Mother Fang,0,dead;3,540,Gath'Ilzogg,0,dead;4,720,Morgan,0,dead;5,960,Edwin VanCleef,1,dead")
MOCK.Addon("AZSRUN", "t=1000;ph=playing;lvl=30;xp=1;xpn=9000;hp=2000;hpm=2400;sh=0;gold=10;kills=5000;en=200;el=5;bu=0;gu=0;ga=0;lairs=0;bs=5;bt=5;nb=45;nbn=;fin=960;left=-1;endl=1;won=1;lives=0;rr=0;rrc=0;chest=500;owed=0")
MOCK.Addon("AZSUNITS", "")
MOCK.Addon("AZSLAIRS", "")
MOCK.Run(0.5)
CHECK("endless: label", hasText(AetherHUDChrono, "ENDLESS"), table.concat(shownTexts(AetherHUDChrono), " / "))
CHECK("endless: next boss from the run line", hasText(AetherHUDChrono, "0:4"))
CHECK("no bosses: bars hidden", not hasText(AetherHUDBosses, "Hogger II"))
CHECK("no lairs: panel hidden", not AetherHUDLairs:IsVisible())

-- boss warning: the last ten seconds before a boss, over the hero
MOCK.sounds = {}
MOCK.Addon("AZSBOSSES", "1,180,Hogger,0,dead;2,1006,Mother Fang,0,due;3,1100,Edwin VanCleef,1,due")
MOCK.Addon("AZSRUN", "t=1000.5;ph=playing;lvl=30;hp=2000;hpm=2400;gold=10;kills=5000;bs=1;bt=3;nb=5.5;nbn=Mother Fang;fin=1100;left=99;endl=0;won=0;lives=1")
MOCK.Addon("AZSUNITS", "boss,813,Rhahk'Zor,52000,52500,0")
MOCK.Run(0.3)
local function warnSounds()
	local n = 0
	for _, v in ipairs(MOCK.sounds) do
		if v == "RaidWarning" then
			n = n + 1
		end
	end
	return n
end
CHECK("boss warning: the last seconds count down", AetherHUDBossWarning:IsVisible() and hasText(AetherHUDBossWarning, "Mother Fang")
	and hasText(AetherHUDBossWarning, "6") and hasText(AetherHUDBossWarning, "B O S S"), table.concat(shownTexts(AetherHUDBossWarning), " / "))
CHECK("boss warning: one sound as it starts", warnSounds() == 1, warnSounds())
MOCK.Run(1.0)
CHECK("boss warning: counts on, no more sounds", hasText(AetherHUDBossWarning, "5") and warnSounds() == 1)
MOCK.Run(5.5)
CHECK("boss warning: gone once the boss is due", not AetherHUDBossWarning:IsVisible())
MOCK.Addon("AZSUNITS", "boss,813,Rhahk'Zor,52000,52500,1")
MOCK.Run(0.3)
CHECK("boss warning: an enrage flashes", AetherHUDBossWarning:IsVisible() and hasText(AetherHUDBossWarning, "Rhahk'Zor")
	and hasText(AetherHUDBossWarning, "E N R A G E D"), table.concat(shownTexts(AetherHUDBossWarning), " / "))
MOCK.Run(3.5)
CHECK("boss warning: and fades", not AetherHUDBossWarning:IsVisible())
MOCK.Run(0.5)
CHECK("boss warning: once per enrage", not AetherHUDBossWarning:IsVisible())
MOCK.Addon("AZSBOSSES", "1,180,Hogger,0,dead;2,1006,Mother Fang,0,dead;3,1016,Edwin VanCleef,1,due")
MOCK.Run(0.3)
local warnName
for _, fs in ipairs(find(AetherHUDBossWarning, function(o) return o.__kind == "FontString" and o.__text == "Edwin VanCleef" end)) do
	warnName = fs
end
CHECK("boss warning: the final boss in gold", hasText(AetherHUDBossWarning, "F I N A L") and warnName
	and warnName.__tcolor[1] == AetherHUD.C.gold[1], table.concat(shownTexts(AetherHUDBossWarning), " / "))
MOCK.Addon("AZSRUN", "t=1000;ph=choosing;nb=10;nbn=x")
MOCK.Run(0.3)
CHECK("boss warning: not while choosing a card", not AetherHUDBossWarning:IsVisible())
MOCK.Addon("AZSBOSSES", "1,180,Hogger,0,dead;2,258,Mother Fang,0,due;3,540,Gath'Ilzogg,0,due;4,720,Morgan,0,due;5,960,Edwin VanCleef,1,due")

-- target gone
MOCK.target = nil
MOCK.Addon("AZSTGT", "kind=none")
MOCK.Fire("PLAYER_TARGET_CHANGED")
MOCK.Run(0.3)
CHECK("target frame hides", not AetherHUDTarget:IsVisible())

-- a friendly target without AZS data
MOCK.target = { name = "Guide", hp = 100, hpm = 100, friend = true, level = 60 }
MOCK.Addon("AZSTGT", "kind=other;name=Guide;hp=100;hpm=100")
MOCK.Fire("PLAYER_TARGET_CHANGED")
MOCK.Run(0.3)
CHECK("friendly target", AetherHUDTarget:IsVisible() and hasText(AetherHUDTarget, "Guide"))

------------------------------------------------------------------------
-- Interaction
------------------------------------------------------------------------

MOCK.Addon("AZSRUN", RUN)
MOCK.Addon("AZSUNITS", "boss,812,Hogger II,52000,52500,1")
MOCK.Run(0.3)
local errs = errorsSoFar()
local hovered = 0
local function hoverAll(root)
	for _, o in ipairs(find(root, function(o) return o.__scripts and o.__scripts.OnEnter end)) do
		MOCK.Script(o, "OnEnter")
		MOCK.Script(o, "OnLeave")
		hovered = hovered + 1
	end
end
hoverAll(AetherHUDRoot)
CHECK("every tooltip opens (" .. hovered .. " hovered)", errorsSoFar() == errs, MOCK.errors[errs + 1])

local pill = find(AetherHUDBosses, function(o) return o.__scripts and o.__scripts.OnMouseUp end)[1]
MOCK.Script(pill, "OnMouseUp", "LeftButton")
local buffButton = find(AetherHUDHero, function(o) return o.__kind == "Button" and o.buffId == 0 end)[1]
if buffButton then
	buffButton:Click()
end
CHECK("right-click cancels a buff", MOCK.cancelled == 0, tostring(MOCK.cancelled))
CHECK("stock buff frame silenced", not BuffFrame:IsShown())
CHECK("click a boss bar targets it", MOCK.targeted == "Hogger II", MOCK.targeted)

for _, b in ipairs(find(AetherHUDMeter, function(o) return o.__kind == "Button" end)) do
	b:Click()
	MOCK.Run(0.3)
end
CHECK("meter tabs", errorsSoFar() == errs, MOCK.errors[errs + 1])
MOCK.Script(AetherHUDMeter, "OnMouseWheel", -1)

-- steady state: how much does the HUD redraw when nothing changes?
MOCK.Run(0.5)
local c0 = { SetText = MOCK.calls.SetText, SetWidth = MOCK.calls.SetWidth, SetTexture = MOCK.calls.SetTexture }
MOCK.Run(5)
PERF = {
	SetText = (MOCK.calls.SetText - c0.SetText) / 5,
	SetWidth = (MOCK.calls.SetWidth - c0.SetWidth) / 5,
	SetTexture = (MOCK.calls.SetTexture - c0.SetTexture) / 5,
}

------------------------------------------------------------------------
-- Slash commands, movers, demo, options
------------------------------------------------------------------------

errs = errorsSoFar()
MOCK.Slash("/aether", "unlock")
MOCK.Run(1)
local overlays = find(AetherHUDRoot, function(o) return o.__kind == "Button" and o.__strata == "DIALOG" end)
CHECK("unlock shows a mover per frame (" .. table.getn(overlays) .. ")", table.getn(overlays) == 22) -- 2.1 inspect; 2.2 downed allies; 2.3 boss warning, run record
for _, o in ipairs(overlays) do
	MOCK.Script(o, "OnDragStart")
	MOCK.Script(o, "OnDragStop")
	MOCK.Script(o, "OnMouseWheel", 1)
	MOCK.Script(o, "OnEnter")
end
CHECK("positions saved", AetherHUDDB.pos.chrono ~= nil)
CHECK("sizes saved", AetherHUDDB.fscale.chrono == 1.05, AetherHUDDB.fscale.chrono)
MOCK.Script(overlays[1], "OnClick", "RightButton")
CHECK("right-click resets one frame", true)
MOCK.Run(1)
MOCK.Slash("/aether", "lock")
MOCK.Slash("/aether", "demo")
MOCK.Addon("AZSRUN", "ph=ready")
MOCK.Run(3)
CHECK("demo fills frames outside a run", AetherHUDChrono:IsVisible() and hasText(AetherHUDBosses, "Mother Fang"), table.concat(shownTexts(AetherHUDBosses), " / "))
MOCK.Slash("/aether", "demo")
MOCK.Run(0.5)
CHECK("demo off hides them again", not AetherHUDChrono:IsVisible())
MOCK.Slash("/aether", "scale 0.9")
CHECK("scale command", AetherHUDDB.scale == 0.9)
MOCK.Slash("/aether", "reset")
CHECK("reset command", next(AetherHUDDB.pos) == nil and AetherHUDDB.scale == 1)
MOCK.Slash("/aether", "help")
MOCK.Slash("/ahud", "")
CHECK("options window opens", AetherHUDOptions and AetherHUDOptions:IsShown())
local before = {}
for k, v in pairs(AetherHUDDB.modules) do
	before[k] = v
end
for _, b in ipairs(find(AetherHUDOptions, function(o) return o.__kind == "Button" end)) do
	b:Click()
	b:Click()
end
local same = true
for k, v in pairs(before) do
	if AetherHUDDB.modules[k] ~= v then
		same = false
	end
end
CHECK("every options button clicks (twice)", errorsSoFar() == errs, MOCK.errors[errs + 1])
CHECK("toggles flip back", same)

-- switching the meter off gives the game's meter back right away
for _, b in ipairs(find(AetherHUDOptions, function(o) return o.__kind == "Button" end)) do
	local label = find(b, function(o) return o.__kind == "FontString" end)[1]
	if label and label.__text == "Combat meter" then
		b:Click()
	end
end
CHECK("meter off: game's meter back", MOCK.cvars.hudMeter == "1", MOCK.cvars.hudMeter)

------------------------------------------------------------------------
-- Enemy plates and floating numbers
------------------------------------------------------------------------

errs = errorsSoFar()
CHECK("plates: the client's nameplates switched on", NAMEPLATES_ON == 1)
CHECK("numbers: the client's own damage numbers off", MOCK.cvars.CombatDamage == "0" and MOCK.cvars.PetMeleeDamage == "0")
CHECK("numbers: combat log reaches the whole swarm", MOCK.cvars.CombatLogRangeCreature == "200")
CHECK("numbers: damage over time in the log", MOCK.cvars.CombatLogPeriodicSpells == "1")

MOCK.target = nil
MOCK.Addon("AZSTGT", "kind=none")
MOCK.Addon("AZSRUN", RUN)
MOCK.Addon("AZSUNITS", "boss,812,Hogger II,52000,52500,0;guardian,90,Kobold Geomancer,300,900,1;elite,95,Kobold Geomancer,400,400,0;elite,96,Defias Pillager,100,400,0")
local thugA = MOCK.SpawnPlate("Defias Thug", 100, 100, 600, 420)
local thugB = MOCK.SpawnPlate("Defias Thug", 100, 100, 820, 300)
local murloc = MOCK.SpawnPlate("Murloc", 100, 100, 700, 500)
local guard = MOCK.SpawnPlate("Kobold Geomancer", 300, 900, 500, 300)
local elite = MOCK.SpawnPlate("Kobold Geomancer", 400, 400, 520, 330)
local boss = MOCK.SpawnPlate("Hogger II", 52000, 52500, 760, 560)
MOCK.Run(0.3)

local function plateBar(p)
	return find(p, function(o) return o.__kind == "StatusBar" end)[1]
end
local function plateName(p)
	return find(p, function(o) return o.__kind == "FontString" end)[1]
end
local border = find(thugA, function(o) return o.__tex == "Interface\\Tooltips\\Nameplate-Border" end)[1]
CHECK("plates: stock border hidden", border and border.__alpha == 0)
CHECK("plates: Aion bar texture", plateBar(thugA).__sbtex == "Interface\\AddOns\\AetherHUD\\media\\bar")
CHECK("plates: name in the title font", plateName(thugA).__font[1] == "Fonts\\FRIZQT__.TTF")
CHECK("plates: full-health fodder stays hidden", thugA.__alpha == 0 and murloc.__alpha == 0)
CHECK("plates: a boss always shows", boss.__alpha == 1)
local bc = plateName(boss).__tcolor
CHECK("plates: boss name in red", bc[1] > 0.9 and bc[2] < 0.6, bc[1] .. "," .. bc[2])
local gc = plateName(guard).__tcolor
CHECK("plates: guardian told from its elites by its health", gc[3] > 0.9 and gc[1] < 0.8, gc[1] .. "," .. gc[3])
local ec = plateName(elite).__tcolor
CHECK("plates: elite in gold", ec[1] == 1 and ec[2] > 0.7 and ec[3] < 0.5)
CHECK("plates: boss bar wider", plateBar(boss).__w > plateBar(thugA).__w)
CHECK("plates: percent on special enemies", hasText(boss, "99%"))

-- thug B loses health, then the log line arrives
plateBar(thugB):SetValue(60)
MOCK.Run(0.15)
CHECK("plates: a damaged enemy shows its plate", thugB.__alpha == 1)
MOCK.Fire("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Frostbolt hits Defias Thug for 1234 Frost damage.")
MOCK.Run(0.05)
local function numberTexts()
	local out = {}
	for _, fs in ipairs(find(AetherHUDNumbers, function(o) return o.__kind == "FontString" end)) do
		if fs:IsVisible() and fs.__text then
			table.insert(out, fs)
		end
	end
	return out
end
local function numberWith(t)
	for _, fs in ipairs(numberTexts()) do
		if fs.__text == t then
			return fs
		end
	end
end
local function shownNumbers()
	local out = {}
	for _, fs in ipairs(numberTexts()) do
		table.insert(out, fs.__text)
	end
	return table.concat(out, " ")
end
local n1 = numberWith("1,234")
CHECK("numbers: a hit shows", n1 ~= nil, shownNumbers())
local pt = n1 and n1.__parent.__points[1]
local px = pt and pt[4] * n1.__parent.__scale
CHECK("numbers: rise over the enemy that was hit", px and math.abs(px - 820) < 40, px)
CHECK("numbers: frost colour", n1 and n1.__tcolor[3] > 0.9 and n1.__tcolor[1] < 0.7)

MOCK.Fire("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Frostbolt hits Defias Thug for 100 Frost damage.")
MOCK.Run(0.05)
CHECK("numbers: the same spell on the same enemy adds up", numberWith("1,334") ~= nil, shownNumbers())
MOCK.Fire("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Fireball crits Hogger II for 5000 Fire damage. (120 resisted)")
MOCK.Run(0.05)
local crit = numberWith("5,000")
CHECK("numbers: a crit bursts in gold", crit and crit.__tcolor[1] == 1 and crit.__tcolor[2] > 0.7 and crit.__parent.__scale > 1, shownNumbers())
MOCK.Fire("CHAT_MSG_COMBAT_SELF_HITS", "You hit Murloc for 20.")
MOCK.Fire("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "Defias Thug suffers 50 Shadow damage from your Corruption.")
MOCK.Fire("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "Defias Thug suffers 70 Shadow damage from Gnoll's Rend.")
MOCK.Fire("CHAT_MSG_COMBAT_PET_HITS", "Water Elemental hits Murloc for 40.")
MOCK.Fire("CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF", "You reflect 12 Nature damage to Murloc.")
MOCK.Fire("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "Defias Thug hits you for 35.")
MOCK.Fire("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "Murloc crits you for 15.")
MOCK.Fire("CHAT_MSG_SPELL_SELF_BUFF", "Your Renew heals you for 120.")
MOCK.Run(0.05)
CHECK("numbers: melee", numberWith("20") ~= nil, shownNumbers())
CHECK("numbers: your damage over time", numberWith("50") ~= nil)
CHECK("numbers: someone else's damage over time left out", numberWith("70") == nil)
CHECK("numbers: pet", numberWith("40") ~= nil)
CHECK("numbers: damage shield", numberWith("12") ~= nil)
CHECK("numbers: damage taken adds up beside the hero", numberWith("-50") ~= nil, shownNumbers())
CHECK("numbers: healing", numberWith("+120") ~= nil)
MOCK.Run(2)
CHECK("numbers: gone after their time", table.getn(numberTexts()) == 0, shownNumbers())

MOCK.target = { name = "Hogger II", hp = 99, hpm = 100, level = -1 }
MOCK.Addon("AZSTGT", "kind=boss;id=812;name=Hogger II;hp=52000;hpm=52500;state=0;elite=1")
MOCK.Run(0.2)
local marker = find(boss, function(o) return o.__tex == "Interface\\AddOns\\AetherHUD\\media\\diamond" end)[1]
CHECK("plates: your target is marked", marker and marker:IsVisible())
local otherMarker = find(thugB, function(o) return o.__tex == "Interface\\AddOns\\AetherHUD\\media\\diamond" end)[1]
CHECK("plates: only your target", otherMarker and not otherMarker:IsVisible())

-- the client re-uses a plate for another enemy
plateName(boss).__text = "Murloc"
plateBar(boss):SetMinMaxValues(0, 100)
plateBar(boss):SetValue(100)
MOCK.Run(0.2)
CHECK("plates: a re-used plate takes its new enemy's look", plateBar(boss).__w == plateBar(murloc).__w and boss.__alpha == 0)
plateBar(murloc).__sbcolor = { 0, 1, 0 } -- the client recolours by reaction
MOCK.Run(0.2)
CHECK("plates: our colour comes back after the client's", plateBar(murloc).__sbcolor[1] > 0.8)

for i = 1, 300 do
	MOCK.Fire("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Arcane Explosion hits Mob" .. math.mod(i, 60) .. " for " .. (100 + i) .. " Arcane damage.")
end
MOCK.Run(0.05)
CHECK("numbers: a swarm stays capped (" .. table.getn(numberTexts()) .. " on screen)", table.getn(numberTexts()) <= 40)

SPELLLOGTEST = "%2$s erleidet %3$d %4$s Schaden (%1$s)."
local lp = AetherHUD.CompileLog("SPELLLOGTEST")
local _, _, c1, c2, c3, c4 = string.find("Defias erleidet 77 Feuer Schaden (Feuerball).", lp.pat)
local lcaps = { c1, c2, c3, c4 }
CHECK("numbers: localized argument order", lcaps[lp.map[1]] == "Feuerball" and lcaps[lp.map[2]] == "Defias" and lcaps[lp.map[3]] == "77", lp.pat)

AetherHUD.demo = true
MOCK.Run(1)
CHECK("numbers: demo shows sample hits", table.getn(numberTexts()) > 0)
AetherHUD.demo = false
MOCK.Run(2)
CHECK("plates and numbers: no Lua errors", errorsSoFar() == errs, MOCK.errors[errs + 1])

------------------------------------------------------------------------
-- The rest of the UI
------------------------------------------------------------------------

errs = errorsSoFar()
MOCK.Addon("AZSRUN", RUN)

-- pop-ups come through AetherHUD
UIErrorsFrame:AddMessage("Not enough gold.", 1, 0.1, 0.1)
UIErrorsFrame:AddMessage("Not enough gold.", 1, 0.1, 0.1)
RaidWarningFrame:AddMessage("Watch out!", 1, 0.5, 0)
MOCK.Run(0.2)
CHECK("errors become system messages", hasText(AetherHUDNotices, "Not enough gold.") and table.getn(MOCK.stockMessages) == 0)
local repeats = 0
for _, s in ipairs(shownTexts(AetherHUDNotices)) do
	if s == "Not enough gold." then
		repeats = repeats + 1
	end
end
CHECK("a repeated message shows once", repeats == 1, repeats)
CHECK("raid warnings too", hasText(AetherHUDNotices, "Watch out!"))
MOCK.Run(5)
CHECK("system messages fade away", not hasText(AetherHUDNotices, "Not enough gold."))
ZoneTextFrame:Show()
CHECK("stock zone text stays down", not ZoneTextFrame:IsShown())
MOCK.Fire("ZONE_CHANGED_NEW_AREA")
MOCK.Run(4) -- let earlier banners pass
local sawZone = false
for i = 1, 40 do
	MOCK.Run(0.25)
	if hasText(AetherHUDBanner, "Elwynn Forest") then
		sawZone = true
		break
	end
end
CHECK("a new zone gets a banner", sawZone)

-- loot cards
MOCK.Fire("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:2000:0:0:0|h[Hogger's Collar]|h|r New in your collection!")
MOCK.Fire("CHAT_MSG_LOOT", "Bob receives loot: |cff1eff00|Hitem:3000:0:0:0|h[Bob's Boots]|h|r.")
MOCK.Fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:2589:0:0:0|h[Linen Cloth]|h|rx3.")
MOCK.Run(0.3)
CHECK("loot card: name", hasText(AetherHUDLoot, "Hogger's Collar"), table.concat(shownTexts(AetherHUDLoot), " / "))
CHECK("loot card: the game's note", hasText(AetherHUDLoot, "New in your collection!"))
CHECK("loot card: someone else's loot left out", not hasText(AetherHUDLoot, "Bob's Boots"))
CHECK("loot card: stack count", hasText(AetherHUDLoot, "Linen Cloth") and hasText(AetherHUDLoot, "3"))
local collar
for _, fs in ipairs(find(AetherHUDLoot, function(o) return o.__kind == "FontString" end)) do
	if fs.__text == "Hogger's Collar" then
		collar = fs
	end
end
CHECK("loot card: epic purple", collar and collar.__tcolor[1] > 0.6 and collar.__tcolor[3] > 0.9)
MOCK.Run(6)
CHECK("loot cards leave", not hasText(AetherHUDLoot, "Hogger's Collar"))

-- stored level-ups and party revive
MOCK.Addon("AZSRUN", RUN .. ";sl=2")
MOCK.Run(0.3)
CHECK("level-up button with the count", hasText(AetherHUDXP, "LEVEL UP  x2"), table.concat(shownTexts(AetherHUDXP), " / "))
AetherHUDXP.levelButton:Click()
CHECK("level-up button opens the stored levels", MOCK.cvars.spendLevels == "1")
MOCK.Addon("AZSRUN", RUN)
MOCK.Run(0.3)
CHECK("no stored levels: no button", not AetherHUDXP.levelButton:IsVisible())
MOCK.Addon("AZSREVIVE", "down=1;share=0.4;by=Friendo;reviving=;rshare=0")
MOCK.Run(0.3)
CHECK("revive: you are down", AetherHUDRevive:IsVisible() and hasText(AetherHUDRevive, "Friendo"))
MOCK.Addon("AZSREVIVE", "down=0;share=0;by=;reviving=Pal;rshare=0.5")
MOCK.Run(0.3)
CHECK("revive: you bring a friend back", hasText(AetherHUDRevive, "Pal"))
MOCK.Addon("AZSREVIVE", "down=0;share=0;by=;reviving=;rshare=0")
MOCK.Run(0.3)
CHECK("revive: gone when nobody is down", not AetherHUDRevive:IsVisible())

-- skins
CHECK("tooltip in glass", GameTooltip.edge ~= nil and GameTooltip.aSkinned)
GameTooltipTextLeft1:SetTextColor(0.64, 0.21, 0.93)
GameTooltip:Show()
CHECK("tooltip edge takes the item's quality", GameTooltip.edge[1].aR == 0.64)
GameTooltip:Hide()
CHECK("dialogs in glass", StaticPopup1.aSkinned and StaticPopup1Button1.aSkinned)
local header = find(GameMenuFrame, function(o) return o.__tex == "Interface\\DialogFrame\\UI-DialogBox-Header" end)[1]
CHECK("game menu: stock art gone", header and header.__alpha == 0 and GameMenuButtonLogout.aSkinned)
CHECK("right-click menus in glass", DropDownList1Backdrop.aSkinned)
MOCK.mouseover = { name = "Hogger II", classification = "worldboss" }
GameTooltip:Show()
MOCK.Fire("UPDATE_MOUSEOVER_UNIT")
local tagged = false
for _, l in ipairs(GameTooltip.__lines or {}) do
	if l == "Boss" then
		tagged = true
	end
end
CHECK("enemy tooltips say what they are", tagged)
GameTooltip:Hide()

-- chat
CHECK("chat: Roboto", ChatFrame1.__font and ChatFrame1.__font[1] == "Interface\\AddOns\\AetherHUD\\media\\Roboto.ttf")
CHECK("chat: arrow buttons gone", not ChatFrame1UpButton:IsShown())
CHECK("chat: stock tab art gone", ChatFrame1TabLeft.__alpha == 0)
CHECK("chat: glass behind", AetherHUDChatBack ~= nil and AetherHUDChatBack.edge ~= nil)
MOCK.Script(ChatFrame1, "OnMouseWheel", 1)
CHECK("chat: wheel scrolls", ChatFrame1.__scroll == 1)
SELECTED_DOCK_FRAME = ChatFrame2
MOCK.Run(0.3)
CHECK("chat: the open tab in gold", ChatFrame2TabText.__tcolor[1] == 1 and ChatFrame1TabText.__tcolor[1] < 0.9)
SELECTED_DOCK_FRAME = ChatFrame1
ChatFrameEditBox:Show()
CHECK("chat: input line lights up", ChatFrameEditBox.edge[1].aR == AetherHUD.C.aether[1])

-- minimap: the map stays the game's (the client draws your arrow and its icons with it);
-- its cluster follows our ring
MOCK.Run(0.6)
CHECK("minimap: the map stays in its cluster", Minimap.__parent == MinimapCluster)
CHECK("minimap: its layer, level and size untouched", not Minimap.__strataSet and not Minimap.__levelSet and Minimap.__w == 140)
local cp = MinimapCluster.__points[1]
CHECK("minimap: the cluster puts its map on our ring", cp and cp[1] == "TOP" and cp[2] and cp[2].__parent == AetherHUDMinimap
	and cp[4] == -9 and cp[5] == 92, cp and (tostring(cp[1]) .. " " .. tostring(cp[4]) .. "," .. tostring(cp[5])))
CHECK("minimap: stock border gone", not MinimapBorder:IsShown())
CHECK("minimap: zone, coordinates and time", hasText(AetherHUDMinimap, "Goldshire") and hasText(AetherHUDMinimap, "42, 65"))
MOCK.Script(Minimap, "OnMouseWheel", 1)
CHECK("minimap: wheel zooms", Minimap:GetZoom() == 1)
local stockZone = GetMinimapZoneText
GetMinimapZoneText = function() return "The Jasperlode Mine Depths" end
MOCK.Run(0.6)
local zfs = find(AetherHUDMinimap, function(o) return o.__kind == "FontString" and o.__text and string.find(o.__text, "Jasper", 1, true) end)[1]
CHECK("minimap: a long zone name is cut, not wrapped", zfs and string.find(zfs.__text, "...", 1, true) and zfs:GetStringWidth() <= 169 - 24 - 66,
	zfs and zfs.__text)
GetMinimapZoneText = stockZone
AetherHUD.db.fscale.minimap = 1.2
AetherHUD.Place("minimap")
MOCK.Run(0.6)
CHECK("minimap: the cluster takes our size", math.abs(MinimapCluster:GetScale() - 1.2) < 0.001, MinimapCluster:GetScale())
AetherHUD.db.fscale.minimap = nil
AetherHUD.Place("minimap")
MOCK.Run(0.6)

-- the clock's boss diamonds: shadow and gem on layers of their own (the client draws a shared
-- layer in no fixed order, so they flickered)
local shadows, gems, blackGems = 0, 0, 0
for _, o in ipairs(find(AetherHUDChrono, function(o) return o.__kind == "Texture" and o.__tex == "Interface\\AddOns\\AetherHUD\\media\\diamond" end)) do
	local black = o.__color and o.__color[1] == 0 and o.__color[2] == 0 and o.__color[3] == 0
	if o.__layer == "BORDER" and black then
		shadows = shadows + 1
	elseif o.__layer == "OVERLAY" then
		gems = gems + 1
		if black then
			blackGems = blackGems + 1
		end
	end
end
CHECK("clock: diamonds and shadows apart", shadows >= 5 and gems >= 5 and blackGems == 0, shadows .. "/" .. gems .. "/" .. blackGems)

-- an empty skill socket shows no icon (the client's missing-icon art is a red slash)
MOCK.actions[5] = nil
MOCK.Run(0.5)
local s5 = find(AetherHUDSkills, function(o) return o.__kind == "Button" and o.slot == 5 end)[1]
local icon5 = s5 and find(s5, function(o) return o.__kind == "Texture" and o.__layer == "BORDER" end)[1]
CHECK("skill bar: an empty socket shows no icon", icon5 and icon5.__alpha == 0, icon5 and icon5.__alpha)
MOCK.actions[5] = true

-- inventory
MOCK.bags[0][1] = { tex = "Interface\\Icons\\INV_Misc_Coin_01", count = 5, quality = 1, link = "|cffffffff|Hitem:1:0:0:0|h[Coins]|h|r" }
MOCK.bags[0][2] = { tex = "Interface\\Icons\\INV_Box_01", count = 1, quality = 4, link = "|cffa335ee|Hitem:2:0:0:0|h[Epic Box]|h|r" }
MOCK.bags[1][3] = { tex = "Interface\\Icons\\INV_Box_01", count = 1, locked = 1, link = "|cff1eff00|Hitem:3:0:0:0|h[Green Box]|h|r" }
ToggleBackpack()
MOCK.Run(0.2)
CHECK("B opens the cube, not the stock bags", AetherHUDBags:IsShown() and MOCK.stockBags == nil)
local sockets = {}
for _, o in ipairs(find(AetherHUDBags, function(o) return o.__kind == "Button" and o.bag ~= nil end)) do
	if o:IsShown() then
		table.insert(sockets, o)
	end
end
CHECK("cube: every slot of every bag (" .. table.getn(sockets) .. ")", table.getn(sockets) == 26)
CHECK("cube: stack count and capacity", hasText(AetherHUDBags, "5") and hasText(AetherHUDBags, "3 / 26"))
local epicRim = find(sockets[2], function(o) return o.__tex == "Interface\\AddOns\\AetherHUD\\media\\slot" end)[1]
CHECK("cube: epic rim", epicRim and epicRim.__color[1] > 0.6 and epicRim.__color[3] > 0.9)
local lockedIcon = sockets[19] and find(sockets[19], function(o) return o.__layer == "BORDER" and o.__kind == "Texture" end)[1]
CHECK("cube: locked item dimmed", lockedIcon and lockedIcon.__alpha < 0.5)
local emptyIcon = sockets[3] and find(sockets[3], function(o) return o.__layer == "BORDER" and o.__kind == "Texture" end)[1]
CHECK("cube: an empty slot shows no icon, not a missing texture", emptyIcon and emptyIcon.__alpha == 0 and emptyIcon.__tex ~= nil)
CHECK("cube: money", hasText(AetherHUDBags, "12") and hasText(AetherHUDBags, "34") and hasText(AetherHUDBags, "56"))
arg1 = "LeftButton"
MOCK.Script(sockets[2], "OnClick", "LeftButton")
CHECK("cube: left-click picks up", MOCK.picked == "0:2")
MOCK.Script(sockets[2], "OnClick", "RightButton")
CHECK("cube: right-click uses", MOCK.used == "0:2")
MOCK.shift = true
MOCK.Script(sockets[2], "OnClick", "LeftButton")
MOCK.shift = false
CHECK("cube: shift-click links (with the chat line open)", ChatFrameEditBox.__inserted and string.find(ChatFrameEditBox.__inserted, "Epic Box", 1, true))
ChatFrameEditBox:Hide()
ToggleBackpack()
CHECK("B again closes it", not AetherHUDBags:IsShown())
OpenAllBags(true)
CHECK("a merchant opens it", AetherHUDBags:IsShown())
CloseAllBags()
ToggleBag(7)
CHECK("bank bags stay stock", MOCK.stockBags == "ToggleBag7" and not AetherHUDBags:IsShown())

-- character window
MOCK.equip[1] = { tex = "Interface\\Icons\\INV_Helmet_01", link = "|cff0070dd|Hitem:10:0:0:0|h[Blue Helm]|h|r" }
MOCK.Addon("AZS", "hp=2400;dmg=1.35;cd=0.85;crit=0.12;cm=1.5;arm=0.2;reg=3.5;area=1.2;cnt=1;echo=0.05;spd=1.1;pick=6;xp=1;luck=0.1;gold=1;heal=4;lch=0.02;thn=0;liv=2;bp=0;dots=1;doth=0;big=0.1;exe=0;cc=0;dotd=0;shd=0;auto=0;pet=0;gdmg=0.05;ghp=120")
ToggleCharacter("PaperDollFrame")
MOCK.Run(0.2)
CHECK("C opens the character window", AetherHUDCharacter:IsShown() and MOCK.stockCharacter == nil)
CHECK("character: name and line", hasText(AetherHUDCharacter, "Utther") and hasText(AetherHUDCharacter, "Mage"))
CHECK("character: stats", hasText(AetherHUDCharacter, "+35%") and hasText(AetherHUDCharacter, "Crit damage"))
CHECK("character: what gear adds", hasText(AetherHUDCharacter, "+5%") and hasText(AetherHUDCharacter, "+120"))
CHECK("character: rows only when they count", hasText(AetherHUDCharacter, "Vs elites") and not hasText(AetherHUDCharacter, "Execute"))
local helm
for _, o in ipairs(find(AetherHUDCharacter, function(o) return o.__kind == "Button" and o.inv == 1 end)) do
	helm = o
end
local helmRim = helm and find(helm, function(o) return o.__tex == "Interface\\AddOns\\AetherHUD\\media\\slot" end)[1]
CHECK("character: gear rim in its quality", helmRim and helmRim.__color[3] > 0.8 and helmRim.__color[1] < 0.1)
MOCK.Script(helm, "OnClick", "LeftButton")
CHECK("character: click picks gear up", MOCK.pickedInv == 1)
ToggleCharacter("PetPaperDollFrame")
CHECK("other character tabs stay stock", MOCK.stockCharacter == "PetPaperDollFrame")
ToggleCharacter()
CHECK("C again closes it", not AetherHUDCharacter:IsShown())

-- party and pet
MOCK.party = { { name = "Friendo", hp = 50, hpm = 100, class = "Priest", token = "PRIEST" } }
MOCK.pet = { name = "Wolf", hp = 80, hpm = 100 }
MOCK.Run(0.5)
CHECK("party frame", hasText(AetherHUDParty, "Friendo") and hasText(AetherHUDParty, "50%"))
MOCK.party[1].dead = true
MOCK.Run(0.3)
CHECK("party: down", hasText(AetherHUDParty, "DOWN"))
CHECK("pet frame", AetherHUDPet:IsVisible() and hasText(AetherHUDPet, "Wolf"))
MOCK.party = nil
MOCK.pet = nil
MOCK.Run(0.3)
CHECK("no party, no frames", not hasText(AetherHUDParty, "Friendo") and not AetherHUDPet:IsVisible())

-- unit menus: the game's own, on our frames
MOCK.Script(AetherHUDHero, "OnMouseUp", "RightButton")
CHECK("hero: right-click opens the game's menu", DropDownList1:IsShown() and MOCK.menu and MOCK.menu.which == "SELF" and MOCK.menu.unit == "player",
	MOCK.menu and MOCK.menu.which)
local lp = DropDownList1.__points[1]
CHECK("menu: at the cursor", lp and lp[2] == UIParent and lp[4] == 640, lp and tostring(lp[4]))
MOCK.Script(AetherHUDHero, "OnMouseUp", "RightButton")
CHECK("menu: right-click again closes it", not DropDownList1:IsShown())
MOCK.Script(AetherHUDHero, "OnMouseUp", "LeftButton")
CHECK("hero: left-click targets you", MOCK.targetUnit == "player")

MOCK.party = { { name = "Jaina", hp = 90, hpm = 1500, level = 20, class = "Mage", token = "MAGE", race = "Human", player = true, friend = true } }
MOCK.pet = { name = "Wolf", hp = 80, hpm = 100 }
MOCK.guilds = { Jaina = "Kirin Tor" }
MOCK.inspected = { Jaina = {
	[1] = { tex = "Interface\\Icons\\INV_Helmet_02", link = "|cffa335ee|Hitem:20:0:0:0|h[Crown of Frost]|h|r" },
	[16] = { tex = "Interface\\Icons\\INV_Staff_01", link = "|cff0070dd|Hitem:21:0:0:0|h[Staff of Jordan]|h|r" },
} }
MOCK.Run(0.5)
MOCK.Script(AetherHUDParty1, "OnMouseUp", "RightButton")
CHECK("party: right-click, the party menu", MOCK.menu and MOCK.menu.which == "PARTY" and MOCK.menu.unit == "party1", MOCK.menu and MOCK.menu.which)
MOCK.Script(AetherHUDPet, "OnMouseUp", "RightButton")
CHECK("pet: right-click, the pet menu (another frame's opens anew)", DropDownList1:IsShown() and MOCK.menu.which == "PET")
CloseDropDownMenus()

-- inspecting: the menu's Inspect calls InspectUnit
InspectUnit("party1")
MOCK.Run(0.6)
CHECK("inspect: our window, not the stock one", AetherHUDInspect:IsShown() and MOCK.stockInspect == nil)
CHECK("inspect: asks the server for their gear", MOCK.notified == "Jaina")
CHECK("inspect: name, guild and class", hasText(AetherHUDInspect, "Jaina") and hasText(AetherHUDInspect, "Kirin Tor")
	and hasText(AetherHUDInspect, "Mage"), table.concat(shownTexts(AetherHUDInspect), " / "))
CHECK("inspect: their gear by name", hasText(AetherHUDInspect, "Crown of Frost") and hasText(AetherHUDInspect, "Staff of Jordan"))
local theirHelm
for _, o in ipairs(find(AetherHUDInspect, function(o) return o.__kind == "Button" and o.inv == 1 and o.slotName == "HeadSlot" end)) do
	if find(o, function(r) return r.__tex == "Interface\\AddOns\\AetherHUD\\media\\slot" end)[1] then
		theirHelm = o
	end
end
local theirRim = theirHelm and find(theirHelm, function(o) return o.__tex == "Interface\\AddOns\\AetherHUD\\media\\slot" end)[1]
CHECK("inspect: their gear rimmed in its quality", theirRim and theirRim.__color[1] > 0.6 and theirRim.__color[3] > 0.9)
CHECK("inspect: health and gear count", hasText(AetherHUDInspect, "1,500") and hasText(AetherHUDInspect, "2 / 19"))
CHECK("inspect: no run section outside the party meter", not hasText(AetherHUDInspect, "T H I S"))
MOCK.Addon("AZSPARTY", "Jaina,mage,48000,200,0.58,Frostbolt,120;Utther,mage,35000,150,0.42,Blizzard,90")
MOCK.Run(0.6)
CHECK("inspect: what they did this run", hasText(AetherHUDInspect, "T H I S") and hasText(AetherHUDInspect, "48,000")
	and hasText(AetherHUDInspect, "58%") and hasText(AetherHUDInspect, "Frostbolt"), table.concat(shownTexts(AetherHUDInspect), " / "))
MOCK.shift = true
ChatFrameEditBox:Show()
MOCK.Script(theirHelm, "OnClick", "LeftButton")
MOCK.shift = false
CHECK("inspect: shift-click links their item", ChatFrameEditBox.__inserted and string.find(ChatFrameEditBox.__inserted, "Crown of Frost", 1, true))
ChatFrameEditBox:Hide()
AetherHUDInspect:Hide()
CHECK("inspect: closing lets the server go", MOCK.notified == nil)

-- from the target frame: a friend gets an Inspect button, which keeps to them as party1
MOCK.target = MOCK.party[1]
MOCK.Fire("PLAYER_TARGET_CHANGED")
MOCK.Run(0.3)
local inspectButton = find(AetherHUDTarget, function(o) return o.__kind == "Button" and o.text and o.text.__text == "INSPECT" end)[1]
CHECK("target: Inspect button for another hero", inspectButton and inspectButton:IsVisible())
inspectButton:Click()
MOCK.Run(0.3)
CHECK("target: it inspects them", AetherHUDInspect:IsShown() and MOCK.notified == "Jaina")
MOCK.target = { name = "Kobold Vermin", hp = 10, hpm = 10 }
MOCK.Fire("PLAYER_TARGET_CHANGED")
MOCK.Run(0.6)
CHECK("inspect: stays on a party member when the target moves on", AetherHUDInspect:IsShown() and hasText(AetherHUDInspect, "Jaina"))
CHECK("target: no Inspect button on an enemy", not inspectButton:IsVisible())
MOCK.Script(AetherHUDTarget, "OnMouseUp", "RightButton")
CHECK("target: an enemy gets the raid-mark menu", MOCK.menu and MOCK.menu.which == "RAID_TARGET_ICON", MOCK.menu and MOCK.menu.which)
CloseDropDownMenus()
InspectUnit("target")
CHECK("inspect: an enemy goes to the stock call", MOCK.stockInspect == "target")
AetherHUDInspect:Hide()
InspectUnit("player")
CHECK("inspect: yourself opens your character window", AetherHUDCharacter:IsShown())
AetherHUDCharacter:Hide()
MOCK.target = nil
MOCK.party = nil
MOCK.pet = nil
MOCK.Fire("PLAYER_TARGET_CHANGED")
MOCK.Run(0.3)

-- the game's own run settings and Options window, from ours
AetherHUD.ToggleOptions()
CHECK("options: the game's run settings", hasText(AetherHUDOptions, "store level-ups") and hasText(AetherHUDOptions, "caches")
	and not hasText(AetherHUDOptions, "spell effects"))
local storeRow
for _, o in ipairs(find(AetherHUDOptions, function(o) return o.__kind == "Button" end)) do
	if find(o, function(r) return r.__kind == "FontString" and r.__text and string.find(r.__text, "store level-ups", 1, true) end)[1] then
		storeRow = o
	end
end
storeRow:Click()
CHECK("options: store level-ups through the game's call", MOCK.cvars.storeLevels == "1")
storeRow:Click()
CHECK("options: and off again", MOCK.cvars.storeLevels == "0")
CHECK("options: the inspect window can be switched off", hasText(AetherHUDOptions, "Inspect window"))
local gameButton
for _, o in ipairs(find(AetherHUDOptions, function(o) return o.__kind == "Button" end)) do
	if o.text and o.text.__text == "Game options" then
		gameButton = o
	end
end
gameButton:Click()
CHECK("options: Game options opens the game's window", BenillaOptionsFrame:IsShown() and not AetherHUDOptions:IsShown())
BenillaOptionsFrame:Hide()

-- downed allies: where they lie, on the minimap's ring, their party frame and a plate
local DIAMOND = "Interface\\AddOns\\AetherHUD\\media\\diamond"
local function redGems(frame)
	local out = {}
	for _, o in ipairs(find(frame, function(o) return o.__kind == "Texture" and o.__tex == DIAMOND and o.__layer == "OVERLAY" end)) do
		if o:IsVisible() and o.__color and o.__color[1] == AetherHUD.C.bad[1] and o.__color[2] == AetherHUD.C.bad[2] then
			table.insert(out, o)
		end
	end
	return out
end
MOCK.party = { { name = "Brakka", hp = 0, hpm = 1500, class = "Warrior", token = "WARRIOR", player = true, friend = true,
	dead = true, map = { 0.45, 0.60 }, dist = 20 } }
MOCK.Run(0.5)
CHECK("downed: a plate names them and how far", AetherHUDRescue:IsVisible() and hasText(AetherHUDRescue, "Brakka")
	and hasText(AetherHUDRescue, "is down") and hasText(AetherHUDRescue, "close"), table.concat(shownTexts(AetherHUDRescue), " / "))
-- they lie north-east: 0.03 of the map east (x1.5 for its shape) and 0.05 north
local pin = redGems(AetherHUD.minimapRing.frame)[1]
local pp = pin and pin.__points[1]
CHECK("downed: a gem on the minimap's ring points at them", pp and pp[2] == AetherHUD.minimapRing.spot and pp[4] == 52 and pp[5] == 57,
	pp and (tostring(pp[4]) .. "," .. tostring(pp[5])))
local dot = redGems(AetherHUDParty1)[1]
local dp = dot and dot.__points[1]
CHECK("downed: their party frame says DOWN with a compass", hasText(AetherHUDParty1, "DOWN") and dp and dp[4] > 0 and dp[5] > 0)
MOCK.party[1].dist = 6
MOCK.Run(0.3)
CHECK("downed: in reach next to them", hasText(AetherHUDRescue, "in reach"))
MOCK.Addon("AZSREVIVE", "down=0;share=0;by=;reviving=Brakka;rshare=0.45")
MOCK.Run(0.3)
CHECK("downed: how far along your revive is", hasText(AetherHUDRescue, "bringing back 45%"), table.concat(shownTexts(AetherHUDRescue), " / "))
MOCK.Addon("AZSREVIVE", "down=0;share=0;by=;reviving=;rshare=0")
MOCK.cvars.rotateMinimap = "1"
MOCK.Run(0.3)
CHECK("downed: no ring gem on a turning minimap", table.getn(redGems(AetherHUD.minimapRing.frame)) == 0 and AetherHUDRescue:IsVisible())
MOCK.cvars.rotateMinimap = nil
MOCK.party[1].map = nil
MOCK.Run(0.3)
CHECK("downed: place unknown, the plate stays without pointers", AetherHUDRescue:IsVisible() and table.getn(redGems(AetherHUD.minimapRing.frame)) == 0
	and table.getn(redGems(AetherHUDRescue)) == 0)
MOCK.party[1].map = { 0.45, 0.60 }
MOCK.party[1].dead = false
MOCK.party[1].hp = 1500
MOCK.Run(0.3)
CHECK("downed: up again, all gone", not AetherHUDRescue:IsVisible() and table.getn(redGems(AetherHUD.minimapRing.frame)) == 0
	and not hasText(AetherHUDParty1, "DOWN"))
-- the game's own "is down" banner, while the client still counts them alive at no health
MOCK.party[1].hp = 1
MOCK.Addon("AZSBANNER", "id=40;kind=frienddown;boss=0;name=Brakka;text=Brakka is down! Stand next to them to bring them back.")
MOCK.Run(0.3)
CHECK("downed: the game's banner counts too", AetherHUDRescue:IsVisible() and hasText(AetherHUDParty1, "DOWN"))
MOCK.party[1].hp = 900
MOCK.Run(0.3)
CHECK("downed: and health back ends it", not AetherHUDRescue:IsVisible())
MOCK.party = nil
MOCK.Run(0.3)

-- the skill bar's menu buttons
local minis = {}
for _, o in ipairs(find(AetherHUDSkills, function(o) return o.__kind == "Button" and o.__w == 18 end)) do
	table.insert(minis, o)
end
CHECK("skill bar: four menu buttons", table.getn(minis) == 4, table.getn(minis))
minis[3]:Click()
CHECK("skill bar: inventory button", AetherHUDBags:IsShown())
minis[4]:Click()
CHECK("skill bar: game menu button", GameMenuFrame:IsShown())
GameMenuFrame:Hide()
AetherHUDBags:Hide()
MOCK.Run(0.3)
CHECK("the rest of the UI: no Lua errors", errorsSoFar() == errs, MOCK.errors[errs + 1])

-- run records: the run's end, the bests per zone and class, the history
local END1 = "result=dead;t=543;lvl=17;kills=1234;elites=12;guardians=2;bosses=3;dmg=812345;taken=40000;gold=900;chests=6;"
	.. "magnets=2;endl=0;hero=Utther;class=mage;cname=Mage;race=human;rname=Human;zone=elwynn;zname=Elwynn Forest"
MOCK.Addon("AZSEND", END1)
MOCK.Run(0.6)
local rec = AetherHUD.db.records
CHECK("records: the record opens when a run ends", AetherHUDRecords:IsShown() and hasText(AetherHUDRecords, "F A L L E N")
	and hasText(AetherHUDRecords, "1,234") and hasText(AetherHUDRecords, "9:03"), table.concat(shownTexts(AetherHUDRecords), " / "))
CHECK("records: kept in the history", table.getn(rec.runs) == 1 and rec.runs[1].kills == 1234)
local b = rec.bests["elwynn:mage"]
CHECK("records: a first run sets the bests", b and b.kills == 1234 and b.longest == 543 and b.fastest == nil and math.floor(b.dps) == 1496)
CHECK("records: first records, no NEW BEST yet", hasText(AetherHUDRecords, "first record") and not hasText(AetherHUDRecords, "N E W"))
MOCK.Run(1.0)
CHECK("records: once per run", table.getn(rec.runs) == 1)
AetherHUDRecords:Hide()
MOCK.Addon("AZSEND", "result=won;t=1001;lvl=31;kills=4210;elites=26;guardians=4;bosses=5;dmg=1830000;taken=61000;gold=800;chests=11;"
	.. "magnets=3;endl=0;hero=Utther;class=mage;cname=Mage;race=human;rname=Human;zone=elwynn;zname=Elwynn Forest")
MOCK.Run(0.6)
CHECK("records: a win", AetherHUDRecords:IsShown() and hasText(AetherHUDRecords, "V I C T O R Y"))
CHECK("records: NEW BEST where it beat the last", hasText(AetherHUDRecords, "N E W") and hasText(AetherHUDRecords, "best 900"),
	table.concat(shownTexts(AetherHUDRecords), " / "))
CHECK("records: a win's time counts as the fastest", b.fastest == 1001 and b.longest == 543 and b.kills == 4210 and b.gold == 900)
CHECK("records: newest first in the list", rec.runs[1].result == "won" and rec.runs[2].result == "dead")
CHECK("records: the list on the right", hasText(AetherHUDRecords, "16:41") and hasText(AetherHUDRecords, "R E C E N T"))
AetherHUDRecords:Hide()
MOCK.Slash("/aether", "runs")
CHECK("/aether runs opens it", AetherHUDRecords:IsShown() and hasText(AetherHUDRecords, "V I C T O R Y"))
MOCK.Slash("/aether", "runs")
CHECK("/aether runs again closes it", not AetherHUDRecords:IsShown())
rec.auto = false
MOCK.Addon("AZSEND", "result=left;t=60;lvl=2;kills=20;dmg=900;gold=5;hero=Utther;class=mage;cname=Mage;zone=duskwood;zname=Duskwood")
MOCK.Run(0.6)
CHECK("records: kept but not opened with the option off", table.getn(rec.runs) == 3 and not AetherHUDRecords:IsShown()
	and rec.bests["duskwood:mage"] ~= nil)
rec.auto = true

------------------------------------------------------------------------
-- Zone change and logout
------------------------------------------------------------------------

local frames = table.getn(MOCK.frames)
MOCK.Fire("PLAYER_ENTERING_WORLD")
MOCK.Run(0.6)
CHECK("re-entering the world builds nothing twice", table.getn(MOCK.frames) == frames, frames .. " -> " .. table.getn(MOCK.frames))
MOCK.Fire("PLAYER_LOGOUT")
CHECK("logout gives the game's HUD back", MOCK.cvars.hudClock == "1" and MOCK.cvars.hudBanners == "1", MOCK.cvars.hudClock)
CHECK("logout gives the client's settings back", MOCK.cvars.CombatDamage == "1" and MOCK.cvars.CombatLogRangeCreature == "50"
	and MOCK.cvars.CombatLogPeriodicSpells == "0", MOCK.cvars.CombatDamage)
CHECK("no Lua errors in the whole run", table.getn(MOCK.errors) == 0, MOCK.errors[1])
-- AetherHUD catches its own errors and prints them to chat, where players see them
local printed
for _, m in ipairs(MOCK.chat) do
	if string.find(m, "error:", 1, true) then
		printed = printed or m
	end
end
CHECK("no errors printed to chat in the whole run", printed == nil, printed)
