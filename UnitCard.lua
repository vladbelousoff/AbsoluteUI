-- AbsoluteUI: the "card", our visual layer over one Blizzard unit frame.
--
-- A card is an insecure, mouse-disabled frame laid out inside the Blizzard
-- frame (NS.layouts), so it follows Edit Mode. The secure frame underneath
-- keeps handling clicks, menus and tooltips.

local _, NS = ...

local IsSecret = NS.IsSecret

local LOW_HEALTH_THRESHOLD = 0.35
local LOSS_HOLD = 0.35      -- seconds before the damage chunk starts draining
local LOSS_SPEED = 7        -- drain speed (higher is faster)

local LEVEL_W = 28 -- room for "60", "??" or the skull

local Card = {}

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

-- config = {
--   layout, mirror  -- NS.layouts entry; mirror puts the portrait right
--   blizzPower      -- Blizzard power bar (its visibility is followed)
--   name, levelText, levelIcon  -- Blizzard regions to adopt (optional)
--   textKey         -- db key for the health text mode (nil for none)
--   powerText       -- show the power value
--   showLoss        -- animate recent damage
--   poll            -- seconds between refreshes, for units without events
-- }
function NS:CreateUnitCard(owner, config)
	local card = CreateFrame("Frame", nil, owner)
	Mixin(card, Card)
	card.owner = owner
	card.config = config
	card:SetAllPoints(owner)
	-- Just above the owner, so Blizzard's target auras (which start a few
	-- pixels inside the panel's bottom edge) still draw on top of it.
	card:SetFrameLevel(owner:GetFrameLevel() + 1)

	local c, L, mirror = NS.color, config.layout, config.mirror
	local function Rect(region, key)
		NS:PlaceRect(region, owner, L[key], mirror)
		return region
	end

	card.panel = Rect(NS:CreateTexture(card, "BACKGROUND", -7, c.panel), "panel")
	card.panelBorder = NS:CreateBorder(card, card.panel)
	card.shadow = NS:CreateShadow(card, card.panel)

	card.header = Rect(card:CreateTexture(nil, "BACKGROUND", nil, -5), "header")
	card.headerBox = NS:CreateBox(card, card, card.header, c.header)

	if config.showLoss then
		card.loss = Rect(NS:CreateStatusBar(card), "health")
		card.loss.card = card
		card.loss:SetFrameLevel(card:GetFrameLevel() + 1)
		NS:SetColor(card.loss:GetStatusBarTexture(), c.loss)
	end
	card.health = Rect(NS:CreateStatusBar(card), "health")
	card.health:SetFrameLevel(card:GetFrameLevel() + 2)
	card.healthBox = NS:CreateBox(card, card, card.health, c.tile)

	-- Shields: a striped bar starting where health ends, clipped to the
	-- health bar. A bright edge marks shields beyond max health.
	local healthRect = L.health
	card.absorbClip = CreateFrame("Frame", nil, card)
	card.absorbClip:SetAllPoints(card.health)
	card.absorbClip:SetClipsChildren(true)
	card.absorbClip:SetFrameLevel(card:GetFrameLevel() + 3)
	local fill = card.health:GetStatusBarTexture()
	card.absorb = NS:CreateStatusBar(card.absorbClip)
	card.absorb:SetPoint("TOPLEFT", fill, "TOPRIGHT")
	card.absorb:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
	card.absorb:SetWidth(healthRect[3] - healthRect[1])
	NS:SetColor(card.absorb:GetStatusBarTexture(), c.absorb)
	card.absorbStripes = card.absorb:CreateTexture(nil, "ARTWORK", nil, 1)
	card.absorbStripes:SetTexture("Interface\\RaidFrame\\Shield-Overlay", "REPEAT", "REPEAT")
	card.absorbStripes:SetHorizTile(true)
	card.absorbStripes:SetVertTile(true)
	card.absorbStripes:SetAllPoints(card.absorb:GetStatusBarTexture())
	card.absorbStripes:SetAlpha(0.4)
	card.overAbsorb = NS:CreateTexture(card.absorbClip, "OVERLAY", 0, c.overAbsorb)
	card.overAbsorb:SetPoint("TOPRIGHT", card.health, "TOPRIGHT")
	card.overAbsorb:SetPoint("BOTTOMRIGHT", card.health, "BOTTOMRIGHT")
	card.overAbsorb:SetWidth(2)
	card.overAbsorb:Hide()

	card.power = Rect(NS:CreateStatusBar(card), "power")
	card.power:SetFrameLevel(card:GetFrameLevel() + 2)
	card.powerBox = NS:CreateBox(card, card, card.power, c.powerBg)

	local portraitRect = Rect(card:CreateTexture(nil, "BACKGROUND"), "portrait")
	card.portrait = NS:CreatePortrait(card, portraitRect)
	card.portrait:SetFrameLevel(card:GetFrameLevel() + 3)
	card.portrait.model:SetFrameLevel(card.portrait:GetFrameLevel() + 1)
	card.portrait.top:SetFrameLevel(card.portrait:GetFrameLevel() + 2)

	-- Texts, hover highlight and adopted Blizzard regions.
	card.overlay = CreateFrame("Frame", nil, card)
	card.overlay:SetAllPoints()
	card.overlay:SetFrameLevel(card:GetFrameLevel() + 8)

	card.hover = NS:CreateTexture(card.overlay, "BACKGROUND", 0, c.highlight)
	card.hover:SetAllPoints(card.panel)
	card.hover:SetBlendMode("ADD")
	card.hover:Hide()

	if config.textKey then
		card.value = card.overlay:CreateFontString(nil, "OVERLAY")
		NS:StyleBarText(card.value, L.valueSize or 11, "CENTER")
		card.value:SetPoint("CENTER", card.health, "CENTER", 0, 0)
	end
	if config.powerText then
		card.powerValue = card.overlay:CreateFontString(nil, "OVERLAY")
		NS:StyleBarText(card.powerValue, L.powerSize or 9, "CENTER")
		card.powerValue:SetPoint("CENTER", card.power, "CENTER", 0, 0)
	end

	if config.levelText or config.levelIcon then
		card.levelSlot = card.overlay:CreateTexture(nil, "ARTWORK")
		card.levelSlot:SetSize(LEVEL_W, L.nameSize + 4)
		card.levelSlot:SetPoint("RIGHT", card.header, "RIGHT", -5, 0)
	end

	card:AdoptTexts()

	card:SetScript("OnEvent", card.OnEvent)
	card:SetScript("OnShow", function() card:Update() end)
	if config.poll then
		card.elapsed = 0
		card:SetScript("OnUpdate", card.OnPoll)
	end

	-- Hooking a secure frame's scripts waits until combat ends.
	NS:RunSafe(card, function()
		owner:HookScript("OnEnter", function() card:SetHighlight(true) end)
		owner:HookScript("OnLeave", function() card:SetHighlight(false) end)
	end)

	return card
end

-- Name left, level right in the header. Blizzard re-anchors these on art
-- changes, so this is safe to call again.
function Card:AdoptTexts()
	local config, L = self.config, self.config.layout
	local slot = self.levelSlot
	local name = config.name
	if name then
		NS:Adopt(name, self.overlay)
		NS:StyleFont(name, L.nameSize or 12, "LEFT")
		name:ClearAllPoints()
		name:SetPoint("LEFT", self.header, "LEFT", 5, 0)
		if slot then
			name:SetPoint("RIGHT", slot, "LEFT", -4, 0)
		else
			name:SetPoint("RIGHT", self.header, "RIGHT", -5, 0)
		end
		name:SetHeight(L.nameSize + 4)
	end
	if not slot then return end

	local level, skull = config.levelText, config.levelIcon
	if level then
		NS:Adopt(level, self.overlay)
		NS:StyleFont(level, L.nameSize or 12, "RIGHT")
		level:ClearAllPoints()
		level:SetAllPoints(slot)
	end
	if skull then
		NS:Adopt(skull, self.overlay)
		skull:ClearAllPoints()
		skull:SetPoint("RIGHT", slot, "RIGHT", 0, 0)
		skull:SetSize(L.nameSize + 2, L.nameSize + 2)
	end
end

function Card:SetHighlight(on)
	self.hovered = on
	self.hover:SetShown(on)
	self:UpdateBorder()
end

---------------------------------------------------------------------------
-- Unit binding
---------------------------------------------------------------------------

local UNIT_EVENTS = {
	"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_FACTION",
	"UNIT_MODEL_CHANGED", "UNIT_PORTRAIT_UPDATE",
	"UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
	"UNIT_ABSORB_AMOUNT_CHANGED",
}

function Card:SetUnit(unit)
	if unit ~= self.unit then
		self.unit = unit
		self:UnregisterAllEvents()
		if unit and not self.config.poll then
			for _, event in ipairs(UNIT_EVENTS) do
				self:RegisterUnitEvent(event, unit)
			end
		end
	end
	self.portrait:SetUnit(unit)
	self:Update()
end

function Card:OnEvent(event)
	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
		self:UpdateHealth()
	elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" then
		self:UpdatePower()
	elseif event == "UNIT_DISPLAYPOWER" then
		self:UpdatePowerColor()
		self:UpdatePower()
	elseif event == "UNIT_MODEL_CHANGED" or event == "UNIT_PORTRAIT_UPDATE" then
		self.portrait:Update(true)
	else
		self:Update()
	end
end

function Card:OnPoll(elapsed)
	self.elapsed = self.elapsed + elapsed
	if self.elapsed >= self.config.poll then
		self.elapsed = 0
		self:Update(true)
	end
end

---------------------------------------------------------------------------
-- Updates
---------------------------------------------------------------------------

function Card:Exists()
	return self.unit ~= nil and UnitExists(self.unit)
end

-- `soft` keeps the damage animation running (used by polling).
function Card:Update(soft)
	if not self:Exists() then
		return
	end
	if not soft then
		self.lastHealth = nil
	end
	self:UpdateHealth()

	-- Blizzard hides the power bar for some units (e.g. minor mobs).
	local blizzPower = self.config.blizzPower
	local hasPower = not blizzPower or blizzPower:IsShown()
	self.power:SetShown(hasPower)
	self.powerBox:SetShown(hasPower)
	if self.powerValue then
		self.powerValue:SetShown(hasPower and NS.db.powerText)
	end
	self:UpdatePowerColor()
	self:UpdatePower()

	self.portrait:Update()
	self:UpdateBorder()
end

function Card:UpdateHealthColor()
	local color = NS:UnitHealthColor(self.unit, NS.db.classColors)
	self.healthColor = color
	NS:SetColor(self.health:GetStatusBarTexture(), color)
end

function Card:UpdateHealth()
	if not self:Exists() then return end
	local unit = self.unit
	local value, maxValue = UnitHealth(unit), UnitHealthMax(unit)
	local secret = IsSecret(value) or IsSecret(maxValue)

	if not UnitIsConnected(unit) then
		-- Like Blizzard: offline units show a full grey bar.
		value, maxValue, secret = 1, 1, false
	elseif not secret and maxValue <= 0 then
		maxValue = 1
	end
	self.health:SetMinMaxValues(0, maxValue)
	self.health:SetValue(value)

	self:UpdateLoss(value, maxValue, secret)
	self:UpdateAbsorb(value, maxValue, secret)

	if self.value then
		local mode = NS.db[self.config.textKey]
		self.value:SetText(NS.HealthText(unit, value, maxValue, mode))
	end

	-- Dead/offline/tapped changes don't always come with their own event.
	self:UpdateHealthColor()
	self:UpdateHealthBackground((not secret) and NS.Fraction(value, maxValue) or nil)
end

-- The empty part of the bar is a dark shade of the bar color, turning red
-- when health runs low.
function Card:UpdateHealthBackground(fraction)
	local color, k = self.healthColor or NS.color.dead, NS.HEALTH_BG_FACTOR
	local r, g, b = color[1] * k, color[2] * k, color[3] * k
	if NS.db.lowHealth and fraction and fraction < LOW_HEALTH_THRESHOLD and not UnitIsDeadOrGhost(self.unit) then
		local t, low = 1 - fraction / LOW_HEALTH_THRESHOLD, NS.color.lowHealth
		r, g, b = r + (low[1] - r) * t, g + (low[2] - g) * t, b + (low[3] - b) * t
	end
	self.healthBox.bg:SetVertexColor(r, g, b, 1)
end

-- Damage chunk: a lighter bar that holds the previous health for a moment,
-- then drains down to the new value.
local function LossOnUpdate(bar, elapsed)
	local card = bar.card
	if card.lossHold > 0 then
		card.lossHold = card.lossHold - elapsed
		return
	end
	local current, target = bar:GetValue(), card.lossTarget or 0
	local nextValue = current - (current - target) * math.min(1, elapsed * LOSS_SPEED)
	if nextValue - target < 0.5 then
		bar:SetValue(target)
		card.lossTarget = nil
		bar:SetScript("OnUpdate", nil)
	else
		bar:SetValue(nextValue)
	end
end

function Card:UpdateLoss(value, maxValue, secret)
	local loss = self.loss
	if not loss then return end
	loss:SetMinMaxValues(0, maxValue)

	local last = self.lastHealth
	self.lastHealth = (not secret) and value or nil

	if secret or not last or value >= last then
		loss:SetValue(value)
		self.lossTarget = nil
		loss:SetScript("OnUpdate", nil)
		return
	end

	if not self.lossTarget then
		loss:SetValue(last)
	end
	self.lossTarget = value
	self.lossHold = LOSS_HOLD
	loss:SetScript("OnUpdate", LossOnUpdate)
end

-- Shields fill from the end of current health. The over-shield edge needs
-- arithmetic, so it only shows when the values are readable.
function Card:UpdateAbsorb(value, maxValue, secret)
	local absorb = UnitIsConnected(self.unit) and UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(self.unit) or 0
	self.absorb:SetMinMaxValues(0, maxValue)
	self.absorb:SetValue(absorb or 0)
	local over = false
	if not secret and absorb and not IsSecret(absorb) then
		over = absorb > 0 and value + absorb > maxValue
	end
	self.overAbsorb:SetShown(over)
end

function Card:UpdatePowerColor()
	if not self:Exists() then return end
	local color = NS:UnitPowerColor(self.unit)
	local dead = UnitIsDeadOrGhost(self.unit)
	NS:SetColor(self.power:GetStatusBarTexture(), color, dead and 0.35 or 1)
end

function Card:UpdatePower()
	if not self:Exists() then return end
	local unit = self.unit
	local powerType = UnitPowerType(unit)
	local maxValue = UnitPowerMax(unit, powerType)
	if not IsSecret(maxValue) and maxValue <= 0 then
		self.power:SetMinMaxValues(0, 1)
		self.power:SetValue(0)
		if self.powerValue then self.powerValue:SetText("") end
		return
	end
	local value = UnitPower(unit, powerType)
	self.power:SetMinMaxValues(0, maxValue)
	self.power:SetValue(value)
	if self.powerValue then
		self.powerValue:SetText(NS.PowerText(value))
	end
end

function Card:UpdateBorder()
	self.panelBorder:SetColor(unpack(self.hovered and NS.color.borderHover or NS.color.border))
end
