-- AbsoluteUI: talents page of the spellbook window (SpellBook.lua skins
-- the window itself).
--
-- Talent buttons, tree headers and tabs are pooled; each is styled once as
-- Blizzard hands it out, and buttons are re-colored on every state change.
-- Choice and capstone nodes keep Blizzard's art, since their shapes are
-- what tells them apart.

local _, NS = ...

local M = NS:NewModule("Talents", { setting = "spellBook", addon = "Blizzard_PlayerSpells", flavor = "modern" })

local ACCENT = NS.color.accent
local CONTROL = 20 -- search options button
local NODE_HOVER = { 1, 1, 1, 0.15 }
local TREE_RULE = { 0, 0, 0, 0.6 } -- between the trees, over the class art
local BADGE_W, BADGE_H = 24, 16    -- points spent in a tree

-- Spec tabs: text tiles.
local TAB_STYLE = { insetX = 1, insetY = 4 }

local FRAME_ART = { "Background", "BackgroundBorder", "DividerHorizontalLeft", "DividerHorizontalRight" }
local TREE_DIVIDERS = { "DividerVerticalLeft", "DividerVerticalRight" }

---------------------------------------------------------------------------
-- Talent buttons
---------------------------------------------------------------------------

local nodes = {}       -- [button] = icon tile, or false when left as it is
local stateColors = {} -- [visual state] = border color (others: plain)

-- Same colors as Blizzard's rank text: green while points can go in, gold
-- when maxed, red when a refund isn't allowed.
local function BuildStateColors()
	local states = TalentButtonUtil and TalentButtonUtil.BaseVisualState
	if not states then
		NS:Missing("TalentButtonUtil.BaseVisualState")
		return
	end
	local c = NS.color
	for key, color in pairs({
		Normal = c.friendly, Selectable = c.friendly, Maxed = c.accent,
		RefundInvalid = c.hostile, DisplayError = c.hostile,
	}) do
		if states[key] then
			stateColors[states[key]] = color
		end
	end
end

-- After every state change, which re-sets the border atlases and the
-- sheen and hover alphas.
local function ApplyState(button, visualState)
	local tile = nodes[button]
	if not tile then return end
	NS:HideTextures(button.StateBorder, button.StateBorderHover, button.BorderSheen)
	local color = stateColors[visualState] or NS.color.border
	tile:SetBorderColor(color[1], color[2], color[3])
end

-- Square and circle nodes; choice nodes have a second icon, capstones a
-- divider.
local function IsPlainNode(button)
	return button.Icon and button.StateBorder and not button.Icon2 and not button.Divider
end

local function SkinNode(button)
	if not button or nodes[button] ~= nil then return end
	if not IsPlainNode(button) then
		nodes[button] = false
		return
	end
	local tile = NS:CreateTile(button)
	nodes[button] = tile

	if button.IconMask then
		button.Icon:RemoveMaskTexture(button.IconMask)
	end
	tile.icon = button.Icon
	tile:Layout()
	NS:CropIcon(button.Icon)
	local overlay = button.DisabledOverlay
	if overlay then
		if button.DisabledOverlayMask then
			overlay:RemoveMaskTexture(button.DisabledOverlayMask)
		end
		overlay:ClearAllPoints()
		overlay:SetAllPoints(tile.fill)
	end
	NS:HideTextures(button.Shadow)
	local hover = NS:CreateTexture(button, "HIGHLIGHT", 0, NODE_HOVER)
	hover:SetAllPoints(tile.fill)

	-- Ranks in the corner, outlined instead of Blizzard's four shadow copies.
	if button.SpendText then
		NS:RestyleFont(button.SpendText, 12, "RIGHT", true)
		button.SpendText:ClearAllPoints()
		button.SpendText:SetPoint("BOTTOMRIGHT", tile.fill, "BOTTOMRIGHT", 0, 1)
	end
	for _, shadow in ipairs(button.spendTextShadows or {}) do
		shadow:SetAlpha(0)
	end

	NS:Hook(button, "UpdateStateBorder", ApplyState)
	ApplyState(button, button.visualState)
end

---------------------------------------------------------------------------
-- Tree headers: the tree icon as a tile, points spent in a badge on its
-- corner.
---------------------------------------------------------------------------

local treeHeaders = {}

local function SkinTreeHeader(header)
	if treeHeaders[header] then return end
	treeHeaders[header] = true

	local icon = header.Icon
	if icon then
		local mask = icon.GetMaskTexture and icon:GetMaskTexture(1)
		if mask then
			icon:RemoveMaskTexture(mask)
		end
		NS:CropIcon(icon)
		local box = NS:CreateBox(header, header, icon, NS.color.tile)
		box.shadow = NS:CreateShadow(header, box.base)
	end
	NS:Kill(header.MainRing)
	NS:Kill(header.Divider)

	local text, slot = header.Text, header.TextBackground
	if text and slot then
		NS:HideTextures(slot)
		-- Above the icon, which it overlaps.
		local badge = CreateFrame("Frame", nil, header)
		badge:SetSize(BADGE_W, BADGE_H)
		badge:SetPoint("CENTER", slot, "CENTER")
		badge:SetFrameLevel(header:GetFrameLevel() + 2)
		NS:CreateBox(badge, badge, badge, NS.color.header)
		NS:Adopt(text, badge)
		text:ClearAllPoints()
		text:SetPoint("CENTER", badge, "CENTER", 0, 0)
		NS:StyleFont(text, 12, "CENTER")
		text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
	end
	if header.Name then
		NS:StyleFont(header.Name, 15, "LEFT", true)
	end
end

local function SkinTreeHeaders(talents)
	for _, header in ipairs(talents.treeHeaders or {}) do
		SkinTreeHeader(header)
	end
end

---------------------------------------------------------------------------
-- Controls around the trees
---------------------------------------------------------------------------

-- Blizzard's yellow glow (changes to apply, a spec to activate) becomes an
-- accent border on the button's tile.
local function GlowAsBorder(glow, tile)
	if not glow or not tile then return end
	NS:HideTextures(glow.Left, glow.Middle, glow.Right)
	local function Sync()
		tile:SetBorderColor(unpack(glow:IsShown() and ACCENT or NS.color.border))
	end
	glow:HookScript("OnShow", Sync)
	glow:HookScript("OnHide", Sync)
	Sync()
end

local function SkinGlowButton(button)
	local tile = NS:SkinPanelButton(button)
	if tile then
		GlowAsBorder(button.YellowGlow, tile)
	end
end

-- Unspent points: the number on a small tile.
local function SkinCurrency(display)
	if not display then return end
	NS:HideTextures(display.Border)
	if display.UnspentLabel then
		NS:StyleFont(display.UnspentLabel, 13, "RIGHT")
	end
	local container = display.CurrentAmountContainer
	local amount = container and container.CurrencyAmount
	if amount then
		NS:CreateTile(container, 8, 6, NS.color.header, true)
		NS:RestyleFont(amount, 20, "CENTER", true)
	end
end

local function SkinActiveSpec(frame)
	if not frame then return end
	if frame.ActiveLabel then
		NS:RestyleFont(frame.ActiveLabel, 14, "CENTER")
	end
	SkinGlowButton(frame.ActivateButton)
end

-- Blizzard re-anchors both whenever inspecting starts or ends.
local function AlignSearchOptions(talents)
	local dropdown, search = talents.SearchOptionsDropdown, talents.SearchBox
	if dropdown and search then
		dropdown:SetPoint("LEFT", search, "RIGHT", 4, 0)
	end
end

local function SkinSearch(talents)
	local search, dropdown = talents.SearchBox, talents.SearchOptionsDropdown
	if search then
		NS:SkinSearchBox(search)
		search:SetHeight(CONTROL)
	end
	if dropdown then
		dropdown:SetSize(CONTROL, CONTROL)
		NS:SkinChevronDropdown(dropdown)
	end
	NS:SkinSearchPreview(talents.SearchPreviewContainer)
	NS:Hook(talents, "SetSearchBoxDefaultPosition", AlignSearchOptions)
	AlignSearchOptions(talents)
end

-- The class art framed like a tile, with flat rules between the trees.
local function SkinArt(talents)
	for _, key in ipairs(FRAME_ART) do
		NS:Kill(talents[key])
	end
	local art = talents.ClassBackground
	if art then
		local box = NS:CreateBox(talents, talents, art, NS.color.tile)
		box.shadow = NS:CreateShadow(talents, box.base)
	end
	for _, key in ipairs(TREE_DIVIDERS) do
		local divider = talents[key]
		if divider then
			NS:Kill(divider)
			local rule = NS:CreateLine(talents, "OVERLAY", TREE_RULE, true)
			rule:SetPoint("TOP", divider, "TOP")
			rule:SetPoint("BOTTOM", divider, "BOTTOM")
		end
	end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Init()
	local talents = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
	if not talents then
		NS:Missing("PlayerSpellsFrame.TalentsFrame")
		return
	end
	BuildStateColors()

	SkinArt(talents)
	NS:SkinTabSystem(talents.TabSystem, TAB_STYLE)
	SkinCurrency(talents.ClassCurrencyDisplay)
	SkinActiveSpec(talents.ActiveSpec)
	SkinGlowButton(talents.ApplyButton)
	NS:SkinPanelButton(talents.InspectCopyButton)
	SkinSearch(talents)

	if talents.RefreshTreeHeaders then
		NS:Hook(talents, "RefreshTreeHeaders", SkinTreeHeaders)
		SkinTreeHeaders(talents)
	end

	local events = TalentFrameBaseMixin and TalentFrameBaseMixin.Event
	if talents.RegisterCallback and events and events.TalentButtonAcquired then
		talents:RegisterCallback(events.TalentButtonAcquired, function(_, button) SkinNode(button) end, M)
	else
		NS:Missing("TalentFrameBaseMixin.Event.TalentButtonAcquired")
	end
	-- Buttons already in the tree.
	if talents.EnumerateAllTalentButtons then
		for button in talents:EnumerateAllTalentButtons() do
			SkinNode(button)
		end
	end
end
