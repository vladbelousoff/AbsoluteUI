-- AbsoluteUI: number and text formatting.
--
-- The client can hand out "secret" values that may be displayed but not
-- computed with; these then fall back to display-only C helpers.

local _, NS = ...

local format, floor = string.format, math.floor
local issecretvalue = issecretvalue

function NS.IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end
local IsSecret = NS.IsSecret

-- Each step starts where the one below would round to "1000.0k".
local UNITS = {
	{ 999950000, 1e9, "b" },
	{ 999950, 1e6, "m" },
	{ 1e4, 1e3, "k" },
}

-- 512 -> "512", 4321 -> "4321", 12345 -> "12.3k", 1234567 -> "1.2m"
function NS.ShortNumber(n)
	local magnitude = n < 0 and -n or n
	for _, unit in ipairs(UNITS) do
		if magnitude >= unit[1] then
			local text = format("%.1f", n / unit[2]):gsub("%.0$", "")
			return text .. unit[3]
		end
	end
	return format("%d", n)
end

-- In [0, 1], or nil when it can't be computed.
function NS.Fraction(value, maxValue)
	if IsSecret(value) or IsSecret(maxValue) or not maxValue or maxValue <= 0 then
		return nil
	end
	local f = value / maxValue
	if f < 0 then return 0 elseif f > 1 then return 1 end
	return f
end

local function StatusText(unit)
	if not UnitIsConnected(unit) then
		return PLAYER_OFFLINE or "Offline"
	elseif UnitIsGhost(unit) then
		return GHOST or "Ghost"
	elseif UnitIsDead(unit) then
		return DEAD or "Dead"
	end
end

local function SecretText(unit, value, mode)
	local valueText, percentText
	if mode ~= "percent" then
		valueText = AbbreviateNumbers and AbbreviateNumbers(value) or value
	end
	if mode ~= "value" then
		if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
			percentText = format("%.0f%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
		elseif mode == "percent" then
			valueText = AbbreviateNumbers and AbbreviateNumbers(value) or value
		end
	end
	if valueText and percentText then
		return format("%s (%s)", valueText, percentText)
	end
	return valueText or percentText or ""
end

function NS.PowerText(value)
	if IsSecret(value) then
		local ok, text = pcall(AbbreviateNumbers or tostring, value)
		return ok and text or ""
	end
	return NS.ShortNumber(value)
end

-- `value`/`maxValue` are what the bar displays. "both" is "9.4k (85%)".
function NS.HealthText(unit, value, maxValue, mode)
	if mode == "none" or not unit or not UnitExists(unit) then
		return ""
	end
	local status = StatusText(unit)
	if status then
		return status
	end
	if IsSecret(value) or IsSecret(maxValue) then
		local ok, text = pcall(SecretText, unit, value, mode)
		return ok and text or ""
	end
	local fraction = NS.Fraction(value, maxValue)
	local percentText = fraction and format("%d%%", floor(fraction * 100 + 0.5)) or ""
	if mode == "percent" then
		return percentText
	elseif mode == "value" then
		return NS.ShortNumber(value)
	end
	if not fraction then
		return NS.ShortNumber(value)
	end
	return format("%s (%s)", NS.ShortNumber(value), percentText)
end
