-- AbsoluteUI: settings panel (Options > AddOns > AbsoluteUI).
--
-- An overview page with actions and slash commands, then one page per
-- `page` group of NS.settingsSchema (Settings.lua).

local ADDON, NS = ...

local M = NS:NewModule("Options")

local VARIABLE_PREFIX = "ABSOLUTEUI_"
local RELOAD_NOTE = "|cffff6060Takes effect after a UI reload.|r"
local PAD = 7 -- Blizzard's settings page inset

---------------------------------------------------------------------------
-- Dialogs
---------------------------------------------------------------------------

local function DefineDialogs()
	if not StaticPopupDialogs then return false end
	StaticPopupDialogs.ABSOLUTEUI_RELOAD = {
		text = "Some AbsoluteUI changes take effect after reloading the interface.",
		button1 = "Reload Now",
		button2 = "Later",
		OnAccept = function() ReloadUI() end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopupDialogs.ABSOLUTEUI_RESET = {
		text = "Restore all AbsoluteUI settings to their defaults?",
		button1 = "Reset",
		button2 = "Cancel",
		OnAccept = function() NS:ResetSettings() end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	return true
end

local reloadQueued = false

-- Asks once the settings panel closes, so toggling several options gives
-- one prompt (and none when they were switched back).
local function PromptReload()
	if not NS:IsReloadPending() then return end
	if SettingsPanel and SettingsPanel:IsShown() then
		reloadQueued = true
	else
		StaticPopup_Show("ABSOLUTEUI_RELOAD")
	end
end

local function OpenEditMode()
	if InCombatLockdown() then
		NS:Print("Edit Mode can't be opened in combat.")
		return
	end
	if SettingsPanel and SettingsPanel:IsShown() then
		HideUIPanel(SettingsPanel)
	end
	if EditModeManagerFrame then
		ShowUIPanel(EditModeManagerFrame)
	end
end

local function ConfirmReset()
	if StaticPopupDialogs and StaticPopupDialogs.ABSOLUTEUI_RESET then
		StaticPopup_Show("ABSOLUTEUI_RESET")
	else
		NS:ResetSettings()
	end
end

---------------------------------------------------------------------------
-- Overview page
---------------------------------------------------------------------------

local function Metadata(field)
	return C_AddOns and C_AddOns.GetAddOnMetadata(ADDON, field)
end

local function Text(parent, font, justify)
	local fs = parent:CreateFontString(nil, "ARTWORK", font)
	fs:SetJustifyH(justify or "LEFT")
	fs:SetJustifyV("TOP")
	return fs
end

-- Native section header: large white title, spaced like the settings list.
local function SectionHeader(parent, anchor, title)
	local fs = Text(parent, "GameFontHighlightLarge")
	fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -26)
	fs:SetText(title)
	return fs
end

local function Button(parent, text, tooltip, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetText(text)
	button:SetSize(math.max(140, button:GetFontString():GetStringWidth() + 32), 24)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 1, 1)
		GameTooltip:AddLine(tooltip, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return button
end

local function CreateOverview()
	local frame = CreateFrame("Frame")
	frame:Hide()

	local title = Text(frame, "GameFontHighlightHuge")
	title:SetPoint("TOPLEFT", PAD, -22)
	title:SetText(ADDON)

	local version = Text(frame, "GameFontDisable")
	version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
	version:SetText("Version " .. NS.version)

	local divider = frame:CreateTexture(nil, "ARTWORK")
	divider:SetPoint("TOP", 0, -50)
	if not pcall(divider.SetAtlas, divider, "Options_HorizontalDivider", true) then
		divider:SetColorTexture(1, 1, 1, 0.15)
		divider:SetPoint("LEFT", PAD, 0)
		divider:SetPoint("RIGHT", -PAD, 0)
		divider:SetHeight(1)
	end

	local about = Text(frame, "GameFontHighlight")
	about:SetPoint("TOPLEFT", PAD, -66)
	about:SetPoint("TOPRIGHT", -PAD * 4, -66)
	about:SetSpacing(3)
	about:SetText((Metadata("Notes") or "") .. "\n\n"
		.. "Move and scale frames in Edit Mode. Everything else is in the pages on the left.")

	local actions = SectionHeader(frame, about, "Actions")
	local editMode = Button(frame, "Open Edit Mode",
		"Move and scale frames and castbars.", OpenEditMode)
	editMode:SetPoint("TOPLEFT", actions, "BOTTOMLEFT", 0, -12)
	local reset = Button(frame, "Reset Settings",
		"Back to default settings. Your Edit Mode layout isn't touched.", ConfirmReset)
	reset:SetPoint("LEFT", editMode, "RIGHT", 8, 0)
	local reload = Button(frame, "Reload UI",
		"Applies changes that need a reload.", function() ReloadUI() end)
	reload:SetPoint("LEFT", reset, "RIGHT", 8, 0)

	local commands = SectionHeader(frame, editMode, "Slash Commands")
	local previous = commands
	for i, command in ipairs(NS:GetSlashCommands()) do
		local name = Text(frame, "GameFontNormal")
		name:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, i == 1 and -12 or -6)
		name:SetText(command[1])
		local help = Text(frame, "GameFontHighlight")
		help:SetPoint("TOPLEFT", name, "TOPLEFT", 130, 0)
		help:SetText(command[2]:sub(1, 1):upper() .. command[2]:sub(2) .. ".")
		previous = name
	end

	local author = Metadata("Author")
	if author then
		local credit = Text(frame, "GameFontDisableSmall")
		credit:SetPoint("BOTTOMLEFT", PAD, 12)
		credit:SetText("By " .. author)
	end
	return frame
end

---------------------------------------------------------------------------
-- Setting pages
---------------------------------------------------------------------------

-- Some settings explain themselves and only carry the reload note.
local function Tooltip(entry)
	local text = entry.tooltip
	if entry.apply == "reload" then
		text = text and (text .. "\n\n" .. RELOAD_NOTE) or RELOAD_NOTE
	end
	return text or ""
end

-- One control per setting kind, each returning its initializer. A kind this
-- client can't draw is left out; its setting still works.
local controls = {}

function controls.toggle(category, setting, entry)
	return Settings.CreateCheckbox(category, setting, Tooltip(entry))
end

function controls.choice(category, setting, entry)
	local function GetOptions()
		local container = Settings.CreateControlTextContainer()
		for _, choice in ipairs(NS:GetSettingChoices(entry)) do
			container:Add(choice[1], choice[2])
		end
		return container:GetData()
	end
	return Settings.CreateDropdown(category, setting, GetOptions, Tooltip(entry))
end

function controls.range(category, setting, entry)
	if not (Settings.CreateSlider and Settings.CreateSliderOptions) then return end
	local options = Settings.CreateSliderOptions(entry.min, entry.max, entry.step or 1)
	if MinimalSliderWithSteppersMixin and options.SetLabelFormatter then
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
	end
	return Settings.CreateSlider(category, setting, options, Tooltip(entry))
end

local function RegisterSetting(category, entry)
	local setting = Settings.RegisterAddOnSetting(category, VARIABLE_PREFIX .. entry.key:upper(),
		entry.key, NS.db, type(entry.default), entry.label, entry.default)
	setting:SetValueChangedCallback(function() NS:ApplySetting(entry.key) end)
	NS.settingObjects[entry.key] = setting
	return setting
end

-- Greys out (and indents) a control while its parent toggle is off.
local function SetParent(initializer, parentKey, initializers)
	local parent, parentSetting = initializers[parentKey], NS.settingObjects[parentKey]
	if initializer and parent and parentSetting and initializer.SetParentInitializer then
		initializer:SetParentInitializer(parent, function() return parentSetting:GetValue() end)
	end
end

-- Settings for addons that aren't installed are left out.
local function VisibleSchema()
	local list = {}
	for _, entry in ipairs(NS.settingsSchema) do
		if not entry.addon or NS:IsAddOnInstalled(entry.addon) then
			table.insert(list, entry)
		end
	end
	return list
end

-- A section header is added with the first setting of its section, so
-- sections with nothing to show don't get one.
local function BuildPages(root)
	local category, layout, section
	local initializers = {}
	for _, entry in ipairs(VisibleSchema()) do
		if entry.page then
			category, layout = Settings.RegisterVerticalLayoutSubcategory(root, entry.page)
			section = nil
		elseif entry.section then
			section = entry.section
		elseif controls[entry.kind] then
			if section and CreateSettingsListSectionHeaderInitializer then
				layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(section))
			end
			section = nil
			local setting = RegisterSetting(category, entry)
			local ok, initializer = NS.SafeCall(controls[entry.kind], category, setting, entry)
			if ok then
				initializers[entry.key] = initializer
				if entry.parent then
					SetParent(initializer, entry.parent, initializers)
				end
			end
		else
			NS:Missing("option control: " .. tostring(entry.kind))
		end
	end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Init()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterVerticalLayoutSubcategory) then
		NS:Missing("Settings API")
		return
	end

	local root = Settings.RegisterCanvasLayoutCategory(CreateOverview(), ADDON)
	self.category = root
	BuildPages(root)
	Settings.RegisterAddOnCategory(root)

	if DefineDialogs() then
		NS.PromptReload = PromptReload
		if EventRegistry then
			EventRegistry:RegisterCallback("SettingsPanel.OnHide", function()
				if reloadQueued then
					reloadQueued = false
					PromptReload()
				end
			end, M)
		end
	end
end

function NS:OpenOptions()
	if M.category and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(M.category:GetID())
	else
		NS:Print("Settings are unavailable. Type /aui help for commands.")
	end
end
