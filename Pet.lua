-- AbsoluteUI: pet frame.
--
-- Edit Mode places the pet frame; its card is laid out inside it
-- (NS.layouts.pet), like the target of target's. While the pet attacks,
-- the card's border turns red, where Blizzard pulses a red glow.

local _, NS = ...

local M = NS:NewModule("Pet")

function M:Init()
	local frame = PetFrame
	if not frame then
		NS:Missing("PetFrame")
		return
	end

	-- The attack glow keeps toggling while hidden; the border follows it below.
	for _, region in ipairs({
		PetFrameTexture, PetPortrait, frame.PortraitMask, PetFrameFlash, PetAttackModeTexture, PetHitIndicator,
	}) do
		NS:Kill(region)
	end
	NS:HideProtectedBars("pet-bars", PetFrameHealthBar, PetFrameManaBar)

	local card = NS:CreateUnitCard(frame, {
		layout = NS.layouts.pet,
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
	local panel = NS.layouts.pet.panel
	NS:RunSafe("pet-frame", function()
		local width, height = frame:GetSize()
		frame:SetHitRectInsets(panel[1], width - panel[3], -panel[2], height + panel[4])

		local attacking = false
		frame:HookScript("OnUpdate", function()
			local now = PetAttackModeTexture and PetAttackModeTexture:IsShown() or false
			if now ~= attacking then
				attacking = now
				card:SetBorderAlert(now and NS.color.hostile or nil)
			end
		end)
	end)
end

function M:Refresh()
	if self.card then
		self.card:Update()
	end
end
