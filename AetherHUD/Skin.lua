-- AetherHUD skins: the stock frames that stay (tooltips, dialogs, the game menu, right-click
-- menus) re-dressed in the same navy glass, and the helpers the window modules share.

local A = AetherHUD
local C = A.C

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

-- Every texture drawn directly on `frame` goes invisible (its own art, not its children's).
function A.StripTextures(frame, pattern)
	if not frame or not frame.GetRegions then
		return
	end
	local regions = { frame:GetRegions() }
	for i = 1, table.getn(regions) do
		local r = regions[i]
		if r.GetObjectType and r:GetObjectType() == "Texture" then
			local tex = r:GetTexture()
			if not pattern or (tex and string.find(string.lower(tex), pattern, 1, true)) then
				r:SetAlpha(0)
			end
		end
	end
end

-- A stock frame gone for good: hidden, deaf and unable to come back.
function A.Kill(frame)
	if not frame then
		return
	end
	if frame.UnregisterAllEvents then
		frame:UnregisterAllEvents()
	end
	if frame.EnableMouse then
		frame:EnableMouse(false)
	end
	frame:Hide()
	frame:SetAlpha(0)
	frame.Show = function() end
end

-- A stock frame in our glass.
function A.SkinFrame(frame, opts)
	if not frame or frame.aSkinned then
		return frame
	end
	frame.aSkinned = true
	if frame.SetBackdrop then
		pcall(frame.SetBackdrop, frame, nil)
	end
	return A.Dress(frame, opts or { alpha = 0.94, bracket = 6 })
end

-- A stock push button: its art gone, a glass slab with a soft aether glow on hover.
function A.SkinButton(b)
	if not b or b.aSkinned then
		return
	end
	b.aSkinned = true
	A.StripTextures(b)
	for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local t = b[get] and b[get](b)
		if t then
			t:SetAlpha(0)
		end
	end
	local bg = A.Tex(b, "BACKGROUND")
	bg:SetAllPoints(b)
	A.Gradient(bg, "VERTICAL", { 0.04, 0.10, 0.16 }, { 0.10, 0.22, 0.32 }, 1, 1)
	b.aEdge = A.Border(b, C.edge, 1, "BORDER")
	local hl = A.Tex(b, "HIGHLIGHT", A.MEDIA .. "glow")
	hl:SetBlendMode("ADD")
	hl:SetAllPoints(b)
	hl:SetVertexColor(C.aether[1], C.aether[2], C.aether[3], 0.35)
end

-- Our own glass button.
function A.GlassButton(parent, label, w, h, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(w)
	b:SetHeight(h or 20)
	A.SkinButton(b)
	b.text = A.Text(b, 10, true)
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.text:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

-- A movable window: glass panel, title, close button, Escape closes it, and its place
-- is remembered like any other frame (it also shows up when frames are unlocked).
function A.Window(key, name, title, w, h, default)
	-- above the floating numbers (MEDIUM), below dialogs and tooltips
	local f = A.Panel(name, A.root, w, h, { strata = "HIGH", alpha = 0.95, bracket = 10 })
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:Hide()
	f.aS = false
	local bar = CreateFrame("Frame", nil, f)
	bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, 0)
	bar:SetHeight(26)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function()
		f:SetMovable(true)
		f:StartMoving()
	end)
	bar:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		if f.SetUserPlaced then
			f:SetUserPlaced(false)
		end
		A.SavePos(key)
	end)
	f.title = A.Text(f, 13, true)
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -9)
	f.title:SetText(A.Spaced(title))
	f.title:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	local rule = A.Tex(f, "ARTWORK", A.MEDIA .. "line")
	rule:SetBlendMode("ADD")
	rule:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -26)
	rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -26)
	rule:SetHeight(3)
	rule:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.6)
	local close = A.GlassButton(f, "X", 20, 18, function()
		f:Hide()
	end)
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -5)
	f:SetScript("OnShow", function()
		this.aS = true
		if this.OnOpen then
			this.OnOpen()
		end
	end)
	f:SetScript("OnHide", function()
		this.aS = false
	end)
	table.insert(UISpecialFrames, name)
	A.RegisterMover(key, f, title, default)
	return f
end

function A.ToggleWindow(f)
	if f:IsShown() then
		f:Hide()
	else
		f:Show()
	end
end

-- Item quality colour from a link's |cffRRGGBB, or nil.
function A.LinkColor(link)
	if type(link) ~= "string" then
		return nil
	end
	local _, _, hex = string.find(link, "|c%x%x(%x%x%x%x%x%x)")
	if not hex then
		return nil
	end
	return { tonumber(string.sub(hex, 1, 2), 16) / 255, tonumber(string.sub(hex, 3, 4), 16) / 255,
		tonumber(string.sub(hex, 5, 6), 16) / 255 }
end

-- Shift-click: the item's link into the chat line, as the stock frames do.
function A.InsertLink(link)
	if link and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
		ChatFrameEditBox:Insert(link)
		return true
	end
	return false
end

------------------------------------------------------------------------
-- Tooltips: glass, the hairline in the colour of the first line (item quality,
-- reaction), and enemies tagged with what they are to the run.
------------------------------------------------------------------------

local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "WorldMapTooltip" }

local KIND = {
	final = { "Final Boss", A.C.gold },
	boss = { "Boss", A.C.bad },
	guardian = { "Guardian", A.C.violet },
	elite = { "Elite", A.C.gold },
}

local function TintEdge(tip)
	local line = getglobal(tip:GetName() .. "TextLeft1")
	local r, g, b = 1, 1, 1
	if line and line.GetTextColor then
		r, g, b = line:GetTextColor()
	end
	if r and (r < 0.9 or g < 0.9 or b < 0.9) then
		A.BorderColor(tip.edge, { r, g, b }, 0.95)
	else
		A.BorderColor(tip.edge, C.edge, 0.9)
	end
end

local function SkinTooltips()
	for i = 1, table.getn(TIPS) do
		local tip = getglobal(TIPS[i])
		if tip then
			A.SkinFrame(tip, { alpha = 0.94, bracket = 5 })
			-- re-tint on every Show: a tooltip already up moves on to the next item without hiding
			local show = tip.Show
			tip.Show = function(self)
				show(self)
				TintEdge(self)
			end
		end
	end
	if GameTooltipStatusBar then
		GameTooltipStatusBar:SetStatusBarTexture(A.MEDIA .. "bar")
		GameTooltipStatusBar:SetHeight(5)
	end
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	ev:SetScript("OnEvent", function()
		local kind = AZS_UnitKind and AZS_UnitKind("mouseover")
		local k = kind and KIND[kind]
		if k and GameTooltip:IsShown() then
			GameTooltip:AddLine(k[1], k[2][1], k[2][2], k[2][3])
			GameTooltip:Show()
		end
	end)
end

------------------------------------------------------------------------
-- Dialogs and menus
------------------------------------------------------------------------

local function SkinPopups()
	for i = 1, 4 do
		local p = getglobal("StaticPopup" .. i)
		if p then
			A.SkinFrame(p, { alpha = 0.96, bracket = 8 })
			A.SkinButton(getglobal("StaticPopup" .. i .. "Button1"))
			A.SkinButton(getglobal("StaticPopup" .. i .. "Button2"))
		end
	end
	if GameMenuFrame then
		A.StripTextures(GameMenuFrame)
		A.SkinFrame(GameMenuFrame, { alpha = 0.96, bracket = 9 })
		local kids = { GameMenuFrame:GetChildren() }
		for i = 1, table.getn(kids) do
			if kids[i]:GetObjectType() == "Button" then
				A.SkinButton(kids[i])
			end
		end
	end
	for _, name in ipairs({ "DropDownList1Backdrop", "DropDownList2Backdrop", "DropDownList3Backdrop",
		"ChatMenu", "EmoteMenu", "LanguageMenu", "VoiceMacroMenu" }) do
		local f = getglobal(name)
		if f then
			A.SkinFrame(f, { alpha = 0.96, bracket = 5, noGlint = true })
		end
	end
end

A.OnInit(function()
	if not A.On("skin") then
		return
	end
	SkinTooltips()
	SkinPopups()
end)
