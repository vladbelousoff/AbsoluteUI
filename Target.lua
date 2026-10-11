-- AbsoluteUI: target and focus frames, each with its target-of-target.
--
-- Both use Blizzard's TargetFrameTemplate, so one skin serves both: the
-- player layout mirrored, our aura display and a compact ToT card.

local _, NS = ...

-- Blizzard's aura container offsets from the frame texture
-- (Blizzard_UnitFrame/Mainline/TargetFrame.lua).
local AURA_START_X = 5
local AURA_START_Y = 9
local AURA_MIRRORED_START_Y = -6

local AS = NS.auraStyle

NS.targetSkins = {} -- [Blizzard frame] = skin

local Skin = {}

-- spec = {
--   unit         -- "target" | "focus"
--   changeEvent  -- event fired when the unit changes
--   textKey      -- settings key for the health text mode
-- }
function NS:SkinTargetFrame(frame, spec)
	local skin = CreateFromMixins(Skin)
	skin.frame = frame
	skin.unit = spec.unit
	skin.changeEvent = spec.changeEvent
	skin.textKey = spec.textKey
	NS.targetSkins[frame] = skin
	skin:Init()
	return skin
end

function Skin:Init()
	local frame = self.frame
	local main = NS:Get(frame, "TargetFrameContent.TargetFrameContentMain")
	local context = NS:Get(frame, "TargetFrameContent.TargetFrameContentContextual")
	self.card = NS:CreateUnitCard(frame, {
		layout = NS.layouts.unit,
		mirror = true,
		blizzPower = NS:Get(main, "ManaBar"),
		name = main and main.Name,
		levelText = main and main.LevelText,
		levelIcon = context and context.HighLevelTexture,
		textKey = self.textKey,
		powerText = true,
		showLoss = true,
	})

	self:HideBlizzardArt(main, context)
	self:AdoptIcons(context)
	self:InitTargetOfTarget()

	self:AnchorBlizzardAuras()
	NS:RegisterPixelClient(function()
		self:AnchorBlizzardAuras()
		self:AnchorTargetOfTarget() -- its gap is in physical pixels
	end)
	NS:Hook(frame, "ConfigureAuraContainer", function() self:ConfigureBlizzardAuras() end)
	self:ConfigureBlizzardAuras()

	NS:CreateAuraDisplay(self) -- sets self.auras

	local function Rebind()
		self.card:SetUnit(frame.unit or self.unit)
		self:UpdateRarity()
	end
	NS:Hook(frame, "Update", Rebind)
	NS:Hook(frame, "CheckClassification", function() self:UpdateRarity() end)
	NS:On(self.changeEvent, Rebind)
	Rebind()
end

function Skin:Refresh()
	self.card:Update()
	if self.totCard then self.totCard:Update() end
end

function Skin:HideBlizzardArt(main, context)
	local frame = self.frame
	-- Killed regions keep their rect, so the aura container, raid icon and
	-- combo points anchored to them stay in place.
	NS:KillAll(NS:Get(frame, "TargetFrameContainer"), {
		"FrameTexture", "Portrait", "PortraitMask", "Flash", "BossPortraitFrameTexture",
	})
	NS:KillAll(main, { "ReputationColor", "LevelBackgroundCircle" })
	NS:KillAll(context, {
		"PvpBackgroundCircle", "PvpBackgroundIcon", "BossIcon", "QuestIcon",
		"PvpIcon", "PrestigePortrait", "PrestigeBadge", "PetBattleIcon",
	})

	if main then
		NS:HideProtectedBars(self.unit .. "-bars", main.HealthBarsContainer, main.ManaBar)
	end
end

-- Icons move one by one: their layer also holds the secure aura container.
function Skin:AdoptIcons(context)
	if not context then return end
	local overlay = self.card.overlay
	for _, key in ipairs({ "LeaderIcon", "GuideIcon", "RaidTargetIcon" }) do
		NS:Adopt(context[key], overlay)
	end
	NS:Kill(context.NumericalThreat)
end

function Skin:UpdateRarity()
	local unit = self.frame.unit or self.unit
	local info = UnitExists(unit) and NS.rarity[UnitClassification(unit)]
	self.card.portrait:SetRarity(info or nil)
end

---------------------------------------------------------------------------
-- Target of target
--
-- The secure ToT button is resized to our card (NS.layouts.tot) and tucked
-- under the panel's right end, so the click area matches what is drawn.
-- Edit Mode doesn't place it, so moving it out of combat is safe. The focus
-- ToT has its own scale, so offsets are converted into its units.
---------------------------------------------------------------------------

local function ToTSize()
	local panel = NS.layouts.tot.panel
	return panel[3] - panel[1], panel[2] - panel[4]
end

function Skin:AnchorTargetOfTarget()
	local frame, tot = self.frame, self.tot
	if not tot then return end
	NS:RunSafe(self.unit .. "-tot", function()
		local panel = NS.layouts.unit.panel
		local scale = tot:GetScale()
		-- Mirrored: panel[1] is the inset from the right edge.
		local x = -panel[1]
		local y = panel[4] - AS.gapPx * NS:Px(frame)
		tot:SetSize(ToTSize())
		tot:ClearAllPoints()
		tot:SetPoint("TOPRIGHT", frame, "TOPRIGHT", x / scale, y / scale)

		-- Aura rows wrap at the ToT's edge.
		self:ConfigureBlizzardAuras()
		if self.auras then self.auras:Update() end
	end)
end

-- Returns width, height: aura rows within `height` of the panel wrap at
-- `width` to clear the ToT card (frame units).
function Skin:GetAuraConstraint(panelWidth)
	local tot = self.tot
	if not tot or not tot:IsShown() or self.frame.buffsOnTop then
		return panelWidth, 0
	end
	local width, height = ToTSize()
	local scale = tot:GetScale()
	return math.max(panelWidth - width * scale - AS.spacing * 2, 0), height * scale + AS.spacing
end

function Skin:InitTargetOfTarget()
	local frame = self.frame
	local tot = frame.totFrame
	if not tot then
		NS:Missing(self.unit .. " totFrame")
		return
	end
	self.tot = tot

	NS:KillAll(tot, { "FrameTexture", "Portrait", "PortraitMask" })
	local mana = tot.ManaBar
	NS:HideProtectedBars(self.unit .. "-tot-bars", tot.HealthBar, mana)
	self:AnchorTargetOfTarget()
	-- The focus frame re-anchors and rescales its ToT on size changes.
	if frame.SetSmallSize then
		NS:Hook(frame, "SetSmallSize", function() self:AnchorTargetOfTarget() end)
	end

	-- <unit>target has no unit events, so the card polls while shown.
	local card = NS:CreateUnitCard(tot, {
		layout = NS.layouts.tot,
		mirror = true,
		blizzPower = mana,
		name = tot.Name,
		poll = 0.2,
	})
	self.totCard = card

	local totUnit = self.unit .. "target"
	local function Rebind()
		card:SetUnit(tot.unit or totUnit)
	end
	card:HookScript("OnShow", Rebind)
	NS:On("UNIT_TARGET", function(_, unit)
		if unit == self.unit then Rebind() end
	end)
	Rebind()
end

---------------------------------------------------------------------------
-- Blizzard's aura container
--
-- Empty while our display runs; it takes over if aura data becomes
-- unreadable, lined up with the panel through the hidden frame texture it
-- anchors to.
---------------------------------------------------------------------------

function Skin:AnchorBlizzardAuras()
	local frame = self.frame
	local anchor = NS:Get(frame, "TargetFrameContainer.FrameTexture")
	if not anchor then return end

	-- Mirrored: rects are measured from the top-right.
	local panel = NS.layouts.unit.panel
	local left, top, right, bottom = -panel[3], panel[2], -panel[1], panel[4]
	local gap = AS.gapPx * NS:Px(frame)

	anchor:ClearAllPoints()
	anchor:SetPoint("TOPLEFT", frame, "TOPRIGHT",
		left - AURA_START_X, top + gap - AURA_MIRRORED_START_Y)
	anchor:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT",
		right, bottom - gap - AURA_START_Y)
end

-- Runs after Blizzard's ConfigureAuraContainer, which resets these values.
function Skin:ConfigureBlizzardAuras()
	local frame = self.frame
	local container = frame.GetAuraContainer and frame:GetAuraContainer()
	if not container then return end
	local function Call(method, ...)
		if container[method] then
			pcall(container[method], container, ...)
		end
	end
	local function Get(method)
		if container[method] then
			local ok, value = pcall(container[method], container)
			if ok then return value end
		end
	end

	if self.auras and self.auras:IsActive() then
		Call("SetMaxBuffs", 0)
		Call("SetMaxDebuffs", 0)
		return
	end

	if Get("GetSmallAuraSize") ~= AS.size then Call("SetSmallAuraSize", AS.size) end
	if Get("GetLargeAuraSize") ~= AS.largeSize then Call("SetLargeAuraSize", AS.largeSize) end
	Call("SetFlowLayoutSpacing", AS.spacing, AS.spacing)

	local panel = NS.layouts.unit.panel
	local panelWidth = panel[3] - panel[1]
	Call("SetFlowLayoutMaximumLineSize", panelWidth)
	local width, height = self:GetAuraConstraint(panelWidth)
	if height > 0 then
		Call("SetConstrainedFlowLayoutLineSize", width)
		Call("SetNumConstrainedFlowLayoutLines", math.ceil(height / (AS.size + AS.spacing)))
	else
		Call("SetNumConstrainedFlowLayoutLines", 0)
	end
end

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------

local function SkinModule(name, frameName, spec)
	local M = NS:NewModule(name)
	function M:Init()
		local frame = _G[frameName]
		if not frame then
			NS:Missing(frameName)
			return
		end
		self.skin = NS:SkinTargetFrame(frame, spec)
	end
	function M:Refresh()
		if self.skin then self.skin:Refresh() end
	end
	return M
end

SkinModule("Target", "TargetFrame", {
	unit = "target", changeEvent = "PLAYER_TARGET_CHANGED", textKey = "targetText",
})
SkinModule("Focus", "FocusFrame", {
	unit = "focus", changeEvent = "PLAYER_FOCUS_CHANGED", textKey = "focusText",
})
