local addOnName, RT = ...

local setmetatable =
      setmetatable

local Character = {}
RT.Character = Character

function Character:New(characterID, characterClass)
	local character = { id = characterID, name = characterID, class = characterClass }
	setmetatable(character, self)
	self.__index = self
	character.colorName = RT.Util:FormatColorClass(character.class, character.name)
	return character
end

function Character:__lt(otherCharacter)
	return self.name < otherCharacter.name
end