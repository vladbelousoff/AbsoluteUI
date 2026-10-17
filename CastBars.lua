-- AbsoluteUI: player, target and focus castbars.
--
-- The player bar is drawn over its Edit Mode footprint (or in a row above
-- the player frame) and shows latency. Target and focus bars sit in a row
-- above their frame's panel.

local _, NS = ...

local M = NS:NewModule("CastBars")

local IsSecret = NS.IsSecret
local min = math.min

local KILL = {
	"Border", "BorderShield", "TextBorder", "Background", "Flash", "ChargeFlash",
	"DropShadow", "InterruptGlow", "ChargeGlow", "EnergyGlow", "Flakes01",
	"Flakes02", "Flakes03", "BaseGlow", "WispGlow", "Sparkles01", "Sparkles02",
	"StandardGlow", "CraftGlow", "ChannelShadow", "Shine", "Spark",
}

local skins = {}

-- Rows above a unit frame's panel (target and focus, optionally the player).
local ROW_HEIGHT = 14   -- in the bar's own units, snapped to whole pixels
local ROW_GAP_PX = 3    -- physical pixels between the row and the panel

local function Snap(value, unit)
	return math.floor(value / unit + 0.5) * unit
end

-- A skin draws on `skin.fillBar`: the Blizzard bar itself, or our mirror
-- bar for the player.
local function AnchorSpark(bar)
	local skin = skins[bar]
	local fill = skin and skin.fillBar:GetStatusBarTexture()
	if not fill then return end
	skin.spark:ClearAllPoints()
	skin.spark:SetPoint("TOP", fill, "TOPRIGHT")
	skin.spark:SetPoint("BOTTOM", fill, "BOTTOMRIGHT")
end

local function ApplyFill(bar, isFull)
	local barType = bar.barType
	local skin = skins[bar]
	if skin.fillBar ~= bar then
		-- Blizzard's own fill just got a new atlas; keep it invisible.
		local fill = bar:GetStatusBarTexture()
		if fill then fill:SetAlpha(0) end
	end
	-- A secret cast type keeps Blizzard's colors.
	if not IsSecret(barType) then
		local color = NS.castColor[barType or "standard"] or NS.castColor.standard
		local boost = (isFull and barType ~= "interrupted") and 1.15 or 1
		if skin.fillBar == bar then
			-- Blizzard just set an atlas fill; this also clears its crop.
			NS:ApplyBarTexture(bar)
		end
		skin.fillBar:SetStatusBarColor(min(color[1] * boost, 1), min(color[2] * boost, 1), min(color[3] * boost, 1))
		local k = NS.HEALTH_BG_FACTOR
		skin.box.bg:SetVertexColor(color[1] * k, color[2] * k, color[3] * k, 1)
		skin.box.border:SetColor(unpack(barType == "uninterruptable" and NS.color.borderArmored or NS.color.border))
	end
	AnchorSpark(bar)
end

-- Blizzard re-applies fonts when the look changes.
local function StyleTexts(bar)
	if bar.Text then
		local _, size = bar.Text:GetFont()
		NS:StyleFont(bar.Text, math.max(10, math.min(size or 11, 12)), bar.Text:GetJustifyH())
	end
	if bar.CastTimeText then
		NS:StyleFont(bar.CastTimeText, 11, "LEFT")
	end
end

local function UpdatePixels(bar)
	local skin = skins[bar]
	skin.spark:SetWidth(NS:Px(skin.fillBar) * 2)
end

local function OnUpdate(bar)
	local skin = skins[bar]
	-- Blizzard sets these as plain booleans; an unreadable one counts as on.
	local casting, channeling = bar.casting, bar.channeling
	local active = IsSecret(casting) or IsSecret(channeling) or casting or channeling
	skin.spark:SetShown(active and true or false)
	-- Runs right after Blizzard's OnUpdate; secret values pass through as is.
	local mirror = skin.fillBar
	if mirror ~= bar then
		mirror:SetMinMaxValues(bar:GetMinMaxValues())
		mirror:SetValue(bar:GetValue())
	end
	-- Sized every frame, so resizing and pushback need no extra handling.
	if skin.lag then
		local fraction = active and skin.lagFraction
		if fraction then
			skin.lag:SetWidth(math.max(mirror:GetWidth() * fraction, NS:Px(mirror)))
		end
		skin.lag:SetShown(fraction and true or false)
	end
	if skin.iconBox then
		local shown = bar.Icon:IsShown()
		skin.iconBox:SetShown(shown)
		if skin.iconShadow then
			skin.iconShadow:SetShown(shown)
		end
	end
end

-- `fillBar` (optional) is a bar of ours to draw on instead of Blizzard's.
local function Skin(bar, fillBar)
	if not bar or skins[bar] then return end
	local skin = { fillBar = fillBar or bar }
	skins[bar] = skin
	NS:RegisterBar(skin.fillBar)

	for _, key in ipairs(KILL) do
		NS:Kill(bar[key])
	end
	-- Classic bars also have an unnamed backdrop.
	if bar.classicStyleCastBar then
		local fill = bar:GetStatusBarTexture()
		for _, region in ipairs({ bar:GetRegions() }) do
			if region:IsObjectType("Texture") and region ~= fill and region:GetDrawLayer() == "BACKGROUND" then
				NS:Kill(region)
			end
		end
	end

	skin.box = NS:CreateBox(bar, bar, skin.fillBar, NS.color.tile)
	skin.shadow = NS:CreateShadow(bar, skin.box.base)

	-- A mirror bar has an icon of its own.
	local icon = bar.Icon
	if icon and not fillBar then
		NS:CropIcon(icon)
		skin.iconBox = NS:CreateBox(bar, bar, icon, NS.color.panel)
		skin.iconShadow = NS:CreateShadow(bar, skin.iconBox.base)
		skin.iconBox:SetShown(icon:IsShown())
	end

	skin.spark = NS:CreateTexture(skin.fillBar, "OVERLAY", 7)
	skin.spark:SetVertexColor(1, 1, 1, 0.8)
	skin.spark:Hide()

	NS:Hook(bar, "UpdateBarFillTexture", ApplyFill)
	if bar.SetLook then -- modern only
		NS:Hook(bar, "SetLook", StyleTexts)
	end
	bar:HookScript("OnUpdate", OnUpdate)

	StyleTexts(bar)
	UpdatePixels(bar)
	ApplyFill(bar, false)
end

---------------------------------------------------------------------------
-- Player castbar
--
-- Blizzard's bar is left untouched. Our mirror bar and its spell icon cover
-- its Edit Mode box (the bar plus the name strip below it on modern
-- clients, a strip above it on classic), or with "Attach to player frame"
-- sit in a row above the player panel. Blizzard only shows its own icon in
-- some looks, so ours is fed from it and always shown.
---------------------------------------------------------------------------

local FOOTPRINT_BOTTOM = -12 -- Blizzard's modern editModeSelectionBottomOffset
local TEXT_INSET = 4

local function CreateMirror(bar)
	local mirror = CreateFrame("StatusBar", nil, bar)
	mirror:SetMinMaxValues(0, 1)
	mirror:SetValue(0)
	mirror.overlay = CreateFrame("Frame", nil, mirror)
	mirror.overlay:SetAllPoints(mirror)
	mirror.overlay:SetFrameLevel(mirror:GetFrameLevel() + 2)
	return mirror
end

local function LayoutPlayerTexts(bar)
	local skin = skins[bar]
	local mirror = skin and skin.fillBar
	if not mirror or mirror == bar then return end
	local size = skin.onFrame and 10 or 11
	local time = bar.CastTimeText
	local showTime = time and bar.showCastTimeSetting
	if time then
		NS:Adopt(time, mirror.overlay)
		NS:StyleFont(time, size, "RIGHT", true)
		time:ClearAllPoints()
		time:SetPoint("RIGHT", mirror, "RIGHT", -TEXT_INSET, 0)
	end
	local text = bar.Text
	if text then
		NS:Adopt(text, mirror.overlay)
		NS:StyleFont(text, size, "LEFT", true)
		text:ClearAllPoints()
		text:SetPoint("LEFT", mirror, "LEFT", TEXT_INSET, 0)
		if showTime then
			text:SetPoint("RIGHT", time, "LEFT", -TEXT_INSET, 0)
		else
			text:SetPoint("RIGHT", mirror, "RIGHT", -TEXT_INSET, 0)
		end
	end
end

-- The latency marker sits at the end the cast runs into: right for casts,
-- left for channels.
local LATENCY_EVENTS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
}

-- startMS, endMS, isChannel; nil when there is no readable cast.
local function CastWindow(unit)
	local _, _, _, startMS, endMS = UnitCastingInfo(unit)
	if IsSecret(startMS) or IsSecret(endMS) then return nil end
	if startMS then return startMS, endMS, false end
	_, _, _, startMS, endMS = UnitChannelInfo(unit)
	if IsSecret(startMS) or IsSecret(endMS) or not startMS then return nil end
	return startMS, endMS, true
end

local function UpdateLatency(bar)
	local skin = skins[bar]
	if not skin or not skin.lag then return end
	skin.lagFraction = nil
	if not NS.db.castLatency then return end

	local startMS, endMS, channel = CastWindow(bar.unit or "player")
	if not startMS then return end
	local _, _, home, world = GetNetStats()
	local latency = (world and world > 0) and world or home or 0
	local duration = endMS - startMS
	if duration <= 0 or latency <= 0 then return end

	skin.lagFraction = math.min(latency / duration, 1)
	local side = channel and "LEFT" or "RIGHT"
	local mirror = skin.fillBar
	skin.lag:ClearAllPoints()
	skin.lag:SetPoint("TOP" .. side, mirror, "TOP" .. side)
	skin.lag:SetPoint("BOTTOM" .. side, mirror, "BOTTOM" .. side)
end

-- The icon is a square as tall as the bar, left of it, sharing a border:
-- | border | icon (square) | shared border | bar | border |
local function PlaceIcon(mirror, size, px)
	local icon = mirror.icon
	icon:ClearAllPoints()
	icon:SetSize(size, size)
	icon:SetPoint("TOPRIGHT", mirror, "TOPLEFT", -px, 0)
end

-- The icon takes the left end of the box, so the borders still trace the
-- Edit Mode selection. The look sets the bar's height.
local function PlaceOnFootprint(bar, mirror)
	mirror:SetScale(1)
	local px = NS:Px(bar)
	local top = bar.editModeSelectionTopOffset or 0
	local bottom = bar.editModeSelectionBottomOffset or FOOTPRINT_BOTTOM
	local size = bar:GetHeight() + top - bottom
	mirror:ClearAllPoints()
	mirror:SetPoint("TOPLEFT", bar, "TOPLEFT", size + px, top)
	mirror:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, bottom)
	PlaceIcon(mirror, size, px)
end

-- Laid out like the target's row (M:AnchorUnitBar).
local function PlaceOnFrame(bar, mirror, frame)
	-- Takes the player frame's scale, whatever Edit Mode scales the castbar to.
	local barScale = bar:GetEffectiveScale()
	if barScale <= 0 then return end
	mirror:SetScale(frame:GetEffectiveScale() / barScale)

	local px = NS:Px(frame)
	local panel = NS.layouts.unit.panel
	local panelLeft, panelTop, panelRight = panel[1], panel[2], panel[3]
	local height = Snap(ROW_HEIGHT, px)
	local barLeft = panelLeft + px + height + px
	mirror:ClearAllPoints()
	mirror:SetSize((panelRight - px) - barLeft, height)
	mirror:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", barLeft, panelTop + (ROW_GAP_PX + 1) * px)
	PlaceIcon(mirror, height, px)
end

local function PlacePlayerBar(bar)
	local skin = skins[bar]
	local mirror = skin.fillBar
	local frame = PlayerFrame
	local onFrame = NS.db.castbarOnPlayerFrame and frame ~= nil
	skin.onFrame = onFrame
	if onFrame then
		PlaceOnFrame(bar, mirror, frame)
	else
		PlaceOnFootprint(bar, mirror)
	end
	LayoutPlayerTexts(bar)
	UpdatePixels(bar)
end

local function SetupPlayerBar(bar)
	local mirror = CreateMirror(bar)
	Skin(bar, mirror)
	local skin = skins[bar]
	if not skin then return end

	-- Spell icon, fed by Blizzard's hidden one.
	local icon = mirror:CreateTexture(nil, "ARTWORK")
	NS:CropIcon(icon)
	mirror.icon = icon
	local iconBox = NS:CreateBox(bar, bar, icon, NS.color.panel)
	NS:CreateShadow(bar, iconBox.base)
	if bar.Icon then
		bar.Icon:SetAlpha(0)
		icon:SetTexture(bar.Icon:GetTexture())
		NS:Hook(bar.Icon, "SetTexture", function(_, texture) icon:SetTexture(texture) end)
	end

	if bar.SetLook then
		NS:Hook(bar, "SetLook", function() PlacePlayerBar(bar) end)
	end
	NS:Hook(bar, "SetCastTimeTextShown", LayoutPlayerTexts)
	-- Scales may have changed while it was hidden.
	bar:HookScript("OnShow", function() PlacePlayerBar(bar) end)
	NS:OnSettingChanged("castbarOnPlayerFrame", function() PlacePlayerBar(bar) end)
	NS:RegisterPixelClient(function() PlacePlayerBar(bar) end)
	PlacePlayerBar(bar)

	-- Above the mirror's fill, below the spark and texts.
	skin.lag = NS:CreateTexture(skin.fillBar, "ARTWORK", 7, NS.color.castLatency)
	skin.lag:Hide()
	local events = CreateFrame("Frame", nil, bar)
	for _, event in ipairs(LATENCY_EVENTS) do
		events:RegisterUnitEvent(event, "player", "vehicle")
	end
	events:SetScript("OnEvent", function() UpdateLatency(bar) end)
	NS:OnSettingChanged("castLatency", function() UpdateLatency(bar) end)
end

---------------------------------------------------------------------------
-- Target and focus castbars
---------------------------------------------------------------------------

local unitFrames = {} -- [Blizzard frame] = true

-- A row as wide as the panel, ROW_GAP_PX above it (or above the auras with
-- "Buffs on Top"):
-- | border | icon (square) | shared border | bar | border |
-- The bar may have its own scale (the small focus frame), so its height
-- stays in bar units and offsets are converted from frame units.
function M:AnchorUnitBar(frame)
	local bar = frame and frame.spellbar
	if not bar or not skins[bar] then return end

	local scale = bar:GetScale()
	local px, barPx = NS:Px(frame), NS:Px(bar)

	-- Mirrored: offsets are measured from the top-right.
	local panel = NS.layouts.unit.panel
	local panelLeft, panelTop, panelRight = -panel[3], panel[2], -panel[1]
	local rowBottom = panelTop + ROW_GAP_PX * px

	local skin = NS.targetSkins[frame]
	local auras = skin and skin.auras
	if frame.buffsOnTop and auras and auras:IsActive() and auras.count > 0 then
		local holderTop, frameTop = auras.holder:GetTop(), frame:GetTop()
		if holderTop and frameTop then
			rowBottom = Snap(holderTop - frameTop, px) + ROW_GAP_PX * px
		end
	end

	local height = Snap(ROW_HEIGHT, barPx)
	local icon = bar.Icon
	-- Asked rather than read (it hides between casts), so the row doesn't
	-- shift when a cast starts. Unknown keeps room for the icon.
	local showIcon = icon ~= nil
	if icon and bar.ShouldIconBeShown then
		local ok, shown = pcall(bar.ShouldIconBeShown, bar)
		showIcon = not ok or NS.IsSecret(shown) or shown == true
	end
	local iconSpace = showIcon and (height + barPx) * scale or 0
	local barLeft = panelLeft + px + iconSpace
	local barWidth = (panelRight - px) - barLeft

	-- Blizzard may lock the bar's layout while its aura container anchors it.
	pcall(function()
		bar:SetSize(barWidth / scale, height)
		bar:ClearAllPoints()
		bar:SetPoint("BOTTOMLEFT", frame, "TOPRIGHT", barLeft / scale, (rowBottom + px) / scale)
	end)

	if icon then
		icon:ClearAllPoints()
		icon:SetSize(height, height)
		icon:SetPoint("TOPRIGHT", bar, "TOPLEFT", -barPx, 0)
	end

	-- Blizzard hangs the spell name below the bar, over our panel.
	if bar.Text then
		bar.Text:ClearAllPoints()
		bar.Text:SetPoint("LEFT", bar, "LEFT", 4, 0)
		bar.Text:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
		bar.Text:SetHeight(height)
	end
end

local function SkinUnitBar(frameName)
	local frame = _G[frameName]
	local bar = frame and frame.spellbar
	if not bar then
		NS:Missing(frameName .. ".spellbar")
		return
	end
	Skin(bar)
	if bar.Text then
		NS:StyleFont(bar.Text, 10, "LEFT", true)
	end
	unitFrames[frame] = true
	-- Blizzard re-places the bar on show, unit change and aura updates.
	NS:Hook(bar, "AdjustPosition", function() M:AnchorUnitBar(frame) end)
	bar:HookScript("OnShow", function() M:AnchorUnitBar(frame) end)
	M:AnchorUnitBar(frame)
end

function M:Init()
	if PlayerCastingBarFrame then
		SetupPlayerBar(PlayerCastingBarFrame)
	else
		NS:Missing("PlayerCastingBarFrame")
	end

	SkinUnitBar("TargetFrame")
	SkinUnitBar("FocusFrame")
	NS:RegisterCallback("TargetAurasLayout", function(frame) M:AnchorUnitBar(frame) end)

	NS:RegisterPixelClient(function()
		for bar in pairs(skins) do UpdatePixels(bar) end
		for frame in pairs(unitFrames) do M:AnchorUnitBar(frame) end
	end)
end
