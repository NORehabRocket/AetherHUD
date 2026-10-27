-- The rest of the stock 1.12 interface AetherHUD re-dresses or replaces: chat windows,
-- the minimap, bags and equipment, tooltips, dialogs, the game menu, party and pet
-- frames, error and zone text. Loaded after wowmock.lua.

local M = MOCK.methods
local new = MOCK.new

local function inherit(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = v
		end
	end
end

------------------------------------------------------------------------
-- More widget types
------------------------------------------------------------------------

local FI = {} -- FontInstance, shared by edit boxes and message frames
function FI:SetFont(path, size, flags)
	assert(type(path) == "string" and type(size) == "number", "SetFont")
	self.__font = { path, size, flags }
end
function FI:GetFont() if self.__font then return self.__font[1], self.__font[2], self.__font[3] end return "Fonts\\ARIALN.TTF", 14 end
function FI:SetShadowColor() end
function FI:SetShadowOffset() end
function FI:SetJustifyH() end

inherit(M.EditBox, FI)
inherit(M.EditBox, M.Frame)
function M.EditBox:SetTextInsets() end
function M.EditBox:Insert(s) self.__inserted = (self.__inserted or "") .. s end
function M.EditBox:SetText(s) self.__text = s end
function M.EditBox:GetText() return self.__text end

inherit(M.ScrollingMessageFrame, FI)
inherit(M.ScrollingMessageFrame, M.Frame)
function M.ScrollingMessageFrame:AddMessage(msg) table.insert(MOCK.chat, msg) end
function M.ScrollingMessageFrame:ScrollUp() self.__scroll = (self.__scroll or 0) + 1 end
function M.ScrollingMessageFrame:ScrollDown() self.__scroll = (self.__scroll or 0) - 1 end
function M.ScrollingMessageFrame:ScrollToTop() self.__scroll = 99 end
function M.ScrollingMessageFrame:ScrollToBottom() self.__scroll = 0 end
function M.ScrollingMessageFrame:SetFading() end
function M.ScrollingMessageFrame:SetTimeVisible() end
function M.ScrollingMessageFrame:SetFadeDuration() end

inherit(M.MessageFrame, FI)
inherit(M.MessageFrame, M.Frame)
function M.MessageFrame:AddMessage(msg) table.insert(MOCK.stockMessages, msg) end
MOCK.stockMessages = {}

inherit(M.Minimap, M.Frame)
function M.Minimap:SetZoom(z) self.__zoom = z end
function M.Minimap:GetZoom() return self.__zoom or 0 end
function M.Minimap:GetZoomLevels() return 6 end

-- buttons' state textures, frames' top-level flag, font string colours
local B = M.Button
function B:SetNormalTexture(t) self.__normal = t end
function B:SetPushedTexture(t) self.__pushed = t end
function B:SetHighlightTexture(t) self.__highlight = t end
function B:SetDisabledTexture(t) self.__disabled = t end
function B:GetPushedTexture() return nil end
function B:GetHighlightTexture() return nil end
function B:GetDisabledTexture() return nil end
function B:GetText() return self.__text end
function M.Frame:SetToplevel() end
function M.FontString:GetTextColor()
	local c = self.__tcolor or { 1, 1, 1 }
	return c[1], c[2], c[3], 1
end
for _, k in ipairs({ "Frame", "Button", "GameTooltip", "StatusBar", "EditBox", "ScrollingMessageFrame", "Minimap", "MessageFrame" }) do
	inherit(M[k], M.Frame)
	M[k].SetToplevel = M.Frame.SetToplevel
end

local GT = M.GameTooltip
function GT:SetBagItem(bag, slot) assert(type(bag) == "number" and type(slot) == "number") return 1 end
function GT:SetInventoryItem(unit, id) assert(type(id) == "number") return MOCK.equip[id] and 1 or nil end
function GameTooltip_SetDefaultAnchor(tip, owner) tip:SetOwner(owner, "ANCHOR_NONE") end

------------------------------------------------------------------------
-- Stock frames
------------------------------------------------------------------------

local function F(kind, name, parent)
	return new(kind, name, parent or UIParent)
end

-- chat windows: ChatFrame1 already exists (DEFAULT_CHAT_FRAME); give it the message-frame
-- methods and build 2-7 and their tabs, buttons and the input line
for k, v in pairs(M.ScrollingMessageFrame) do
	if k ~= "AddMessage" then
		ChatFrame1[k] = v
	end
end
ChatFrame1.__w, ChatFrame1.__h = 430, 120
ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 95)
NUM_CHAT_WINDOWS = 7
for i = 1, 7 do
	local chat = i == 1 and ChatFrame1 or F("ScrollingMessageFrame", "ChatFrame" .. i)
	if i > 1 then
		chat:Hide()
	end
	local tab = F("Button", "ChatFrame" .. i .. "Tab")
	tab.__w, tab.__h = 70, 24
	tab:SetPoint("BOTTOMLEFT", chat, "TOPLEFT", (i - 1) * 72, 2)
	for _, part in ipairs({ "Left", "Middle", "Right" }) do
		local t = tab:CreateTexture("ChatFrame" .. i .. "Tab" .. part, "BACKGROUND")
		t:SetTexture("Interface\\ChatFrame\\ChatFrameTab")
	end
	local text = tab:CreateFontString("ChatFrame" .. i .. "TabText", "OVERLAY")
	text:SetFont("Fonts\\FRIZQT__.TTF", 10)
	text:SetText(i == 1 and "General" or i == 2 and "Combat Log" or ("Chat " .. i))
	text:SetPoint("CENTER", tab, "CENTER", 0, 0)
	if i > 2 then
		tab:Hide()
	end
	for _, b in ipairs({ "UpButton", "DownButton", "BottomButton" }) do
		F("Button", "ChatFrame" .. i .. b, chat)
	end
end
F("Button", "ChatFrameMenuButton")
F("EditBox", "ChatFrameEditBox")
ChatFrameEditBox:CreateTexture("ChatFrameEditBoxLeft", "BACKGROUND"):SetTexture("Interface\\ChatFrame\\UI-ChatInputBorder-Left")
ChatFrameEditBoxHeader = ChatFrameEditBox:CreateFontString("ChatFrameEditBoxHeader", "OVERLAY")
ChatFrameEditBox:Hide()
SELECTED_DOCK_FRAME = ChatFrame1
DEFAULT_CHATFRAME_ALPHA = 0.25
function FCF_SetWindowAlpha(frame, a) frame.__bgAlpha = a end
function FCF_SetWindowColor() end

-- minimap
MinimapCluster = F("Frame", "MinimapCluster")
MinimapCluster.__w, MinimapCluster.__h = 192, 192
MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
Minimap = new("Minimap", "Minimap", MinimapCluster)
Minimap.__w, Minimap.__h = 140, 140
Minimap:SetPoint("CENTER", MinimapCluster, "TOP", 9, -92)
MinimapCluster:CreateTexture("MinimapBorder", "ARTWORK"):SetTexture("Interface\\Minimap\\UI-Minimap-Border")
MinimapCluster:CreateTexture("MinimapBorderTop", "ARTWORK"):SetTexture("Interface\\Minimap\\UI-Minimap-Border")
MinimapCluster:CreateTexture("MinimapNorthTag", "ARTWORK")
for _, n in ipairs({ "MinimapZoomIn", "MinimapZoomOut", "MiniMapWorldMapButton", "GameTimeFrame",
	"MinimapToggleButton", "MinimapZoneTextButton" }) do
	F("Button", n, MinimapCluster)
end
MinimapZoneText = MinimapZoneTextButton:CreateFontString("MinimapZoneText", "OVERLAY")
for _, n in ipairs({ "MiniMapTrackingFrame", "MiniMapMailFrame", "MiniMapBattlefieldFrame" }) do
	local fr = F("Frame", n, MinimapCluster)
	fr.__w, fr.__h = 32, 32
	fr:CreateTexture(n .. "Icon", "ARTWORK"):SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
end
MiniMapMailFrame:Hide()
MiniMapBattlefieldFrame:Hide()
MiniMapTrackingFrame:CreateTexture("MiniMapTrackingBorder", "OVERLAY")
MiniMapMailFrame:CreateTexture("MiniMapMailBorder", "OVERLAY")
WorldMapFrame = F("Frame", "WorldMapFrame")
WorldMapFrame:Hide()
function GetMinimapZoneText() return "Goldshire" end
function GetZoneText() return "Elwynn Forest" end
function GetPlayerMapPosition() return 0.42, 0.65 end
function SetMapToCurrentZone() MOCK.mapSet = true end
date = os.date

-- error / zone text
UIErrorsFrame = F("MessageFrame", "UIErrorsFrame")
RaidWarningFrame = F("MessageFrame", "RaidWarningFrame")
F("Frame", "ZoneTextFrame")
F("Frame", "SubZoneTextFrame")

-- tooltips, dialogs, menus
GameTooltipTextLeft1 = GameTooltip:CreateFontString("GameTooltipTextLeft1", "ARTWORK")
GameTooltipStatusBar = new("StatusBar", "GameTooltipStatusBar", GameTooltip)
for _, n in ipairs({ "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "WorldMapTooltip" }) do
	local t = F("GameTooltip", n)
	t:CreateFontString(n .. "TextLeft1", "ARTWORK")
	t:Hide()
end
GameTooltip:Hide()
for i = 1, 4 do
	local p = F("Frame", "StaticPopup" .. i)
	F("Button", "StaticPopup" .. i .. "Button1", p)
	F("Button", "StaticPopup" .. i .. "Button2", p)
	p:Hide()
end
GameMenuFrame = F("Frame", "GameMenuFrame")
GameMenuFrame:CreateTexture("GameMenuFrameHeader", "ARTWORK"):SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
for _, n in ipairs({ "GameMenuButtonOptions", "GameMenuButtonKeybindings", "GameMenuButtonLogout", "GameMenuButtonContinue" }) do
	F("Button", n, GameMenuFrame)
end
GameMenuFrame:Hide()
for _, n in ipairs({ "DropDownList1Backdrop", "DropDownList2Backdrop", "ChatMenu" }) do
	F("Frame", n)
end
function ShowUIPanel(f) f:Show() end
function HideUIPanel(f) f:Hide() end

-- unit frames the party module replaces
for i = 1, 4 do
	F("Frame", "PartyMemberFrame" .. i)
end
F("Frame", "PetFrame", PlayerFrame)
function GetNumPartyMembers() return MOCK.party and table.getn(MOCK.party) or 0 end
function UnitIsConnected(u) local d = MOCK.party and string.find(u, "party") and MOCK.party[tonumber(string.sub(u, 6))] return not (d and d.offline) end
function UnitIsGhost() return nil end
function TargetUnit(u) MOCK.targetUnit = u end

------------------------------------------------------------------------
-- Bags and equipment
------------------------------------------------------------------------

MOCK.bagSizes = { [0] = 16, [1] = 10, [2] = 0, [3] = 0, [4] = 0 }
MOCK.bags = { [0] = {}, [1] = {} }
MOCK.equip = {}
MOCK.money = 123456
MOCK.cursor = false

function GetContainerNumSlots(bag) return MOCK.bagSizes[bag] or 0 end
function GetContainerItemInfo(bag, slot)
	local it = MOCK.bags[bag] and MOCK.bags[bag][slot]
	if it then
		return it.tex, it.count or 1, it.locked, it.quality
	end
end
function GetContainerItemLink(bag, slot)
	local it = MOCK.bags[bag] and MOCK.bags[bag][slot]
	return it and it.link
end
function GetContainerItemCooldown(bag, slot)
	local it = MOCK.bags[bag] and MOCK.bags[bag][slot]
	if it and it.cd then
		return it.cd[1], it.cd[2], 1
	end
	return 0, 0, 1
end
function PickupContainerItem(bag, slot) MOCK.picked = bag .. ":" .. slot end
function UseContainerItem(bag, slot) MOCK.used = bag .. ":" .. slot end
function ContainerIDToInventoryID(bag) return 19 + bag end
function PutItemInBag(id) MOCK.putBag = id end
function PickupBagFromSlot(id) MOCK.pickedBag = id end
function CursorHasItem() return MOCK.cursor end
function GetMoney() return MOCK.money end
function IsShiftKeyDown() return MOCK.shift end
for i = 1, 12 do
	F("Frame", "ContainerFrame" .. i):Hide()
end
-- the stock bag calls, kept so we can tell when they still get through
function ToggleBackpack() MOCK.stockBags = "ToggleBackpack" end
function OpenBackpack() MOCK.stockBags = "OpenBackpack" end
function CloseBackpack() MOCK.stockBags = "CloseBackpack" end
function OpenAllBags() MOCK.stockBags = "OpenAllBags" end
function CloseAllBags() MOCK.stockBags = "CloseAllBags" end
function ToggleBag(id) MOCK.stockBags = "ToggleBag" .. id end
function OpenBag(id) MOCK.stockBags = "OpenBag" .. id end
function CloseBag(id) MOCK.stockBags = "CloseBag" .. id end
function IsBagOpen(id) return nil end

local SLOT_IDS = {
	HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, ShirtSlot = 4, ChestSlot = 5, WaistSlot = 6, LegsSlot = 7,
	FeetSlot = 8, WristSlot = 9, HandsSlot = 10, Finger0Slot = 11, Finger1Slot = 12, Trinket0Slot = 13,
	Trinket1Slot = 14, BackSlot = 15, MainHandSlot = 16, SecondaryHandSlot = 17, RangedSlot = 18, TabardSlot = 19,
}
function GetInventorySlotInfo(name)
	local id = SLOT_IDS[name]
	if not id then
		error("Invalid inventory slot " .. tostring(name))
	end
	return id, "Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. name
end
-- another hero's gear: MOCK.inspected[name][id], known only once NotifyInspect asked for it
local function Gear(unit)
	if unit == "player" then
		return MOCK.equip
	end
	local name = UnitName(unit)
	return (name and MOCK.notified == name and MOCK.inspected and MOCK.inspected[name]) or {}
end
function GetInventoryItemTexture(unit, id) local e = Gear(unit)[id] return e and e.tex end
function GetInventoryItemLink(unit, id) local e = Gear(unit)[id] return e and e.link end
function GetInventoryItemCooldown() return 0, 0, 1 end
function PickupInventoryItem(id) MOCK.pickedInv = id end
function UseInventoryItem(id) MOCK.usedInv = id end
HEADSLOT = "Head"

CharacterFrame = F("Frame", "CharacterFrame")
CharacterFrame:Hide()
function ToggleCharacter(tab) MOCK.stockCharacter = tab end

function GetItemInfo(item)
	local _, _, id = string.find(item or "", "item:(%d+)")
	if not id then
		return nil
	end
	return "Item " .. id, item, 4, 1, "Armor", "Cloth", 1, "INVTYPE_NECK", "Interface\\Icons\\Mock_Item" .. id
end

-- the game's own stats parser (from its PaperDollFrame patch; AZS_ApiOnEvent calls it)
function AZS_Parse(msg)
	local t = {}
	local pos = 1
	while true do
		local s, e, k, v = string.find(msg, "(%w+)=([^;]*)", pos)
		if not s then
			break
		end
		t[k] = tonumber(v) or 0
		pos = e + 1
	end
	return t
end

LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
LOOT_ITEM_CREATED_SELF = "You create: %s."

------------------------------------------------------------------------
-- Unit menus (UIDropDownMenu + UnitPopup) and inspecting
------------------------------------------------------------------------

RAID_TARGET_ICON = "Raid Target Icon"
UIDROPDOWNMENU_OPEN_MENU = nil
UIDROPDOWNMENU_INIT_MENU = nil
DropDownList1 = F("Button", "DropDownList1")
DropDownList1.__w, DropDownList1.__h = 120, 160
DropDownList1:Hide()
function UIDropDownMenu_Initialize(frame, fn, mode)
	assert(frame:GetName(), "a dropdown needs a name")
	frame.initialize, frame.displayMode = fn, mode
	UIDROPDOWNMENU_INIT_MENU = frame:GetName()
	fn(1)
end
function ToggleDropDownMenu(level, value, frame, anchor, x, y)
	assert(type(anchor) == "string" and getglobal(anchor), "ToggleDropDownMenu: anchor by frame name")
	if DropDownList1:IsShown() and UIDROPDOWNMENU_OPEN_MENU == frame:GetName() then
		DropDownList1:Hide()
		return
	end
	DropDownList1:Hide()
	UIDROPDOWNMENU_OPEN_MENU = frame:GetName()
	MOCK.menu = nil
	UIDropDownMenu_Initialize(frame, frame.initialize, nil, level)
	DropDownList1:ClearAllPoints()
	DropDownList1:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
	DropDownList1:Show()
end
function CloseDropDownMenus() DropDownList1:Hide() end
function UnitPopup_ShowMenu(dropdown, which, unit, name)
	assert(getglobal(UIDROPDOWNMENU_INIT_MENU) == dropdown, "UnitPopup needs the dropdown being initialised")
	dropdown.which, dropdown.unit = which, unit
	MOCK.menu = { which = which, unit = unit, name = name }
end
function GetCursorPosition() return 640, 120 end
function UnitInParty(u) return string.find(u, "^party%d") and 1 or nil end
function CanInspect(u) return UnitIsPlayer(u) and not UnitIsUnit(u, "player") and 1 or nil end
function NotifyInspect(u) MOCK.notified = UnitName(u) end
function ClearInspectPlayer() MOCK.notified = nil end
function InspectUnit(u) MOCK.stockInspect = u end
function GetGuildInfo(u) local n = UnitName(u) return MOCK.guilds and MOCK.guilds[n], "Officer", 1 end
function IsControlKeyDown() return MOCK.ctrl end
function DressUpItemLink(link) MOCK.dressedUp = link end
BenillaOptionsFrame = F("Frame", "BenillaOptionsFrame")
BenillaOptionsFrame:Hide()
