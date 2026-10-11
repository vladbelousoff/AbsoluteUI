-- AbsoluteUI: player frame.

local _, NS = ...

local M = NS:NewModule("Player")

function M:Init()
	local frame = PlayerFrame
	if not frame then
		NS:Missing("PlayerFrame")
		return
	end
	self.frame = frame

	local main = NS:Get(frame, "PlayerFrameContent.PlayerFrameContentMain")
	local card = NS:CreateUnitCard(frame, {
		layout = NS.layouts.unit,
		blizzPower = PlayerFrame_GetManaBar and PlayerFrame_GetManaBar() or NS:Get(main, "ManaBarArea.ManaBar"),
		name = PlayerName,
		levelText = PlayerLevelText,
		textKey = "playerText",
		powerText = true,
		showLoss = true,
	})
	self.card = card

	self:HideBlizzardArt(main)
	self:AdoptContextual()

	-- Blizzard re-anchors the name on art changes (e.g. vehicles).
	NS:Hook(nil, "PlayerFrame_UpdatePlayerNameTextAnchor", function() card:AdoptTexts() end)

	local function Rebind()
		card:SetUnit(frame.unit or "player")
	end
	NS:Hook(nil, "PlayerFrame_ToPlayerArt", Rebind)
	NS:Hook(nil, "PlayerFrame_ToVehicleArt", Rebind)
	NS:On("PLAYER_ENTERING_WORLD", Rebind)
	Rebind()
end

function M:HideBlizzardArt(main)
	local frame = self.frame
	NS:KillAll(NS:Get(frame, "PlayerFrameContainer"), {
		"FrameTexture", "AlternatePowerFrameTexture", "VehicleFrameTexture",
		"PlayerPortrait", "PlayerPortraitMask", "FrameFlash",
	})
	NS:KillAll(main, {
		"StatusTexture", "LevelBackgroundCircle", "PvpBackgroundCircle",
		"PvpBackgroundIcon", "HitIndicator",
	})
	NS:KillAll(NS:Get(frame, "PlayerFrameContent.PlayerFrameContentContextual"), {
		"PlayerPortraitCornerIcon", "PVPIcon", "PrestigePortrait",
		"PrestigeBadge", "GroupIndicator", "PvpTimerText",
	})

	if main then
		NS:HideProtectedBars("player-bars", main.HealthBarsContainer, main.ManaBarArea)
	end
end

-- Status icons (combat, rest, leader, role, ready check) keep their places
-- but draw above our art. Their layer covers the whole player frame, so it
-- moves to our overlay as a whole.
function M:AdoptContextual()
	local context = NS:Get(self.frame, "PlayerFrameContent.PlayerFrameContentContextual")
	if not context or context:IsProtected() then return end
	local overlay = self.card.overlay
	NS:Adopt(context, overlay, 1)
	for _, child in ipairs({ context:GetChildren() }) do
		child:SetFrameLevel(context:GetFrameLevel() + 1)
	end
	if context.ReadyCheck then
		context.ReadyCheck:SetFrameLevel(context:GetFrameLevel() + 3)
	end
end

function M:Refresh()
	if self.card then
		self.card:Update()
	end
end
