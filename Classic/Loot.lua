-- AbsoluteUI: classic loot window.
--
-- Four fixed loot buttons ("LootButton1"...) with paging. Each becomes a
-- card: the icon framed in its quality color, the name beside it. The
-- buttons only loot through LootSlot, so moving them is safe in combat.

local _, NS = ...

local M = NS:NewModule("Loot", { setting = "lootFrame", flavor = "classic" })

local MARGIN = NS.panelStyle.margin
local HEADER_HEIGHT = NS.panelStyle.header
local NUM_BUTTONS = 4
local CARD_GAP = 4
local PAGE_BUTTON = 20

local CARD_HOVER = { 1, 1, 1, 0.08 }
local ICON_PUSHED = { 1, 1, 1, 0.25 }

local cards = {} -- [button] = { tile, iconBox }

---------------------------------------------------------------------------
-- Loot buttons
---------------------------------------------------------------------------

-- The icon fills the card's left end; its box shares the card's border.
local function LayoutIcon(button)
	local px = NS:Px(button)
	local icon = button.icon
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", button, "TOPLEFT", px, -px)
	icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -px, px)
end

-- The card spans from the icon to the window's right margin; the button's
-- hit rect already reaches past its text.
local function SkinButton(button, frame)
	local name = button:GetName()
	local rect = button:CreateTexture(nil, "BACKGROUND")
	rect:SetPoint("TOPLEFT", button, "TOPLEFT")
	rect:SetPoint("BOTTOM", button, "BOTTOM")
	rect:SetPoint("RIGHT", frame, "RIGHT", -MARGIN, 0)
	local card = { tile = NS:CreateTile(button, 0, 0, NS.color.tile, true) }
	card.tile.anchor = rect
	card.tile:Layout()
	cards[button] = card

	NS:Kill(_G[name .. "NameFrame"])
	NS:HideTextures(button:GetNormalTexture(), button.IconBorder)
	NS:SetFlat(button:GetHighlightTexture(), CARD_HOVER, card.tile.fill)

	local icon = button.icon
	LayoutIcon(button)
	NS:CropIcon(icon)
	card.iconBox = NS:CreateBox(button, button, icon, NS.color.panel)
	NS:SetFlat(button:GetPushedTexture(), ICON_PUSHED, icon)
	if button.Count then
		NS:StyleFont(button.Count, 12, "RIGHT", true)
	end

	local text = _G[name .. "Text"]
	if text then
		NS:RestyleFont(text, 12, "LEFT")
		text:SetWordWrap(true)
		text:ClearAllPoints()
		text:SetPoint("LEFT", button, "RIGHT", 6, 0)
		text:SetPoint("RIGHT", rect, "RIGHT", -6, 0)
	end
end

-- After every update: Blizzard sets the quality and tints locked items red.
local function SyncButton(index)
	local button = _G["LootButton" .. index]
	local card = button and cards[button]
	if not card then return end
	local r, g, b = NS:QualityColor(button.quality)
	card.iconBox.border:SetColor(r, g, b)
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

-- Cards stack under the header; paging buttons sit in the bottom corners.
local function Layout(frame)
	local top = MARGIN + HEADER_HEIGHT + MARGIN
	for i = 1, NUM_BUTTONS do
		local button = _G["LootButton" .. i]
		if button then
			local size = button:GetHeight()
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -(top + (i - 1) * (size + CARD_GAP)))
			LayoutIcon(button)
		end
	end
end

local function SkinPaging(frame)
	local up, down = LootFrameUpButton, LootFrameDownButton
	for _, spec in ipairs({ { up, "up", "BOTTOMLEFT", MARGIN }, { down, "down", "BOTTOMRIGHT", -MARGIN } }) do
		local button = spec[1]
		if button then
			button:SetSize(PAGE_BUTTON, PAGE_BUTTON)
			button:ClearAllPoints()
			button:SetPoint(spec[3], frame, spec[3], spec[4], MARGIN)
			NS:SkinArrowButton(button, spec[2])
		end
	end
	for _, spec in ipairs({ { LootFramePrev, up, "LEFT", "RIGHT", 6 }, { LootFrameNext, down, "RIGHT", "LEFT", -6 } }) do
		local text, button = spec[1], spec[2]
		if text and button then
			NS:StyleFont(text, 12, spec[3])
			text:ClearAllPoints()
			text:SetPoint(spec[3], button, spec[4], spec[5], 0)
		end
	end
end

-- The "Items" label is the window's title.
local function FindTitle(frame)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("FontString") and region:GetText() == ITEMS then
			return region
		end
	end
end

function M:Init()
	local frame = LootFrame
	if not frame or not LootButton1 then
		NS:Missing("LootFrame")
		return
	end

	local header = NS:SkinPanelFrame(frame)
	-- The button frame's inset would draw its marble behind the cards.
	local inset = frame.Inset
	if inset then
		NS:Kill(inset.Bg)
		if inset.NineSlice then inset.NineSlice:SetAlpha(0) end
	end
	local portrait = NS:SkinPanelPortrait(frame, header, LootFramePortraitOverlay)
	if portrait then
		portrait:SetTexCoord(0, 1, 0, 1) -- the skull isn't an icon with a border
	end
	local title = FindTitle(frame)
	if title then
		NS:Adopt(title, header)
		NS:StyleFont(title, 12, "CENTER")
		title:ClearAllPoints()
		title:SetPoint("CENTER", header, "CENTER", 0, 0)
	end

	for i = 1, NUM_BUTTONS do
		local button = _G["LootButton" .. i]
		if button then
			SkinButton(button, frame)
		end
	end
	Layout(frame)
	SkinPaging(frame)

	NS:Hook(nil, "LootFrame_UpdateButton", SyncButton)
	NS:RegisterPixelClient(function() Layout(frame) end)
end
