-- AbsoluteUI: classic quest log (QuestLogFrame), a window of its own.
--
-- The quest list above, the selected quest's details below, each in a box
-- on the panel. Blizzard colors the details for parchment (black and dark
-- grey), so they are recolored after every update; rewards become the item
-- cards of the NPC quest window.

local _, NS = ...

local M = NS:NewModule("QuestLog", { setting = "worldMap", flavor = "classic" })

-- The log inside Blizzard's 384x512 frame: { left, top, right, bottom }.
local WINDOW_INSET = { 10, 10, 35, 46 }
local NUM_OBJECTIVES = 10
local NUM_REWARDS = 10

local TITLES = { "QuestLogQuestTitle", "QuestLogDescriptionTitle", "QuestLogRewardTitleText" }
local TEXTS = {
	"QuestLogObjectivesText", "QuestLogQuestDescription", "QuestLogItemChooseText", "QuestLogItemReceiveText",
	"QuestLogSpellLearnText", "QuestLogSuggestedGroupNum", "QuestLogTimerText",
}
local BUTTONS = { "QuestLogFrameAbandonButton", "QuestFrameExitButton", "QuestFramePushQuestButton" }
-- Frames whose own textures are parchment-era art: the "All" sort tab, the
-- empty log's book and the quest count's border.
local ART_FRAMES = { "QuestLogExpandButtonFrame", "EmptyQuestLogFrame", "QuestLogCount" }

local function SetColor(fs, color)
	if fs then fs:SetTextColor(color[1], color[2], color[3]) end
end

-- Blizzard draws open objectives black and finished ones dark grey.
local function ColorDetails()
	local c = NS.color
	for _, name in ipairs(TITLES) do
		SetColor(_G[name], c.accent)
	end
	for _, name in ipairs(TEXTS) do
		SetColor(_G[name], c.text)
	end
	for i = 1, NUM_OBJECTIVES do
		local objective = _G["QuestLogObjective" .. i]
		if objective then
			local r = objective:GetTextColor()
			SetColor(objective, r > 0.1 and c.dim or c.text)
		end
	end
	-- Black when affordable, grey when not.
	local money = QuestLogRequiredMoneyText
	if money then
		local r = money:GetTextColor()
		SetColor(money, r > 0.1 and c.dim or c.text)
	end

	for i = 1, NUM_REWARDS do
		local button = _G["QuestLogItem" .. i]
		if button and button:IsShown() then
			local card = NS:SyncRewardCard(button)
			local link = card and button.type and GetQuestLogItemLink(button.type, button:GetID())
			local quality = link and C_Item.GetItemQualityByID(link)
			if quality and quality >= 2 then
				card.icon.border:SetColor(NS:QualityColor(quality))
			end
		end
	end
end

local function HideArt(frame)
	local icon
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("Texture") then
			if region:GetDrawLayer() == "BACKGROUND" then
				icon = region -- the book icon
			else
				NS:Kill(region)
			end
		end
	end
	for _, name in ipairs(ART_FRAMES) do
		local holder = _G[name]
		for _, region in ipairs(holder and { holder:GetRegions() } or {}) do
			if region:IsObjectType("Texture") then
				NS:Kill(region)
			end
		end
	end
	return icon
end

function M:Init()
	local frame = QuestLogFrame
	if not frame or not QuestLogListScrollFrame or not QuestLogDetailScrollFrame then
		NS:Missing("QuestLogFrame")
		return
	end

	local icon = HideArt(frame)
	NS:SkinClassicWindow(frame, WINDOW_INSET, QuestLogTitleText, QuestLogFrameCloseButton, icon)
	if QuestLogCount then
		NS:CreateTile(QuestLogCount, 0, 0, NS.color.tile, true)
	end

	-- The list and the details, each in a box.
	for _, scroll in ipairs({ QuestLogListScrollFrame, QuestLogDetailScrollFrame }) do
		NS:CreateBox(frame, frame, scroll, NS.color.header)
		NS:SkinSliderScrollBar(scroll.ScrollBar)
	end
	if QuestLogSkillHighlight then
		-- Blizzard tints it in the selected quest's difficulty color.
		QuestLogSkillHighlight:SetColorTexture(1, 1, 1, 0.15)
	end

	for _, name in ipairs(BUTTONS) do
		NS:SkinPanelButton(_G[name])
	end
	local track = QuestLogTrackTitle
	if track then
		NS:RestyleFont(track, 12, "LEFT")
	end

	NS:Hook(nil, "QuestLog_UpdateQuestDetails", ColorDetails)
	ColorDetails()
end
