-- AbsoluteUI: a bar style for BigWigs, picked in BigWigs > Bars > Style.
--
-- Bars come from LibCandyBar, shared with other addons, so the style only
-- uses the backdrop frames each bar already has and puts back whatever it
-- changed when the bar stops. Picking the style also switches BigWigs to
-- our bar texture and font (it reads them from the style by name).

local _, NS = ...

local M = NS:NewModule("BigWigs", { setting = "skinBigWigs", addon = "BigWigs", early = true })

local STYLE_ID = "AbsoluteUI"
local BAR_HEIGHT = 20

local function Backdrop(px)
	return {
		bgFile = NS.SOLID, edgeFile = NS.SOLID, edgeSize = px,
		insets = { left = px, right = px, top = px, bottom = px },
	}
end

local function Frame(backdrop, region, px)
	backdrop:ClearAllPoints()
	backdrop:SetPoint("TOPLEFT", region, "TOPLEFT", -px, px)
	backdrop:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", px, -px)
	backdrop:SetBackdrop(Backdrop(px))
	local c, b = NS.color.tile, NS.color.border
	backdrop:SetBackdropColor(c[1], c[2], c[3], 0.9)
	backdrop:SetBackdropBorderColor(b[1], b[2], b[3], 1)
end

-- Like BigWigs' own flat styles: the icon is a square at one end with a
-- gap to the bar, each framed by its own backdrop.
local function ApplyStyle(bar)
	local px = NS:Px(bar)
	local statusbar, icon, iconBackdrop = bar.candyBarBar, bar.candyBarIconFrame, bar.candyBarIconFrameBackdrop
	local reApplyIcon
	if icon.IsAnchoringSecret and icon:IsAnchoringSecret() then
		reApplyIcon = bar:GetIcon()
		icon:SetToDefaults()
		iconBackdrop:SetToDefaults()
		iconBackdrop:SetFrameLevel(0)
	end
	statusbar:ClearAllPoints()
	icon:ClearAllPoints()

	local gap = 3 * px
	if bar:GetIconPosition() == "RIGHT" then
		icon:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
		icon:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
		statusbar:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
		if bar:IsIconVisible() then
			statusbar:SetPoint("TOPRIGHT", icon, "TOPLEFT", -gap, 0)
		else
			statusbar:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
		end
	else
		icon:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
		icon:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
		statusbar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
		if bar:IsIconVisible() then
			statusbar:SetPoint("TOPLEFT", icon, "TOPRIGHT", gap, 0)
		else
			statusbar:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
		end
	end
	icon:SetSize(bar:GetHeight(), bar:GetHeight())

	Frame(bar.candyBarBackdrop, statusbar, px)
	bar.candyBarBackdrop:Show()
	Frame(iconBackdrop, icon, px)
	if bar:IsIconVisible() then
		iconBackdrop:Show()
	end

	-- LibCandyBar crops icons itself, except after the reset above.
	if reApplyIcon then
		icon:SetTexture(reApplyIcon)
		NS:CropIcon(icon)
	end
end

local function BarStopped(bar)
	bar.candyBarBackdrop:Hide()
	bar.candyBarIconFrameBackdrop:Hide()
end

function M:Init()
	local api = _G.BigWigsAPI
	if not (api and api.RegisterBarStyle) then
		NS:Missing("BigWigsAPI")
		return
	end
	local texture, font = NS:SharedBarMedia()
	api:RegisterBarStyle(STYLE_ID, {
		apiVersion = 1,
		version = 1,
		barSpacing = 4,
		barHeight = BAR_HEIGHT,
		fontSizeNormal = 12,
		fontSizeEmphasized = 14,
		fontOutline = "OUTLINE",
		spellIndicatorsOffset = 2,
		texture = texture,
		fontName = font,
		ApplyStyle = ApplyStyle,
		BarStopped = BarStopped,
		GetStyleName = function() return "AbsoluteUI" end,
	})
end
