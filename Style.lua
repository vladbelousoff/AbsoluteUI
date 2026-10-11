-- AbsoluteUI: palette, layouts and unit colors.

local _, NS = ...

---------------------------------------------------------------------------
-- Palette
---------------------------------------------------------------------------

NS.color = {
	panel      = { 0.055, 0.055, 0.065, 0.94 },
	tile       = { 0.10, 0.10, 0.11, 1 },
	header     = { 0.085, 0.085, 0.095, 1 },
	meterHeader = { 0.12, 0.12, 0.135, 1 },  -- damage meter header strip
	border     = { 0, 0, 0, 1 },
	borderHover = { 0.32, 0.33, 0.36, 1 },
	borderArmored = { 0.75, 0.77, 0.82, 1 },  -- uninterruptible casts
	castLatency = { 0.90, 0.20, 0.20, 0.55 }, -- castbar part covered by ping
	shadow     = { 0, 0, 0, 1 },
	powerBg    = { 0.07, 0.07, 0.08, 1 },
	lowHealth  = { 0.42, 0.05, 0.05, 1 },    -- empty health tint at 0%
	text       = { 0.95, 0.95, 0.96 },
	dim        = { 0.62, 0.65, 0.70 },
	accent     = { 0.96, 0.77, 0.30 },       -- gold: checked, alerts, elite
	highlight  = { 1, 1, 1, 0.05 },
	glyphHover = { 1, 1, 1, 0.12 },          -- flat +/-/x buttons on hover
	loss       = { 1, 0.85, 0.80, 0.45 },    -- recent damage chunk
	absorb     = { 0.80, 0.90, 1.00, 0.55 }, -- shields
	overAbsorb = { 0.90, 0.96, 1.00, 0.95 }, -- shields beyond max health
	hostile    = { 0.80, 0.25, 0.22 },
	neutral    = { 0.89, 0.72, 0.28 },
	friendly   = { 0.30, 0.70, 0.33 },
	tapped     = { 0.52, 0.53, 0.56 },
	dead       = { 0.30, 0.30, 0.33 },
	stealable  = { 0.40, 0.75, 1.00 },       -- purgeable buff border
}

-- How much of the health color shows through in the empty part of the bar.
NS.HEALTH_BG_FACTOR = 0.22

-- Icon crop that removes Blizzard's built-in icon border.
NS.ICON_CROP = { 0.08, 0.92, 0.08, 0.92 }

NS.powerColor = {
	MANA        = { 0.25, 0.48, 0.90 },
	RAGE        = { 0.84, 0.22, 0.22 },
	ENERGY      = { 0.95, 0.82, 0.30 },
	FOCUS       = { 0.92, 0.56, 0.26 },
	RUNIC_POWER = { 0.00, 0.78, 0.96 },
}

NS.castColor = {
	standard         = { 0.95, 0.76, 0.34 },
	channel          = { 0.34, 0.76, 0.68 },
	uninterruptable  = { 0.56, 0.58, 0.63 },
	interrupted      = { 0.86, 0.28, 0.26 },
	applyingcrafting = { 0.50, 0.70, 0.95 },
	applyingtalents  = { 0.95, 0.76, 0.34 },
}

-- Portrait accent for elites, rares and bosses.
NS.rarity = {
	elite     = { color = NS.color.accent, label = "Elite" },
	rare      = { color = { 0.74, 0.80, 0.90 }, label = "Rare" },
	rareelite = { color = { 0.80, 0.88, 1.00 }, label = "Rare Elite" },
	worldboss = { color = { 0.92, 0.27, 0.24 }, label = "Boss" },
}

---------------------------------------------------------------------------
-- Layouts
--
-- Rects are { left, top, right, bottom } from the Blizzard frame's top-left,
-- matching Blizzard's player frame geometry. Target and focus use the same
-- layout mirrored.
---------------------------------------------------------------------------

NS.layouts = {
	unit = { -- PlayerFrame / TargetFrame (232x100)
		panel    = { 21, -16, 212, -82 },
		portrait = { 24, -19, 84, -79 },
		header   = { 85, -19, 209, -38 },
		health   = { 85, -40, 209, -59 },
		power    = { 85, -60, 209, -79 },
		nameSize = 12,
		valueSize = 12,
		powerSize = 12,
	},
	-- Target of target: two aura rows tall, tucked under the parent panel's
	-- right end (Target.lua resizes the Blizzard button to this panel).
	tot = {
		panel    = { 0, 0, 100, -42 },
		portrait = { 3, -3, 39, -39 },
		header   = { 40, -3, 97, -12 },
		health   = { 40, -14, 97, -26 },
		power    = { 40, -27, 97, -39 },
		nameSize = 10,
	},
}

-- Window panels (loot, bags): every gap is `margin`; the header strip is
-- `header` tall.
NS.panelStyle = {
	margin = 6,
	header = 18,
}

-- Target aura grid (UI units; the gap is in physical pixels).
NS.auraStyle = {
	size = 20,        -- others' auras
	largeSize = 24,   -- your own auras
	spacing = 2,
	gapPx = 3,        -- between the panel and the first row
	maxBuffs = 32,
	maxDebuffs = 16,
}

---------------------------------------------------------------------------
-- Unit colors
--
-- These run on every health and power event, so they return shared tables.
-- Callers must not modify them.
---------------------------------------------------------------------------

local classColors = {}

local function ClassColor(classFile)
	local color = classColors[classFile]
	if color == nil then
		local source = C_ClassColor and C_ClassColor.GetClassColor(classFile)
			or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
		color = source and { source.r, source.g, source.b } or false
		classColors[classFile] = color
	end
	return color or nil
end

function NS:UnitHealthColor(unit, useClassColor)
	local c = NS.color
	if not unit or not UnitExists(unit) then
		return c.dead
	end
	if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
		return c.dead
	end
	if UnitIsPlayer(unit) and useClassColor then
		local _, classFile = UnitClass(unit)
		local color = classFile and ClassColor(classFile)
		if color then
			return color
		end
	end
	if UnitIsTapDenied(unit) then
		return c.tapped
	end
	if UnitIsUnit(unit, "player") then
		return c.friendly
	end
	local reaction = UnitReaction(unit, "player")
	if reaction then
		if reaction <= 3 then
			return c.hostile
		elseif reaction == 4 then
			return c.neutral
		end
		return c.friendly
	end
	return UnitCanAttack("player", unit) and c.hostile or c.friendly
end

function NS:QualityColor(quality)
	if quality and C_Item and C_Item.GetItemQualityColor then
		local r, g, b = C_Item.GetItemQualityColor(quality)
		if r then return r, g, b end
	end
	local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	if color then return color.r, color.g, color.b end
	return NS.color.text[1], NS.color.text[2], NS.color.text[3]
end

local blizzardPowerColors = {}

function NS:UnitPowerColor(unit)
	local _, token, altR, altG, altB = UnitPowerType(unit)
	local color = token and NS.powerColor[token]
	if color then
		return color
	end
	if token then
		color = blizzardPowerColors[token]
		if color == nil then
			local blizzard = PowerBarColor and PowerBarColor[token]
			color = (blizzard and blizzard.r) and { blizzard.r, blizzard.g, blizzard.b } or false
			blizzardPowerColors[token] = color
		end
		if color then
			return color
		end
	end
	if altR then
		return { altR, altG, altB }
	end
	return NS.powerColor.MANA
end
