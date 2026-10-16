-- AbsoluteUI: bar textures, font faces and font objects.
--
-- NS:RegisterBarTexture and NS:RegisterFontFace add choices to the options;
-- saved settings are validated against them.

local _, NS = ...

local MEDIA = "Interface\\AddOns\\AbsoluteUI\\Media\\"

NS.SOLID = "Interface\\Buttons\\WHITE8x8"
NS.BAR = "Interface\\TargetingFrame\\UI-StatusBar"
NS.SHADOW = MEDIA .. "Shadow" -- 16x16 nine-slice, 6px margins
NS.FONT = "Fonts\\ARIALN.TTF"

---------------------------------------------------------------------------
-- Registries
---------------------------------------------------------------------------

-- { key, label, ... } in the order the options show them.
NS.barTextures = {}
NS.fontFaces = {}

local function Find(list, key)
	for _, entry in ipairs(list) do
		if entry.key == key then return entry end
	end
end

local function Register(list, entry)
	assert(type(entry.key) == "string" and type(entry.label) == "string",
		"AbsoluteUI: media needs a key and a label")
	local existing = Find(list, entry.key)
	if existing then
		Mixin(existing, entry)
	else
		table.insert(list, entry)
	end
end

function NS:MediaChoices(list)
	local choices = {}
	for _, entry in ipairs(list) do
		table.insert(choices, { entry.key, entry.label })
	end
	return choices
end

-- Bar textures are grey shading, tinted per bar.
function NS:RegisterBarTexture(key, label, file)
	Register(NS.barTextures, { key = key, label = label, file = file })
end

NS:RegisterBarTexture("blizzard", "Blizzard Classic", NS.BAR)
NS:RegisterBarTexture("smooth", "Smooth", MEDIA .. "Smooth")
NS:RegisterBarTexture("glass", "Glass", MEDIA .. "Glass")
NS:RegisterBarTexture("clean", "Clean", MEDIA .. "Clean")
NS:RegisterBarTexture("gradient", "Gradient", MEDIA .. "Gradient")
NS:RegisterBarTexture("bevel", "Bevel", MEDIA .. "Bevel")
NS:RegisterBarTexture("tube", "Tube", MEDIA .. "Tube")
NS:RegisterBarTexture("chrome", "Chrome", MEDIA .. "Chrome")
NS:RegisterBarTexture("sunken", "Sunken", MEDIA .. "Sunken")
NS:RegisterBarTexture("brushed", "Brushed", MEDIA .. "Brushed")
NS:RegisterBarTexture("lines", "Lines", MEDIA .. "Lines")
NS:RegisterBarTexture("solid", "Solid", NS.SOLID)
NS:RegisterBarTexture("raid", "Blizzard Raid", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
NS:RegisterBarTexture("unitframe", "Blizzard Unit Frame", "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")

-- Font faces are font families with one font per alphabet: a bare font file
-- would drop Blizzard's per-alphabet fallbacks and break non-Latin names.
local ALPHABETS = { "roman", "russian", "korean", "simplifiedchinese", "traditionalchinese" }
local KOREAN = "Fonts\\2002.TTF"
local FALLBACK_MEMBERS = {
	roman = NS.FONT, russian = NS.FONT, korean = KOREAN,
	simplifiedchinese = "Fonts\\ARHei.ttf", traditionalchinese = "Fonts\\arheiuhk_bd.TTF",
}

-- `members` maps alphabet -> font file; a plain file name covers roman and
-- russian. Missing alphabets fall back to Blizzard's fonts.
function NS:RegisterFontFace(key, label, members)
	if type(members) == "string" then
		members = { roman = members, russian = members }
	end
	local full = {}
	for _, alphabet in ipairs(ALPHABETS) do
		full[alphabet] = members[alphabet] or FALLBACK_MEMBERS[alphabet]
	end
	Register(NS.fontFaces, { key = key, label = label, members = full })
end

local CHINESE_SERIF = { simplifiedchinese = "Fonts\\ARKai_T.ttf", traditionalchinese = "Fonts\\blei00d.TTF" }

local function Serif(roman, russian)
	return {
		roman = roman, russian = russian,
		simplifiedchinese = CHINESE_SERIF.simplifiedchinese,
		traditionalchinese = CHINESE_SERIF.traditionalchinese,
	}
end

NS:RegisterFontFace("arialn", "Arial Narrow", FALLBACK_MEMBERS)
NS:RegisterFontFace("friz", "Friz Quadrata", Serif("Fonts\\FRIZQT__.TTF", "Fonts\\FRIZQT___CYR.TTF"))
NS:RegisterFontFace("skurri", "Skurri", Serif("Fonts\\skurri.ttf", "Fonts\\SKURRI_CYR.TTF"))
NS:RegisterFontFace("morpheus", "Morpheus", Serif("Fonts\\MORPHEUS.ttf", "Fonts\\MORPHEUS_CYR.TTF"))

-- Bundled open fonts (Media/Fonts, with their licenses), Latin and Cyrillic.
local FONTS = MEDIA .. "Fonts\\"
NS:RegisterFontFace("ptsansnarrow", "PT Sans Narrow", FONTS .. "PTSansNarrow-Bold.ttf")
NS:RegisterFontFace("firasans", "Fira Sans Condensed", FONTS .. "FiraSansCondensed-Medium.ttf")
NS:RegisterFontFace("ubuntu", "Ubuntu Condensed", FONTS .. "UbuntuCondensed-Regular.ttf")
NS:RegisterFontFace("play", "Play", FONTS .. "Play-Bold.ttf")
NS:RegisterFontFace("russoone", "Russo One", FONTS .. "RussoOne-Regular.ttf")
NS:RegisterFontFace("philosopher", "Philosopher", FONTS .. "Philosopher-Bold.ttf")

---------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------

local fonts = {}

-- Font object for a size/outline in a face (default: Arial Narrow).
function NS:GetFont(size, outline, faceKey)
	-- Tenths are kept for texts inside scaled frames (damage meter rows).
	size = math.floor(size * 10 + 0.5) / 10
	local face = Find(NS.fontFaces, faceKey or "arialn") or NS.fontFaces[1]
	local flags = outline and "OUTLINE" or ""
	local key = face.key .. ":" .. size .. ":" .. flags
	if fonts[key] then
		return fonts[key]
	end
	local name = "AbsoluteUIFont_" .. face.key .. tostring(size):gsub("%.", "_") .. (outline and "Outline" or "")
	local font
	if CreateFontFamily then
		local members = {}
		for _, alphabet in ipairs(ALPHABETS) do
			table.insert(members, { alphabet = alphabet, file = face.members[alphabet], height = size, flags = flags })
		end
		local ok, result = pcall(CreateFontFamily, name, members)
		font = ok and result or nil
	end
	if not font then
		font = CreateFont(name)
		font:SetFont(face.members.roman, size, flags)
	end
	fonts[key] = font
	return font
end

-- Points a Blizzard font object at our family, keeping color, alignment and
-- shadow.
function NS:ApplyFontFamily(fontObject, size, outline)
	local r, g, b, a = fontObject:GetTextColor()
	local justifyH, justifyV = fontObject:GetJustifyH(), fontObject:GetJustifyV()
	local sx, sy = fontObject:GetShadowOffset()
	local sr, sg, sb, sa = fontObject:GetShadowColor()
	fontObject:SetFontObject(NS:GetFont(size, outline))
	fontObject:SetTextColor(r, g, b, a)
	fontObject:SetJustifyH(justifyH)
	fontObject:SetJustifyV(justifyV)
	fontObject:SetShadowOffset(sx, sy)
	fontObject:SetShadowColor(sr, sg, sb, sa)
end

-- Restyles global font objects at their current size plus `extra` points
-- (Arial Narrow runs small). Safe to call again after Blizzard resizes them.
function NS:ApplyFontFamilies(names, extra)
	for _, name in ipairs(names) do
		local font = _G[name]
		if font and font.GetFont then
			local _, size = font:GetFont()
			NS:ApplyFontFamily(font, math.floor((size or 12) + 0.5) + (extra or 0))
		end
	end
end

function NS:StyleFont(fs, size, justify, outline, faceKey)
	fs:SetFontObject(NS:GetFont(size, outline, faceKey))
	if outline then
		fs:SetShadowOffset(0, 0)
	else
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 0.9)
	end
	fs:SetJustifyH(justify or "LEFT")
	fs:SetJustifyV("MIDDLE")
	fs:SetWordWrap(false)
	fs:SetTextColor(NS.color.text[1], NS.color.text[2], NS.color.text[3])
end

-- NS:StyleFont for texts Blizzard colors by state: the color stays.
function NS:RestyleFont(fs, size, justify, outline)
	local r, g, b, a = fs:GetTextColor()
	NS:StyleFont(fs, size, justify, outline)
	fs:SetTextColor(r, g, b, a)
end

-- Texts that follow the "Bar text font" setting.
local barTexts = setmetatable({}, { __mode = "k" })

local function ApplyBarFont(fs, spec)
	NS:StyleFont(fs, spec.size, spec.justify, true, NS.db and NS.db.barFont)
end

function NS:StyleBarText(fs, size, justify)
	if not fs then return end
	local spec = barTexts[fs] or {}
	spec.size, spec.justify = size, justify
	barTexts[fs] = spec
	ApplyBarFont(fs, spec)
end

function NS:UpdateBarFonts()
	for fs, spec in pairs(barTexts) do
		ApplyBarFont(fs, spec)
	end
end

NS:OnSettingChanged("barFont", function() NS:UpdateBarFonts() end)

---------------------------------------------------------------------------
-- Bar texture
---------------------------------------------------------------------------

function NS:GetBarTexture()
	local texture = Find(NS.barTextures, NS.db and NS.db.barTexture)
	return texture and texture.file or NS.BAR
end

local bars = setmetatable({}, { __mode = "k" })

local cleanFills = setmetatable({}, { __mode = "k" })

-- A fill that was given an atlas (damage meter rows, castbars) keeps the
-- atlas crop after a plain texture is set, showing the wrong slice. Such a
-- bar gets two fills of our own, used in turn: whichever one Blizzard puts
-- an atlas on next is detached and reset while the other takes over.
--
-- Other units' casts can make a fill's properties secret, and secrets can't
-- be passed back in, so the draw layer is read once and colors are only
-- restored when readable.
local function CleanFill(bar, atlasFill)
	local pool = cleanFills[bar]
	if not pool then
		local layer, subLevel = atlasFill:GetDrawLayer()
		if NS.IsSecret(layer) or NS.IsSecret(subLevel) or not layer then
			layer, subLevel = "ARTWORK", 0
		end
		pool = { bar:CreateTexture(nil, layer, nil, subLevel), bar:CreateTexture(nil, layer, nil, subLevel) }
		cleanFills[bar] = pool
	end
	local fresh = (atlasFill == pool[1]) and pool[2] or pool[1]
	fresh:SetTexCoord(0, 1, 0, 1)
	bar:SetStatusBarTexture(fresh)
	fresh:Show()
	-- The replaced fill would keep drawing at its last size.
	atlasFill:Hide()
	atlasFill:SetTexCoord(0, 1, 0, 1)
end

local function AnySecret(...)
	for i = 1, select("#", ...) do
		if NS.IsSecret((select(i, ...))) then return true end
	end
	return false
end

-- Swaps the fill texture but keeps its vertex color. A secret color is left
-- to whoever tints the bar next.
function NS:ApplyBarTexture(bar)
	local fill = bar:GetStatusBarTexture()
	local r, g, b, a
	if fill then
		r, g, b, a = fill:GetVertexColor()
		if AnySecret(r, g, b, a) then
			r = nil
		end
		-- An unreadable atlas is treated as set: a clean fill is always safe.
		local atlas = fill:GetAtlas()
		if NS.IsSecret(atlas) or atlas then
			CleanFill(bar, fill)
		end
	end
	bar:SetStatusBarTexture(NS:GetBarTexture())
	fill = bar:GetStatusBarTexture()
	if fill then
		fill:SetHorizTile(false)
		fill:SetVertTile(false)
		if r then
			fill:SetVertexColor(r, g, b, a)
		end
	end
end

-- The bar follows the bar texture setting from now on. Restyling is
-- cosmetic, so a bar that errors is skipped.
function NS:RegisterBar(bar)
	if not bar then return end
	bars[bar] = true
	pcall(NS.ApplyBarTexture, NS, bar)
end

function NS:UpdateBarTextures()
	for bar in pairs(bars) do
		pcall(NS.ApplyBarTexture, NS, bar)
	end
end

NS:OnSettingChanged("barTexture", function() NS:UpdateBarTextures() end)
