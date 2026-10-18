-- AbsoluteUI: drawing primitives and shared skinning helpers.
--
-- Borders, boxes and tiles draw their lines in whole physical pixels at any
-- resolution and UI scale, and re-lay themselves out when either changes.

local _, NS = ...

---------------------------------------------------------------------------
-- Pixel helpers
---------------------------------------------------------------------------

-- Thickness of a line, in a frame's coordinate space: one UI unit rounded
-- to whole physical pixels, at least one. That is one pixel at 1080p and
-- most UI scales, and more on high-DPI screens, so lines keep their weight
-- next to the rest of the UI. Only the screen's height matters, so wide
-- screens get the same lines as 16:9 ones.
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
-- Box: flat background plus a 1px border hugging `region` from outside, or
-- from inside after box:SetInside(true).
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
	box.border = NewBorder(borderParent, box.base, nil, true)
	box:UpdatePixels()
	NS:RegisterPixelClient(box)
	return box
end

-- Inside, the box keeps the region's exact rect at any pixel size, so its
-- edges line up with tiles laid out in UI units.
function BoxMixin:SetInside(inside)
	self.inside = inside
	self:UpdatePixels()
end

function BoxMixin:SetThickness(px)
	local out, inset = px, 0
	if self.inside then
		out, inset = 0, px
	end
	self.base:ClearAllPoints()
	self.base:SetPoint("TOPLEFT", self.region, "TOPLEFT", -out, out)
	self.base:SetPoint("BOTTOMRIGHT", self.region, "BOTTOMRIGHT", out, -out)
	self.bg:ClearAllPoints()
	self.bg:SetPoint("TOPLEFT", self.region, "TOPLEFT", inset, -inset)
	self.bg:SetPoint("BOTTOMRIGHT", self.region, "BOTTOMRIGHT", -inset, inset)
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
-- frame. An optional `tile.icon` is laid out to fill the inside, and an
-- optional `tile.anchor` region gives the rect instead of the frame (the
-- tile still draws on the frame).
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

-- Call again after setting `tile.icon` or `tile.anchor`.
function TileMixin:Layout()
	local px = NS:Px(self.frame)
	local anchor, x, y = self.anchor or self.frame, self.insetX, self.insetY
	self.rect:ClearAllPoints()
	self.rect:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, -y)
	self.rect:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -x, y)
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

-- Hides a frame's own textures (only those on `layer`, if given), except
-- the ones listed after it. Font strings and child frames are untouched.
function NS:HideRegions(frame, layer, ...)
	if not frame then return end
	local keep = {}
	for i = 1, select("#", ...) do
		local region = select(i, ...)
		if region then keep[region] = true end
	end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("Texture") and not keep[region]
			and (not layer or region:GetDrawLayer() == layer) then
			region:SetAlpha(0)
		end
	end
end

local CHECK_BOX = { 0.20, 0.20, 0.22, 1 }
local CHECK_SIZE = 12
local CHECK_INSET = 3 -- the selected mark inside the box

-- Flat checkbox from a box texture and the mark Blizzard shows when
-- checked: an accent square inside the box.
function NS:StyleCheckbox(box, mark)
	if not box then return end
	box:SetColorTexture(unpack(CHECK_BOX))
	box:SetSize(CHECK_SIZE, CHECK_SIZE)
	if mark then
		local c = NS.color.accent
		mark:SetColorTexture(c[1], c[2], c[3], 1)
		mark:ClearAllPoints()
		mark:SetPoint("TOPLEFT", box, "TOPLEFT", CHECK_INSET, -CHECK_INSET)
		mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -CHECK_INSET, CHECK_INSET)
	end
end

-- The same look for CheckButtons that draw the box as their normal
-- texture: a small box centered on the button.
function NS:SkinCheckButton(check)
	local box = check and check:GetNormalTexture()
	if not box then return end
	box:ClearAllPoints()
	box:SetPoint("CENTER", check, "CENTER")
	local mark = check:GetCheckedTexture()
	NS:StyleCheckbox(box, mark)
	local disabled = check:GetDisabledCheckedTexture()
	if disabled and mark then
		local c = NS.color.dim
		disabled:SetColorTexture(c[1], c[2], c[3], 1)
		disabled:ClearAllPoints()
		disabled:SetAllPoints(mark)
	end
	NS:HideTextures(check:GetPushedTexture())
	local hover = check:GetHighlightTexture()
	if hover then
		NS:SetFlat(hover, NS.color.glyphHover, box)
		hover:SetBlendMode("BLEND")
	end
end

local function FlattenButton(button)
	NS:HideTextures(button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture())
	NS:SetFlat(button:GetHighlightTexture(), NS.color.glyphHover, button)
end

-- Flat button with a "+" drawn in strokes (font glyphs sit off center).
-- Returns the vertical stroke: hide it for a "-".
function NS:SkinPlusButton(button)
	if not button then return nil end
	FlattenButton(button)
	local _, vertical = NS:CreatePlus(button)
	return vertical
end

-- Flat close button with an "x" drawn in strokes, as bold as the "+".
function NS:SkinCloseButton(button)
	if not button then return end
	FlattenButton(button)
	NS:CreateCross(button)
end

-- Restyles a (Portrait)FrameFlat / ButtonFrame window as a dark panel with
-- a header strip. Returns the header.
function NS:SkinPanelFrame(frame)
	NS:CreateTile(frame, 0, 0, NS.color.panel)
	return NS:SkinPanelChrome(frame)
end

-- Classic windows draw their border from pieces of their own (and a
-- ButtonFrameTemplate adds a bottom strip, named after the window).
local CLASSIC_BORDER = {
	"TitleBg", "PortraitFrame", "TopRightCorner", "TopLeftCorner", "TopBorder",
	"BotLeftCorner", "BotRightCorner", "BottomBorder", "LeftBorder", "RightBorder",
}
local CLASSIC_BUTTON_BORDER = { "BtnCornerLeft", "BtnCornerRight", "ButtonBottomBorder" }

local function HideClassicBorder(frame)
	for _, key in ipairs(CLASSIC_BORDER) do
		NS:Kill(frame[key])
	end
	local name = frame:GetName()
	if name then
		for _, key in ipairs(CLASSIC_BUTTON_BORDER) do
			NS:Kill(_G[name .. key])
		end
	end
end

-- NS:SkinPanelFrame without the panel, for windows that draw it elsewhere:
-- hides the border art and adds the header strip with the title and close
-- button. Returns the header.
function NS:SkinPanelChrome(frame)
	local P = NS.panelStyle
	if frame.NineSlice then
		frame.NineSlice:SetAlpha(0)
	end
	for _, key in ipairs({ "Bg", "TopTileStreaks" }) do
		NS:Kill(frame[key])
	end
	if NS.isClassic then
		HideClassicBorder(frame)
	end

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
		NS:SkinCloseButton(close)
	end
	return header
end

-- Classic windows such as the spellbook draw their art in a frame with room
-- around it for tabs. The panel covers `inset` = { left, top, right, bottom }
-- of the frame, and the header takes the title, close button and portrait
-- given (each optional). Returns the header and the panel's rect.
function NS:SkinClassicWindow(frame, inset, title, close, portrait)
	local P = NS.panelStyle
	local rect = frame:CreateTexture(nil, "BACKGROUND")
	rect:SetPoint("TOPLEFT", frame, "TOPLEFT", inset[1], -inset[2])
	rect:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset[3], inset[4])
	local panel = NS:CreateTile(frame, 0, 0, NS.color.panel)
	panel.anchor = rect
	panel:Layout()

	local header = NS:SkinPanelChrome(frame)
	header:ClearAllPoints()
	header:SetPoint("TOPLEFT", rect, "TOPLEFT", P.margin, -P.margin)
	header:SetPoint("TOPRIGHT", rect, "TOPRIGHT", -P.margin, -P.margin)
	if title then
		NS:Adopt(title, header)
		NS:StyleFont(title, 12, "CENTER")
		title:ClearAllPoints()
		title:SetPoint("LEFT", header, "LEFT", P.header, 0)
		title:SetPoint("RIGHT", header, "RIGHT", -P.header, 0)
	end
	if close then
		close:SetSize(P.header, P.header)
		close:ClearAllPoints()
		close:SetPoint("RIGHT", header, "RIGHT", 0, 0)
		NS:SkinCloseButton(close)
	end
	if portrait then
		NS:SkinPanelPortrait(frame, header, portrait)
	end
	return header, rect
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
	elseif frame.CircleMask and portrait == frame.Portrait then
		portrait:RemoveMaskTexture(frame.CircleMask) -- classic bag windows
	end
	NS:Adopt(portrait, header)
	portrait:SetDrawLayer("ARTWORK")
	portrait:ClearAllPoints()
	portrait:SetPoint("LEFT", header, "LEFT", 2, 0)
	portrait:SetSize(size, size)
	NS:CropIcon(portrait)
	return portrait
end

-- MaximizeMinimizeButtonFrameTemplate as flat "+" and "-" buttons, header
-- sized. It sits left of the close button.
function NS:SkinMaximizeMinimize(frame)
	if not frame then return end
	local size = NS.panelStyle.header
	frame:SetSize(size, size)
	NS:SkinPlusButton(frame.MaximizeButton)
	local minimize = NS:SkinPlusButton(frame.MinimizeButton)
	if minimize then minimize:Hide() end
end

-- UIPanelButtonTemplate buttons. Blizzard swaps the slice textures on
-- every click and enable change, so they're hidden by alpha. Returns the
-- tile.
function NS:SkinPanelButton(button)
	if not button then return nil end
	NS:HideTextures(button.Left, button.Middle, button.Right)
	local tile = NS:CreateTile(button, 0, 0, NS.color.tile, true)
	NS:SetFlat(button:GetHighlightTexture(), NS.color.rowHover, tile.fill)
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

-- A "+" from two strokes centered on `parent`; hide the vertical one for a
-- "-". Font glyphs sit off center. Returns the horizontal and vertical
-- strokes.
function NS:CreatePlus(parent, size)
	size = size or 8
	local horizontal = NS:CreateStroke(parent, size, 1.5)
	horizontal:SetPoint("CENTER", parent, "CENTER")
	local vertical = NS:CreateStroke(parent, 1.5, size)
	vertical:SetPoint("CENTER", parent, "CENTER")
	return horizontal, vertical
end

-- An "x" from two strokes crossed at 45 degrees, centered on `parent`. The
-- default length spans about as much as the "+". Returns the strokes.
function NS:CreateCross(parent, size)
	local strokes = {}
	for _, degrees in ipairs({ 45, -45 }) do
		local line = NS:CreateStroke(parent, size or 10, 1.5, math.rad(degrees))
		line:SetPoint("CENTER", parent, "CENTER")
		table.insert(strokes, line)
	end
	return strokes
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

-- Returns the strokes, centered on `parent`, or on its `point` moved by
-- (x, y).
function NS:CreateChevron(parent, direction, point, x, y)
	local strokes = {}
	for _, spec in ipairs(CHEVRONS[direction]) do
		local line = NS:CreateStroke(parent, 6, 1.5, math.rad(spec[1]))
		line:SetPoint("CENTER", parent, point or "CENTER", (x or 0) + spec[2], (y or 0) + spec[3])
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
	NS:HideRegions(dropdown, "HIGHLIGHT")
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

-- Dropdowns that show their value (WowStyle1DropdownTemplate) as a box with
-- the text and a chevron in the last `arrowWidth` units. Blizzard redraws
-- the arrow on every state change. Returns the box.
function NS:SkinTextDropdown(dropdown, arrowWidth)
	if not dropdown then return nil end
	arrowWidth = arrowWidth or 24
	NS:HideTextures(dropdown.Background)
	local box = NS:CreateControlBox(dropdown)
	box:SetInside(true)
	local strokes = NS:CreateChevron(dropdown, "down", "RIGHT", -arrowWidth / 2, 0)
	local text = dropdown.Text
	if text then
		NS:StyleFont(text, 12, "LEFT")
		text:ClearAllPoints()
		text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
		text:SetPoint("RIGHT", dropdown, "RIGHT", -arrowWidth, 0)
	end
	NS:HookButtonStates(dropdown, function(control)
		NS:HideTextures(control.Arrow)
		local v = NS:ControlBrightness(control)
		NS:SetStrokeBrightness(strokes, v)
		NS:SetControlBoxState(box, v)
		if text then text:SetTextColor(v, v, v) end
	end)
	return box
end

-- Previous/next page buttons as a box with a chevron. Returns the box.
function NS:SkinArrowButton(button, direction)
	if not button then return nil end
	NS:HideTextures(button:GetNormalTexture(), button:GetPushedTexture(),
		button:GetDisabledTexture(), button:GetHighlightTexture())
	local box = NS:CreateControlBox(button)
	local strokes = NS:CreateChevron(button, direction)
	NS:HookButtonStates(button, function(control)
		local v = NS:ControlBrightness(control)
		NS:SetStrokeBrightness(strokes, v)
		NS:SetControlBoxState(box, v)
	end)
	return box
end

local GEAR = "Interface\\WorldMap\\Gear_64Grey"

-- Settings dropdowns with an `Icon` as a box with a grey gear. Blizzard
-- re-anchors the icon on every press. Returns the box.
function NS:SkinGearDropdown(dropdown)
	if not dropdown or not dropdown.Icon then return nil end
	NS:HideRegions(dropdown, "HIGHLIGHT")
	local box = NS:CreateControlBox(dropdown)
	local icon = dropdown.Icon
	NS:HookButtonStates(dropdown, function(control)
		icon:SetTexture(GEAR)
		icon:SetTexCoord(0, 1, 0, 1)
		icon:ClearAllPoints()
		icon:SetPoint("CENTER", control, "CENTER", 0, 0)
		icon:SetSize(14, 14)
		icon:SetDesaturated(true)
		local v = NS:ControlBrightness(control)
		icon:SetVertexColor(v, v, v)
		NS:SetControlBoxState(box, v)
	end)
	return box
end

---------------------------------------------------------------------------
-- Scroll bars (MinimalScrollBar): a thin flat thumb on a faint rail, and
-- chevron steppers. Blizzard swaps their atlases on every state change.
---------------------------------------------------------------------------

local SCROLL_WIDTH = 4

local function SkinStepper(button, direction)
	if not button then return end
	local strokes = NS:CreateChevron(button, direction)
	NS:HookButtonStates(button, function(control)
		NS:HideTextures(control.Texture)
		NS:SetStrokeBrightness(strokes, NS:ControlBrightness(control))
	end)
end

function NS:SkinScrollBar(bar)
	local track = bar and bar.Track
	local thumb = track and track.Thumb
	if not thumb then return end
	NS:HideTextures(track.Begin, track.Middle, track.End)
	local rail = NS:CreateTexture(track, "BACKGROUND", 0, NS.color.highlight)
	rail:SetPoint("TOP", track, "TOP")
	rail:SetPoint("BOTTOM", track, "BOTTOM")
	rail:SetWidth(SCROLL_WIDTH)

	local fill = NS:CreateTexture(thumb, "OVERLAY", 7)
	fill:SetPoint("TOP", thumb, "TOP")
	fill:SetPoint("BOTTOM", thumb, "BOTTOM")
	fill:SetWidth(SCROLL_WIDTH)
	NS:HookButtonStates(thumb, function(control)
		NS:HideTextures(control.Begin, control.Middle, control.End)
		local active = control.down or control:IsMouseOver()
		NS:SetColor(fill, active and NS.color.dim or NS.color.borderHover)
	end)

	SkinStepper(bar.Back, "up")
	SkinStepper(bar.Forward, "down")
end

-- Classic scroll bars (UIPanelScrollBarTemplate sliders) get the same look.
-- Their thumb is a texture, so it has no hover state.
local function SkinSliderStepper(button, direction)
	if not button then return end
	NS:HideTextures(button:GetNormalTexture(), button:GetPushedTexture(),
		button:GetDisabledTexture(), button:GetHighlightTexture())
	local strokes = NS:CreateChevron(button, direction)
	NS:HookButtonStates(button, function(control)
		NS:SetStrokeBrightness(strokes, NS:ControlBrightness(control))
	end)
end

function NS:SkinSliderScrollBar(bar)
	if not bar or not bar.GetThumbTexture then return end
	local rail = NS:CreateTexture(bar, "BACKGROUND", 0, NS.color.highlight)
	rail:SetPoint("TOP", bar, "TOP")
	rail:SetPoint("BOTTOM", bar, "BOTTOM")
	rail:SetWidth(SCROLL_WIDTH)
	local thumb = bar:GetThumbTexture()
	if thumb then
		thumb:SetColorTexture(unpack(NS.color.borderHover))
		thumb:SetWidth(SCROLL_WIDTH)
	end
	SkinSliderStepper(bar.ScrollUpButton, "up")
	SkinSliderStepper(bar.ScrollDownButton, "down")
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

-- Classic tabs (CharacterFrameTabButtonTemplate and alike): a tile over the
-- tab's visible part, `inset` = { left, right, top, bottom } within the
-- tab. Blizzard disables the selected tab, which gets an accent border.
--
-- The button applies a font object per state, so it gets ours: dim while
-- idle, light on hover and when selected. Selecting or deselecting a tab
-- moves its text up or down (and resets the selected font); it stays
-- centered on the tile instead.

local classicTabs = {} -- [tab] = tile
local classicTabFonts
local classicTabsHooked = false

local function ClassicTabFonts()
	if not classicTabFonts then
		classicTabFonts = {}
		for key, color in pairs({ normal = NS.color.dim, highlight = NS.color.text, selected = NS.color.text }) do
			local font = CreateFont("AbsoluteUIClassicTab_" .. key)
			font:SetFontObject(NS:GetFont(12))
			font:SetTextColor(color[1], color[2], color[3])
			font:SetShadowOffset(1, -1)
			font:SetShadowColor(0, 0, 0, 0.9)
			classicTabFonts[key] = font
		end
	end
	return classicTabFonts
end

local function SyncClassicTab(tab)
	local tile = classicTabs[tab]
	if not tile then return end
	local fonts = ClassicTabFonts()
	tab:SetDisabledFontObject(fonts.selected)
	local text = tab:GetFontString()
	if text then
		text:SetFontObject(tab:IsEnabled() and fonts.normal or fonts.selected)
		text:ClearAllPoints()
		text:SetPoint("CENTER", tile.fill, "CENTER", 0, 0)
	end
	tile:SetBorderColor(unpack(tab:IsEnabled() and NS.color.border or NS.color.accent))
end

-- Returns the tile.
function NS:SkinClassicTab(tab, inset)
	if not tab or classicTabs[tab] then return classicTabs[tab] end
	for _, region in ipairs({ tab:GetRegions() }) do
		if region:IsObjectType("Texture") then
			region:SetAlpha(0)
		end
	end
	NS:HideTextures(tab:GetNormalTexture(), tab:GetPushedTexture(), tab:GetDisabledTexture(), tab:GetHighlightTexture())

	local rect = tab:CreateTexture(nil, "BACKGROUND")
	rect:SetPoint("TOPLEFT", tab, "TOPLEFT", inset[1], -inset[3])
	rect:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -inset[2], inset[4])
	local tile = NS:CreateTile(tab, 0, 0, NS.color.tile)
	tile.anchor = rect
	tile:Layout()
	local hover = NS:CreateTexture(tab, "HIGHLIGHT", 0, TAB_HOVER)
	hover:SetAllPoints(tile.fill)
	classicTabs[tab] = tile

	local fonts = ClassicTabFonts()
	tab:SetNormalFontObject(fonts.normal)
	tab:SetHighlightFontObject(fonts.highlight)
	-- Spellbook tabs move their text in OnEnable/OnDisable, talent tabs in
	-- PanelTemplates_SelectTab/DeselectTab.
	tab:HookScript("OnEnable", SyncClassicTab)
	tab:HookScript("OnDisable", SyncClassicTab)
	if not classicTabsHooked then
		classicTabsHooked = true
		NS:Hook(nil, "PanelTemplates_SelectTab", SyncClassicTab)
		NS:Hook(nil, "PanelTemplates_DeselectTab", SyncClassicTab)
	end
	SyncClassicTab(tab)
	return tile
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
