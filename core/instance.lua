local _, RT = ...

local setmetatable, string =
      setmetatable, string

local Instance = {}
RT.Instance = Instance

-- TODO: change the signature of the method to accept a table instead
function Instance:New(instanceName, instanceID, lockoutID, resetsIn, isRaid, isHeroic, maxPlayers, difficultyID, difficultyName, encountersTotal, encountersCompleted)
	local instance = {
        instanceName = instanceName,
        instanceID = instanceID,
        lockoutID = lockoutID,
        resetsIn = resetsIn,
        isRaid = isRaid,
        isHeroic = isHeroic,
        maxPlayers = maxPlayers,
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        encountersTotal = encountersTotal,
        encountersCompleted = encountersCompleted
    }
	setmetatable(instance, self)
	self.__index = self
	instance.id = string.format("%s %s", instanceName, difficultyName)

	return instance
end

function Instance:__eq(other)
	return self.instanceName == other.instanceName
		and self.maxPlayers == other.maxPlayers
		and self.isHeroic == other.isHeroic
end

function Instance:__lt(other)
	return self.instanceName < other.instanceName
		or (self.instanceName == other.instanceName
			and self.maxPlayers > other.maxPlayers)
		or (self.instanceName == other.instanceName
			and self.maxPlayers == other.maxPlayers
			and not self.isHeroic and other.isHeroic)
end