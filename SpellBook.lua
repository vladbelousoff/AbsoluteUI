-- AbsoluteUI: spellbook window (PlayerSpellsFrame).
--
-- WoW Forever shows the spellbook and the talents in one window, one at a
-- time. This module skins the window and the spellbook page; Talents.lua
-- skins the talents page.
--
-- Spells and section headers are pooled frames, styled as the paged view
-- hands them out, before Blizzard fills them in. Clicking a spell casts it
-- through a protected call, so those frames only get textures and
-- post-hooks, never fields.

local _, NS = ...

local M = NS:NewModule("SpellBook", { setting = "spellBook", addon = "Blizzard_PlayerSpells" })

local ACCENT = NS.color.accent
local CONTROL = 20 -- settings, search and page buttons

-- Blizzard drives these alphas: the icon highlight at 0.35 (hover) and 0.65
-- (pressed), the backplate at 0.25 (idle) and 1 (hover).
local ICON_HOVER = { 1, 1, 1, 0.4 }
local CARD = { 1, 1, 1, 0.08 }
local CARD_PAD = 10 -- card space left of the icon, as above and below it
local UNASSIGNED = { ACCENT[1], ACCENT[2], ACCENT[3], 0.35 } -- not on any action bar

-- Category tabs: 30x30 icon tiles.
local TAB_STYLE = { insetX = 3, insetY = 1, iconWidth = 36 }

local BOOK_ART = { "TopBar", "BookBGHalved", "BookBGLeft", "BookBGRight", "BookCornerFlipbook", "Bookmark" }
local ITEM_ART = { "Border", "BorderShadow", "BorderSheen", "TrainableShadow", "TrainableBackplate" }

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local portrait

-- The spellbook shows a skill line icon with its built-in border; the
-- talents' class icon comes with its own tex coords.
local function CropPortrait()
	local left, top, _, _, _, _, right, bottom = portrait:GetTexCoord()
	if left == 0 and top == 0 and right == 1 and bottom == 1 then
		NS:CropIcon(portrait)
	end
end

function M:SkinWindow(frame)
	local header = NS:SkinPanelFrame(frame)
	portrait = NS:SkinPanelPortrait(frame, header)
	if portrait then
		NS:Hook(frame, "UpdatePortrait", CropPortrait)
		CropPortrait()
	end
	-- Expands to two pages or condenses to one.
	NS:SkinMaximizeMinimize(frame.MaximizeMinimizeButton)
end

---------------------------------------------------------------------------
-- Spells
---------------------------------------------------------------------------

local items = {}   -- [spell frame] = icon tile
local headers = {} -- [header frame] = true

-- After every UpdateVisuals, which resets the highlight atlas. Spells to
-- learn at a trainer get an accent border.
local function SyncItem(item)
	local tile = items[item]
	if not tile then return end
	NS:SetFlat(item.Button.IconHighlight, ICON_HOVER, tile.fill)
	local trainable = item.isTrainable
	tile:SetBorderColor(unpack(trainable and ACCENT or NS.color.border))
	local c = trainable and ACCENT or NS.color.dim
	item.RequiredLevel:SetTextColor(c[1], c[2], c[3])
end

-- Names may take a few lines.
local function StyleItemText(fs, size, color)
	NS:StyleFont(fs, size, "LEFT")
	fs:SetWordWrap(true)
	fs:SetTextColor(color[1], color[2], color[3])
end

local function SkinItem(item)
	local button = item.Button
	local tile = NS:CreateTile(button)
	items[item] = tile

	-- Square icons for every spell, passives included.
	for _, region in ipairs({ button.Icon, button.LevelLinkIconCover, button.ClickBindingIconCover }) do
		region:RemoveMaskTexture(button.IconMask)
	end
	tile.icon = button.Icon
	tile:Layout()
	NS:CropIcon(button.Icon)
	for _, region in ipairs({ button.LevelLinkIconCover, button.ClickBindingIconCover, button.Cooldown }) do
		region:ClearAllPoints()
		region:SetAllPoints(tile.fill)
	end

	for _, key in ipairs(ITEM_ART) do
		NS:HideTextures(button[key])
	end
	NS:SetFlat(button.ActionBarHighlight, UNASSIGNED, tile.fill)

	-- Blizzard's hover backplate becomes a card around the spell.
	local card = item.Backplate
	card:SetColorTexture(CARD[1], CARD[2], CARD[3], CARD[4])
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", item, "TOPLEFT", -CARD_PAD, 0)
	card:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)

	StyleItemText(item.Name, 14, NS.color.text)
	StyleItemText(item.SubName, 12, NS.color.dim)
	StyleItemText(item.RequiredLevel, 12, NS.color.dim)

	NS:Hook(item, "UpdateVisuals", SyncItem)
end

-- Section title in the accent color over a thin rule.
local function SkinHeader(header)
	headers[header] = true
	NS:Kill(header.Border)
	NS:Kill(header.Backplate)
	local text = header.Text
	NS:StyleFont(text, 16, "LEFT")
	text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
	local rule = NS:CreateLine(header, "ARTWORK", NS.color.divider)
	rule:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -5)
	rule:SetPoint("TOPRIGHT", text, "BOTTOMRIGHT", 0, -5)
end

-- Runs after a pooled frame is placed and before Blizzard fills it in.
local function OnElementFrame(_, frame)
	if not frame or items[frame] or headers[frame] then return end
	if frame.Button and frame.TextContainer then
		SkinItem(frame)
	elseif frame.Text and frame.Border then
		SkinHeader(frame)
	end
end

---------------------------------------------------------------------------
-- Spellbook page
---------------------------------------------------------------------------

-- Blizzard puts this back when gamepad mode ends.
local function AnchorSearch(book)
	local search, dropdown = book.SearchBox, book.SettingsDropdown
	if search and dropdown then
		search:ClearAllPoints()
		search:SetPoint("RIGHT", dropdown, "LEFT", -4, 0)
	end
end

-- Category tabs on the left, search and settings on the right, on one line
-- through the settings button.
local function LayoutToolbar(book)
	local dropdown, tabs = book.SettingsDropdown, book.CategoryTabSystem
	if dropdown then
		dropdown:SetSize(CONTROL, CONTROL)
		NS:SkinChevronDropdown(dropdown)
		if tabs then
			local _, _, _, x = tabs:GetPoint(1)
			tabs:ClearAllPoints()
			tabs:SetPoint("LEFT", book, "TOPLEFT", x or 70, (dropdown.yOffset or -27) - CONTROL / 2)
		end
	end
	NS:SkinTabSystem(tabs, TAB_STYLE)

	if book.SearchBox then
		NS:SkinSearchBox(book.SearchBox)
		book.SearchBox:SetHeight(CONTROL)
		AnchorSearch(book)
	end
	NS:SkinSearchPreview(book.SearchPreviewContainer)
end

local function SkinPaging(paging)
	if not paging then return end
	if paging.PageText then
		NS:StyleFont(paging.PageText, 12, "CENTER")
		local c = NS.color.dim
		paging.PageText:SetTextColor(c[1], c[2], c[3])
	end
	for _, spec in ipairs({ { paging.PrevPageButton, "left" }, { paging.NextPageButton, "right" } }) do
		local button = spec[1]
		if button then
			button:SetSize(CONTROL, CONTROL)
			NS:SkinArrowButton(button, spec[2])
		end
	end
end

-- A rule down the middle of the gap between the two pages; hidden with the
-- right page when the book is condensed.
local function AddSpine(paged)
	local left, right = paged.View1, paged.View2
	if not (left and right) then return end
	local gap = right:CreateTexture(nil, "BACKGROUND")
	gap:SetPoint("TOPLEFT", left, "TOPRIGHT")
	gap:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	local spine = NS:CreateLine(right, "BACKGROUND", NS.color.divider, true)
	spine:SetPoint("TOP", gap, "TOP")
	spine:SetPoint("BOTTOM", gap, "BOTTOM")
end

-- The assisted combat button, if this client has it.
local function SkinRotationSpell(frame)
	local button = frame and frame.Button
	if not button or not button.Icon then return end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:GetObjectType() == "Texture" then
			region:SetAlpha(0) -- divider art
		end
	end
	local tile = NS:CreateTile(button)
	tile.icon = button.Icon
	tile:Layout()
	NS:CropIcon(button.Icon)
	NS:HideTextures(button.Border)
	NS:SetFlat(button:GetHighlightTexture(), { 1, 1, 1, 0.15 }, tile.fill)
	NS:SetFlat(button:GetPushedTexture(), { 1, 1, 1, 0.25 }, tile.fill)
	if frame.Label then
		NS:StyleFont(frame.Label, 12, "RIGHT")
		frame.Label:SetWordWrap(true)
	end
end

function M:SkinSpellBook(book)
	for _, key in ipairs(BOOK_ART) do
		NS:Kill(book[key])
	end
	LayoutToolbar(book)
	SkinRotationSpell(book.AssistedCombatRotationSpellFrame)

	local paged = book.PagedSpellsFrame
	if not paged then
		NS:Missing("PlayerSpellsFrame.SpellBookFrame.PagedSpellsFrame")
		return
	end
	SkinPaging(paged.PagingControls)
	AddSpine(paged)
	NS:Hook(paged, "ProcessElementFrame", OnElementFrame)
	-- Frames already on the page.
	if paged.EnumerateFrames then
		for _, frame in paged:EnumerateFrames() do
			OnElementFrame(paged, frame)
			SyncItem(frame)
		end
	end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Init()
	local frame = PlayerSpellsFrame
	if not frame then
		NS:Missing("PlayerSpellsFrame")
		return
	end
	self:SkinWindow(frame)
	if frame.SpellBookFrame then
		self:SkinSpellBook(frame.SpellBookFrame)
		NS:Hook(frame, "UninitializeGamepad", function(window) AnchorSearch(window.SpellBookFrame) end)
	else
		NS:Missing("PlayerSpellsFrame.SpellBookFrame")
	end
end
