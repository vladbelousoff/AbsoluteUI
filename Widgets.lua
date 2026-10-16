-- AbsoluteUI: drawing primitives and shared skinning helpers.
--
-- Borders, boxes and tiles draw 1px lines as one physical pixel at any UI
-- scale and re-lay themselves out when the scale changes.

local _, NS = ...

---------------------------------------------------------------------------
-- Pixel helpers
---------------------------------------------------------------------------

-- Size of one physical pixel in a frame's coordinate space.
function NS:Px(frame)
	local scale = frame and frame:GetEffectiveScale() or UIParent:GetEffectiveScale()
	if PixelUtil and PixelUtil.GetNearestPixelSize then
		return PixelUtil.GetNearestPixelSize(1, scale, 1)
	end
	return 1
end

local pixelClients = {}

-- `client` (a function, or an object with :UpdatePixels()) runs whenever
-- the UI scale, the resolution or Edit Mode scales change.
function NS:RegisterPixelClient(client)
	if type(client) ~= "function" then
		local object = client
		client = function() object:UpdatePixels() end
	end
	table.insert(pixelClients, client)
end

function NS:UpdatePixels()
	for i = 1, #pixelClients do
		NS.SafeCall(pixelClients[i])
	end
end

-- Scale events come in bursts; lay out once, on the next frame.
local queued = false
local function QueuePixelUpdate()
	if queued then return end
	queued = true
	C_Timer.After(0, function()
		queued = false
		NS:UpdatePixels()
	end)
end

NS:On("UI_SCALE_CHANGED", QueuePixelUpdate)
NS:On("DISPLAY_SIZE_CHANGED", QueuePixelUpdate)
if EventRegistry then
	EventRegistry:RegisterCallback("EditMode.Exit", QueuePixelUpdate, NS)
end

---------------------------------------------------------------------------
-- Basic regions
---------------------------------------------------------------------------

function NS:SetColor(texture, color, alpha)
	texture:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

function NS:CreateText(parent, size, justify, outline)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	NS:StyleFont(fs, size, justify, outline)
	return fs
end

function NS:CreateTexture(parent, layer, subLevel, color, file)
	local tex = parent:CreateTexture(nil, layer, nil, subLevel or 0)
	tex:SetTexture(file or NS.SOLID)
	if color then
		NS:SetColor(tex, color)
	end
	return tex
end

function NS:CreateStatusBar(parent)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	NS:RegisterBar(bar)
	return bar
end

-- A one pixel line; the caller anchors its length. Vertical lines keep
-- their width at one pixel, horizontal ones their height.
function NS:CreateLine(parent, layer, color, vertical)
	local line = NS:CreateTexture(parent, layer, 0, color)
	local function UpdatePixels()
		if vertical then
			line:SetWidth(NS:Px(parent))
		else
			line:SetHeight(NS:Px(parent))
		end
	end
	UpdatePixels()
	NS:RegisterPixelClient(UpdatePixels)
	return line
end

---------------------------------------------------------------------------
-- Border: four edge textures drawn inside `rectRegion`'s rect.
---------------------------------------------------------------------------

local BorderMixin = {}

function BorderMixin:SetThickness(px)
	local f = self.rect
	local top, bottom, left, right = self.top, self.bottom, self.left, self.right
	top:ClearAllPoints()
	top:SetPoint("TOPLEFT", f, "TOPLEFT")
	top:SetPoint("TOPRIGHT", f, "TOPRIGHT")
	top:SetHeight(px)
	bottom:ClearAllPoints()
	bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT")
	bottom:SetHeight(px)
	left:ClearAllPoints()
	left:SetPoint("TOPLEFT", f, "TOPLEFT")
	left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT")
	left:SetWidth(px)
	right:ClearAllPoints()
	right:SetPoint("TOPRIGHT", f, "TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT")
	right:SetWidth(px)
end

function BorderMixin:UpdatePixels()
	self:SetThickness(NS:Px(self.owner))
end

function BorderMixin:SetColor(r, g, b, a)
	for _, edge in ipairs(self.edges) do
		edge:SetVertexColor(r, g, b, a or 1)
	end
end

function BorderMixin:SetAlpha(alpha)
	for _, edge in ipairs(self.edges) do
		edge:SetAlpha(alpha)
	end
end

function BorderMixin:SetShown(shown)
	for _, edge in ipairs(self.edges) do
		edge:SetShown(shown)
	end
end

-- `managed` borders are laid out by their owner (a box) instead.
local function NewBorder(drawOn, rectRegion, layer, managed)
	local border = CreateFromMixins(BorderMixin)
	border.owner = drawOn
	border.rect = rectRegion or drawOn
	local function Edge() return NS:CreateTexture(drawOn, layer or "BORDER", 7) end
	border.top, border.bottom, border.left, border.right = Edge(), Edge(), Edge(), Edge()
	border.edges = { border.top, border.bottom, border.left, border.right }
	border:SetColor(unpack(NS.color.border))
	if not managed then
		border:UpdatePixels()
		NS:RegisterPixelClient(border)
	end
	return border
end

function NS:CreateBorder(drawOn, rectRegion, layer)
	return NewBorder(drawOn, rectRegion, layer)
end

---------------------------------------------------------------------------
-- Shadow: soft drop shadow around a region (nine-slice texture).
---------------------------------------------------------------------------

local SHADOW_OUTSET = 5

-- Nil on clients without nine-slice textures.
function NS:CreateShadow(drawOn, rectRegion)
	local shadow = drawOn:CreateTexture(nil, "BACKGROUND", nil, -8)
	if not shadow.SetTextureSliceMargins then
		return nil
	end
	shadow:SetTexture(NS.SHADOW)
	shadow:SetTextureSliceMargins(6, 6, 6, 6)
	if shadow.SetTextureSliceMode and Enum.UITextureSliceMode then
		shadow:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
	end
	shadow:SetPoint("TOPLEFT", rectRegion, "TOPLEFT", -SHADOW_OUTSET, SHADOW_OUTSET)
	shadow:SetPoint("BOTTOMRIGHT", rectRegion, "BOTTOMRIGHT", SHADOW_OUTSET, -SHADOW_OUTSET)
	NS:SetColor(shadow, NS.color.shadow)
	return shadow
end

---------------------------------------------------------------------------
-- Box: flat background plus a 1px border hugging `region` from outside.
---------------------------------------------------------------------------

local BoxMixin = {}

-- The background draws on `bgParent` (whose scale sets the pixel size), the
-- border on `borderParent` (so it can sit above other art).
function NS:CreateBox(bgParent, borderParent, region, bgColor)
	local box = CreateFromMixins(BoxMixin)
	box.owner = bgParent
	box.region = region
	-- Sublevels sit above a panel's shadow (-8) and background (-7).
	box.base = NS:CreateTexture(bgParent, "BACKGROUND", -6, NS.color.border)
	box.bg = NS:CreateTexture(bgParent, "BACKGROUND", -5, bgColor or NS.color.tile)
	box.bg:SetAllPoints(region)
	box.border = NewBorder(borderParent, box.base, nil, true)
	box:UpdatePixels()
	NS:RegisterPixelClient(box)
	return box
end

function BoxMixin:SetThickness(px)
	self.base:ClearAllPoints()
	self.base:SetPoint("TOPLEFT", self.region, "TOPLEFT", -px, px)
	self.base:SetPoint("BOTTOMRIGHT", self.region, "BOTTOMRIGHT", px, -px)
	self.border:SetThickness(px)
end

function BoxMixin:UpdatePixels()
	self:SetThickness(NS:Px(self.owner))
end

function BoxMixin:SetShown(shown)
	self.base:SetShown(shown)
	self.bg:SetShown(shown)
	self.border:SetShown(shown)
end

---------------------------------------------------------------------------
-- Tile: dark fill with a 1px border and a shadow, inset (x, y) inside a
-- frame. An optional `tile.icon` is laid out to fill the inside.
---------------------------------------------------------------------------

local TileMixin = {}

function NS:CreateTile(frame, insetX, insetY, fillColor, noShadow)
	local tile = CreateFromMixins(TileMixin)
	tile.frame, tile.insetX, tile.insetY = frame, insetX or 0, insetY or 0
	tile.rect = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	if not noShadow then
		tile.shadow = NS:CreateShadow(frame, tile.rect)
	end
	tile.base = NS:CreateTexture(frame, "BACKGROUND", -7, NS.color.border)
	tile.base:SetAllPoints(tile.rect)
	tile.fill = NS:CreateTexture(frame, "BACKGROUND", -6, fillColor or NS.color.tile)
	tile:Layout()
	NS:RegisterPixelClient(function() tile:Layout() end)
	return tile
end

-- Call again after setting `tile.icon`.
function TileMixin:Layout()
	local px = NS:Px(self.frame)
	local frame, x, y = self.frame, self.insetX, self.insetY
	self.rect:ClearAllPoints()
	self.rect:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
	self.rect:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -x, y)
	self.fill:ClearAllPoints()
	self.fill:SetPoint("TOPLEFT", self.rect, "TOPLEFT", px, -px)
	self.fill:SetPoint("BOTTOMRIGHT", self.rect, "BOTTOMRIGHT", -px, px)
	if self.icon then
		self.icon:ClearAllPoints()
		self.icon:SetAllPoints(self.fill)
	end
end

function TileMixin:SetBorderColor(r, g, b, a)
	self.base:SetVertexColor(r, g, b, a or 1)
end

function TileMixin:SetShown(shown)
	self.base:SetShown(shown)
	self.fill:SetShown(shown)
	if self.shadow then
		self.shadow:SetShown(shown)
	end
end

---------------------------------------------------------------------------
-- Skinning helpers for Blizzard widgets
---------------------------------------------------------------------------

function NS:CropIcon(texture)
	if not texture then return end
	local c = NS.ICON_CROP
	texture:SetTexCoord(c[1], c[2], c[3], c[4])
end

-- Turns a state texture (highlight, pushed, checked...) into a flat color
-- wash covering `anchor`.
function NS:SetFlat(texture, color, anchor)
	if not texture then return end
	texture:SetColorTexture(color[1], color[2], color[3], color[4])
	texture:ClearAllPoints()
	texture:SetAllPoints(anchor)
end

function NS:HideTextures(...)
	for i = 1, select("#", ...) do
		local texture = select(i, ...)
		if texture then texture:SetAlpha(0) end
	end
end

-- Flat button with a text glyph ("x", "+", "-"). Returns the glyph.
function NS:SkinGlyphButton(button, size, text)
	if not button then return end
	NS:HideTextures(button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture())
	NS:SetFlat(button:GetHighlightTexture(), NS.color.glyphHover, button)
	local glyph = NS:CreateText(button, size, "CENTER", true)
	glyph:SetPoint("CENTER", button, "CENTER", 0, 1)
	if text then glyph:SetText(text) end
	return glyph
end

-- Restyles a (Portrait)FrameFlat / ButtonFrame window as a dark panel with
-- a header strip. Returns the header.
function NS:SkinPanelFrame(frame)
	local P = NS.panelStyle
	if frame.NineSlice then
		frame.NineSlice:SetAlpha(0)
	end
	for _, key in ipairs({ "Bg", "TopTileStreaks" }) do
		NS:Kill(frame[key])
	end
	NS:CreateTile(frame, 0, 0, NS.color.panel)

	local header = CreateFrame("Frame", nil, frame)
	header:SetPoint("TOPLEFT", frame, "TOPLEFT", P.margin, -P.margin)
	header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -P.margin, -P.margin)
	header:SetHeight(P.header)
	header:SetFrameLevel(frame:GetFrameLevel() + 1)
	NS:CreateTile(header, 0, 0, NS.color.header, true)

	local title = frame.GetTitleText and frame:GetTitleText()
		or (frame.TitleContainer and frame.TitleContainer.TitleText)
	if title then
		NS:StyleFont(title, 12, "CENTER")
		title:ClearAllPoints()
		title:SetPoint("LEFT", header, "LEFT", P.header, 0)
		title:SetPoint("RIGHT", header, "RIGHT", -P.header, 0)
	end

	local close = frame.ClosePanelButton or frame.CloseButton
	if close then
		close:SetSize(P.header, P.header)
		close:ClearAllPoints()
		close:SetPoint("RIGHT", header, "RIGHT", 0, 0)
		NS:SkinGlyphButton(close, 13, "x")
	end
	return header
end

-- The portrait of a panel from NS:SkinPanelFrame (or `portrait`, for
-- frames with their own) becomes a small square icon at the header's left
-- end. Returns the portrait.
function NS:SkinPanelPortrait(frame, header, portrait)
	local container = frame.PortraitContainer
	portrait = portrait or (container and container.portrait)
	if not portrait then return nil end
	local size = NS.panelStyle.header - 4
	if container and container.CircleMask and portrait == container.portrait then
		portrait:RemoveMaskTexture(container.CircleMask)
	end
	NS:Adopt(portrait, header)
	portrait:SetDrawLayer("ARTWORK")
	portrait:ClearAllPoints()
	portrait:SetPoint("LEFT", header, "LEFT", 2, 0)
	portrait:SetSize(size, size)
	NS:CropIcon(portrait)
	return portrait
end

local PANEL_BUTTON_HOVER = { 1, 1, 1, 0.08 }

-- UIPanelButtonTemplate buttons. Blizzard swaps the slice textures on
-- every click and enable change, so they're hidden by alpha. Returns the
-- tile.
function NS:SkinPanelButton(button)
	if not button then return nil end
	NS:HideTextures(button.Left, button.Middle, button.Right)
	local tile = NS:CreateTile(button, 0, 0, NS.color.tile, true)
	NS:SetFlat(button:GetHighlightTexture(), PANEL_BUTTON_HOVER, tile.fill)
	return tile
end

function NS:SkinSearchBox(box)
	if not box then return end
	NS:HideTextures(box.Left, box.Middle, box.Right)
	NS:CreateTile(box, -2, 0, NS.color.tile, true)
end

-- The suggestion list under a spell search box (SpellSearchPreviewContainerTemplate).
function NS:SkinSearchPreview(container)
	if not container then return end
	NS:HideTextures(container.Background, container.BorderAnchor, container.BotRightCorner,
		container.BottomBorder, container.LeftBorder, container.RightBorder)
	NS:CreateTile(container, 0, 0, NS.color.panel)
end

---------------------------------------------------------------------------
-- Control buttons: small flat tiles with stroke glyphs (chevrons, plus,
-- minus), dimmed while idle and lit on hover or while their menu is open.
---------------------------------------------------------------------------

-- Glyph brightness for a control's current state.
function NS:ControlBrightness(button)
	if button.IsEnabled and not button:IsEnabled() then return 0.35 end
	local active = (button.IsOver and button:IsOver())
		or (button.IsMenuOpen and button:IsMenuOpen())
		or button:IsMouseOver()
	return active and 1 or 0.72
end

function NS:CreateControlBox(button)
	return NS:CreateBox(button, button, button, NS.color.panel)
end

-- The box border lights up at full brightness.
function NS:SetControlBoxState(box, brightness)
	box.border:SetColor(unpack(brightness == 1 and NS.color.borderHover or NS.color.border))
end

function NS:CreateStroke(parent, width, height, rotation)
	local line = NS:CreateTexture(parent, "OVERLAY", 7, NS.color.text)
	line:SetSize(width, height)
	if rotation then line:SetRotation(rotation) end
	return line
end

function NS:SetStrokeBrightness(strokes, brightness)
	for _, line in ipairs(strokes) do
		line:SetVertexColor(brightness, brightness, brightness, 1)
	end
end

-- Two strokes per direction: { rotation, x, y } in degrees and units from
-- the center.
local CHEVRONS = {
	down  = { { -45, -1.8, 0 }, { 45, 1.8, 0 } },
	up    = { { 45, -1.8, 0 }, { -45, 1.8, 0 } },
	left  = { { 45, 0, 1.8 }, { -45, 0, -1.8 } },
	right = { { -45, 0, 1.8 }, { 45, 0, -1.8 } },
}

-- Returns the strokes, centered on `parent`.
function NS:CreateChevron(parent, direction)
	local strokes = {}
	for _, spec in ipairs(CHEVRONS[direction]) do
		local line = NS:CreateStroke(parent, 6, 1.5, math.rad(spec[1]))
		line:SetPoint("CENTER", parent, "CENTER", spec[2], spec[3])
		table.insert(strokes, line)
	end
	return strokes
end

-- Runs apply(button) now and on every state change. Hover changes don't
-- always go through OnButtonStateChanged, so the scripts are hooked too.
function NS:HookButtonStates(button, apply)
	if button.OnButtonStateChanged then
		NS:Hook(button, "OnButtonStateChanged", apply)
	end
	for _, script in ipairs({ "OnEnter", "OnLeave", "OnEnable", "OnDisable" }) do
		if button:HasScript(script) then
			button:HookScript(script, apply)
		end
	end
	apply(button)
end

-- Arrow dropdown buttons (WowStyle1ArrowDropdownTemplate,
-- UIPanelArrowDropdownButtonTemplate) as a box with a chevron. Blizzard
-- redraws the arrow on every state change. Returns the box.
function NS:SkinChevronDropdown(dropdown)
	if not dropdown then return nil end
	for _, region in ipairs({ dropdown:GetRegions() }) do
		if region:GetObjectType() == "Texture" and region:GetDrawLayer() == "HIGHLIGHT" then
			region:SetAlpha(0)
		end
	end
	local box = NS:CreateControlBox(dropdown)
	local strokes = NS:CreateChevron(dropdown, "down")
	NS:HookButtonStates(dropdown, function(control)
		NS:HideTextures(control.Arrow, control.Icon)
		local v = NS:ControlBrightness(control)
		NS:SetStrokeBrightness(strokes, v)
		NS:SetControlBoxState(box, v)
	end)
	return box
end

-- Previous/next page buttons as a box with a chevron.
function NS:SkinArrowButton(button, direction)
	if not button then return end
	NS:HideTextures(button:GetNormalTexture(), button:GetPushedTexture(),
		button:GetDisabledTexture(), button:GetHighlightTexture())
	local box = NS:CreateControlBox(button)
	local strokes = NS:CreateChevron(button, direction)
	NS:HookButtonStates(button, function(control)
		local v = NS:ControlBrightness(control)
		NS:SetStrokeBrightness(strokes, v)
		NS:SetControlBoxState(box, v)
	end)
end

---------------------------------------------------------------------------
-- Tab systems (TabSystemTemplate): every tab a tile, the selected one with
-- an accent border. Tabs are pooled and set up again whenever Blizzard
-- rebuilds the tab list.
--
-- style = { insetX, insetY, iconWidth }  -- tile inset; width of icon tabs
---------------------------------------------------------------------------

local TAB_HOVER = { 1, 1, 1, 0.12 }
local TAB_ART = {
	"Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
	"LeftHighlight", "MiddleHighlight", "RightHighlight",
	"SquareBackground", "SquareBackgroundActive", "SquareBackgroundActiveGlow",
}

local tabTiles = {}

-- Blizzard re-anchors the icon and the text on every selection change.
local function ApplyTabSelected(tab, isSelected)
	local tile = tabTiles[tab]
	if not tile then return end
	if tile.icon then
		tile:Layout()
	elseif tab.Text then
		tab.Text:SetPoint("CENTER", tile.fill, "CENTER", 0, 0)
	end
	tile:SetBorderColor(unpack(isSelected and NS.color.accent or NS.color.border))
end

local function SkinTab(tab, style)
	local tile = tabTiles[tab]
	if not tile then
		tile = NS:CreateTile(tab, style.insetX, style.insetY, NS.color.tile)
		tabTiles[tab] = tile
		for _, key in ipairs(TAB_ART) do
			NS:HideTextures(tab[key])
		end
		if tab.Icon and tab.IconMask then
			tab.Icon:RemoveMaskTexture(tab.IconMask)
		end
		-- The selected tab is disabled, so only the others light up.
		local hover = NS:CreateTexture(tab, "HIGHLIGHT", 0, TAB_HOVER)
		hover:SetAllPoints(tile.fill)
		NS:Hook(tab, "SetTabSelected", ApplyTabSelected)
	end
	-- Init sizes the tab and decides between icon and text.
	if tab.tabIcon and tab.Icon then
		tile.icon = tab.Icon
		NS:CropIcon(tab.Icon)
		if style.iconWidth then
			tab:SetWidth(style.iconWidth)
		end
	else
		tile.icon = nil
	end
	ApplyTabSelected(tab, tab.isSelected)
end

function NS:SkinTabSystem(tabSystem, style)
	if not tabSystem or not tabSystem.tabs then return end
	for _, tab in ipairs(tabSystem.tabs) do
		SkinTab(tab, style)
	end
	NS:Hook(tabSystem, "AddTab", function(system)
		local tab = system.tabs[#system.tabs]
		if tab then SkinTab(tab, style) end
	end)
end

local function HideDividers(bar)
	for _, poolKey in ipairs({ "HorizontalDividersPool", "VerticalDividersPool" }) do
		local pool = bar[poolKey]
		if pool then
			for divider in pool:EnumerateActive() do
				divider:Hide()
			end
		end
	end
end

function NS:KeepDividersHidden(bar)
	if not bar or not bar.UpdateDividers then return end
	NS:Hook(bar, "UpdateDividers", HideDividers)
	HideDividers(bar)
end

-- Returns the box drawn around the bar.
function NS:SkinStatusBar(bar)
	local fill = bar:GetStatusBarTexture()
	for _, region in ipairs({ bar:GetRegions() }) do
		if region ~= fill and region:GetObjectType() == "Texture" then
			NS:Kill(region)
		end
	end
	NS:RegisterBar(bar)
	local box = NS:CreateBox(bar, bar, bar, NS.color.tile)
	box.shadow = NS:CreateShadow(bar, box.base)
	return box
end

-- Protected bars keep working and keep their place; only their alpha
-- changes, after combat if need be.
function NS:HideProtectedBars(key, ...)
	local list, count = { ... }, select("#", ...) -- may contain nils
	NS:RunSafe(key, function()
		for i = 1, count do
			local bar = list[i]
			if bar then bar:SetAlpha(0) end
		end
	end)
end
