local addOnName, RT = ...

local tostring = tostring
---@diagnostic disable-next-line: undefined-global
local IsOnQuest, IsQuestComplete, GetQuestsCompleted = C_QuestLog.IsOnQuest, IsQuestComplete, GetQuestsCompleted
local GetSecondsUntilWeeklyReset = C_DateAndTime.GetSecondsUntilWeeklyReset
local GetSecondsUntilDailyReset  = C_DateAndTime.GetSecondsUntilDailyReset
local GetServerTime = GetServerTime
local C_Timer = C_Timer

local addon = LibStub("AceAddon-3.0"):GetAddon(addOnName) --[[@as RackensTracker]]

---@class QuestModule: AceModule, AceConsole-3.0, AceEvent-3.0, AddonModulePrototype
local QuestModule = addon:NewModule("Quests", "AceEvent-3.0")
addon:DisableModule("Quests")

local function Log(message, ...)
	if (addon.LOGGING_ENABLED) then
    	QuestModule:DebugLog(message, ...)
	end
end

--- Iterates over all known characters for the current realm and checks each of the character's quests to see if
--- they have reset. If they have, they are removed from the tracker, also flags quests picked up from a previous reset with an hasExpired flag.
function QuestModule:ResetTrackedQuestsIfNecessary()
    --Log("Running ResetExpiredQuests!")
    for characterName, character in pairs(addon.db.global.realms[addon.currentRealm].characters) do
		for questID, quest in pairs(character.quests) do
			if (quest.acceptedAt + quest.secondsToReset < GetServerTime()) then
				Log("Found tracked quest that expired in a previous reset for: " .. characterName)
				local timeNow = GetServerTime()
				Log("Current server time: " .. timeNow)
				Log("Tracked quest set to expire at server time: " .. quest.acceptedAt + quest.secondsToReset)
				Log("Tracked quest expired: " .. RT.TimeUtil.TimeFormatter:Format(timeNow - (quest.acceptedAt + quest.secondsToReset)) .. " ago")
				Log("At the time of accepting the quest there was: " .. RT.TimeUtil.TimeFormatter:Format(quest.secondsToReset) .. " left until reset")
				-- Found a tracked weekly or daily quest that has expired past the weekly reset time
				-- It is now stale and a new one should be picked up by the player.
				-- Stop tracking quests that are past its current reset date
				-- There is an edge case where the player can hold on to a completed but not turned in quest so dont delete that one
				-- If they turn it in past the "deadline" it counts as completed for that lockout period anyway.
				if (quest.isCompleted and quest.isTurnedIn) then
					Log("Expired quest is completed and turned in, now removing quest with questID: " .. quest.id .. " name: " .. quest.name .. " from the tracker database")
					addon.db.global.realms[addon.currentRealm].characters[characterName].quests[questID] = nil
				end

				-- If the player has an in progress quest that belongs to an older daily or weekly reset then just flag it
				-- This will show up in the UI with a warning triangle and a message so they know they are on a quest belonging to an older reset.
				if (not quest.isCompleted and not quest.isTurnedIn) then
					Log("Expired quest is NOT completed and NOT turned in, flagging quest with a user warning for questID: " .. quest.id .. " name: " .. quest.name .. " in the tracker database")
					addon.db.global.realms[addon.currentRealm].characters[characterName].quests[questID].hasExpired = true
				end
			end
		end
	end
end

--- Iterate over all tracked quests for the current character and if there is a mismatch between the database and the quest's completion state, update the database.
function QuestModule:UpdateQuestCompletionIfNecessary()
    --Log("Running UpdateQuestCompletionIfNecessary!")
	for questID, trackedQuest in pairs(addon.currentCharacter.quests) do
		if (IsOnQuest(trackedQuest.id) and IsQuestComplete(trackedQuest.id)) then
			if (trackedQuest.isCompleted == false) then
				Log("Found a tracked quest that was completed but lacked that information in the database, questID: " .. trackedQuest.id .. " and name: " .. trackedQuest.name)
				addon.currentCharacter.quests[questID].isCompleted = true
			end
		end
	end
end

--- Adds quests to the database if they are found in the current character's quest log and they do not exist in the database
function QuestModule:CreateActiveMissingQuests()
    --Log("Running CreateActiveMissingQuests!")
	for questID, trackableQuest in pairs(RT.Quests) do
		-- If the current player is already on a trackable quest but they dont have it tracked that means they 
		-- accepted it before they used this addon or had it disabled during a time in which they
		-- accepted the quest.

		-- We can not make any assumptions on the internal secondsToReset or acceptedAt timestamps
		-- but we should be able to handle this tracked quest object like any other created by our event handlers anyway
		-- This does mean however that the quest might be removed from the tracker after completion and turn in
		-- as the code that checks if we are past the weekly or daily reset assumes these timestamps exist.
		-- It is a small price to pay to be more inclusive.
		if (IsOnQuest(questID) and not addon.currentCharacter.quests[questID]) then
			---@type DbQuest
			local newTrackedQuest = {
				id = questID,
				name = trackableQuest.getName(questID),
				questTag = trackableQuest.getQuestTag(questID),
				faction = trackableQuest.faction,
				isWeekly = trackableQuest.isWeekly,
				 -- Assume it was just picked up, we cant know anyway
				acceptedAt = GetServerTime(),
				-- Assume its for the current reset
				-- if the player somehow kept an old quest and didnt complete it or did complete it but not turned it in then it will be cleared 
				-- by the tracker at the next available daily or weekly reset.
				-- TODO: This might cause bug reports, so maybe take a second look at this at some point.
				secondsToReset = trackableQuest.isWeekly and GetSecondsUntilWeeklyReset() or GetSecondsUntilDailyReset(),
				isCompleted = IsQuestComplete(questID),
				isTurnedIn = false,
				craftedFromExistingQuest = true -- Just there to differentiate between quest handled fully by our addon.		
			}

			addon.currentCharacter.quests[questID] = newTrackedQuest

			Log("Trackable active quest found in quest log but not in the database, adding it to the tracker..")
			Log("Found new trackable quest, questID: " .. newTrackedQuest.id .. " questTag: " .. newTrackedQuest.questTag .. " and name: " .. newTrackedQuest.name)
		end
	end
end

--- Attempts to find the current weekly quest for the active reset by looking at all other characters except the current one in the database.
---@return DbQuest|nil
function QuestModule:TryToFindCurrentWeeklyQuest()
    --Log("Running TryToFindCurrentWeeklyQuest!")
	for characterName, character in pairs(addon.db.global.realms[addon.currentRealm].characters) do
		if (characterName ~= addon.currentCharacter.name) then
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
function QuestModule:TryGetCurrentFinishedWeeklyQuest()
	for _, quest in pairs(addon.currentCharacter.quests) do
		if (quest.isWeekly and quest.isCompleted and quest.isTurnedIn) then
			if (quest.acceptedAt + quest.secondsToReset > GetServerTime()) then
				return quest
			end
		end
	end
	return nil
end

--- Adds completed and turned in quests for the current character if they do not exist the database.
--- For weekly quests this will use a heuristic process as completing one weekly raid quest means you "completed" all the others in that pool of quests.
function QuestModule:CreateFinishedMissingQuests()
    -- This is a collection of all quests the current character has completed in its lifetime.
    -- Daily quests appear completed only if they have been completed that day.
    -- Weekly quests appear completed only if they have been completed that week.
    --Log("Running CreateFinishedMissingQuests!")
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
                if (not addon.currentCharacter.quests[questID]) then
                    newTrackedQuest = {
                        id = questID,
                        name = trackableQuest.getName(questID),
                        questTag = trackableQuest.getQuestTag(questID),
                        faction = trackableQuest.faction,
                        isWeekly = false,
                        -- Assume it was just turned in, we cant know anyway
                        acceptedAt = GetServerTime(),
                        -- We know it's for the current reset
                        secondsToReset = GetSecondsUntilDailyReset(),
                        isCompleted = true,
                        isTurnedIn = true,
                        craftedFromExistingQuest = true,
                    }

                    addon.currentCharacter.quests[questID] = newTrackedQuest

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
                        if (currentWeeklyQuest.faction == nil or (currentWeeklyQuest.faction and currentWeeklyQuest.faction == addon.currentCharacter.faction)) then
                            -- Possibly found a better match for the current weekly quest, so we must delete the current one in the database
                            if currentCharacterFinishedWeeklyQuest then addon.currentCharacter.quests[currentCharacterFinishedWeeklyQuest.id] = nil end
                            if (not addon.currentCharacter.quests[currentWeeklyQuest.id]) then

                                newTrackedQuest = {
                                    id = currentWeeklyQuest.id,
                                    name = currentWeeklyQuest.name,
                                    questTag = currentWeeklyQuest.questTag,
                                    faction = currentWeeklyQuest.faction,
                                    isWeekly = true,
                                    -- Assume it was just turned in, we cant know anyway
                                    acceptedAt = GetServerTime(),
                                    -- We know it's for the current reset
                                    secondsToReset = GetSecondsUntilWeeklyReset(),
                                    isCompleted = true,
                                    isTurnedIn = true,
                                    -- This quest is guaranteed to belong to another character's tracked quests but it could either be for the active reset or come from 
                                    -- another reset therefore its crafted from an existing quest from another character.
                                    craftedFromExistingQuest = true
                                }

                                addon.currentCharacter.quests[currentWeeklyQuest.id] = newTrackedQuest

                                Log("Trackable completed and turned in weekly quest found but not found in the database, adding it to the tracker..")
                                Log("Heuristics found current active weekly quest with questID: " .. questID .. " name: " .. newTrackedQuest.name)
                                -- TODO: Maybe optimize this to set a field in the currentCharacter such as hasCompletedRaidWeekly
                                -- this must be unflagged though when the weekly reset happens which could be a source for more bugs, so the tradeoff is more computing, less flags
                                currentCharacterFinishedWeeklyQuest = self:TryGetCurrentFinishedWeeklyQuest()
                            end
                        end
                    else
                        if (trackableQuest.faction == nil or (trackableQuest.faction and trackableQuest.faction == addon.currentCharacter.faction)) then
                            if (not addon.currentCharacter.quests[questID]) then
                                newTrackedQuest = {
                                    id = questID,
                                    name = trackableQuest.getName(questID),
                                    questTag = trackableQuest.getQuestTag(questID),
                                    faction = trackableQuest.faction,
                                    isWeekly = true,
                                    -- Assume it was just turned in, we cant know anyway
                                    acceptedAt = GetServerTime(),
                                    -- We know it's for the current reset
                                    secondsToReset = GetSecondsUntilWeeklyReset(),
                                    isCompleted = true,
                                    isTurnedIn = true,
                                    craftedFromHeuristicGuess = true,
                                }

                                addon.currentCharacter.quests[questID] = newTrackedQuest
                                -- TODO: Maybe optimize this to set a field in the currentCharacter such as hasCompletedRaidWeekly
                                -- this must be unflagged though when the weekly reset happens which could be a source for more bugs, so the tradeoff is more computing, less flags
                                currentCharacterFinishedWeeklyQuest = self:TryGetCurrentFinishedWeeklyQuest()
                                Log("Trackable completed and turned in weekly quest found but not found in the database, adding it to the tracker..")
                                Log("Heuristics could not find the current active weekly quest, guessing its questID: " .. questID .. " name: " .. newTrackedQuest.name .. " questTag: " .. newTrackedQuest.questTag)
                            end
                        end
                    end
                end
            end
        end
    end
end


function QuestModule:OnInitialize()
	Log("Initializing")
    -- Reset any character's weekly or daily quests if it meets the criteria to do so
    --self:ResetTrackedQuestsIfNecessary()
end

function QuestModule:OnEnable()
    self:UpdateQuestCompletionIfNecessary()
    self:CreateActiveMissingQuests()
    -- Delay this by 1.5 seconds or so because the queried information from the functions C_QuestLog.GetQuestInfo and GetQuestTagInfo
    -- can return empty values while logging in : /
    C_Timer.After(1.5, function() self:CreateFinishedMissingQuests() end)

    -- Daily - Weekly quest related events
	self:RegisterEvent("QUEST_ACCEPTED", "OnEventQuestAccepted")
	self:RegisterEvent("QUEST_REMOVED", "OnEventQuestRemoved")
	self:RegisterEvent("QUEST_TURNED_IN", "OnEventQuestTurnedIn")
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED", "OnEventUnitQuestLogChanged")
	self:RegisterEvent("QUEST_LOG_CRITERIA_UPDATE", "OnEventQuestLogCriteriaUpdate")
end

--- Called when a quest is accepted.
--- Inserts the newly accepted quest into the database for the current character
---@param event string QUEST_ACCEPTED
---@param questLogIndex number
---@param questID number
function QuestModule:OnEventQuestAccepted(event, questLogIndex, questID)
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
		if (trackableQuest.faction == nil or (trackableQuest.faction and trackableQuest.faction == addon.currentCharacter.faction) and trackableQuest.prerequesite(addon.currentCharacter.level)) then
			newTrackedQuest.name = trackableQuest.getName(questID)
			newTrackedQuest.questTag = trackableQuest.getQuestTag(questID)
			newTrackedQuest.faction = trackableQuest.faction
			newTrackedQuest.isWeekly = trackableQuest.isWeekly
			newTrackedQuest.acceptedAt = GetServerTime()
			if (trackableQuest.isWeekly) then
				newTrackedQuest.secondsToReset = GetSecondsUntilWeeklyReset()
			else
				newTrackedQuest.secondsToReset = GetSecondsUntilDailyReset()
			end

			Log("Found new trackable quest, is faction specific: " .. tostring(trackableQuest.faction) .. " questID: " .. newTrackedQuest.id .. " questTag: " .. newTrackedQuest.questTag .. " and name: " .. newTrackedQuest.name)
			addon.currentCharacter.quests[questID] = newTrackedQuest
		end
	end
end

--- Called when a player has turned in a quest or when they removed it manually from their quest log. Removes the quest from the database for the current character
---@param event string QUEST_REMOVED
---@param questID number
function QuestModule:OnEventQuestRemoved(event, questID)
	Log("OnEventQuestRemoved")

	local trackableQuest = RT.Quests[questID]
	local trackedQuest = addon.currentCharacter.quests[questID]
	if (trackableQuest) then
		-- NOTE: Only remove the tracked quest if it's not being turned in because OnEventQuestTurnedIn is called BEFORE this event handler is executed.
		-- Only remove the quest from the table of tracked quests for this player if they manually remove the quest from their quest log.
		if (trackedQuest and trackedQuest.isTurnedIn == false) then
			Log("Removed tracked quest, isWeekly: " .. tostring(trackedQuest.isWeekly) .. " questID: " .. trackedQuest.id .. " and name: " .. trackedQuest.name)
			addon.currentCharacter.quests[questID] = nil
		end
	end
end

--- Called when the player has turned in a quest from their quest log. Marks the quest as turned in, in the database
---@param event string QUEST_TURNED_IN
---@param questID number
function QuestModule:OnEventQuestTurnedIn(event, questID)
	Log("OnEventQuestTurnedIn")

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
			secondsToReset = trackableQuest.isWeekly and GetSecondsUntilWeeklyReset() or GetSecondsUntilDailyReset(),
			isCompleted = true,
			isTurnedIn = true
		}

		addon.currentCharacter.quests[questID] = trackedQuest
		Log("Tracked quest belongs to the active reset, set to expire at server time: " .. trackedQuest.acceptedAt + trackedQuest.secondsToReset)
		Log("Tracked quest will expire in: " .. RT.TimeUtil.TimeFormatter:Format(trackedQuest.secondsToReset))
	end
end

--- Called when the player's quest log changed, this happens frequently when interacting with quests. Will mark quests as completed when the player completes the quest's objectives
---@param event string UNIT_QUEST_LOG_CHANGED
---@param unitTarget string
function QuestModule:OnEventUnitQuestLogChanged(event, unitTarget)
	if (unitTarget == "player") then
		Log("OnEventUnitQuestLogChanged")

		for questID, trackedQuest in pairs(addon.currentCharacter.quests) do
			if (IsOnQuest(trackedQuest.id) and IsQuestComplete(trackedQuest.id)) then
				if (trackedQuest.isCompleted == false) then
					Log("Completed tracked quest, isWeekly: " .. tostring(trackedQuest.isWeekly) .. " questID: " .. trackedQuest.id .. " and name: " .. trackedQuest.name)
					addon.currentCharacter.quests[questID].isCompleted = true
				end
			end
		end
	end
end

--- Called when a quest objective is updated for the player. Will mark quests as completed when the player completes the quest's objectives
---@param event string QUEST_LOG_CRITERIA_UPDATE
---@param questID number
---@param specificTreeID number
---@param description string
---@param numFulfilled number
---@param numRequired number
function QuestModule:OnEventQuestLogCriteriaUpdate(event, questID, specificTreeID, description, numFulfilled, numRequired)
	Log("OnEventQuestLogCriteriaUpdate")
	--Log("specificTreeID: " .. tostring(specificTreeID) .. " description: " .. description .. " numFulfilled: " .. tostring(numFulfilled) .. " numRequired: " .. tostring(numRequired))

	local trackedQuest = addon.currentCharacter.quests[questID]
	if (trackedQuest) then
		if (IsOnQuest(trackedQuest.id) and IsQuestComplete(trackedQuest.id)) then
			if (trackedQuest.isCompleted == false) then
				Log("Completed tracked quest, isWeekly: " .. tostring(trackedQuest.isWeekly) .. " questID: " .. trackedQuest.id .. " and name: " .. trackedQuest.name)
				addon.currentCharacter.quests[questID].isCompleted = true
			end
        end
	end
end