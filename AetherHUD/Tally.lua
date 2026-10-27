-- AetherHUD tally: the run's counters in a glass grid (kills, gold, the next cache's
-- price, enemies and elites alive, rerolls). Stands in for the game's "tally".

local A = AetherHUD
local C, D = A.C, A.D

local COLS, CW, CH, PAD = 3, 70, 24, 6
local W = PAD * 2 + COLS * CW
local H = PAD * 2 + 2 * CH

local CELLS = {
	{ key = "kills", icon = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", tip = "Enemies killed", crop = false },
	{ key = "gold", icon = "Interface\\Icons\\INV_Misc_Coin_01", tip = "Gold", color = A.C.gold },
	{ key = "chest", icon = "Interface\\Icons\\INV_Box_01", tip = "The next cache costs" },
	{ key = "en", icon = "Interface\\Icons\\Ability_Hunter_SniperShot", tip = "Enemies alive" },
	{ key = "el", icon = "Interface\\Icons\\Spell_Shadow_UnholyStrength", tip = "Elites alive (not bosses or guardians)", color = A.C.gold },
	{ key = "rr", icon = "Interface\\Icons\\Spell_Shadow_Teleport", tip = "Rerolls left" },
}

local f
local cells = {}

local function Update()
	if not D.InRun() then
		A.Show(f, false)
		return
	end
	A.Show(f, true)
	local run = D.Run()
	for i = 1, table.getn(cells) do
		local c = cells[i]
		local v = A.N(run[c.def.key])
		local s
		if c.def.key == "kills" or c.def.key == "gold" then
			s = A.Short(v)
		else
			s = tostring(math.floor(v + 0.5))
		end
		if c.def.key == "chest" then
			-- red when you can't afford it yet
			A.SetTextColor(c.text, v > A.N(run.gold) and C.bad or C.text)
		end
		A.SetText(c.text, s)
	end
end

local function CellTooltip()
	local def = this.def
	local run = D.Run()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetText(def.tip, 1, 1, 1)
	if def.key == "kills" then
		GameTooltip:AddDoubleLine("Bosses", A.N(run.bk), 0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:AddDoubleLine("Guardians", A.N(run.gk), 0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:AddDoubleLine("Elites", A.N(run.ek), 0.8, 0.8, 0.8, 1, 1, 1)
	elseif def.key == "gold" then
		GameTooltip:AddDoubleLine("Earned this run", A.Comma(run.ge), 0.8, 0.8, 0.8, 1, 0.82, 0)
	elseif def.key == "chest" then
		GameTooltip:AddDoubleLine("Caches opened", A.N(run.ck), 0.8, 0.8, 0.8, 1, 1, 1)
	elseif def.key == "rr" then
		GameTooltip:AddDoubleLine("Next one costs", A.Comma(run.rrc) .. " gold", 0.8, 0.8, 0.8, 1, 0.82, 0)
	end
	GameTooltip:Show()
end

local function Init()
	if not A.On("tally") then
		return
	end
	f = A.Panel("AetherHUDTally", A.root, W, H)
	for i = 1, table.getn(CELLS) do
		local def = CELLS[i]
		local col = math.mod(i - 1, COLS)
		local row = math.floor((i - 1) / COLS)
		local cell = CreateFrame("Frame", nil, f)
		cell:SetWidth(CW)
		cell:SetHeight(CH)
		cell:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + col * CW, -PAD - row * CH)
		cell:EnableMouse(true)
		cell.def = def
		cell:SetScript("OnEnter", CellTooltip)
		cell:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		local icon = A.Tex(cell, "ARTWORK", def.icon)
		icon:SetWidth(18)
		icon:SetHeight(18)
		icon:SetPoint("LEFT", cell, "LEFT", 3, 0)
		if def.crop ~= false then
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			A.Border(cell, { 0, 0, 0 }, 1, "OVERLAY", icon, -1)
		end
		local text = A.Text(cell, 12)
		text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
		if def.color then
			text:SetTextColor(def.color[1], def.color[2], def.color[3])
		end
		if col > 0 then
			local div = A.Tex(cell, "BORDER")
			div:SetWidth(1)
			div:SetHeight(CH - 8)
			div:SetPoint("LEFT", cell, "LEFT", -1, 0)
			div:SetVertexColor(C.edge[1], C.edge[2], C.edge[3], 0.5)
		end
		table.insert(cells, { def = def, text = text })
	end
	A.RegisterMover("tally", f, "Run tally", function(fr)
		fr:SetPoint("TOPRIGHT", A.root, "TOPRIGHT", -14, -214)
	end)
	A.Every(0.2, Update)
end

A.OnInit(Init)
