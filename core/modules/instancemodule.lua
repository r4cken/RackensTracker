local addOnName, RT = ...

local MAX_RAID_INFOS = MAX_RAID_INFOS
local strformat = string.format
local GetServerTime = GetServerTime
local GetNumSavedInstances, GetSavedInstanceInfo, GetSavedInstanceEncounterInfo, GetDifficultyInfo =
      GetNumSavedInstances, GetSavedInstanceInfo, GetSavedInstanceEncounterInfo, GetDifficultyInfo

local addon = LibStub("AceAddon-3.0"):GetAddon(addOnName) --[[@as RackensTracker]]

---@class InstanceModule: AceModule, AceConsole-3.0, AceEvent-3.0, AddonModulePrototype
local InstanceModule = addon:NewModule("Instances", "AceEvent-3.0")

local function Log(message, ...)
	if (addon.LOGGING_ENABLED) then
    	InstanceModule:DebugLog(message, ...)
	end
end

--- Retrieves all of the current characters locked raids and dungeons
---@return { [string]: DbSavedInstance } instances A table of raids and dungeons keyed by the string 'instanceName SPACE difficultyName'
local function GetCharacterLockouts()
	---@type table<string, DbSavedInstance>
	local savedInstances = {}
	local nSavedInstances = GetNumSavedInstances()

	if (nSavedInstances > 0) then
		for savedInstanceIndex = 1, MAX_RAID_INFOS do -- blizz ui stores max 20 entries per character so why not follow suit
			if ( savedInstanceIndex <= nSavedInstances) then
				local instanceName, lockoutID, resetsIn, difficultyID, isLocked, _, _, isRaid, maxPlayers, difficultyName, encountersTotal, encountersCompleted, _, instanceID = GetSavedInstanceInfo(savedInstanceIndex)
				local _, _, isHeroic, _, _, _, toggleDifficultyID = GetDifficultyInfo(difficultyID);

				-- Only store active lockouts
				if resetsIn > 0 and isLocked then
					local id = strformat("%s %s", instanceName, difficultyName)
					local encounterInformation = {}
					for encounterIndex = 1, encountersTotal do
						local bossName, fileDataID, isKilled, _ = GetSavedInstanceEncounterInfo(savedInstanceIndex, encounterIndex)
						encounterInformation[encounterIndex] =
						{
							bossName = bossName,
							isKilled = isKilled,
							fileDataID = fileDataID,
						}
					end
					savedInstances[id] =
					{
						savedInstanceIndex = savedInstanceIndex,
						instanceName = instanceName,
						instanceID = instanceID,
						lockoutID = lockoutID,
						resetTime = GetServerTime() + resetsIn,
						isLocked = isLocked,
						isRaid = isRaid,
						isHeroic = isHeroic,
						maxPlayers = maxPlayers,
						difficultyID = difficultyID,
						difficultyName = difficultyName,
						toggleDifficultyID = toggleDifficultyID,
						encountersTotal = encountersTotal,
						encountersCompleted = encountersCompleted,
						encounterInformation = encounterInformation,
					}
				end
			end
		end
	end

	return savedInstances
end

--- Iterates over all known characters for the current realm and checks each of the character's saved instances to see if
--- they have reset. If they have, they are removed from the tracker.
function InstanceModule:ResetTrackedInstancesIfNecessary()
    --Log("Running ResetTrackedInstancesIfNecessary!")
	for characterName, character in pairs(addon.db.global.realms[addon.currentRealm].characters) do
		for id, savedInstance in pairs(character.savedInstances) do
			-- TODO: Look into if this savedInstance.resetTime is completely accurate as we update our information about it very frequently on events
			if (savedInstance.resetTime and savedInstance.resetTime < GetServerTime()) then
				Log("Found tracked instance that expired in a previous reset for: " .. characterName)
				Log("Tracked instance id: " .. savedInstance.instanceName .. " " .. savedInstance.difficultyName)
				local timeNow = GetServerTime()
				Log("Current server time: " .. timeNow)
				Log("Tracked instance set to expire at server time: " .. savedInstance.resetTime)
				Log("Tracked instance expired: " .. RT.TimeUtil.TimeFormatter:Format(timeNow - (savedInstance.resetTime)) .. " ago")
				Log("At the time of getting saved to the instance there was: " .. RT.TimeUtil.TimeFormatter:Format(timeNow - savedInstance.resetTime) .. " left until reset")

				addon.db.global.realms[addon.currentRealm].characters[characterName].savedInstances[id] = nil
			end
		end
	end
end

function InstanceModule:OnInitialize()
    -- Reset any character's weekly raid or daily dungeon lockouts if it meets the criteria to do so
    self:ResetTrackedInstancesIfNecessary()
end

function InstanceModule:OnEnable()
    -- Raid and dungeon related events
	self:RegisterEvent("BOSS_KILL", "OnEventBossKill")
    self:RegisterEvent("INSTANCE_LOCK_START", "OnEventInstanceLockStart")
    self:RegisterEvent("INSTANCE_LOCK_STOP", "OnEventInstanceLockStop")
    self:RegisterEvent("INSTANCE_LOCK_WARNING", "OnEventInstanceLockWarning")
    self:RegisterEvent("UPDATE_INSTANCE_INFO", "OnEventUpdateInstanceInfo")

    InstanceModule:TriggerUpdateInstanceInfo()
end

--- Updates the database with the latest saved instance information current character
function InstanceModule:UpdateCharacterLockouts()
	local savedInstances = GetCharacterLockouts()

	addon.currentCharacter.savedInstances = savedInstances
end

--- Called when data from RequestRaidInfo is available from the server, runs self:UpdateCharacterLockouts()
function InstanceModule:OnEventUpdateInstanceInfo()
    Log("OnEventUpdateInstanceInfo")
	self:UpdateCharacterLockouts()
end

--- Requests saved instance information from the game server.
function InstanceModule:TriggerUpdateInstanceInfo()
	RequestRaidInfo()
end

--- Called when a boss is killed in an instance
function InstanceModule:OnEventBossKill()
    Log("OnEventBossKill")
    InstanceModule:TriggerUpdateInstanceInfo()
end

function InstanceModule:OnEventInstanceLockStart()
    Log("OnEventInstanceLockStart")
    InstanceModule:TriggerUpdateInstanceInfo()
end

--- Called when quitting the game
function InstanceModule:OnEventInstanceLockStop()
    Log("OnEventInstanceLockStop")
    InstanceModule:TriggerUpdateInstanceInfo()
end

--- Called when recieving a warning that the player will be saved if they accept
function InstanceModule:OnEventInstanceLockWarning()
    Log("OnEventInstanceLockWarning")
    InstanceModule:TriggerUpdateInstanceInfo()
end