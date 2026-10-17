-- AbsoluteUI: pet frame.
--
-- Edit Mode places the pet frame; its card is laid out inside it
-- (NS.layouts.pet), like the target of target's. While the pet attacks,
-- the card's border turns red, where Blizzard pulses a red glow.

local _, NS = ...

local M = NS:NewModule("Pet")

local AURA_GAP_PX = 3 -- physical pixels between the card and the pet's auras

-- The attack glow keeps toggling while hidden; the border follows it.
local ART = { "PetFrameTexture", "PetPortrait", "PetFrameFlash", "PetAttackModeTexture", "PetHitIndicator" }
-- Classic frames also show texts on the bars and absorb glows.
local CLASSIC_ART = {
	"PetFrameHealthBarText", "PetFrameHealthBarTextLeft", "PetFrameHealthBarTextRight",
	"PetFrameManaBarText", "PetFrameManaBarTextLeft", "PetFrameManaBarTextRight",
	"PetFrameOverAbsorbGlow", "PetFrameOverHealAbsorbGlow",
}

-- Blizzard puts the pet's auras in a row just under its bars, across the
-- card's bottom edge; the row moves below the card.
local function AnchorAuras(frame, layout)
	local auras = frame.AuraFrameContainer
	if not auras then return end
	local panel = layout.panel
	auras:ClearAllPoints()
	auras:SetPoint("TOPLEFT", frame, "TOPLEFT", panel[1], panel[4] - AURA_GAP_PX * NS:Px(frame))
end

function M:Init()
	local frame = PetFrame
	if not frame then
		NS:Missing("PetFrame")
		return
	end

	local layout = NS.isClassic and NS.layouts.petClassic or NS.layouts.pet
	for _, name in ipairs(ART) do
		NS:Kill(_G[name])
	end
	NS:Kill(frame.PortraitMask)
	if NS.isClassic then
		NS:KillGlobals(CLASSIC_ART)
	end
	NS:HideProtectedBars("pet-bars", PetFrameHealthBar, PetFrameManaBar)

	local card = NS:CreateUnitCard(frame, {
		layout = layout,
		blizzPower = PetFrameManaBar,
		name = PetName,
	})
	self.card = card

	-- "player" while a vehicle shows its own pet frame.
	local function Rebind()
		card:SetUnit(frame.unit or "pet")
	end
	NS:Hook(frame, "Update", Rebind)
	Rebind()

	-- Blizzard's click area only covers its portrait; ours is the panel.
	local panel = layout.panel
	NS:RunSafe("pet-frame", function()
		local width, height = frame:GetSize()
		frame:SetHitRectInsets(panel[1], width - panel[3], -panel[2], height + panel[4])
		AnchorAuras(frame, layout)

		local attacking = false
		frame:HookScript("OnUpdate", function()
			local now = PetAttackModeTexture and PetAttackModeTexture:IsShown() or false
			if now ~= attacking then
				attacking = now
				card:SetBorderAlert(now and NS.color.hostile or nil)
			end
		end)
	end)
	NS:RegisterPixelClient(function() AnchorAuras(frame, layout) end)
end

function M:Refresh()
	if self.card then
		self.card:Update()
	end
end
