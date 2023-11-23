-- Set to ignore a bunch of AceGUI / AceAddon related annotation problems.
---@diagnostic disable: undefined-field
---@alias questID number
---@alias currencyID number

---@class DbQuest
---@field id questID
---@field name string
---@field questTag string
---@field faction string|nil
---@field isWeekly boolean
---@field acceptedAt number
---@field secondsToReset number
---@field isCompleted boolean
---@field isTurnedIn boolean
---@field hasExpired boolean?
-- !!!This field is only used for debugging purposes and should not actually be used for anything!!!
---@field craftedFromExistingQuest boolean?
---@field craftedFromCompletedTurnedInQuest boolean?

---@class DbCurrency
---@field currencyID currencyID
---@field name string
---@field description string
---@field quantity number
---@field maxQuantity number
---@field quality number
---@field iconFileID string	
---@field discovered boolean

---@class DbSavedInstance
---@field instanceName string
---@field instanceID number
---@field lockoutID number
---@field resetTime number
---@field isLocked boolean
---@field isRaid boolean
---@field isHeroic boolean
---@field maxPlayers number
---@field difficultyID number
---@field difficultyName string
---@field encountersTotal number
---@field encounterCompleted number

---@class DbCharacter
---@field name string|nil
---@field class string|nil
---@field level string|nil
---@field realm string|nil
---@field savedInstances table<string, DbSavedInstance>
---@field currencies table<currencyID, DbCurrency>
---@field quests table<questID, DbQuest>

local addOnName, RT = ...
local addOnVersion = GetAddOnMetadata("RackensTracker", "Version") or 9999;

local table, math, type, string, pairs, ipairs =
	  table, math, type, string, pairs, ipairs

local ContainsIf =
	  ContainsIf

local GetServerTime, C_DateAndTime =
	  GetServerTime, C_DateAndTime

local RequestRaidInfo, GetDifficultyInfo, GetNumSavedInstances, GetSavedInstanceInfo =
	  RequestRaidInfo, GetDifficultyInfo, GetNumSavedInstances, GetSavedInstanceInfo

local C_CurrencyInfo =
	  C_CurrencyInfo

local DAILY_QUEST_TAG_TEMPLATE = DAILY_QUEST_TAG_TEMPLATE

local C_QuestLog, IsQuestComplete, GetQuestsCompleted =
	  C_QuestLog, IsQuestComplete, GetQuestsCompleted

local UnitName, UnitClassBase, UnitLevel, GetClassAtlas, CreateAtlasMarkup =
	  UnitName, UnitClassBase, UnitLevel, GetClassAtlas, CreateAtlasMarkup

local NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE =
	  NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE

local Settings, CreateSettingsListSectionHeaderInitializer =
	  Settings, CreateSettingsListSectionHeaderInitializer

local CreateFromMixins, SecondsFormatterMixin, SecondsFormatter =
	  CreateFromMixins, SecondsFormatterMixin, SecondsFormatter

local timeFormatter = CreateFromMixins(SecondsFormatterMixin)
timeFormatter:Init(nil, SecondsFormatter.Abbreviation.Truncate, false, true)

---@class RackensTracker : AceAddon, AceConsole-3.0, AceEvent-3.0
local RackensTracker = LibStub("AceAddon-3.0"):NewAddon("RackensTracker", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RackensTracker", true)
local AceGUI = LibStub("AceGUI-3.0")

local LOGGING_ENABLED = true

local database_defaults = {
	global = {
		options = {
			showCurrencies = true,
			shownCurrencies = {
				["341"] = true,  -- Emblem of Frost
				["301"] = true,  -- Emblem of Triumph
				["221"] = true,  -- Emblem of Conquest
				["102"] = true,	 -- Emblem of Valor
				["101"] = true,  -- Emblem of Heroism
				["2711"] = true, -- Defiler's Scourgestone
				["2589"] = true, -- Sidreal Essence
				["241"] = false, -- Champion's Seal
				["1901"] = true, -- Honor Points
				["1900"] = true, -- Arena Points
				["161"] = true,  -- Stone Keeper's Shard
				["81"] = true,	 -- Epicurean's Award
				["61"] = true,	 -- Dalaran Jewelcrafter's Token
				["126"] = false, -- Wintergrasp Mark of Honor
			},
			shownCharacters = {},
			shownQuests = {
				["Weekly"] = true,
				["Daily"] = true,
			}
		},
		realms = {
			['*'] = {
				weeklyResetTime = nil,
				secondsToWeeklyReset = nil,
				dailyResetTime = nil,
				secondsToDailyReset = nil,
				---@type table<string, DbCharacter>
				characters = {
					['*'] = {
						name = nil,
						class = nil,
						level = nil,
						realm = nil,
						savedInstances = {},
						currencies = {},
						quests = {},
					}
				}
			}
		}
	},
	char = {
		minimap = {
			hide = false
		}
	},
}

local function SlashCmdLog(message, ...)
	RackensTracker:Printf(message, ...)
end

local function Log(message, ...)
	if (LOGGING_ENABLED) then
    	RackensTracker:Printf(message, ...)
	end
end

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
local function GetCharacterClass()
    local classFilename, _ = UnitClassBase("player")
    return classFilename
end


---@param class ClassBaseName
---@param iconSize number
---@return string AtlasMarkup A class icon with given size for the class provided.
local function GetCharacterIcon(class, iconSize)
	local textureAtlas = GetClassAtlas(class)
	local icon = CreateAtlasMarkup(textureAtlas, iconSize, iconSize)
	return icon
end

--- Retrieves all of the current characters locked raids and dungeons
---@return { [string]: DbSavedInstance } instances A table of raids and dungeons keyed by the string 'instanceName SPACE difficultyName'
local function GetCharacterLockouts()
	local savedInstances = {}
	local nSavedInstances = GetNumSavedInstances()

	if (nSavedInstances > 0) then
		for i = 1, MAX_RAID_INFOS do -- blizz ui stores max 20 entries per character so why not follow suit
			if ( i <= nSavedInstances) then
				local instanceName, lockoutID, resetsIn, difficultyID, isLocked, _, _, isRaid, maxPlayers, difficultyName, encountersTotal, encountersCompleted, _, instanceID = GetSavedInstanceInfo(i)
				local _, _, isHeroic, _, _, _, _ = GetDifficultyInfo(difficultyID);

				-- Only store active lockouts
				if resetsIn > 0 and isLocked then
					local id = string.format("%s %s", instanceName, difficultyName)
					savedInstances[id] =
					{
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
						encountersTotal = encountersTotal,
						encountersCompleted = encountersCompleted
					}
				end
			end
		end
	end

	return savedInstances
end

--- Retrieves all the current players currencies
---@return { [string]: DbCurrency } currencies A table of currencies keyed by currencyID
local function GetCharacterCurrencies()
	local currencies = {}
	-- Iterate over all known currency ID's
	for currencyID = 61, 3000, 1 do
		-- Exclude some currencies which arent useful or those that are deprecated
		if (not RT.ExcludedCurrencyIds[currencyID]) then
		   local currency = C_CurrencyInfo.GetCurrencyInfo(currencyID)
		   if currency and currency.name ~= nil and currency.name:trim() ~= "" then
			currencies[currencyID] =
				{
					currencyID = currencyID,
					name = currency.name,
					description = currency.description or "",
					quantity = currency.quantity,
					maxQuantity = currency.maxQuantity,
					quality = currency.quality,
					iconFileID = currency.iconFileID,
					discovered = currency.discovered
				}
		   end
		end
	 end

	return currencies
end

--- Updates the database with the latest saved instance information current character
function RackensTracker:UpdateCharacterLockouts()
	local savedInstances = GetCharacterLockouts()

	self.currentCharacter.savedInstances = savedInstances
end

--- Updates the database with the latest currency information for the current character
function RackensTracker:UpdateCharacterCurrencies()
	local currencies = GetCharacterCurrencies()

	self.currentCharacter.currencies = currencies
end

--- Updates the database with the new level for the current character
function RackensTracker:UpdateCharacterLevel(newLevel)
	self.currentCharacter.level = newLevel
end


---@param characterName string
---@return boolean characterHasLockouts
---@return table raidInstances
---@return table dungeonInstances
---@return table lockoutInformation
function RackensTracker:RetrieveSavedInstanceInformation(characterName)
	local lockoutInformation = {}
	local raidInstances = RT.Container:New()
	local dungeonInstances = RT.Container:New()

	local character = self.db.global.realms[self.currentRealm].characters[characterName]
	local characterHasLockouts = false

	for _, savedInstance in pairs(character.savedInstances) do
		if savedInstance.resetTime and savedInstance.resetTime > GetServerTime() then
			local isRaid = savedInstance.isRaid
			if isRaid == nil then
				isRaid = true
			end

			local instance = RT.Instance:New(
				savedInstance.instanceName,
				savedInstance.instanceID,
				savedInstance.lockoutID,
				savedInstance.resetTime,
				savedInstance.isRaid,
				savedInstance.isHeroic,
				savedInstance.maxPlayers,
				savedInstance.difficultyID,
				savedInstance.difficultyName,
				savedInstance.encountersTotal,
				savedInstance.encountersCompleted)
				if (isRaid) then
					if (raidInstances:Add(instance)) then
						lockoutInformation[instance.id] = {}
					end

					lockoutInformation[instance.id]["progress"] = RT.Util:FormatEncounterProgress(instance.encountersCompleted, instance.encountersTotal)
				else
					if (dungeonInstances:Add(instance)) then
						lockoutInformation[instance.id] = {}
					end

					lockoutInformation[instance.id]["progress"] = RT.Util:FormatEncounterProgress(instance.encountersCompleted, instance.encountersTotal)
				end


			characterHasLockouts = true
		end
	end


	return characterHasLockouts, raidInstances, dungeonInstances, lockoutInformation

end

--- Attempts to find the current weekly quest for the active reset by looking at all other characters except the current one in the database.
---@return DbQuest|nil
function RackensTracker:TryToFindCurrentWeeklyQuest()
	for characterName, character in pairs(self.db.global.realms[self.currentRealm].characters) do
		if (characterName ~= self.currentCharacter.name) then
			for _, quest in pairs(character.quests) do
				-- todo: Maybe we dont need to check against this flag
				if (quest.isWeekly and not quest.craftedFromHeuristicGuess) then
					if (quest.acceptedAt + quest.secondsToReset > GetServerTime()) then
						return quest
					end
				end
			end
		end
	end
	return nil
end

--- Attempts to find a completed and turned in weekly quest for the current character.
---@return DbQuest|nil
function RackensTracker:TryGetCurrentFinishedWeeklyQuest()
	for _, quest in pairs(self.currentCharacter.quests) do
		if (quest.isWeekly and quest.isCompleted and quest.isTurnedIn) then
			if (quest.acceptedAt + quest.secondsToReset > GetServerTime()) then
				return quest
			end
		end
	end
	return nil
end

--- Iterates over all known characters for the current realm and checks each of the character's quests to see if
--- they have reset. If they have, they are removed from the tracker, also flags quests picked up from a previous reset with an hasExpired flag.
function RackensTracker:ResetTrackedQuestsIfNecessary()
	for characterName, character in pairs(self.db.global.realms[self.currentRealm].characters) do
		for questID, quest in pairs(character.quests) do
			if (quest.acceptedAt + quest.secondsToReset < GetServerTime()) then
				Log("Found tracked quest that expired in a previous reset for: " .. characterName)
				local timeNow = GetServerTime()
				Log("Current server time: " .. timeNow)
				Log("Tracked quest set to expire at server time: " .. quest.acceptedAt + quest.secondsToReset)
				Log("Tracked quest expired: " .. timeFormatter:Format(timeNow - (quest.acceptedAt + quest.secondsToReset)) .. " ago")
				Log("At the time of accepting the quest there was: " .. timeFormatter:Format(quest.secondsToReset) .. " left until reset")
				-- Found a tracked weekly or daily quest that has expired past the weekly reset time
				-- It is now stale and a new one should be picked up by the player.
				-- Stop tracking quests that are past its current reset date
				-- There is an edge case where the player can hold on to a completed but not turned in quest so dont delete that one
				-- If they turn it in past the "deadline" it counts as completed for that lockout period anyway.
				if (quest.isCompleted and quest.isTurnedIn) then
					Log("Expired quest is completed and turned in, now removing quest with questID: " .. quest.id .. " name: " .. quest.name .. " from the tracker database")
					self.db.global.realms[self.currentRealm].characters[characterName].quests[questID] = nil
				end

				-- If the player has an in progress quest that belongs to an older daily or weekly reset then just flag it
				-- This will show up in the UI with a warning triangle and a message so they know they are on a quest belonging to an older reset.
				if (not quest.isCompleted and not quest.isTurnedIn) then
					Log("Expired quest is NOT completed and NOT turned in, flagging quest with a user warning for questID: " .. quest.id .. " name: " .. quest.name .. " in the tracker database")
					self.db.global.realms[self.currentRealm].characters[characterName].quests[questID].hasExpired = true
				end
			end
		end
	end
end

--- Iterate over all tracked quests for the current character and if there is a mismatch between the database and the quest's completion state, update the database.
function RackensTracker:UpdateQuestCompletionIfNecessary()
	for questID, trackedQuest in pairs(self.currentCharacter.quests) do
		if (C_QuestLog.IsOnQuest(trackedQuest.id) and IsQuestComplete(trackedQuest.id)) then
			if (trackedQuest.isCompleted == false) then
				Log("Found a tracked quest that was completed but lacked that information in the database, questID: " .. trackedQuest.id .. " and name: " .. trackedQuest.name)
				self.currentCharacter.quests[questID].isCompleted = true
			end
		end
	end
end

--- Iterates over all known characters for the current realm and checks each of the character's saved instances to see if
--- they have reset. If they have, they are removed from the tracker.
function RackensTracker:ResetTrackedInstancesIfNecessary()
	for characterName, character in pairs(self.db.global.realms[self.currentRealm].characters) do
		for id, savedInstance in pairs(character.savedInstances) do
			-- TODO: Look into if this savedInstance.resetTime is completely accurate as we update our information about it very frequently on events
			if (savedInstance.resetTime and savedInstance.resetTime < GetServerTime()) then
				Log("Found tracked instance that expired in a previous reset for: " .. characterName)
				Log("Tracked instance id: " .. savedInstance.instanceName .. " " .. savedInstance.difficultyName)
				local timeNow = GetServerTime()
				Log("Current server time: " .. timeNow)
				Log("Tracked instance set to expire at server time: " .. savedInstance.resetTime)
				Log("Tracked instance expired: " .. timeFormatter:Format(timeNow - (savedInstance.resetTime)) .. " ago")
				Log("At the time of getting saved to the instance there was: " .. timeFormatter:Format(timeNow - savedInstance.resetTime) .. " left until reset")

				self.db.global.realms[self.currentRealm].characters[characterName].savedInstances[id] = nil
			end
		end
	end
end

--- Adds quests to the database if they are found in the current character's quest log and they do not exist in the database
function RackensTracker:CreateActiveMissingQuests()
	for questID, trackableQuest in pairs(RT.Quests) do
		-- If the current player is already on a trackable quest but they dont have it tracked that means they 
		-- accepted it before they used this addon or had it disabled during a time in which they
		-- accepted the quest.

		-- We can not make any assumptions on the internal secondsToReset or acceptedAt timestamps
		-- but we should be able to handle this tracked quest object like any other created by our event handlers anyway
		-- This does mean however that the quest might be removed from the tracker after completion and turn in
		-- as the code that checks if we are past the weekly or daily reset assumes these timestamps exist.
		-- It is a small price to pay to be more inclusive.
		if (C_QuestLog.IsOnQuest(questID) and not self.currentCharacter.quests[questID]) then
			local newTrackedQuest = {
				id = questID,
				name = trackableQuest.getName(questID),
				questTag = trackableQuest.getQuestTag(questID),
				isWeekly = trackableQuest.isWeekly,
				 -- Assume it was just picked up, we cant know anyway
				acceptedAt = GetServerTime(),
				-- Assume its for the current reset
				-- if the player somehow kept an old quest and didnt complete it or did complete it but not turned it in then it will be cleared 
				-- by the tracker at the next available daily or weekly reset.
				-- TODO: This might cause bug reports, so maybe take a second look at this at some point.
				secondsToReset = trackableQuest.isWeekly and C_DateAndTime.GetSecondsUntilWeeklyReset() or C_DateAndTime.GetSecondsUntilDailyReset(),
				isCompleted = IsQuestComplete(questID),
				isTurnedIn = false,
				craftedFromExistingQuest = true -- Just there to differentiate between quest handled fully by our addon.		
			}

			self.currentCharacter.quests[questID] = newTrackedQuest

			Log("Trackable active quest found in quest log but not in the database, adding it to the tracker..")
			Log("Found new trackable quest, questID: " .. newTrackedQuest.id .. " questTag: " .. newTrackedQuest.questTag .. " and name: " .. newTrackedQuest.name)
		end
	end
end

--- Adds completed and turned in quests for the current character if they do not exist the database.
--- For weekly quests this will use a heuristic process as completing one weekly raid quest means you "completed" all the others in that pool of quests.
function RackensTracker:CreateFinishedMissingQuests()
	-- This is a collection of all quests the current character has completed in its lifetime.
	-- Daily quests appear completed only if they have been completed that day.
	-- Weekly quests appear completed only if they have been completed that week.
	local allQuestsCompletedTurnedIn = GetQuestsCompleted()
	local currentWeeklyQuest = self:TryToFindCurrentWeeklyQuest()
	local currentCharacterFinishedWeeklyQuest = self:TryGetCurrentFinishedWeeklyQuest()

	---@type DbQuest
	local newTrackedQuest = {
		id = 0,
		name = "",
		questTag = "",
		faction = nil,
		isWeekly = true,
		acceptedAt = 0,
		secondsToReset = 0,
		isCompleted = true,
		isTurnedIn = true,
	}

	for questID, isCompletedAndTurnedIn in pairs(allQuestsCompletedTurnedIn) do
		if (RT.Quests[questID] and isCompletedAndTurnedIn) then
			local trackableQuest = RT.Quests[questID]
			if (not trackableQuest.isWeekly) then
				-- Found a completed and turned in daily quest for this ACTIVE reset that is not currently tracked for the character
				if (not self.currentCharacter.quests[questID]) then
					newTrackedQuest = {
						id = questID,
						name = trackableQuest.getName(questID),
						questTag = trackableQuest.getQuestTag(questID),
						faction = trackableQuest.faction,
						isWeekly = false,
						-- Assume it was just turned in, we cant know anyway
						acceptedAt = GetServerTime(),
						-- We know it's for the current reset
						secondsToReset = C_DateAndTime.GetSecondsUntilDailyReset(),
						isCompleted = true,
						isTurnedIn = true,
						craftedFromExistingQuest = true,
					}

					self.currentCharacter.quests[questID] = newTrackedQuest

					Log("Trackable completed and turned in daily quest found but not found in the database, adding it to the tracker..")
					Log("Found new trackable daily quest with questID: " .. questID .. " name: " .. newTrackedQuest.name)
				end
			else
				-- NOTE: If one of the raid weekly quests have been completed and turned in this reset, they are ALL marked as completed and turned in
				-- We will try to select this week's active quest by using a heuristic process, this process is applied for both of the following conditions:
				-- 1. If the current character has no tracked weekly raid quest but has finished one
				-- 2. If the current character has a tracked weekly raid quest but it might have previously been created by this function with craftedFromHeuristicGuess.
				-- 	  So we look if another character possibly knows which quest was actually available for this active reset
				-- Heuristic process:
				-- 1. Do we have a weekly quest stored in the database for a character that is not the current character? YES/NO
				-- 2. Is the quest crafted without craftedFromHeuristicGuess YES/NO
				-- 3. Is the quest still valid for this reset YES/NO
				-- If all of the above is answered by YES, we will take this known weekly quest to create the missing finished weekly quest
				-- if all of the above is not answered by YES, we will grab the first possible weekly quest returned from GetQuestsCompleted()
				if (not currentCharacterFinishedWeeklyQuest or (currentCharacterFinishedWeeklyQuest and currentWeeklyQuest and currentCharacterFinishedWeeklyQuest.id ~= currentWeeklyQuest.id)) then
					if (currentWeeklyQuest) then
						if (currentWeeklyQuest.faction == nil or (currentWeeklyQuest.faction and currentWeeklyQuest.faction == self.currentCharacter.faction)) then
							-- Possibly found a better match for the current weekly quest, so we must delete the current one in the database
							if currentCharacterFinishedWeeklyQuest then self.currentCharacter.quests[currentCharacterFinishedWeeklyQuest.id] = nil end
							if (not self.currentCharacter.quests[currentWeeklyQuest.id]) then

								newTrackedQuest = {
									id = currentWeeklyQuest.id,
									name = currentWeeklyQuest.name,
									questTag = currentWeeklyQuest.questTag,
									faction = currentWeeklyQuest.faction,
									isWeekly = true,
									-- Assume it was just turned in, we cant know anyway
									acceptedAt = GetServerTime(),
									-- We know it's for the current reset
									secondsToReset = C_DateAndTime.GetSecondsUntilWeeklyReset(),
									isCompleted = true,
									isTurnedIn = true,
									-- This quest is guaranteed to belong to another character's tracked quests but it could either be for the active reset or come from 
									-- another reset therefore its crafted from an existing quest from another character.
									craftedFromExistingQuest = true
								}

								self.currentCharacter.quests[currentWeeklyQuest.id] = newTrackedQuest

								Log("Trackable completed and turned in weekly quest found but not found in the database, adding it to the tracker..")
								Log("Heuristics found current active weekly quest with questID: " .. questID .. " name: " .. newTrackedQuest.name)
								-- TODO: Maybe optimize this to set a field in the currentCharacter such as hasCompletedRaidWeekly
								-- this must be unflagged though when the weekly reset happens which could be a source for more bugs, so the tradeoff is more computing, less flags
								currentCharacterFinishedWeeklyQuest = self:TryGetCurrentFinishedWeeklyQuest()
							end
						end
					else
						if (trackableQuest.faction == nil or (trackableQuest.faction and trackableQuest.faction == self.currentCharacter.faction)) then
							if (not self.currentCharacter.quests[questID]) then
								newTrackedQuest = {
									id = questID,
									name = trackableQuest.getName(questID),
									questTag = trackableQuest.getQuestTag(questID),
									faction = trackableQuest.faction,
									isWeekly = true,
									-- Assume it was just turned in, we cant know anyway
									acceptedAt = GetServerTime(),
									-- We know it's for the current reset
									secondsToReset = C_DateAndTime.GetSecondsUntilWeeklyReset(),
									isCompleted = true,
									isTurnedIn = true,
									craftedFromHeuristicGuess = true,
								}

								self.currentCharacter.quests[questID] = newTrackedQuest
								-- TODO: Maybe optimize this to set a field in the currentCharacter such as hasCompletedRaidWeekly
								-- this must be unflagged though when the weekly reset happens which could be a source for more bugs, so the tradeoff is more computing, less flags
								currentCharacterFinishedWeeklyQuest = self:TryGetCurrentFinishedWeeklyQuest()
								Log("Trackable completed and turned in weekly quest found but not found in the database, adding it to the tracker..")
								Log("Heuristics could not find the current active weekly quest, guessing its questID: " .. questID .. " name: " .. newTrackedQuest.name)
							end
						end
					end
				end
			end
		end
	end
end

--- Asks the server for the latest weekly and daily reset times and saves them to the database
function RackensTracker:UpdateWeeklyDailyResetTime()
	-- Update to get the absolute latest timers
	self.db.global.realms[self.currentRealm].secondsToWeeklyReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
	self.db.global.realms[self.currentRealm].secondsToDailyReset  = C_DateAndTime.GetSecondsUntilDailyReset()
	self.db.global.realms[self.currentRealm].weeklyResetTime = GetServerTime() + self.db.global.realms[self.currentRealm].secondsToWeeklyReset
	self.db.global.realms[self.currentRealm].dailyResetTime = GetServerTime() + self.db.global.realms[self.currentRealm].secondsToDailyReset
end

--- Called when the addon is initialized
function RackensTracker:OnInitialize()

	self.currentRealm = GetRealmName()

	self.tracker_frame = nil
	self.optionsCategory = nil
	self.optionsLayout = nil

	-- Load saved variables
	self.db = LibStub("AceDB-3.0"):New("RackensTrackerDB", database_defaults, true)

	-- Reset any character's weekly or daily quests if it meets the criteria to do so
	self:ResetTrackedQuestsIfNecessary()

	-- Reset any character's weekly raid or daily dungeon lockouts if it meets the criteria to do so
	self:ResetTrackedInstancesIfNecessary()

	-- Update weekly and daily reset timers
	self:UpdateWeeklyDailyResetTime()

	local function OnQuestOptionSettingChanged(_, setting, value)
		local variable = setting:GetVariable()
		self.db.global.options.shownQuests[variable] = value
	end

	local function OnCurrencyOptionSettingChanged(_, setting, value)
		local variable = setting:GetVariable()
		if (variable == L["optionsToggleNameShowCurrencies"]) then
			self.db.global.options.showCurrencies = value
		else
			self.db.global.options.shownCurrencies[variable] = value
		end
	end

	-- Sets up the layout and options see under the AddOn options
	self:RegisterAddOnSettings(OnQuestOptionSettingChanged, OnCurrencyOptionSettingChanged)

	-- Setup the data broken and the minimap icon
	self.libDataBroker = LibStub("LibDataBroker-1.1", true)
	self.libDBIcon = self.libDataBroker and LibStub("LibDBIcon-1.0", true)
	local minimapBtn = self.libDataBroker:NewDataObject(addOnName, {
		type = "launcher",
		icon = "Interface\\Icons\\Achievement_boss_lichking",
		OnClick = function(_, button)
			if (button == "LeftButton") then
				-- If the window is already created
				self:ToggleTrackerFrame()
			end
			if (button == "RightButton") then
				self:OpenOptionsFrame()
			end
		end,
		tocname = addOnName,
		label = addOnName,
		---@type function|GameTooltip
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(RT.Util:FormatColor(HIGHLIGHT_FONT_COLOR_CODE, "%s - %s %s", addOnName, L["version"], addOnVersion))
			tooltip:AddLine(RT.Util:FormatColor(GRAY_FONT_COLOR_CODE, "%s", "/rackenstracker for available commands"))
			tooltip:AddLine(RT.Util:FormatColor(GRAY_FONT_COLOR_CODE, "%s: ", L["minimapLeftClickAction"]) .. RT.Util:FormatColor(NORMAL_FONT_COLOR_CODE, "%s", L["minimapLeftClickDescription"]))
			tooltip:AddLine(RT.Util:FormatColor(GRAY_FONT_COLOR_CODE, "%s: ", L["minimapRightClickAction"]) .. RT.Util:FormatColor(NORMAL_FONT_COLOR_CODE, "%s", L["minimapRightClickDescription"]))
		end,
	})

	if self.libDBIcon then
		---@diagnostic disable-next-line: param-type-mismatch
		self.libDBIcon:Register(addOnName, minimapBtn, self.db.char.minimap)
	end

	tinsert(UISpecialFrames, "RackensTrackerWindowFrame")
end


--- Called when the addon is enabled
function RackensTracker:OnEnable()
	local characterName = UnitName("player")
	self.currentCharacter = self.db.global.realms[self.currentRealm].characters[characterName]
	self.currentCharacter.name = characterName
	self.currentCharacter.class = GetCharacterClass()
	self.currentCharacter.level = UnitLevel("player")
	self.currentCharacter.realm = GetRealmName()
	self.currentCharacter.faction = UnitFactionGroup("player")

	self:UpdateQuestCompletionIfNecessary()

	self:CreateActiveMissingQuests()

	self:CreateFinishedMissingQuests()

	-- Raid and dungeon related events
	self:RegisterEvent("BOSS_KILL", "OnEventBossKill")
    self:RegisterEvent("INSTANCE_LOCK_START", "OnEventInstanceLockStart")
    self:RegisterEvent("INSTANCE_LOCK_STOP", "OnEventInstanceLockStop")
    self:RegisterEvent("INSTANCE_LOCK_WARNING", "OnEventInstanceLockWarning")
    self:RegisterEvent("UPDATE_INSTANCE_INFO", "OnEventUpdateInstanceInfo")

	-- Currency related events
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "OnEventCurrencyDisplayUpdate")
	self:RegisterEvent("CHAT_MSG_CURRENCY", "OnEventChatMsgCurrency")

	-- Daily - Weekly quest related events
	self:RegisterEvent("QUEST_ACCEPTED", "OnEventQuestAccepted")
	self:RegisterEvent("QUEST_REMOVED", "OnEventQuestRemoved")
	self:RegisterEvent("QUEST_TURNED_IN", "OnEventQuestTurnedIn")
	-- TODO: maybe register for UNIT_QUEST_LOG_CHANGED or last resort QUEST_LOG_UPDATE to check if we made progress to complete a quest
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED", "OnEventUnitQuestLogChanged")
	self:RegisterEvent("QUEST_LOG_CRITERIA_UPDATE", "OnEventQuestLogCriteriaUpdate")

	-- Level up event
	self:RegisterEvent("PLAYER_LEVEL_UP", "OnEventPlayerLevelUp")

	-- Register Slash Commands
	self:RegisterChatCommand("RackensTracker", "SlashCommand")

	-- Request raid lockout information from the server
	self:TriggerUpdateInstanceInfo()

	-- Update currency information for the currenct logged in character
	self:UpdateCharacterCurrencies()
end

--- Called when the addon is disabled
function RackensTracker:OnDisable()
	-- Called when the addon is disabled
	self:UnregisterChatCommand("RackensTracker")
end

--- Registers this AddOns configurable settings and specifies the layout and graphical elements for the settings panel.
---@param OnQuestOptionChanged function
---@param OnCurrencyOptionChanged function
function RackensTracker:RegisterAddOnSettings(OnQuestOptionChanged, OnCurrencyOptionChanged)
	-- Register the Options menu
	self.optionsCategory, self.optionsLayout = Settings.RegisterVerticalLayoutCategory("RackensTracker")
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsQuestsHeader"]))

	local weeklyQuestOptionVariable = L["optionsToggleNameWeeklyQuest"]
	local weeklyQuestOptionDisplayName = L["optionsToggleDescriptionWeeklyQuest"]
	local defaultWeeklyQuestVisibilityValue = database_defaults.global.options.shownQuests[weeklyQuestOptionVariable]
	local weeklyQuestOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, weeklyQuestOptionDisplayName, weeklyQuestOptionVariable, type(defaultWeeklyQuestVisibilityValue), defaultWeeklyQuestVisibilityValue)
	Settings.CreateCheckBox(self.optionsCategory, weeklyQuestOptionVisibilitySetting)
	Settings.SetOnValueChangedCallback(weeklyQuestOptionVariable, OnQuestOptionChanged)
	weeklyQuestOptionVisibilitySetting:SetValue(self.db.global.options.shownQuests[weeklyQuestOptionVariable], true) -- true means force

	local dailyQuestOptionVariable = L["optionsToggleNameDailyQuest"]
	local dailyQuestOptionDisplayName = L["optionsToggleDescriptionDailyQuest"]
	local defaultDailyQuestVisibilityValue = database_defaults.global.options.shownQuests[dailyQuestOptionVariable]
	local dailyquestOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, dailyQuestOptionDisplayName, dailyQuestOptionVariable, type(defaultDailyQuestVisibilityValue), defaultDailyQuestVisibilityValue)
	Settings.CreateCheckBox(self.optionsCategory, dailyquestOptionVisibilitySetting)
	Settings.SetOnValueChangedCallback(dailyQuestOptionVariable, OnQuestOptionChanged)
	dailyquestOptionVisibilitySetting:SetValue(self.db.global.options.shownQuests[dailyQuestOptionVariable], true) -- true means force

	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsCurrenciesHeader"]))

	local allCurrencyOptionVariable = L["optionsToggleNameShowCurrencies"]
	local allCurrencyOptionDisplayName = L["optionsToggleDescriptionShowCurrencies"]
	local defaultAllCurrencyVisibilityValue = database_defaults.global.options.showCurrencies
	local allCurrencyOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, allCurrencyOptionDisplayName, allCurrencyOptionVariable, type(defaultAllCurrencyVisibilityValue), defaultAllCurrencyVisibilityValue)
	local allCurrencyOptionInitializer = Settings.CreateCheckBox(self.optionsCategory, allCurrencyOptionVisibilitySetting)
	Settings.SetOnValueChangedCallback(allCurrencyOptionVariable, OnCurrencyOptionChanged)
	dailyquestOptionVisibilitySetting:SetValue(self.db.global.options.showCurrencies, true) -- true means force

	for _, currency in ipairs(RT.Currencies) do
		local variable = tostring(currency.id)
		local name = currency:GetName()
		-- Look at our database_defaults for a default value.
		local defaultValue = database_defaults.global.options.shownCurrencies[variable]
		local setting = Settings.RegisterAddOnSetting(self.optionsCategory, name, variable, type(defaultValue), defaultValue)
		local initializer = Settings.CreateCheckBox(self.optionsCategory, setting, L["optionsToggleCurrencyTooltip"])
		Settings.SetOnValueChangedCallback(variable, OnCurrencyOptionChanged)

		-- The initial value for the checkbox is defaultValue, but we want it to reflect what's in our savedVars, we want to keep the defaultValue what it should be
		-- because when we click the "Default" button and choose "These Settings" we want it to revert to the database default setting.
		setting:SetValue(self.db.global.options.shownCurrencies[variable], true) -- true means force
		initializer:SetParentInitializer(allCurrencyOptionInitializer, function() return allCurrencyOptionVisibilitySetting:GetValue() end)
	end

	Settings.RegisterAddOnCategory(self.optionsCategory)
end

--- Prints the available slash commands used for this AddOn to the chat window
local function slashCommandUsage()
	SlashCmdLog("\"/rackenstracker toggle\" toggles visibility of the the tracking window")
	SlashCmdLog("\"/rackenstracker options\" opens the options window")
	SlashCmdLog("\"/rackenstracker minimap show\" shows the minimap button")
	SlashCmdLog("\"/rackenstracker minimap hide\" hides the minimap button")
end

--- Handler for all slash commands available for this AddOn
---@param msg string
function RackensTracker:SlashCommand(msg)
	local command, value, _ = self:GetArgs(msg, 2)

	if (command == nil or command:trim() == "") then
		return slashCommandUsage()
	end

	if (command == "toggle") then
		return self:ToggleTrackerFrame()
	elseif (command == "options" or command == "config") then
		return self:OpenOptionsFrame()
	elseif (command == "minimap") then
		if (value == "show") then
			--Log("Enabling the minimap button")
			self.db.char.minimap.hide = false
			--print("curr minimap hide state:" .. tostring(self.db.char.minimap.hide))
			return self.libDBIcon:Show(addOnName)
		elseif (value == "hide") then
			--Log("Disabling the minimap button")
			self.db.char.minimap.hide = true
			--print("curr minimap hide state:" .. tostring(self.db.char.minimap.hide))
			return self.libDBIcon:Hide(addOnName)
		else
			return slashCommandUsage()
		end
	else
		return slashCommandUsage()
	end
end

--- Requests saved instance information from the game server.
function RackensTracker:TriggerUpdateInstanceInfo()
	RequestRaidInfo()
end

--- Called when a boss is killed in an instance
function RackensTracker:OnEventBossKill()
    --Log("OnEventBossKill")
    self:TriggerUpdateInstanceInfo()
end

function RackensTracker:OnEventInstanceLockStart()
    --Log("OnEventInstanceLockStart")
    self:TriggerUpdateInstanceInfo()
end

--- Called when quitting the game
function RackensTracker:OnEventInstanceLockStop()
    --Log("OnEventInstanceLockStop")
    self:TriggerUpdateInstanceInfo()
end

--- Called when recieving a warning that the player will be saved if they accept
function RackensTracker:OnEventInstanceLockWarning()
    --Log("OnEventInstanceLockWarning")
    self:TriggerUpdateInstanceInfo()
end

--- Called when data from RequestRaidInfo is available from the server, runs self:UpdateCharacterLockouts()
function RackensTracker:OnEventUpdateInstanceInfo()
    --Log("OnEventUpdateInstanceInfo")
	self:UpdateCharacterLockouts()
end

--- Called when currency information is updated from the server, runs self:UpdateCharacterCurrencies()
function RackensTracker:OnEventCurrencyDisplayUpdate()
	--Log("OnEventCurrencyDisplayUpdate")
	self:UpdateCharacterCurrencies()
end

--- Called when the player gains currency other than money, such as emblems
function RackensTracker:OnEventChatMsgCurrency(event, text, playerName)
	--Log("OnEventChatMsgCurrency")
	--Log("Recieved text: " .. text)

	-- TODO: Maybe we dont need CHAT_MSG_CURRENCY event as it seems that CURRENCY_DISPLAY_UPDATE triggers on both boss kills and quest turn ins.
	-- Also playerName seems to be nil or "" :/
	if (playerName == UnitName("player")) then
		-- We recieved a currency, update character currencies
		-- TODO: maybe use lua pattern matching and match groups to extract the item name and
		-- find out if the item is one of the currencies we are interested in, no idea if the currency name is localized if it's in enUS
		--local itemLink, count = string.match(text, "(|c.+|r) ?x?(%d*).?")
		--local itemInfo = C_CurrencyInfo.GetCurrencyInfoFromLink(itemLink)
		self:UpdateCharacterCurrencies()
	end
end

--- Called when the player levels up
---@param event string PLAYER_LEVEL_UP
---@param newLevel number
function RackensTracker:OnEventPlayerLevelUp(event, newLevel)
	self:UpdateCharacterLevel(newLevel)
end

--- Called when a quest is accepted.
--- Inserts the newly accepted quest into the database for the current character
---@param event string QUEST_ACCEPTED
---@param questLogIndex number
---@param questID number
function RackensTracker:OnEventQuestAccepted(event, questLogIndex, questID)
	Log("OnEventQuestAccepted")
	--Log("questID: " .. questID)

	---@type DbQuest
	local newTrackedQuest = {
		id = questID,
		name = "",
		questTag = "",
		faction = nil,
		isWeekly = true,
		acceptedAt = 0,
		secondsToReset = 0,
		isCompleted = false,
		isTurnedIn = false,
	}

	-- It's a weekly or daily quest we care to track
	local trackableQuest = RT.Quests[questID]
	if (trackableQuest) then
		-- TODO: Might be able to remove this check because you cant accept a quest you arent eligible for in the first place
		if (trackableQuest.faction == nil or (trackableQuest.faction and trackableQuest.faction == self.currentCharacter.faction) and trackableQuest.prerequesite(self.currentCharacter.level)) then
			newTrackedQuest.name = trackableQuest.getName(questID)
			newTrackedQuest.questTag = trackableQuest.getQuestTag(questID)
			newTrackedQuest.faction = trackableQuest.faction
			newTrackedQuest.isWeekly = trackableQuest.isWeekly
			newTrackedQuest.acceptedAt = GetServerTime()
			if (trackableQuest.isWeekly) then
				newTrackedQuest.secondsToReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
			else
				newTrackedQuest.secondsToReset = C_DateAndTime.GetSecondsUntilDailyReset()
			end

			Log("Found new trackable quest, is faction specific: " .. tostring(trackableQuest.faction) .. " questID: " .. newTrackedQuest.id .. " questTag: " .. newTrackedQuest.questTag .. " and name: " .. newTrackedQuest.name)
			self.currentCharacter.quests[questID] = newTrackedQuest
		end
	end
end

--- Called when a player has turned in a quest or when they removed it manually from their quest log. Removes the quest from the database for the current character
---@param event string QUEST_REMOVED
---@param questID number
function RackensTracker:OnEventQuestRemoved(event, questID)
	Log("OnEventQuestRemoved")
	--Log("questID: " .. tostring(questID))

	local trackableQuest = RT.Quests[questID]
	local trackedQuest = self.currentCharacter.quests[questID]
	if (trackableQuest) then
		-- NOTE: Only remove the tracked quest if it's not being turned in because OnEventQuestTurnedIn is called BEFORE this event handler is executed.
		-- Only remove the quest from the table of tracked quests for this player if they manually remove the quest from their quest log.
		if (trackedQuest and trackedQuest.isTurnedIn == false) then
			Log("Removed tracked quest, isWeekly: " .. tostring(trackedQuest.isWeekly) .. " questID: " .. trackedQuest.id .. " and name: " .. trackedQuest.name)
			self.currentCharacter.quests[questID] = nil
		end
	end
end

--- Called when the player has turned in a quest from their quest log. Marks the quest as turned in, in the database
---@param event string QUEST_TURNED_IN
---@param questID number
function RackensTracker:OnEventQuestTurnedIn(event, questID)
	Log("OnEventQuestTurnedIn")
	--Log("questID: " .. tostring(questID))
	local trackableQuest = RT.Quests[questID]
	if (trackableQuest) then
		Log("Turned in tracked quest, isWeekly: " .. tostring(trackableQuest.isWeekly) .. " questID: " .. trackableQuest.id .. " and name: " .. trackableQuest.getName(trackableQuest.id))

		---@type DbQuest
		local trackedQuest = {
			id = questID,
			name = trackableQuest.getName(questID),
			questTag = trackableQuest.getQuestTag(questID),
			faction = trackableQuest.faction,
			isWeekly = trackableQuest.isWeekly,
			acceptedAt = GetServerTime(),
			secondsToReset = trackableQuest.isWeekly and C_DateAndTime.GetSecondsUntilWeeklyReset() or C_DateAndTime.GetSecondsUntilDailyReset(),
			isCompleted = true,
			isTurnedIn = true
		}

		self.currentCharacter.quests[questID] = trackedQuest
		Log("Tracked quest belongs to the active reset, set to expire at server time: " .. trackedQuest.acceptedAt + trackedQuest.secondsToReset)
		Log("Tracked quest will expire in: " .. timeFormatter:Format(trackedQuest.secondsToReset))
	end
end

--- Called when a quest objective is updated for the player. Will mark quests as completed when the player completes the quest's objectives
---@param event string QUEST_LOG_CRITERIA_UPDATE
---@param questID number
---@param specificTreeID number
---@param description string
---@param numFulfilled number
---@param numRequired number
function RackensTracker:OnEventQuestLogCriteriaUpdate(event, questID, specificTreeID, description, numFulfilled, numRequired)
	Log("OnEventQuestLogCriteriaUpdate")
	--Log("specificTreeID: " .. tostring(specificTreeID) .. " description: " .. description .. " numFulfilled: " .. tostring(numFulfilled) .. " numRequired: " .. tostring(numRequired))

	local trackedQuest = self.currentCharacter.quests[questID]
	if (trackedQuest) then
		if (C_QuestLog.IsOnQuest(trackedQuest.id) and IsQuestComplete(trackedQuest.id)) then
			if (trackedQuest.isCompleted == false) then
				Log("Completed tracked quest, isWeekly: " .. tostring(trackedQuest.isWeekly) .. " questID: " .. trackedQuest.id .. " and name: " .. trackedQuest.name)
				self.currentCharacter.quests[questID].isCompleted = true
			end
        end
	end
end

--- Called when the player's quest log changed, this happens frequently when interacting with quests. Will mark quests as completed when the player completes the quest's objectives
---@param event string UNIT_QUEST_LOG_CHANGED
---@param unitTarget string
function RackensTracker:OnEventUnitQuestLogChanged(event, unitTarget)
	if (unitTarget == "player") then
		Log("OnEventUnitQuestLogChanged")

		for questID, trackedQuest in pairs(self.currentCharacter.quests) do
			if (C_QuestLog.IsOnQuest(trackedQuest.id) and IsQuestComplete(trackedQuest.id)) then
				if (trackedQuest.isCompleted == false) then
					Log("Completed tracked quest, isWeekly: " .. tostring(trackedQuest.isWeekly) .. " questID: " .. trackedQuest.id .. " and name: " .. trackedQuest.name)
					self.currentCharacter.quests[questID].isCompleted = true
				end
			end
		end
	end
end


-- GUI Code --
-- The "Flow" Layout will let widgets fill one row, and then flow into the next row if there isn't enough space left. 
-- Its most of the time the best Layout to use.
-- The "List" Layout will simply stack all widgets on top of each other on the left side of the container.
-- The "Fill" Layout will use the first widget in the list, and fill the whole container with it. Its only useful for containers 

--- Creates an empty dummy label widget to take up UI space but is rendered as invisible
---@return AceGUIWidget
local function CreateDummyFrame()
	local dummyFiller = AceGUI:Create("Label")
	dummyFiller:SetText(" ")
	dummyFiller:SetFullWidth(true)
	dummyFiller:SetHeight(20)
	return dummyFiller
end

--- Given a DbQuest object returns an appropriate icon depending on the quests progressed state
---@param quest any
---@return string textureString
local function getQuestIcon(quest)
	local atlasSize = 14
	local textureAtlas = ""
	local questionMarkAtlas = "QuestTurnin"
	local turnedInAtlas = "common-icon-checkmark"
	local warningAtlas = "services-icon-warning"

	if (quest.isCompleted) then
		textureAtlas = questionMarkAtlas
		if (quest.isTurnedIn) then
			textureAtlas = turnedInAtlas
		end
		if (quest.craftedFromHeuristicGuess) then
			textureAtlas = turnedInAtlas
		end
	else
		if quest.isWeekly then
			textureAtlas = questionMarkAtlas
			return CreateSimpleTextureMarkup("Interface\\GossipFrame\\IncompleteQuestIcon", atlasSize, atlasSize)
		else
			textureAtlas = questionMarkAtlas
			return CreateSimpleTextureMarkup("Interface\\GossipFrame\\IncompleteQuestIcon", atlasSize, atlasSize)
		end
		if (quest.hasExpired) then
			textureAtlas = warningAtlas
		end
	end

	local icon = CreateAtlasMarkup(textureAtlas, atlasSize, atlasSize)
	return icon
end

--- Returns the quest available icon, blue for daily yellow for anything else
---@param isWeekly boolean
---@return string textureString
local function getAvailableQuestIcon(isWeekly)
	local atlasSize = 14
	local textureAtlas = ""
	local availableAtlas = "QuestNormal"
	local availableDailyAtlas = "QuestDaily"

	if isWeekly then
		textureAtlas = availableAtlas
	else
		textureAtlas = availableDailyAtlas
	end
	local icon = CreateAtlasMarkup(textureAtlas, atlasSize, atlasSize)
	return icon
end

--- Creates an AceGUI label widget for an available quest, with an icon and text to be displayed in the tracker
---@param name string quest name
---@param questTag string (Heroic|Raid)
---@param isWeekly boolean if the quest is a weekly or daily quest
---@return AceGUIWidget
local function createAvailableQuestLogItemEntry(name, questTag, isWeekly)
	local questLabel = AceGUI:Create("Label")
	questLabel:SetFullWidth(true)

	local icon = getAvailableQuestIcon(isWeekly)
	local status = L["questStatusAvailable"]

	local displayedQuestTag = ""
	if (isWeekly) then
		displayedQuestTag = questTag
	else
		displayedQuestTag = string.format(DAILY_QUEST_TAG_TEMPLATE, questTag)
	end

	local colorizedText = RT.Util:FormatColor(YELLOW_FONT_COLOR_CODE, "%s (%s) - %s", isWeekly and L["weeklyQuest"] or name, displayedQuestTag, status)
	local labelText = string.format("%s %s", icon, colorizedText)

	questLabel:SetText(labelText)
	return questLabel
end

--- Creates an AceGUI label widget with an icon and text to be displayed, reflecting the current state of the quest's progress
---@param quest table
---@return AceGUIWidget
local function createTrackedQuestLogItemEntry(quest)
	local questLabel = AceGUI:Create("Label")
	questLabel:SetFullWidth(true)

	local icon = getQuestIcon(quest)
	---@type string|true
	local status = ""
	local questTag = ""
	if (quest.isWeekly) then
		questTag = quest.questTag
	else
		questTag = string.format(DAILY_QUEST_TAG_TEMPLATE, quest.questTag)
	end

	if (quest.isCompleted) then
		status = L["questStatusCompleted"]
		if (quest.isTurnedIn) then
			status = L["questStatusTurnedIn"]
		end
	else
		status = L["questStatusInProgress"]
	end

	if (quest.hasExpired) then
		status = status .. " " .. L["questStatusExpired"]
	end

	local colorizedText = RT.Util:FormatColor(YELLOW_FONT_COLOR_CODE, "%s (%s) - %s", quest.isWeekly and L["weeklyQuest"] or quest.name, questTag, status)
	local labelText = string.format("%s %s", icon, colorizedText)

	questLabel:SetText(labelText)
	return questLabel
end

--- Draws the graphical elements to display the tracked quests, given a known character name
---@param container AceGUIWidget
---@param characterName string name of the character to render quests for
function RackensTracker:DrawQuests(container, characterName)
	if (not ContainsIf(self.db.global.options.shownQuests, function(questTypeEnabled) return questTypeEnabled end)) then
		return
	end

	local shouldDisplayWeeklyQuests = self.db.global.options.shownQuests[L["optionsToggleNameWeeklyQuest"]]
	local shouldDisplayDailyQuests = self.db.global.options.shownQuests[L["optionsToggleNameDailyQuest"]]
	local characterQuests = self.db.global.realms[self.currentRealm].characters[characterName].quests

	local sortedAvailableQuests = {}
	local availableWeeklyQuest = nil
	local characterWeeklyQuest = nil
	local questEntry = nil

	-- Grab the first available weekly that this character has, may be none
	for _, quest in pairs(characterQuests) do
		if quest.isWeekly then
			characterWeeklyQuest = quest
			break
		end
	end

	for _, quest in pairs(RT.Quests) do
		table.insert(sortedAvailableQuests, quest)
		table.sort(sortedAvailableQuests, function(q1, q2) return q1.isWeekly and not q2.isWeekly end)
	end

	-- Grab the last available weekly that is available
	for _, quest in pairs(sortedAvailableQuests) do
		if (quest.isWeekly) then
			availableWeeklyQuest = quest
		end
	end

	container:AddChild(CreateDummyFrame())

	local questsHeading = AceGUI:Create("Heading")
	questsHeading:SetFullWidth(true)
	questsHeading:SetText(L["weeklyDailyQuests"])

	container:AddChild(questsHeading)
	container:AddChild(CreateDummyFrame())

	-- Draw the current weekly quest if we have one, or just pick the available one to show as available,
	-- all weekly quests share lockout so we don't care about its name anyway.
	-- Draw all the characters daily quests or show the available ones below it.
	for _, quest in ipairs(sortedAvailableQuests) do
		if (characterQuests[quest.id]) then
			if (characterWeeklyQuest and characterWeeklyQuest.id == quest.id) then
				if (shouldDisplayWeeklyQuests) then
					questEntry = createTrackedQuestLogItemEntry(characterWeeklyQuest)
					container:AddChild(questEntry)
					if (shouldDisplayDailyQuests) then container:AddChild(CreateDummyFrame()) end
				end
			end
			if (not characterQuests[quest.id].isWeekly) then
				if (shouldDisplayDailyQuests) then
					questEntry = createTrackedQuestLogItemEntry(characterQuests[quest.id])
					container:AddChild(questEntry)
				end
			end
		else
			if (not characterWeeklyQuest and availableWeeklyQuest and availableWeeklyQuest.id == quest.id) then
				if (shouldDisplayWeeklyQuests) then
					questEntry = createAvailableQuestLogItemEntry(quest.getName(quest.id), quest.getQuestTag(quest.id), quest.isWeekly)
					container:AddChild(questEntry)
					if (shouldDisplayDailyQuests) then container:AddChild(CreateDummyFrame()) end
				end
			end
			if (not quest.isWeekly) then
				if (shouldDisplayDailyQuests) then
					questEntry = createAvailableQuestLogItemEntry(quest.getName(quest.id), quest.getQuestTag(quest.id), quest.isWeekly)
					container:AddChild(questEntry)
				end
			end
		end
	end

	container:AddChild(CreateDummyFrame())
end

--- Draws the graphical elements to display the currencies, given a known character name
---@param container AceGUIWidget
---@param characterName string name of the character to render quests for
function RackensTracker:DrawCurrencies(container, characterName)
	if (not ContainsIf(self.db.global.options.shownCurrencies, function(currencyTypeEnabled) return currencyTypeEnabled end) or not self.db.global.options.showCurrencies) then
		return
	end

	local labelHeight = 20
	local relWidthPerCurrency = 0.25 -- Use a quarter of the container space per item, making new rows as fit.

	local characterCurrencies = self.db.global.realms[self.currentRealm].characters[characterName].currencies

	container:AddChild(CreateDummyFrame())

	-- Heading 
	local currenciesHeading = AceGUI:Create("Heading")
	currenciesHeading:SetText(L["currencies"])
	currenciesHeading:SetFullWidth(true)
	container:AddChild(currenciesHeading)

	container:AddChild(CreateDummyFrame())

	local currenciesGroup = AceGUI:Create("SimpleGroup")
	currenciesGroup:SetLayout("Flow")
	currenciesGroup:SetFullHeight(true)
	currenciesGroup:SetFullWidth(true)

	local currencyDisplayLabel
	local colorizedName, icon, quantity = "", "", 0

	for _, currency in ipairs(RT.Currencies) do
		if (self.db.global.options.shownCurrencies[tostring(currency.id)]) then

			currencyDisplayLabel = AceGUI:Create("Label")
			currencyDisplayLabel:SetHeight(labelHeight)	
			currencyDisplayLabel:SetRelativeWidth(relWidthPerCurrency) -- Make each currency take up equal space and give each an extra 10%

			colorizedName = currency:GetColorizedName()
			icon = currency:GetIcon(12) --iconSize set to 12

			-- If this character has this currency, that means we have quantity information.
			if (characterCurrencies[currency.id]) then
				quantity = characterCurrencies[currency.id].quantity
			else
				-- The selected character doesnt have any quantity for the currency.
				quantity = 0
			end

			if (quantity == 0) then
				local disabledAmount = RT.Util:FormatColor(GRAY_FONT_COLOR_CODE, quantity)
				currencyDisplayLabel:SetText(string.format("%s\n%s %s", colorizedName, icon, disabledAmount))
			else
				currencyDisplayLabel:SetText(string.format("%s\n%s %s", colorizedName, icon, quantity))
			end

			currenciesGroup:AddChild(currencyDisplayLabel)
		end
	end

	container:AddChild(currenciesGroup)
end

--- Returns the texture used to display the weekly or daily dungeon reset, together with the time remaining.
---@param isRaid boolean
---@return string atlasMarkup
function RackensTracker:GetLockoutTimeWithIcon(isRaid)

	-- https://www.wowhead.com/wotlk/icon=134238/inv-misc-key-04
	local raidAtlas = "Raid"
	-- https://www.wowhead.com/wotlk/icon=134237/inv-misc-key-03
	local dungeonAtlas = "Dungeon"
	local atlasSize = 16
	local iconMarkup = ""
	if (isRaid and self.db.global.realms[self.currentRealm].secondsToWeeklyReset) then
		iconMarkup = CreateAtlasMarkup(raidAtlas, atlasSize, atlasSize)
		--return string.format("%s %s: %s", iconMarkup, L["raidLockExpiresIn"], SecondsToTime(self.db.global.realms[self.currentRealm].secondsToWeeklyReset, true, nil, 3))
		return string.format("%s %s: %s", iconMarkup, L["raidLockExpiresIn"], timeFormatter:Format(self.db.global.realms[self.currentRealm].secondsToWeeklyReset))
	end
	if (isRaid == false and self.db.global.realms[self.currentRealm].secondsToDailyReset) then
		iconMarkup = CreateAtlasMarkup(dungeonAtlas, atlasSize, atlasSize)
		return string.format("%s %s: %s", iconMarkup, L["dungeonLockExpiresIn"], timeFormatter:Format(self.db.global.realms[self.currentRealm].secondsToDailyReset))
	end
	return ""
end

--- Draws the graphical elements to display the saved instances, given a known character name
---@param container AceGUIWidget
---@param characterName string name of the character to render quests for
function RackensTracker:DrawSavedInstances(container, characterName)

	-- Refresh the currently known daily and weekly reset timers
	RackensTracker:UpdateWeeklyDailyResetTime()

	local characterHasLockouts, raidInstances, dungeonInstances, lockoutInformation = self:RetrieveSavedInstanceInformation(characterName)
	local nRaids, nDungeons = #raidInstances.sorted, #dungeonInstances.sorted

	-- Heading 
	local lockoutsHeading = AceGUI:Create("Heading")
	lockoutsHeading:SetFullWidth(true)
	-- Return after creation of the heading stating no lockouts were found.
	if (characterHasLockouts == false) then
		lockoutsHeading:SetText(L["noLockouts"])
	else
		lockoutsHeading:SetText(L["lockouts"])
	end

	container:AddChild(lockoutsHeading)

	-- Empty Row
	container:AddChild(CreateDummyFrame())

	-- Display weekly raid reset time	
	local raidResetTimeIconLabel = AceGUI:Create("Label")
	local weeklyLockoutWithIcon = RackensTracker:GetLockoutTimeWithIcon(true)
	raidResetTimeIconLabel:SetText(weeklyLockoutWithIcon)
	raidResetTimeIconLabel:SetFullWidth(true)
	container:AddChild(raidResetTimeIconLabel)

	-- Display dungeon daily reset time
	local dungeonResetTimeIconLabel = AceGUI:Create("Label")
	local dungeonLockoutWithIcon = RackensTracker:GetLockoutTimeWithIcon(false)
	dungeonResetTimeIconLabel:SetText(dungeonLockoutWithIcon)
	dungeonResetTimeIconLabel:SetFullWidth(true)
	container:AddChild(dungeonResetTimeIconLabel)

	if (characterHasLockouts == false) then
		return
	end

	-- Empty Row
	container:AddChild(CreateDummyFrame())

	local lockoutsGroup = AceGUI:Create("SimpleGroup")
	lockoutsGroup:SetLayout("Flow")
	lockoutsGroup:SetFullWidth(true)


	local raidGroup = AceGUI:Create("InlineGroup")
	raidGroup:SetLayout("List")
	raidGroup:SetTitle(L["raids"])
	raidGroup:SetFullHeight(true)
	raidGroup:SetRelativeWidth(0.50) -- Half of the parent

	local dungeonGroup = AceGUI:Create("InlineGroup")
	dungeonGroup:SetLayout("List")
	dungeonGroup:SetTitle(L["dungeons"])
	dungeonGroup:SetFullHeight(true)
	dungeonGroup:SetRelativeWidth(0.50) -- Half of the parent

	-- Fill in the raids inside raidGroup.
	-- There is a wierd problem where the containers raidGroup and dungeonGroup are not anchored to the top of the parent container.
	-- This makes for an awkard layout where one of raidGroup or dungeonGroup is taller than the other one as they dont fill out the height even with :SetFullHeight(true)
	-- but rather fills its height by content, this is an ugly hack to fill dummy frames into either raidGroup or dungeonGroup to match the number of rows, thus making their heights equal :/
	local nDummyFramesNeeded = math.max(nRaids, nDungeons)
	local hasMoreRaidsThanDungeons = nRaids > nDungeons
	local hasEqualRaidsAndDungeons = nRaids == nDungeons

	local instanceNameLabel, instanceProgressLabel, instanceColorizedName = nil, nil, nil
	local labelHeight = 20
	local lockoutInfo = {}
	for _, instance in ipairs(raidInstances.sorted) do
		lockoutInfo = lockoutInformation[instance.id]
		instanceNameLabel = AceGUI:Create("Label")
		instanceColorizedName = RT.Util:FormatColor(NORMAL_FONT_COLOR_CODE, "%s", instance.id)
		instanceNameLabel:SetText(instanceColorizedName)
		instanceNameLabel:SetFullWidth(true)
		instanceNameLabel:SetHeight(labelHeight)
		raidGroup:AddChild(instanceNameLabel)
		instanceProgressLabel = AceGUI:Create("Label")
		instanceProgressLabel:SetText(string.format("%s%s: %s", CreateAtlasMarkup("DungeonSkull", 12, 12), L["progress"], lockoutInfo.progress))
		instanceProgressLabel:SetFullWidth(true)
		instanceProgressLabel:SetHeight(labelHeight)
		raidGroup:AddChild(instanceProgressLabel)
	end

	if (not hasEqualRaidsAndDungeons) then
		if (hasMoreRaidsThanDungeons == false) then
			for i = 1, nDummyFramesNeeded - nRaids do
				raidGroup:AddChild(CreateDummyFrame())
				raidGroup:AddChild(CreateDummyFrame())
			end
		end
	end

	-- Fill in the character for this tab's dungeon lockouts
	for _, instance in ipairs(dungeonInstances.sorted) do
		lockoutInfo = lockoutInformation[instance.id]
		instanceNameLabel = AceGUI:Create("Label")
		instanceColorizedName = RT.Util:FormatColor(NORMAL_FONT_COLOR_CODE, "%s", instance.id)
		instanceNameLabel:SetText(instanceColorizedName)
		instanceNameLabel:SetFullWidth(true)
		instanceNameLabel:SetHeight(labelHeight)
		dungeonGroup:AddChild(instanceNameLabel)
		instanceProgressLabel = AceGUI:Create("Label")
		instanceProgressLabel:SetText(string.format("%s%s: %s", CreateAtlasMarkup("DungeonSkull", 12, 12), L["progress"], lockoutInfo.progress))
		instanceProgressLabel:SetFullWidth(true)
		instanceProgressLabel:SetHeight(labelHeight)
		dungeonGroup:AddChild(instanceProgressLabel)
	end

	if (not hasEqualRaidsAndDungeons) then
		if (hasMoreRaidsThanDungeons) then
			for i = 1, nDummyFramesNeeded - nDungeons do
				dungeonGroup:AddChild(CreateDummyFrame())
				dungeonGroup:AddChild(CreateDummyFrame())
			end
		end
	end

	-- If these arent added AFTER all the child objects have been added, the anchor points and positioning gets all screwed up : (
	lockoutsGroup:AddChild(raidGroup)
	lockoutsGroup:AddChild(dungeonGroup)
	container:AddChild(lockoutsGroup)
end

--- Callback that runs when the user selects a character tab in the main tracker frame
---@param container AceGUIWidget
---@param event string
---@param characterName string
local function SelectCharacterTab(container, event, characterName)
	container:ReleaseChildren()
	RackensTracker:DrawQuests(container, characterName)
	RackensTracker:DrawSavedInstances(container, characterName)
	RackensTracker:DrawCurrencies(container, characterName)
end

--- Closes the tracker frame
function RackensTracker:CloseTrackerFrame()
	AceGUI:Release(self.tracker_frame)
	self.tracker_frame = nil
	self.tracker_tabs = nil
end

--- Opens the setting panel for the AddOn
function RackensTracker:OpenOptionsFrame()
	if (self.tracker_frame) then
		self:CloseTrackerFrame()
	end
	Settings.OpenToCategory(self.optionsCategory:GetID())
end

--- Toggles visibility of the tracker frame
function RackensTracker:ToggleTrackerFrame()
	if (self.tracker_frame) then
		if (self.tracker_frame:IsVisible()) then
			self:CloseTrackerFrame()
		end
	else
		self:OpenTrackerFrame()
	end
end

--- Creates and renders the tracker frame
function RackensTracker:OpenTrackerFrame()
	-- No need to render and create the user interface again if its already created.
	if (self.tracker_frame and self.tracker_frame:IsVisible()) then
		return
	end

	-- TODO: Figure out why ElvUI is tainting AceGUI making the height calculations all fucked
	-- AND making extra borders / backdrops
	self.tracker_frame = AceGUI:Create("Window")

	-- Make it so pressing Escape closes the tracker window
	_G["RackensTrackerWindowFrame"] = self.tracker_frame.frame

	self.tracker_frame:SetTitle(addOnName)
	self.tracker_frame:SetLayout("Fill")
	self.tracker_frame:SetWidth(650)
	self.tracker_frame:SetHeight(650)

	-- Minimum width and height when resizing the window.
	self.tracker_frame.frame:SetResizeBounds(650, 650)

	self.tracker_frame:SetCallback("OnClose", function(widget)
		-- Clear any local tables containing processed instances and currencies
		AceGUI:Release(widget)
		self.tracker_frame = nil
		self.tracker_tabs = nil
	end)

	-- Create our TabGroup
	self.tracker_tabs = AceGUI:Create("TabGroup")

	-- The frames inside the selected tab are stacked
	self.tracker_tabs:SetLayout("List")
	self.tracker_tabs:SetFullHeight(true)

	-- Setup which tabs to show, one tab per character
	local tabsData = {}
	local tabIconSize = 12
	local tabIcon = ""
	local tabName = ""

	-- TODO: Enable configuration options to include certain characters regardless of their level.
	--		 Currently only create tabs for each level 80 character and if none is found, we display a helpful message.

	local initialCharacterTab = self.currentCharacter.name
	local isInitialCharacterMaxLevel = false

	-- Create one tab per level 80 character 
	for characterName, character in pairs(self.db.global.realms[self.currentRealm].characters) do
		if (character.level == GetMaxPlayerLevel()) then
			if (character.name == initialCharacterTab and character.level == GetMaxPlayerLevel()) then
				isInitialCharacterMaxLevel = true
			end
			tabIcon = GetCharacterIcon(character.class, tabIconSize)
			tabName = RT.Util:FormatColorClass(character.class, character.name)
			table.insert(tabsData, { text=string.format("%s %s", tabIcon, tabName), value=characterName})
		end
	end

	-- Do we have ANY level 80 characters at all?
	local isAnyCharacterMaxLevel = #tabsData > 0
	if (isAnyCharacterMaxLevel) then
		-- Add the TabGroup to the main frame
		self.tracker_frame:AddChild(self.tracker_tabs)

		self.tracker_tabs:SetTabs(tabsData)
		-- Register callbacks on tab selected
		self.tracker_tabs:SetCallback("OnGroupSelected", SelectCharacterTab)

		if (isInitialCharacterMaxLevel) then
			-- Set initial tab to the current character
			self.tracker_tabs:SelectTab(initialCharacterTab)
		else 
			-- If the current character is not level 80, set initial tab to the first available level 80 character 
			self.tracker_tabs:SelectTab(tabsData[1].value)
		end

	else
		local noTrackingInformationGroup = AceGUI:Create("SimpleGroup")
		noTrackingInformationGroup:SetLayout("List")
		noTrackingInformationGroup:SetFullWidth(true)
		noTrackingInformationGroup:SetFullHeight(true)

		noTrackingInformationGroup:AddChild(CreateDummyFrame())

		-- Add a Heading to the main frame with information stating that no tracking information is available, must have logged in to a level 80 character once to enable tracking.
		local noTrackingInformationAvailable = AceGUI:Create("Heading")
		noTrackingInformationAvailable:SetText(L["noTrackingAvailable"])
		noTrackingInformationAvailable:SetFullWidth(true)
		noTrackingInformationGroup:AddChild(noTrackingInformationAvailable)

		noTrackingInformationGroup:AddChild(CreateDummyFrame())

		-- Add a more descriptive label explaining why
		local noTrackingDetailedInformation = AceGUI:Create("Label")
		noTrackingDetailedInformation:SetFullWidth(true)
		noTrackingDetailedInformation:SetText(L["noTrackingAvailableDescription1"])
		noTrackingInformationGroup:AddChild(noTrackingDetailedInformation)

		noTrackingInformationGroup:AddChild(CreateDummyFrame())

		noTrackingDetailedInformation = AceGUI:Create("Label")
		noTrackingDetailedInformation:SetFullWidth(true)
		noTrackingDetailedInformation:SetText(L["noTrackingAvailableDescription2"])
		noTrackingInformationGroup:AddChild(noTrackingDetailedInformation)

		self.tracker_frame:AddChild(noTrackingInformationGroup)
	end
end