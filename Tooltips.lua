-- AbsoluteUI: tooltips.
--
-- Tooltips are picked up as Blizzard applies their backdrop style, so ones
-- created later (by other addons too) get the same look.

local _, NS = ...

local M = NS:NewModule("Tooltips", { setting = "tooltips" })

local TOOLTIPS = {
	"GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
	"ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "EmbeddedItemTooltip",
	"GameNoHeaderTooltip", "GameSmallHeaderTooltip", "BuffFrameTooltip",
	"NamePlateTooltip", "QuickKeybindTooltip", "SettingsTooltip",
}

local FONTS = { "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall" }

local tiles = {}

local function SetBorder(tooltip, r, g, b)
	local tile = tiles[tooltip]
	if tile then
		tile:SetBorderColor(r, g, b)
	end
end

local function ResetBorder(tooltip)
	SetBorder(tooltip, unpack(NS.color.border))
end

-- Embedded tooltips stay frameless.
local function ApplyStyle(tooltip, _, embedded)
	if not tooltip or not tooltip.NineSlice then return end
	local tile = tiles[tooltip]
	if not tile then
		tile = NS:CreateTile(tooltip, 0, 0, NS.color.panel)
		tiles[tooltip] = tile
		tooltip:HookScript("OnTooltipCleared", ResetBorder)
	end
	tooltip.NineSlice:SetAlpha(0)
	tile:SetShown(not (embedded or tooltip.IsEmbedded))
	ResetBorder(tooltip)
end

---------------------------------------------------------------------------
-- Border colors
---------------------------------------------------------------------------

local function OnItem(tooltip)
	if not tiles[tooltip] or not TooltipUtil then return end
	local _, link, id = TooltipUtil.GetDisplayedItem(tooltip)
	local quality = (link or id) and C_Item.GetItemQualityByID(link or id)
	if quality and quality >= 2 then
		local r, g, b = C_Item.GetItemQualityColor(quality)
		SetBorder(tooltip, r, g, b)
	end
end

local function OnUnit(tooltip)
	if not tiles[tooltip] or not TooltipUtil then return end
	local _, unit = TooltipUtil.GetDisplayedUnit(tooltip)
	if unit and not NS.IsSecret(unit) and UnitExists(unit) then
		local color = NS:UnitHealthColor(unit, true)
		SetBorder(tooltip, color[1], color[2], color[3])
	end
end

-- Cosmetic; must never break a tooltip.
local function Safe(fn)
	return function(tooltip) pcall(fn, tooltip) end
end

---------------------------------------------------------------------------
-- Health bar and fonts
---------------------------------------------------------------------------

local HEALTH_HEIGHT = 8  -- UI units, snapped to whole pixels
local HEALTH_GAP_PX = 3  -- physical pixels between the bar and the tooltip

-- The health bar sits on top of the tooltip, full width.
local function LayoutStatusBar(bar, box)
	local px = NS:Px(bar)
	local tooltip = bar:GetParent()
	box:SetThickness(px)
	bar:SetHeight(math.floor(HEALTH_HEIGHT / px + 0.5) * px)
	bar:ClearAllPoints()
	bar:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", px, (HEALTH_GAP_PX + 1) * px)
	bar:SetPoint("BOTTOMRIGHT", tooltip, "TOPRIGHT", -px, (HEALTH_GAP_PX + 1) * px)
end

local function SkinHealthBar(bar)
	if not bar then return end
	-- Partly secure bar; restyling must not error.
	pcall(function()
		local box = NS:SkinStatusBar(bar)
		LayoutStatusBar(bar, box)
		NS:RegisterPixelClient(function() pcall(LayoutStatusBar, bar, box) end)
	end)
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Init()
	for _, name in ipairs(TOOLTIPS) do
		local tooltip = _G[name]
		if tooltip and tooltip.NineSlice then
			ApplyStyle(tooltip, nil, tooltip.IsEmbedded)
		end
	end
	NS:Hook(nil, "SharedTooltip_SetBackdropStyle", ApplyStyle)

	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, Safe(OnItem))
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, Safe(OnUnit))
	end

	SkinHealthBar(GameTooltip and GameTooltip.StatusBar)
	NS:ApplyFontFamilies(FONTS, 1)
end
