-- AbsoluteUI: settings schema, saved variables and change notifications.
--
-- Every setting is declared once below; the options panel is built from this
-- list, in order. `page` and `section` entries group the settings that follow.
--
-- Setting fields:
--   key, label, tooltip
--   kind     "toggle" | "choice" | "range"
--   default  value of the matching type
--   choices  (choice) { { value, label }, ... } or a function returning it
--   min, max, step  (range)
--   parent   key of a toggle that must be on for this setting to matter
--   apply    "refresh" (default): every module's Refresh runs
--            "live":    only the NS:OnSettingChanged listeners run
--            "reload":  takes effect after a UI reload

local _, NS = ...

local DB_VERSION = 1

local TEXT_CHOICES = {
	{ "value", "Current value" },
	{ "percent", "Percent" },
	{ "both", "Value and percent" },
	{ "none", "Hidden" },
}

NS.settingsSchema = {
	{ page = "General" },
	{ section = "Media" },
	{ key = "barTexture", kind = "choice", default = "blizzard", apply = "live", label = "Bar texture",
		tooltip = "Texture for every AbsoluteUI bar: unit frames, castbars, the tooltip health bar, "
			.. "quest tracker bars and the damage meter.",
		choices = function() return NS:MediaChoices(NS.barTextures) end },
	{ key = "barFont", kind = "choice", default = "friz", apply = "live", label = "Bar text font",
		tooltip = "Font for the health and power numbers on the unit frames and the damage meter rows.",
		choices = function() return NS:MediaChoices(NS.fontFaces) end },
	{ section = "Colors" },
	{ key = "classColors", kind = "toggle", default = true, label = "Class colored health",
		tooltip = "Color player health bars by class. Creatures always use reaction colors." },
	{ key = "lowHealth", kind = "toggle", default = true, label = "Low health warning",
		tooltip = "Tint the empty part of a health bar red below 35% health." },

	{ page = "Unit Frames" },
	{ section = "Portrait" },
	{ key = "portrait", kind = "choice", default = "3d", label = "Portrait style",
		tooltip = "3D model of the unit, its flat portrait, or the class icon for players.",
		choices = { { "3d", "3D model" }, { "2d", "Flat portrait" }, { "class", "Class icon" } } },
	{ section = "Text" },
	{ key = "playerText", kind = "choice", default = "value", label = "Player health",
		tooltip = "What the player health bar shows.", choices = TEXT_CHOICES },
	{ key = "targetText", kind = "choice", default = "both", label = "Target health",
		tooltip = "What the target health bar shows.", choices = TEXT_CHOICES },
	{ key = "focusText", kind = "choice", default = "both", label = "Focus health",
		tooltip = "What the focus health bar shows.", choices = TEXT_CHOICES },
	{ key = "powerText", kind = "toggle", default = true, label = "Power values",
		tooltip = "Show mana, rage or energy values on the power bars." },

	{ page = "Castbars" },
	{ section = "Player Castbar" },
	{ key = "castbarOnPlayerFrame", kind = "toggle", default = false, apply = "live",
		label = "Attach to player frame",
		tooltip = "Show your castbar in a row above the player frame, like the target's, instead of where "
			.. "Edit Mode places it." },
	{ key = "castLatency", kind = "toggle", default = true, apply = "live", label = "Show latency",
		tooltip = "Shade the end of your castbar by your latency. Once the cast reaches the shaded part, "
			.. "you can already queue your next spell." },

	{ page = "Action Bars" },
	{ section = "Style" },
	{ key = "actionBars", kind = "toggle", default = true, apply = "reload",
		label = "Restyle action bars",
		tooltip = "Give action buttons, bag slots and the micro menu the AbsoluteUI look." },
	{ section = "Visibility" },
	{ key = "hideMicroMenu", kind = "toggle", default = false, label = "Hide micro menu",
		tooltip = "Hide the menu buttons (character, spellbook, talents...). Their keybinds keep working. "
			.. "Shown while Edit Mode is open." },
	{ key = "hideBags", kind = "toggle", default = false, label = "Hide bag bar",
		tooltip = "Hide the bag buttons. The bags keybind keeps working. Shown while Edit Mode is open." },

	{ page = "Skins" },
	{ section = "Blizzard Windows" },
	{ key = "tooltips", kind = "toggle", default = true, apply = "reload", label = "Tooltips",
		tooltip = "Tooltips with borders colored by item quality or unit class and reaction." },
	{ key = "questTracker", kind = "toggle", default = true, apply = "reload", label = "Quest tracker",
		tooltip = "The objective tracker. Its background follows Edit Mode's opacity setting." },
	{ key = "lootFrame", kind = "toggle", default = true, apply = "reload", label = "Loot window",
		tooltip = "The loot window, with item names and borders in quality colors." },
	{ key = "bags", kind = "toggle", default = true, apply = "reload", label = "Bags",
		tooltip = "Blizzard's bag windows, or Bagnon's when you use it (unless you picked another skin "
			.. "in Bagnon's options)." },

	{ page = "Damage Meter" },
	{ key = "damageMeter", kind = "toggle", default = true, apply = "reload", label = "Restyle damage meter",
		tooltip = "Give Blizzard's damage meter the AbsoluteUI look. Its own settings (text size, transparency, "
			.. "class colors) keep working." },
	{ key = "meterBarHeight", kind = "range", default = 25, min = 15, max = 40, step = 1, apply = "live",
		parent = "damageMeter", label = "Bar height",
		tooltip = "Height of the damage meter rows. Replaces Edit Mode's Bar Height while the meter is restyled." },
	{ key = "meterBarSpacing", kind = "range", default = 4, min = 0, max = 12, step = 1, apply = "live",
		parent = "damageMeter", label = "Bar spacing",
		tooltip = "Gap between the damage meter rows. 0 makes the bars touch." },
}

---------------------------------------------------------------------------
-- Schema lookup and validation
---------------------------------------------------------------------------

local byKey = {}
NS.defaults = {}

for _, entry in ipairs(NS.settingsSchema) do
	if entry.key then
		assert(not byKey[entry.key], "AbsoluteUI: duplicate setting " .. entry.key)
		byKey[entry.key] = entry
		NS.defaults[entry.key] = entry.default
	end
end

function NS:GetSettingInfo(key)
	return byKey[key]
end

function NS:GetSettingChoices(entry)
	local choices = entry.choices
	if type(choices) == "function" then
		choices = choices()
	end
	return choices or {}
end

-- Ranges are clamped and snapped to their step; any other invalid value
-- becomes the default.
local function Normalize(entry, value)
	if entry.kind == "range" then
		if type(value) ~= "number" or value ~= value then
			return entry.default
		end
		local step = entry.step or 1
		value = entry.min + math.floor((value - entry.min) / step + 0.5) * step
		return math.min(math.max(value, entry.min), entry.max)
	elseif entry.kind == "toggle" then
		if type(value) == "boolean" then return value end
	elseif entry.kind == "choice" then
		for _, choice in ipairs(NS:GetSettingChoices(entry)) do
			if choice[1] == value then return value end
		end
	end
	return entry.default
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

-- MIGRATIONS[n] upgrades a version n-1 table to version n, in place. Values
-- are validated afterwards, so a migration only carries over renamed keys
-- and changed formats.
local MIGRATIONS = {
	[1] = function() end,
}

local function Migrate(db)
	local version = type(db.version) == "number" and db.version or 0
	for target = version + 1, DB_VERSION do
		if MIGRATIONS[target] then
			MIGRATIONS[target](db)
		end
		db.version = target
	end
end

local function Sanitize(db)
	for key in pairs(db) do
		if key ~= "version" and not byKey[key] then
			db[key] = nil
		end
	end
	for key, entry in pairs(byKey) do
		db[key] = Normalize(entry, db[key])
	end
end

-- The last value each setting was applied with, so no-op changes are
-- skipped (the panel reports every setting on Defaults).
local applied = {}
-- The values the UI was loaded with, to tell whether a reload is due.
local loaded = {}

NS:On("ADDON_LOADED", function(_, name)
	if name ~= NS.name then return end
	local db = type(AbsoluteUIDB) == "table" and AbsoluteUIDB or {}
	AbsoluteUIDB = db
	Migrate(db)
	Sanitize(db)
	for key in pairs(byKey) do
		applied[key] = db[key]
		loaded[key] = db[key]
	end
	NS.db = db
end)

---------------------------------------------------------------------------
-- Changes
---------------------------------------------------------------------------

-- Setting objects of the options panel, so changes made in code show up
-- there too.
NS.settingObjects = {}

-- While set, refreshes and reload prompts are collected and run once.
local batch

-- Whether a "reload" setting differs from the value the UI was loaded with.
function NS:IsReloadPending()
	if not NS.db then return false end
	for key, entry in pairs(byKey) do
		if entry.apply == "reload" and NS.db[key] ~= loaded[key] then
			return true
		end
	end
	return false
end

-- Options replaces this with a dialog.
function NS:PromptReload()
	NS:Print("Some changes take effect after /reload.")
end

-- Applies NS.db[key] after it was written: listeners first, then `apply`.
function NS:ApplySetting(key)
	local entry = byKey[key]
	if not entry or not NS.db then return end
	local value = Normalize(entry, NS.db[key])
	NS.db[key] = value
	if applied[key] == value then return end
	applied[key] = value

	NS:TriggerCallback("SettingChanged:" .. key, value, key)
	if entry.apply == "reload" then
		if batch then
			batch.reload = true
		else
			NS:PromptReload()
		end
	elseif entry.apply ~= "live" then
		if batch then
			batch.refresh = true
		else
			NS:Refresh()
		end
	end
end

function NS:SetSetting(key, value)
	local entry = byKey[key]
	assert(entry, "AbsoluteUI: unknown setting " .. tostring(key))
	value = Normalize(entry, value)
	local object = NS.settingObjects[key]
	if object then
		object:SetValue(value) -- writes NS.db and calls ApplySetting
	else
		NS.db[key] = value
	end
	NS:ApplySetting(key)
end

function NS:ResetSettings()
	batch = {}
	for key, entry in pairs(byKey) do
		NS.SafeCall(NS.SetSetting, NS, key, entry.default)
	end
	local done = batch
	batch = nil
	if done.refresh then
		NS:Refresh()
	end
	NS:Print("Settings restored to defaults.")
	if done.reload then
		NS:PromptReload()
	end
end

NS:RegisterSlashCommand("reset", "restore default settings", function()
	NS:ResetSettings()
end)
