-- AetherHUD lairs: every guardian's lair, whether its guardian sleeps, fights (with its
-- health) or is gone and when the lair fills again.

local A = AetherHUD
local C, D = A.C, A.D

local W, HEAD, ROW, PAD = 214, 20, 18, 6

local f, title, count
local rows = {}

local function Row(i)
	local r = rows[i]
	if r then
		return r
	end
	r = {}
	local y = -HEAD - (i - 1) * ROW
	r.gem = A.Diamond(f, 11, C.violet, "ARTWORK")
	r.gem:SetPoint("CENTER", f, "TOPLEFT", PAD + 6, y - ROW / 2 + 1)
	r.name = A.Text(f, 10)
	r.name:SetPoint("LEFT", r.gem, "RIGHT", 5, 0)
	r.name:SetWidth(W - 90)
	r.name:SetJustifyH("LEFT")
	r.state = A.Text(f, 10)
	r.state:SetPoint("RIGHT", f, "TOPRIGHT", -PAD - 2, y - ROW / 2 + 1)
	r.state:SetJustifyH("RIGHT")
	r.track = A.Tex(f, "ARTWORK")
	r.track:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 17, y - ROW + 2)
	r.track:SetWidth(W - 2 * PAD - 19)
	r.track:SetHeight(2)
	r.track:SetVertexColor(0, 0, 0, 0.6)
	r.hp = A.Tex(f, "OVERLAY")
	r.hp:SetPoint("TOPLEFT", r.track, "TOPLEFT", 0, 0)
	r.hp:SetHeight(2)
	r.hp:SetVertexColor(C.violet[1], C.violet[2], C.violet[3], 1)
	rows[i] = r
	return r
end

local function Update()
	if not D.InRun() then
		A.Show(f, false)
		return
	end
	local lairs = D.Lairs()
	local n = table.getn(lairs)
	if n == 0 then
		A.Show(f, false)
		return
	end
	A.Show(f, true)
	local hpById = {}
	local guardians = D.Guardians()
	for i = 1, table.getn(guardians) do
		local g = guardians[i]
		hpById[A.N(g.id)] = g
	end
	local held = 0
	local pulse = A.Pulse(1.2)
	for i = 1, n do
		local l = lairs[i]
		local r = Row(i)
		A.SetText(r.name, l.name or "?")
		local trackW = W - 2 * PAD - 19
		if l.state == "awake" then
			held = held + 1
			local g = hpById[A.N(l.id)]
			local frac = g and A.N(g.hpm) > 0 and A.N(g.hp) / A.N(g.hpm) or 1
			A.SetColor(r.gem, C.violet[1], C.violet[2], C.violet[3], 0.55 + 0.45 * pulse)
			A.SetTextColor(r.name, C.text)
			A.SetText(r.state, string.format("%.0f%%", frac * 100))
			A.SetTextColor(r.state, C.violet)
			A.SetWidth(r.hp, math.max(0.5, trackW * frac))
			A.Show(r.track, true)
			A.Show(r.hp, true)
		elseif l.state == "asleep" then
			held = held + 1
			A.SetColor(r.gem, C.violet[1] * 0.6, C.violet[2] * 0.6, C.violet[3] * 0.6, 1)
			A.SetTextColor(r.name, C.steel)
			A.SetText(r.state, "asleep")
			A.SetTextColor(r.state, C.muted)
			A.Show(r.track, false)
			A.Show(r.hp, false)
		else
			A.SetColor(r.gem, 0.3, 0.34, 0.4, 1)
			A.SetTextColor(r.name, C.muted)
			local left = A.N(l.left)
			if left > 0 then
				A.SetText(r.state, A.Clock(left))
				A.SetTextColor(r.state, C.muted)
			else
				A.SetText(r.state, "due")
				A.SetTextColor(r.state, C.gold)
			end
			A.Show(r.track, false)
			A.Show(r.hp, false)
		end
		A.Show(r.gem, true)
		A.Show(r.name, true)
		A.Show(r.state, true)
	end
	for i = n + 1, table.getn(rows) do
		local r = rows[i]
		A.Show(r.gem, false)
		A.Show(r.name, false)
		A.Show(r.state, false)
		A.Show(r.track, false)
		A.Show(r.hp, false)
	end
	A.SetText(count, held .. " / " .. n .. " held")
	A.SetHeight(f, HEAD + n * ROW + PAD)
end

local function Init()
	if not A.On("lairs") then
		return
	end
	f = A.Panel("AetherHUDLairs", A.root, W, HEAD + ROW + PAD)
	title = A.Text(f, 10, true)
	title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 1, -6)
	title:SetText("LAIRS")
	title:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	count = A.Text(f, 9)
	count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD - 2, -7)
	count:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	local rule = A.Tex(f, "ARTWORK", A.MEDIA .. "line")
	rule:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -HEAD + 3)
	rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -HEAD + 3)
	rule:SetHeight(3)
	rule:SetVertexColor(C.violet[1], C.violet[2], C.violet[3], 0.7)
	A.RegisterMover("lairs", f, "Lairs", function(fr)
		fr:SetPoint("TOPRIGHT", A.root, "TOPRIGHT", -14, -286)
	end)
	A.Every(0.2, Update)
end

A.OnInit(Init)
