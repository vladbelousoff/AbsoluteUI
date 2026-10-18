-- AbsoluteUI: Attune's window, quest reward panel and quest details.
--
-- Attune's window is an AceGUI frame under a PortraitFrameTemplate border.
-- AceGUI hands its widgets to whichever addon asks next once they're
-- released, so of the window's contents only the tree's backdrops are
-- flattened, and they get their own back before the next rebuild. The
-- chain nodes keep their colors: those show quest progress.

local _, NS = ...

local M = NS:NewModule("Attune", { setting = "skinAttune", addon = "Attune" })

---------------------------------------------------------------------------
-- Main window
---------------------------------------------------------------------------

local skinned = {}

local function SkinChrome(chrome)
	if not chrome or skinned[chrome] then return end
	skinned[chrome] = true
	local header = NS:SkinPanelFrame(chrome)
	NS:SkinPanelPortrait(chrome, header)
	-- ButtonFrameTemplate (the reward panel) adds an inset.
	local inset = chrome.Inset
	if inset then
		if inset.NineSlice then inset.NineSlice:SetAlpha(0) end
		NS:HideTextures(inset.Bg)
	end
end

-- Attune's buttons on the window itself (not AceGUI's): Survey and
-- Results. AceGUI widgets carry `obj`.
local function SkinWindowButtons(window)
	for _, child in ipairs({ window:GetChildren() }) do
		if not skinned[child] and not child.obj and child:IsObjectType("Button")
			and child.Left and child.Middle and child.Right then
			skinned[child] = true
			NS:SkinPanelButton(child)
		end
	end
end

-- The pooled tree widget's frames that were flattened, put back on every
-- rebuild.
local pooled = {}

local function SkinTree()
	for frame in pairs(pooled) do
		NS:RestoreBackdrop(frame)
		pooled[frame] = nil
	end
	local window = _G.Attune_MainFrame
	local widget = window and window.obj
	local tree = widget and widget.children and widget.children[1]
	if not tree then return end
	for _, frame in ipairs({ tree.treeframe, tree.border }) do
		NS:FlattenBackdrop(frame)
		pooled[frame] = true
	end
end

-- The quest chain: nodes and their badges are Attune's own frames.
local function SkinGraph()
	NS:FlattenBackdrops(_G.Attune_GraphRoot)
end

---------------------------------------------------------------------------
-- Side panels
---------------------------------------------------------------------------

local function SkinRows(rows)
	for _, row in ipairs(rows or {}) do
		local icon = row.icon or row.Icon
		if icon and icon.GetTexture and not skinned[row] then
			skinned[row] = true
			NS:CreateBox(row, row, icon, NS.color.tile)
		end
		NS:CropIcon(icon)
	end
end

local function SkinPanel(panel)
	if not panel then return end
	if panel.bronze then
		SkinChrome(panel.bronze)
	end
	NS:FlattenBackdrops(panel, true)
	NS:SkinDescendants(panel)
	SkinRows(panel.rows)
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

local function OnToggleView()
	local window = _G.Attune_MainFrame
	if not window then return end
	SkinChrome(_G.AttuneBronzeChrome)
	SkinWindowButtons(window)
	-- AceGUI's status bar under the window.
	local widget = window.obj
	if widget and widget.statustext then
		NS:FlattenBackdrop(widget.statustext:GetParent())
	end
	SkinTree()
end

function M:Init()
	NS:Hook(nil, "Attune_Frame", OnToggleView)
	NS:Hook(nil, "Attune_ToggleView", OnToggleView)
	NS:Hook(nil, "Attune_Select", SkinGraph)
	NS:Hook(nil, "Attune_ShowQuestRewards", function() SkinPanel(_G.AttuneQuestRewardFrame) end)
	NS:Hook(nil, "Attune_ShowQuestDetail", function() SkinPanel(_G.AttuneQuestDetail) end)
	-- The portrait changes with the view.
	NS:Hook(nil, "Attune_UpdateWindowPortrait", function()
		local chrome = _G.AttuneBronzeChrome
		local container = chrome and chrome.PortraitContainer
		NS:CropIcon(container and container.portrait or (chrome and chrome.portrait))
	end)
	if _G.Attune_MainFrame then
		OnToggleView()
	end
end
