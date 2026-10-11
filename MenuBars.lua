-- AbsoluteUI: bag bar and micro menu.
--
-- The module always runs so the hide options work without the restyle,
-- which follows the "actionBars" setting.

local _, NS = ...

local M = NS:NewModule("MenuBars")

local BAG_BUTTONS = {
	"MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot",
	"CharacterBag2Slot", "CharacterBag3Slot", "CharacterReagentBag0Slot", "KeyRingButton",
}

local MICRO_BUTTONS = {
	"CharacterMicroButton", "ProfessionMicroButton", "PlayerSpellsMicroButton",
	"SpellbookMicroButton", "TalentMicroButton", "AchievementMicroButton",
	"LegacyMicroButton", "QuestLogMicroButton", "HousingMicroButton",
	"GuildMicroButton", "LFDMicroButton", "CollectionsMicroButton",
	"EJMicroButton", "HelpMicroButton", "StoreMicroButton", "MainMenuMicroButton",
}

-- Micro buttons are 32x40 but laid out 5px overlapping; the tile covers
-- the visible part so neighbors sit 1px apart.
local MICRO_INSET_X, MICRO_INSET_Y = 3, 4

local ACCENT = NS.color.accent
local STATE = {
	highlight = { 1, 1, 1, 0.35 },  -- Blizzard draws bag highlights at 40% alpha
	pushed    = { 1, 1, 1, 0.25 },
	open      = { ACCENT[1], ACCENT[2], ACCENT[3], 0.30 },
	alert     = { ACCENT[1], ACCENT[2], ACCENT[3], 0.25 },
}

local tiles = {}

---------------------------------------------------------------------------
-- Bag buttons
---------------------------------------------------------------------------

-- Re-applied after Blizzard's UpdateTextures, which resets these atlases.
local function ApplyBagState(button)
	local tile = tiles[button]
	if not tile then return end
	NS:HideTextures(button:GetNormalTexture())
	NS:SetFlat(button:GetPushedTexture(), STATE.pushed, tile.fill)
	NS:SetFlat(button:GetHighlightTexture(), STATE.highlight, tile.fill)
	NS:SetFlat(button.SlotHighlightTexture, STATE.open, tile.fill)
end

local function SkinBagButton(button)
	if not button or tiles[button] or not button.icon then return end
	local tile = NS:CreateTile(button)
	tiles[button] = tile
	tile.icon = button.icon
	tile:Layout()

	for _, key in ipairs({ "SquareMask", "CircleMask", "IconMask" }) do
		if button[key] then
			button.icon:RemoveMaskTexture(button[key])
		end
	end
	NS:CropIcon(button.icon)
	NS:Kill(button.IconBorder)

	for _, key in ipairs({ "Count", "FreeSlots" }) do
		local fs = button[key]
		if fs then
			local _, size = fs:GetFont()
			NS:StyleFont(fs, math.max(10, math.min(size or 12, 13)), "RIGHT", true)
		end
	end

	NS:Hook(button, "UpdateTextures", ApplyBagState)
	ApplyBagState(button)
end

---------------------------------------------------------------------------
-- Micro buttons
---------------------------------------------------------------------------

local function SkinMicroButton(button)
	if not button or tiles[button] then return end
	local tile = NS:CreateTile(button, MICRO_INSET_X, MICRO_INSET_Y)
	tiles[button] = tile

	for _, key in ipairs({ "Background", "PushedBackground", "Shadow", "PushedShadow" }) do
		NS:Kill(button[key])
	end
	NS:SetFlat(button.FlashBorder, STATE.alert, tile.fill)
end

---------------------------------------------------------------------------
-- Hiding. Hidden bars come back while Edit Mode is open so they stay
-- movable.
---------------------------------------------------------------------------

local hideOptions = {} -- [frame] = setting key
local hiddenByUs = {}

local function InEditMode()
	return EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
end

local function UpdateVisibility(frame)
	local key = hideOptions[frame]
	if not key then return end
	if NS.db[key] and not InEditMode() then
		if frame:IsShown() then
			hiddenByUs[frame] = true
			-- Edit Mode's Hide override would unsnap frames attached to
			-- this bar and change the layout; the base Hide doesn't.
			local hide = frame.HideBase or frame.Hide
			hide(frame)
		end
	elseif hiddenByUs[frame] then
		hiddenByUs[frame] = nil
		frame:Show()
	end
end

function M:UpdateVisibility()
	for frame in pairs(hideOptions) do
		UpdateVisibility(frame)
	end
end

function M:InitVisibility()
	if BagsBar then hideOptions[BagsBar] = "hideBags" end
	if MicroMenuContainer then hideOptions[MicroMenuContainer] = "hideMicroMenu" end
	for frame in pairs(hideOptions) do
		frame:HookScript("OnShow", UpdateVisibility) -- Blizzard re-shows them
	end
	if EventRegistry then
		EventRegistry:RegisterCallback("EditMode.Enter", function() M:UpdateVisibility() end, M)
		EventRegistry:RegisterCallback("EditMode.Exit", function() M:UpdateVisibility() end, M)
	end
	self:UpdateVisibility()
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Skin()
	for _, name in ipairs(BAG_BUTTONS) do
		SkinBagButton(_G[name])
	end
	if MainMenuBarBagManager and MainMenuBarBagManager.EnumerateBagButtons then
		for _, button in MainMenuBarBagManager:EnumerateBagButtons() do
			SkinBagButton(button)
		end
	end

	for _, name in ipairs(MICRO_BUTTONS) do
		SkinMicroButton(_G[name])
	end

	if BagsBar then
		NS:Kill(BagsBar.BorderArt)
		NS:KeepDividersHidden(BagsBar)
	end
	if MicroMenu then
		NS:Kill(MicroMenu.BorderArt)
		NS:Kill(MicroMenu.BackgroundArt)
	end
end

function M:Init()
	self:InitVisibility()
	if NS.db.actionBars then
		self:Skin()
	end
end

function M:Refresh()
	self:UpdateVisibility()
end
