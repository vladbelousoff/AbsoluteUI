-- AbsoluteUI: experience and reputation bars.
--
-- Edit Mode places and sizes the bar containers; each bar is laid out to
-- fill its container's box, with the castbar look: a flat fill in a box,
-- colored by what Blizzard's fill atlas stands for. Rested experience shows
-- as a lighter part past the fill.

local _, NS = ...

local M = NS:NewModule("TrackingBars", { setting = "trackingBars" })

-- Blizzard's fill atlases, by NS.trackingColor key.
local FILL_PREFIX = "UI-HUD-ExperienceBar-Fill-"
local FILLS = {
	[FILL_PREFIX .. "Experience"] = "xp",
	[FILL_PREFIX .. "Rested"] = "rested",
	[FILL_PREFIX .. "Reputation-Faction-Red"] = "hostile",
	[FILL_PREFIX .. "Reputation-Faction-Orange"] = "unfriendly",
	[FILL_PREFIX .. "Reputation-Faction-Yellow"] = "neutral",
	[FILL_PREFIX .. "Reputation-Faction-Green"] = "friendly",
	[FILL_PREFIX .. "Reputation-Faction-Blue"] = "renown",
}

local KILL = { "Background", "Underlay", "Overlay" }
-- Gain and level up flashes, drawn through Blizzard's animation mask.
local FLASHES = { "GainFlareAnimationTexture", "LevelUpTexture" }

local skins = {} -- [bar] = { box, color, rested }

-- The box's border traces the container, which Edit Mode places and sizes.
-- Blizzard anchors the bars once and then only resizes them, so anchored
-- at both corners they follow it.
local function Layout(bar)
	local container = bar:GetParent()
	local px = NS:Px(bar)
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", container, "TOPLEFT", px, -px)
	bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -px, px)
	bar.StatusBar:ClearAllPoints()
	bar.StatusBar:SetAllPoints(bar)
end

-- Blizzard sets a width for the rested part and crops it to match; the
-- crop is redone here after a texture change.
local function ApplyRestedTexture(bar)
	local rested = skins[bar].rested
	if not rested then return end
	rested:SetTexture(NS:GetBarTexture())
	local width, barWidth = rested:GetWidth(), bar:GetWidth()
	local crop = (barWidth and barWidth > 0) and math.min(width / barWidth, 1) or 1
	rested:SetTexCoord(0, crop, 0, 1)
end

-- An atlas we don't know keeps the current color.
local function ApplyFill(statusBar, atlas)
	local bar = statusBar:GetParent()
	local skin = skins[bar]
	NS:ApplyBarTexture(statusBar)
	local color = NS.trackingColor[FILLS[atlas]] or skin.color
	skin.color = color
	statusBar:SetStatusBarColor(color[1], color[2], color[3])
	local k = NS.HEALTH_BG_FACTOR
	skin.box.bg:SetVertexColor(color[1] * k, color[2] * k, color[3] * k, 1)
end

local function SkinBar(bar)
	local statusBar = bar.StatusBar
	if not statusBar or skins[bar] then return end
	local skin = { color = NS.trackingColor.xp }
	skins[bar] = skin

	NS:KillAll(statusBar, KILL)
	local mask = statusBar.AnimationMask
	for _, key in ipairs(FLASHES) do
		local flash = statusBar[key]
		if flash and mask then
			flash:RemoveMaskTexture(mask)
		end
		NS:Kill(flash)
	end
	NS:RegisterBar(statusBar)
	skin.box = NS:CreateBox(bar, bar, bar, NS.color.tile)
	NS:CreateShadow(bar, skin.box.base)

	local rested = bar.ExhaustionLevelFillBar
	if rested then
		skin.rested = rested
		rested:ClearAllPoints()
		rested:SetPoint("TOPLEFT", bar, "TOPLEFT")
		rested:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
		NS:SetColor(rested, NS.trackingColor.restedPart)
		ApplyRestedTexture(bar)
	end
	local tick = bar.ExhaustionTick
	if tick then
		NS:HideTextures(tick:GetNormalTexture(), tick:GetHighlightTexture())
	end

	local text = bar.OverlayFrame and bar.OverlayFrame.Text
	if text then
		NS:StyleBarText(text, 11, "CENTER")
		text:ClearAllPoints()
		text:SetPoint("CENTER", bar, "CENTER", 0, 0)
	end

	-- Deferred textures come back undeferred once Blizzard applies them.
	NS:Hook(statusBar, "SetBarTexture", function(self, atlas, deferUntilNextLevel)
		if not deferUntilNextLevel then ApplyFill(self, atlas) end
	end)
	local fill = statusBar:GetStatusBarTexture()
	ApplyFill(statusBar, fill and fill:GetAtlas())
	Layout(bar)
end

local function SkinContainer(container)
	NS:Kill(container.BarFrameTexture)
	NS:KeepDividersHidden(container)
	-- Keyed by bar type, not a sequence.
	for _, bar in pairs(container.bars or {}) do
		SkinBar(bar)
	end
end

function M:Init()
	local manager = StatusTrackingBarManager
	if not manager or not manager.barContainers then
		NS:Missing("StatusTrackingBarManager")
		return
	end
	for _, container in ipairs(manager.barContainers) do
		SkinContainer(container)
	end

	NS:RegisterPixelClient(function()
		for bar in pairs(skins) do Layout(bar) end
	end)
	NS:OnSettingChanged("barTexture", function()
		for bar in pairs(skins) do ApplyRestedTexture(bar) end
	end)
end
