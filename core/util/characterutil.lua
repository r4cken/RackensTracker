local _, RT = ...

local UnitClassBase = UnitClassBase
local CreateAtlasMarkup, CreateAtlasMarkupWithAtlasSize, GetClassAtlas =
	  CreateAtlasMarkup, CreateAtlasMarkupWithAtlasSize, GetClassAtlas

local CharacterUtil = {}

---@alias ClassBaseName
---| '"DEATHKNIGHT"'
---| '"DRUID"'
---| '"HUNTER"'
---| '"MAGE"'
---| '"PALADIN"'
---| '"PRIEST"'
---| '"ROGUE"'
---| '"SHAMAN"'
---| '"WARLOCK"'
---| '"WARRIOR"'
---@return ClassBaseName class Gets the players locale-independent name
function CharacterUtil:GetCharacterClass()
    local classFilename, _ = UnitClassBase("player")
    return classFilename
end

---@param class ClassBaseName
---@param iconSize number
---@return string icon A class icon with given size for the class provided.
function CharacterUtil:GetCharacterIcon(class, iconSize)
	local textureAtlas = GetClassAtlas(class)
	local icon = CreateAtlasMarkup(textureAtlas, iconSize, iconSize)
	return icon
end

---@param iconScale number
---@return string icon
function CharacterUtil:GetEquipmentIcon(iconSize)
	local atlasName = "bags-icon-equipment"
	local atlasSize = 16
	local icon = CreateAtlasMarkup(atlasName, iconSize or atlasSize, iconSize or atlasSize)
	return icon
end

---@param level number
function CharacterUtil:IsCharacterAtEffectiveMaxLevel(level)
	return level >= GetMaxPlayerLevel();
end

RT.CharacterUtil = CharacterUtil
