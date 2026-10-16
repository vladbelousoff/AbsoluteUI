-- AbsoluteUI: right-click and dropdown menus (Blizzard_Menu).
--
-- Menus and their rows are run by Blizzard's compositor: it hands out and
-- resets every region on them, and doesn't allow creating new ones. Menu
-- frames are pooled, so each gets a child frame of ours once, carrying the
-- panel, shown whenever it opens with Blizzard's default style. Rows are
-- only restyled through the regions Blizzard attaches (post-hooks on
-- MenuVariants).

local _, NS = ...

local M = NS:NewModule("Menus", { setting = "menus" })

local MARGIN = NS.panelStyle.margin -- around the rows
local TEXT_SIZE = 13
local ROW_HOVER = NS.color.rowHover

---------------------------------------------------------------------------
-- Menu panels
---------------------------------------------------------------------------

local panels = {} -- [menu frame] = { frame, tile }

-- Below the rows, which Blizzard raises 20 levels above the menu.
local function CreatePanel(menu)
	local frame = CreateFrame("Frame", nil, menu)
	local panel = { frame = frame, tile = NS:CreateTile(frame, 0, 0, NS.color.panel) }
	panels[menu] = panel
	return panel
end

-- MARGIN around the rows, whatever insets the style uses.
local function LayoutPanel(menu, panel)
	local inset = menu.GetInset and menu:GetInset()
	local left, top = inset and inset.left or MARGIN, inset and inset.top or MARGIN
	local right, bottom = inset and inset.right or MARGIN, inset and inset.bottom or MARGIN
	local frame = panel.frame
	frame:SetFrameLevel(menu:GetFrameLevel())
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", menu, "TOPLEFT", left - MARGIN, MARGIN - top)
	frame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", MARGIN - right, bottom - MARGIN)
	panel.tile:Layout()
end

-- Every menu, submenus included. Menus from other addons with their own
-- style keep it.
local function OnMenuShow(_, menu)
	local panel = panels[menu]
	local default = MenuStyle1Mixin and menu.Generate == MenuStyle1Mixin.Generate
	if not default then
		if panel then panel.frame:Hide() end
		return
	end
	panel = panel or CreatePanel(menu)
	-- Blizzard attaches its background again on every open.
	for _, region in ipairs({ menu:GetRegions() }) do
		if region:IsObjectType("Texture") then
			region:SetAlpha(0)
		end
	end
	LayoutPanel(menu, panel)
	panel.frame:Show()
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

local function StyleTexts(row)
	for _, region in ipairs({ row:GetRegions() }) do
		if region:IsObjectType("FontString") then
			NS:RestyleFont(region, TEXT_SIZE, region:GetJustifyH())
		end
	end
end

local function SkinHighlight(row)
	if row.highlight then
		row.highlight:SetColorTexture(ROW_HOVER[1], ROW_HOVER[2], ROW_HOVER[3], ROW_HOVER[4])
	end
end

-- Checkboxes and radio buttons: a flat box, with an accent square when
-- selected.
local function SkinSelection(_, row)
	NS:StyleCheckbox(row.leftTexture1, row.leftTexture2)
	StyleTexts(row)
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Init()
	if not (MenuVariants and EventRegistry) then
		NS:Missing("MenuVariants")
		return
	end
	EventRegistry:RegisterCallback("MenuProxy.OnShow", OnMenuShow, M)

	-- Each runs as Blizzard builds a row, before the menu measures it.
	NS:Hook(MenuVariants, "CreateFontString", StyleTexts)
	NS:Hook(MenuVariants, "CreateHighlight", SkinHighlight)
	NS:Hook(MenuVariants, "CreateCheckbox", SkinSelection)
	NS:Hook(MenuVariants, "CreateRadio", SkinSelection)
end
