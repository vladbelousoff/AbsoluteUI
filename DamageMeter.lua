-- AbsoluteUI: Blizzard's built-in damage meter.
--
-- The meter's own settings keep working, except row height and spacing,
-- which come from AbsoluteUI. Windows and rows are styled as Blizzard
-- creates them.

local _, NS = ...

local M = NS:NewModule("DamageMeter", { setting = "damageMeter", addon = "Blizzard_DamageMeter" })

local windows = {}
local entries = {}

---------------------------------------------------------------------------
-- Row height and spacing
--
-- Setting the meter's own bar height would taint it (its rows handle secret
-- values), so the list is scaled instead: one row plus Blizzard's spacing
-- comes out meterBarHeight + meterBarSpacing tall. Each bar is pinned to
-- the top of its row at meterBarHeight, leaving the gap below. Texts are
-- sized down by the scale to keep their size.
---------------------------------------------------------------------------

local TEXT_SIZE = 12
local DEFAULT_SPACING = 4 -- DAMAGE_METER_DEFAULT_BAR_SPACING

local function RowScale(entry)
	local meter = DamageMeter or UIParent
	return entry:GetEffectiveScale() / meter:GetEffectiveScale()
end

-- In the entry's own (scaled) units.
local function BarHeight(entry)
	return NS.db.meterBarHeight / RowScale(entry)
end

local function StyleEntryText(entry)
	local skin = entries[entry]
	local size = TEXT_SIZE / RowScale(entry)
	if not skin or skin.textSize == size then return end
	skin.textSize = size
	NS:StyleBarText(entry:GetName(), size, "LEFT")
	NS:StyleBarText(entry:GetValue(), size, "RIGHT")
end

local StyleEntry -- below

local function ApplyRowHeight(window)
	local scrollBox = window.GetScrollBox and window:GetScrollBox()
	local base = window.GetBarHeight and window:GetBarHeight()
	if not scrollBox or type(base) ~= "number" or base <= 0 then return end
	local spacing = window.GetBarSpacing and window:GetBarSpacing()
	if type(spacing) ~= "number" or spacing < 0 then
		spacing = DEFAULT_SPACING
	end
	local scale = (NS.db.meterBarHeight + NS.db.meterBarSpacing) / (base + spacing)
	scrollBox:SetScale(scale)
	-- The player's pinned row, shown when scrolled out of view.
	local localPlayer = window.GetLocalPlayerEntry and window:GetLocalPlayerEntry()
	if localPlayer then
		localPlayer:SetScale(scale)
	end
	for entry in pairs(entries) do
		StyleEntryText(entry)
		StyleEntry(entry)
	end
end

---------------------------------------------------------------------------
-- Entries
---------------------------------------------------------------------------

-- Re-applied after every style update, which resets the background atlas
-- and the bar and text anchors.
function StyleEntry(entry)
	if not entries[entry] then return end
	local bar = entry:GetStatusBar()
	local height = BarHeight(entry)

	-- A square as tall as the bar, instead of a fixed 24x24.
	local icon = entry.Icon
	if icon then
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", entry, "TOPLEFT", 0, 0)
		icon:SetSize(height, height)
	end

	local relativeTo, x = entry, 0
	if entry.GetIconAttachmentAnchor then
		local _, anchor = entry:GetIconAttachmentAnchor()
		if anchor and anchor ~= entry and icon then
			relativeTo, x = icon, 2
		end
	end
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", relativeTo, relativeTo == entry and "TOPLEFT" or "TOPRIGHT", x, 0)
	bar:SetPoint("TOPRIGHT", entry, "TOPRIGHT", 0, 0)
	bar:SetHeight(height)

	local name, value = entry:GetName(), entry:GetValue()
	value:ClearAllPoints()
	value:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	name:ClearAllPoints()
	name:SetPoint("LEFT", bar, "LEFT", 4, 0)
	name:SetPoint("RIGHT", value, "LEFT", -8, 0)

	local background = entry:GetBackground()
	local c = NS.color.tile
	background:SetColorTexture(c[1], c[2], c[3], 1)
	background:ClearAllPoints()
	background:SetAllPoints(bar)
end

local function IsEntry(frame)
	return type(frame) == "table" and frame.GetStatusBar ~= nil and frame.GetBackground ~= nil
end

-- Called as (owner, frame) by scroll box callbacks, but as (frame,
-- elementData) when a scroll box iterates existing frames; accept both.
local function SkinEntry(a, b)
	local entry = IsEntry(b) and b or (IsEntry(a) and a or nil)
	if not entry or entries[entry] then return end
	local bar = entry:GetStatusBar()
	local skin = {}
	entries[entry] = skin

	NS:RegisterBar(bar)
	NS:Kill(entry:GetBackgroundEdge())
	NS:CreateBorder(bar, bar, "OVERLAY")
	StyleEntryText(entry)

	NS:Hook(entry, "UpdateStyle", StyleEntry)
	StyleEntry(entry)
	-- The new fill needs Blizzard's vertex color again.
	if entry.UpdateStatusBarColor then
		entry:UpdateStatusBarColor()
	end
end

-- InitEntry and the initialized callback together catch every row.
local function WatchScrollBox(scrollBox, window)
	if not scrollBox then return end
	if window and window.InitEntry then
		NS:Hook(window, "InitEntry", SkinEntry)
	end
	if ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
		ScrollUtil.AddInitializedFrameCallback(scrollBox, SkinEntry, M, true)
	elseif ScrollBoxListMixin and ScrollBoxListMixin.Event then
		scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, SkinEntry, M)
	end
end

---------------------------------------------------------------------------
-- Header controls: 20px flat tiles on the header's center line.
-- | [v] Type name ............ timer [Session] [gear] [-] |
---------------------------------------------------------------------------

local CONTROL = 20
local CONTROL_GAP = 4
local HEADER_MARGIN = 6

-- Blizzard's dropdowns redraw their art on every state change, so the
-- apply functions below run after each one (NS:HookButtonStates).

local function SkinSessionDropdown(dropdown)
	if not dropdown then return end
	if dropdown.Background then dropdown.Background:SetAlpha(0) end
	local box = NS:CreateControlBox(dropdown)
	for _, fs in pairs({ dropdown.Text, dropdown.SessionName }) do
		NS:StyleFont(fs, 11, "CENTER")
	end
	NS:HookButtonStates(dropdown, function(self)
		if self.Arrow then self.Arrow:SetAlpha(0) end
		local v = NS:ControlBrightness(self)
		for _, fs in pairs({ self.Text, self.SessionName }) do
			fs:SetTextColor(v, v, v)
		end
		NS:SetControlBoxState(box, v)
	end)
end

-- A minus, or a plus while collapsed.
local function SkinCollapseButton(button, window)
	if not button then return end
	for _, texture in pairs({ button:GetNormalTexture(), button:GetPushedTexture(),
		button:GetHighlightTexture(), button:GetDisabledTexture() }) do
		texture:SetAlpha(0)
	end
	local box = NS:CreateControlBox(button)
	local horizontal, vertical = NS:CreatePlus(button)
	local strokes = { horizontal, vertical }
	local function Apply()
		vertical:SetShown((window.IsMinimized and window:IsMinimized()) and true or false)
		local v = button:IsMouseOver() and 1 or 0.72
		NS:SetStrokeBrightness(strokes, v)
		NS:SetControlBoxState(box, v)
	end
	button:HookScript("OnEnter", Apply)
	button:HookScript("OnLeave", Apply)
	NS:Hook(window, "SetMinimized", Apply)
	Apply()
end

local function Place(region, point, relativeTo, relativePoint, x)
	if not region then return end
	region:ClearAllPoints()
	region:SetPoint(point, relativeTo, relativePoint, x, 0)
end

-- Blizzard's offsets are tuned for its own header art.
local function LayoutHeader(window, rect)
	local collapse = window.MinimizeButton
	local settings = window.SettingsDropdown
	local session = window.SessionDropdown
	local typeDropdown = window.DamageMeterTypeDropdown
	local timer = window.SessionTimer

	if collapse then
		collapse:SetSize(CONTROL, CONTROL)
		Place(collapse, "RIGHT", rect, "RIGHT", -HEADER_MARGIN)
	end
	if settings then
		settings:SetSize(CONTROL, CONTROL)
		Place(settings, "RIGHT", collapse or rect, collapse and "LEFT" or "RIGHT", -CONTROL_GAP)
	end
	if session then
		session:SetHeight(CONTROL)
		Place(session, "RIGHT", settings or rect, settings and "LEFT" or "RIGHT", -CONTROL_GAP)
	end
	Place(timer, "RIGHT", session or rect, session and "LEFT" or "RIGHT", -HEADER_MARGIN)

	if typeDropdown then
		typeDropdown:SetSize(CONTROL, CONTROL)
		Place(typeDropdown, "LEFT", rect, "LEFT", HEADER_MARGIN)
		local typeName = typeDropdown.TypeName
		if typeName then
			Place(typeName, "LEFT", typeDropdown, "RIGHT", HEADER_MARGIN)
			typeName:SetPoint("RIGHT", timer or session or rect, "LEFT", -HEADER_MARGIN, 0)
		end
	end
end

local function SkinResizeButton(button)
	if not button then return end
	for _, texture in pairs({ button:GetNormalTexture(), button:GetHighlightTexture(), button:GetPushedTexture() }) do
		texture:SetDesaturated(true)
		texture:SetVertexColor(0.8, 0.8, 0.8)
	end
end

-- The border around `borderRect` (default: the background) fades with the
-- window transparency setting. Returns the function that syncs it.
local function SkinBackground(owner, background, borderRect)
	local c = NS.color.panel
	background:SetTexture(NS.SOLID)
	background:SetVertexColor(c[1], c[2], c[3], 1)
	local border = NS:CreateBorder(owner, borderRect or background)
	local function Sync()
		border:SetAlpha(background:GetAlpha())
	end
	Sync()
	return Sync
end

---------------------------------------------------------------------------
-- Windows
---------------------------------------------------------------------------

local function SkinSourceWindow(window)
	if not window or windows[window] then return end
	windows[window] = true
	if window.Background then
		local sync = SkinBackground(window, window.Background)
		if window.UpdateBackground then
			NS:Hook(window, "UpdateBackground", sync)
		end
	end
	NS:SkinCloseButton(window.CloseButton)
	SkinResizeButton(window.ResizeButton)
	WatchScrollBox(window.ScrollBox, window)
	NS:Hook(window, "OnBarHeightChanged", ApplyRowHeight)
	NS:Hook(window, "OnBarSpacingChanged", ApplyRowHeight)
	ApplyRowHeight(window)
end

local function SkinSessionWindow(window)
	if not window or windows[window] then return end
	windows[window] = true

	-- A flat fill over the header area, framed by the window's own border.
	local header = window.Header
	local rect
	if header then
		NS:Kill(header)
		rect = window:CreateTexture(nil, "BACKGROUND", nil, -8)
		rect:SetAllPoints(header)
		rect:SetTexture(NS.SOLID)
		NS:SetColor(rect, NS.color.meterHeader)
	end

	for _, fs in pairs({
		window.SessionTimer,
		window.SessionDropdown and window.SessionDropdown.SessionName,
		window.DamageMeterTypeDropdown and window.DamageMeterTypeDropdown.TypeName,
	}) do
		NS:StyleFont(fs, 12, fs:GetJustifyH())
	end

	NS:SkinChevronDropdown(window.DamageMeterTypeDropdown)
	SkinSessionDropdown(window.SessionDropdown)
	NS:SkinGearDropdown(window.SettingsDropdown)
	SkinCollapseButton(window.MinimizeButton, window)
	if rect then
		LayoutHeader(window, rect)
	end

	local container = window.MinimizeContainer
	if container then
		if container.Background then
			SkinResizeButton(container.ResizeButton)
			-- Starts below the header so it can't paint over the header fill.
			if header then
				container.Background:ClearAllPoints()
				container.Background:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
				container.Background:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT")
			end
			local sync = SkinBackground(container, container.Background, window)
			if window.UpdateBackground then
				NS:Hook(window, "UpdateBackground", sync)
			end
		end
		WatchScrollBox(container.ScrollBox, window)
		SkinEntry(nil, container.LocalPlayerEntry)
		SkinSourceWindow(container.SourceWindow)
	end
	NS:Hook(window, "OnBarHeightChanged", ApplyRowHeight)
	NS:Hook(window, "OnBarSpacingChanged", ApplyRowHeight)
	ApplyRowHeight(window)
end

function M:UpdateRowHeight()
	for window in pairs(windows) do
		ApplyRowHeight(window)
	end
end

local function OnRowSettingChanged()
	if M.loaded then M:UpdateRowHeight() end
end
NS:OnSettingChanged("meterBarHeight", OnRowSettingChanged)
NS:OnSettingChanged("meterBarSpacing", OnRowSettingChanged)

function M:Init()
	local meter = DamageMeter
	if not meter then
		NS:Missing("DamageMeter")
		return
	end

	if meter.ForEachSessionWindow and meter.windowDataList then
		meter:ForEachSessionWindow(SkinSessionWindow)
	end
	NS:Hook(meter, "SetupSessionWindow", function(_, _, windowData)
		SkinSessionWindow(windowData and windowData.sessionWindow)
	end)
end
