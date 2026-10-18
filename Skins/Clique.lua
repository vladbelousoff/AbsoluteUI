-- AbsoluteUI: Clique's binding window, spell catalog and spellbook tab.
--
-- Clique builds its window on first open (and never in combat); the skin
-- follows its InitializeLayout. The list rows come from a ScrollBox and
-- keep Clique's scripts; only their textures change.

local _, NS = ...

local M = NS:NewModule("Clique", { setting = "skinClique", addon = "Clique" })

local SELECTED = { 1, 1, 1, 0.10 }

---------------------------------------------------------------------------
-- Binding rows
---------------------------------------------------------------------------

local rows = {}

local function SkinRow(button)
	if rows[button] then return end
	rows[button] = true
	if button.Background then
		NS:SetFlat(button.Background, { 0, 0, 0, 0 }, button)
	end
	NS:SetFlat(button.FrameHighlight, NS.color.rowHover, button)
	if button.Icon then
		NS:CreateBox(button, button, button.Icon, NS.color.tile)
	end
	-- Clique clears and sets this per selection change.
	local pushed = button:GetPushedTexture()
	if pushed then NS:SetFlat(pushed, SELECTED, button) end
end

local function SyncRow(page, button)
	SkinRow(button)
	NS:CropIcon(button.Icon)
	local normal = button:GetNormalTexture()
	if normal and button.id ~= nil and button.id == page.selectedBind then
		NS:SetFlat(normal, SELECTED, button)
	end
end

local function SyncAllRows(page)
	for _, row in ipairs(page.bindRows or {}) do
		SyncRow(page, row)
	end
end

---------------------------------------------------------------------------
-- Windows
---------------------------------------------------------------------------

local function SkinWindow(frame)
	if not frame then return nil end
	local header = NS:SkinPanelFrame(frame)
	NS:SkinPanelPortrait(frame, header, frame.portrait)
	if not frame.GetTitleText and not frame.TitleContainer and frame.TitleText then
		-- Classic PortraitFrameTemplate
		NS:StyleFont(frame.TitleText, 12, "CENTER")
		frame.TitleText:ClearAllPoints()
		frame.TitleText:SetPoint("LEFT", header, "LEFT", NS.panelStyle.header, 0)
		frame.TitleText:SetPoint("RIGHT", header, "RIGHT", -NS.panelStyle.header, 0)
	end
	return header
end

local function SkinCatalog(window)
	local cf = window and window.frame
	if not cf then return end
	SkinWindow(cf)
	NS:SkinTextDropdown(cf.filterButton, 20)
	for _, key in ipairs({ "next", "prev" }) do
		local button = cf[key]
		if button then
			NS:HideTextures(button.bg)
			NS:SkinArrowButton(button, key == "next" and "right" or "left")
		end
	end
	if cf.tabSystem then
		NS:SkinTabSystem(cf.tabSystem, { insetX = 1, insetY = 4 })
	end
	for _, button in ipairs(cf.buttons or {}) do
		NS:CreateBox(button, button, button, NS.color.tile)
		NS:SetFlat(button:GetHighlightTexture(), NS.color.glyphHover, button)
	end
	NS:SkipDescendant(cf.filterButton, cf.tabSystem)

	local function SyncIcons()
		for _, button in ipairs(cf.buttons or {}) do
			NS:CropIcon(button.background)
		end
	end
	NS:Hook(window, "UPDATE_CATALOG_WINDOW", SyncIcons)
	SyncIcons()
end

local tabSkinned = false

local function SkinSpellbookTab(tab)
	if not tab or tabSkinned then return end
	tabSkinned = true
	NS:Kill(tab.bg)
	local tile = NS:CreateTile(tab, 0, 0, NS.color.tile)
	tile.icon = tab:GetNormalTexture()
	tile:Layout()
	NS:CropIcon(tile.icon)
	NS:SetFlat(tab:GetHighlightTexture(), NS.color.glyphHover, tile.fill)
end

local done = false

local function SkinConfig(config)
	if done or not (config.ui and config.ui.initialized) then return end
	done = true
	SkinWindow(config.ui)

	local browse = config.BrowsePage
	local frame = browse and browse.frame
	if frame then
		NS:SkinTextDropdown(frame.OptionsButton, 20)
		NS:SkipDescendant(frame.OptionsButton)
		NS:Hook(browse, "InitializeBindingRow", SyncRow)
		NS:Hook(browse, "SelectBindRow", SyncAllRows)
		SyncAllRows(browse)
	end
	SkinCatalog(config.CatalogWindow)

	-- Buttons, checkboxes, backdrops, scroll bars and the option lists of
	-- every page.
	NS:SkinDescendants(config.ui)
end

function M:Init()
	local clique = _G.Clique
	local config = clique and clique.GetBindingConfig and clique:GetBindingConfig()
	if not config then
		NS:Missing("Clique binding config")
		return
	end
	NS:Hook(config, "InitializeLayout", SkinConfig)
	SkinConfig(config)

	SkinSpellbookTab(clique.spellbookTab)
	NS:Hook(clique, "ShowSpellBookButton", function(addon) SkinSpellbookTab(addon.spellbookTab) end)
end
