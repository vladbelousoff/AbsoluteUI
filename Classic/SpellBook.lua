-- AbsoluteUI: classic spellbook (SpellBookFrame).
--
-- Twelve fixed spell buttons in two columns, skill line tabs down the right
-- edge and book tabs (spells, pet) below. Spell buttons are secure, so they
-- keep their places and only get textures and post-hooks.

local _, NS = ...

local M = NS:NewModule("SpellBook", { setting = "spellBook", flavor = "classic" })

local ACCENT = NS.color.accent
local NUM_SPELLS = 12
local NUM_SKILL_LINES = 8
local CONTROL = 20 -- page buttons

-- The book inside Blizzard's 384x512 frame: { left, top, right, bottom }.
local WINDOW_INSET = { 10, 12, 32, 76 }
-- The visible part of a book tab (128x64).
local TAB_INSET = { 15, 14, 19, 23 }

local ICON_HOVER = { 1, 1, 1, 0.15 }
local ICON_PUSHED = { 1, 1, 1, 0.25 }
local SELECTED = { ACCENT[1], ACCENT[2], ACCENT[3], 0.35 } -- an open profession

---------------------------------------------------------------------------
-- Spell buttons ("SpellButton1"...)
---------------------------------------------------------------------------

local spells = {} -- [button] = icon tile

-- After every UpdateButton: Blizzard swaps the highlight texture and
-- colors the name for the parchment.
local function SyncSpell(button)
	local tile = spells[button]
	if not tile then return end
	local name = button:GetName()
	local icon = _G[name .. "IconTexture"]
	tile:SetShown(icon and icon:IsShown() or false)
	NS:SetFlat(button:GetHighlightTexture(), ICON_HOVER, tile.fill)

	local c = button.isPassive and NS.color.dim or NS.color.text
	local spellName = _G[name .. "SpellName"]
	if spellName then spellName:SetTextColor(c[1], c[2], c[3]) end
	local subName = _G[name .. "SubSpellName"]
	if subName then
		local d = NS.color.dim
		subName:SetTextColor(d[1], d[2], d[3])
	end
end

local function SkinSpell(button)
	local name = button:GetName()
	local icon = _G[name .. "IconTexture"]
	if not icon then return end
	local tile = NS:CreateTile(button)
	spells[button] = tile
	tile.icon = icon
	tile:Layout()
	NS:CropIcon(icon)

	NS:HideTextures(button.EmptySlot, button:GetNormalTexture())
	NS:SetFlat(button:GetPushedTexture(), ICON_PUSHED, tile.fill)
	NS:SetFlat(button:GetCheckedTexture(), SELECTED, tile.fill)
	local cooldown = _G[name .. "Cooldown"]
	if cooldown then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(tile.fill)
	end

	local spellName = _G[name .. "SpellName"]
	if spellName then
		NS:StyleFont(spellName, 13, "LEFT")
		spellName:SetWordWrap(true)
	end
	local subName = _G[name .. "SubSpellName"]
	if subName then
		NS:StyleFont(subName, 11, "LEFT")
	end

	NS:Hook(button, "UpdateButton", SyncSpell)
	SyncSpell(button)
end

---------------------------------------------------------------------------
-- Skill line tabs: the icon in a tile, the selected one with an accent
-- border. Blizzard sets their icons and checked state on every update.
---------------------------------------------------------------------------

local skillTabs = {} -- [tab] = tile

local function SyncSkillTabs()
	for tab, tile in pairs(skillTabs) do
		local icon = tab:GetNormalTexture()
		if icon then
			tile.icon = icon
			NS:CropIcon(icon)
		end
		tile:Layout()
		tile:SetBorderColor(unpack(tab:GetChecked() and ACCENT or NS.color.border))
	end
end

local function SkinSkillTab(tab)
	-- The frame art around the icon is its one unnamed texture.
	for _, region in ipairs({ tab:GetRegions() }) do
		if region:IsObjectType("Texture") and region:GetDrawLayer() == "BACKGROUND" then
			region:SetAlpha(0)
		end
	end
	skillTabs[tab] = NS:CreateTile(tab)
	NS:HideTextures(tab:GetCheckedTexture())
	NS:SetFlat(tab:GetHighlightTexture(), ICON_HOVER, skillTabs[tab].fill)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

-- The book's art is unnamed: the icon in the background layer, the pages
-- in the artwork layer.
local function FindArt(frame)
	local icon, pages = nil, {}
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("Texture") then
			if region:GetDrawLayer() == "BACKGROUND" then
				icon = region
			else
				table.insert(pages, region)
			end
		end
	end
	return icon, pages
end

local function SkinPaging()
	for _, spec in ipairs({ { SpellBookPrevPageButton, "left" }, { SpellBookNextPageButton, "right" } }) do
		local button = spec[1]
		if button then
			button:SetSize(CONTROL, CONTROL)
			NS:SkinArrowButton(button, spec[2])
		end
	end
	local text = SpellBookPageText
	if text and SpellBookPrevPageButton and SpellBookNextPageButton then
		NS:StyleFont(text, 12, "CENTER")
		local d = NS.color.dim
		text:SetTextColor(d[1], d[2], d[3])
		text:ClearAllPoints()
		text:SetPoint("LEFT", SpellBookPrevPageButton, "RIGHT", 4, 0)
		text:SetPoint("RIGHT", SpellBookNextPageButton, "LEFT", -4, 0)
	end
end

function M:Init()
	local frame = SpellBookFrame
	if not frame or not SpellButton1 then
		NS:Missing("SpellBookFrame")
		return
	end

	local icon, pages = FindArt(frame)
	for _, page in ipairs(pages) do
		NS:Kill(page)
	end
	NS:SkinClassicWindow(frame, WINDOW_INSET, SpellBookTitleText, SpellBookCloseButton, icon)
	if icon then
		icon:SetTexCoord(0, 1, 0, 1) -- a round book, not an icon with a border
	end

	local ranks = ShowAllSpellRanksCheckbox
	local ranksText = ranks and _G[ranks:GetName() .. "Text"]
	if ranksText then
		NS:RestyleFont(ranksText, 12, "LEFT")
		local c = NS.color.text
		ranksText:SetTextColor(c[1], c[2], c[3])
	end

	for i = 1, NUM_SPELLS do
		local button = _G["SpellButton" .. i]
		if button then SkinSpell(button) end
	end
	for i = 1, NUM_SKILL_LINES do
		local tab = _G["SpellBookSkillLineTab" .. i]
		if tab then SkinSkillTab(tab) end
	end
	NS:Hook(frame, "UpdateSkillLineTabs", SyncSkillTabs)
	SyncSkillTabs()

	for i = 1, 3 do
		NS:SkinClassicTab(_G["SpellBookFrameTabButton" .. i], TAB_INSET)
	end
	SkinPaging()
end
