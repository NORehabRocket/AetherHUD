-- AetherHUD chat: the stock chat windows in Aion's dress. A glass panel behind the main
-- window, flat tabs with a gold underline on the open one, a glass input line, Roboto text,
-- no arrow buttons (the mouse wheel scrolls; Shift jumps to the top or bottom) and old
-- lines fading after a while.

local A = AetherHUD
local C = A.C

local tabs = {}

local function Wheel()
	if arg1 > 0 then
		if IsShiftKeyDown() then
			this:ScrollToTop()
		else
			this:ScrollUp()
		end
	elseif IsShiftKeyDown() then
		this:ScrollToBottom()
	else
		this:ScrollDown()
	end
end

local function StyleWindow(i)
	local chat = getglobal("ChatFrame" .. i)
	if not chat then
		return
	end
	A.Kill(getglobal("ChatFrame" .. i .. "UpButton"))
	A.Kill(getglobal("ChatFrame" .. i .. "DownButton"))
	A.Kill(getglobal("ChatFrame" .. i .. "BottomButton"))
	chat:EnableMouseWheel(true)
	chat:SetScript("OnMouseWheel", Wheel)
	local _, size = chat:GetFont()
	chat:SetFont(A.FONT, size or 13, "")
	chat:SetShadowColor(0, 0, 0, 1)
	chat:SetShadowOffset(1, -1)
	chat:SetFading(true)
	chat:SetTimeVisible(25)
	chat:SetFadeDuration(3)

	local tab = getglobal("ChatFrame" .. i .. "Tab")
	if tab then
		A.StripTextures(tab)
		for _, part in ipairs({ "Left", "Middle", "Right" }) do
			local t = getglobal("ChatFrame" .. i .. "Tab" .. part)
			if t then
				t:SetAlpha(0)
			end
		end
		local text = getglobal("ChatFrame" .. i .. "TabText")
		if text then
			text:SetFont(A.FONT_TITLE, 10, "OUTLINE")
		end
		local mark = A.Tex(tab, "OVERLAY", A.MEDIA .. "line")
		mark:SetBlendMode("ADD")
		mark:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 6, 2)
		mark:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -6, 2)
		mark:SetHeight(3)
		mark:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
		mark:Hide()
		tabs[i] = { chat = chat, text = text, mark = mark }
	end
end

-- Which window is open in the dock: its tab gold and underlined, the others steel.
local function UpdateTabs()
	local open = SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME
	for i, t in pairs(tabs) do
		local on = t.chat == open
		A.Show(t.mark, on)
		if t.text then
			A.SetTextColor(t.text, on and C.gold or C.steel)
		end
	end
end

local function StyleInput()
	local box = ChatFrameEditBox
	if not box then
		return
	end
	A.StripTextures(box)
	A.Dress(box, { alpha = 0.92, bracket = 5, noGlint = true })
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", ChatFrame1, "BOTTOMLEFT", -4, -8)
	box:SetPoint("TOPRIGHT", ChatFrame1, "BOTTOMRIGHT", 4, -8)
	box:SetHeight(22)
	if box.SetTextInsets then
		box:SetTextInsets(8, 8, 0, 0)
	end
	box:SetFont(A.FONT, 13, "")
	local header = ChatFrameEditBoxHeader
	if header then
		header:SetFont(A.FONT, 13, "")
		header:ClearAllPoints()
		header:SetPoint("LEFT", box, "LEFT", 8, 0)
	end
	-- the hairline lights up while you type
	local orig = box:GetScript("OnShow")
	box:SetScript("OnShow", function()
		if orig then
			orig()
		end
		A.BorderColor(this.edge, C.aether, 1)
	end)
end

local function Init()
	if not A.On("chat") then
		return
	end
	for i = 1, (NUM_CHAT_WINDOWS or 7) do
		StyleWindow(i)
	end
	A.Kill(ChatFrameMenuButton)
	StyleInput()

	-- the stock window backgrounds stay off (the game fades one in on mouse-over)
	DEFAULT_CHATFRAME_ALPHA = 0
	for i = 1, (NUM_CHAT_WINDOWS or 7) do
		local chat = getglobal("ChatFrame" .. i)
		if chat and FCF_SetWindowAlpha then
			pcall(FCF_SetWindowAlpha, chat, 0)
		end
	end

	-- our glass behind the main window, a little larger than the text area
	local back = CreateFrame("Frame", "AetherHUDChatBack", ChatFrame1)
	back:SetFrameLevel(math.max(0, ChatFrame1:GetFrameLevel() - 1))
	back:SetPoint("TOPLEFT", ChatFrame1, "TOPLEFT", -6, 6)
	back:SetPoint("BOTTOMRIGHT", ChatFrame1, "BOTTOMRIGHT", 6, -4)
	A.Dress(back, { alpha = 0.42, bracket = 8 })

	UpdateTabs()
	A.Every(0.25, UpdateTabs)
end

A.OnInit(Init)
