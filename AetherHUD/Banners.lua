-- AetherHUD banners: the game's announcements (a boss arriving, a guardian slain, a zone
-- opened...) as Aion's winged notices. Every banner reaches us through the game's own
-- banner hook, so nothing is lost when the game's banners are hidden.

local A = AetherHUD
local C = A.C

local IN, HOLD, OUT = 0.25, 2.6, 0.55

local STYLES = {
	boss = { "Boss", A.C.rage2 },
	finalboss = { "Final Boss", A.C.gold },
	bossdown = { "Boss Defeated", A.C.gold },
	guardian = { "Guardian Slain", A.C.violet },
	unlocked = { "Zone Unlocked", A.C.aether },
	achievement = { "Achievement", A.C.gold },
	downed = { "Down", A.C.bad },
	frienddown = { "Ally Down", A.C.bad },
	revived = { "Revived", A.C.good },
	magnet = { "Magnet", A.C.aether },
	zone = { "Zone", A.C.aether },
}

local f, caption, text, glow, rule, wingL, wingR
local queue = {}
local current, age

local function Show(b)
	local style = STYLES[b.kind or ""] or { "", C.aether }
	local c = style[2]
	A.SetText(caption, A.Spaced(style[1]))
	caption:SetTextColor(c[1], c[2], c[3])
	A.SetText(text, b.text or b.name or "")
	if b.kind == "finalboss" or b.kind == "boss" then
		text:SetTextColor(1, 0.86, 0.72)
	else
		text:SetTextColor(C.text[1], C.text[2], C.text[3])
	end
	glow:SetVertexColor(c[1], c[2], c[3], 1)
	rule:SetVertexColor(c[1], c[2], c[3], 1)
	wingL:SetVertexColor(c[1], c[2], c[3], 1)
	wingR:SetVertexColor(c[1], c[2], c[3], 1)
	current, age = b, 0
	A.Show(f, true)
end

local function Push(b)
	-- the same notice twice in a row (a re-sent line) shows once
	local last = queue[table.getn(queue)] or current
	if last and last.text == b.text and last.kind == b.kind and age and age < 1 then
		return
	end
	table.insert(queue, b)
	while table.getn(queue) > 5 do
		table.remove(queue, 1)
	end
end

local function Tick(dt)
	if not current then
		if table.getn(queue) == 0 and A.unlocked then
			-- something to look at while placing the frame
			A.TestBanners()
		end
		if table.getn(queue) > 0 then
			Show(table.remove(queue, 1))
		end
		return
	end
	age = age + dt
	local hold = table.getn(queue) > 1 and HOLD * 0.55 or HOLD
	local a, slide
	if age < IN then
		local p = age / IN
		a, slide = p, (1 - p) * 26
	elseif age < IN + hold then
		a, slide = 1, 0
	elseif age < IN + hold + OUT then
		a, slide = 1 - (age - IN - hold) / OUT, 0
	else
		current = nil
		A.Show(f, false)
		return
	end
	A.SetAlpha(f, a)
	A.SetAlpha(glow, 0.32 + 0.12 * A.Pulse(0.7))
	if f.slide ~= slide then
		f.slide = slide
		wingL:ClearAllPoints()
		wingL:SetPoint("RIGHT", text, "LEFT", -10 + slide, -2)
		wingR:ClearAllPoints()
		wingR:SetPoint("LEFT", text, "RIGHT", 10 - slide, -2)
	end
end

function A.TestBanners()
	if not f then
		return
	end
	Push({ kind = "boss", text = "Mother Fang approaches!" })
	Push({ kind = "guardian", text = "Kobold Geomancer is slain! Its hoard and a level." })
	Push({ kind = "finalboss", text = "Edwin VanCleef has come!" })
	if A.LootCard then
		A.LootCard("Hogger's Spiked Collar", "Interface\\Icons\\Spell_Holy_SealOfSalvation", { 0.64, 0.21, 0.93 }, nil,
			"New in your collection!")
	end
end

local function Init()
	if not A.On("banners") then
		return
	end
	if type(AZS_RegisterBannerHandler) ~= "function" then
		-- an older client without the hook: leave the game's own banners up
		A.noBannerHook = true
		return
	end
	f = CreateFrame("Frame", "AetherHUDBanner", A.root)
	f:SetFrameStrata("FULLSCREEN") -- over open windows: a notice must always read
	f:SetWidth(620)
	f:SetHeight(90)

	glow = A.Tex(f, "BACKGROUND", A.MEDIA .. "glow")
	glow:SetBlendMode("ADD")
	glow:SetPoint("CENTER", f, "CENTER", 0, -2)
	glow:SetWidth(520)
	glow:SetHeight(110)

	caption = A.Text(f, 11, true)
	caption:SetPoint("TOP", f, "TOP", 0, -8)
	text = A.Text(f, 24, true)
	A.Font(text, 24, true, "OUTLINE")
	text:SetPoint("TOP", caption, "BOTTOM", 0, -6)
	rule = A.Tex(f, "ARTWORK", A.MEDIA .. "line")
	rule:SetBlendMode("ADD")
	rule:SetPoint("TOP", text, "BOTTOM", 0, -6)
	rule:SetWidth(460)
	rule:SetHeight(5)

	wingL = A.Tex(f, "ARTWORK", A.MEDIA .. "wing")
	wingL:SetWidth(150)
	wingL:SetHeight(38)
	wingL:SetBlendMode("ADD")
	wingR = A.Tex(f, "ARTWORK", A.MEDIA .. "wing")
	wingR:SetWidth(150)
	wingR:SetHeight(38)
	wingR:SetTexCoord(1, 0, 0, 1)
	wingR:SetBlendMode("ADD")
	f.slide = nil
	f:Hide()
	f.aS = false

	A.PushBanner = Push
	AZS_RegisterBannerHandler(function(b)
		if type(b) == "table" then
			Push(b)
		end
	end)

	A.RegisterMover("banners", f, "Banners", function(fr)
		fr:SetPoint("CENTER", A.root, "CENTER", 0, 150)
	end)
	A.Every(0.02, Tick)
end

A.OnInit(Init)
