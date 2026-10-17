-- AbsoluteUI: experience and reputation bars.
--
-- Edit Mode places and sizes the bar containers; each bar is laid out to
-- fill its container's box, with the castbar look: a flat fill in a box,
-- colored by what Blizzard's fill atlas (modern) or tint (classic) stands
-- for. Rested experience shows as a lighter part past the fill.

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

-- Classic tints by reaction: 1 (hated) to 8 (exalted).
local STANDINGS = { "hostile", "hostile", "unfriendly", "neutral", "friendly", "friendly", "friendly", "friendly" }

local KILL = { "Background", "Underlay", "Overlay" }
-- Classic containers draw a border of their own, matching either the main
-- menu bar or a standalone bar.
local CONTAINER_ART = { "MainMenuBarTextures", "StandaloneTextures" }
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

-- `key` is an NS.trackingColor key; one we don't know keeps the current
-- color.
local function ApplyColor(bar, key)
	local skin = skins[bar]
	local color = NS.trackingColor[key] or skin.color
	skin.color = color
	bar.StatusBar:SetStatusBarColor(color[1], color[2], color[3])
	local k = NS.HEALTH_BG_FACTOR
	skin.box.bg:SetVertexColor(color[1] * k, color[2] * k, color[3] * k, 1)
	-- Classic tints the rested part along with the fill.
	if skin.rested then
		NS:SetColor(skin.rested, NS.trackingColor.restedPart)
	end
end

local function ApplyFill(statusBar, atlas)
	NS:ApplyBarTexture(statusBar)
	ApplyColor(statusBar:GetParent(), FILLS[atlas])
end

-- Classic bars are tinted rather than given an atlas. Blizzard tinted them
-- before we loaded, so the first color is worked out here.
local function ClassicStartColor(bar)
	if bar.UpdateStatusBarTextures then
		return (GetRestState and GetRestState() == 1) and "rested" or "xp"
	end
	local data = C_Reputation and C_Reputation.GetWatchedFactionData and C_Reputation.GetWatchedFactionData()
	return data and STANDINGS[data.reaction]
end

local function HookClassicColors(bar)
	NS:Hook(bar, bar.UpdateStatusBarTextures and "UpdateStatusBarTextures" or "UpdateBarTextures",
		function(_, state)
			if bar.UpdateStatusBarTextures then
				ApplyColor(bar, state and "rested" or "xp") -- state: rested
			else
				ApplyColor(bar, STANDINGS[state]) -- state: reaction
			end
		end)
end

local function SkinBar(bar)
	local statusBar = bar.StatusBar
	if not statusBar or skins[bar] then return end
	local skin = { color = NS.trackingColor.xp }
	skins[bar] = skin

	for _, key in ipairs(KILL) do
		NS:Kill(statusBar[key])
	end
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

	if NS.isClassic then
		HookClassicColors(bar)
		ApplyColor(bar, ClassicStartColor(bar))
	else
		-- Deferred textures come back undeferred once Blizzard applies them.
		NS:Hook(statusBar, "SetBarTexture", function(self, atlas, deferUntilNextLevel)
			if not deferUntilNextLevel then ApplyFill(self, atlas) end
		end)
		local fill = statusBar:GetStatusBarTexture()
		ApplyFill(statusBar, fill and fill:GetAtlas())
	end
	Layout(bar)
end

local function SkinContainer(container)
	NS:Kill(container.BarFrameTexture)
	for _, key in ipairs(CONTAINER_ART) do
		for _, texture in ipairs(container[key] or {}) do
			NS:Kill(texture)
		end
	end
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
