-- AbsoluteUI: action bar buttons.
--
-- Only textures, font strings and cooldowns are touched, none of them
-- protected, so this also works in combat.

local _, NS = ...

local M = NS:NewModule("ActionBars", { setting = "actionBars" })

local BARS = {
	"MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
	"MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7",
	"StanceBar", "PetActionBar", "PossessActionBar",
}

-- Washes drawn over the icon.
local ACCENT = NS.color.accent
local STATE = {
	highlight = { 1, 1, 1, 0.15 },
	pushed    = { 1, 1, 1, 0.25 },
	checked   = { ACCENT[1], ACCENT[2], ACCENT[3], 0.35 },
	flash     = { 0.90, 0.15, 0.15, 0.35 },
	spell     = { ACCENT[1], ACCENT[2], ACCENT[3], 0.30 },
}

local skins = {}

-- Re-applied after UpdateButtonArt, which resets these atlases.
local function ApplyStateArt(button)
	NS:HideTextures(button:GetNormalTexture())
	local pushed = button:GetPushedTexture()
	NS:SetFlat(pushed, STATE.pushed, button.icon)
	if pushed then
		pushed:SetDrawLayer("OVERLAY", 1)
	end
end

local function UpdatePixels(button)
	local skin = skins[button]
	local px = NS:Px(button)
	local icon = button.icon
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", button, "TOPLEFT", px, -px)
	icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -px, px)
	skin.tile:ClearAllPoints()
	skin.tile:SetAllPoints(icon)
end

local function StyleText(fs, size, point, x, y, justify, width)
	if not fs then return end
	NS:StyleFont(fs, size, justify, true)
	fs:ClearAllPoints()
	fs:SetPoint(point, fs:GetParent(), point, x, y)
	-- Blizzard's fixed sizes are too small for outlined text.
	fs:SetSize(width, size + 3)
end

local function SkinButton(button)
	if not button or skins[button] or not button.icon then return end
	local skin = {}
	skins[button] = skin
	local icon = button.icon

	-- The black base shows as the 1px border around the tile.
	skin.shadow = NS:CreateShadow(button, button)
	skin.base = NS:CreateTexture(button, "BACKGROUND", -8, NS.color.border)
	skin.base:SetAllPoints(button)
	skin.tile = NS:CreateTexture(button, "BACKGROUND", -7, NS.color.tile)

	if button.IconMask then
		icon:RemoveMaskTexture(button.IconMask)
	end
	NS:CropIcon(icon)

	for _, key in ipairs({ "SlotArt", "SlotBackground", "Border" }) do
		NS:Kill(button[key])
	end

	NS:SetFlat(button:GetHighlightTexture(), STATE.highlight, icon)
	NS:SetFlat(button:GetCheckedTexture(), STATE.checked, icon)
	NS:SetFlat(button.Flash, STATE.flash, icon)
	NS:SetFlat(button.NewActionTexture, STATE.spell, icon)
	NS:SetFlat(button.SpellHighlightTexture, STATE.spell, icon)
	if button.QuickKeybindHighlightTexture then
		button.QuickKeybindHighlightTexture:ClearAllPoints()
		button.QuickKeybindHighlightTexture:SetAllPoints(icon)
	end

	for _, key in ipairs({ "cooldown", "lossOfControlCooldown", "chargeCooldown" }) do
		local cooldown = button[key]
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
		end
	end

	local width = button:GetWidth()
	local small = width < 40
	StyleText(button.HotKey, small and 9 or 11, "TOPRIGHT", -2, -3, "RIGHT", width - 4)
	StyleText(button.Count, small and 10 or 12, "BOTTOMRIGHT", -2, 3, "RIGHT", width - 4)
	StyleText(button.Name, small and 8 or 9, "BOTTOM", 0, 3, "CENTER", width - 4)

	ApplyStateArt(button)
	NS:Hook(button, "UpdateButtonArt", ApplyStateArt)
	UpdatePixels(button)
end

-- The classic main bar sits on Blizzard's big bar art (its counterpart of
-- BorderArt), and the stance and pet bars on backgrounds of their own. The
-- art frame keeps running its events, so only its textures go. The
-- gryphons stay, as on modern clients: Edit Mode's "Hide Bar Art" hides
-- them.
function M:HideClassicArt()
	NS:KillGlobals({
		"MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3",
		"MainMenuBarTextureExtender", "MainMenuBarMaxLevelBar", "MainMenuBarPerformanceBarFrame",
	})
	NS:KillAll(StanceBar, { "BackgroundArtLeft", "BackgroundArtMiddle", "BackgroundArtRight" })
	for _, texture in ipairs(PetActionBar and PetActionBar.BackgroundArtTextures or {}) do
		NS:Kill(texture)
	end
end

function M:Init()
	for _, barName in ipairs(BARS) do
		local bar = _G[barName]
		if bar and bar.actionButtons then
			for _, button in ipairs(bar.actionButtons) do
				SkinButton(button)
			end
		end
	end

	local main = MainActionBar
	if main then
		NS:Kill(main.BorderArt)
		NS:KeepDividersHidden(main)
	end
	if NS.isClassic then
		self:HideClassicArt()
	end

	NS:RegisterPixelClient(function()
		for button in pairs(skins) do UpdatePixels(button) end
	end)
end
