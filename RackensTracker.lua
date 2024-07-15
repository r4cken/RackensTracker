local addOnName, RT = ...
local addOnVersion = C_AddOns.GetAddOnMetadata(addOnName, "Version");

local strformat = string.format
local table, math, type, strtrim, pairs, ipairs =
	  table, math, type, strtrim, pairs, ipairs

local ContainsIf, GetKeysArray =
	  ContainsIf, GetKeysArray

local GetServerTime = GetServerTime
local GetSecondsUntilWeeklyReset = C_DateAndTime.GetSecondsUntilWeeklyReset
local GetSecondsUntilDailyReset  = C_DateAndTime.GetSecondsUntilDailyReset

local DAILY_QUEST_TAG_TEMPLATE = DAILY_QUEST_TAG_TEMPLATE
local INSTANCE_LOCK_SS, BOSS_DEAD, AVAILABLE =
	  INSTANCE_LOCK_SS, BOSS_DEAD, AVAILABLE

local UnitName, UnitLevel, CreateAtlasMarkup =
	  UnitName, UnitLevel, CreateAtlasMarkup

local Settings, CreateSettingsListSectionHeaderInitializer =
	  Settings, CreateSettingsListSectionHeaderInitializer

---@class RackensTracker : AceAddon, AceConsole-3.0, AceEvent-3.0
local RackensTracker = LibStub("AceAddon-3.0"):GetAddon(addOnName)
local L = LibStub("AceLocale-3.0"):GetLocale(addOnName, true)
local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

-- Set bindings translations (used in game options keybinds section)
_G.BINDING_HEADER_RACKENSTRACKER = RT.ColorUtil:FormatColor(RT.ColorUtil.Color.ADDON_FONT_COLOR_CODE, addOnName)
_G.BINDING_NAME_RACKENSTRACKER_TOGGLE = L["toggleTrackerPanel"]
_G.BINDING_NAME_RACKENSTRACKER_OPTIONS_OPEN = L["openOptionsPanel"]

---@type DatabaseDefaults
local database_defaults = RT.DatabaseSettings:GetDefaults()

local function SlashCmdLog(message, ...)
	RackensTracker:Printf(message, ...)
end

local function Log(message, ...)
	if (RackensTracker.LOGGING_ENABLED) then
    	RackensTracker:Printf(message, ...)
	end
end

--- Asks the server for the latest weekly and daily reset times and saves them to the database
function RackensTracker:UpdateWeeklyDailyResetTime()
	-- Update to get the absolute latest timers
	self.db.global.realms[self.currentRealm].secondsToWeeklyReset = GetSecondsUntilWeeklyReset()
	self.db.global.realms[self.currentRealm].secondsToDailyReset  = GetSecondsUntilDailyReset()
	self.db.global.realms[self.currentRealm].weeklyResetTime = GetServerTime() + self.db.global.realms[self.currentRealm].secondsToWeeklyReset
	self.db.global.realms[self.currentRealm].dailyResetTime = GetServerTime() + self.db.global.realms[self.currentRealm].secondsToDailyReset
end


--- Checks if a character has transfered realm or changed name.
--- Checks if a character has faction changed.
--- Deletes old database records if required.
function RackensTracker:DeleteCharacterDataIfNecessary()
	local currentCharacterGUID = UnitGUID("player")
	local currentCharacterRealm = GetRealmName()
	local currentCharacterName = UnitName("player")
	local currentCharacterFaction = UnitFactionGroup("player")

	for _, realm in pairs(self.db.global.realms) do
		for _, character in pairs(realm.characters) do
			-- Found the character
			if (character.guid and character.guid == currentCharacterGUID) then
				Log("GUID checking.")
				local optionsKey = strformat("%s.%s", character.realm, character.name)
				-- If a faction change occured, we need to delete a tracked quest from the other faction if they have one
				if (character.faction and character.faction ~= currentCharacterFaction) then
					Log("Character on: " .. character.realm .. " changed faction to: " .. currentCharacterFaction)
					for questID, quest in pairs(character.quests) do
						if (quest.faction and quest.faction ~= currentCharacterFaction) then
							Log("Tracked quest found for another faction, deleting old record for questID: " .. questID .. " name: " .. quest.name)
							self.db.global.realms[character.realm].characters[character.name].quests[questID] = nil
						end
					end
				end
				-- If they realm swapped, clear the database for that character on the old realm.
				if (character.realm ~= currentCharacterRealm) then
					Log("Character on: " .. character.realm .. " changed realm to: " .. currentCharacterRealm)
					Log("Character realm transfer found, deleting old record from: " .. character.realm .. " for character with stored name: " .. character.name)
					self.db.global.realms[character.realm].characters[character.name] = nil
					self.db.global.options.shownCharacters[optionsKey] = nil
				else
					-- Same realm but if they name changed, clear the database for that character
					if (character.name ~= currentCharacterName) then
						Log("Character on: " .. character.realm .. " changed name to: " .. currentCharacterName)
						Log("Character name change found, deleting old record from: " .. character.realm .. " for character with stored former name: " .. character.name)
						self.db.global.realms[currentCharacterRealm].characters[character.name] = nil
						self.db.global.options.shownCharacters[optionsKey] = nil
					end
				end
			end
		end
	end
end

function RackensTracker:CreateRealmOptions()
	local realmsAvailable = GetKeysArray(self.db.global.realms)
	table.sort(realmsAvailable, function(a,b) return a < b end)

	local options = {
		type = "group",
		args = {
		}
	}

	-- Create one subcategory with characters to display per realm
	for _, realmName in ipairs(realmsAvailable) do
		local order = 0
		--if not options.args[realmName] then
			options.args[realmName] = {}
			options.args[realmName].name = string.format("%s character options", realmName)
			options.args[realmName].type = "group"
			options.args[realmName].args = {}
			options.args[realmName].args.displayedCharactersHeader = {
				type = "header",
				name = L["optionsCharactersHeader"],
				order = order
			}
			-- Display an options header depending if we have eligible characters to track or not, on this realm
			if (not ContainsIf(self.db.global.realms[realmName].characters, function(character) return RT.CharacterUtil:IsCharacterAtEffectiveMaxLevel(character.level) end)) then
				options.args[realmName].args.displayedCharactersHeader.name = L["optionsNoCharactersHeader"]
			end

			-- Character toggles for the tracker
			for characterName, character in pairs(self.db.global.realms[realmName].characters) do
				order = order + 1
				if (RT.CharacterUtil:IsCharacterAtEffectiveMaxLevel(character.level)) then
					local key = strformat("%s.%s", character.realm, characterName)
					options.args[realmName].args[characterName] = {
						name = characterName,
						desc = L["optionsToggleCharacterTooltip"],
						type = "toggle",
						order = order,
						set = function(info, value) self.db.global.options.shownCharacters[key] = value end,
						get = function(info) return self.db.global.options.shownCharacters[key] end,
					}
				end
			end

			order = order + 1
			options.args[realmName].args.deleteCharacterHeader = {
				type = "header",
				name = L["optionsSelectDeleteCharacter"],
				order = order,
			}
			order = order + 1

			-- Dropdown select for which character to select for deletion
			options.args[realmName].args.characterSelectDelete = {
				type = "select",
				name = L["optionsSelectDeleteCharacter"],
				desc = L["optionsSelectDeleteCharacterTooltip"],
				values = {},
				sorting = {},
				order = order,
				width = "normal",
				get = function(info)
					--self.db.global.realms[realmName].selectedCharacterForDeletion = self.db.global.realms[realmName].selectedCharacterForDeletion or strformat("%s.%s", self.currentCharacter.realm, self.currentCharacter.name)
					return self.db.global.realms[realmName].selectedCharacterForDeletion
				end,
				set = function(info, value) self.db.global.realms[realmName].selectedCharacterForDeletion = value end,
			}

			for characterName, character in pairs(self.db.global.realms[realmName].characters) do
				if (RT.CharacterUtil:IsCharacterAtEffectiveMaxLevel(character.level)) then
					local key = strformat("%s.%s", realmName, characterName)
					options.args[realmName].args.characterSelectDelete.values[key] = characterName
					options.args[realmName].args.characterSelectDelete.sorting[#options.args[realmName].args.characterSelectDelete.sorting + 1] = key
				end
			end

			-- Button to delete the selected character from the select dropdown
			order = order + 1
			options.args[realmName].args.deleteCharacterButton = {
				type = "execute",
				name = L["optionsButtonDeleteCharacter"],
				desc = L["optionsButtonDeleteCharacterTooltip"],
				func = function(info, value)
					local realm, name = strsplit(".", self.db.global.realms[realmName].selectedCharacterForDeletion)
					self.db.global.realms[realm].characters[name] = nil
					self.db.global.options.shownCharacters[self.db.global.realms[realmName].selectedCharacterForDeletion] = nil
					options.args[realmName].args[name] = nil
					options.args[realmName].args.characterSelectDelete.values[self.db.global.realms[realmName].selectedCharacterForDeletion] = nil
					local sortedIndex = tIndexOf(options.args[realmName].args.characterSelectDelete.sorting, self.db.global.realms[realmName].selectedCharacterForDeletion)
					if sortedIndex then
						options.args[realmName].args.characterSelectDelete.sorting[sortedIndex] = nil
					end
					-- Display an options header depending if we have eligible characters to track or not, on this realm
					if (not ContainsIf(self.db.global.realms[realmName].characters, function(character) return RT.CharacterUtil:IsCharacterAtEffectiveMaxLevel(character.level) end)) then
						options.args[realmName].args.displayedCharactersHeader.name = L["optionsNoCharactersHeader"]
					end
					self.db.global.realms[realmName].selectedCharacterForDeletion = nil
					AceConfigRegistry:NotifyChange(addOnName)
				end,
				order = order,
				confirm = function()
					local _, name = strsplit(".", self.db.global.realms[realmName].selectedCharacterForDeletion)
					return string.format(L["optionsButtonDeleteCharacterConfirm"], name);
				end,
				disabled = function()
					if not self.db.global.realms[realmName].selectedCharacterForDeletion then
						return true
					end
				end,
			}
		--end
	end

	return options
end
--- Called when the addon is initialized
function RackensTracker:OnInitialize()
	-- Load saved variables
	self.db = LibStub("AceDB-3.0"):New(addOnName .. "DB", database_defaults, true)
	self:DeleteCharacterDataIfNecessary()

	self.currentRealm = GetRealmName()
	-- setup realm to show data for in the tracker window
	self.currentDisplayedRealm = self.db.global.options.shownRealm and self.db.global.options.shownRealm or GetRealmName()
	-- GUI related handles
	self.tracker_frame = nil
	self.optionsCategory = nil
	self.optionsLayout = nil
	self.realmSubFramesAndCategoryIds = nil

	-- TODO: Investigate later if this needs to go back down to OnEnable or not
	local characterName = UnitName("player")
	self.currentCharacter = self.db.global.realms[self.currentRealm].characters[characterName]
	self.currentCharacter.name = characterName
	self.currentCharacter.class = RT.CharacterUtil:GetCharacterClass()
	self.currentCharacter.level = UnitLevel("player")
	self.currentCharacter.realm = GetRealmName()
	self.currentCharacter.faction = UnitFactionGroup("player")
	self.currentCharacter.guid = UnitGUID("player")

	-- Update weekly and daily reset timers
	self:UpdateWeeklyDailyResetTime()

	local function OnRealmOptionChanged(_, _, value)
		if (self.db.global.realms[value]) then
			self.db.global.options.shownRealm = value
			self.currentDisplayedRealm = value
		end
	end

	local function OnQuestOptionSettingChanged(_, setting, value)
		local variable = setting:GetVariable()
		if (variable == "showQuests") then
			self.db.global.options.showQuests = value
		else
			self.db.global.options.shownQuests[variable] = value
		end
	end

	local function OnCurrencyOptionSettingChanged(_, setting, value)
		local variable = setting:GetVariable()
		if (variable == "showCurrencies") then
			self.db.global.options.showCurrencies = value
		else
			self.db.global.options.shownCurrencies[variable] = value
		end
	end

	self.OnQuestOptionSettingChanged = OnQuestOptionSettingChanged
	self.OnCurrencyOptionSettingChanged = OnCurrencyOptionSettingChanged
	self.OnRealmOptionChanged = OnRealmOptionChanged

	local options = self:CreateRealmOptions()
	LibStub("AceConfig-3.0"):RegisterOptionsTable(addOnName, options)
	-- Sets up the layout and options see under the AddOn options
	AceConfigRegistry:NotifyChange(addOnName)
	
	self:RegisterAddOnSettings(OnQuestOptionSettingChanged, OnCurrencyOptionSettingChanged, OnRealmOptionChanged)

	-- Setup the data broken and the minimap icon
	self.libDataBroker = LibStub("LibDataBroker-1.1", true)
	self.libDBIcon = self.libDataBroker and LibStub("LibDBIcon-1.0", true)
	local minimapBtn = self.libDataBroker:NewDataObject(addOnName, {
		type = "launcher",
		icon = [[Interface\Addons\RackensTracker\art\RackensTracker-Medium]],
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
			tooltip:AddLine(RT.ColorUtil:FormatColor(RT.ColorUtil.Color.HIGHLIGHT_FONT_COLOR_CODE, "%s - %s %s", addOnName, L["version"], addOnVersion))
			tooltip:AddLine(RT.ColorUtil:FormatColor(RT.ColorUtil.Color.GRAY_FONT_COLOR_CODE, "%s", "/rackenstracker for available commands"))
			tooltip:AddLine(RT.ColorUtil:FormatColor(RT.ColorUtil.Color.GRAY_FONT_COLOR_CODE, "%s: ", L["minimapLeftClickAction"]) .. RT.ColorUtil:FormatColor(RT.ColorUtil.Color.NORMAL_FONT_COLOR_CODE, "%s", L["minimapLeftClickDescription"]))
			tooltip:AddLine(RT.ColorUtil:FormatColor(RT.ColorUtil.Color.GRAY_FONT_COLOR_CODE, "%s: ", L["minimapRightClickAction"]) .. RT.ColorUtil:FormatColor(RT.ColorUtil.Color.NORMAL_FONT_COLOR_CODE, "%s", L["minimapRightClickDescription"]))
		end,
	})

	if self.libDBIcon then
		---@diagnostic disable-next-line: param-type-mismatch
		self.libDBIcon:Register(addOnName, minimapBtn, self.db.char.minimap)
	end

	tinsert(UISpecialFrames, "RackensTrackerWindowFrame")
end

--- Registers this AddOns configurable settings and specifies the layout and graphical elements for the settings panel.
---@param OnQuestOptionChanged function
---@param OnCurrencyOptionChanged function
---@param OnRealmOptionChanged function
function RackensTracker:RegisterAddOnSettings(OnQuestOptionChanged, OnCurrencyOptionChanged, OnRealmOptionChanged)
	-- Register the Options menu
	self.optionsCategory, self.optionsLayout = Settings.RegisterVerticalLayoutCategory(addOnName)
	self.optionsCategory.ID = addOnName

	self.realmSubFramesAndCategoryIds = {}
	local realmsAvailable = GetKeysArray(self.db.global.realms)
	table.sort(realmsAvailable, function(a,b) return a < b end)

	-- Realm data 
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsTrackedRealmsHeader"]))
	local realmsDropDownOptionVariable = "shownRealm"
	local realmsDropDownOptionDisplayName = L["optionsDropDownDescriptionRealms"]
	local defaultRealmsDropDownOptionValue = self.currentRealm
	local realmsDropDownOptionTooltip = L["optionsDropDownTooltipRealms"]
	local function GetRealmOptions()
		local container = Settings.CreateControlTextContainer();
		for _, realmName in ipairs(realmsAvailable) do
			container:Add(realmName, realmName)
		end
		return container:GetData();
	end
	local shownRealmSetting = Settings.RegisterAddOnSetting(self.optionsCategory, realmsDropDownOptionDisplayName, realmsDropDownOptionVariable, Settings.VarType.string, defaultRealmsDropDownOptionValue)
	Settings.CreateDropDown(self.optionsCategory, shownRealmSetting, GetRealmOptions, realmsDropDownOptionTooltip)
	Settings.SetOnValueChangedCallback(realmsDropDownOptionVariable, OnRealmOptionChanged)
	if (self.db.global.options.shownRealm == nil) then
		shownRealmSetting:SetValue(self.currentRealm, true)
	else
		shownRealmSetting:SetValue(self.db.global.options[realmsDropDownOptionVariable], true)
	end

	-- Weekly / Daily options
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsQuestsHeader"]))
	local allQuestsOptionVariable = "showQuests"
	local allQuestsOptionDisplayName = L["optionsToggleDescriptionShowQuests"]
	local defaultAllQuestsVisibilityValue = database_defaults.global.options.showQuests
	local allQuestsOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, allQuestsOptionDisplayName, allQuestsOptionVariable, type(defaultAllQuestsVisibilityValue), defaultAllQuestsVisibilityValue)
	local allQuestsOptionInitializer = Settings.CreateCheckBox(self.optionsCategory, allQuestsOptionVisibilitySetting)
	Settings.SetOnValueChangedCallback(allQuestsOptionVariable, OnQuestOptionChanged)
	allQuestsOptionVisibilitySetting:SetValue(self.db.global.options.showQuests, true) -- true means force

	local weeklyQuestOptionVariable = "Weekly"
	local weeklyQuestOptionDisplayName = L["optionsToggleDescriptionWeeklyQuest"]
	local defaultWeeklyQuestVisibilityValue = database_defaults.global.options.shownQuests[weeklyQuestOptionVariable]
	local weeklyQuestOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, weeklyQuestOptionDisplayName, weeklyQuestOptionVariable, type(defaultWeeklyQuestVisibilityValue), defaultWeeklyQuestVisibilityValue)
	local weeklyQuestOptionInitializer = Settings.CreateCheckBox(self.optionsCategory, weeklyQuestOptionVisibilitySetting)
	Settings.SetOnValueChangedCallback(weeklyQuestOptionVariable, OnQuestOptionChanged)
	weeklyQuestOptionVisibilitySetting:SetValue(self.db.global.options.shownQuests[weeklyQuestOptionVariable], true) -- true means force
	weeklyQuestOptionInitializer:SetParentInitializer(allQuestsOptionInitializer, function() return allQuestsOptionVisibilitySetting:GetValue() end)

	local dailyQuestOptionVariable = "Daily"
	local dailyQuestOptionDisplayName = L["optionsToggleDescriptionDailyQuest"]
	local defaultDailyQuestVisibilityValue = database_defaults.global.options.shownQuests[dailyQuestOptionVariable]
	local dailyquestOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, dailyQuestOptionDisplayName, dailyQuestOptionVariable, type(defaultDailyQuestVisibilityValue), defaultDailyQuestVisibilityValue)
	local dailyQuestOptionInitializer = Settings.CreateCheckBox(self.optionsCategory, dailyquestOptionVisibilitySetting)
	Settings.SetOnValueChangedCallback(dailyQuestOptionVariable, OnQuestOptionChanged)
	dailyquestOptionVisibilitySetting:SetValue(self.db.global.options.shownQuests[dailyQuestOptionVariable], true) -- true means force
	dailyQuestOptionInitializer:SetParentInitializer(allQuestsOptionInitializer, function() return allQuestsOptionVisibilitySetting:GetValue() end)

	-- Currency options
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsCurrenciesHeader"]))
	local allCurrencyOptionVariable = "showCurrencies"
	local allCurrencyOptionDisplayName = L["optionsToggleDescriptionShowCurrencies"]
	local defaultAllCurrencyVisibilityValue = database_defaults.global.options.showCurrencies
	local allCurrencyOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, allCurrencyOptionDisplayName, allCurrencyOptionVariable, type(defaultAllCurrencyVisibilityValue), defaultAllCurrencyVisibilityValue)
	local allCurrencyOptionInitializer = Settings.CreateCheckBox(self.optionsCategory, allCurrencyOptionVisibilitySetting)
	Settings.SetOnValueChangedCallback(allCurrencyOptionVariable, OnCurrencyOptionChanged)
	allCurrencyOptionVisibilitySetting:SetValue(self.db.global.options.showCurrencies, true) -- true means force

	for _, currency in ipairs(RT.Currencies) do
		local variable = tostring(currency.id)
		local name = currency:GetName()
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

	-- Create one option subcategory with characters to display per realm
	for _, realmName in ipairs(realmsAvailable) do
		self.realmSubFramesAndCategoryIds[realmName] = {}
		self.realmSubFramesAndCategoryIds[realmName].frame, self.realmSubFramesAndCategoryIds[realmName].categoryID = AceConfigDialog:AddToBlizOptions(addOnName, realmName, self.optionsCategory:GetID(), realmName)
	end
end

--- Called when the addon is enabled
function RackensTracker:OnEnable()
	-- Level up event
	self:RegisterEvent("PLAYER_LEVEL_UP", "OnEventPlayerLevelUp")

	-- Register Slash Commands
	self:RegisterChatCommand(addOnName, "HandleSlashCommands")
end

--- Called when the addon is disabled
function RackensTracker:OnDisable()
	-- Called when the addon is disabled
	self:UnregisterChatCommand(addOnName)
	self:UnhookAll()
end

--- Updates the database with the new level for the current character
function RackensTracker:UpdateCharacterLevel(newLevel)
	self.currentCharacter.level = newLevel
end

--- Called when the player levels up
---@param event string PLAYER_LEVEL_UP
---@param newLevel number
function RackensTracker:OnEventPlayerLevelUp(event, newLevel)
	self:UpdateCharacterLevel(newLevel)
	if (RT.CharacterUtil:IsCharacterAtEffectiveMaxLevel(newLevel)) then
		--self:RegisterAddOnSettings(self.OnQuestOptionSettingChanged, self.OnCurrencyOptionSettingChanged, self.OnRealmOptionChanged)
		AceConfigRegistry:NotifyChange(addOnName)
	end
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
function RackensTracker:HandleSlashCommands(msg)
	local command, value, _ = self:GetArgs(msg, 2)

	if (command == nil or strtrim(command) == "") then
		return slashCommandUsage()
	end

	if (command == "toggle") then
		return self:ToggleTrackerFrame()
	elseif (command == "options" or command == "config") then
		return self:OpenOptionsFrame()
	elseif (command == "minimap") then
		if (value == "show") then
			self.db.char.minimap.hide = false
			return self.libDBIcon:Show(addOnName)
		elseif (value == "hide") then
			self.db.char.minimap.hide = true
			return self.libDBIcon:Hide(addOnName)
		else
			return slashCommandUsage()
		end
	else
		return slashCommandUsage()
	end
end

--- GUI Code ---

--- Creates an empty dummy label widget to take up UI space but is rendered as invisible
---@return AceGUIWidget
local function CreateDummyFrame()
	local dummyFiller = AceGUI:Create("Label")
	dummyFiller:SetText(" ")
	dummyFiller:SetFullWidth(true)
	dummyFiller:SetHeight(20)
	return dummyFiller
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
		displayedQuestTag = strformat(DAILY_QUEST_TAG_TEMPLATE, questTag)
	end

	local colorizedText = RT.ColorUtil:FormatColor(RT.ColorUtil.Color.YELLOW_FONT_COLOR_CODE, "%s (%s) - %s", isWeekly and L["weeklyQuest"] or name, displayedQuestTag, status)
	local labelText = strformat("%s %s", icon, colorizedText)

	questLabel:SetText(labelText)
	return questLabel
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
		questTag = strformat(DAILY_QUEST_TAG_TEMPLATE, quest.questTag)
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

	local colorizedText = RT.ColorUtil:FormatColor(RT.ColorUtil.Color.YELLOW_FONT_COLOR_CODE, "%s (%s) - %s", quest.isWeekly and L["weeklyQuest"] or quest.name, questTag, status)
	local labelText = strformat("%s %s", icon, colorizedText)

	questLabel:SetText(labelText)
	return questLabel
end

--- Draws the graphical elements to display which realm is currently being viewed
---@param container AceGUIWidget
function RackensTracker:DrawCurrentRealmInfo(container)
	--container:AddChild(CreateDummyFrame())
	local realmHeading = AceGUI:Create("Heading")
	realmHeading:SetFullWidth(true)
	realmHeading:SetText(self.currentDisplayedRealm)
	container:AddChild(realmHeading)
end

--- Draws the graphical elements to display the tracked quests, given a known character name
---@param container AceGUIWidget
---@param characterName string name of the character to render quests for
function RackensTracker:DrawQuests(container, characterName)
	if (not ContainsIf(self.db.global.options.shownQuests, function(questTypeEnabled) return questTypeEnabled end) or not self.db.global.options.showQuests) then
		return
	end

	local shouldDisplayWeeklyQuests = self.db.global.options.shownQuests["Weekly"]
	local shouldDisplayDailyQuests = self.db.global.options.shownQuests["Daily"]
	local characterQuests = self.db.global.realms[self.currentDisplayedRealm].characters[characterName].quests

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

	local characterCurrencies = self.db.global.realms[self.currentDisplayedRealm].characters[characterName].currencies

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

	container:AddChild(currenciesGroup)

	local currencyDisplayLabel
	local colorizedName, icon, quantity, maxQuantity = "", "", 0, 0

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
				maxQuantity = characterCurrencies[currency.id].maxQuantity
			else
				-- The selected character doesnt have any quantity for the currency.
				quantity = 0
				maxQuantity = 0
			end

			if (quantity == 0) then
				local disabledAmount = RT.ColorUtil:FormatColor(RT.ColorUtil.Color.GRAY_FONT_COLOR_CODE, quantity)
				currencyDisplayLabel:SetText(strformat("%s\n%s %s", colorizedName, icon, disabledAmount))
			else
				if (maxQuantity ~= 0) then
					if (quantity == maxQuantity) then
						local maxQuantityColorized = RT.ColorUtil:FormatColor(RT.ColorUtil.Color.RED_FONT_COLOR_CODE, "%i", maxQuantity)
						local quantityColorized = RT.ColorUtil:FormatColor(RT.ColorUtil.Color.RED_FONT_COLOR_CODE, "%i", quantity)
						currencyDisplayLabel:SetText(strformat("%s\n%s %s/%s", colorizedName, icon, quantityColorized, maxQuantityColorized))
					else
						currencyDisplayLabel:SetText(strformat("%s\n%s %s/%s", colorizedName, icon, quantity, maxQuantity))
					end
				else
					currencyDisplayLabel:SetText(strformat("%s\n%s %s", colorizedName, icon, quantity))
				end
			end

			if not self:IsHooked(currencyDisplayLabel.frame, "OnEnter") and not self:IsHooked(currencyDisplayLabel.frame, "OnLeave") then
				self:SecureHookScript(currencyDisplayLabel.frame, "OnEnter", function()
					GameTooltip:SetOwner(currencyDisplayLabel.frame, "ANCHOR_CURSOR")
					GameTooltip:SetCurrencyTokenByID(currency.id)
				end)
				self:SecureHookScript(currencyDisplayLabel.frame, "OnLeave", function()
					GameTooltip:Hide()
				end)
			end
			currenciesGroup:AddChild(currencyDisplayLabel)
		end
	end
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
	if (isRaid and self.db.global.realms[self.currentDisplayedRealm].secondsToWeeklyReset) then
		iconMarkup = CreateAtlasMarkup(raidAtlas, atlasSize, atlasSize)
		return strformat("%s %s: %s", iconMarkup, L["raidLockExpiresIn"], RT.TimeUtil.TimeFormatter:Format(self.db.global.realms[self.currentDisplayedRealm].secondsToWeeklyReset))
	end
	if (isRaid == false and self.db.global.realms[self.currentDisplayedRealm].secondsToDailyReset) then
		iconMarkup = CreateAtlasMarkup(dungeonAtlas, atlasSize, atlasSize)
		return strformat("%s %s: %s", iconMarkup, L["dungeonLockExpiresIn"], RT.TimeUtil.TimeFormatter:Format(self.db.global.realms[self.currentDisplayedRealm].secondsToDailyReset))
	end
	return ""
end

---@param characterName string
---@return boolean characterHasLockouts
---@return table raidInstances
---@return table dungeonInstances
function RackensTracker:GetSavedInstanceInformationFor(characterName)
	local raidInstances = RT.Container:New()
	local dungeonInstances = RT.Container:New()

	local character = self.db.global.realms[self.currentDisplayedRealm].characters[characterName]
	local characterHasLockouts = false

	for _, savedInstance in pairs(character.savedInstances) do
		if savedInstance.resetTime and savedInstance.resetTime > GetServerTime() then
			local isRaid = savedInstance.isRaid
			if isRaid == nil then
				isRaid = true
			end

			local instance = RT.Instance:New(
				savedInstance.savedInstanceIndex,
				savedInstance.instanceName,
				savedInstance.instanceID,
				savedInstance.lockoutID,
				savedInstance.resetTime,
				savedInstance.isRaid,
				savedInstance.isHeroic,
				savedInstance.maxPlayers,
				savedInstance.difficultyID,
				savedInstance.difficultyName,
				savedInstance.toggleDifficultyID,
				savedInstance.encountersTotal,
				savedInstance.encountersCompleted,
				savedInstance.encounterInformation)
				if (isRaid) then
					raidInstances:Add(instance)
				else
					dungeonInstances:Add(instance)
				end

			characterHasLockouts = true
		end
	end


	return characterHasLockouts, raidInstances, dungeonInstances

end

--- Draws the graphical elements to display the saved instances, given a known character name
---@param container AceGUIWidget
---@param characterName string name of the character to render quests for
function RackensTracker:DrawSavedInstances(container, characterName)

	-- Refresh the currently known daily and weekly reset timers
	RackensTracker:UpdateWeeklyDailyResetTime()

	local characterHasLockouts, raidInstances, dungeonInstances = self:GetSavedInstanceInformationFor(characterName)
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

	container:AddChild(lockoutsGroup)

	local raidGroup = AceGUI:Create("InlineGroup")
	raidGroup:SetLayout("List")
	raidGroup:SetTitle(L["raids"])
	raidGroup:SetFullHeight(true)
	raidGroup:SetRelativeWidth(0.50) -- Half of the parent

	lockoutsGroup:AddChild(raidGroup)

	local dungeonGroup = AceGUI:Create("InlineGroup")
	dungeonGroup:SetLayout("List")
	dungeonGroup:SetTitle(L["dungeons"])
	dungeonGroup:SetFullHeight(true)
	dungeonGroup:SetRelativeWidth(0.50) -- Half of the parent

	lockoutsGroup:AddChild(dungeonGroup)

	-- Fill in the raids inside raidGroup.
	-- There is a wierd problem where the containers raidGroup and dungeonGroup are not anchored to the top of the parent container.
	-- This makes for an awkard layout where one of raidGroup or dungeonGroup is taller than the other one as they dont fill out the height even with :SetFullHeight(true)
	-- but rather fills its height by content, this is an ugly hack to fill dummy frames into either raidGroup or dungeonGroup to match the number of rows, thus making their heights equal :/
	local nDummyFramesNeeded = math.max(nRaids, nDungeons)
	local hasMoreRaidsThanDungeons = nRaids > nDungeons
	local hasEqualRaidsAndDungeons = nRaids == nDungeons

	local instanceProgressLabel, instanceColorizedName = nil, nil
	local instanceProgress = nil
	local raidInstanceNameLabels = {}
	local dungeonInstanceNameLabels = {}
	local labelHeight = 20

	for raidInstanceIndex, raidInstance in ipairs(raidInstances.sorted) do
		instanceColorizedName = RT.ColorUtil:FormatColor(RT.ColorUtil.Color.NORMAL_FONT_COLOR_CODE, "%s", raidInstance.id)
		raidInstanceNameLabels[raidInstanceIndex] = AceGUI:Create("Label")
		raidInstanceNameLabels[raidInstanceIndex]:SetText(instanceColorizedName)
		raidInstanceNameLabels[raidInstanceIndex]:SetFullWidth(true)
		raidInstanceNameLabels[raidInstanceIndex]:SetHeight(labelHeight)
		raidGroup:AddChild(raidInstanceNameLabels[raidInstanceIndex])
		instanceProgress = RT.ColorUtil:FormatEncounterProgress(raidInstance.encountersCompleted, raidInstance.encountersTotal)
		instanceProgressLabel = AceGUI:Create("Label")
		instanceProgressLabel:SetText(strformat("%s: %s", L["progress"], instanceProgress))
		instanceProgressLabel:SetFullWidth(true)
		instanceProgressLabel:SetHeight(labelHeight)

		if not self:IsHooked(raidInstanceNameLabels[raidInstanceIndex].frame, "OnEnter") and not self:IsHooked(raidInstanceNameLabels[raidInstanceIndex].frame, "OnLeave") then
			self:SecureHookScript(raidInstanceNameLabels[raidInstanceIndex].frame, "OnEnter", function()
				GameTooltip:ClearLines()
				GameTooltip:SetOwner(raidInstanceNameLabels[raidInstanceIndex].frame, "ANCHOR_CURSOR")
				GameTooltip:AddLine(strformat(L["bossesAndIcon"], CreateAtlasMarkup("DungeonSkull", 12, 12)))
					for _, encounterInfo in ipairs(raidInstance.encounterInformation) do
						local rightRed = encounterInfo.isKilled and 1 or 0
						local rightGreen = encounterInfo.isKilled and 0 or 1
						GameTooltip:AddDoubleLine(encounterInfo.bossName, encounterInfo.isKilled and BOSS_DEAD or AVAILABLE, 1, 1, 1, rightRed, rightGreen, 0)
					end
					GameTooltip:Show()
			end)
			self:SecureHookScript(raidInstanceNameLabels[raidInstanceIndex].frame, "OnLeave", function()
				GameTooltip:Hide()
			end)
		end

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
	for dungeonInstanceIndex, dungeonInstance in ipairs(dungeonInstances.sorted) do
		instanceColorizedName = RT.ColorUtil:FormatColor(RT.ColorUtil.Color.NORMAL_FONT_COLOR_CODE, "%s", dungeonInstance.id)
		dungeonInstanceNameLabels[dungeonInstanceIndex] = AceGUI:Create("Label")
		dungeonInstanceNameLabels[dungeonInstanceIndex]:SetText(instanceColorizedName)
		dungeonInstanceNameLabels[dungeonInstanceIndex]:SetFullWidth(true)
		dungeonInstanceNameLabels[dungeonInstanceIndex]:SetHeight(labelHeight)
		dungeonGroup:AddChild(dungeonInstanceNameLabels[dungeonInstanceIndex])
		instanceProgress = RT.ColorUtil:FormatEncounterProgress(dungeonInstance.encountersCompleted, dungeonInstance.encountersTotal)
		instanceProgressLabel = AceGUI:Create("Label")
		instanceProgressLabel:SetText(strformat("%s%s: %s", CreateAtlasMarkup("DungeonSkull", 12, 12), L["progress"], instanceProgress))
		instanceProgressLabel:SetFullWidth(true)
		instanceProgressLabel:SetHeight(labelHeight)

		if not self:IsHooked(dungeonInstanceNameLabels[dungeonInstanceIndex].frame, "OnEnter") and not self:IsHooked(dungeonInstanceNameLabels[dungeonInstanceIndex].frame, "OnLeave") then
			self:SecureHookScript(dungeonInstanceNameLabels[dungeonInstanceIndex].frame, "OnEnter", function()
				GameTooltip:ClearLines()
				GameTooltip:SetOwner(dungeonInstanceNameLabels[dungeonInstanceIndex].frame, "ANCHOR_CURSOR")
				GameTooltip:SetInstanceLockEncountersComplete(dungeonInstance.savedInstanceIndex)
			end)
			self:SecureHookScript(dungeonInstanceNameLabels[dungeonInstanceIndex].frame, "OnLeave", function()
				GameTooltip:Hide()
			end)
		end

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
end

--- Callback that runs when the user selects a character tab in the main tracker frame
---@param container AceGUIWidget
---@param event string
---@param characterName string
local function SelectCharacterTab(container, event, characterName)
	RackensTracker:UnhookAll()
	container:ReleaseChildren()

	container:PauseLayout()
	-- NOTE: Layout pausing is necessary in order for everything to calculate correctly during rendering
	-- this fixes all my current sizing and anchoring problems, without this all hell breaks loose.
	-- Figured out that every AddChild call runs PerformLayout EVERY TIME and this causes major layout shift and visual glitches
	-- Just pause all layout calculations until after we placed all the widgets on screen.
	RackensTracker:DrawCurrentRealmInfo(container)
	RackensTracker:DrawQuests(container, characterName)
	RackensTracker:DrawSavedInstances(container, characterName)
	RackensTracker:DrawCurrencies(container, characterName)
	container:ResumeLayout()
	container:PerformLayout()
end

--- Closes the tracker frame
function RackensTracker:CloseTrackerFrame()
	AceGUI:Release(self.tracker_frame)
	self.tracker_frame = nil
	self.tracker_tabs = nil
	self:UnhookAll()
end

--- Opens the setting panel for the AddOn
function RackensTracker:OpenOptionsFrame()
	if (self.tracker_frame) then
		self:CloseTrackerFrame()
	end
	Settings.OpenToCategory(addOnName)
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

	self.tracker_frame = AceGUI:Create("Window")

	-- Make it so pressing Escape closes the tracker window
	_G["RackensTrackerWindowFrame"] = self.tracker_frame.frame

	local textureSize = 22
	local addonTexture = CreateSimpleTextureMarkup([[Interface\Addons\RackensTracker\Art\RackensTracker-Small]], textureSize, textureSize)
	self.tracker_frame:SetTitle(string.format("%s %s", addonTexture, addOnName))
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
		self:UnhookAll()
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
	for characterName, character in pairs(self.db.global.realms[self.currentDisplayedRealm].characters) do
		local optionsKey = strformat("%s.%s", character.realm, characterName)
		if (self.db.global.options.shownCharacters[optionsKey]) then
			if (RT.CharacterUtil:IsCharacterAtEffectiveMaxLevel(character.level)) then
				if (character.name == initialCharacterTab and RT.CharacterUtil:IsCharacterAtEffectiveMaxLevel(character.level)) then
					isInitialCharacterMaxLevel = true
				end
				tabIcon = RT.CharacterUtil:GetCharacterIcon(character.class, tabIconSize)
				tabName = RT.ColorUtil:FormatColorClass(character.class, character.name)
				table.insert(tabsData, { text=strformat("%s %s", tabIcon, tabName), value=characterName})
			end
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
		self:DrawCurrentRealmInfo(noTrackingInformationGroup)
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