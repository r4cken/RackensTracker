---@class RT
local RT = select(2, ...)

local UnitClassBase = UnitClassBase
local CreateAtlasMarkup, CreateAtlasMarkupWithAtlasSize, GetClassAtlas =
	  CreateAtlasMarkup, CreateAtlasMarkupWithAtlasSize, GetClassAtlas

---@class CharacterUtil
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

--- Returns The player's locale-independent class name
---@return ClassBaseName class
function CharacterUtil:GetCharacterClass()
    local classFilename, _ = UnitClassBase("player")
    return classFilename
end

---@param class ClassBaseName
---@param iconSize number icon size in UI pixels
---@return string icon
--- Retrieves a class icon with given size for the localized class name provided.
function CharacterUtil:GetCharacterIcon(class, iconSize)
	local textureAtlas = GetClassAtlas(class)
	local icon = CreateAtlasMarkup(textureAtlas, iconSize, iconSize)
	return icon
end

---@param iconSize number icon size in UI pixels
---@return string icon
--- Retrieves the texture markup string for the texture 'UI-EquipmentManager-Toggle'
function CharacterUtil:GetEquipmentIcon(iconSize)
	iconSize = iconSize or 22
	local icon = CreateSimpleTextureMarkup([[Interface\PaperDollInfoFrame\UI-EquipmentManager-Toggle]], iconSize, iconSize)
	return icon
end

---@param level number a given character level
---@return boolean
--- Returns true / false if the passed level equals the maximum player level available
function CharacterUtil:IsCharacterAtEffectiveMaxLevel(level)
	return level >= GetMaxPlayerLevel();
end

RT.CharacterUtil = CharacterUtil
