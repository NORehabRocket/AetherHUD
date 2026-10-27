-- AetherHUD boss warnings: the last ten seconds before each boss as a big countdown over
-- your hero (red, the final boss in gold) with the raid-warning sound as it starts, and a
-- short flash when a boss turns enraged. The clock shows the same wait, but mid-fight it's
-- easy to miss.

local A = AetherHUD
local C, D = A.C, A.D

local COUNT = 10 -- seconds of countdown
local ENRAGE_FOR = 3

local f, caption, number, nameText, glow, rule
local second -- the second shown, nil while no countdown runs
local tickAt = 0
local enraged = {} -- boss ids already announced as enraged this run
local enrage -- { name, at } of the last one

local function NextBoss()
	local nb = D.Upcoming()[1]
	if nb and nb.name then
		return nb.name, A.N(nb.left), A.Flag(nb.final)
	end
	local run = D.Run()
	if run.nb ~= nil and A.N(run.nb) >= 0 then
		return (run.nbn and run.nbn ~= "" and run.nbn) or "Boss", A.N(run.nb), false
	end
end

local function Watch(now)
	local bosses = D.Bosses()
	for i = 1, table.getn(bosses) do
		local b = bosses[i]
		local id = A.N(b.id)
		if A.Flag(b.enraged) and not enraged[id] then
			enraged[id] = true
			enrage = { name = b.name or "Boss", at = now }
		end
	end
end

local function Paint(cap, num, name, c)
	A.SetText(caption, cap)
	A.SetText(number, num)
	A.SetText(nameText, name)
	A.SetTextColor(number, c)
	A.SetTextColor(nameText, c)
	A.SetColor(glow, c[1], c[2], c[3], 1)
	A.SetColor(rule, c[1], c[2], c[3], 0.8)
end

local function Update()
	local phase = D.Phase()
	if not D.InRun() then
		A.Show(f, false)
		return
	end
	local now = GetTime()
	if phase == "ready" then
		enraged, enrage = {}, nil
	end
	local name, left, final
	if A.Demo() then
		name, left, final = "Morgan the Collector", COUNT - math.mod(now, COUNT + 4), false
	elseif phase == "playing" then
		name, left, final = NextBoss()
	end
	if name and left and left > 0 and left <= COUNT then
		local s = math.ceil(left)
		if s ~= second then
			if not second and PlaySound and A.db.warnSound then
				PlaySound("RaidWarning")
			end
			second = s
			tickAt = now
			local c = final and C.gold or C.bad
			Paint(final and A.Spaced("Final boss") or A.Spaced("Boss incoming"), tostring(s), name, c)
		end
		-- each second lands bright, then settles
		local k = 1 - math.min(1, (now - tickAt) / 0.6)
		A.SetAlpha(glow, 0.2 + 0.6 * k)
		A.SetAlpha(number, 0.7 + 0.3 * k)
		A.SetAlpha(f, 1)
		A.Show(f, true)
		return
	end
	second = nil

	if not A.Demo() then
		Watch(now)
	end
	if enrage and now - enrage.at < ENRAGE_FOR then
		Paint(A.Spaced("Enraged"), "", enrage.name, C.rage2)
		A.SetAlpha(glow, 0.3 + 0.4 * A.Pulse(2))
		A.SetAlpha(f, math.min(1, (ENRAGE_FOR - (now - enrage.at)) / 0.5))
		A.Show(f, true)
		return
	end
	A.Show(f, false)
end

local function Init()
	if not A.On("warnings") then
		return
	end
	-- floating over the hero, under the banners; above windows, as the banners are
	f = CreateFrame("Frame", "AetherHUDBossWarning", A.root)
	f:SetFrameStrata("FULLSCREEN")
	f:SetWidth(320)
	f:SetHeight(84)
	glow = A.Tex(f, "BACKGROUND", A.MEDIA .. "glow")
	glow:SetBlendMode("ADD")
	glow:SetWidth(200)
	glow:SetHeight(90)
	glow:SetPoint("CENTER", f, "CENTER", 0, 4)
	caption = A.Text(f, 10, true)
	caption:SetPoint("TOP", f, "TOP", 0, -2)
	caption:SetTextColor(C.steel[1], C.steel[2], C.steel[3])
	rule = A.Tex(f, "ARTWORK", A.MEDIA .. "line")
	rule:SetBlendMode("ADD")
	rule:SetWidth(220)
	rule:SetHeight(4)
	rule:SetPoint("TOP", caption, "BOTTOM", 0, -2)
	number = A.Text(f, 40)
	number:SetPoint("TOP", rule, "BOTTOM", 0, -1)
	nameText = A.Text(f, 14, true)
	nameText:SetPoint("BOTTOM", f, "BOTTOM", 0, 2)
	f:Hide()
	f.aS = false

	A.RegisterMover("warnings", f, "Boss warning", function(fr)
		fr:SetPoint("CENTER", A.root, "CENTER", 0, 62)
	end)
	A.Every(0.05, Update)
end

A.OnInit(Init)
