-- AbsoluteUI: Mapster on our world map.
--
-- Mapster moves and scales the map but keeps Blizzard's frame, so the
-- World map skin carries on as usual. Its "Mapster" button joins our
-- header, left of the window buttons, and its coordinates use the bar
-- font. With the World map skin off this does nothing.

local _, NS = ...

local M = NS:NewModule("Mapster", { setting = "skinMapster", addon = "Mapster", flavor = "modern" })

local BUTTON_WIDTH = 70

local function SkinButton(mapster)
	local button = mapster.optionsButton
	if not button or M.button == button then return end
	M.button = button
	local border = WorldMapFrame.BorderFrame
	local sizer = border and border.MaximizeMinimizeFrame
	NS:SkinPanelButton(button)
	button:SetSize(BUTTON_WIDTH, NS.panelStyle.header)
	local text = button:GetFontString()
	if text then NS:StyleFont(text, 11, "CENTER") end
	if sizer then
		button:ClearAllPoints()
		button:SetPoint("RIGHT", sizer, "LEFT", -2, 0)
	end
end

-- Mapster sets the font on every map resize.
local function SkinCoords()
	local display = _G.Mapster_CoordsFrame
	if not display then return end
	for _, region in ipairs({ display:GetRegions() }) do
		if region:IsObjectType("FontString") then
			local _, size = region:GetFont()
			region:SetFont(NS:GetBarFontFile(), size or 12, "OUTLINE")
		end
	end
end

function M:Init()
	if not NS.db.worldMap then return end
	local aceAddon = _G.LibStub and _G.LibStub("AceAddon-3.0", true)
	local mapster = aceAddon and aceAddon:GetAddon("Mapster", true)
	if not mapster then
		NS:Missing("Mapster addon object")
		return
	end
	NS:Hook(mapster, "SetupMapButton", SkinButton)
	SkinButton(mapster)

	local coords = mapster.GetModule and mapster:GetModule("Coords", true)
	if coords then
		NS:Hook(coords, "UpdateMapSize", SkinCoords)
		SkinCoords()
	end
end
