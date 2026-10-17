-- AbsoluteUI: buffs and debuffs for target and focus.
--
-- Blizzard's aura buttons are secure and can't be restyled, so we draw our
-- own with the same filtering and placement and keep Blizzard's container
-- empty. Secret aura fields go through the client's secret-safe helpers;
-- if reading still fails, Blizzard's container takes over again.

local _, NS = ...

local AS = NS.auraStyle
local PLAYER_UNITS = PLAYER_UNITS or { "player", "pet", "vehicle" }
local IsSecret = NS.IsSecret

local function Known(value)
	if IsSecret(value) then return nil end
	return value
end

-- Debuff type colors by dispel type enum, for secret dispel names.
local dispelCurve
if C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum.LuaCurveType then
	dispelCurve = C_CurveUtil.CreateColorCurve()
	dispelCurve:SetType(Enum.LuaCurveType.Step)
	local colors = {
		[0] = DEBUFF_TYPE_NONE_COLOR,
		[1] = DEBUFF_TYPE_MAGIC_COLOR,
		[2] = DEBUFF_TYPE_CURSE_COLOR,
		[3] = DEBUFF_TYPE_DISEASE_COLOR,
		[4] = DEBUFF_TYPE_POISON_COLOR,
		[9] = DEBUFF_TYPE_BLEED_COLOR,
		[11] = DEBUFF_TYPE_BLEED_COLOR,
	}
	for index = 0, 11 do
		if colors[index] then
			dispelCurve:AddPoint(index, colors[index])
		end
	end
end

local BUFF_FILTER = "HELPFUL"
local DEBUFF_FILTER = "HARMFUL|INCLUDE_NAME_PLATE_ONLY"
if AuraUtil and AuraUtil.CreateFilterString and AuraUtil.AuraFilters then
	BUFF_FILTER = AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Helpful)
	DEBUFF_FILTER = AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Harmful, AuraUtil.AuraFilters.IncludeNameplateOnly)
end

---------------------------------------------------------------------------
-- Which auras show (mirrors TargetFrameAuraContainer.lua)
---------------------------------------------------------------------------

local function IsFromPlayer(source)
	if not source then return false end
	for _, token in ipairs(PLAYER_UNITS) do
		if UnitIsUnit(source, token) or (UnitIsOwnerOrControllerOfUnit and UnitIsOwnerOrControllerOfUnit(token, source)) then
			return true
		end
	end
	return false
end

-- Cast by the player or their pet; the "PLAYER" filter decides when the
-- caster is secret.
local function IsMine(unit, aura)
	local source = Known(aura.sourceUnit)
	if source then
		return IsFromPlayer(source)
	end
	local id = Known(aura.auraInstanceID)
	if id and C_UnitAuras.IsAuraFilteredOutByInstanceID then
		local filteredOut = C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, id, aura.baseFilter .. "|PLAYER")
		if not IsSecret(filteredOut) then
			return not filteredOut
		end
	end
	return false
end

local function ShowBuff(_, aura)
	if Known(aura.isPrivate) then return true end
	if Known(aura.isNameplateOnly) then return false end
	if C_GameRules and Enum.GameRule and Enum.GameRule.TargetFrameBuffsDisabled
		and C_GameRules.IsGameRuleActive(Enum.GameRule.TargetFrameBuffsDisabled) then
		return false
	end
	return true
end

-- Unreadable fields count as "unknown" and never hide an aura.
local function ShowDebuff(unit, aura, friendly)
	if Known(aura.isPrivate) or Known(aura.nameplateShowAll) then return true end
	if C_CVar and C_CVar.GetCVarBool("noBuffDebuffFilterOnTarget") then return true end
	if aura.isMine then return true end
	if UnitIsUnit("player", unit) then return true end
	local otherPlayersPet = UnitIsOtherPlayersPet and UnitIsOtherPlayersPet(unit)
	if not UnitIsPlayer(unit) and not otherPlayersPet and not friendly and Known(aura.isFromPlayerOrPlayerPet) then
		return false
	end
	return true
end

-- `list` is reused: UNIT_AURA fires a lot in groups.
local function Collect(list, unit, filter, baseFilter, limit, test, friendly)
	wipe(list)
	if limit <= 0 then return list end
	for index = 1, 255 do
		local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
		if not aura then break end
		aura.index, aura.filter, aura.baseFilter = index, filter, baseFilter
		aura.isHelpful = baseFilter == "HELPFUL"
		aura.isMine = IsMine(unit, aura)
		if test(unit, aura, friendly) then
			table.insert(list, aura)
			if #list >= limit then break end
		end
	end
	return list
end

---------------------------------------------------------------------------
-- Countdown text
--
-- Localized units ("42 min.") are too wide for a 20px icon, so a numeric
-- rule formatter shows "45", "42m", "3h", "2d" instead. The engine applies
-- it, so secret durations work too. Units take over at 1.5x their size and
-- round up, like Blizzard's.
---------------------------------------------------------------------------

local countdownFormatter

local function CreateCountdownFormatter()
	if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and Enum.NumericRuleFormatRounding) then
		return nil
	end
	local up, down = Enum.NumericRuleFormatRounding.Up, Enum.NumericRuleFormatRounding.Down
	local formatter = C_StringUtil.CreateNumericRuleFormatter()
	formatter:AddBreakpoint({ threshold = 0, step = 1, rounding = up, format = "%d" })
	for _, unit in ipairs({ { 60, "m" }, { 3600, "h" }, { 86400, "d" } }) do
		local size, suffix = unit[1], unit[2]
		formatter:AddBreakpoint({ threshold = math.floor(size * 1.5) + 1, step = 1, rounding = down, min = 1,
			format = "%d" .. suffix, components = { { div = size, rounding = up } } })
	end
	return formatter
end

local function ShortenCountdown(cooldown)
	if not cooldown.SetCountdownFormatter then return end
	if countdownFormatter == nil then
		local ok, formatter = pcall(CreateCountdownFormatter)
		countdownFormatter = ok and formatter or false
		if not ok then NS:Missing("countdown formatter: " .. tostring(formatter)) end
	end
	if countdownFormatter then
		cooldown:SetCountdownFormatter(countdownFormatter)
	end
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

local function OnEnter(button)
	local unit, id = button.unit, button.auraInstanceID
	GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT")
	if id and button.isHelpful and GameTooltip.SetUnitBuffByAuraInstanceID then
		GameTooltip:SetUnitBuffByAuraInstanceID(unit, id, button.filter)
	elseif id and not button.isHelpful and GameTooltip.SetUnitDebuffByAuraInstanceID then
		GameTooltip:SetUnitDebuffByAuraInstanceID(unit, id, button.filter)
	else
		GameTooltip:SetUnitAura(unit, button.index, button.filter)
	end
	GameTooltip:Show()
end

local function OnLeave()
	GameTooltip:Hide()
end

local function LayoutButton(button)
	local px = NS:Px(button)
	button.icon:ClearAllPoints()
	button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", px, -px)
	button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -px, px)
end

local function CreateButton(holder, unit)
	local button = CreateFrame("Button", nil, holder)
	button.unit = unit
	button.shadow = NS:CreateShadow(button, button)
	button.border = NS:CreateTexture(button, "BACKGROUND", -7, NS.color.border)
	button.border:SetAllPoints()
	button.icon = button:CreateTexture(nil, "ARTWORK")
	NS:CropIcon(button.icon)

	button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	button.cooldown:SetAllPoints(button.icon)
	button.cooldown:SetReverse(true)
	button.cooldown:SetDrawEdge(false)
	button.cooldown:SetSwipeColor(0, 0, 0, 0.6)
	button.cooldown:SetHideCountdownNumbers(false)
	ShortenCountdown(button.cooldown)

	button.text = CreateFrame("Frame", nil, button)
	button.text:SetAllPoints()
	button.text:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)
	button.count = NS:CreateText(button.text, 10, "RIGHT", true)
	button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, 1)

	button:SetScript("OnEnter", OnEnter)
	button:SetScript("OnLeave", OnLeave)
	LayoutButton(button)
	return button
end

-- Shown from 2 stacks, like Blizzard.
local function SetCount(button, aura)
	local applications = aura.applications
	if not IsSecret(applications) then
		button.count:SetText((applications or 0) > 1 and applications or "")
	elseif C_StringUtil and C_StringUtil.TruncateWhenZero then
		button.count:SetText(C_StringUtil.TruncateWhenZero(applications))
	else
		button.count:SetText("")
	end
end

-- Duration objects work for secret durations; permanent auras get no swipe.
local function SetCooldown(button, aura)
	local cooldown = button.cooldown
	local id = Known(aura.auraInstanceID)
	if id and C_UnitAuras.GetAuraDuration and cooldown.SetCooldownFromDurationObject then
		local durationObject = C_UnitAuras.GetAuraDuration(button.unit, id)
		if durationObject then
			cooldown:SetCooldownFromDurationObject(durationObject)
			if cooldown.SetAlphaFromBoolean and durationObject.IsZero then
				cooldown:SetAlphaFromBoolean(durationObject:IsZero(), 0, 1)
			end
		else
			cooldown:Clear()
		end
		return
	end

	local duration, expiration = Known(aura.duration), Known(aura.expirationTime)
	if duration and expiration and duration > 0 then
		cooldown:SetCooldown(expiration - duration, duration)
	else
		cooldown:Clear()
	end
end

-- Debuffs: debuff type color. Buffs: light blue when stealable (not on
-- yourself). Otherwise black.
local function BorderColor(unit, aura)
	if not aura.isHelpful then
		local dispelName = aura.dispelName
		local color
		if not IsSecret(dispelName) then
			color = DebuffTypeColor and (DebuffTypeColor[dispelName or "none"] or DebuffTypeColor.none)
		elseif dispelCurve and C_UnitAuras.GetAuraDispelTypeColor and Known(aura.auraInstanceID) then
			color = C_UnitAuras.GetAuraDispelTypeColor(unit, aura.auraInstanceID, dispelCurve)
		end
		if color then
			return color.r, color.g, color.b, 1
		end
		return 0, 0, 0, 1
	end

	if UnitIsUnit("player", unit) then
		return 0, 0, 0, 1
	end
	local stealable, c = aura.isStealable, NS.color.stealable
	if IsSecret(stealable) then
		local Eval = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
		if Eval then
			return Eval(stealable, c[1], 0), Eval(stealable, c[2], 0), Eval(stealable, c[3], 0), 1
		end
	elseif stealable then
		return c[1], c[2], c[3], 1
	end
	return 0, 0, 0, 1
end

local function Assign(button, aura, size)
	if button.size ~= size then
		button.size = size
		button:SetSize(size, size)
		local countdown = button.cooldown.GetCountdownFontString and button.cooldown:GetCountdownFontString()
		if countdown then
			NS:StyleFont(countdown, size >= AS.largeSize and 10 or 9, "CENTER", true)
		end
	end

	button.icon:SetTexture(aura.icon)
	SetCount(button, aura)
	SetCooldown(button, aura)
	button.border:SetVertexColor(BorderColor(button.unit, aura))

	button.auraInstanceID = aura.auraInstanceID
	button.index = aura.index
	button.filter = aura.filter
	button.isHelpful = aura.isHelpful
	button:Show()
end

---------------------------------------------------------------------------
-- Display
---------------------------------------------------------------------------

local Display = {}

-- `skin` provides frame, unit, changeEvent and GetAuraConstraint().
function NS:CreateAuraDisplay(skin)
	local frame, unit = skin.frame, skin.unit
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
		NS:Missing("aura API")
		return nil
	end
	local d = CreateFromMixins(Display)
	d.skin, d.frame, d.unit = skin, frame, unit
	d.buttons, d.buffs, d.debuffs = {}, {}, {}
	d.count = 0
	d.fallback = false

	local holder = CreateFrame("Frame", nil, frame)
	holder:SetFrameLevel(frame:GetFrameLevel() + 12)
	holder:SetSize(1, 1)
	holder:RegisterUnitEvent("UNIT_AURA", unit)
	holder:RegisterEvent(skin.changeEvent)
	holder:RegisterEvent("PLAYER_REGEN_DISABLED")
	holder:RegisterEvent("PLAYER_REGEN_ENABLED")
	holder:SetScript("OnEvent", function() d:Update() end)
	d.holder = holder

	-- ToT visibility, "Buffs on Top" and the focus frame's size all
	-- reconfigure the container. Classic frames have none; the skin updates
	-- the display after each of their aura updates instead.
	if frame.ConfigureAuraContainer then
		NS:Hook(frame, "ConfigureAuraContainer", function() d:Update() end)
	end

	NS:RegisterPixelClient(function()
		for _, button in ipairs(d.buttons) do LayoutButton(button) end
		d:Update()
	end)

	-- The skin's hook empties Blizzard's container once skin.auras is set.
	skin.auras = d
	d:RefreshBlizzard()
	d:Update()
	return d
end

function Display:AnchorHolder()
	local frame, holder, panel = self.frame, self.holder, NS.layouts.unit.panel
	local gap = AS.gapPx * NS:Px(frame)
	holder:ClearAllPoints()
	-- Mirrored layout: offsets are measured from the top-right.
	if frame.buffsOnTop then
		holder:SetPoint("BOTTOMLEFT", frame, "TOPRIGHT", -panel[3], panel[2] + gap)
	else
		holder:SetPoint("TOPLEFT", frame, "TOPRIGHT", -panel[3], panel[4] - gap)
	end
end

-- Debuffs first on enemies, buffs first on friends, the other group on a
-- new line. Rows level with the ToT card wrap early.
function Display:Rebuild()
	local frame, holder, unit, buttons = self.frame, self.holder, self.unit, self.buttons
	local used = 0

	if UnitExists(unit) then
		local friendly = UnitIsFriend("player", unit)
		-- Blizzard limits some frames (the small focus frame: no buffs).
		local maxBuffs = math.min(AS.maxBuffs, frame.maxBuffs or AS.maxBuffs)
		local maxDebuffs = math.min(AS.maxDebuffs, frame.maxDebuffs or AS.maxDebuffs)
		local buffs = Collect(self.buffs, unit, BUFF_FILTER, "HELPFUL", maxBuffs, ShowBuff, friendly)
		local debuffs = Collect(self.debuffs, unit, DEBUFF_FILTER, "HARMFUL", maxDebuffs, ShowDebuff, friendly)
		local first, second = debuffs, buffs
		if friendly then first, second = buffs, debuffs end

		local panel = NS.layouts.unit.panel
		local panelWidth = panel[3] - panel[1]
		local onTop = frame.buffsOnTop
		local narrowWidth, narrowHeight = self.skin:GetAuraConstraint(panelWidth)

		local x, y, lineHeight = 0, 0, 0
		local function NewLine()
			if x > 0 then
				y = y + lineHeight + AS.spacing
				x, lineHeight = 0, 0
			end
		end
		local function Place(aura)
			local size = aura.isMine and AS.largeSize or AS.size
			local width = (y < narrowHeight) and narrowWidth or panelWidth
			if x > 0 and x + size > width then
				NewLine()
			end
			used = used + 1
			local button = buttons[used] or CreateButton(holder, unit)
			buttons[used] = button
			Assign(button, aura, size)
			button:ClearAllPoints()
			if onTop then
				button:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", x, y)
			else
				button:SetPoint("TOPLEFT", holder, "TOPLEFT", x, -y)
			end
			x = x + size + AS.spacing
			lineHeight = math.max(lineHeight, size)
		end

		for _, aura in ipairs(first) do Place(aura) end
		NewLine()
		for _, aura in ipairs(second) do Place(aura) end
		holder:SetSize(panelWidth, math.max(y + lineHeight, 1))
	end

	for i = used + 1, #buttons do
		buttons[i]:Hide()
	end
	self.count = used
	self:AnchorHolder()
	-- With "Buffs on Top" the castbar sits above this block.
	NS:TriggerCallback("TargetAurasLayout", frame)
end

function Display:IsActive()
	return not self.fallback
end

-- true hands the auras back to Blizzard's container.
function Display:SetFallback(fallback)
	if self.fallback == fallback then return end
	self.fallback = fallback
	self.holder:SetShown(not fallback)
	self:RefreshBlizzard()
end

-- Re-runs Blizzard's aura setup (the skin's hook empties or restores its
-- container) and castbar placement.
function Display:RefreshBlizzard()
	local frame = self.frame
	if frame.UpdateAuras then
		pcall(frame.UpdateAuras, frame)
	end
	if frame.spellbar and frame.spellbar.AdjustPosition then
		pcall(frame.spellbar.AdjustPosition, frame.spellbar)
	end
end

function Display:Update()
	if self.updating then return end
	self.updating = true
	local ok, err = pcall(self.Rebuild, self)
	if not ok then
		NS:Missing(("aura error (%s): %s"):format(self.unit, tostring(err)))
	end
	self:SetFallback(not ok)
	self.updating = false
end
