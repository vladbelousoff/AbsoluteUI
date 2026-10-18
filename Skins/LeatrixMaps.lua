-- AbsoluteUI: Leatrix Maps' zone menus, coordinates and options windows.
--
-- The map itself is the World map skin's. Leatrix Maps keeps its frames to
-- itself, so they're found by shape: the zone menus are dropdowns in an
-- unnamed strip on the map, the coordinates unnamed frames holding one
-- text (`x`), and the options windows the 470x470 panels it registers to
-- close on Escape.

local _, NS = ...

local M = NS:NewModule("LeatrixMaps", { setting = "skinLeatrixMaps", addon = "Leatrix_Maps" })

local PANEL_SIZE = 470

local dropdowns, coords, panels = {}, {}, {}

local function IsDropdown(frame)
	return frame:IsObjectType("DropdownButton") and frame.Background and frame.Text
end

-- Zone and continent menus, and the coordinates. Blizzard's own map
-- dropdowns are direct children of the map; Leatrix's sit in a strip.
local function SkinMapParts()
	local map = WorldMapFrame
	if not map then return end
	for _, child in ipairs({ map:GetChildren() }) do
		if not child:GetName() then
			for _, inner in ipairs({ child:GetChildren() }) do
				if not dropdowns[inner] and IsDropdown(inner) then
					dropdowns[inner] = true
					NS:SkinTextDropdown(inner, 20)
				end
			end
			local text = child.x
			if not coords[child] and type(text) == "table" and text.IsObjectType and text:IsObjectType("FontString") then
				coords[child] = true
				NS:StyleFont(text, 12, "LEFT", true)
			end
		end
	end
end

-- Leatrix draws its buttons with its own texture over the template's.
local function SkinButtons(panel)
	for _, child in ipairs({ panel:GetChildren() }) do
		if child:IsObjectType("Button") and child.Left and child.Middle and child.Right then
			NS:SkinPanelButton(child)
			NS:HideTextures(child:GetNormalTexture())
		end
	end
end

local function SkinPanel(panel)
	if panels[panel] then return end
	panels[panel] = true
	-- Its parchment, and the dark wash under it.
	NS:HideRegions(panel, "BORDER")
	NS:HideTextures(panel.t)
	NS:CreateTile(panel, 0, 0, NS.color.panel)
	SkinButtons(panel)
	NS:SkinDescendants(panel)
end

local function IsLeatrixPanel(frame)
	if type(frame) ~= "table" or not frame.GetSize or not frame.t then return false end
	local w, h = frame:GetSize()
	return math.floor(w + 0.5) == PANEL_SIZE and math.floor(h + 0.5) == PANEL_SIZE
		and frame:GetFrameStrata() == "FULLSCREEN_DIALOG"
end

local function SkinPanels()
	for _, name in ipairs(UISpecialFrames or {}) do
		local frame = _G[name]
		if IsLeatrixPanel(frame) then
			SkinPanel(frame)
		end
	end
end

local function SkinAll()
	SkinMapParts()
	SkinPanels()
end

function M:Init()
	-- Leatrix builds most of its parts when the world is first entered.
	SkinAll()
	NS:On("PLAYER_ENTERING_WORLD", function()
		C_Timer.After(0, function() NS.SafeCall(SkinAll) end)
	end)
	if WorldMapFrame then
		WorldMapFrame:HookScript("OnShow", SkinAll)
	end
	if SlashCmdList and type(SlashCmdList.Leatrix_Maps) == "function" then
		hooksecurefunc(SlashCmdList, "Leatrix_Maps", SkinPanels)
	end
end
