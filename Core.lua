-- AbsoluteUI: core namespace, events, callbacks, modules and safe helpers.
--
-- Blizzard's frames stay in charge of everything secure (clicks, menus,
-- Edit Mode position and scale). AbsoluteUI hides their art and draws its
-- own on top, never writes fields onto Blizzard tables and only post-hooks
-- Blizzard functions.

local ADDON, NS = ...

NS.name = ADDON
NS.version = C_AddOns and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"

-- WoW Forever runs Blizzard's modern frames, TBC Anniversary the classic
-- ones. Settings and modules that only one of them has carry a matching
-- `flavor`.
NS.isClassic = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE and WOW_PROJECT_ID ~= WOW_PROJECT_CAMELOT
NS.flavor = NS.isClassic and "classic" or "modern"

---------------------------------------------------------------------------
-- Output and diagnostics
---------------------------------------------------------------------------

function NS:Print(...)
	print("|cff7fb8ffAbsoluteUI|r", ...)
end

-- Blizzard elements this client doesn't have, hooks that couldn't be placed
-- and errors caught at runtime. Listed by /aui debug.
NS.missing = {}

function NS:Missing(key)
	NS.missing[key] = true
end

-- Errors go to the error handler (BugSack and friends) instead of aborting
-- the caller. The handler is looked up per error, since error addons may
-- install theirs after we load.
local function errorHandler(err)
	return geterrorhandler()(err)
end

local function SafeCall(fn, ...)
	return xpcall(fn, errorHandler, ...)
end
NS.SafeCall = SafeCall

---------------------------------------------------------------------------
-- Game events
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		SafeCall(list[i], event, ...)
	end
end)

function NS:On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		eventFrame:RegisterEvent(event)
	end
	table.insert(handlers[event], fn)
end

---------------------------------------------------------------------------
-- Internal callbacks
--   "SettingChanged:<key>" (value, key)  a setting changed
--   "TargetAurasLayout" (frame)          a target/focus aura block was laid out
---------------------------------------------------------------------------

local callbacks = {}

function NS:RegisterCallback(name, fn)
	callbacks[name] = callbacks[name] or {}
	table.insert(callbacks[name], fn)
end

function NS:TriggerCallback(name, ...)
	local list = callbacks[name]
	if not list then return end
	for i = 1, #list do
		SafeCall(list[i], ...)
	end
end

function NS:OnSettingChanged(key, fn)
	NS:RegisterCallback("SettingChanged:" .. key, fn)
end

---------------------------------------------------------------------------
-- Combat-safe execution for protected operations
---------------------------------------------------------------------------

local pending = {}

-- Runs fn now, or after combat ends. Queuing the same key twice keeps only
-- the latest fn.
function NS:RunSafe(key, fn)
	if InCombatLockdown() then
		pending[key] = fn
	else
		pending[key] = nil
		SafeCall(fn)
	end
end

NS:On("PLAYER_REGEN_ENABLED", function()
	for key, fn in pairs(pending) do
		pending[key] = nil
		SafeCall(fn)
	end
end)

---------------------------------------------------------------------------
-- Blizzard frame access
---------------------------------------------------------------------------

-- Killed regions are reparented into a hidden frame (so Blizzard's Show()
-- calls are harmless) that has the old parent's rect and scale, so anything
-- anchored to a killed region stays in place.
local graveyards, isGraveyard = {}, {}

local function GetGraveyard(parent)
	local grave = graveyards[parent]
	if not grave then
		grave = CreateFrame("Frame", nil, parent)
		grave:SetAllPoints(parent)
		grave:Hide()
		graveyards[parent] = grave
		isGraveyard[grave] = true
	end
	return grave
end

-- Nil-safe lookup of a dotted path, e.g. NS:Get(PlayerFrame, "A.B.C").
function NS:Get(root, path)
	local node = root
	for key in path:gmatch("[^%.]+") do
		if type(node) ~= "table" then
			node = nil
			break
		end
		node = node[key]
	end
	if node == nil then
		NS:Missing(path)
	end
	return node
end

function NS:Kill(region)
	if not region or not region.SetParent then return end
	local parent = region:GetParent()
	if parent and not isGraveyard[parent] then
		region:SetParent(GetGraveyard(parent))
	end
end

function NS:KillAll(root, keys)
	if not root then return end
	for _, key in ipairs(keys) do
		NS:Kill(NS:Get(root, key))
	end
end

-- Classic frames name their regions globally instead.
function NS:KillGlobals(names)
	for _, name in ipairs(names) do
		local region = _G[name]
		if region then
			NS:Kill(region)
		else
			NS:Missing(name)
		end
	end
end

-- Moves a Blizzard region onto one of our frames so it draws above our art.
-- `target` must cover the old parent's rect, so anchors relative to the
-- parent resolve to the same place.
function NS:Adopt(region, target, level)
	if not region then return end
	region:SetParent(target)
	if level and region.SetFrameLevel then
		region:SetFrameLevel(target:GetFrameLevel() + level)
	end
end

-- `rect` is { left, top, right, bottom } from the owner's top-left, or from
-- its top-right when mirrored.
function NS:PlaceRect(region, owner, rect, mirror)
	local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
	region:ClearAllPoints()
	if mirror then
		region:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -x1, y1)
		region:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", -x2, y2)
	else
		region:SetPoint("TOPLEFT", owner, "TOPLEFT", x1, y1)
		region:SetPoint("BOTTOMRIGHT", owner, "TOPLEFT", x2, y2)
	end
end

-- Post-hooks a method on a table, or a global function when target is nil.
function NS:Hook(target, name, fn)
	if target == nil then
		if type(_G[name]) == "function" then
			hooksecurefunc(name, fn)
			return true
		end
	elseif type(target[name]) == "function" then
		hooksecurefunc(target, name, fn)
		return true
	end
	NS:Missing("hook:" .. name)
	return false
end

---------------------------------------------------------------------------
-- Modules
--
-- local M = NS:NewModule(name, {
--   setting = "key",          -- toggle that enables the module (read at login)
--   addon = "Blizzard_Name",  -- Init waits until this addon has loaded
--   flavor = "modern",        -- only on this client (NS.flavor); elsewhere the
--                             -- module is returned unregistered and never loads
-- })
--
-- Optional, error-isolated methods:
--   M:Init()     once, at login (or when `addon` loads), if enabled
--   M:Refresh()  after a setting that affects the look changed
---------------------------------------------------------------------------

local modules = {}
NS.modules = {}

local ModuleMixin = {}

function ModuleMixin:IsEnabled()
	return not self.setting or (NS.db and NS.db[self.setting]) == true
end

function ModuleMixin:GetState()
	if self.failed then return "loaded with an error during setup" end
	if self.loaded then return "loaded" end
	if self.waiting then return "waiting for " .. self.addon end
	if not NS.loggedIn then return "pending" end
	if not self:IsEnabled() then return "disabled" end
	return "enabled after login (needs /reload)"
end

function NS:NewModule(name, spec)
	local module = Mixin({ name = name }, ModuleMixin, spec or {})
	if module.flavor and module.flavor ~= NS.flavor then
		return module
	end
	assert(not NS.modules[name], "AbsoluteUI: duplicate module " .. tostring(name))
	table.insert(modules, module)
	NS.modules[name] = module
	return module
end

local function CallMethod(module, method)
	if module[method] then
		return SafeCall(module[method], module)
	end
	return true
end

-- A module whose Init failed part way still counts as loaded, so whatever
-- it built keeps following setting changes.
local function LoadModule(module)
	module.waiting = nil
	if module.loaded then return end
	module.loaded = true
	module.failed = not CallMethod(module, "Init") or nil
end

local function IsAddOnLoaded(addon)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		return C_AddOns.IsAddOnLoaded(addon)
	end
	return true -- can't tell; the module checks for its frames itself
end

local waiting = {} -- [addon name] = { module, ... }

NS:On("ADDON_LOADED", function(_, addon)
	local list = waiting[addon]
	if not list then return end
	waiting[addon] = nil
	for _, module in ipairs(list) do
		LoadModule(module)
		CallMethod(module, "Refresh")
	end
end)

function NS:Refresh()
	for _, module in ipairs(modules) do
		if module.loaded then
			CallMethod(module, "Refresh")
		end
	end
end

NS:On("PLAYER_LOGIN", function()
	NS.loggedIn = true
	for _, module in ipairs(modules) do
		if module:IsEnabled() then
			if module.addon and not IsAddOnLoaded(module.addon) then
				module.waiting = true
				waiting[module.addon] = waiting[module.addon] or {}
				table.insert(waiting[module.addon], module)
			else
				LoadModule(module)
			end
		end
	end
	NS:Refresh()
end)

---------------------------------------------------------------------------
-- Slash commands and addon compartment
---------------------------------------------------------------------------

local commands, commandList = {}, {}

-- /aui <name> <args> runs fn(args).
function NS:RegisterSlashCommand(name, help, fn)
	name = name:lower()
	if not commands[name] then
		table.insert(commandList, name)
	end
	commands[name] = { help = help, fn = fn }
end

-- { { "/aui name", help }, ... } in registration order.
function NS:GetSlashCommands()
	local list = { { "/aui", "open settings" } }
	for _, name in ipairs(commandList) do
		table.insert(list, { "/aui " .. name, commands[name].help })
	end
	return list
end

NS:RegisterSlashCommand("help", "list commands", function()
	NS:Print("commands:")
	for _, command in ipairs(NS:GetSlashCommands()) do
		print(("  %s - %s"):format(command[1], command[2]))
	end
end)

NS:RegisterSlashCommand("debug", "diagnostics", function()
	NS:Print("version " .. tostring(NS.version))
	for _, module in ipairs(modules) do
		print(("  %s: %s"):format(module.name, module:GetState()))
	end
	local keys = {}
	for key in pairs(NS.missing) do
		table.insert(keys, key)
	end
	table.sort(keys)
	if #keys == 0 then
		print("  All Blizzard frame elements were found.")
	else
		print("  Missing Blizzard elements and caught errors (skipped safely):")
		for _, key in ipairs(keys) do
			print("    - " .. key)
		end
	end
end)

SLASH_ABSOLUTEUI1 = "/aui"
SLASH_ABSOLUTEUI2 = "/absoluteui"
SlashCmdList.ABSOLUTEUI = function(msg)
	local name, args = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
	name = (name or ""):lower()
	if name == "" then
		NS:OpenOptions()
	elseif commands[name] then
		commands[name].fn(args)
	else
		commands.help.fn("")
	end
end

function AbsoluteUI_OnAddonCompartmentClick()
	NS:OpenOptions()
end
