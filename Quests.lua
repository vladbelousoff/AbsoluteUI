-- AbsoluteUI: quest dialog (QuestFrame) and NPC gossip window (GossipFrame).
--
-- Blizzard colors their text for parchment (dark brown), so on the dark
-- panel it is recolored after every update. The quest text frames
-- (QuestInfo) are shared with the quest log on the world map: each module
-- registers the parents it darkens (NS:RegisterDarkQuestInfo), and the
-- others get Blizzard's colors back.

local _, NS = ...

local M = NS:NewModule("Quests", { setting = "questFrames" })

local ROW_HOVER = NS.color.rowHover

local QUEST_PANELS = { "QuestFrameRewardPanel", "QuestFrameProgressPanel", "QuestFrameDetailPanel", "QuestFrameGreetingPanel" }
local PANEL_ART = { "Bg", "MaterialTopLeft", "MaterialTopRight", "MaterialBotLeft", "MaterialBotRight", "SealMaterialBG" }
local QUEST_BUTTONS = {
	"QuestFrameCompleteQuestButton", "QuestFrameGoodbyeButton", "QuestFrameCompleteButton",
	"QuestFrameDeclineButton", "QuestFrameAcceptButton", "QuestFrameGreetingGoodbyeButton",
}

-- Texts Blizzard colors with QuestFrame_SetTextColor / _SetTitleTextColor.
local FRAME_TEXTS = {
	"GreetingText", "CurrentQuestsText", "AvailableQuestsText",
	"QuestProgressTitleText", "QuestProgressText", "QuestProgressRequiredItemsText",
}

-- Shared quest text frames (QuestInfo), by role.
local INFO_TITLES = { "QuestInfoTitleHeader", "QuestInfoDescriptionHeader", "QuestInfoObjectivesHeader" }
local INFO_TEXTS = {
	"QuestInfoDescriptionText", "QuestInfoObjectivesText", "QuestInfoGroupSize",
	"QuestInfoRewardText", "QuestInfoTimerText", "QuestInfoSpellObjectiveLearnLabel",
}
local REWARD_TEXTS = { "ItemChooseText", "ItemReceiveText", "PlayerTitleText", "QuestSessionBonusReward" }
-- Texts Blizzard colors on every display, so only dark parents touch them.
local DISPLAY_TEXTS = { "QuestInfoRequiredMoneyText", "QuestInfoQuestType" }

-- Reward buttons besides RewardButtons; those with an icon and a name frame
-- become cards.
local REWARD_EXTRAS = { "HonorFrame", "SkillPointFrame", "ArtifactXPFrame", "WarModeBonusFrame", "XPFrame", "MoneyFrame" }
local REWARD_POOLS = { "spellRewardPool", "reputationRewardPool" }

-- Some keys hold frames on one rewards frame and font strings on the other.
local function SetTextColor(fs, color)
	if fs and fs.SetTextColor then fs:SetTextColor(color[1], color[2], color[3]) end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

-- Panel, header and a framed content area where Blizzard's inset is.
local function SkinWindow(frame, portrait)
	local header = NS:SkinPanelFrame(frame)
	NS:SkinPanelPortrait(frame, header, portrait)
	local inset = frame.Inset
	if inset then
		NS:Kill(inset.Bg)
		if inset.NineSlice then inset.NineSlice:SetAlpha(0) end
		NS:CreateBox(frame, frame, inset, NS.color.header)
	end
end

---------------------------------------------------------------------------
-- Item cards: quest rewards and items to hand in
---------------------------------------------------------------------------

local cards = {} -- [button] = { tile, icon box }

local function SkinCard(button)
	local card = cards[button]
	if card then return card end
	local icon = button.Icon
	if not icon then return nil end
	card = { tile = NS:CreateTile(button, 0, 0, NS.color.tile, true) }
	cards[button] = card
	NS:Kill(button.NameFrame)
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
	-- Small buttons (the map's rewards) are as tall as their icon.
	local size = button:GetHeight() - 2
	if icon:GetHeight() > size then
		icon:SetSize(size, size)
	end
	NS:CropIcon(icon)
	card.icon = NS:CreateBox(button, button, icon, NS.color.panel)
	return card
end

-- Quality on the icon border (Blizzard's own is hidden), the chosen
-- reward in the accent color. Rewards are only picked in the NPC window;
-- the map's choice rewards would match a stale choice.
local function SyncCard(button)
	local card = SkinCard(button)
	if not card then return end
	local quality = button.IconBorder
	if quality and quality:IsShown() then
		local r, g, b = quality:GetVertexColor()
		card.icon.border:SetColor(r, g, b)
	else
		card.icon.border:SetColor(unpack(NS.color.border))
	end
	NS:HideTextures(quality)
	local chosen = QuestInfoFrame and button:GetParent() == QuestInfoRewardsFrame
		and button.type == "choice" and QuestInfoFrame.itemChoice == button:GetID()
	card.tile:SetBorderColor(unpack(chosen and NS.color.accent or NS.color.border))
end

local function IsCardButton(button)
	return type(button) == "table" and button.Icon and button.NameFrame
		and button.IsObjectType and button:IsObjectType("Button")
end

-- QuestInfoRewardsFrame or MapQuestInfoRewardsFrame.
local function SyncRewardCards(rewards)
	if not rewards then return end
	for _, button in ipairs(rewards.RewardButtons or {}) do
		SyncCard(button)
	end
	for _, key in ipairs(REWARD_EXTRAS) do
		if IsCardButton(rewards[key]) then SyncCard(rewards[key]) end
	end
	for _, key in ipairs(REWARD_POOLS) do
		local pool = rewards[key]
		if pool and pool.EnumerateActive then
			for button in pool:EnumerateActive() do
				if IsCardButton(button) then SyncCard(button) end
			end
		end
	end
end

local function SyncProgressCards()
	for i = 1, 6 do
		local button = _G["QuestProgressItem" .. i]
		if button then SyncCard(button) end
	end
end

---------------------------------------------------------------------------
-- Quest text on dark panels (QuestInfo, shared with WorldMap.lua)
---------------------------------------------------------------------------

local function ColorRewardTexts(rewards, text, title)
	if not rewards then return end
	SetTextColor(rewards.Header, title)
	for _, key in ipairs(REWARD_TEXTS) do
		SetTextColor(rewards[key], text)
	end
	SetTextColor(rewards.XPFrame and rewards.XPFrame.ReceiveText, text)
end

local function ColorQuestInfo(text, title)
	for _, name in ipairs(INFO_TITLES) do
		SetTextColor(_G[name], title)
	end
	for _, name in ipairs(INFO_TEXTS) do
		SetTextColor(_G[name], text)
	end
	ColorRewardTexts(QuestInfoRewardsFrame, text, title)
end

-- Finished objectives end in " (Complete)" and are dimmed.
local function ColorObjectives()
	local list = QuestInfoObjectivesFrame and QuestInfoObjectivesFrame.Objectives
	local suffix = COMPLETE and " (" .. COMPLETE .. ")"
	for _, fs in ipairs(list or {}) do
		local text = fs:GetText()
		local done = suffix and type(text) == "string" and text:sub(-#suffix) == suffix
		SetTextColor(fs, done and NS.color.dim or NS.color.text)
	end
end

local darkParents = {} -- [QuestInfo parent frame] = true
local recolored = false

-- Blizzard only recolors when the material changes, so other parents would
-- keep our colors otherwise.
local function OnQuestInfoDisplay(_, parentFrame, _, material)
	if darkParents[parentFrame] then
		ColorQuestInfo(NS.color.text, NS.color.accent)
		for _, name in ipairs(DISPLAY_TEXTS) do
			SetTextColor(_G[name], NS.color.text)
		end
		ColorObjectives()
		recolored = true
		local rewards = QuestInfoFrame and QuestInfoFrame.rewardsFrame
		if rewards and rewards:GetParent() == parentFrame then
			ColorRewardTexts(rewards, NS.color.text, NS.color.accent)
			SyncRewardCards(rewards)
		end
	elseif recolored and GetMaterialTextColors then
		local useLight = QuestTextContrast and QuestTextContrast.UseLightText()
		local text, title = GetMaterialTextColors(useLight and "Stone" or material or "Default")
		if text and title then
			ColorQuestInfo(text, title)
			recolored = false
		end
	end
end

local hooked = false

-- Quest text shown in `parentFrame` gets light colors and reward cards.
function NS:RegisterDarkQuestInfo(parentFrame)
	if not parentFrame then return end
	darkParents[parentFrame] = true
	if not hooked then
		hooked = NS:Hook(nil, "QuestInfo_Display", OnQuestInfoDisplay)
	end
end

---------------------------------------------------------------------------
-- Quest dialog
---------------------------------------------------------------------------

local frameTexts = {} -- [font string] = true

local function OnFrameText(fs)
	if frameTexts[fs] then SetTextColor(fs, NS.color.text) end
end

local function OnFrameTitle(fs)
	if frameTexts[fs] then SetTextColor(fs, NS.color.accent) end
end

-- Quest titles carry a black color code; fixed color ignores it.
local function StyleTitleButton(button)
	local fs = button.GetFontString and button:GetFontString()
	if fs then
		fs:SetFixedColor(true)
		SetTextColor(fs, NS.color.text)
	end
	NS:SetFlat(button:GetHighlightTexture(), ROW_HOVER, button)
end

local function OnGreetingShow(panel)
	local pool = panel.titleButtonPool
	if not pool then return end
	for button in pool:EnumerateActive() do
		StyleTitleButton(button)
	end
end

local function OnProgressItemsUpdate()
	SetTextColor(QuestProgressRequiredMoneyText, NS.color.text)
	SyncProgressCards()
end

function M:SkinQuestFrame()
	local frame = QuestFrame
	SkinWindow(frame, QuestFramePortrait)
	for _, name in ipairs(QUEST_PANELS) do
		local panel = _G[name]
		if panel then
			for _, key in ipairs(PANEL_ART) do
				NS:Kill(panel[key])
			end
		end
	end
	for _, name in ipairs(QUEST_BUTTONS) do
		NS:SkinPanelButton(_G[name])
	end
	NS:Kill(QuestGreetingFrameHorizontalBreak)

	for _, name in ipairs(FRAME_TEXTS) do
		if _G[name] then frameTexts[_G[name]] = true end
	end
	NS:Hook(nil, "QuestFrame_SetTextColor", OnFrameText)
	NS:Hook(nil, "QuestFrame_SetTitleTextColor", OnFrameTitle)
	NS:Hook(nil, "QuestFrameProgressItems_Update", OnProgressItemsUpdate)
	NS:RegisterDarkQuestInfo(QuestDetailScrollChildFrame)
	NS:RegisterDarkQuestInfo(QuestRewardScrollChildFrame)
	NS:Hook(nil, "QuestInfoItem_OnClick", function() SyncRewardCards(QuestInfoRewardsFrame) end)
	if QuestFrameGreetingPanel then
		QuestFrameGreetingPanel:HookScript("OnShow", OnGreetingShow)
	end

	-- The chosen reward gets an accent border instead.
	if QuestInfoItemHighlight then
		for _, region in ipairs({ QuestInfoItemHighlight:GetRegions() }) do
			region:SetAlpha(0)
		end
	end
end

---------------------------------------------------------------------------
-- Gossip
---------------------------------------------------------------------------

local gossipRows = {}

local function StyleGossipRow(row)
	if not row then return end
	if row.GreetingText then
		SetTextColor(row.GreetingText, NS.color.text)
	elseif row.GetFontString then
		local fs = row:GetFontString()
		if fs then
			fs:SetFixedColor(true)
			SetTextColor(fs, NS.color.text)
		end
		if not gossipRows[row] then
			gossipRows[row] = true
			NS:SetFlat(row:GetHighlightTexture(), ROW_HOVER, row)
		end
	end
end

function M:SkinGossipFrame()
	local frame = GossipFrame
	SkinWindow(frame)
	NS:Kill(frame.Background)
	local panel = frame.GreetingPanel
	if not panel then return end
	for _, region in ipairs({ panel:GetRegions() }) do
		if region:IsObjectType("Texture") then
			NS:Kill(region)
		end
	end
	NS:SkinPanelButton(panel.GoodbyeButton)

	-- Rows are recycled as the list scrolls and colored as they're set up.
	local scrollBox = panel.ScrollBox
	if scrollBox and ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
		ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, row) StyleGossipRow(row) end, M, true)
	end
	NS:Hook(frame, "Update", function(gossip)
		local box = gossip.GreetingPanel and gossip.GreetingPanel.ScrollBox
		if box and box.ForEachFrame then
			box:ForEachFrame(StyleGossipRow)
		end
	end)
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Init()
	if QuestFrame then
		self:SkinQuestFrame()
	else
		NS:Missing("QuestFrame")
	end
	if GossipFrame then
		self:SkinGossipFrame()
	else
		NS:Missing("GossipFrame")
	end
end
