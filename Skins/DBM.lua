-- AbsoluteUI: a bar skin for DBM, picked in DBM's timer options.
--
-- DBM keeps one timer profile per skin and fills it from the skin's
-- defaults the first time the skin is picked; after that it's the user's,
-- like any other DBM profile. DBM draws the borders and backgrounds itself;
-- the skin only adds the icon crop.

local _, NS = ...

local M = NS:NewModule("DBM", { setting = "skinDBM", addon = "DBM-StatusBarTimers", early = true })

local SKIN_ID = "AbsoluteUI"

local function Defaults()
	local tile, border = NS.color.tile, NS.color.border
	local defaults = {
		Texture = NS:GetBarTexture(),
		Font = NS:GetBarFontFile(),
		FontFlag = "OUTLINE",
		FontShadow = false,
		FontSize = 11,
		Height = 20,
		HugeHeight = 22,
		BarStyle = "NoAnim",
		IconLeft = true,
		IconRight = false,
		TextColorR = NS.color.text[1], TextColorG = NS.color.text[2], TextColorB = NS.color.text[3],
	}
	for _, prefix in ipairs({ "", "Huge" }) do
		defaults[prefix .. "BackgroundColorR"] = tile[1]
		defaults[prefix .. "BackgroundColorG"] = tile[2]
		defaults[prefix .. "BackgroundColorB"] = tile[3]
		defaults[prefix .. "BackgroundAlpha"] = 0.9
		defaults[prefix .. "BorderEnabled"] = true
		defaults[prefix .. "BorderSize"] = 1
		defaults[prefix .. "BorderColorR"] = border[1]
		defaults[prefix .. "BorderColorG"] = border[2]
		defaults[prefix .. "BorderColorB"] = border[3]
		defaults[prefix .. "BorderAlpha"] = 1
	end
	return defaults
end

-- Bars set their icons while DBM creates them.
local function CropIcons(dbt)
	if not (dbt.Options and dbt.Options.Skin == SKIN_ID and dbt.GetBarIterator) then return end
	local iterate, state, start = dbt:GetBarIterator()
	if not iterate then return end
	for bar in iterate, state, start do
		local name = bar.frame and bar.frame:GetName()
		if name then
			NS:CropIcon(_G[name .. "BarIcon1"])
			NS:CropIcon(_G[name .. "BarIcon2"])
		end
	end
end

function M:Init()
	local dbt = _G.DBT
	if not (dbt and dbt.RegisterSkin) then
		NS:Missing("DBT skin API")
		return
	end
	local skin = dbt:RegisterSkin(SKIN_ID)
	for option, value in pairs(Defaults()) do
		skin.Defaults[option] = value
	end
	NS:Hook(dbt, "CreateBar", CropIcons)
end
