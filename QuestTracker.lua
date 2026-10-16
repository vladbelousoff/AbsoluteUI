-- AbsoluteUI: objective tracker.
--
-- Pooled frames are found by reading Blizzard's pools after each tracker
-- update. Quest item buttons call a protected function, so nothing on them
-- is hooked.

local _, NS = ...

local M = NS:NewModule("QuestTracker", { setting = "questTracker", addon = "Blizzard_ObjectiveTracker" })

local MODULES = {
	"ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "CampaignQuestObjectiveTracker",
	"QuestObjectiveTracker", "AdventureObjectiveTracker", "AchievementObjectiveTracker",
	"MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker",
	"ProfessionsRecipeTracker", "BonusObjectiveTracker", "WorldQuestObjectiveTracker",
}

local FONTS = { "ObjectiveTrackerLineFont", "ObjectiveTrackerHeaderFont" }

local skinned = {}

-- Edit Mode's text size swaps the font objects; reapply ours on top.
local function ApplyFonts()
	NS:ApplyFontFamilies(FONTS, 1)
end

---------------------------------------------------------------------------
-- Headers
---------------------------------------------------------------------------

local function SkinMinimizeButton(header, isCollapsed)
	local button = header.MinimizeButton
	if not button then return end
	local vertical = NS:SkinPlusButton(button)
	local function Apply(_, collapsed)
		-- Blizzard swaps these atlases on every collapse.
		NS:HideTextures(button:GetNormalTexture(), button:GetPushedTexture())
		vertical:SetShown(collapsed and true or false)
	end
	NS:Hook(header, "SetCollapsed", Apply)
	Apply(header, isCollapsed)
end

local function SkinHeader(header, insetY, color, isCollapsed)
	if not header or skinned[header] then return end
	skinned[header] = true
	for _, key in ipairs({ "Background", "Glow", "Shine" }) do
		NS:Kill(header[key])
	end
	NS:CreateTile(header, 0, insetY, color)
	SkinMinimizeButton(header, isCollapsed)
end

local function SkinModule(module)
	if not module or not module.Header then return end
	local collapsed = module.IsCollapsed and module:IsCollapsed()
	SkinHeader(module.Header, 3, NS.color.tile, collapsed)
end

---------------------------------------------------------------------------
-- Pooled frames: progress bars, timer bars, quest item buttons
---------------------------------------------------------------------------

local function SkinBar(bar)
	if not bar or skinned[bar] then return end
	skinned[bar] = true
	NS:SkinStatusBar(bar)
	if bar.Label then
		NS:StyleFont(bar.Label, 11, "CENTER", true)
	end
end

local function SkinItemButton(button)
	if skinned[button] then return end
	skinned[button] = true
	local tile = NS:CreateTile(button)
	tile.icon = button.icon
	tile:Layout()
	NS:CropIcon(button.icon)

	NS:HideTextures(button:GetNormalTexture())
	NS:SetFlat(button:GetPushedTexture(), { 1, 1, 1, 0.25 }, tile.fill)
	NS:SetFlat(button:GetHighlightTexture(), { 1, 1, 1, 0.15 }, tile.fill)
	if button.Cooldown then
		button.Cooldown:ClearAllPoints()
		button.Cooldown:SetAllPoints(tile.fill)
	end
	if button.Count then NS:StyleFont(button.Count, 11, "RIGHT", true) end
	if button.HotKey then NS:StyleFont(button.HotKey, 10, "LEFT", true) end
end

local function ScanPools()
	local pools = ObjectiveTrackerManager and ObjectiveTrackerManager.poolCollection
	if not pools then return end
	for frame in pools:EnumerateActive() do
		if not skinned[frame] then
			if frame.Bar and frame.Bar.GetStatusBarTexture then
				SkinBar(frame.Bar)
			elseif frame.icon and frame.Cooldown and frame.GetNormalTexture then
				SkinItemButton(frame)
			end
			skinned[frame] = true
		end
	end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Init()
	local tracker = ObjectiveTrackerFrame
	if not tracker then
		NS:Missing("ObjectiveTrackerFrame")
		return
	end

	ApplyFonts()
	if ObjectiveTrackerManager then
		NS:Hook(ObjectiveTrackerManager, "SetTextSize", ApplyFonts)
	end

	-- Shown at Edit Mode's opacity setting.
	local nineSlice = tracker.NineSlice
	if nineSlice then
		for _, region in ipairs({ nineSlice:GetRegions() }) do
			NS:Kill(region)
		end
		NS:CreateTile(nineSlice, 0, 0, NS.color.panel)
	end

	local collapsed = tracker.IsCollapsed and tracker:IsCollapsed()
	SkinHeader(tracker.Header, 4, NS.color.header, collapsed)

	for _, name in ipairs(MODULES) do
		SkinModule(_G[name])
	end
	if tracker.ForEachModule then
		tracker:ForEachModule(SkinModule)
	end
	NS:Hook(tracker, "AddModule", function(_, module) SkinModule(module) end)
	NS:Hook(tracker, "Update", ScanPools)
	ScanPools()
end
