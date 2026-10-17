-- AbsoluteUI: swing timers (main hand, off hand, ranged).
--
-- Edit Mode places and sizes the timers; they get the castbar look in
-- place: a flat bar in a box, colored per hand, with a spark at the fill
-- end. Out of range, Blizzard dims the bar and our box with it.

local _, NS = ...

local M = NS:NewModule("SwingTimer", { setting = "swingTimer", addon = "Blizzard_SwingTimer", flavor = "modern" })

local TIMERS = {
	SwingTimerMainHandFrame = "mainHand",
	SwingTimerOffHandFrame = "offHand",
	SwingTimerRangedFrame = "ranged",
}

local function SkinTimer(frame, color)
	local bar = frame.StatusBar
	if not bar then
		NS:Missing("SwingTimer StatusBar")
		return
	end
	-- Blizzard sets the art's alpha for range, so it's moved away instead.
	for _, region in ipairs({ frame.Background, frame.Border, bar.Pip, bar.TypeLabelShadow }) do
		NS:Kill(region)
	end

	NS:RegisterBar(bar)
	bar:SetStatusBarColor(color[1], color[2], color[3])
	local box = NS:CreateBox(bar, bar, bar, NS.color.tile)
	local k = NS.HEALTH_BG_FACTOR
	box.bg:SetVertexColor(color[1] * k, color[2] * k, color[3] * k, 1)
	NS:CreateShadow(bar, box.base)

	local spark = NS:CreateTexture(bar, "OVERLAY", 7)
	spark:SetVertexColor(1, 1, 1, 0.8)
	spark:Hide()
	local anchoredTo
	bar:HookScript("OnValueChanged", function(self, value)
		-- The bar texture setting can swap the fill texture.
		local fill = self:GetStatusBarTexture()
		if fill and fill ~= anchoredTo then
			anchoredTo = fill
			spark:ClearAllPoints()
			spark:SetPoint("TOP", fill, "TOPRIGHT")
			spark:SetPoint("BOTTOM", fill, "BOTTOMRIGHT")
		end
		spark:SetShown(value > 0 and value < 1)
	end)
	local function UpdatePixels()
		spark:SetWidth(NS:Px(bar) * 2)
	end
	UpdatePixels()
	NS:RegisterPixelClient(UpdatePixels)

	NS:StyleBarText(bar.TypeLabel, 11, "LEFT")
	NS:StyleBarText(bar.TimeLabel, 11, "RIGHT")
end

function M:Init()
	for name, key in pairs(TIMERS) do
		local frame = _G[name]
		if frame then
			SkinTimer(frame, NS.swingColor[key])
		else
			NS:Missing(name)
		end
	end
end
