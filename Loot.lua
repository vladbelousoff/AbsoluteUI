-- AbsoluteUI: loot window.
--
-- Entries come from a scroll box and are styled as it initializes them,
-- right after Blizzard sets their contents.

local _, NS = ...

local M = NS:NewModule("Loot", { setting = "lootFrame", flavor = "modern" })

local MARGIN = NS.panelStyle.margin
local HEADER_HEIGHT = NS.panelStyle.header
local VIEW_PADDING = 6 -- Blizzard's scroll view padding
local SCROLLBAR_WIDTH = 16

local CARD_HOVER = { 1, 1, 1, 0.08 }
local CARD_PUSHED = { 1, 1, 1, 0.15 }
local ICON_HOVER = { 1, 1, 1, 0.15 }
local ICON_PUSHED = { 1, 1, 1, 0.25 }

local cards = {}

---------------------------------------------------------------------------
-- Entries
---------------------------------------------------------------------------

local function SkinCard(card)
	local skin = { tile = NS:CreateTile(card, 0, 0, NS.color.tile, true) }
	cards[card] = skin

	for _, key in ipairs({ "NameFrame", "BorderFrame", "QualityStripe" }) do
		NS:Kill(card[key])
	end
	NS:SetFlat(card.HighlightNameFrame, CARD_HOVER, skin.tile.fill)
	NS:SetFlat(card.PushedNameFrame, CARD_PUSHED, skin.tile.fill)

	local item = card.Item
	skin.iconTile = NS:CreateTile(item, 0, 0, NS.color.panel, true)
	skin.iconTile.icon = item.icon
	skin.iconTile:Layout()
	NS:CropIcon(item.icon)
	NS:Kill(item.IconBorder)
	NS:HideTextures(item:GetNormalTexture())
	NS:SetFlat(item:GetPushedTexture(), ICON_PUSHED, skin.iconTile.fill)
	NS:SetFlat(item:GetHighlightTexture(), ICON_HOVER, skin.iconTile.fill)
	if item.Count then
		NS:StyleFont(item.Count, 12, "RIGHT", true)
	end

	if card.Text then
		NS:StyleFont(card.Text, 12, card.Text:GetJustifyH())
	end
	if card.QualityText then
		NS:StyleFont(card.QualityText, 9, "RIGHT", true)
	end
	return skin
end

-- Runs on every (re)initialization, since entries are recycled.
local function OnCardInitialized(_, card)
	if not card or not card.Item or not card.Item.icon then return end
	local skin = cards[card] or SkinCard(card)
	local quality = card.GetQuality and card:GetQuality()
	local r, g, b = NS:QualityColor(quality)
	skin.iconTile:SetBorderColor(r, g, b)
	if card.Text and not card.ignoreColorOverrides then
		card.Text:SetTextColor(r, g, b)
	end
	if card.QualityText then
		card.QualityText:SetTextColor(r, g, b)
	end
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

-- Blizzard's sizing is tuned for its own frame art.
local function Resize(frame)
	local scrollBox = frame.ScrollBox
	local contentTop = MARGIN + HEADER_HEIGHT + MARGIN
	local scrollTop = contentTop - VIEW_PADDING
	local height = scrollTop + frame:CalculateElementsHeight() + 2 * VIEW_PADDING
	local maxHeight = frame.panelMaxHeight or height
	local scrolls = height > maxHeight

	frame:SetHeight(math.min(height, maxHeight))
	frame:SetWidth(frame.panelWidth + (scrolls and SCROLLBAR_WIDTH or 0))

	scrollBox:ClearAllPoints()
	scrollBox:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN - VIEW_PADDING, -scrollTop)
	scrollBox:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", MARGIN - VIEW_PADDING, 0)
	scrollBox:SetWidth(frame.panelWidth - 2 * (MARGIN - VIEW_PADDING))

	local scrollBar = frame.ScrollBar
	if scrollBar then
		scrollBar:ClearAllPoints()
		scrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -MARGIN, -contentTop)
		scrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -MARGIN, MARGIN)
		scrollBar:SetShown(scrolls)
	end
end

function M:SkinPanel(frame)
	NS:SkinPanelFrame(frame)

	local scrollBox = frame.ScrollBox
	for _, getter in ipairs({ "GetUpperShadowTexture", "GetLowerShadowTexture" }) do
		local shadow = scrollBox[getter] and scrollBox[getter](scrollBox)
		if shadow then shadow:SetAlpha(0) end
	end

	if frame.Resize and frame.CalculateElementsHeight and frame.panelWidth then
		NS:Hook(frame, "Resize", Resize)
	end
end

function M:Init()
	local frame = LootFrame
	if not frame or not frame.ScrollBox then
		NS:Missing("LootFrame")
		return
	end

	self:SkinPanel(frame)

	if ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
		ScrollUtil.AddInitializedFrameCallback(frame.ScrollBox, OnCardInitialized, M, true)
	elseif ScrollBoxListMixin and ScrollBoxListMixin.Event then
		frame.ScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, OnCardInitialized, M)
	else
		NS:Missing("LootFrame scroll callbacks")
	end
end
