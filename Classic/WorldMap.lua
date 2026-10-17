-- AbsoluteUI: classic world map (WorldMapFrame).
--
-- Two modes: maximized (1024x768 over a black screen, with zone dropdowns
-- above the map) and a small window. Blizzard's art goes; a panel frames
-- the map canvas with a margin, with a header strip on top carrying the map
-- name and the window buttons. Blizzard re-anchors the buttons on every
-- mode change, so the layout is redone after it.

local _, NS = ...

local M = NS:NewModule("WorldMap", { setting = "worldMap", addon = "Blizzard_WorldMap", flavor = "classic" })

local P = NS.panelStyle
local BORDER = 1 -- the canvas frame, drawn outside the canvas

local rect, header, title

-- The panel reaches a margin past the canvas frame on three sides. When
-- maximized it starts at the window's top, above the dropdowns; the small
-- window has room for the header above its canvas only.
local function Layout(map)
	local canvas = map.ScrollContainer
	local out = P.margin + BORDER
	rect:ClearAllPoints()
	rect:SetPoint("LEFT", canvas, "LEFT", -out, 0)
	rect:SetPoint("RIGHT", canvas, "RIGHT", out, 0)
	rect:SetPoint("BOTTOM", canvas, "BOTTOM", 0, -out)
	if map:IsMaximized() then
		rect:SetPoint("TOP", map, "TOP", 0, 0)
	else
		rect:SetPoint("TOP", canvas, "TOP", 0, out + P.header + P.margin)
	end

	local close = WorldMapFrameCloseButton
	if close then
		close:ClearAllPoints()
		close:SetPoint("RIGHT", header, "RIGHT", 0, 0)
	end
	local sizer = map.MaximizeMinimizeFrame
	if sizer and close then
		sizer:ClearAllPoints()
		sizer:SetPoint("RIGHT", close, "LEFT", 0, 0)
	end
end

local function UpdateTitle()
	local name = MiniWorldMapTitle and MiniWorldMapTitle:GetText()
	title:SetText(name or WORLD_MAP)
end

-- Both border frames go with their titles (unnamed when maximized); the
-- small window's title still names the map for ours.
local function HideBorderArt(map)
	for _, border in ipairs({ map.BorderFrame, map.MiniBorderFrame }) do
		for _, region in ipairs({ border:GetRegions() }) do
			NS:Kill(region)
		end
	end
end

function M:Init()
	local map = WorldMapFrame
	if not map or not map.ScrollContainer or not map.BorderFrame or not map.MiniBorderFrame then
		NS:Missing("WorldMapFrame")
		return
	end

	HideBorderArt(map)

	rect = map:CreateTexture(nil, "BACKGROUND")
	local panel = NS:CreateTile(map, 0, 0, NS.color.panel)
	panel.anchor = rect
	NS:CreateBox(map, map, map.ScrollContainer, NS.color.panel)

	header = CreateFrame("Frame", nil, map)
	header:SetPoint("TOPLEFT", rect, "TOPLEFT", P.margin, -P.margin)
	header:SetPoint("TOPRIGHT", rect, "TOPRIGHT", -P.margin, -P.margin)
	header:SetHeight(P.header)
	header:SetFrameLevel(map:GetFrameLevel() + 2)
	NS:CreateTile(header, 0, 0, NS.color.header, true)
	title = NS:CreateText(header, 12, "CENTER")
	title:SetPoint("LEFT", header, "LEFT", P.header * 2, 0)
	title:SetPoint("RIGHT", header, "RIGHT", -P.header * 2, 0)

	local close = WorldMapFrameCloseButton
	if close then
		close:SetSize(P.header, P.header)
		close:SetFrameLevel(header:GetFrameLevel() + 1)
		NS:SkinCloseButton(close)
	end
	if map.MaximizeMinimizeFrame then
		map.MaximizeMinimizeFrame:SetFrameLevel(header:GetFrameLevel() + 1)
		NS:SkinMaximizeMinimize(map.MaximizeMinimizeFrame)
	end
	NS:SkinPanelButton(WorldMapZoomOutButton)

	NS:Hook(map, "SynchronizeDisplayState", Layout)
	NS:Hook(nil, "WorldMapFrame_SetMapName", UpdateTitle)
	Layout(map)
	panel:Layout()
	UpdateTitle()
end
