-- AbsoluteUI: classic talents window (PlayerTalentFrame, Blizzard_TalentUI).
--
-- One tree at a time in a scroll frame over the class art, a tab per tree
-- below the window. Talent buttons become square tiles with borders
-- colored by state, read from the slot color Blizzard sets on every update
-- (green while points can go in, gold when maxed).

local _, NS = ...

local M = NS:NewModule("Talents", { setting = "spellBook", addon = "Blizzard_TalentUI", flavor = "classic" })

local NUM_TALENTS = 40
local NUM_TREE_TABS = 4 -- the fourth is for glyphs, hidden in TBC
local NUM_SPEC_TABS = 3

-- The window inside Blizzard's 384x512 frame: { left, top, right, bottom }.
local WINDOW_INSET = { 10, 12, 32, 76 }
-- The visible part of a tree tab (CharacterFrameTabButtonTemplate).
local TAB_INSET = { 8, 8, 6, 6 }

local NODE_HOVER = { 1, 1, 1, 0.15 }
local NODE_PUSHED = { 1, 1, 1, 0.25 }

local ART = {
	"PlayerTalentFrameTopLeft", "PlayerTalentFrameTopRight", "PlayerTalentFrameBottomLeft",
	"PlayerTalentFrameBottomRight", "PlayerTalentFrameScrollFrameBackgroundTop",
	"PlayerTalentFrameScrollFrameBackgroundBottom", "PlayerTalentFramePointsLeft",
	"PlayerTalentFramePointsMiddle", "PlayerTalentFramePointsRight",
	"PlayerTalentFramePreviewBarButtonBorder", "PlayerTalentFramePreviewBarFillerButtonBackgroundLeft",
	"PlayerTalentFramePreviewBarFillerButtonBackgroundRight",
	"PlayerTalentFramePreviewBarFillerButtonBackgroundMiddle",
}
local BUTTONS = {
	"PlayerTalentFrameCancelButton", "PlayerTalentFrameActivateButton",
	"PlayerTalentFrameResetButton", "PlayerTalentFrameLearnButton",
}
local TEXTS = { "PlayerTalentFrameSpentPointsText", "PlayerTalentFrameStatusText", "PlayerTalentFrameTalentPointsText" }

---------------------------------------------------------------------------
-- Talent buttons ("PlayerTalentFrameTalent1"...)
---------------------------------------------------------------------------

local nodes = {} -- [button] = icon tile

-- The slot is tinted green, gold or grey (TalentFrame_Update).
local function StateColor(slot)
	local r, g, b = slot:GetVertexColor()
	if g > 0.9 and r < 0.5 then
		return NS.color.friendly
	elseif r > 0.9 and g > 0.7 and b < 0.3 then
		return NS.color.accent
	end
	return NS.color.border
end

local function SyncNodes(talentFrame)
	if talentFrame ~= PlayerTalentFrame then return end
	for button, tile in pairs(nodes) do
		local slot = _G[button:GetName() .. "Slot"]
		if slot then
			local c = StateColor(slot)
			tile:SetBorderColor(c[1], c[2], c[3])
		end
	end
end

local function SkinNode(button)
	local name = button:GetName()
	local icon = button.icon
	if not icon then return end
	local tile = NS:CreateTile(button)
	nodes[button] = tile
	tile.icon = icon
	tile:Layout()
	NS:CropIcon(icon)

	NS:HideTextures(_G[name .. "Slot"], _G[name .. "RankBorder"], button:GetNormalTexture())
	NS:SetFlat(button:GetHighlightTexture(), NODE_HOVER, tile.fill)
	NS:SetFlat(button:GetPushedTexture(), NODE_PUSHED, tile.fill)

	-- Ranks in the corner, outlined; Blizzard colors them by state.
	local rank = _G[name .. "Rank"]
	if rank then
		NS:RestyleFont(rank, 12, "RIGHT", true)
		rank:ClearAllPoints()
		rank:SetPoint("BOTTOMRIGHT", tile.fill, "BOTTOMRIGHT", 0, 1)
	end
end

---------------------------------------------------------------------------
-- Spec tabs (dual specs, the pet's talents): icons in tiles, the selected
-- one with an accent border.
---------------------------------------------------------------------------

local specTabs = {} -- [tab] = tile

local function SyncSpecTabs()
	for tab, tile in pairs(specTabs) do
		local icon = tab:GetNormalTexture()
		if icon then
			tile.icon = icon
			NS:CropIcon(icon)
		end
		tile:Layout()
		tile:SetBorderColor(unpack(tab:GetChecked() and NS.color.accent or NS.color.border))
	end
end

local function SkinSpecTab(tab)
	NS:HideTextures(_G[tab:GetName() .. "Background"], tab:GetCheckedTexture())
	specTabs[tab] = NS:CreateTile(tab)
	NS:SetFlat(tab:GetHighlightTexture(), NODE_HOVER, specTabs[tab].fill)
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Init()
	local frame = PlayerTalentFrame
	if not frame or not PlayerTalentFrameTalent1 then
		NS:Missing("PlayerTalentFrame")
		return
	end

	for _, name in ipairs(ART) do
		NS:Kill(_G[name])
	end
	NS:SkinClassicWindow(frame, WINDOW_INSET, PlayerTalentFrameTitleText, PlayerTalentFrameCloseButton,
		PlayerTalentFramePortrait)

	-- The class art keeps its place, framed like a tile.
	local scroll = PlayerTalentFrameScrollFrame
	if scroll then
		local box = NS:CreateBox(frame, frame, scroll, NS.color.tile)
		box.shadow = NS:CreateShadow(frame, box.base)
		NS:SkinSliderScrollBar(scroll.ScrollBar)
	end

	for _, name in ipairs(BUTTONS) do
		NS:SkinPanelButton(_G[name])
	end
	for _, name in ipairs(TEXTS) do
		if _G[name] then NS:RestyleFont(_G[name], 12, _G[name]:GetJustifyH()) end
	end

	for i = 1, NUM_TALENTS do
		local button = _G["PlayerTalentFrameTalent" .. i]
		if button then SkinNode(button) end
	end
	NS:Hook(nil, "TalentFrame_Update", SyncNodes)
	SyncNodes(frame)

	for i = 1, NUM_TREE_TABS do
		NS:SkinClassicTab(_G["PlayerTalentFrameTab" .. i], TAB_INSET)
	end
	for i = 1, NUM_SPEC_TABS do
		local tab = _G["PlayerSpecTab" .. i]
		if tab then SkinSpecTab(tab) end
	end
	NS:Hook(nil, "PlayerTalentFrame_Update", SyncSpecTabs)
	SyncSpecTabs()
end
