-- AbsoluteUI: Blizzard's bag windows and Bagnon's.
--
-- Both use Blizzard's item button template, so they share one item skin.
-- Bagnon gets an "AbsoluteUI" skin through its skin API that replaces its
-- default skin; Bagnon's saved settings are never written.
--
-- Item clicks use protected functions, so Blizzard's buttons only get
-- textures and post-hooks, never fields.

local _, NS = ...

local M = NS:NewModule("Bags", { setting = "bags" })

local SKIN_ID = "AbsoluteUI"
local ITEM_HOVER = { 1, 1, 1, 0.15 }
local ITEM_PUSHED = { 1, 1, 1, 0.25 }
local MIN_QUALITY = 2 -- uncommon; poor and common items keep a plain border

---------------------------------------------------------------------------
-- Item slots (ContainerFrameItemButtonTemplate: Blizzard and Bagnon)
---------------------------------------------------------------------------

local items = {} -- [button] = tile

local function SkinItem(button)
	local tile = items[button]
	if tile then return tile end
	local icon = button.icon
	if not icon then return nil end

	tile = NS:CreateTile(button)
	items[button] = tile
	tile.icon = icon
	tile:Layout()

	-- Quality shows on our border instead (Bagnon's glow too).
	NS:HideTextures(button:GetNormalTexture(), button.IconBorder, button.IconGlow)
	NS:SetFlat(button:GetPushedTexture(), ITEM_PUSHED, tile.fill)
	NS:SetFlat(button:GetHighlightTexture(), ITEM_HOVER, tile.fill)
	if button.Cooldown then
		button.Cooldown:ClearAllPoints()
		button.Cooldown:SetAllPoints(tile.fill)
	end
	if button.Count then
		NS:StyleFont(button.Count, 12, "RIGHT", true)
	end
	return tile
end

-- Re-applied after every update: Blizzard re-shows the empty slot art and
-- resets the icon crop. `r` nil means a plain border.
local function SyncItem(button, hasItem, r, g, b)
	local tile = SkinItem(button)
	if not tile then return end
	-- Combined bags create this on first use.
	NS:Kill(button.ItemSlotBackground)
	if hasItem then
		NS:CropIcon(tile.icon)
		tile.icon:Show()
	else
		tile.icon:Hide()
	end
	if r then
		tile:SetBorderColor(r, g, b)
	else
		tile:SetBorderColor(unpack(NS.color.border))
	end
end

---------------------------------------------------------------------------
-- Blizzard's bag windows
---------------------------------------------------------------------------

-- Not EnumerateValidItems: it yields nil for slots not built yet.
local function SyncBlizzardItems(frame)
	for _, button in ipairs(frame.Items or {}) do
		local slot, bag = button:GetSlotAndBagID()
		local info = bag and slot and C_Container.GetContainerItemInfo(bag, slot)
		local r, g, b
		if button.IconQuestTexture and button.IconQuestTexture:IsShown() then
			r, g, b = unpack(NS.color.accent)
		elseif info and info.quality and info.quality >= MIN_QUALITY then
			r, g, b = NS:QualityColor(info.quality)
		end
		SyncItem(button, info and true or false, r, g, b)
	end
end

-- The bag icon becomes a small square in the header, still opening the bag
-- menu.
local function SkinPortrait(frame, header)
	local portrait = NS:SkinPanelPortrait(frame, header)
	if not portrait then return end

	local button = frame.PortraitButton
	if button then
		button:ClearAllPoints()
		button:SetAllPoints(portrait)
		if button.Highlight then
			NS:SetFlat(button.Highlight, NS.color.glyphHover, portrait)
		end
	end
	-- Bag assignment badge.
	if frame.FilterIcon then
		frame.FilterIcon:ClearAllPoints()
		frame.FilterIcon:SetPoint("CENTER", portrait, "BOTTOMRIGHT", 0, 0)
		frame.FilterIcon:SetSize(12, 12)
	end
end

local function SkinMoney(frame)
	local border = frame.MoneyFrame and frame.MoneyFrame.Border
	if not border then return end
	NS:HideTextures(border.Left, border.Middle, border.Right)
	NS:CreateTile(border, 0, 0, NS.color.tile, true)
end

local skinnedFrames = {}

local function SkinBagFrame(frame)
	if not frame or skinnedFrames[frame] then return end
	skinnedFrames[frame] = true
	local header = NS:SkinPanelFrame(frame)
	SkinPortrait(frame, header)
	SkinMoney(frame)
	NS:Hook(frame, "UpdateItems", SyncBlizzardItems)
	SyncBlizzardItems(frame)
end

local function BlizzardFrames()
	local list = {}
	local holder = ContainerFrameContainer and ContainerFrameContainer.ContainerFrames
	for _, frame in ipairs(holder or {}) do
		table.insert(list, frame)
	end
	table.insert(list, ContainerFrameCombinedBags)
	return list
end

function M:InitBlizzard()
	for _, frame in ipairs(BlizzardFrames()) do
		SkinBagFrame(frame)
	end
	NS:SkinSearchBox(BagItemSearchBox)
	-- Blizzard shrinks the windows when many bags are open; keep 1px lines.
	NS:Hook(nil, "UpdateContainerFrameAnchors", function() NS:UpdatePixels() end)
end

---------------------------------------------------------------------------
-- Bagnon
---------------------------------------------------------------------------

local function TitleFonts()
	local c = NS.color.text
	local normal = CreateFont("AbsoluteUIBagnonTitle")
	normal:SetFontObject(NS:GetFont(12))
	normal:SetTextColor(c[1], c[2], c[3])
	normal:SetShadowOffset(1, -1)
	normal:SetShadowColor(0, 0, 0, 0.9)
	local highlight = CreateFont("AbsoluteUIBagnonTitleHighlight")
	highlight:CopyFontObject(normal)
	highlight:SetTextColor(1, 1, 1)
	return normal, highlight
end

local bagnonPanels = {}

-- Bagnon calls this whenever a window's look updates; ours is built once.
-- Its top row sits 8 units in, 20 tall.
local function LoadBagnonSkin(bg)
	if bagnonPanels[bg] then return end
	bagnonPanels[bg] = true
	NS:CreateTile(bg, 0, 0, NS.color.panel)

	local header = CreateFrame("Frame", nil, bg)
	header:SetPoint("TOPLEFT", bg, "TOPLEFT", 6, -6)
	header:SetPoint("TOPRIGHT", bg, "TOPRIGHT", -6, -6)
	header:SetHeight(24)
	NS:CreateTile(header, 0, 0, NS.color.header, true)

	local window = bg:GetParent()
	local close = window and window.CloseButton
	if close then
		close:SetSize(20, 20)
		NS:SkinGlyphButton(close, 13, "x")
	end
end

local function SyncBagnonItem(button)
	local border = button.IconBorder
	local r, g, b
	-- Bagnon only shows this border for items worth marking.
	if border and border:IsShown() then
		r, g, b = border:GetVertexColor()
	end
	SyncItem(button, button.hasItem, r, g, b)
end

function M:InitBagnon()
	local bagnon = _G.Bagnon
	local skins = bagnon and bagnon.Skins
	if not (skins and skins.Register and bagnon.Item) then
		NS:Missing("Bagnon skin API")
		return
	end

	local font, fontH = TitleFonts()
	skins:Register({
		id = SKIN_ID,
		template = "NineSliceCodeTemplate", -- what Bagnon's own default skin uses
		load = LoadBagnonSkin,
		font = font, fontH = fontH,
		margin = 3,
		closeX = -4, closeY = -6, -- close button 6 in from the corner
	})

	-- Windows on Bagnon's default skin use ours instead.
	local acquire = skins.Acquire
	function skins.Acquire(registry, id, parent)
		if id == nil or id == registry.Default then
			id = SKIN_ID
		end
		return acquire(registry, id, parent)
	end

	NS:Hook(bagnon.Item, "Update", SyncBagnonItem)
	NS:Hook(bagnon.Item, "UpdateBorder", SyncBagnonItem)

	if bagnon.Frames and bagnon.Frames.Iterate then
		for _, frame in bagnon.Frames:Iterate() do
			if frame.UpdateVisuals then
				NS.SafeCall(frame.UpdateVisuals, frame)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function M:Init()
	self:InitBlizzard()
	if C_AddOns.IsAddOnLoaded("Bagnon") then
		self:InitBagnon()
	else
		NS:On("ADDON_LOADED", function(_, name)
			if name == "Bagnon" and not M.bagnon then
				M.bagnon = true
				M:InitBagnon()
			end
		end)
	end
end
