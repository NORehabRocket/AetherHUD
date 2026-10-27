-- AetherHUD run records: when a run ends, Aion's record of it. The result, then time, level,
-- kills, damage per second, damage, gold, bosses, elites, guardians, caches, damage taken and
-- magnets, with your best for that zone and class under each (a gold NEW BEST where you beat
-- it), and your recent runs on the right. `/aether runs` opens it any time.
--
-- Bests are kept per zone and class (endless runs apart), for every hero on the account, in
-- AetherHUD's saved variables. Time counts both ways: the fastest win, or in a run you lost,
-- the longest you lasted.

local A = AetherHUD
local C, D = A.C, A.D

local W, H = 640, 300
local TILE_W, TILE_H, GAP = 100, 52, 6
local LIST_W = 176
local KEEP = 30 -- runs kept in the history

local f, resultText, subText, footText, listCol
local tiles = {}
local lines = {}
local shown -- the run on show (a history entry)

local function Won(r)
	local s = string.lower(r.result or "")
	return s == "won" or s == "victory" or s == "win" or A.Flag(r.won)
end

local function ResultLabel(r)
	local s = string.lower(r.result or "")
	if Won(r) then
		return "VICTORY", C.gold
	elseif s == "left" or s == "quit" or s == "abandoned" then
		return "LEFT THE RUN", C.muted
	elseif s == "dead" or s == "fell" or s == "died" or s == "lost" or s == "death" then
		return "FALLEN", C.bad
	end
	return string.upper(r.result or "?"), C.steel
end

local function Per(r)
	return A.N(r.dmg) / math.max(1, A.N(r.t))
end

local BESTS = {
	kills = function(r) return A.N(r.kills) end,
	dmg = function(r) return A.N(r.dmg) end,
	dps = Per,
	gold = function(r) return A.N(r.gold) end,
	lvl = function(r) return A.N(r.lvl) end,
	fastest = function(r) if Won(r) then return A.N(r.t) end end,
	longest = function(r) if not Won(r) then return A.N(r.t) end end,
}
local LOWER = { fastest = true } -- smaller is better

-- { label, value(run), best key (or a function of the run), how the best reads }
local TILES = {
	{ "TIME", function(r) return A.Clock(A.N(r.t)) end, function(r) return Won(r) and "fastest" or "longest" end, A.Clock },
	{ "LEVEL", function(r) return tostring(A.N(r.lvl)) end, "lvl", function(v) return tostring(v) end },
	{ "KILLS", function(r) return A.Comma(r.kills) end, "kills", A.Comma },
	{ "PER SECOND", function(r) return A.Comma(Per(r)) end, "dps", A.Comma },
	{ "DAMAGE", function(r) return A.Short(r.dmg) end, "dmg", A.Short },
	{ "GOLD", function(r) return A.Comma(r.gold) end, "gold", A.Comma },
	{ "BOSSES", function(r) return tostring(A.N(r.bosses)) end },
	{ "ELITES", function(r) return tostring(A.N(r.elites)) end },
	{ "GUARDIANS", function(r) return tostring(A.N(r.guardians)) end },
	{ "CACHES", function(r) return tostring(A.N(r.chests)) end },
	{ "TAKEN", function(r) return A.Short(r.taken) end },
	{ "MAGNETS", function(r) return tostring(A.N(r.magnets)) end },
}

local FIELDS = { "result", "t", "lvl", "kills", "elites", "guardians", "bosses", "dmg", "taken", "gold", "chests",
	"magnets", "endl", "hero", "class", "cname", "race", "rname", "zone", "zname" }

local function BestKey(r)
	return (r.zone or r.zname or "?") .. ":" .. (r.class or r.cname or "?") .. (A.Flag(r.endl) and ":endless" or "")
end

local function Sig(r)
	return table.concat({ r.hero or "", r.zone or "", r.result or "", A.N(r.t), A.N(r.kills), A.N(r.dmg) }, "|")
end

-- Keep a finished run: the history, and the bests it beat (flagged on the entry).
local function Record(summary)
	local db = A.db.records
	local r = { date = date and date("%d %b %H:%M") or "" }
	for i = 1, table.getn(FIELDS) do
		r[FIELDS[i]] = summary[FIELDS[i]]
	end
	r.sig = Sig(r)
	r.new = {}
	r.prev = {}
	local key = BestKey(r)
	db.bests[key] = db.bests[key] or {}
	local best = db.bests[key]
	for k, get in pairs(BESTS) do
		local v = get(r)
		if v then
			local old = best[k]
			r.prev[k] = old
			if old == nil or (LOWER[k] and v < old) or (not LOWER[k] and v > old) then
				if old ~= nil then
					r.new[k] = true
				end
				best[k] = v
			end
		end
	end
	table.insert(db.runs, 1, r)
	while table.getn(db.runs) > KEEP do
		table.remove(db.runs)
	end
	db.last = r.sig
	return r
end

local DEMO = {
	result = "won", t = 1001, lvl = 31, kills = 4210, elites = 26, guardians = 4, bosses = 5, dmg = 1830000,
	taken = 61000, gold = 2140, chests = 11, magnets = 3, endl = 0, hero = "Utther", class = "shaman",
	cname = "Shaman", race = "orc", rname = "Orc", zone = "elwynn", zname = "Elwynn Forest", date = "today",
	new = { kills = true, dps = true }, prev = { kills = 3890, dps = 1702, fastest = 1012, lvl = 31, gold = 2300, dmg = 1910000 },
	demo = true,
}

------------------------------------------------------------------------

local function Tile(i)
	local t = tiles[i]
	if t then
		return t
	end
	local col = math.mod(i - 1, 4)
	local row = math.floor((i - 1) / 4)
	local p = A.Panel(nil, f, TILE_W, TILE_H, { bracket = 4, noGlint = true, alpha = 0.6 })
	p:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + col * (TILE_W + GAP), -84 - row * (TILE_H + GAP))
	t = { frame = p }
	t.label = A.Text(p, 8, true)
	t.label:SetPoint("TOP", p, "TOP", 0, -5)
	t.label:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	t.value = A.Text(p, 14)
	t.value:SetPoint("CENTER", p, "CENTER", 0, -1)
	t.best = A.Text(p, 8)
	t.best:SetPoint("BOTTOM", p, "BOTTOM", 0, 5)
	tiles[i] = t
	return t
end

local function Line(i)
	local l = lines[i]
	if l then
		return l
	end
	local b = CreateFrame("Button", nil, listCol)
	b:SetWidth(LIST_W)
	b:SetHeight(14)
	b:SetPoint("TOPLEFT", listCol, "TOPLEFT", 8, -26 - (i - 1) * 14)
	local hl = A.Tex(b, "HIGHLIGHT")
	hl:SetAllPoints(b)
	hl:SetVertexColor(C.aether[1], C.aether[2], C.aether[3], 0.08)
	l = { button = b }
	l.gem = A.Diamond(b, 7, C.steel, "ARTWORK")
	l.gem:SetPoint("LEFT", b, "LEFT", 1, 0)
	l.zone = A.Text(b, 9)
	l.zone:SetPoint("LEFT", b, "LEFT", 12, 0)
	l.time = A.Text(b, 9)
	l.time:SetPoint("RIGHT", b, "RIGHT", 0, 0)
	l.time:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	b:SetScript("OnClick", function()
		if this.run then
			A.ShowRecord(this.run)
		end
	end)
	b:SetScript("OnEnter", function()
		local r = this.run
		if not r then
			return
		end
		local label, c = ResultLabel(r)
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(r.zname or r.zone or "?", C.gold[1], C.gold[2], C.gold[3])
		GameTooltip:AddLine(label, c[1], c[2], c[3])
		GameTooltip:AddDoubleLine((r.hero or "") .. ", " .. (r.cname or ""), r.date or "", 0.8, 0.8, 0.8, 0.6, 0.6, 0.6)
		GameTooltip:AddDoubleLine("Time", A.Clock(A.N(r.t)), 0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:AddDoubleLine("Kills", A.Comma(r.kills), 0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:AddDoubleLine("Per second", A.Comma(Per(r)), 0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	lines[i] = l
	return l
end

-- Under a tile: NEW BEST where this run beat it, else the best to beat (the sample run in
-- demo brings its own).
local function BestLine(t, r, key, fmt)
	local best = (A.db.records.bests[BestKey(r)] or {})[key]
	if r.demo then
		best = r.prev[key]
	end
	local text, c, edge = "", C.muted, nil
	if r.new and r.new[key] then
		text, c, edge = A.Spaced("New best"), C.gold, C.gold
	elseif best ~= nil then
		local get = BESTS[key]
		if get(r) == best and r.prev and r.prev[key] == nil then
			text = "first record"
		else
			text = "best " .. fmt(best)
		end
	end
	A.SetText(t.best, text)
	A.SetTextColor(t.best, c)
	A.PanelAlert(t.frame, edge, 0.9)
end

local function Paint(r)
	if not r then
		A.SetText(resultText, A.Spaced("No runs yet"))
		A.SetTextColor(resultText, C.muted)
		A.SetText(subText, "Finish a run and its record shows here.")
		A.SetText(footText, "")
		for i = 1, table.getn(TILES) do
			local t = Tile(i)
			A.SetText(t.label, TILES[i][1])
			A.SetText(t.value, "-")
			A.SetText(t.best, "")
		end
	else
		local label, c = ResultLabel(r)
		A.SetText(resultText, A.Spaced(label))
		A.SetTextColor(resultText, c)
		local cc = A.CLASS[string.lower(r.class or "")] or C.steel
		local mode = A.Flag(r.endl) and (A.Hex(C.violet) .. "  endless|r") or ""
		A.SetText(subText, A.Hex(C.gold) .. (r.zname or r.zone or "") .. "|r" .. mode .. A.Hex(C.muted) .. "  \194\183  |r"
			.. (r.hero or "") .. "  " .. (r.rname or "") .. " " .. A.Hex(cc) .. (r.cname or "") .. "|r" .. A.Hex(C.muted)
			.. "  \194\183  " .. (r.date or "") .. "|r")
		for i = 1, table.getn(TILES) do
			local def = TILES[i]
			local t = Tile(i)
			A.SetText(t.label, def[1])
			local ok, v = pcall(def[2], r)
			A.SetText(t.value, ok and v or "-")
			if def[3] then
				local key = type(def[3]) == "function" and def[3](r) or def[3]
				BestLine(t, r, key, def[4])
			else
				A.SetText(t.best, "")
				A.PanelAlert(t.frame, nil)
			end
		end
		A.SetText(footText, "Bests are for " .. (r.zname or r.zone or "this zone") .. " with a " .. (r.cname or "hero")
			.. (A.Flag(r.endl) and ", endless" or "") .. ". Time: the fastest win, or the longest you lasted.")
	end

	local runs = A.db.records.runs
	local n = math.min(table.getn(runs), 20)
	for i = 1, n do
		local run = runs[i]
		local l = Line(i)
		l.button.run = run
		local _, c = ResultLabel(run)
		A.SetColor(l.gem, c[1], c[2], c[3], 1)
		A.SetText(l.zone, (run == r and A.Hex(C.gold) or "") .. (run.zname or run.zone or "?"))
		A.SetText(l.time, A.Clock(A.N(run.t)))
		A.Show(l.button, true)
	end
	for i = n + 1, table.getn(lines) do
		A.Show(lines[i].button, false)
	end
end

function A.ShowRecord(r)
	if not f then
		return
	end
	shown = r
	Paint(r)
	f:Show()
end

function A.ToggleRecords()
	if not f then
		A.Print("run records are switched off in /aether.")
		return
	end
	if f:IsShown() then
		f:Hide()
		return
	end
	A.ShowRecord(A.Demo() and DEMO or A.db.records.runs[1])
end

-- A run that just ended: record it once, then show it.
local function Check()
	if A.Demo() or not AZS_GetRunSummary then
		return
	end
	local s = AZS_GetRunSummary()
	if not s or not s.result then
		return
	end
	local sig = Sig(s)
	if sig == A.db.records.last then
		return
	end
	local r = Record(s)
	if A.db.records.auto then
		A.ShowRecord(r)
	end
end

local function Init()
	if not A.On("records") then
		return
	end
	f = A.Window("records", "AetherHUDRecords", "Run record", W, H, function(fr)
		fr:SetPoint("CENTER", A.root, "CENTER", -300, 60)
	end)
	resultText = A.Text(f, 18, true)
	resultText:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -36)
	subText = A.Text(f, 10)
	subText:SetPoint("TOPLEFT", resultText, "BOTTOMLEFT", 0, -5)
	footText = A.Text(f, 9)
	footText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12)
	footText:SetTextColor(C.muted[1], C.muted[2], C.muted[3])

	listCol = A.Panel(nil, f, LIST_W + 16, H - 44, { bracket = 5, noGlint = true, alpha = 0.45 })
	listCol:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -32)
	local head = A.Text(listCol, 10, true)
	head:SetPoint("TOPLEFT", listCol, "TOPLEFT", 8, -6)
	head:SetText(A.Spaced("Recent runs"))
	head:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	local rule = A.Tex(listCol, "ARTWORK", A.MEDIA .. "line")
	rule:SetHeight(3)
	rule:SetWidth(LIST_W)
	rule:SetPoint("TOPLEFT", listCol, "TOPLEFT", 4, -19)
	rule:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.5)

	f.OnOpen = function()
		Paint(shown)
	end
	Check()
	A.Every(0.5, Check)
end

A.OnInit(Init)
