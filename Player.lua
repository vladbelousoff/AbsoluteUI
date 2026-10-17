-- AbsoluteUI: player frame.

local _, NS = ...

local M = NS:NewModule("Player")

---------------------------------------------------------------------------
-- Blizzard's regions, per client:
--   power, name, level  the card follows or adopts these
--   context             layer of status icons (combat, rest, leader, ready
--                       check), moved above our art as a whole
--   nameHooks           functions after which Blizzard re-anchors the name
--   artHooks            functions that switch between player and vehicle art
--   HideArt()           hides the art and the protected bars
---------------------------------------------------------------------------

local function ModernParts(frame)
	local main = NS:Get(frame, "PlayerFrameContent.PlayerFrameContentMain")
	return {
		power = PlayerFrame_GetManaBar and PlayerFrame_GetManaBar() or NS:Get(main, "ManaBarArea.ManaBar"),
		name = PlayerName,
		level = PlayerLevelText,
		context = NS:Get(frame, "PlayerFrameContent.PlayerFrameContentContextual"),
		nameHooks = { "PlayerFrame_UpdatePlayerNameTextAnchor" },
		artHooks = { "PlayerFrame_ToPlayerArt", "PlayerFrame_ToVehicleArt" },
		HideArt = function(parts)
			NS:KillAll(NS:Get(frame, "PlayerFrameContainer"), {
				"FrameTexture", "AlternatePowerFrameTexture", "VehicleFrameTexture",
				"PlayerPortrait", "PlayerPortraitMask", "FrameFlash",
			})
			NS:KillAll(main, {
				"StatusTexture", "LevelBackgroundCircle", "PvpBackgroundCircle",
				"PvpBackgroundIcon", "HitIndicator",
			})
			NS:KillAll(parts.context, {
				"PlayerPortraitCornerIcon", "PVPIcon", "PrestigePortrait",
				"PrestigeBadge", "GroupIndicator", "PvpTimerText",
			})
			if main then
				NS:HideProtectedBars("player-bars", main.HealthBarsContainer, main.ManaBarArea)
			end
		end,
	}
end

local function ClassicParts(frame)
	return {
		power = PlayerFrame_GetManaBar and PlayerFrame_GetManaBar() or PlayerFrameManaBar,
		name = PlayerName,
		level = PlayerLevelText,
		context = NS:Get(frame, "rightFrame"),
		nameHooks = {},
		-- Both re-anchor the name.
		artHooks = { "PlayerFrame_ToPlayerArt", "PlayerFrame_ToVehicleArt" },
		HideArt = function()
			NS:KillGlobals({
				"PlayerFrameFlash", "PlayerFrameBackground", "PlayerPortrait", "PlayerFrameTexture",
				"PlayerFrameVehicleTexture", "PlayerStatusTexture", "PlayerStatusGlow",
				"PlayerAttackBackground", "PlayerHitIndicator", "PlayerPVPIcon", "PlayerPVPTimerText",
				"PlayerFrameGroupIndicator",
				"PlayerFrameHealthBarText", "PlayerFrameHealthBarTextLeft", "PlayerFrameHealthBarTextRight",
				"PlayerFrameManaBarText", "PlayerFrameManaBarTextLeft", "PlayerFrameManaBarTextRight",
			})
			NS:KillAll(NS:Get(frame, "rightFrame.textFrame"), { "overAbsorbGlow", "overHealAbsorbGlow" })
			NS:HideProtectedBars("player-bars", PlayerFrameHealthBar, PlayerFrameManaBar)
		end,
	}
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Init()
	local frame = PlayerFrame
	if not frame then
		NS:Missing("PlayerFrame")
		return
	end

	local parts = (NS.isClassic and ClassicParts or ModernParts)(frame)
	local card = NS:CreateUnitCard(frame, {
		layout = NS.layouts.unit,
		blizzPower = parts.power,
		name = parts.name,
		levelText = parts.level,
		textKey = "playerText",
		powerText = true,
		showLoss = true,
	})
	self.card = card

	parts:HideArt()
	self:AdoptContextual(parts.context)

	for _, name in ipairs(parts.nameHooks) do
		NS:Hook(nil, name, function() card:AdoptTexts() end)
	end

	local function Rebind()
		card:SetUnit(frame.unit or "player")
		card:AdoptTexts()
	end
	for _, name in ipairs(parts.artHooks) do
		NS:Hook(nil, name, Rebind)
	end
	NS:On("PLAYER_ENTERING_WORLD", Rebind)
	Rebind()
end

-- Status icons keep their places but draw above our art. Their layer covers
-- the whole player frame, so it moves to our overlay as a whole.
function M:AdoptContextual(context)
	if not context or context:IsProtected() then return end
	local overlay = self.card.overlay
	NS:Adopt(context, overlay, 1)
	for _, child in ipairs({ context:GetChildren() }) do
		child:SetFrameLevel(context:GetFrameLevel() + 1)
	end
	local readyCheck = context.ReadyCheck or PlayerFrameReadyCheck
	if readyCheck then
		readyCheck:SetFrameLevel(context:GetFrameLevel() + 3)
	end
end

function M:Refresh()
	if self.card then
		self.card:Update()
	end
end
