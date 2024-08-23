---@class RT
local RT = select(2, ...)

local setmetatable, string =
      setmetatable, string

---@class Instance : DbSavedInstance
---@field id string
local Instance = {}
RT.Instance = Instance

-- TODO: change the signature of the method to accept a table instead
---@return Instance
function Instance:New(savedInstanceIndex, instanceName, instanceID, lockoutID, resetsIn, isRaid, isHeroic, maxPlayers, difficultyID, difficultyName, toggleDifficultyID, encountersTotal, encountersCompleted, encounterInformation)
	local instance = {
		savedInstanceIndex = savedInstanceIndex,
        instanceName = instanceName,
        instanceID = instanceID,
        lockoutID = lockoutID,
        resetsIn = resetsIn,
        isRaid = isRaid,
        isHeroic = isHeroic,
        maxPlayers = maxPlayers,
        difficultyID = difficultyID,
        difficultyName = difficultyName,
		toggleDifficultyID = toggleDifficultyID,
        encountersTotal = encountersTotal,
        encountersCompleted = encountersCompleted,
		encounterInformation = encounterInformation
    }
	setmetatable(instance, self)
	self.__index = self
	instance.id = string.format("%s %s", instanceName, difficultyName)

	return instance
end

---@param other Instance
---@return boolean
function Instance:__eq(other)
	return self.instanceName == other.instanceName
		and self.maxPlayers == other.maxPlayers
		and self.isHeroic == other.isHeroic
end

---@param other Instance
---@return boolean
function Instance:__lt(other)
	return self.instanceName < other.instanceName
		or (self.instanceName == other.instanceName
			and self.maxPlayers > other.maxPlayers)
		or (self.instanceName == other.instanceName
			and self.maxPlayers == other.maxPlayers
			and not self.isHeroic and other.isHeroic)
end