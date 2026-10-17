-- AbsoluteUI: world map window (WorldMapFrame) and the quest log beside it
-- (QuestMapFrame).
--
--   | [icon]            Map & Quest Log             [+][x] |  header
--   | World > Kalimdor > Durotar  [v] | [search     ] [*] |  controls row
--   | +------------- map -------------+ | +-- quests ---+ |
--
-- The window, the map canvas and the quest log keep Blizzard's sizes. The
-- panel reaches a few units past the window's left, right and bottom edges
-- so the canvas gets the same margin as everything else, and the controls
-- row (navigation bar, filter, quest search) is re-anchored to line up with
-- it. Quest list rows are pooled and styled after every list update; the
-- quest text of the details view is colored by Quests.lua.

local _, NS = ...

local M = NS:NewModule("WorldMap", { setting = "worldMap", addon = "Blizzard_WorldMap", flavor = "modern" })

local MARGIN = NS.panelStyle.margin
-- The frame around the canvas and the quest list, past their edges. Every
-- edge here is laid out in UI units and every border is drawn inside its
-- rect, so the edges line up at any resolution and UI scale.
local BORDER = 1

-- Blizzard's geometry: the canvas starts CANVAS_TOP below the window's top,
-- CANVAS_INSET in from its left and bottom edges and QUEST_INSET from the
-- right, where the quest log also sits, QUEST_TOP below the top.
local CANVAS_TOP = 67
local CANVAS_INSET = 2
local QUEST_INSET = 3
local QUEST_TOP = 25
local DETAILS_TOP = 44 -- the quest details' scroll frame, from the quest log's top

-- The panel's edges, MARGIN from the canvas box.
local OUTSET = MARGIN + BORDER - CANVAS_INSET
local OUTSET_RIGHT = MARGIN + BORDER - QUEST_INSET

-- Controls row between the header and the canvas box: 30, Blizzard's
-- navigation button height.
local ROW_TOP = 2 * MARGIN + NS.panelStyle.header
local ROW = CANVAS_TOP - BORDER - MARGIN - ROW_TOP

-- The quest list box's inner rect, from the quest log's left edge.
local LIST_LEFT = MARGIN + 2 * BORDER - QUEST_INSET

local MAP_BUTTON = 24            -- buttons over the map canvas
local SEARCH_OUTSET = 2          -- NS:SkinSearchBox draws past the edit box
local COUNT_PAD = 8              -- around the quest count text
local BACK_WIDTH = 90
local BUTTON_INSET = 5           -- details buttons in the list box
local BUTTON_GAP = 4

local ROW_HOVER = NS.color.rowHover
local SEPARATOR = 0.45 -- breadcrumb chevron brightness

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

-- Panel on the map frame, below the canvas; the header on the border
-- frame, which sits above it.
local function SkinWindow(map)
	local border = map.BorderFrame
	local rect = map:CreateTexture()
	rect:SetPoint("TOPLEFT", map, "TOPLEFT", -OUTSET, 0)
	rect:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", OUTSET_RIGHT, -OUTSET)
	local panel = NS:CreateTile(map, 0, 0, NS.color.panel)
	panel.anchor = rect
	panel:Layout()

	local header = NS:SkinPanelChrome(border)
	header:ClearAllPoints()
	header:SetPoint("TOPLEFT", rect, "TOPLEFT", MARGIN, -MARGIN)
	header:SetPoint("TOPRIGHT", rect, "TOPRIGHT", -MARGIN, -MARGIN)
	NS:SkinPanelPortrait(border, header)
	-- Full screen map, or the window.
	NS:SkinMaximizeMinimize(border.MaximizeMinimizeFrame)
	NS:Kill(border.InsetBorderTop)
end

-- Draws a BORDER wide frame around `region` on `frame`.
local function FrameRegion(frame, region, color)
	local tile = NS:CreateTile(frame, -BORDER, -BORDER, color, true)
	tile.anchor = region
	tile:Layout()
	return tile
end

-- A plain frame around the canvas, drawn on the frame Blizzard shows
-- behind it.
local function SkinCanvas(map)
	local host = map.OverscrollBG
	if host then
		NS:HideRegions(host)
	else
		host = map
	end
	FrameRegion(host, map.ScrollContainer, NS.color.panel)
end

---------------------------------------------------------------------------
-- Navigation bar: a strip of breadcrumbs, the current map in the accent
-- color, chevrons between them. Crumbs overlap their neighbors (Blizzard's
-- art had arrows there), so each chevron sits in the gap at its crumb's left
-- end and the hover covers only the text.
---------------------------------------------------------------------------

local crumbs = {} -- [button] = text
local navBar

local HOME_PAD = 35 -- around the home text: 10 left, 25 right (the next crumb overlaps 15)
local CRUMB_GAP = 5 -- from a crumb's left end to its chevron
-- Blizzard's crumb widths past the text, with and without the menu arrow.
local CRUMB_PAD, CRUMB_MENU_PAD = 30, 53

local function ColorCrumb(button)
	local text = crumbs[button]
	if not text then return end
	local c = NS.color.dim
	if not button:IsEnabled() then
		c = NS.color.accent
	elseif button:IsMouseOver() then
		c = NS.color.text
	end
	text:SetTextColor(c[1], c[2], c[3])
end

local function AddCrumbHover(button, text)
	local hover = NS:CreateTexture(button, "HIGHLIGHT", 0, ROW_HOVER)
	local half = ROW / 2 - BORDER
	hover:SetPoint("TOPLEFT", text, "LEFT", -8, half)
	hover:SetPoint("BOTTOMRIGHT", text, "RIGHT", 8, -half)
end

local function AddSeparator(button, x)
	NS:SetStrokeBrightness(NS:CreateChevron(button, "right", "LEFT", x, 0), SEPARATOR)
end

-- The arrow that lists the sibling maps.
local function SkinMenuArrow(arrow)
	if not arrow then return end
	arrow:SetSize(16, 16)
	local strokes = NS:CreateChevron(arrow, "down")
	NS:HookButtonStates(arrow, function(self)
		NS:HideTextures(self.Art, self.NormalTexture, self.PushedTexture, self:GetHighlightTexture())
		NS:SetStrokeBrightness(strokes, NS:ControlBrightness(self))
	end)
end

local function SkinCrumb(button, isHome)
	if crumbs[button] then return end
	local text = button.text
	if not text then return end
	crumbs[button] = text
	NS:HideRegions(button)
	NS:StyleFont(text, 13, "LEFT")
	if isHome then
		text:ClearAllPoints()
		text:SetPoint("LEFT", button, "LEFT", 10, 0)
		button:SetWidth(text:GetStringWidth() + HOME_PAD)
	else
		AddSeparator(button, CRUMB_GAP)
	end
	AddCrumbHover(button, text)
	SkinMenuArrow(button.MenuArrowButton)
	NS:HookButtonStates(button, ColorCrumb)
end

-- Lists the crumbs Blizzard hid for lack of room.
local function SkinOverflow(button)
	if not button then return end
	NS:HideRegions(button)
	local visible = button:GetWidth() + (button.xoffset or 0)
	local strokes = NS:CreateChevron(button, "left", "LEFT", visible / 2, 0)
	NS:HookButtonStates(button, function(self)
		NS:SetStrokeBrightness(strokes, NS:ControlBrightness(self))
	end)
end

-- Blizzard sized the crumb for its own font and decided which crumbs fit
-- by that size, so it decides again with ours.
local function OnNavButtonAdded(bar)
	if bar ~= navBar then return end
	local button = bar.navList and bar.navList[#bar.navList]
	if not button then return end
	SkinCrumb(button)
	local text = crumbs[button]
	if text then
		local menu = button.MenuArrowButton
		local width = text:GetStringWidth() + (menu and menu:IsShown() and CRUMB_MENU_PAD or CRUMB_PAD)
		if math.abs(button:GetWidth() - width) > 0.5 then
			button:SetWidth(width)
			NavBar_CheckLength(bar)
		end
	end
	ColorCrumb(button)
end

-- Runs whenever Blizzard enables the crumbs and disables the current one.
local function OnNavBarLayout(bar)
	if bar ~= navBar then return end
	for _, button in ipairs(bar.navList or {}) do
		ColorCrumb(button)
	end
end

local function SkinNavBar(bar)
	navBar = bar
	NS:HideRegions(bar)
	NS:HideRegions(bar.overlay)
	NS:CreateTile(bar, 0, 0, NS.color.header, true)
	if bar.homeButton then
		SkinCrumb(bar.homeButton, true)
	end
	for _, button in ipairs(bar.navList or {}) do
		SkinCrumb(button)
	end
	SkinOverflow(bar.overflowButton)
	NS:Hook(nil, "NavBar_AddButton", OnNavButtonAdded)
	NS:Hook(nil, "NavBar_CheckLength", OnNavBarLayout)
	-- The home crumb was resized. Before the map first opens the bar has no
	-- width yet, and Blizzard checks again when it fills the bar.
	if bar.navList and NavBar_CheckLength and bar:GetWidth() > 0 then
		NavBar_CheckLength(bar)
	end
end

---------------------------------------------------------------------------
-- Buttons over the map
---------------------------------------------------------------------------

local function ControlBox(button)
	local box = NS:CreateControlBox(button)
	box:SetInside(true)
	return box
end

-- Waypoint pin: a box with the pin icon, the border lit while placing.
local function SkinPinButton(button, canvas)
	if not button or not button.Icon then return end
	NS:HideRegions(button, nil, button.Icon, button.IconOverlay)
	button:SetSize(MAP_BUTTON, MAP_BUTTON)
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", canvas, "TOPLEFT", MARGIN, -MARGIN)

	-- Blizzard moves the icon on every press.
	local function PlaceIcon(pressed)
		local icon = button.Icon
		icon:ClearAllPoints()
		icon:SetPoint("CENTER", button, "CENTER", pressed and 1 or 0, pressed and -1 or 0)
		icon:SetSize(MAP_BUTTON - 6, MAP_BUTTON - 6)
	end
	button:HookScript("OnMouseDown", function(self) PlaceIcon(self:IsEnabled()) end)
	button:HookScript("OnMouseUp", function() PlaceIcon(false) end)
	PlaceIcon(false)

	local box = ControlBox(button)
	local function Apply(self)
		if self.isActive then
			box.border:SetColor(unpack(NS.color.accent))
		else
			NS:SetControlBoxState(box, NS:ControlBrightness(self))
		end
	end
	NS:HookButtonStates(button, Apply)
	NS:Hook(button, "SetActive", Apply)
end

-- Floors of dungeons and multi-level zones, right of the pin.
local function SkinFloorDropdown(dropdown, canvas, pin)
	if not dropdown then return end
	NS:HideTextures(dropdown.Background)
	dropdown:SetHeight(MAP_BUTTON)
	dropdown:ClearAllPoints()
	local x = MARGIN + (pin and MAP_BUTTON + MARGIN or 0)
	dropdown:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -MARGIN)

	local box = ControlBox(dropdown)
	local strokes = NS:CreateChevron(dropdown, "down", "RIGHT", -MAP_BUTTON / 2, 0)
	local text = dropdown.Text
	if text then
		NS:StyleFont(text, 12, "LEFT")
		text:ClearAllPoints()
		text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
		text:SetPoint("RIGHT", dropdown, "RIGHT", -MAP_BUTTON, 0)
	end
	NS:HookButtonStates(dropdown, function(self)
		NS:HideTextures(self.Arrow)
		local v = NS:ControlBrightness(self)
		NS:SetStrokeBrightness(strokes, v)
		NS:SetControlBoxState(box, v)
		if text then text:SetTextColor(v, v, v) end
	end)
end

-- Shows or hides the quest log: the window grows to the right, or back.
local function SkinSidePanelToggle(toggle, canvas)
	if not toggle then return end
	toggle:SetSize(MAP_BUTTON, MAP_BUTTON)
	toggle:ClearAllPoints()
	toggle:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -MARGIN, MARGIN)
	for _, spec in ipairs({ { toggle.OpenButton, "right" }, { toggle.CloseButton, "left" } }) do
		local button = spec[1]
		if button then
			NS:HideRegions(button) -- the corner shadow
			button:SetSize(MAP_BUTTON, MAP_BUTTON)
			NS:SkinArrowButton(button, spec[2]):SetInside(true)
		end
	end
end

local function StyleCoords(panel)
	for _, key in ipairs({ "CursorCoords", "CrosshairCoords", "PlayerCoords" }) do
		local label = panel[key] and panel[key].Label
		if label then
			NS:StyleFont(label, 12, "LEFT", true)
		end
	end
end

-- Overlay frames Blizzard keeps no key for.
local function FindOverlays(map)
	local floor, coords
	local floorMixin = WorldMapFloorNavigationFrameMixin
	for _, frame in ipairs(map.overlayFrames or {}) do
		if floorMixin and frame.RefreshMenu == floorMixin.RefreshMenu then
			floor = frame
		elseif frame.CursorCoords and frame.PlayerCoords then
			coords = frame
		end
	end
	return floor, coords
end

local function SkinOverlays(map)
	local canvas = map.ScrollContainer
	local pin = map.WorldMapTrackingPinButton
	local filter = map.WorldMapTrackingOptionsButton
	if filter then
		NS:HideRegions(filter)
		filter:SetSize(ROW, ROW)
		NS:SkinChevronDropdown(filter):SetInside(true)
	end
	SkinPinButton(pin, canvas)
	local floor, coords = FindOverlays(map)
	SkinFloorDropdown(floor, canvas, pin)
	if coords then
		StyleCoords(coords)
	end
	SkinSidePanelToggle(map.SidePanelToggle, canvas)
end

---------------------------------------------------------------------------
-- Quest list
---------------------------------------------------------------------------

local headers, titles = {}, {}
local headerFont

local function HeaderFont()
	if not headerFont then
		headerFont = CreateFont("AbsoluteUIQuestLogHeader")
		headerFont:SetFontObject(NS:GetFont(13))
		headerFont:SetShadowOffset(1, -1)
		headerFont:SetShadowColor(0, 0, 0, 0.9)
	end
	return headerFont
end

-- Zone names in the accent color, white on hover (Blizzard: grey).
local function ColorHeaderTitle(header, isMouseOver)
	local title = header.GetTitleRegion and header:GetTitleRegion()
	if not title then return end
	if isMouseOver == nil then
		isMouseOver = header:IsMouseMotionFocus()
	end
	local c = isMouseOver and NS.color.text or NS.color.accent
	title:SetTextColor(c[1], c[2], c[3])
end

-- "+" while collapsed, "-" while expanded.
local function SkinCollapseButton(button)
	if not button then return end
	local _, vertical = NS:CreatePlus(button)
	local function Sync(self, collapsed)
		NS:HideTextures(self.Icon, self:GetHighlightTexture())
		vertical:SetShown(collapsed and true or false)
	end
	NS:Hook(button, "UpdateCollapsedState", Sync)
	Sync(button, button.collapsed)
end

local function SkinHeader(header)
	if headers[header] then return end
	headers[header] = true
	NS:HideTextures(header:GetNormalTexture(), header:GetHighlightTexture())
	local tile = NS:CreateTile(header, 0, 0, NS.color.tile, true)
	local hover = NS:CreateTexture(header, "HIGHLIGHT", 0, ROW_HOVER)
	hover:SetAllPoints(tile.fill)
	local font = HeaderFont()
	header:SetNormalFontObject(font)
	header:SetHighlightFontObject(font)
	SkinCollapseButton(header.CollapseButton)
	NS:Hook(header, "CheckHighlightTitle", ColorHeaderTitle)
	ColorHeaderTitle(header)
end

-- The track checkbox: a background box, the check mark and a highlight.
local function SkinCheckbox(check)
	if not check then return end
	local box, hover
	for _, region in ipairs({ check:GetRegions() }) do
		if region:IsObjectType("Texture") and region ~= check.CheckMark then
			local layer = region:GetDrawLayer()
			if layer == "BACKGROUND" then
				box = region
			elseif layer == "HIGHLIGHT" then
				hover = region
			end
		end
	end
	NS:StyleCheckbox(box, check.CheckMark)
	if box and hover then
		NS:SetFlat(hover, NS.color.glyphHover, box)
		hover:SetAlpha(1)
	end
end

-- Quest titles keep Blizzard's difficulty colors. The glow Blizzard shows
-- on hover (and while a map pin is hovered) becomes a flat wash.
local function SkinTitle(button)
	if titles[button] then return end
	titles[button] = true
	NS:SetFlat(button.HighlightTexture, ROW_HOVER, button)
	SkinCheckbox(button.Checkbox)
end

local function SkinListRows()
	local scroll = QuestScrollFrame
	for _, key in ipairs({ "headerFramePool", "titleFramePool" }) do
		local pool = scroll[key]
		if pool then
			local skin = key == "headerFramePool" and SkinHeader or SkinTitle
			for frame in pool:EnumerateActive() do
				skin(frame)
			end
		end
	end
end

local function SkinListExtras(contents)
	local separator = contents.Separator
	if separator then
		NS:HideTextures(separator.Divider)
		local rule = NS:CreateLine(separator, "OVERLAY", NS.color.divider)
		rule:SetPoint("LEFT", separator, "LEFT", 9, 0)
		rule:SetPoint("RIGHT", separator, "RIGHT", -6, 0)
	end
	local story = contents.StoryHeader
	if story then
		NS:Kill(story.Background)
		NS:Kill(story.Divider)
		NS:SetFlat(story.HighlightTexture, ROW_HOVER, story)
		if story.HighlightTexture then story.HighlightTexture:SetAlpha(1) end
	end
end

---------------------------------------------------------------------------
-- Quest log: a box below the controls row, level with the canvas box.
---------------------------------------------------------------------------

-- Search, quest count and settings in the controls row, the list in the
-- box. Blizzard anchors the count to the search box's right end and sizes
-- the search box on every update; both anchors below override that size.
local function LayoutQuestList(log)
	local scroll = QuestScrollFrame
	local top = ROW_TOP - QUEST_TOP
	local search, settings, count = scroll.SearchBox, scroll.SettingsDropdown, QuestLogCount
	local right = BORDER - ROW - MARGIN -- left of the settings box
	if count then
		count:ClearAllPoints()
		count:SetPoint("TOPRIGHT", log, "TOPRIGHT", right, -top)
		count:SetHeight(ROW)
	end
	if search then
		search:ClearAllPoints()
		search:SetPoint("TOPLEFT", log, "TOPLEFT", LIST_LEFT - BORDER + SEARCH_OUTSET, -top)
		if count then
			search:SetPoint("BOTTOMRIGHT", count, "BOTTOMLEFT", -(MARGIN + SEARCH_OUTSET), 0)
		else
			search:SetPoint("BOTTOMRIGHT", log, "TOPRIGHT", right - SEARCH_OUTSET, -(top + ROW))
		end
	end
	if settings then
		settings:SetSize(ROW, ROW)
		settings:ClearAllPoints()
		settings:SetPoint("TOPRIGHT", log, "TOPRIGHT", BORDER, -top)
	end
	scroll:SetPoint("TOPLEFT", log.QuestsFrame, "TOPLEFT", LIST_LEFT, -(CANVAS_TOP - QUEST_TOP))
	if scroll.ScrollBar then
		scroll.ScrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", scroll.scrollBarX or 8, -MARGIN)
	end
end

-- Blizzard rewrites the count after every list update.
local function SizeQuestCount()
	local count, text = QuestLogCount, QuestLogQuestCount
	if count and text then
		count:SetWidth(math.ceil(text:GetStringWidth()) + 2 * COUNT_PAD)
	end
end

-- "Quests: 11/40" on a tile: the label dimmed, the numbers white (red past
-- the limit) through Blizzard's color codes.
local function SkinQuestCount()
	local count, text = QuestLogCount, QuestLogQuestCount
	if not (count and text) then return end
	NS:HideRegions(count)
	NS:CreateTile(count, 0, 0, NS.color.tile, true)
	NS:StyleFont(text, 12, "CENTER")
	local c = NS.color.dim
	text:SetTextColor(c[1], c[2], c[3])
	text:ClearAllPoints()
	text:SetPoint("CENTER", count, "CENTER", 0, 0)
	NS:Hook(nil, "QuestLogQuests_ShowQuestCount", SizeQuestCount)
	SizeQuestCount()
end

local function SkinQuestList(log)
	local scroll = QuestScrollFrame
	NS:HideTextures(scroll.Background, scroll.Edge)
	NS:Kill(scroll.BorderFrame)
	NS:SkinScrollBar(scroll.ScrollBar)
	NS:SkinSearchBox(scroll.SearchBox)
	local settings = NS:SkinGearDropdown(scroll.SettingsDropdown)
	if settings then settings:SetInside(true) end
	SkinQuestCount()
	if scroll.Contents then
		SkinListExtras(scroll.Contents)
	end
	LayoutQuestList(log)
	NS:Hook(nil, "QuestLogQuests_Update", SkinListRows)
	SkinListRows()
end

-- Details of one quest: Back in the controls row, the abandon, share and
-- track buttons along the bottom of the box, the rewards above them.
local function SkinDetails(log, listRect)
	local details = log.DetailsFrame or (log.QuestsFrame and log.QuestsFrame.DetailsFrame)
	if not details then
		NS:Missing("QuestMapFrame.DetailsFrame")
		return
	end
	NS:Kill(details.Bg)
	NS:Kill(details.SealMaterialBG)
	NS:Kill(details.BorderFrame)

	local back = details.BackFrame
	if back then
		NS:HideRegions(back)
		local button = back.BackButton
		if button then
			NS:SkinPanelButton(button)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", log, "TOPLEFT", LIST_LEFT - BORDER, -(ROW_TOP - QUEST_TOP))
			button:SetSize(BACK_WIDTH, ROW)
		end
	end

	local scroll = details.ScrollFrame
	if scroll and scroll.ScrollBar then
		NS:SkinScrollBar(scroll.ScrollBar)
		-- Level with the list's scroll bar; Blizzard's reached into the
		-- controls row and down past the buttons.
		local x = scroll.scrollBarX or 13
		local bar = scroll.ScrollBar
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", x, DETAILS_TOP - (CANVAS_TOP - QUEST_TOP) - MARGIN)
		bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", x, 0)
	end

	local abandon, share, track = details.AbandonButton, details.ShareButton, details.TrackButton
	for _, button in ipairs({ abandon, share, track }) do
		NS:SkinPanelButton(button)
	end
	NS:HideRegions(share, "OVERLAY") -- divider art on both sides

	local container = details.RewardsFrameContainer
	if abandon and share and track then
		local inner = log:GetWidth() - LIST_LEFT - 2 * BUTTON_INSET
		local width = math.floor((inner - 2 * BUTTON_GAP) / 3)
		abandon:ClearAllPoints()
		abandon:SetPoint("BOTTOMLEFT", listRect, "BOTTOMLEFT", BUTTON_INSET, BUTTON_INSET)
		abandon:SetWidth(width)
		track:ClearAllPoints()
		track:SetPoint("BOTTOMRIGHT", listRect, "BOTTOMRIGHT", -BUTTON_INSET, BUTTON_INSET)
		track:SetWidth(width)
		share:ClearAllPoints()
		share:SetPoint("TOPLEFT", abandon, "TOPRIGHT", BUTTON_GAP, 0)
		share:SetPoint("BOTTOMRIGHT", track, "BOTTOMLEFT", -BUTTON_GAP, 0)
		if container then
			-- Keeps its left edge (the quest log's) above the buttons.
			container:ClearAllPoints()
			container:SetPoint("BOTTOMLEFT", abandon, "TOPLEFT", -(LIST_LEFT + BUTTON_INSET), BUTTON_INSET)
		end
	end

	-- Blizzard's rewards art also hid the quest text scrolling under it.
	local rewards = container and container.RewardsFrame
	if rewards then
		NS:HideTextures(rewards.Top, rewards.Bottom, rewards.Background)
		local bg = NS:CreateTexture(container, "BACKGROUND", 0, NS.color.header)
		bg:SetPoint("TOPLEFT", container, "TOPLEFT", LIST_LEFT, 0)
		bg:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT")
		local rule = NS:CreateLine(container, "BORDER", NS.color.divider)
		rule:SetPoint("TOPLEFT", bg, "TOPLEFT")
		rule:SetPoint("TOPRIGHT", bg, "TOPRIGHT")
		if rewards.Label then
			NS:StyleFont(rewards.Label, 15, "CENTER")
			local c = NS.color.accent
			rewards.Label:SetTextColor(c[1], c[2], c[3])
		end
		NS:RegisterDarkQuestInfo(rewards)
	end
	if scroll then
		NS:RegisterDarkQuestInfo(scroll.Contents)
	end
end

local function SkinQuestLog(log)
	local listRect = log:CreateTexture()
	listRect:SetPoint("TOPLEFT", log, "TOPLEFT", LIST_LEFT, -(CANVAS_TOP - QUEST_TOP))
	listRect:SetPoint("BOTTOMRIGHT", log, "BOTTOMRIGHT", 0, CANVAS_INSET - QUEST_INSET)
	FrameRegion(log, listRect, NS.color.header)
	SkinQuestList(log)
	SkinDetails(log, listRect)
end

---------------------------------------------------------------------------
-- Layout of the controls row
---------------------------------------------------------------------------

-- Blizzard re-anchors the navigation bar on every resize, and the filter
-- and the search box when gamepad mode starts or ends.
local function LayoutControls(map)
	local spacer = map.TitleCanvasSpacerFrame
	local filter = map.WorldMapTrackingOptionsButton
	if filter then
		filter:ClearAllPoints()
		filter:SetPoint("TOPRIGHT", spacer, "BOTTOMRIGHT", BORDER, BORDER + MARGIN + ROW)
	end
	local bar = map.NavBar
	if bar then
		local right = filter and ROW + MARGIN or 0
		bar:SetPoint("TOPLEFT", spacer, "TOPLEFT", -BORDER, -ROW_TOP)
		bar:SetPoint("BOTTOMRIGHT", spacer, "BOTTOMRIGHT", BORDER - right, BORDER + MARGIN)
	end
	if QuestMapFrame and QuestScrollFrame and QuestMapFrame:GetParent() == map then
		LayoutQuestList(QuestMapFrame)
	end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Init()
	local map = WorldMapFrame
	if not (map and map.BorderFrame and map.ScrollContainer and map.TitleCanvasSpacerFrame) then
		NS:Missing("WorldMapFrame")
		return
	end
	SkinWindow(map)
	SkinCanvas(map)
	if map.NavBar then
		SkinNavBar(map.NavBar)
	end
	SkinOverlays(map)

	-- The quest log is attached to the map when the map loads.
	local log = QuestMapFrame
	if log and QuestScrollFrame and log:GetParent() == map then
		SkinQuestLog(log)
	else
		NS:Missing("QuestMapFrame")
	end

	local function Relayout() LayoutControls(map) end
	Relayout()
	NS:Hook(map, "Minimize", Relayout)
	NS:Hook(map, "Maximize", Relayout)
	-- Blizzard's gamepad callbacks are closures over the original methods,
	-- so they can't be hooked; lay out again once they have run.
	NS:On("INPUT_DEVICE_INTERFACE_TRANSITION", function()
		C_Timer.After(0, Relayout)
	end)
end
