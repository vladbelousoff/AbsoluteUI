-- AbsoluteUI: character window (CharacterFrame).
--
--   | [icon]               Name                 [x] |  header
--   | +------- gear and model -------+ +- pane --+ |
--   | | Level 60 Orc Warrior      [<]| | [tabs]  | |  [mode tabs]
--   | | [slots]    model     [slots] | | stats   | |
--   | +------------------------------+ +---------+ |
--
-- WoW Forever's window: the character on the left, a collapsible pane on
-- the right (stats, gear sets, titles, pet stats) and a column of mode tabs
-- outside the window. The other modes (reputation, skills, currencies,
-- statistics) are a list on the left and a details pane on the right, built
-- from the same few templates, so one set of skins covers them all.
--
-- Equipment slots are secure, so they only get textures and post-hooks.
-- They are skinned here for both clients; the TBC window is in
-- Classic/CharacterFrame.lua.

local _, NS = ...

local M = NS:NewModule("Character", { setting = "characterFrame", flavor = "modern" })

local ACCENT = NS.color.accent
local ROW_HOVER = NS.color.rowHover
local TAB_HOVER = { 1, 1, 1, 0.12 }
local STRIPE = { 1, 1, 1, 0.035 } -- every other row of a list
local SELECTED = { ACCENT[1], ACCENT[2], ACCENT[3], 0.2 }
local WHITE = { 1, 1, 1 }

---------------------------------------------------------------------------
-- Equipment slots (both clients): icon tiles with the item quality on the
-- border, like bag slots. Empty slots show Blizzard's slot icon, dimmed.
---------------------------------------------------------------------------

local SLOTS = {
	"Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
	"Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1",
	"MainHand", "SecondaryHand", "Ranged", "Ammo",
}
local SLOT_HOVER = { 1, 1, 1, 0.15 }
local SLOT_PUSHED = { 1, 1, 1, 0.25 }
local EMPTY_ALPHA = 0.5
local MIN_QUALITY = 2 -- uncommon; poor and common items keep a plain border

local slots = {} -- [button] = tile

-- After every PaperDollItemSlotButton_Update.
local function SyncSlot(button)
	local tile = slots[button]
	if not tile then return end
	local id = button:GetID()
	local hasItem = GetInventoryItemTexture("player", id) ~= nil
	NS:CropIcon(tile.icon)
	tile.icon:SetAlpha(hasItem and 1 or EMPTY_ALPHA)
	local quality = hasItem and GetInventoryItemQuality("player", id)
	if quality and quality >= MIN_QUALITY then
		tile:SetBorderColor(NS:QualityColor(quality))
	else
		tile:SetBorderColor(unpack(NS.color.border))
	end
end

-- The ammo slot isn't built from the slot template: its art sits on the
-- button and, on Forever, an arrow on a child frame.
local function HideAmmoArt(button)
	NS:HideRegions(button, "BACKGROUND")
	NS:HideRegions(button, "OVERLAY")
	for _, child in ipairs({ button:GetChildren() }) do
		if child:GetObjectType() == "Frame" then
			NS:HideRegions(child)
		end
	end
end

local function SkinSlot(button)
	local name = button:GetName()
	local icon = button.icon or _G[name .. "IconTexture"]
	if not icon then return end
	if name == "CharacterAmmoSlot" then
		HideAmmoArt(button)
	end
	local tile = NS:CreateTile(button)
	slots[button] = tile
	tile.icon = icon
	tile:Layout()

	-- Quality shows on the tile's border instead.
	NS:HideTextures(button:GetNormalTexture(), button.IconBorder)
	NS:HideRegions(button.BorderFrame)
	NS:SetFlat(button:GetPushedTexture(), SLOT_PUSHED, tile.fill)
	NS:SetFlat(button:GetHighlightTexture(), SLOT_HOVER, tile.fill)
	local cooldown = button.Cooldown or _G[name .. "Cooldown"]
	if cooldown then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(tile.fill)
	end
	if button.Count then
		NS:StyleFont(button.Count, 12, "RIGHT", true)
	end
end

function NS:SkinCharacterSlots()
	for _, slot in ipairs(SLOTS) do
		local button = _G["Character" .. slot .. "Slot"]
		if button then
			SkinSlot(button)
		else
			NS:Missing("Character" .. slot .. "Slot")
		end
	end
	NS:Hook(nil, "PaperDollItemSlotButton_Update", SyncSlot)
	for button in pairs(slots) do
		SyncSlot(button)
	end
end

---------------------------------------------------------------------------
-- Layout
--
-- Blizzard's panes start PANE_TOP below the window's top, the paperdoll's
-- level strip is STRIP tall from there. The boxes start below our header.
---------------------------------------------------------------------------

local MARGIN = NS.panelStyle.margin
local PANE_TOP = 20
local STRIP = 36
local BOX_TOP = 2 * MARGIN + NS.panelStyle.header - PANE_TOP -- from the pane's top
local CONTROL = 20
local SIDE_TAB = 34      -- mode tab tiles, outside the window
local SIDE_TAB_GAP = 2   -- between the window and the tiles, and between tiles
local SIDEBAR_INSET = 4  -- stats/gear/titles tab tiles in their 42x42 buttons
local CATEGORY_INSET = 8 -- category bands in the 40 tall stat headers
local BAR_HEIGHT = 16    -- reputation and skill bars, room for their text
local ENTRY_TEXT_X = 10  -- list entry names, as far in as the header titles

local function Rect(frame, left, top, right, bottom)
	local rect = frame:CreateTexture()
	rect:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
	rect:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -right, bottom)
	return rect
end

-- Textures already cropped (atlases, Blizzard's own crop) are left alone.
local function CropIfPlain(texture)
	if not texture then return end
	local left, top, _, _, _, _, right, bottom = texture:GetTexCoord()
	if left == 0 and top == 0 and right == 1 and bottom == 1 then
		NS:CropIcon(texture)
	end
end

-- Runs skin(frame) on every frame of the scroll box, now and as Blizzard
-- initializes them.
local function WatchScrollBox(scrollBox, skin)
	if not scrollBox then return end
	if ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
		ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, frame) skin(frame) end, M)
	end
	if scrollBox.ForEachFrame then
		scrollBox:ForEachFrame(skin)
	end
end

local function AddHover(frame, region)
	local hover = NS:CreateTexture(frame, "HIGHLIGHT", 0, ROW_HOVER)
	hover:SetAllPoints(region or frame)
	return hover
end

-- Three-slice buttons (SharedButtonSmallTemplate and alike) as tiles.
-- Blizzard swaps the slices' atlases on every state change.
local function SkinSliceButton(button)
	if not button then return end
	NS:HideRegions(button)
	local tile = NS:CreateTile(button, 0, 0, NS.color.tile, true)
	AddHover(button, tile.fill)
end

---------------------------------------------------------------------------
-- Colored progress bars (reputation, skills, pet experience): a flat bar in
-- a box. Blizzard picks a red, green, blue or white atlas for the fill and
-- tints it; ours uses the bar texture with the same tint.
---------------------------------------------------------------------------

local coloredBars = {} -- [bar] = { percent, tint, color }

local function BarTint(colorType)
	local types = ColoredProgressBarMixin and ColoredProgressBarMixin.ColorType
	if types then
		if colorType == types.Red then return NS.color.hostile end
		if colorType == types.Green then return NS.color.friendly end
		if colorType == types.Blue then return NS.trackingColor.renown end
	end
	return WHITE
end

-- The fill's atlas before we took over.
local function TintFromAtlas(fill)
	local atlas = fill:GetAtlas()
	atlas = type(atlas) == "string" and atlas:lower() or ""
	if atlas:find("red") then return NS.color.hostile end
	if atlas:find("green") then return NS.color.friendly end
	if atlas:find("blue") then return NS.trackingColor.renown end
	return WHITE
end

-- After every fill change. Setting an atlas also resets the fill's size.
local function DrawColoredBar(bar)
	local state = coloredBars[bar]
	if not state then return end
	local fill = bar.Fill
	fill:SetTexture(NS:GetBarTexture())
	fill:SetTexCoord(0, math.max(state.percent, 0.001), 0, 1)
	fill:SetHeight(BAR_HEIGHT)
	fill:SetWidth(state.percent * bar.FillArea:GetWidth())
	fill:SetShown(state.percent > 0)
	local t, c = state.tint, state.color
	fill:SetVertexColor(t[1] * c[1], t[2] * c[2], t[3] * c[3])
end

local function SkinColoredBar(bar)
	if not bar or coloredBars[bar] or not (bar.Fill and bar.FillArea) then return end
	local fill = bar.Fill
	local width = bar.FillArea:GetWidth()
	local r, g, b = fill:GetVertexColor()
	coloredBars[bar] = {
		percent = width > 0 and math.min(fill:GetWidth() / width, 1) or 0,
		tint = TintFromAtlas(fill),
		color = { r, g, b },
	}

	NS:HideRegions(bar, "BACKGROUND")
	if bar.Mask then
		fill:RemoveMaskTexture(bar.Mask)
	end
	local track = bar:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("LEFT", bar.FillArea, "LEFT")
	track:SetPoint("RIGHT", bar.FillArea, "RIGHT")
	track:SetHeight(BAR_HEIGHT)
	NS:CreateBox(bar, bar, track, NS.color.powerBg)
	if bar.Text then
		NS:StyleFont(bar.Text, 11, "CENTER", true)
	end

	NS:Hook(bar, "SetFillPercent", function(self, percent)
		coloredBars[self].percent = math.min(math.max(percent or 0, 0), 1)
		DrawColoredBar(self)
	end)
	NS:Hook(bar, "SetFillTextureByColorType", function(self, colorType)
		coloredBars[self].tint = BarTint(colorType)
		DrawColoredBar(self)
	end)
	if bar.UpdateBarColor then
		NS:Hook(bar, "UpdateBarColor", function(self, color)
			if color and color.GetRGB then
				coloredBars[self].color = { color:GetRGB() }
				DrawColoredBar(self)
			end
		end)
	end
	DrawColoredBar(bar)
end

NS:OnSettingChanged("barTexture", function()
	for bar in pairs(coloredBars) do
		DrawColoredBar(bar)
	end
end)

---------------------------------------------------------------------------
-- Window: panel and header, a box for each pane.
---------------------------------------------------------------------------

local function SkinPortrait(frame, header)
	local portrait = NS:SkinPanelPortrait(frame, header)
	if not portrait then return end
	-- The paperdoll shows the spec icon, the other modes the player.
	local function Crop() CropIfPlain(portrait) end
	NS:Hook(frame, "UpdatePortrait", Crop)
	Crop()
end

-- Returns the left pane's box rect.
local function SkinPanes(frame)
	local left, right = frame.LeftPaneHost, frame.RightPaneHost
	NS:HideRegions(left)
	-- The stat pane's stone header, and the divider frame between the panes.
	NS:HideRegions(right)
	for _, child in ipairs({ right:GetChildren() }) do
		NS:HideRegions(child)
	end

	local leftRect = Rect(left, MARGIN, BOX_TOP, MARGIN, MARGIN)
	NS:CreateBox(left, left, leftRect, NS.color.tile):SetInside(true)
	-- The left box's margin is the gap between the boxes.
	local rightRect = Rect(right, 0, BOX_TOP, MARGIN, MARGIN)
	NS:CreateBox(right, right, rightRect, NS.color.header):SetInside(true)
	return leftRect
end

-- Hides the pane on the right, or shows it again: the window shrinks to
-- the left box or grows back.
local function SkinPaneToggle(frame, strip)
	local button = frame.RightPaneToggleButton
	if not button then return end
	NS:HideTextures(button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture())
	button:SetSize(CONTROL, CONTROL)
	button:ClearAllPoints()
	button:SetPoint("RIGHT", strip, "RIGHT", -(STRIP - BOX_TOP - CONTROL) / 2, 0)

	local box = NS:CreateControlBox(button)
	box:SetInside(true)
	local collapse, expand = NS:CreateChevron(button, "left"), NS:CreateChevron(button, "right")
	local function Apply(self)
		local collapsed = frame.IsRightPaneCollapsed and frame:IsRightPaneCollapsed()
		for _, line in ipairs(collapse) do line:SetShown(not collapsed) end
		for _, line in ipairs(expand) do line:SetShown(collapsed) end
		local v = NS:ControlBrightness(self)
		NS:SetStrokeBrightness(collapse, v)
		NS:SetStrokeBrightness(expand, v)
		NS:SetControlBoxState(box, v)
	end
	NS:HookButtonStates(button, Apply)
	NS:Hook(frame, "UpdateRightPaneToggleButton", function() Apply(button) end)
end

---------------------------------------------------------------------------
-- Mode tabs: icon tiles down the window's right edge, the open mode with an
-- accent border.
---------------------------------------------------------------------------

local modeTabs = {} -- [tab] = tile

-- After SetChecked, which resizes and re-crops the icon, and after clicks,
-- which move it. Blizzard shows SelectedTexture on the checked tab.
local function SyncModeTab(tab)
	local tile = modeTabs[tab]
	if not tile then return end
	tile:Layout()
	NS:CropIcon(tab.Icon)
	local checked = tab.SelectedTexture and tab.SelectedTexture:IsShown()
	tile:SetBorderColor(unpack(checked and ACCENT or NS.color.border))
end

local function SkinModeTab(tab)
	if not tab.Icon or modeTabs[tab] then return end
	NS:HideTextures(tab.Background, tab.SelectedTexture, tab.TabGlow, tab.HighlightTexture)
	if tab.Mask then
		tab.Icon:RemoveMaskTexture(tab.Mask)
	end
	-- Blizzard stacks the tabs by their height, 2 apart.
	tab:SetSize(SIDE_TAB_GAP + SIDE_TAB, SIDE_TAB + SIDE_TAB_GAP)
	local rect = tab:CreateTexture()
	rect:SetSize(SIDE_TAB, SIDE_TAB)
	rect:SetPoint("LEFT", tab, "LEFT", SIDE_TAB_GAP, 0)
	local tile = NS:CreateTile(tab)
	tile.anchor, tile.icon = rect, tab.Icon
	modeTabs[tab] = tile
	local hover = NS:CreateTexture(tab, "HIGHLIGHT", 0, TAB_HOVER)
	hover:SetAllPoints(tile.fill)

	NS:Hook(tab, "SetChecked", SyncModeTab)
	tab:HookScript("OnMouseDown", function(self) SyncModeTab(self) end)
	tab:HookScript("OnMouseUp", function(self) SyncModeTab(self) end)
	SyncModeTab(tab)
end

local function SkinModeTabs(frame)
	local tabs = frame.ModeTabs and frame.ModeTabs.Tabs
	for _, tab in ipairs(tabs or {}) do
		SkinModeTab(tab)
	end
	if frame.UpdateTabLayout then
		frame:UpdateTabLayout()
	end
end

---------------------------------------------------------------------------
-- Paperdoll: a strip for the level line, the model below it, all inside
-- the left box.
---------------------------------------------------------------------------

local function SkinCharacterView(frame, leftRect)
	local paperdoll = PaperDollFrame
	local host = paperdoll.TopBackgroundStripHost
	if not host then
		NS:Missing("PaperDollFrame.TopBackgroundStripHost")
		return
	end
	NS:HideRegions(host)

	-- On the left pane, so the box border stays on top. Only the paperdoll
	-- has the level line.
	local left = frame.LeftPaneHost
	local strip = NS:CreateTexture(left, "BACKGROUND", -4, NS.color.header)
	strip:SetPoint("TOPLEFT", leftRect, "TOPLEFT")
	strip:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -MARGIN, 0)
	local rule = NS:CreateLine(left, "BORDER", NS.color.border)
	rule:SetPoint("TOPLEFT", strip, "BOTTOMLEFT")
	rule:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT")
	local function Sync()
		local shown = paperdoll:IsShown()
		strip:SetShown(shown)
		rule:SetShown(shown)
	end
	paperdoll:HookScript("OnShow", Sync)
	paperdoll:HookScript("OnHide", Sync)
	Sync()

	for _, name in ipairs({ "CharacterLevelText", "PetCharacterLevelText" }) do
		local text = _G[name]
		if text then NS:RestyleFont(text, 13, "CENTER") end
	end

	-- The race art fills the box under the strip, inside the border.
	local scene = CharacterModelScene
	if scene then
		local px = 1 -- the box border, one UI unit
		scene:ClearAllPoints()
		scene:SetPoint("TOPLEFT", host, "BOTTOMLEFT", MARGIN + px, -px)
		scene:SetPoint("BOTTOMRIGHT", leftRect, "BOTTOMRIGHT", -px, px)
	end
	SkinPaneToggle(frame, strip)
	SkinColoredBar(PetPaperDollFrameExpBar)
end

---------------------------------------------------------------------------
-- Right pane tabs (stats, gear sets, titles, pet): icon tiles, the open
-- one with an accent border.
---------------------------------------------------------------------------

local sidebarTabs = {} -- [tab] = tile

local function SyncSidebarTabs()
	for tab, tile in pairs(sidebarTabs) do
		CropIfPlain(tab.Icon) -- the player's portrait
		tile:Layout()
		tile:SetBorderColor(unpack(tab:GetChecked() and ACCENT or NS.color.border))
	end
end

local function SkinSidebarTabs()
	for i = 1, 4 do
		local tab = _G["PaperDollSidebarTab" .. i]
		if tab and tab.Icon then
			NS:HideRegions(tab, "BORDER")
			NS:HideTextures(tab:GetCheckedTexture())
			local tile = NS:CreateTile(tab, SIDEBAR_INSET, SIDEBAR_INSET)
			tile.icon = tab.Icon
			sidebarTabs[tab] = tile
			local hover = NS:CreateTexture(tab, "HIGHLIGHT", 0, TAB_HOVER)
			hover:SetAllPoints(tile.fill)
		end
	end
	NS:Hook(nil, "PaperDollFrame_UpdateSidebarTabs", SyncSidebarTabs)
	SyncSidebarTabs()
end

-- A rule along the top of a right pane, under the tabs.
local function AddPaneRule(pane)
	local rule = NS:CreateLine(pane, "BORDER", NS.color.border)
	rule:SetPoint("TOPLEFT", pane, "TOPLEFT")
	rule:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -MARGIN, 0)
end

---------------------------------------------------------------------------
-- Stats: category bands with an accent title, then label/value rows on a
-- faint stripe.
---------------------------------------------------------------------------

local statRows = {}

local function SkinStatRow(row)
	if not row or statRows[row] then return end
	statRows[row] = true
	if row.Title then
		NS:HideTextures(row.Background)
		NS:CreateTile(row, 0, CATEGORY_INSET, NS.color.tile, true)
		NS:StyleFont(row.Title, 13, "CENTER")
		row.Title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
		return
	end
	-- Blizzard shows the stripe on every other row.
	local stripe = row.Background
	if stripe then
		stripe:SetColorTexture(STRIPE[1], STRIPE[2], STRIPE[3], STRIPE[4])
		stripe:ClearAllPoints()
		stripe:SetAllPoints(row)
	end
	if row.Label then
		NS:StyleFont(row.Label, 12, "LEFT")
		local c = NS.color.dim
		row.Label:SetTextColor(c[1], c[2], c[3])
	end
	if row.Value then
		NS:RestyleFont(row.Value, 12, "RIGHT")
	end
end

local function SkinStatsPane(pane)
	if not pane then return end
	NS:HideTextures(pane.Border, pane.ClassBackground)
	NS:HideRegions(pane, "BORDER") -- the line under the list
	NS:SkinScrollBar(pane.ScrollBar)
	AddPaneRule(pane)
	WatchScrollBox(pane.ScrollBox, SkinStatRow)
end

---------------------------------------------------------------------------
-- Gear sets: rows with the set icon in a box, the equipped set with an
-- accent border.
---------------------------------------------------------------------------

local gearSets = {} -- [button] = row border

local function SetGearSetSelected(button, selected)
	local border = gearSets[button]
	if border then
		border:SetColor(unpack(selected and ACCENT or NS.color.border))
	end
end

local function SkinGearSet(button)
	if not button or gearSets[button] or not button.icon then return end
	-- The card, its hover and selected art, and the icon's frame.
	NS:HideRegions(button, "BACKGROUND")
	NS:HideRegions(button, "ARTWORK", button.icon)
	NS:CreateTexture(button, "BACKGROUND", -8, NS.color.tile):SetAllPoints(button)
	gearSets[button] = NS:CreateBorder(button, button)
	NS:CreateBox(button, button, button.icon, NS.color.tile)
	NS:CropIcon(button.icon)
	AddHover(button)
	if button.text then
		NS:RestyleFont(button.text, 13, "LEFT")
		button.text:SetWordWrap(true)
	end
	SetGearSetSelected(button, button.SelectedBar and button.SelectedBar:IsShown())
end

local function SkinEquipmentManager(pane)
	if not pane then return end
	NS:HideRegions(pane, "BORDER")
	NS:SkinScrollBar(pane.ScrollBar)
	AddPaneRule(pane)
	SkinSliceButton(pane.EquipSet)
	SkinSliceButton(pane.SaveSet)
	local new = pane.NewSet
	if new then
		NS:HideRegions(new, "BACKGROUND") -- the "+" stays
		local tile = NS:CreateTile(new, 0, 0, NS.color.tile, true)
		AddHover(new, tile.fill)
	end
	WatchScrollBox(pane.ScrollBox, SkinGearSet)
	NS:Hook(nil, "PaperDollEquipmentManagerPane_SetButtonSelected", SetGearSetSelected)
end

---------------------------------------------------------------------------
-- Titles: a list on the stripe, the current title washed in the accent.
---------------------------------------------------------------------------

local titleRows = {}

local function SkinTitleRow(button)
	if not button or titleRows[button] then return end
	titleRows[button] = true
	local stripe = button.Stripe
	if stripe then
		stripe:SetColorTexture(STRIPE[1], STRIPE[2], STRIPE[3], STRIPE[4])
		stripe:ClearAllPoints()
		stripe:SetAllPoints(button)
	end
	for _, spec in ipairs({ { button.SelectedBar, SELECTED }, { button:GetHighlightTexture(), ROW_HOVER } }) do
		local texture = spec[1]
		if texture then
			NS:SetFlat(texture, spec[2], button)
			texture:SetBlendMode("BLEND")
			texture:SetAlpha(1)
		end
	end
	if button.text then
		NS:RestyleFont(button.text, 12, "LEFT")
	end
end

local function SkinTitlesPane(pane)
	if not pane then return end
	NS:HideRegions(pane, "BORDER")
	NS:SkinScrollBar(pane.ScrollBar)
	AddPaneRule(pane)
	WatchScrollBox(pane.ScrollBox, SkinTitleRow)
end

---------------------------------------------------------------------------
-- List modes (reputation, skills, currencies, statistics): category rows
-- as tiles with an accent title, entries with a flat hover and selection,
-- bars in a box.
---------------------------------------------------------------------------

local LIST_PAGES = { "ReputationFrame", "SkillsFrame", "TokenFrame", "StatisticsFrame" }

local listRows = {}

local function SkinListHeader(row)
	NS:HideRegions(row, "BACKGROUND")
	NS:HideRegions(row, "HIGHLIGHT")
	local tile = NS:CreateTile(row, 0, 1, NS.color.tile, true)
	AddHover(row, tile.fill)
	NS:StyleFont(row.Name, 13, "LEFT")
	row.Name:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
end

-- Skill and statistic names start 2 in, which Blizzard's rounded highlight
-- hid; on the flat one they need the header's inset.
local function InsetName(row, content)
	local name = content.Name
	if not name or row.ToggleCollapseButton then return end -- subheaders anchor theirs
	for i = 1, name:GetNumPoints() do
		local point, relativeTo, relativePoint, x, y = name:GetPoint(i)
		if point == "LEFT" and relativeTo == content and x < ENTRY_TEXT_X then
			name:SetPoint("LEFT", content, relativePoint, ENTRY_TEXT_X, y)
		end
	end
end

-- Blizzard sets the highlight's color per region and its alpha on the
-- frame (more when selected than on hover), so one flat region is enough.
local function SkinEntry(row, content)
	local highlight = content.BackgroundHighlight
	if highlight then
		NS:HideTextures(highlight.Left, highlight.Right)
		local middle = highlight.Middle
		if middle then
			middle:SetColorTexture(1, 1, 1, 1)
			middle:ClearAllPoints()
			middle:SetAllPoints(highlight)
		end
	end
	-- Blizzard's size: currency names are only 11 tall.
	for _, key in ipairs({ "Name", "Count", "Value" }) do
		local fs = content[key]
		if fs and fs.GetJustifyH then
			NS:RestyleFont(fs, 12, fs:GetJustifyH())
		end
	end
	InsetName(row, content)
	CropIfPlain(content.CurrencyIcon)
	SkinColoredBar(content.ReputationBar or content.SkillsBar)
end

local function SkinListRow(row)
	if not row or listRows[row] then return end
	listRows[row] = true
	if row.StateIcon and row.Name and not row.Content then
		SkinListHeader(row)
	elseif row.Content then
		SkinEntry(row, row.Content)
	elseif row.Text and row.Text.GetJustifyH then
		NS:RestyleFont(row.Text, 13, "LEFT") -- currency subheaders
	end
end

local skinnedPages = {}

local function SkinListPage(page)
	if not page or skinnedPages[page] then return end
	skinnedPages[page] = true
	local scrollBox = page.ScrollBox
	if scrollBox then
		-- The rules above and below the list.
		for _, child in ipairs({ scrollBox:GetChildren() }) do
			NS:HideRegions(child)
		end
		WatchScrollBox(scrollBox, SkinListRow)
	end
	NS:SkinScrollBar(page.ScrollBar)
	local dropdown = page.filterDropdown
	if dropdown then
		dropdown:SetHeight(CONTROL)
		dropdown:ClearAllPoints()
		dropdown:SetPoint("TOPRIGHT", CharacterFrame.LeftPaneHost, "TOPRIGHT", -2 * MARGIN, -(BOX_TOP + MARGIN))
		NS:SkinTextDropdown(dropdown)
	end
end

---------------------------------------------------------------------------
-- Details panes on the right (CharacterFrameSidePaneTemplate): rows come
-- from pools and are laid out after every change.
---------------------------------------------------------------------------

local PANE_CHECKBOXES = {
	"AtWarCheckbox", "MakeInactiveCheckbox", "WatchFactionCheckbox", "InactiveCheckbox", "BackpackCheckbox",
}

local paneRows = {}

local function SkinPaneRows(pane)
	local pools = pane.rowPools
	if not (pools and pools.EnumerateActive) then return end
	for row in pools:EnumerateActive() do
		if not paneRows[row] then
			paneRows[row] = true
			if row.IconSlot and row.Icon then
				NS:HideTextures(row.IconSlot)
				NS:CreateBox(row, row, row.Icon, NS.color.tile)
			elseif row.Background and row.Label then
				NS:HideTextures(row.Background)
				NS:CreateTile(row, 0, CATEGORY_INSET, NS.color.tile, true)
				NS:StyleFont(row.Label, 13, "CENTER")
				row.Label:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
			end
		end
	end
end

local skinnedPanes = {}

local function SkinSidePane(pane)
	if not pane or skinnedPanes[pane] then return end
	skinnedPanes[pane] = true
	local divider = pane.Divider
	if divider then
		local c = NS.color.divider
		divider:SetColorTexture(c[1], c[2], c[3], c[4])
		divider:SetHeight(1)
	end
	if pane.Title then
		NS:RestyleFont(pane.Title, 15, "CENTER")
		pane.Title:SetWordWrap(true)
	end
	if pane.Subtitle then
		NS:RestyleFont(pane.Subtitle, 12, "CENTER")
		pane.Subtitle:SetWordWrap(true)
	end
	NS:SkinScrollBar(pane.DescriptionScrollBar)
	SkinColoredBar(pane.StandingBar or pane.RankBar)
	for _, key in ipairs(PANE_CHECKBOXES) do
		NS:SkinCheckButton(pane[key])
	end
	-- Red like its label, as Blizzard's sword was.
	local atWar = pane.AtWarCheckbox and pane.AtWarCheckbox:GetCheckedTexture()
	if atWar then
		local c = NS.color.hostile
		atWar:SetColorTexture(c[1], c[2], c[3], 1)
	end
	SkinSliceButton(pane.ViewRenownButton)
	if pane.LayoutRows then
		NS:Hook(pane, "LayoutRows", SkinPaneRows)
		SkinPaneRows(pane)
	end
end

-- The currency and statistics modes may load after us.
local function SkinPages(frame)
	for _, name in ipairs(LIST_PAGES) do
		SkinListPage(_G[name])
	end
	for _, pane in ipairs(frame.SidePanes or {}) do
		SkinSidePane(pane)
	end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Init()
	local frame = CharacterFrame
	if not (frame and frame.LeftPaneHost and frame.RightPaneHost and PaperDollFrame) then
		NS:Missing("CharacterFrame")
		return
	end

	local header = NS:SkinPanelFrame(frame)
	SkinPortrait(frame, header)
	local leftRect = SkinPanes(frame)
	SkinModeTabs(frame)

	SkinCharacterView(frame, leftRect)
	NS:SkinCharacterSlots()
	SkinSidebarTabs()
	SkinStatsPane(CharacterStatsPaneScrollBox)
	SkinStatsPane(CharacterStatsPanePetScrollBox)
	SkinEquipmentManager(PaperDollFrame.EquipmentManagerPane)
	SkinTitlesPane(PaperDollFrame.TitleManagerPane)

	SkinPages(frame)
	NS:On("ADDON_LOADED", function() SkinPages(frame) end)
end
