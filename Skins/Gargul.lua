-- AbsoluteUI: Gargul's windows.
--
-- Gargul has two kinds. Its own (Interface:createWindow) are plain frames
-- it keeps, so they get the full look, contents included. The rest are
-- AceGUI frames, which go back to a pool every addon shares when Gargul
-- closes them: those only get a flat backdrop, no title art and a flat
-- close button, all put back when the frame is released.

local _, NS = ...

local M = NS:NewModule("Gargul", { setting = "skinGargul", addon = "Gargul", early = true })

local BUTTON = NS.panelStyle.header

---------------------------------------------------------------------------
-- Gargul's own windows
---------------------------------------------------------------------------

local windows = {}

local function SkinContents(window)
	NS:FlattenBackdrops(window, true)
	NS:SkinDescendants(window)
end

-- The close and minimize buttons sit past the corner, sized for
-- Blizzard's art; ours go inside it.
local function PlaceButtons(window)
	local close, minimize = window.CloseButton, window.Minimize or window.Maximize
	if close then
		close:SetScale(1)
		close:SetSize(BUTTON, BUTTON)
		close:ClearAllPoints()
		close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -6, -6)
	end
	if minimize then
		NS:SkinMaximizeMinimize(minimize)
		minimize:ClearAllPoints()
		if close then
			minimize:SetPoint("RIGHT", close, "LEFT", 0, 0)
		else
			minimize:SetPoint("TOPRIGHT", window, "TOPRIGHT", -6, -6)
		end
	end
end

local function SkinWindow(window)
	if not window or windows[window] then return end
	windows[window] = true
	SkinContents(window)
	if window.SetBackdropColor then
		window:SetBackdropColor(unpack(NS.color.panel))
	end
	PlaceButtons(window)
	-- Windows fill in their contents when they open.
	window:HookScript("OnShow", function(self)
		SkinContents(self)
		C_Timer.After(0, function() NS.SafeCall(SkinContents, self) end)
	end)
	SkinWindow(window.Minimized)
end

---------------------------------------------------------------------------
-- AceGUI windows (reversible)
---------------------------------------------------------------------------

local HEADER_ART = 131080 -- Interface\DialogFrame\UI-DialogBox-Header

local aceFrames = {}  -- [widget] = { hidden textures, close button tile }
local releaseHooked = {}

local function SkinCloseButton(button)
	local tile = NS:CreateTile(button, 0, 0, NS.color.tile, true)
	NS:HideTextures(button.Left, button.Middle, button.Right)
	return tile
end

local function UnskinAceFrame(widget)
	local state = aceFrames[widget]
	if not state then return end
	aceFrames[widget] = nil
	NS:RestoreBackdrop(widget.frame)
	if widget.statustext then
		NS:RestoreBackdrop(widget.statustext:GetParent())
	end
	for _, texture in ipairs(state.art) do
		texture:SetAlpha(1)
	end
	if state.close then
		state.close.tile:SetShown(false)
		local button = state.close.button
		for _, key in ipairs({ "Left", "Middle", "Right" }) do
			if button[key] then button[key]:SetAlpha(1) end
		end
	end
end

local closeTiles = {} -- [button] = tile, reused when the frame comes back

local function SkinAceFrame(widget)
	local frame = widget and widget.frame
	if not frame or aceFrames[widget] or not frame.SetBackdrop then return end
	local state = { art = {} }
	aceFrames[widget] = state

	NS:FlattenBackdrop(frame)
	frame:SetBackdropColor(unpack(NS.color.panel))
	frame:SetBackdropBorderColor(unpack(NS.color.border))
	local status = widget.statustext and widget.statustext:GetParent()
	if status then
		NS:FlattenBackdrop(status)
		status:SetBackdropColor(unpack(NS.color.tile))
		status:SetBackdropBorderColor(unpack(NS.color.border))
	end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("Texture") and region:GetTexture() == HEADER_ART then
			region:SetAlpha(0)
			table.insert(state.art, region)
		end
	end
	-- AceGUI's "Close" button is the frame's only UIPanelButtonTemplate.
	for _, child in ipairs({ frame:GetChildren() }) do
		if child:IsObjectType("Button") and child.Left and child.Middle and child.Right then
			local tile = closeTiles[child] or SkinCloseButton(child)
			closeTiles[child] = tile
			tile:SetShown(true)
			NS:HideTextures(child.Left, child.Middle, child.Right)
			state.close = { button = child, tile = tile }
			break
		end
	end

	if not releaseHooked[widget] and type(widget.OnRelease) == "function" then
		releaseHooked[widget] = true
		hooksecurefunc(widget, "OnRelease", UnskinAceFrame)
	end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Init()
	local gargul = _G.Gargul
	local interface = gargul and gargul.Interface
	if not interface then
		NS:Missing("Gargul.Interface")
		return
	end
	NS:Hook(interface, "createWindow", function(_, spec)
		if type(spec) == "table" and spec.name then
			SkinWindow(_G[spec.name])
		end
	end)
	-- Gargul files every AceGUI window it opens through this.
	NS:Hook(interface, "set", function(_, _, _, item)
		if type(item) == "table" and item.type == "Frame" and item.frame then
			SkinAceFrame(item)
		end
	end)
end
