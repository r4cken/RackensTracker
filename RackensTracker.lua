local addOnName, RT = ...

local table, math, type, string, pairs, ipairs =
	  table, math, type, string, pairs, ipairs

local GetServerTime, SecondsToTime, C_DateAndTime =
	  GetServerTime, SecondsToTime, C_DateAndTime

local RequestRaidInfo, GetDifficultyInfo, GetNumSavedInstances, GetSavedInstanceInfo =
	  RequestRaidInfo, GetDifficultyInfo, GetNumSavedInstances, GetSavedInstanceInfo

local C_CurrencyInfo =
	  C_CurrencyInfo

local UnitName, UnitClassBase, UnitLevel, GetClassAtlas, CreateAtlasMarkup =
	  UnitName, UnitClassBase, UnitLevel, GetClassAtlas, CreateAtlasMarkup

local NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE =
	  NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE

local Settings, CreateSettingsListSectionHeaderInitializer =
	  Settings, CreateSettingsListSectionHeaderInitializer

local DAILY_QUEST_TAG_TEMPLATE = DAILY_QUEST_TAG_TEMPLATE

local C_QuestLog, IsQuestComplete =
	  C_QuestLog, IsQuestComplete

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
		}
	},
	char = {
		minimap = {
			hide = false
		}
	},
	realm = {
		weeklyResetTime = nil,
		secondsToWeeklyReset = nil,
		dailyResetTime = nil,
		secondsToDailyReset = nil,
		characters = {
			--Indexed by characterName
			--[[
				["realmname.character"] = {
					name = "Racken",
					class = "ROGUE",
					realm = Earthshaker
					savedInstances = {
						-- instanceID is made up by instanceName + difficultyName
						[instanceID] = {
							["instanceName"] = instanceName,
							["instanceID"] = instanceID,
							["lockoutID"] = lockoutID,
							["resetTime"] = GetServerTime() + resetsAt,
							["isLocked"] = isLocked,
							["isRaid"] = isRaid,
							["isHeroic"] = isHeroic,
							["maxPlayers"] = maxPlayers,
							["difficultyID"] = difficultyID,
							["difficultyName"] = difficultyName,
							["encountersTotal"] = numEncounters,
							["encounterCompleted"] = encounterProgress,
						}
					},
					currencies = {
						[currencyID] = {
							[currencyID] = currencyID,
							[name] = currency.name,
							[description] = currency.description or "",
							[quantity] = currency.quantity,
							[maxQuantity] = currency.maxQuantity,
							[quality] = currency.quality,
							[iconFileID] = currency.iconFileID,
							[discovered] = currency.discovered
						}
					}
				}
			--]]
			['*'] = {
				name = nil,
				class = nil,
				level = nil,
				realm = nil,
				savedInstances = {},
				currencies = {},
				quests = {
					--[[
						[questID] = {
							id = questID,
							name = string,
							questTag = string,
							isWeekly = boolean
							acceptedAt = number
							secondsToReset = number
							isCompleted = boolean
							isTurnedIn = boolean
							hasExpired = boolean
						}
					--]]
				},
			}
		}
	}
}

local function SlashCmdLog(message, ...)
	RackensTracker:Printf(message, ...)
end

local function Log(message, ...)
	if (LOGGING_ENABLED) then
    	RackensTracker:Printf(message, ...)
	end
end

local function GetCharacterDatabaseID()
	local name = UnitName("player")
	return name
end


local function GetCharacterClass()
    local classFilename, _ = UnitClassBase("player")
    return classFilename
end

local function GetCharacterIcon(class, iconSize)
	local textureAtlas = GetClassAtlas(class)
	local icon = CreateAtlasMarkup(textureAtlas, iconSize, iconSize)
	return icon
end

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


function RackensTracker:UpdateCharacterLockouts()
	local savedInstances = GetCharacterLockouts()

	self.currentCharacter.savedInstances = savedInstances
end


function RackensTracker:UpdateCharacterCurrencies()
	local currencies = GetCharacterCurrencies()

	self.currentCharacter.currencies = currencies
end

function RackensTracker:UpdateCharacterLevel(newLevel)
	self.currentCharacter.level = newLevel
end

function RackensTracker:RetrieveSavedInstanceInformation(characterName)
	local lockoutInformation = {}
	local raidInstances = RT.Container:New()
	local dungeonInstances = RT.Container:New()

	local character = self.db.realm.characters[characterName]
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


function RackensTracker:ResetTrackedQuestsIfNecessary()
	for characterName, character in pairs(self.db.realm.characters) do
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
					self.db.realm.characters[characterName].quests[questID] = nil
				end

				-- If the player has an in progress quest that belongs to an older daily or weekly reset then just flag it
				-- This will show up in the UI with a warning triangle and a message so they know they are on a quest belonging to an older reset.
				if (not quest.isCompleted and not quest.isTurnedIn) then
					Log("Expired quest is NOT completed and NOT turned in, flagging quest with a user warning for questID: " .. quest.id .. " name: " .. quest.name .. " in the tracker database")
					self.db.realm.characters[characterName].quests[questID].hasExpired = true
				end
			end
		end
	end
end

function RackensTracker:ResetTrackedInstancesIfNecessary()
	for characterName, character in pairs(self.db.realm.characters) do
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

				self.db.realm.characters[characterName].savedInstances[id] = nil
			end
		end
	end
end


function RackensTracker:UpdateWeeklyDailyResetTime()
	-- Update to get the absolute latest timers
	self.db.realm.secondsToWeeklyReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
	self.db.realm.secondsToDailyReset  = C_DateAndTime.GetSecondsUntilDailyReset()
	self.db.realm.weeklyResetTime = GetServerTime() + self.db.realm.secondsToWeeklyReset
	self.db.realm.dailyResetTime = GetServerTime() + self.db.realm.secondsToDailyReset
end

function RackensTracker:CreateExistingButNotTrackedQuest()
	for questID, trackableQuest in pairs(RT.Quests) do
		-- If the current player is already on a trackable quest but they dont have it tracked that means they 
		-- accepted it before they used this addon or had it disabled during a time in which they
		-- accepted the quest.
		
		-- We can not make any assumptions on the internal secondsToReset or acceptedAt timestamps
		-- but we should be able to handle this tracked quest object like any other created by our event handlers anyway
		-- This does mean however that the quest might be removed from the tracker after completion and turn in
		-- as the code that checks if we are past the weekly or daily reset assumes these timestamps exist.
		-- It is a small price to pay to be more inclusive.
		if (C_QuestLog.IsOnQuest(trackableQuest.id) and not self.currentCharacter.quests[trackableQuest.id]) then
			local newTrackedQuest = {
				id = trackableQuest.id,
				name = trackableQuest.getName(trackableQuest.id),
				questTag = trackableQuest.getQuestTag(trackableQuest.id),
				isWeekly = trackableQuest.isWeekly,
				 -- Assume it was just picked up, we cant know anyway
				acceptedAt = GetServerTime(),
				-- Assume its for the current reset
				-- if the player somehow kept an old quest and didnt complete it or did complete it but not turned it in then it will be cleared 
				-- by the tracker at the next available daily or weekly reset.
				-- TODO: This might cause bug reports, so maybe take a second look at this at some point.
				secondsToReset = trackableQuest.isWeekly and C_DateAndTime.GetSecondsUntilWeeklyReset() or C_DateAndTime.GetSecondsUntilDailyReset(),
				isCompleted = IsQuestComplete(trackableQuest.id),
				isTurnedIn = false,
				craftedFromExistingQuest = true -- Just there to differentiate between quest handled fully by our addon.
			}
			
			self.currentCharacter.quests[trackableQuest.id] = newTrackedQuest

			Log("Trackable active quest found in quest log but not in the database, adding it to the tracker..")
			Log("Found new trackable quest, questID: " .. newTrackedQuest.id .. " questTag: " .. newTrackedQuest.questTag .. " and name: " .. newTrackedQuest.name)
		end
	end
end


function RackensTracker:OnInitialize()
	-- Called when the addon is Initialized
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

	-- Check for
	local function OnCurrencySettingChanged(_, setting, value)
		local variable = setting:GetVariable()
		self.db.global.options.shownCurrencies[variable] = value
	end

	-- Register the Options menu
	self.optionsCategory, self.optionsLayout = Settings.RegisterVerticalLayoutCategory("RackensTracker")
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Tracked Currencies")) -- Todo: AceLocale

	local showHideCurrencyTooltip = "If checked this currency will be displayed in the tracker window."
	for _, currency in ipairs(RT.Currencies) do
		local variable = tostring(currency.id)
		local name = currency:GetName()
		 -- Look at our database_defaults for a default value.
		local defaultValue = database_defaults.global.options.shownCurrencies[variable]
		local setting = Settings.RegisterAddOnSetting(self.optionsCategory, name, variable, type(defaultValue), defaultValue)
		Settings.CreateCheckBox(self.optionsCategory, setting, showHideCurrencyTooltip)
		Settings.SetOnValueChangedCallback(variable, OnCurrencySettingChanged)

		-- The initial value for the checkbox is defaultValue, but we want it to reflect what's in our savedVars, we want to keep the defaultValue what it should be
		-- because when we click the "Default" button and choose "These Settings" we want it to revert to the database default setting.
		setting:SetValue(self.db.global.options.shownCurrencies[variable], true) -- true means force
	end
	
	Settings.RegisterAddOnCategory(self.optionsCategory)

	-- Setup the data broken and the minimap icon
	self.libDataBroker = LibStub("LibDataBroker-1.1", true)
	self.libDBIcon = self.libDataBroker and LibStub("LibDBIcon-1.0", true)
	local minimapBtn = self.libDataBroker:NewDataObject(addOnName, {
		type = "launcher",
		icon = "Interface\\Icons\\Achievement_boss_lichking",
		OnClick = function(_, button)
			if (button == "LeftButton") then
				-- If the window is already created
				self:OpenTrackerFrame()
			end
			if (button == "RightButton") then
				self:OpenOptionsFrame()
			end
		end,
		tocname = addOnName,
		label = addOnName,
		---@type function|GameTooltip
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE.. addOnName .. FONT_COLOR_CODE_CLOSE )
			tooltip:AddLine(GRAY_FONT_COLOR_CODE .. L["minimapLeftClickAction"]  .. ": " .. FONT_COLOR_CODE_CLOSE .. NORMAL_FONT_COLOR_CODE .. L["minimapLeftClickDescription"] .. FONT_COLOR_CODE_CLOSE)
			tooltip:AddLine(GRAY_FONT_COLOR_CODE .. L["minimapRightClickAction"] .. ": " .. FONT_COLOR_CODE_CLOSE .. NORMAL_FONT_COLOR_CODE .. L["minimapRightClickDescription"] .. FONT_COLOR_CODE_CLOSE)
		end,
	})

	if self.libDBIcon then
		self.libDBIcon:Register(addOnName, minimapBtn, self.db.char.minimap)
	end

	tinsert(UISpecialFrames, "RackensTrackerWindowFrame")
end


function RackensTracker:OnEnable()
	-- Called when the addon is enabled

	local characterName = GetCharacterDatabaseID()

	self.currentCharacter = self.db.realm.characters[characterName]
	self.currentCharacter.name = characterName
	self.currentCharacter.class = GetCharacterClass()
	self.currentCharacter.level = UnitLevel("player")
	self.currentCharacter.realm = GetRealmName()
	self.currentCharacter.faction = UnitFactionGroup("player")

	-- Look for any trackable quests in the players quest log that are NOT in the tracked collection
	self:CreateExistingButNotTrackedQuest()

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

function RackensTracker:OnDisable()
	-- Called when the addon is disabled
	self:UnregisterChatCommand("RackensTracker")
end

local function slashCommandUsage()
	SlashCmdLog("\"/rackenstracker open\" opens the tracking window")
	SlashCmdLog("\"/rackenstracker close\" closes the tracking window")
	SlashCmdLog("\"/rackenstracker options\" opens the options window")
	SlashCmdLog("\"/rackenstracker minimap enable\" enables the minimap button")
	SlashCmdLog("\"/rackenstracker minimap disable\" disables the minimap button")
end

function RackensTracker:SlashCommand(msg)
	local command, value, _ = self:GetArgs(msg, 2)

	if (command == nil or command:trim() == "") then
		return slashCommandUsage()
	end

	if (command == "open") then
		self:OpenTrackerFrame()
	elseif (command == "close") then
		self:CloseTrackerFrame()
	elseif (command == "options") then
		self:OpenOptionsFrame()
	elseif (command == "minimap") then
		if (value == "enable") then
			--Log("Enabling the minimap button")
			self.db.char.minimap.hide = false
			--print("curr minimap hide state:" .. tostring(self.db.char.minimap.hide))
			self.libDBIcon:Show(addOnName)
		elseif (value == "disable") then
			--Log("Disabling the minimap button")
			self.db.char.minimap.hide = true
			--print("curr minimap hide state:" .. tostring(self.db.char.minimap.hide))
			self.libDBIcon:Hide(addOnName)
		else
			return slashCommandUsage()
		end
	else
		return slashCommandUsage()
	end
end


function RackensTracker:TriggerUpdateInstanceInfo()
	RequestRaidInfo()
end

function RackensTracker:OnEventBossKill()
    --Log("OnEventBossKill")
    self:TriggerUpdateInstanceInfo()
end

function RackensTracker:OnEventInstanceLockStart()
    --Log("OnEventInstanceLockStart")
    self:TriggerUpdateInstanceInfo()
end

function RackensTracker:OnEventInstanceLockStop()
    --Log("OnEventInstanceLockStop")
    self:TriggerUpdateInstanceInfo()
end

function RackensTracker:OnEventInstanceLockWarning()
    --Log("OnEventInstanceLockWarning")
    self:TriggerUpdateInstanceInfo()
end

function RackensTracker:OnEventUpdateInstanceInfo()
    --Log("OnEventUpdateInstanceInfo")
	self:UpdateCharacterLockouts()
end

function RackensTracker:OnEventCurrencyDisplayUpdate()
	--Log("OnEventCurrencyDisplayUpdate")
	self:UpdateCharacterCurrencies()
end

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

function RackensTracker:OnEventPlayerLevelUp(event, newLevel)
	self:UpdateCharacterLevel(newLevel)
end


function RackensTracker:OnEventQuestAccepted(event, questLogIndex, questID)
	Log("OnEventQuestAccepted")
	--Log("questID: " .. questID)

	local newTrackedQuest = {
		id = questID,
		name = "",
		questTag = "",
		isWeekly = true,
		acceptedAt = 0,
		secondsToReset = 0,
		isCompleted = false,
		isTurnedIn = false,
	}

	-- It's a weekly or daily quest we care to track
	local trackableQuest = RT.Quests[questID]
	if (trackableQuest) then
		if (trackableQuest.faction == nil or (trackableQuest.faction and trackableQuest.faction == self.currentCharacter.faction) and trackableQuest.prerequesite(self.currentCharacter.level)) then
			newTrackedQuest.name = trackableQuest.getName(questID)
			newTrackedQuest.questTag = trackableQuest.getQuestTag(questID)
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

-- Update the current character's completed weekly or daily quest
-- This event fires when the user turns in a quest, whether automatically or
-- by pressing the complete button in a quest dialog.
function RackensTracker:OnEventQuestTurnedIn(event, questID)
	Log("OnEventQuestTurnedIn")
	--Log("questID: " .. tostring(questID))

	local trackedQuest = self.currentCharacter.quests[questID]
	if (trackedQuest) then
		Log("Turned in tracked quest, isWeekly: " .. tostring(trackedQuest.isWeekly) .. " questID: " .. trackedQuest.id .. " and name: " .. trackedQuest.name)
		self.currentCharacter.quests[questID].isTurnedIn = true

		-- Need to check if we turned in an expired quest that was accepted in a previous weekly/daily reset.
		-- This means that we cannot pick up a new one for that week/day as it counts towards the current ACTIVE reset.
		-- We have to update both the acceptedAt and the secondsToReset because it now belongs in the ACTIVE reset.
		-- If we don't do this, the quest will be removed from the tracker as soon as ResetTrackedQuestsIfNecessary
		-- runs as its way way past its expiration because isCompleted and isTurnedIn will be set to true.
		if (trackedQuest.isTurnedIn and trackedQuest.hasExpired) then
			Log("Tracked quest already expired when turned in and was set to expire at server time: " .. trackedQuest.acceptedAt + trackedQuest.secondsToReset)
			Log("Tracked quest had originally expired: " .. timeFormatter:Format(GetServerTime() - (trackedQuest.acceptedAt + trackedQuest.secondsToReset)) .. " ago")
			self.currentCharacter.quests[questID].acceptedAt = GetServerTime()
			if (trackedQuest.isWeekly) then
				self.currentCharacter.quests[questID].secondsToReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
			else
				self.currentCharacter.quests[questID].secondsToReset = C_DateAndTime.GetSecondsUntilDailyReset()
			end

			Log("Tracked quest is now belongs to the active reset, set to expire at new server time: " .. trackedQuest.acceptedAt + trackedQuest.secondsToReset)
			Log("Tracked quest will now expire in: " .. timeFormatter:Format(trackedQuest.secondsToReset))
		end
	end
end

function RackensTracker:OnEventQuestLogCriteriaUpdate(event, questID, specificTreeID, description, numFulfilled, numRequired)
	Log("OnEventQuestLogCriteriaUpdate")
	Log("specificTreeID: " .. tostring(specificTreeID) .. " description: " .. description .. " numFulfilled: " .. tostring(numFulfilled) .. " numRequired: " .. tostring(numRequired))

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

-- Hopefully this will trigger if QUEST_LOG_CRITERIA_UPDATE hasnt been fired.
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


local function CreateDummyFrame()
	local dummyFiller = AceGUI:Create("Label")
	dummyFiller:SetText(" ")
	dummyFiller:SetFullWidth(true)
	dummyFiller:SetHeight(20)
	return dummyFiller
end

local function getQuestIcon(quest)
	local atlasSize = 14
	local textureAtlas = ""
	local availableAtlas = "QuestNormal"
	local availableDailyAtlas = "QuestDaily"
	local completedAtlas = "QuestTurnin"
	local turnedInAtlas = "common-icon-checkmark"
	local expiredAtlas = "services-icon-warning"

	if (quest.isCompleted) then
		textureAtlas = completedAtlas
		if (quest.isTurnedIn) then
			textureAtlas = turnedInAtlas
		end
	else
		if quest.isWeekly then
			textureAtlas = availableAtlas
		else
			textureAtlas = availableDailyAtlas
		end
		if (quest.hasExpired) then
			textureAtlas = expiredAtlas
		end
	end

	local icon = CreateAtlasMarkup(textureAtlas, atlasSize, atlasSize)
	return icon
end

local function createQuestLogItemEntry(quest)
	local questLabel = AceGUI:Create("Label")
	questLabel:SetFullWidth(true)

	local icon = getQuestIcon(quest)
	
	local questTag = ""
	if (quest.isWeekly) then
		questTag = quest.questTag
	else
		questTag = string.format(DAILY_QUEST_TAG_TEMPLATE, quest.questTag)
	end

	-- TODO: AceLocale
	local status = ""
	if (not quest.isCompleted) then
		status = "In progress"
	else
		status = "Completed"
		if (quest.isTurnedIn) then
			status = "Turned in"
		end
	end

	if (quest.hasExpired) then
		status = status .. " (quest accepted from a previous reset)"
	end

	local colorizedText = RT.Util:FormatColor(YELLOW_FONT_COLOR_CODE, "%s (%s) - %s", quest.name, questTag, status)
	local labelText = string.format("%s %s", icon, colorizedText)

	questLabel:SetText(labelText)
	return questLabel
end

function RackensTracker:DrawQuests(container, characterName)
	local quests = self.db.realm.characters[characterName].quests
	local characterHasQuests = RT.Util:Tablelen(quests) > 0
	container:AddChild(CreateDummyFrame())

	local questsHeading = AceGUI:Create("Heading")
	questsHeading:SetFullWidth(true)
	if (characterHasQuests == false) then
		questsHeading:SetText(L["noWeeklyDailyQuests"])
	else
		questsHeading:SetText(L["weeklyDailyQuests"])
	end

	container:AddChild(questsHeading)
	container:AddChild(CreateDummyFrame())

	if (characterHasQuests == false) then
		return
	end

	local weeklyQuest = nil
	local dailyQuest = nil

	for _, quest in pairs(quests) do
		if (quest.isWeekly) then
			weeklyQuest = createQuestLogItemEntry(quest)
			container:AddChild(weeklyQuest)
		else
			dailyQuest = createQuestLogItemEntry(quest)
			container:AddChild(dailyQuest)
		end
	end
	container:AddChild(CreateDummyFrame())
end

function RackensTracker:DrawCurrencies(container, characterName)
	local labelHeight = 20
	local relWidthPerCurrency = 0.25 -- Use a quarter of the container space per item, making new rows as fit.

	local characterCurrencies = self.db.realm.characters[characterName].currencies

	container:AddChild(CreateDummyFrame())

	-- Heading 
	local currenciesHeading = AceGUI:Create("Heading")
	currenciesHeading:SetText(L["currencies"]) -- TODO: Use AceLocale for things 
	currenciesHeading:SetFullWidth(true)
	container:AddChild(currenciesHeading)

	container:AddChild(CreateDummyFrame())
	
	local currenciesGroup = AceGUI:Create("SimpleGroup")
	currenciesGroup:SetLayout("Flow")
	currenciesGroup:SetFullHeight(true)
	currenciesGroup:SetFullWidth(true)

	local currencyDisplayLabel
	local colorizedName, icon, quantity = ""

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

function RackensTracker:GetLockoutTimeWithIcon(isRaid)

	-- https://www.wowhead.com/wotlk/icon=134238/inv-misc-key-04
	local raidAtlas = "Raid"
	-- https://www.wowhead.com/wotlk/icon=134237/inv-misc-key-03
	local dungeonAtlas = "Dungeon"
	local atlasSize = 16
	local iconMarkup = ""
	if (isRaid and self.db.realm.secondsToWeeklyReset) then
		iconMarkup = CreateAtlasMarkup(raidAtlas, atlasSize, atlasSize)
		return string.format("%s %s: %s", iconMarkup, L["raidLockExpiresIn"], SecondsToTime(self.db.realm.secondsToWeeklyReset, true, nil, 3))
	end
	if (isRaid == false and self.db.realm.secondsToDailyReset) then
		iconMarkup = CreateAtlasMarkup(dungeonAtlas, atlasSize, atlasSize)
		return string.format("%s %s: %s", iconMarkup, L["dungeonLockExpiresIn"], SecondsToTime(self.db.realm.secondsToDailyReset, true, nil, 3))
	end
end

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
	
	-- Empty Row
	container:AddChild(CreateDummyFrame())

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

	container:AddChild(lockoutsGroup)

	local raidGroup = AceGUI:Create("InlineGroup")
	raidGroup:SetLayout("List")
	raidGroup:SetTitle(L["raids"]) -- TODO: AceLocale
	raidGroup:SetFullHeight(true)
	raidGroup:SetRelativeWidth(0.50) -- Half of the parent
	
	local dungeonGroup = AceGUI:Create("InlineGroup")
	dungeonGroup:SetLayout("List")
	dungeonGroup:SetTitle(L["dungeons"]) -- TODO: AceLocale
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
			for i = 1, nDummyFramesNeeded * 2 do -- * 2 to account for the instance name row + the lockout progress row
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
			for i = 1, nDummyFramesNeeded * 2 do
				dungeonGroup:AddChild(CreateDummyFrame())
			end
		end
	end

	-- If these arent added AFTER all the child objects have been added, the anchor points and positioning gets all screwed up : (
	lockoutsGroup:AddChild(raidGroup)
	lockoutsGroup:AddChild(dungeonGroup)
end


local function SelectCharacterTab(container, event, characterName)
	container:ReleaseChildren()
	RackensTracker:DrawQuests(container, characterName)
	RackensTracker:DrawSavedInstances(container, characterName)
	RackensTracker:DrawCurrencies(container, characterName)
end

function RackensTracker:CloseTrackerFrame()
	if (self.tracker_frame and self.tracker_frame:IsVisible()) then
		AceGUI:Release(self.tracker_frame)
		self.tracker_frame = nil
		self.tracker_tabs = nil
	end
end

function RackensTracker:OpenOptionsFrame()
	Settings.OpenToCategory(self.optionsCategory:GetID())
end

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
	for characterName, character in pairs(self.db.realm.characters) do
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