-- luacheck configuration for AbsoluteUI (WoW Forever, Lua 5.1).
-- Run from the addon folder: luacheck .
--
-- Every WoW global the addon touches is listed below, so a typo in a
-- global name shows up as a warning. Add new globals here when using them.

std = "lua51"
max_line_length = 130
codes = true

ignore = {
	"212/self", -- methods that don't use self
}

-- Globals the addon defines.
globals = {
	"AbsoluteUIDB",
	"AbsoluteUI_OnAddonCompartmentClick",
	"SLASH_ABSOLUTEUI1",
	"SLASH_ABSOLUTEUI2",
	"SlashCmdList",
	"StaticPopupDialogs",
}

read_globals = {
	-- Lua extensions
	"geterrorhandler", "hooksecurefunc", "issecretvalue", "strtrim", "wipe",

	-- Frames and widget API
	"CreateColor", "CreateFont", "CreateFontFamily", "CreateFrame", "CreateFromMixins",
	"Mixin", "PixelUtil", "SetPortraitTexture", "UIParent", "HideUIPanel", "ShowUIPanel",
	"InCombatLockdown",

	-- C namespaces and enums
	"C_AddOns", "C_CVar", "C_ClassColor", "C_CurveUtil", "C_GameRules", "C_Item",
	"C_StringUtil", "C_Timer", "C_UnitAuras", "CurveConstants", "Enum",

	-- Unit API
	"UnitCanAttack", "UnitClass", "UnitClassification", "UnitExists", "UnitGUID",
	"UnitGetTotalAbsorbs", "UnitHealth", "UnitHealthMax", "UnitHealthPercent",
	"UnitIsConnected", "UnitIsDead", "UnitIsDeadOrGhost", "UnitIsFriend", "UnitIsGhost",
	"UnitIsOtherPlayersPet", "UnitIsOwnerOrControllerOfUnit", "UnitIsPlayer",
	"UnitIsTapDenied", "UnitIsUnit", "UnitIsVisible", "UnitPower", "UnitPowerMax",
	"UnitPowerType", "UnitReaction", "UnitCastingInfo", "UnitChannelInfo", "GetNetStats",

	-- Formatting and colors
	"AbbreviateNumbers", "CLASS_ICON_TCOORDS", "DebuffTypeColor", "ITEM_QUALITY_COLORS",
	"PowerBarColor", "RAID_CLASS_COLORS",
	"DEBUFF_TYPE_BLEED_COLOR", "DEBUFF_TYPE_CURSE_COLOR", "DEBUFF_TYPE_DISEASE_COLOR",
	"DEBUFF_TYPE_MAGIC_COLOR", "DEBUFF_TYPE_NONE_COLOR", "DEBUFF_TYPE_POISON_COLOR",
	"DEAD", "GHOST", "PLAYER_OFFLINE", "PLAYER_UNITS",

	-- Shared Blizzard UI code
	"AuraUtil", "EventRegistry", "MinimalSliderWithSteppersMixin", "ScrollBoxListMixin",
	"ScrollUtil", "Settings", "CreateSettingsListSectionHeaderInitializer",
	"TooltipDataProcessor", "TooltipUtil", "StaticPopup_Show", "ReloadUI",

	-- Blizzard frames we restyle
	"BagItemSearchBox", "BagsBar", "C_Container", "ContainerFrameCombinedBags", "ContainerFrameContainer", "DamageMeter", "EditModeManagerFrame", "GameTooltip", "LootFrame",
	"MainActionBar", "MainMenuBarBagManager", "MicroMenu", "MicroMenuContainer",
	"ObjectiveTrackerFrame", "ObjectiveTrackerManager", "PlayerCastingBarFrame",
	"PlayerFrame", "PlayerFrame_GetManaBar", "PlayerLevelText", "PlayerName",
	"FocusFrame", "SettingsPanel", "TargetFrame",
	"PlayerSpellsFrame", "TalentButtonUtil", "TalentFrameBaseMixin",
	"MenuStyle1Mixin", "MenuVariants",
	"GossipFrame", "QuestFrame", "QuestFrameGreetingPanel", "QuestFramePortrait",
	"QuestGreetingFrameHorizontalBreak", "QuestProgressRequiredMoneyText",
	"QuestDetailScrollChildFrame", "QuestRewardScrollChildFrame",
	"QuestInfoFrame", "QuestInfoItemHighlight", "QuestInfoRewardsFrame",
	"GetMaterialTextColors", "QuestTextContrast",
	"PetFrame", "PetFrameTexture", "PetPortrait", "PetFrameFlash", "PetAttackModeTexture",
	"PetHitIndicator", "PetFrameHealthBar", "PetFrameManaBar", "PetName",
}
