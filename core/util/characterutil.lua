---@class RT
local RT = select(2, ...)

local UnitClassBase = UnitClassBase
local CreateAtlasMarkup, GetClassAtlas =
	  CreateAtlasMarkup, GetClassAtlas

---@class CharacterUtil
local CharacterUtil = {}

--- Returns The player's locale-independent class name
---@return ClassFile class
function CharacterUtil:GetCharacterClass()
    local classFilename, _ = UnitClassBase("player")
    return classFilename
end

---@param class ClassFile
---@param iconSize number icon size in UI pixels
---@return string icon
--- Retrieves a class icon with given size for the localized class name provided.
function CharacterUtil:GetCharacterIcon(class, iconSize)
	local textureAtlas = GetClassAtlas(class)
	local icon = CreateAtlasMarkup(textureAtlas, iconSize, iconSize)
	return icon
end

---@param level number a given character level
---@return boolean
--- Returns true / false if the passed level equals the maximum player level available
function CharacterUtil:IsCharacterAtEffectiveMaxLevel(level)
	return level >= GetMaxPlayerLevel();
end

RT.CharacterUtil = CharacterUtil
