-- AbsoluteUI: classic character window (CharacterFrame).
--
-- One page at a time (character, pet, reputation, skills, PvP), a tab per
-- page below the window. Each page draws the whole window art itself, so
-- every page's own textures go and the window gets one panel. Lists keep
-- Blizzard's fixed rows: bars get a box, headers a drawn +/-.
--
-- Equipment slots are skinned by CharacterFrame.lua (shared with Forever).

local _, NS = ...

local M = NS:NewModule("Character", { setting = "characterFrame", flavor = "classic" })

-- The window inside Blizzard's 384x512 frame: { left, top, right, bottom }.
local WINDOW_INSET = { 10, 12, 32, 76 }
-- The visible part of a page tab (CharacterFrameTabButtonTemplate).
local TAB_INSET = { 8, 8, 6, 6 }
local NUM_TABS = 5
local CONTROL = 20 -- model rotate buttons
local ROW_HOVER = NS.color.rowHover

local PLAYER_STAT_ART = {
	"PlayerStatLeftTop", "PlayerStatLeftMiddle", "PlayerStatLeftBottom",
	"PlayerStatRightTop", "PlayerStatRightMiddle", "PlayerStatRightBottom",
}
local PET_STATS = {
	"PetStatFrame1", "PetStatFrame2", "PetStatFrame3", "PetStatFrame4", "PetStatFrame5",
	"PetAttackPowerFrame", "PetDamageFrame", "PetSpellDamageFrame", "PetArmorFrame",
}

---------------------------------------------------------------------------
-- Shared bits
---------------------------------------------------------------------------

-- Every page's own textures are window art.
local function HidePageArt(page)
	for _, region in ipairs({ page:GetRegions() }) do
		if region:IsObjectType("Texture") then
			NS:Kill(region)
		end
	end
end

-- Label dimmed, value white (Blizzard colors buffed values itself).
local function StyleStat(frame)
	if not frame then return end
	local name = frame:GetName()
	local label = frame.Label or _G[name .. "Label"]
	if label then
		NS:StyleFont(label, 11, label:GetJustifyH())
		local c = NS.color.dim
		label:SetTextColor(c[1], c[2], c[3])
	end
	local value = _G[name .. "StatText"]
	if value then
		NS:RestyleFont(value, 11, "RIGHT")
	end
end

-- A box behind the model, and the two rotate buttons as chevron boxes in
-- its top left corner. The first one turns the model left.
local function SkinModel(model, rotateLeft, rotateRight)
	if not model then return end
	-- Textures on a model frame draw behind the model.
	NS:CreateBox(model, model, model, NS.color.tile)
	local previous
	for _, spec in ipairs({ { rotateLeft, "left" }, { rotateRight, "right" } }) do
		local button = spec[1]
		if button then
			button:SetSize(CONTROL, CONTROL)
			button:ClearAllPoints()
			if previous then
				button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
			else
				button:SetPoint("TOPLEFT", model, "TOPLEFT", 4, -4)
			end
			NS:SkinArrowButton(button, spec[2])
			previous = button
		end
	end
end

-- Boxes for the bar textures Blizzard draws behind a status bar.
local function BoxBar(bar)
	NS:CreateBox(bar, bar, bar, NS.color.powerBg)
	NS:RegisterBar(bar)
end

---------------------------------------------------------------------------
-- Collapsible headers (reputation, skills): a drawn +/- where Blizzard's
-- button art was, titles in the accent color.
---------------------------------------------------------------------------

local headers = {} -- [button] = vertical stroke of the "+"
local headerFonts

local function HeaderFonts()
	if not headerFonts then
		headerFonts = {}
		for key, color in pairs({ normal = NS.color.accent, highlight = NS.color.text }) do
			local font = CreateFont("AbsoluteUICharacterHeader_" .. key)
			font:SetFontObject(NS:GetFont(12))
			font:SetTextColor(color[1], color[2], color[3])
			font:SetShadowOffset(1, -1)
			font:SetShadowColor(0, 0, 0, 0.9)
			headerFonts[key] = font
		end
	end
	return headerFonts
end

local function SkinHeader(button)
	if not button or headers[button] then return end
	local glyph = CreateFrame("Frame", nil, button)
	glyph:SetSize(16, 16)
	glyph:SetPoint("LEFT", button, "LEFT", 3, 0)
	local _, vertical = NS:CreatePlus(glyph)
	headers[button] = vertical
	NS:SetFlat(button:GetHighlightTexture(), NS.color.glyphHover, glyph)
	local fonts = HeaderFonts()
	button:SetNormalFontObject(fonts.normal)
	button:SetHighlightFontObject(fonts.highlight)
	button:SetDisabledFontObject(fonts.normal)
end

-- Blizzard sets a plus or minus texture on every update.
local function SyncHeader(button, collapsed)
	local vertical = headers[button]
	if not vertical then return end
	NS:HideTextures(button:GetNormalTexture(), button:GetDisabledTexture())
	vertical:SetShown(collapsed and true or false)
end

---------------------------------------------------------------------------
-- Character page
---------------------------------------------------------------------------

local function SkinCharacterPage()
	local page = PaperDollFrame
	HidePageArt(page)
	if CharacterLevelText then
		NS:RestyleFont(CharacterLevelText, 12, "CENTER")
	end
	SkinModel(CharacterModelFrame, CharacterModelFrameRotateRightButton, CharacterModelFrameRotateLeftButton)
	NS:SkinCharacterSlots()

	-- Two stat columns, each with its dropdown on top.
	local attributes = CharacterAttributesFrame
	if attributes then
		NS:KillGlobals(PLAYER_STAT_ART)
		for _, side in ipairs({ "Left", "Right" }) do
			local top, bottom = _G["PlayerStat" .. side .. "Top"], _G["PlayerStat" .. side .. "Bottom"]
			if top and bottom then
				local rect = attributes:CreateTexture()
				rect:SetPoint("TOPLEFT", top, "TOPLEFT")
				rect:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT")
				NS:CreateBox(attributes, attributes, rect, NS.color.header)
			end
			for i = 1, 6 do
				StyleStat(_G["PlayerStatFrame" .. side .. i])
			end
			NS:SkinTextDropdown(_G["PlayerStatFrame" .. side .. "Dropdown"])
		end
	end
	NS:SkinTextDropdown(PlayerTitleDropdown)
end

local function SkinPetPage()
	local page = PetPaperDollFrame
	if not page then return end
	HidePageArt(page)
	SkinModel(PetModelFrame, PetModelFrameRotateRightButton, PetModelFrameRotateLeftButton)
	local attributes = PetAttributesFrame
	if attributes then
		NS:HideRegions(attributes, "BACKGROUND")
		NS:CreateBox(attributes, attributes, attributes, NS.color.header)
	end
	for _, name in ipairs(PET_STATS) do
		StyleStat(_G[name])
	end
	local bar = PetPaperDollFrameExpBar
	if bar then
		NS:SkinStatusBar(bar)
		local text = PetPaperDollFrameExpBarText
		if text then NS:StyleFont(text, 11, "CENTER", true) end
	end
	NS:SkinPanelButton(PetPaperDollCloseButton)
end

---------------------------------------------------------------------------
-- Reputation page: fixed rows, each a header or a bar.
---------------------------------------------------------------------------

local function SyncReputationHeaders()
	for i = 1, NUM_FACTIONS_DISPLAYED or 15 do
		local header = _G["ReputationHeader" .. i]
		if header and header:IsShown() then
			SyncHeader(header, header.isCollapsed)
		end
	end
end

local function SkinReputationBar(bar)
	local name = bar:GetName()
	NS:KillGlobals({ name .. "ReputationBarLeft", name .. "ReputationBarRight" })
	BoxBar(bar)
	-- Blizzard shows both on hover and on the selected faction.
	local highlight = _G[name .. "Highlight1"]
	if highlight then
		NS:SetFlat(highlight, ROW_HOVER, bar)
		highlight:SetBlendMode("BLEND")
	end
	NS:HideTextures(_G[name .. "Highlight2"])
	local faction = _G[name .. "FactionName"]
	if faction then NS:RestyleFont(faction, 11, "LEFT") end
	local standing = _G[name .. "FactionStanding"]
	if standing then NS:StyleFont(standing, 11, "CENTER", true) end
end

-- The details window next to the page.
local function SkinReputationDetails()
	local detail = ReputationDetailFrame
	if not detail then return end
	if detail.ClearBackdrop then detail:ClearBackdrop() end
	NS:HideRegions(detail)
	NS:CreateTile(detail, 0, 0, NS.color.panel)
	local close = ReputationDetailCloseButton
	if close then
		close:SetSize(NS.panelStyle.header, NS.panelStyle.header)
		NS:SkinCloseButton(close)
	end
	for _, name in ipairs({ "ReputationDetailAtWarCheckbox", "ReputationDetailInactiveCheckbox",
		"ReputationDetailMainScreenCheckbox" }) do
		NS:SkinCheckButton(_G[name])
	end
end

local function SkinReputationPage()
	local page = ReputationFrame
	if not page then return end
	HidePageArt(page)
	for _, label in ipairs({ ReputationFrameFactionLabel, ReputationFrameStandingLabel }) do
		NS:StyleFont(label, 12, label:GetJustifyH())
		local c = NS.color.dim
		label:SetTextColor(c[1], c[2], c[3])
	end
	for i = 1, NUM_FACTIONS_DISPLAYED or 15 do
		local bar = _G["ReputationBar" .. i]
		if bar then SkinReputationBar(bar) end
		SkinHeader(_G["ReputationHeader" .. i])
	end
	local scroll = ReputationListScrollFrame
	if scroll then
		NS:HideRegions(scroll)
		NS:SkinSliderScrollBar(scroll.ScrollBar or _G[scroll:GetName() .. "ScrollBar"])
	end
	SkinReputationDetails()
	NS:Hook(nil, "ReputationFrame_Update", SyncReputationHeaders)
end

---------------------------------------------------------------------------
-- Skills page: skill type headers and rank bars in a scrolling list, the
-- selected skill's details below.
---------------------------------------------------------------------------

local function SyncSkillHeaders()
	for i = 1, SKILLS_TO_DISPLAY or 12 do
		local label = _G["SkillTypeLabel" .. i]
		if label and label:IsShown() then
			SyncHeader(label, not label.isExpanded)
		end
	end
	local all = SkillFrameCollapseAllButton
	if all then
		SyncHeader(all, not all.isExpanded)
	end
end

-- SkillStatusBarTemplate and the details bar: the border and background
-- go, the bonus part of the fill stays.
local function SkinSkillBar(bar)
	if not bar then return end
	local name = bar:GetName()
	NS:HideTextures(_G[name .. "Background"])
	-- A texture on the details bar, a button on list rows. The button takes
	-- the clicks, so only its art goes.
	local border = _G[name .. "Border"]
	if border and border:IsObjectType("Texture") then
		NS:Kill(border)
	elseif border and border.GetNormalTexture then
		NS:HideTextures(border:GetNormalTexture())
		NS:SetFlat(border:GetHighlightTexture(), ROW_HOVER, bar)
	end
	BoxBar(bar)
	for _, key in ipairs({ "SkillName", "SkillRank" }) do
		local fs = _G[name .. key]
		if fs then NS:RestyleFont(fs, 11, fs:GetJustifyH()) end
	end
end

local function SkinSkillPage()
	local page = SkillFrame
	if not page then return end
	HidePageArt(page)
	NS:HideRegions(SkillFrameExpandButtonFrame)
	SkinHeader(SkillFrameCollapseAllButton)
	for i = 1, SKILLS_TO_DISPLAY or 12 do
		SkinSkillBar(_G["SkillRankFrame" .. i])
		SkinHeader(_G["SkillTypeLabel" .. i])
	end
	SkinSkillBar(SkillDetailStatusBar)
	for _, scroll in ipairs({ SkillListScrollFrame, SkillDetailScrollFrame }) do
		NS:HideRegions(scroll)
		NS:SkinSliderScrollBar(scroll.ScrollBar or _G[scroll:GetName() .. "ScrollBar"])
	end
	NS:SkinPanelButton(SkillFrameCancelButton)
	NS:Hook(nil, "SkillFrame_UpdateSkills", SyncSkillHeaders)
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Init()
	local frame = CharacterFrame
	if not frame or not PaperDollFrame then
		NS:Missing("CharacterFrame")
		return
	end
	NS:SkinClassicWindow(frame, WINDOW_INSET, CharacterNameText, CharacterFrameCloseButton, CharacterFramePortrait)
	for i = 1, NUM_TABS do
		NS:SkinClassicTab(_G["CharacterFrameTab" .. i], TAB_INSET)
	end

	SkinCharacterPage()
	SkinPetPage()
	SkinReputationPage()
	SkinSkillPage()
	-- The PvP page: only its art for now.
	for _, name in ipairs(CHARACTERFRAME_SUBFRAMES or {}) do
		local page = _G[name]
		if page and (name == "PVPFrame" or name == "HonorFrame") then
			HidePageArt(page)
		end
	end
end
