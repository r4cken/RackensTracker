local addOnName = ...

---@class RT
local RT = select(2, ...)

local addOnVersion = C_AddOns.GetAddOnMetadata(addOnName, "Version");

local strformat, strsplit =
	  string.format, strsplit

local tIndexOf, tinsert =
	  tIndexOf, tinsert

local table, math, type, strtrim, pairs, ipairs =
	  table, math, type, strtrim, pairs, ipairs

local ContainsIf, GetKeysArray =
	  ContainsIf, GetKeysArray

local GetServerTime = GetServerTime
local GetSecondsUntilWeeklyReset = C_DateAndTime.GetSecondsUntilWeeklyReset
local GetSecondsUntilDailyReset  = C_DateAndTime.GetSecondsUntilDailyReset

local CreateSimpleTextureMarkup = CreateSimpleTextureMarkup
local CreateAtlasMarkup = CreateAtlasMarkup

local GetAverageItemLevel = GetAverageItemLevel

local AbbreviateLargeNumbers = AbbreviateLargeNumbers

local DAILY_QUEST_TAG_TEMPLATE = DAILY_QUEST_TAG_TEMPLATE
local CURRENCY_TOTAL, CURRENCY_TOTAL_CAP, CURRENCY_SEASON_TOTAL, CURRENCY_SEASON_TOTAL_MAXIMUM, BOSS_DEAD, AVAILABLE =
	  CURRENCY_TOTAL, CURRENCY_TOTAL_CAP, CURRENCY_SEASON_TOTAL, CURRENCY_SEASON_TOTAL_MAXIMUM, BOSS_DEAD, AVAILABLE

local ACCOUNT_BANK_PANEL_TITLE = ACCOUNT_BANK_PANEL_TITLE

local GetMoneyString = GetMoneyString

local ACCOUNT_LEVEL_CURRENCY, ACCOUNT_TRANSFERRABLE_CURRENCY, CURRENCY_TRANSFER_LOSS = 
	  ACCOUNT_LEVEL_CURRENCY, ACCOUNT_TRANSFERRABLE_CURRENCY, CURRENCY_TRANSFER_LOSS

local UnitName, UnitLevel, UnitGUID =
	  UnitName, UnitLevel, UnitGUID

local Settings = Settings

---@class RackensTracker : AceAddon, AceConsole-3.0, AceEvent-3.0
local RackensTracker = LibStub("AceAddon-3.0"):GetAddon(addOnName)
local L = LibStub("AceLocale-3.0"):GetLocale(addOnName, true)
local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

-- Set bindings translations (used in game options keybinds section)
_G.BINDING_HEADER_RACKENSTRACKER = RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Addon, addOnName)
_G.BINDING_NAME_RACKENSTRACKER_TOGGLE = L["toggleTrackerPanel"]
_G.BINDING_NAME_RACKENSTRACKER_OPTIONS_OPEN = L["openOptionsPanel"]

---@type DatabaseDefaults
local database_defaults = RT.DatabaseSettings:GetDefaults()

--- Logs slash command usage to the chat frame
---@param message string
---@param ... any
local function SlashCmdLog(message, ...)
	RackensTracker:Printf(message, ...)
end

--- Logs message to the chat frame
---@param message string
---@param ... any
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

--- Creates the realm specific options used in the realm specific options menues
function RackensTracker:CreateRealmOptions()
	local realmsWithCharacters = tFilter(self.db.global.realms, function(realm) return RT.AddonUtil.CountTable(realm.characters) > 0 end, false)
	local realmsAvailable = GetKeysArray(realmsWithCharacters)
	table.sort(realmsAvailable, function(a,b) return a < b end)

	local options = {
		type = "group",
		args = {
		}
	}

	-- Create one subcategory with characters to display per realm
	for _, realmName in ipairs(realmsAvailable) do
		local order = 0
		options.args[realmName] = {}
		options.args[realmName].name = string.format("%s character options", realmName)
		options.args[realmName].type = "group"
		options.args[realmName].args = {}
		options.args[realmName].args.displayedCharactersHeader = {
			type = "header",
			name = L["optionsCharactersHeader"],
			order = order
		}

		-- Character toggles for the tracker
		for characterName, character in pairs(self.db.global.realms[realmName].characters) do
			order = order + 1
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

		order = order + 1
		options.args[realmName].args.deleteCharacterHeader = {
			type = "header",
			name = L["optionsCharactersDeleteHeader"],
			order = order,
		}
		order = order + 1

		options.args[realmName].args.characterSelectDelete = {
			type = "select",
			name = L["optionsSelectDeleteCharacter"],
			desc = L["optionsSelectDeleteCharacterTooltip"],
			values = function()
				local selectDropdownValues = {}
				for characterName in pairs(self.db.global.realms[realmName].characters) do
					selectDropdownValues[characterName] = characterName
				end
				return selectDropdownValues
			end,
			order = order,
			width = "normal",
			get = function(info)
				return self.db.global.realms[realmName].selectedCharacterForDeletion
			end,
			set = function(info, characterName)
				self.db.global.realms[realmName].selectedCharacterForDeletion = characterName
			end,
		}

		-- Button to delete the selected character from the select dropdown
		order = order + 1
		options.args[realmName].args.deleteCharacterButton = {
			type = "execute",
			name = L["optionsButtonDeleteCharacter"],
			desc = L["optionsButtonDeleteCharacterTooltip"],
			func = function(info, value)
				-- Key into self.db.global.options.shownCharacters
				local optionsKey = strformat("%s.%s", realmName, self.db.global.realms[realmName].selectedCharacterForDeletion)

				-- Remove character from the database options
				self.db.global.options.shownCharacters[optionsKey] = nil
				-- Remove the options menu checkbox 
				options.args[realmName].args[self.db.global.realms[realmName].selectedCharacterForDeletion] = nil

				-- Remove all database data for the character removed
				self.db.global.realms[realmName].characters[self.db.global.realms[realmName].selectedCharacterForDeletion] = nil

				-- Set the database value selectedCharacterForDeletion on this realm to nil to clear the dropdown
				self.db.global.realms[realmName].selectedCharacterForDeletion = nil

				AceConfigRegistry:NotifyChange(addOnName)
			end,
			order = order,
			confirm = function()
				local name = self.db.global.realms[realmName].selectedCharacterForDeletion
				return string.format(L["optionsButtonDeleteCharacterConfirm"], name);
			end,
			disabled = function()
				if not self.db.global.realms[realmName].selectedCharacterForDeletion then
					return true
				end
			end,
		}
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
	self.currentDisplayedRealm = self.db.global.options.shownRealm

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

	local options = self:CreateRealmOptions()
	LibStub("AceConfig-3.0"):RegisterOptionsTable(addOnName, options)
	-- Sets up the layout and options see under the AddOn options
	AceConfigRegistry:NotifyChange(addOnName)

	if RT.AddonUtil.IsRetail() then
		self:RegisterAddOnSettings_Retail()
	else
		self:RegisterAddOnSettings()
	end

	-- Setup the data broken and the minimap icon
	self.libDataBroker = LibStub("LibDataBroker-1.1", true)
	self.libDBIcon = self.libDataBroker and LibStub("LibDBIcon-1.0", true)
	local minimapBtn = self.libDataBroker:NewDataObject(addOnName, {
		type = "launcher",
		icon = [[Interface\Addons\RackensTracker\art\RackensTracker-Medium]],
		OnClick = function(_, button)
			if (button == "LeftButton") then
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
			tooltip:AddLine(RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Highlight, "%s - %s %s", addOnName, L["version"], addOnVersion))
			tooltip:AddLine(RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Gray, "%s", "/rackenstracker for available commands"))
			tooltip:AddLine(RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Gray, "%s: ", L["minimapLeftClickAction"]) .. RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Normal, "%s", L["minimapLeftClickDescription"]))
			tooltip:AddLine(RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Gray, "%s: ", L["minimapRightClickAction"]) .. RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Normal, "%s", L["minimapRightClickDescription"]))
		end,
	})

	if self.libDBIcon then
		---@diagnostic disable-next-line: param-type-mismatch
		self.libDBIcon:Register(addOnName, minimapBtn, self.db.char.minimap)
	end

	tinsert(UISpecialFrames, "RackensTrackerWindowFrame")
end

local CreateSettingsListSectionHeaderInitializer
do
	if RT.AddonUtil.IsCataClassic() then
		-- NOTE: This is copied from the blizzard code because the original uses Settings.CreateElementInitializer that can end up tainting :(
		CreateSettingsListSectionHeaderInitializer = function(name)
			local data = {name = name};
			return Settings.CreateSettingInitializer("SettingsListSectionHeaderTemplate", data);
		end
	end

	if RT.AddonUtil.IsRetail() then
		-- NOTE: This is copied from the blizzard code because the original uses Settings.CreateElementInitializer that can end up tainting :(
		CreateSettingsListSectionHeaderInitializer = function(name, tooltip)
			local data = {name = name, tooltip = tooltip};
			return Settings.CreateSettingInitializer("SettingsListSectionHeaderTemplate", data);
		end
	end
end


--- Registers this AddOns configurable settings and specifies the layout and graphical elements for the settings panel.
function RackensTracker:RegisterAddOnSettings()
	-- Register the Options menu
	self.optionsCategory, self.optionsLayout = Settings.RegisterVerticalLayoutCategory(addOnName)
	self.optionsCategory.ID = addOnName
	self.realmSubFramesAndCategoryIds = {}

	local realmsWithCharacters = tFilter(self.db.global.realms, function(realm) return RT.AddonUtil.CountTable(realm.characters) > 0 end, false)
	local realmsAvailable = GetKeysArray(realmsWithCharacters)
	table.sort(realmsAvailable, function(a,b) return a < b end)

	local function OnAddOnSettingChanged(setting, value)
		--Log("setting %s changed to %s", setting:GetVariable(), tostring(value))
	end

	-- Realm data options
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsTrackedRealmsHeader"], nil))
	local realmsDropDownOptionVariable = strformat("%s_%s", addOnName, "shownRealm")
	local realmsDropDownOptionName = L["optionsDropDownDescriptionRealms"]
	local realmsDropDownOptionTooltip = L["optionsDropDownTooltipRealms"]
	local defaultRealmsDropDownOptionValue = self.currentRealm

	local function GetRealmDropdownValue()
		return self.db.global.options.shownRealm
	end

	local function SetRealmDropdownValue(value)
		if (self.db.global.realms[value]) then
			self.db.global.options.shownRealm = value
			self.currentDisplayedRealm = value
		end
	end

	local function GetRealmOptions()
		local container = Settings.CreateControlTextContainer();
		for _, realmName in ipairs(realmsAvailable) do
			container:Add(realmName, realmName)
		end
		return container:GetData();
	end

	local shownRealmSetting = Settings.RegisterProxySetting(self.optionsCategory, realmsDropDownOptionVariable, Settings.VarType.string, realmsDropDownOptionName, defaultRealmsDropDownOptionValue, GetRealmDropdownValue, SetRealmDropdownValue)
	shownRealmSetting:SetValueChangedCallback(OnAddOnSettingChanged)

	Settings.CreateDropdown(self.optionsCategory, shownRealmSetting, GetRealmOptions, realmsDropDownOptionTooltip)
	if (self.db.global.options.shownRealm == nil) then
		shownRealmSetting:SetValue(self.currentRealm, true)
	elseif (not realmsWithCharacters[self.db.global.options.shownRealm]) then
		-- Prevent setting the dropdown to a realm that has no tracked characters on it anymore
		shownRealmSetting:SetValue(self.currentRealm, true)
	else
		shownRealmSetting:SetValue(self.db.global.options.shownRealm, true)
	end

	-- Slider options (minimum character level required to display tracking data)
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsMinimumCharacterLevelHeader"]))
	local showCharactersAtOrBelowLevelOptionName = L["optionsSliderDescriptionShowMinimumCharacterLevel"]
	local showCharactersAtOrBelowLevelOptionTooltip = L["optionsSliderShowMinimumCharacterLevelTooltip"]
	local showCharactersAtOrBelowLevelOptionVariable = strformat("%s_%s", addOnName, "showCharactersAtOrBelowLevel")
	local showCharactersAtOrBelowLevelOptionVariableKey = "showCharactersAtOrBelowLevel"
	local showCharactersAtOrBelowLevelOptionVariableTbl = self.db.global.options
	local defaultShowCharactersAtOrBelowLevelVisibilityValue = database_defaults.global.options.showCharactersAtOrBelowLevel
	local showCharactersAtOrBelowLevelOptionMinValue = 1
	local showCharactersAtOrBelowLevelOptionMaxValue = GetMaxPlayerLevel()
	local showCharactersAtOrBelowLevelOptionSliderStep = 1

	local showCharactersAtOrBelowLevelOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, showCharactersAtOrBelowLevelOptionVariable, showCharactersAtOrBelowLevelOptionVariableKey, showCharactersAtOrBelowLevelOptionVariableTbl, type(defaultShowCharactersAtOrBelowLevelVisibilityValue), showCharactersAtOrBelowLevelOptionName, defaultShowCharactersAtOrBelowLevelVisibilityValue)
	showCharactersAtOrBelowLevelOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	local function FormatLevel(value)
		local levelFormat = "Level %d"
		return levelFormat:format(value)
	end

	local showCharactersAtOrBelowLevelOptions = Settings.CreateSliderOptions(showCharactersAtOrBelowLevelOptionMinValue, showCharactersAtOrBelowLevelOptionMaxValue, showCharactersAtOrBelowLevelOptionSliderStep)
	showCharactersAtOrBelowLevelOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatLevel)

	Settings.CreateSlider(self.optionsCategory, showCharactersAtOrBelowLevelOptionVisibilitySetting, showCharactersAtOrBelowLevelOptions, showCharactersAtOrBelowLevelOptionTooltip)
	showCharactersAtOrBelowLevelOptionVisibilitySetting:SetValue(self.db.global.options[showCharactersAtOrBelowLevelOptionVariableKey], true) -- true means force

	-- Character Data options
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsCharacterDataHeader"]))
	local allCharacterDataOptionName = L["optionsToggleDescriptionShowCharacterData"]
	local allCharacterDataOptionTooltip = L["optionsToggleShowCharacterDataTooltip"]
	local allCharacterDataOptionVariable = strformat("%s_%s", addOnName, "showCharacterData")
	local allCharacterDataOptionVariableKey = "showCharacterData"
	local allCharacterDataOptionVariableTbl = self.db.global.options
	local defaultAllCharacterDataVisibilityValue = database_defaults.global.options.showCharacterData
	local allCharacterDataOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, allCharacterDataOptionVariable, allCharacterDataOptionVariableKey, allCharacterDataOptionVariableTbl, type(defaultAllCharacterDataVisibilityValue), allCharacterDataOptionName, defaultAllCharacterDataVisibilityValue)
	allCharacterDataOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	local allCharacterDataOptionInitializer = Settings.CreateCheckbox(self.optionsCategory, allCharacterDataOptionVisibilitySetting, allCharacterDataOptionTooltip)
	allCharacterDataOptionVisibilitySetting:SetValue(self.db.global.options[allCharacterDataOptionVariableKey], true) -- true means force

	-- Character lvl
	local lvlCharacterDataOptionName = L["optionsToggleDescriptionLvlCharacterData"]
	local lvlCharacterDataOptionTooltip = L["optionsToggleLvlCharacterDataTooltip"]
	local lvlCharacterDataOptionVariable = strformat("%s_%s", addOnName, "showCharacterlvl")
	local lvlCharacterDataOptionVariableKey = "lvl"
	local lvlCharacterDataOptionVariableTbl = self.db.global.options.shownCharacterData
	local defaultLvlCharacterDataVisibilityValue = database_defaults.global.options.shownCharacterData[lvlCharacterDataOptionVariableKey]
	local lvlCharacterDataOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, lvlCharacterDataOptionVariable, lvlCharacterDataOptionVariableKey, lvlCharacterDataOptionVariableTbl, type(defaultLvlCharacterDataVisibilityValue), lvlCharacterDataOptionName, defaultLvlCharacterDataVisibilityValue)
	lvlCharacterDataOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	local lvlCharacterDataOptionInitializer = Settings.CreateCheckbox(self.optionsCategory, lvlCharacterDataOptionVisibilitySetting, lvlCharacterDataOptionTooltip)
	lvlCharacterDataOptionVisibilitySetting:SetValue(self.db.global.options.shownCharacterData[lvlCharacterDataOptionVariableKey], true) -- true means force
	lvlCharacterDataOptionInitializer:SetParentInitializer(allCharacterDataOptionInitializer, function() return allCharacterDataOptionVisibilitySetting:GetValue() end)

	-- Character iLvl
	local iLvlCharacterDataOptionName = L["optionsToggleDescriptioniLvlCharacterData"]
	local iLvlCharacterDataOptionTooltip = L["optionsToggleiLvlCharacterDataTooltip"]
	local iLvlCharacterDataOptionVariable = strformat("%s_%s", addOnName, "showCharacteriLvl")
	local iLvlCharacterDataOptionVariableKey = "iLvl"
	local iLvlCharacterDataOptionVariableTbl = self.db.global.options.shownCharacterData
	local defaultiLvlCharacterDataVisibilityValue = database_defaults.global.options.shownCharacterData[iLvlCharacterDataOptionVariableKey]
	local iLvlCharacterDataOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, iLvlCharacterDataOptionVariable, iLvlCharacterDataOptionVariableKey, iLvlCharacterDataOptionVariableTbl, type(defaultiLvlCharacterDataVisibilityValue), iLvlCharacterDataOptionName, defaultiLvlCharacterDataVisibilityValue)
	iLvlCharacterDataOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	local iLvlCharacterDataOptionInitializer = Settings.CreateCheckbox(self.optionsCategory, iLvlCharacterDataOptionVisibilitySetting, iLvlCharacterDataOptionTooltip)
	iLvlCharacterDataOptionVisibilitySetting:SetValue(self.db.global.options.shownCharacterData[iLvlCharacterDataOptionVariableKey], true) -- true means force
	iLvlCharacterDataOptionInitializer:SetParentInitializer(allCharacterDataOptionInitializer, function() return allCharacterDataOptionVisibilitySetting:GetValue() end)

	-- Character money
	local moneyCharacterDataOptionName = L["optionsToggleDescriptionMoneyCharacterData"]
	local moneyCharacterDataOptionTooltip = L["optionsToggleMoneyCharacterDataTooltip"]
	local moneyCharacterDataOptionVariable = strformat("%s_%s", addOnName, "showCharacterMoney")
	local moneyCharacterDataOptionVariableKey = "money"
	local moneyCharacterDataOptionVariableTbl = self.db.global.options.shownCharacterData
	local defaultMoneyCharacterDataVisibilityValue = database_defaults.global.options.shownCharacterData[moneyCharacterDataOptionVariableKey]
	local moneyCharacterDataOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, moneyCharacterDataOptionVariable, moneyCharacterDataOptionVariableKey, moneyCharacterDataOptionVariableTbl, type(defaultMoneyCharacterDataVisibilityValue), moneyCharacterDataOptionName, defaultMoneyCharacterDataVisibilityValue)
	moneyCharacterDataOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	local moneyCharacterDataOptionInitializer = Settings.CreateCheckbox(self.optionsCategory, moneyCharacterDataOptionVisibilitySetting, moneyCharacterDataOptionTooltip)
	moneyCharacterDataOptionVisibilitySetting:SetValue(self.db.global.options.shownCharacterData[moneyCharacterDataOptionVariableKey], true) -- true means force
	moneyCharacterDataOptionInitializer:SetParentInitializer(allCharacterDataOptionInitializer, function() return allCharacterDataOptionVisibilitySetting:GetValue() end)

	-- Currency options
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsCurrenciesHeader"]))
	local allCurrencyOptionName = L["optionsToggleDescriptionShowCurrencies"]
	local allCurrencyOptionTooltip = L["optionsToggleShowCurrenciesTooltip"]
	local allCurrencyOptionVariable = strformat("%s_%s", addOnName, "showCurrencies")
	local allCurrencyOptionVariableKey = "showCurrencies"
	local allCurrencyOptionVariableTbl = self.db.global.options
	local defaultAllCurrencyVisibilityValue = database_defaults.global.options.showCurrencies
	local allCurrencyOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, allCurrencyOptionVariable, allCurrencyOptionVariableKey, allCurrencyOptionVariableTbl, type(defaultAllCurrencyVisibilityValue), allCurrencyOptionName, defaultAllCurrencyVisibilityValue)
	allCurrencyOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	local allCurrencyOptionInitializer = Settings.CreateCheckbox(self.optionsCategory, allCurrencyOptionVisibilitySetting, allCurrencyOptionTooltip)
	allCurrencyOptionVisibilitySetting:SetValue(self.db.global.options[allCurrencyOptionVariableKey], true) -- true means force

	for _, currency in ipairs(RT.Currencies) do
		local name = currency:GetName()
		if name and database_defaults.global.options.shownCurrencies[tostring(currency.id)] ~= nil then
			local tooltip =  strformat(L["optionsToggleShowCurrencyTooltip"], name)
			local variable = strformat("%s_showCurrency_%s", addOnName, tostring(currency.id))
			local variableKey = tostring(currency.id)
			local variableTbl = self.db.global.options.shownCurrencies
			local defaultVisibilityValue = database_defaults.global.options.shownCurrencies[variableKey]
			local setting = Settings.RegisterAddOnSetting(self.optionsCategory, variable, variableKey, variableTbl, type(defaultVisibilityValue), name, defaultVisibilityValue)
			setting:SetValueChangedCallback(OnAddOnSettingChanged)
			local initializer = Settings.CreateCheckbox(self.optionsCategory, setting, tooltip)
			setting:SetValue(self.db.global.options.shownCurrencies[variableKey], true) -- true means force
			initializer:SetParentInitializer(allCurrencyOptionInitializer, function() return allCurrencyOptionVisibilitySetting:GetValue() end)
		else
			local err = RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Error, L["errorCurrencyConflictDatabaseDefaults"], currency.id)
			RackensTracker:Printf(err)
		end
	end

	Settings.RegisterAddOnCategory(self.optionsCategory)

	-- Create one option subcategory with characters to display per realm
	for _, realmName in ipairs(realmsAvailable) do
		self.realmSubFramesAndCategoryIds[realmName] = {}
		self.realmSubFramesAndCategoryIds[realmName].frame, self.realmSubFramesAndCategoryIds[realmName].categoryID = AceConfigDialog:AddToBlizOptions(addOnName, realmName, self.optionsCategory:GetID(), realmName)
	end
end

--- Registers this AddOns configurable settings and specifies the layout and graphical elements for the settings panel.
function RackensTracker:RegisterAddOnSettings_Retail()
	-- Register the Options menu
	self.optionsCategory, self.optionsLayout = Settings.RegisterVerticalLayoutCategory(addOnName)
	self.optionsCategory.ID = addOnName
	self.realmSubFramesAndCategoryIds = {}

	local realmsWithCharacters = tFilter(self.db.global.realms, function(realm) return RT.AddonUtil.CountTable(realm.characters) > 0 end, false)
	local realmsAvailable = GetKeysArray(realmsWithCharacters)
	table.sort(realmsAvailable, function(a,b) return a < b end)

	local function OnAddOnSettingChanged(setting, value)
		--Log("setting %s changed to %s", setting:GetVariable(), tostring(value))
	end

	-- Realm data options
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsTrackedRealmsHeader"], nil))
	local realmsDropDownOptionVariable = strformat("%s_%s", addOnName, "shownRealm")
	local realmsDropDownOptionName = L["optionsDropDownDescriptionRealms"]
	local realmsDropDownOptionTooltip = L["optionsDropDownTooltipRealms"]
	local defaultRealmsDropDownOptionValue = self.currentRealm

	local function GetRealmDropdownValue()
		return self.db.global.options.shownRealm
	end

	local function SetRealmDropdownValue(value)
		if (self.db.global.realms[value]) then
			self.db.global.options.shownRealm = value
			self.currentDisplayedRealm = value
		end
	end

	local function GetRealmOptions()
		local container = Settings.CreateControlTextContainer();
		for _, realmName in ipairs(realmsAvailable) do
			container:Add(realmName, realmName)
		end
		return container:GetData();
	end

	local shownRealmSetting = Settings.RegisterProxySetting(self.optionsCategory, realmsDropDownOptionVariable, Settings.VarType.string, realmsDropDownOptionName, defaultRealmsDropDownOptionValue, GetRealmDropdownValue, SetRealmDropdownValue)
	shownRealmSetting:SetValueChangedCallback(OnAddOnSettingChanged)

	Settings.CreateDropdown(self.optionsCategory, shownRealmSetting, GetRealmOptions, realmsDropDownOptionTooltip)
	if (self.db.global.options.shownRealm == nil) then
		shownRealmSetting:SetValue(self.currentRealm, true)
	elseif (not realmsWithCharacters[self.db.global.options.shownRealm]) then
		-- Prevent setting the dropdown to a realm that has no tracked characters on it anymore
		shownRealmSetting:SetValue(self.currentRealm, true)
	else
		shownRealmSetting:SetValue(self.db.global.options.shownRealm, true)
	end

	-- Slider options (minimum character level required to display tracking data)
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsMinimumCharacterLevelHeader"]))
	local showCharactersAtOrBelowLevelOptionName = L["optionsSliderDescriptionShowMinimumCharacterLevel"]
	local showCharactersAtOrBelowLevelOptionTooltip = L["optionsSliderShowMinimumCharacterLevelTooltip"]
	local showCharactersAtOrBelowLevelOptionVariable = strformat("%s_%s", addOnName, "showCharactersAtOrBelowLevel")
	local showCharactersAtOrBelowLevelOptionVariableKey = "showCharactersAtOrBelowLevel"
	local showCharactersAtOrBelowLevelOptionVariableTbl = self.db.global.options
	local defaultShowCharactersAtOrBelowLevelVisibilityValue = database_defaults.global.options.showCharactersAtOrBelowLevel
	local showCharactersAtOrBelowLevelOptionMinValue = 1
	local showCharactersAtOrBelowLevelOptionMaxValue = GetMaxPlayerLevel()
	local showCharactersAtOrBelowLevelOptionSliderStep = 1

	local showCharactersAtOrBelowLevelOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, showCharactersAtOrBelowLevelOptionVariable, showCharactersAtOrBelowLevelOptionVariableKey, showCharactersAtOrBelowLevelOptionVariableTbl, type(defaultShowCharactersAtOrBelowLevelVisibilityValue), showCharactersAtOrBelowLevelOptionName, defaultShowCharactersAtOrBelowLevelVisibilityValue)
	showCharactersAtOrBelowLevelOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	local function FormatLevel(value)
		local levelFormat = "Level %d"
		return levelFormat:format(value)
	end

	local showCharactersAtOrBelowLevelOptions = Settings.CreateSliderOptions(showCharactersAtOrBelowLevelOptionMinValue, showCharactersAtOrBelowLevelOptionMaxValue, showCharactersAtOrBelowLevelOptionSliderStep)
	showCharactersAtOrBelowLevelOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatLevel)

	Settings.CreateSlider(self.optionsCategory, showCharactersAtOrBelowLevelOptionVisibilitySetting, showCharactersAtOrBelowLevelOptions, showCharactersAtOrBelowLevelOptionTooltip)
	showCharactersAtOrBelowLevelOptionVisibilitySetting:SetValue(self.db.global.options[showCharactersAtOrBelowLevelOptionVariableKey], true) -- true means force

	-- Tooltip Enhancement
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsTooltipEnhancementHeader"]))

	local enhanceCurrencyTooltipsOptionName = L["optionsToggleDescriptionEnhanceCurrencyTooltips"]
	local enhanceCurrencyTooltipsOptionTooltip = L["optionsToggleEnhanceCurrencyTooltipsTooltip"]
	local enhanceCurrencyTooltipsOptionVariable = strformat("%s_%s", addOnName, "enhanceCurrencyTooltips")
	local enhanceCurrencyTooltipsOptionVariableKey = "enhanceCurrencyTooltips"
	local enhanceCurrencyTooltipsOptionVariableTbl = self.db.global.options
	local defaultEnhanceCurrencyTooltipsVisibilityValue = database_defaults.global.options.enhanceCurrencyTooltips
	local enhanceCurrencyTooltipsOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, enhanceCurrencyTooltipsOptionVariable, enhanceCurrencyTooltipsOptionVariableKey, enhanceCurrencyTooltipsOptionVariableTbl, type(defaultEnhanceCurrencyTooltipsVisibilityValue), enhanceCurrencyTooltipsOptionName, defaultEnhanceCurrencyTooltipsVisibilityValue)
	enhanceCurrencyTooltipsOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	Settings.CreateCheckbox(self.optionsCategory, enhanceCurrencyTooltipsOptionVisibilitySetting, enhanceCurrencyTooltipsOptionTooltip)
	enhanceCurrencyTooltipsOptionVisibilitySetting:SetValue(self.db.global.options[enhanceCurrencyTooltipsOptionVariableKey], true) -- true means force

	-- Character Data options
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsCharacterDataHeader"]))
	local allCharacterDataOptionName = L["optionsToggleDescriptionShowCharacterData"]
	local allCharacterDataOptionTooltip = L["optionsToggleShowCharacterDataTooltip"]
	local allCharacterDataOptionVariable = strformat("%s_%s", addOnName, "showCharacterData")
	local allCharacterDataOptionVariableKey = "showCharacterData"
	local allCharacterDataOptionVariableTbl = self.db.global.options
	local defaultAllCharacterDataVisibilityValue = database_defaults.global.options.showCharacterData
	local allCharacterDataOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, allCharacterDataOptionVariable, allCharacterDataOptionVariableKey, allCharacterDataOptionVariableTbl, type(defaultAllCharacterDataVisibilityValue), allCharacterDataOptionName, defaultAllCharacterDataVisibilityValue)
	allCharacterDataOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	local allCharacterDataOptionInitializer = Settings.CreateCheckbox(self.optionsCategory, allCharacterDataOptionVisibilitySetting, allCharacterDataOptionTooltip)
	allCharacterDataOptionVisibilitySetting:SetValue(self.db.global.options[allCharacterDataOptionVariableKey], true) -- true means force

	-- Character lvl
	local lvlCharacterDataOptionName = L["optionsToggleDescriptionLvlCharacterData"]
	local lvlCharacterDataOptionTooltip = L["optionsToggleLvlCharacterDataTooltip"]
	local lvlCharacterDataOptionVariable = strformat("%s_%s", addOnName, "showCharacterlvl")
	local lvlCharacterDataOptionVariableKey = "lvl"
	local lvlCharacterDataOptionVariableTbl = self.db.global.options.shownCharacterData
	local defaultLvlCharacterDataVisibilityValue = database_defaults.global.options.shownCharacterData[lvlCharacterDataOptionVariableKey]
	local lvlCharacterDataOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, lvlCharacterDataOptionVariable, lvlCharacterDataOptionVariableKey, lvlCharacterDataOptionVariableTbl, type(defaultLvlCharacterDataVisibilityValue), lvlCharacterDataOptionName, defaultLvlCharacterDataVisibilityValue)
	lvlCharacterDataOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	local lvlCharacterDataOptionInitializer = Settings.CreateCheckbox(self.optionsCategory, lvlCharacterDataOptionVisibilitySetting, lvlCharacterDataOptionTooltip)
	lvlCharacterDataOptionVisibilitySetting:SetValue(self.db.global.options.shownCharacterData[lvlCharacterDataOptionVariableKey], true) -- true means force
	lvlCharacterDataOptionInitializer:SetParentInitializer(allCharacterDataOptionInitializer, function() return allCharacterDataOptionVisibilitySetting:GetValue() end)

	-- Character iLvl
	local iLvlCharacterDataOptionName = L["optionsToggleDescriptioniLvlCharacterData"]
	local iLvlCharacterDataOptionTooltip = L["optionsToggleiLvlCharacterDataTooltip"]
	local iLvlCharacterDataOptionVariable = strformat("%s_%s", addOnName, "showCharacteriLvl")
	local iLvlCharacterDataOptionVariableKey = "iLvl"
	local iLvlCharacterDataOptionVariableTbl = self.db.global.options.shownCharacterData
	local defaultiLvlCharacterDataVisibilityValue = database_defaults.global.options.shownCharacterData[iLvlCharacterDataOptionVariableKey]
	local iLvlCharacterDataOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, iLvlCharacterDataOptionVariable, iLvlCharacterDataOptionVariableKey, iLvlCharacterDataOptionVariableTbl, type(defaultiLvlCharacterDataVisibilityValue), iLvlCharacterDataOptionName, defaultiLvlCharacterDataVisibilityValue)
	iLvlCharacterDataOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	local iLvlCharacterDataOptionInitializer = Settings.CreateCheckbox(self.optionsCategory, iLvlCharacterDataOptionVisibilitySetting, iLvlCharacterDataOptionTooltip)
	iLvlCharacterDataOptionVisibilitySetting:SetValue(self.db.global.options.shownCharacterData[iLvlCharacterDataOptionVariableKey], true) -- true means force
	iLvlCharacterDataOptionInitializer:SetParentInitializer(allCharacterDataOptionInitializer, function() return allCharacterDataOptionVisibilitySetting:GetValue() end)

	-- Character money
	local moneyCharacterDataOptionName = L["optionsToggleDescriptionMoneyCharacterData"]
	local moneyCharacterDataOptionTooltip = L["optionsToggleMoneyCharacterDataTooltip"]
	local moneyCharacterDataOptionVariable = strformat("%s_%s", addOnName, "showCharacterMoney")
	local moneyCharacterDataOptionVariableKey = "money"
	local moneyCharacterDataOptionVariableTbl = self.db.global.options.shownCharacterData
	local defaultMoneyCharacterDataVisibilityValue = database_defaults.global.options.shownCharacterData[moneyCharacterDataOptionVariableKey]
	local moneyCharacterDataOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, moneyCharacterDataOptionVariable, moneyCharacterDataOptionVariableKey, moneyCharacterDataOptionVariableTbl, type(defaultMoneyCharacterDataVisibilityValue), moneyCharacterDataOptionName, defaultMoneyCharacterDataVisibilityValue)
	moneyCharacterDataOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	local moneyCharacterDataOptionInitializer = Settings.CreateCheckbox(self.optionsCategory, moneyCharacterDataOptionVisibilitySetting, moneyCharacterDataOptionTooltip)
	moneyCharacterDataOptionVisibilitySetting:SetValue(self.db.global.options.shownCharacterData[moneyCharacterDataOptionVariableKey], true) -- true means force
	moneyCharacterDataOptionInitializer:SetParentInitializer(allCharacterDataOptionInitializer, function() return allCharacterDataOptionVisibilitySetting:GetValue() end)

	-- Warband options
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsWarbandDataHeader"]))
	local warbandDataOptionName = L["optionsToggleDescriptionShowWarbandData"]
	local warbandDataOptionTooltip = L["optionsToggleShowWarbandDataTooltip"]
	local warbandDataOptionVariable = strformat("%s_%s", addOnName, "showWarbandData")
	local warbandDataOptionVariableKey = "showWarbandData"
	local warbandDataOptionVariableTbl = self.db.global.options
	local defaultWarbandDataVisibilityValue = database_defaults.global.options.showWarbandData
	local warbandDataOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, warbandDataOptionVariable, warbandDataOptionVariableKey, warbandDataOptionVariableTbl, type(defaultWarbandDataVisibilityValue), warbandDataOptionName, defaultWarbandDataVisibilityValue)
	warbandDataOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	local warbandDataOptionInitializer = Settings.CreateCheckbox(self.optionsCategory, warbandDataOptionVisibilitySetting, warbandDataOptionTooltip)
	warbandDataOptionVisibilitySetting:SetValue(self.db.global.options[warbandDataOptionVariableKey], true) -- true means force

	-- Warband bank gold
	local bankGoldWarbandDataOptionName = L["optionsToggleDescriptionWarbandBankGoldData"]
	local bankGoldWarbandDataOptionTooltip = L["optionsToggleWarbandBankGoldDataTooltip"]
	local bankGoldWarbandDataOptionVariable = strformat("%s_%s", addOnName, "showWarbandBankMoney")
	local bankGoldWarbandDataOptionVariableKey = "bankMoney"
	local bankGoldWarbandDataOptionVariableTbl = self.db.global.options.shownWarbandData
	local defaultBankGoldWarbandDataVisibilityValue = database_defaults.global.options.shownWarbandData[bankGoldWarbandDataOptionVariableKey]
	local bankGoldWarbandDataOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, bankGoldWarbandDataOptionVariable, bankGoldWarbandDataOptionVariableKey, bankGoldWarbandDataOptionVariableTbl, type(defaultBankGoldWarbandDataVisibilityValue), bankGoldWarbandDataOptionName, defaultBankGoldWarbandDataVisibilityValue)
	bankGoldWarbandDataOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	local bankGoldWarbandDataOptionInitializer = Settings.CreateCheckbox(self.optionsCategory, bankGoldWarbandDataOptionVisibilitySetting, bankGoldWarbandDataOptionTooltip)
	bankGoldWarbandDataOptionVisibilitySetting:SetValue(self.db.global.options.shownWarbandData[bankGoldWarbandDataOptionVariableKey], true) -- true means force
	bankGoldWarbandDataOptionInitializer:SetParentInitializer(warbandDataOptionInitializer, function() return warbandDataOptionVisibilitySetting:GetValue() end)

	-- Warband total gold
	-- TODO: Research if people can have multiple accounts in one bnet account
	-- RackensTracker has no cross account tracking features so displaying total warband gold will not be reliable.
	-- local totalGoldWarbandDataOptionName = L["optionsToggleDescriptionWarbandTotalGoldData"]
	-- local totalGoldWarbandDataOptionTooltip = L["optionsToggleWarbandTotalGoldDataTooltip"]
	-- local totalGoldWarbandDataOptionVariable = strformat("%s_%s", addOnName, "showWarbandTotalMoney")
	-- local totalGoldWarbandDataOptionVariableKey = "totalMoney"
	-- local totalGoldWarbandDataOptionVariableTbl = self.db.global.options.shownWarbandData
	-- local defaultTotalGoldWarbandDataVisibilityValue = database_defaults.global.options.shownWarbandData[totalGoldWarbandDataOptionVariableKey]
	-- local totalGoldWarbandDataOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, totalGoldWarbandDataOptionVariable, totalGoldWarbandDataOptionVariableKey, totalGoldWarbandDataOptionVariableTbl, type(defaultTotalGoldWarbandDataVisibilityValue), totalGoldWarbandDataOptionName, defaultTotalGoldWarbandDataVisibilityValue)
	-- totalGoldWarbandDataOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	-- local totalGoldWarbandDataOptionInitializer = Settings.CreateCheckbox(self.optionsCategory, totalGoldWarbandDataOptionVisibilitySetting, totalGoldWarbandDataOptionTooltip)
	-- totalGoldWarbandDataOptionVisibilitySetting:SetValue(self.db.global.options.shownWarbandData[totalGoldWarbandDataOptionVariableKey], true) -- true means force
	-- totalGoldWarbandDataOptionInitializer:SetParentInitializer(warbandDataOptionInitializer, function() return warbandDataOptionVisibilitySetting:GetValue() end)

	-- Currency options
	self.optionsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["optionsCurrenciesHeader"]))
	local allCurrencyOptionName = L["optionsToggleDescriptionShowCurrencies"]
	local allCurrencyOptionTooltip = L["optionsToggleShowCurrenciesTooltip"]
	local allCurrencyOptionVariable = strformat("%s_%s", addOnName, "showCurrencies")
	local allCurrencyOptionVariableKey = "showCurrencies"
	local allCurrencyOptionVariableTbl = self.db.global.options
	local defaultAllCurrencyVisibilityValue = database_defaults.global.options.showCurrencies
	local allCurrencyOptionVisibilitySetting = Settings.RegisterAddOnSetting(self.optionsCategory, allCurrencyOptionVariable, allCurrencyOptionVariableKey, allCurrencyOptionVariableTbl, type(defaultAllCurrencyVisibilityValue), allCurrencyOptionName, defaultAllCurrencyVisibilityValue)
	allCurrencyOptionVisibilitySetting:SetValueChangedCallback(OnAddOnSettingChanged)

	local allCurrencyOptionInitializer = Settings.CreateCheckbox(self.optionsCategory, allCurrencyOptionVisibilitySetting, allCurrencyOptionTooltip)
	allCurrencyOptionVisibilitySetting:SetValue(self.db.global.options[allCurrencyOptionVariableKey], true) -- true means force

	for _, currency in ipairs(RT.Currencies) do
		local name = currency:GetName()
		if name and database_defaults.global.options.shownCurrencies[tostring(currency.id)] ~= nil then
			local tooltip =  strformat(L["optionsToggleShowCurrencyTooltip"], name)
			local variable = strformat("%s_showCurrency_%s", addOnName, tostring(currency.id))
			local variableKey = tostring(currency.id)
			local variableTbl = self.db.global.options.shownCurrencies
			local defaultVisibilityValue = database_defaults.global.options.shownCurrencies[variableKey]
			local setting = Settings.RegisterAddOnSetting(self.optionsCategory, variable, variableKey, variableTbl, type(defaultVisibilityValue), name, defaultVisibilityValue)
			setting:SetValueChangedCallback(OnAddOnSettingChanged)
			local initializer = Settings.CreateCheckbox(self.optionsCategory, setting, tooltip)
			setting:SetValue(self.db.global.options.shownCurrencies[variableKey], true) -- true means force
			initializer:SetParentInitializer(allCurrencyOptionInitializer, function() return allCurrencyOptionVisibilitySetting:GetValue() end)
		else
			local err = RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Error, L["errorCurrencyConflictDatabaseDefaults"], currency.id)
			RackensTracker:Printf(err)
		end
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

	-- Initialize the currency info cache, fetching all currencies CurrencyInfo by C_CurrencyInfo.GetCurrencyInfo internally
	for _, currency in ipairs(RT.Currencies) do
		currency:InitializeCurrencyInfoCache()
	end

	-- Level up event
	self:RegisterEvent("PLAYER_LEVEL_UP", "OnEventPlayerLevelUp")

	-- ilvl Tracking
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnPlayerEquipmentChanged")

	-- Register Slash Commands
	self:RegisterChatCommand(addOnName, "HandleSlashCommands")

	-- Update the stored item level for the current character
	-- NOTE: This can't be put in OnInitialize because the function doesnt have access yet to the character data.
	self.currentCharacter.overallIlvl, self.currentCharacter.equippedIlvl = GetAverageItemLevel()
end

--- Called when the addon is disabled
function RackensTracker:OnDisable()
	-- Called when the addon is disabled
	self:UnregisterChatCommand(addOnName)
end

--- Checks eligibility of a character for the tracker
---@return boolean isEligible
function RackensTracker:IsCharacterEligibleForTracking(level)
	return level >= self.db.global.options.showCharactersAtOrBelowLevel
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
	if (self:IsCharacterEligibleForTracking(newLevel)) then
		AceConfigRegistry:NotifyChange(addOnName)
	end
end

--- Called when the player's equipment has changed
---@param event string PLAYER_EQUIPMENT_CHANGED
---@param equipmentSlot number
---@param hasCurrent boolean
function RackensTracker:OnPlayerEquipmentChanged(event, equipmentSlot, hasCurrent)
	self.currentCharacter.overallIlvl, self.currentCharacter.equippedIlvl = GetAverageItemLevel()
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

	local colorizedText = RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Yellow, "%s (%s) - %s", isWeekly and L["weeklyQuest"] or name, displayedQuestTag, status)
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

	local colorizedText = RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Yellow, "%s (%s) - %s", quest.isWeekly and L["weeklyQuest"] or quest.name, questTag, status)
	local labelText = strformat("%s %s", icon, colorizedText)

	questLabel:SetText(labelText)
	return questLabel
end

--- Draws the graphical elements to display character information (ilvl currently)
---@param container AceGUIWidget
---@param characterName string name of the character to render ilvl information for
function RackensTracker:DrawCharacterInfo(container, characterName)
	if (not ContainsIf(self.db.global.options.shownCharacterData, function(characterDataEnabled) return characterDataEnabled end) or not self.db.global.options.showCharacterData) then
		return
	end

	local character = self.db.global.realms[self.currentDisplayedRealm].characters[characterName]

	local characterHeading = AceGUI:Create("Heading")
	characterHeading:SetFullWidth(true)
	characterHeading:SetText(characterName)
	container:AddChild(characterHeading)

	if self.db.global.options.shownCharacterData.lvl then
		local characterLvlLabel = AceGUI:Create("Label")
		characterLvlLabel:SetFullWidth(true)

		local factionIcon
		if character.faction == "Alliance" then
			factionIcon = [[Interface\WORLDSTATEFRAME\AllianceIcon]]
		else
			factionIcon = [[Interface\WORLDSTATEFRAME\HordeIcon]]
		end

		characterLvlLabel:SetImage(factionIcon)
		characterLvlLabel:SetImageSize(22, 22)
		characterLvlLabel:SetText(strformat("%s: %d", L["level"], character.level))

		container:AddChild(characterLvlLabel)
	end

	if self.db.global.options.shownCharacterData.iLvl then
		local characterIlvlLabel = AceGUI:Create("Label")
		characterIlvlLabel:SetFullWidth(true)
		characterIlvlLabel:SetImage([[Interface\PaperDollInfoFrame\UI-EquipmentManager-Toggle]])
		characterIlvlLabel:SetImageSize(22, 22)
		if (character.equippedIlvl ~= 0 or character.overallIlvl ~= 0) then
			characterIlvlLabel:SetText(strformat("%s: %d/%d", L["itemLevel"], character.equippedIlvl, character.overallIlvl))
		else
			characterIlvlLabel:SetText(strformat("%s: %s", L["itemLevel"], L["unknown"]))
		end

		container:AddChild(characterIlvlLabel)
	end

	if self.db.global.options.shownCharacterData.money then
		local moneyLabel = AceGUI:Create("Label")
		moneyLabel:SetFullWidth(true)
		moneyLabel:SetImage([[Interface\MONEYFRAME\UI-GoldIcon]])
		moneyLabel:SetImageSize(22, 22)
		if (character.money ~= nil) then
			local coinAmountTextureString = GetMoneyString(character.money, true)
			moneyLabel:SetText(strformat("%s: %s", L["money"], coinAmountTextureString))
		else
			moneyLabel:SetText(strformat("%s: %s", L["money"], L["unknown"]))
		end

		container:AddChild(moneyLabel)
	end
end

--- Draws the graphical elements to display character information (ilvl currently)
---@param container AceGUIWidget
function RackensTracker:DrawWarbandInfo(container)
	if (not ContainsIf(self.db.global.options.shownWarbandData, function(warbandDataEnabled) return warbandDataEnabled end) or not self.db.global.options.showWarbandData) then
		return
	end

	-- local warbandHeading = AceGUI:Create("Heading")
	-- warbandHeading:SetFullWidth(true)
	-- warbandHeading:SetText(ACCOUNT_QUEST_LABEL)
	-- container:AddChild(warbandHeading)

	if self.db.global.options.shownWarbandData.bankMoney then
		local moneyLabel = AceGUI:Create("Label")
		moneyLabel:SetFullWidth(true)
		moneyLabel:SetImage([[Interface\MONEYFRAME\UI-GoldIcon]])
		moneyLabel:SetImageSize(22, 22)
		if (self.db.global.warband.bank.money ~= nil) then
			local coinAmountTextureString = GetMoneyString(self.db.global.warband.bank.money, true)
			moneyLabel:SetText(strformat("%s: %s", ACCOUNT_BANK_PANEL_TITLE,  coinAmountTextureString))
		else
			moneyLabel:SetText(strformat("%s: %s", ACCOUNT_BANK_PANEL_TITLE, L["unknown"]))
		end

		container:AddChild(moneyLabel)
	end
end

--- Draws the graphical elements to display which realm is currently being viewed
---@param container AceGUIWidget
function RackensTracker:DrawCurrentRealmInfo(container)
	local realmHeading = AceGUI:Create("Heading")
	realmHeading:SetFullWidth(true)
	realmHeading:SetText(self.currentDisplayedRealm)
	container:AddChild(realmHeading)

	-- Display weekly raid reset time
	local raidResetTimeIconLabel = AceGUI:Create("Label")
	local weeklyLockoutText = RackensTracker:GetLockoutTime(true)
	local raidAtlasInfo = C_Texture.GetAtlasInfo("Raid")
	raidResetTimeIconLabel:SetFullWidth(true)
	raidResetTimeIconLabel:SetImage(raidAtlasInfo.file, raidAtlasInfo.leftTexCoord, raidAtlasInfo.rightTexCoord, raidAtlasInfo.topTexCoord, raidAtlasInfo.bottomTexCoord)
	raidResetTimeIconLabel:SetImageSize(22, 22)
	raidResetTimeIconLabel:SetText(weeklyLockoutText)

	container:AddChild(raidResetTimeIconLabel)

	-- Display dungeon daily reset time
	local dungeonResetTimeIconLabel = AceGUI:Create("Label")
	local dungeonLockoutText = RackensTracker:GetLockoutTime(false)
	local dungeonAtlasInfo = C_Texture.GetAtlasInfo("Dungeon")
	dungeonResetTimeIconLabel:SetFullWidth(true)
	dungeonResetTimeIconLabel:SetImage(dungeonAtlasInfo.file, dungeonAtlasInfo.leftTexCoord, dungeonAtlasInfo.rightTexCoord, dungeonAtlasInfo.topTexCoord, dungeonAtlasInfo.bottomTexCoord)
	dungeonResetTimeIconLabel:SetImageSize(22, 22)
	dungeonResetTimeIconLabel:SetText(dungeonLockoutText)

	container:AddChild(dungeonResetTimeIconLabel)
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

--- Returns a formatted string for the lockout time remaining
---@param isRaid boolean
---@return string lockoutFormattedString
function RackensTracker:GetLockoutTime(isRaid)
	if (isRaid and self.db.global.realms[self.currentDisplayedRealm].secondsToWeeklyReset) then
		return strformat("%s: %s", L["raidLockExpiresIn"], RT.TimeUtil.TimeFormatter:Format(self.db.global.realms[self.currentDisplayedRealm].secondsToWeeklyReset))
	end
	if (isRaid == false and self.db.global.realms[self.currentDisplayedRealm].secondsToDailyReset) then
		return strformat("%s: %s", L["dungeonLockExpiresIn"], RT.TimeUtil.TimeFormatter:Format(self.db.global.realms[self.currentDisplayedRealm].secondsToDailyReset))
	end
	return ""
end

--- Returns Saved instance information for a given character by name
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
		instanceColorizedName = RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Normal, "%s", raidInstance.id)
		raidInstanceNameLabels[raidInstanceIndex] = AceGUI:Create("InteractiveLabel")
		raidInstanceNameLabels[raidInstanceIndex]:SetText(instanceColorizedName)
		raidInstanceNameLabels[raidInstanceIndex]:SetFullWidth(true)
		raidInstanceNameLabels[raidInstanceIndex]:SetHeight(labelHeight)
		raidGroup:AddChild(raidInstanceNameLabels[raidInstanceIndex])
		instanceProgress = RT.ColorUtil:FormatEncounterProgress(raidInstance.encountersCompleted, raidInstance.encountersTotal)
		instanceProgressLabel = AceGUI:Create("Label")
		instanceProgressLabel:SetText(strformat("%s: %s", L["progress"], instanceProgress))
		instanceProgressLabel:SetFullWidth(true)
		instanceProgressLabel:SetHeight(labelHeight)

		-- Custom Instance information GameTooltip allowing us to inject information held by any character tracked about bosses killed.

		raidInstanceNameLabels[raidInstanceIndex]:SetCallback("OnEnter", function()
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

		raidInstanceNameLabels[raidInstanceIndex]:SetCallback("OnLeave", function()
			GameTooltip:Hide()
		end)

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
		instanceColorizedName = RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Normal, "%s", dungeonInstance.id)
		dungeonInstanceNameLabels[dungeonInstanceIndex] = AceGUI:Create("InteractiveLabel")
		dungeonInstanceNameLabels[dungeonInstanceIndex]:SetText(instanceColorizedName)
		dungeonInstanceNameLabels[dungeonInstanceIndex]:SetFullWidth(true)
		dungeonInstanceNameLabels[dungeonInstanceIndex]:SetHeight(labelHeight)
		dungeonGroup:AddChild(dungeonInstanceNameLabels[dungeonInstanceIndex])
		instanceProgress = RT.ColorUtil:FormatEncounterProgress(dungeonInstance.encountersCompleted, dungeonInstance.encountersTotal)
		instanceProgressLabel = AceGUI:Create("Label")
		instanceProgressLabel:SetText(strformat("%s: %s", L["progress"], instanceProgress))
		instanceProgressLabel:SetFullWidth(true)
		instanceProgressLabel:SetHeight(labelHeight)

		-- Custom Instance information GameTooltip allowing us to inject information held by any character tracked about bosses killed.
		dungeonInstanceNameLabels[dungeonInstanceIndex]:SetCallback("OnEnter", function()
			GameTooltip:ClearLines()
			GameTooltip:SetOwner(dungeonInstanceNameLabels[dungeonInstanceIndex].frame, "ANCHOR_CURSOR")
			GameTooltip:AddLine(strformat(L["bossesAndIcon"], CreateAtlasMarkup("DungeonSkull", 12, 12)))
			for _, encounterInfo in ipairs(dungeonInstance.encounterInformation) do
				local rightRed = encounterInfo.isKilled and 1 or 0
				local rightGreen = encounterInfo.isKilled and 0 or 1
				GameTooltip:AddDoubleLine(encounterInfo.bossName, encounterInfo.isKilled and BOSS_DEAD or AVAILABLE, 1, 1, 1, rightRed, rightGreen, 0)
			end
			GameTooltip:Show()
		end)

		dungeonInstanceNameLabels[dungeonInstanceIndex]:SetCallback("OnLeave", function()
			GameTooltip:Hide()
		end)

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

--- Returns the appropriate warband related texture information, used to add a texture to the currency tooltip
---@return fileID | nil file
---@return any | nil tooltipTextureInfo
function RackensTracker:GetWarbandRelatedTextureInfo(atlasName)
	local atlas = C_Texture.GetAtlasInfo(atlasName)
	if atlas then
		return atlas.file,
		{
			width = 15, --23,
			height = 20,--31,
			anchor = Enum.TooltipTextureAnchor.RightCenter,
			region = Enum.TooltipTextureRelativeRegion.LeftLine,
			verticalOffset = 0,
			margin = { left = 4, right = 0, top = 0, bottom = 0 },
			texCoords = { left = atlas.leftTexCoord, right = atlas.rightTexCoord, top = atlas.topTexCoord, bottom = atlas.bottomTexCoord },
			vertexColor = { r = 1, g = 1, b = 1, a = 1 },
		}
	end
	return nil, nil
end

--- Draws the graphical elements to display the currencies, given a known character name
---@param container AceGUIWidget
---@param characterName string name of the character to render quests for
function RackensTracker:DrawCurrencies(container, characterName)
	if (not ContainsIf(self.db.global.options.shownCurrencies, function(currencyTypeEnabled) return currencyTypeEnabled end) or not self.db.global.options.showCurrencies) then
		return
	end

	local CurrencyModule = RackensTracker:GetModule("Currencies") --[[@as CurrencyModule]]
	local labelHeight = 20
	local relWidthPerCurrency = 0.25 -- Use a quarter of the container space per item, making new rows as fit.

	---@type table<currencyID, DbCurrency>
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

	local currencyDisplayLabels = {}

	for _, currency in ipairs(RT.Currencies) do
		local currencyInfo = currency:GetCachedCurrencyInfo()
		local colorizedName = currency:GetColorizedName()
		local icon = currency:GetIconTexture(14)
		local nameAndIcon = strformat("%s\n%s", colorizedName, icon)
		local description = currency:GetDescription()
		local useTotalEarnedForMaxQty = currency:GetUseTotalEarnedForMaxQty()
		local maxQuantity = currency:GetMaxQuantity()
		local quantity = 0
		local totalEarned = 0

		if (self.db.global.options.shownCurrencies[tostring(currency.id)]) then
			local characterHeldCurrency = characterCurrencies[currency.id]
			currencyDisplayLabels[currency.id] = AceGUI:Create("InteractiveLabel")
			currencyDisplayLabels[currency.id]:SetHeight(labelHeight)
			currencyDisplayLabels[currency.id]:SetRelativeWidth(relWidthPerCurrency) -- Make each currency take up equal space and give each an extra 10%

			-- If this character has this currency, that means we have quantity information.
			if (characterHeldCurrency) then
				quantity = characterHeldCurrency.quantity
				totalEarned = characterHeldCurrency.totalEarned
			else
				Log("%s is not character held on %s, fetching data from the CurrencyInfo object instead.", currencyInfo.name, characterName)
			end

			-- Cataclysm classic lists currency amounts without abbreviations or thousands separators but retail does
			local quantityDisplay = RT.AddonUtil.IsRetail() and AbbreviateLargeNumbers(quantity) or quantity
			local maxQuantityDisplay = RT.AddonUtil.IsRetail() and AbbreviateLargeNumbers(maxQuantity) or maxQuantity
			local totalEarnedDisplay = RT.AddonUtil.IsRetail() and AbbreviateLargeNumbers(totalEarned) or totalEarned

			if (quantity == 0) then
				local zeroQuantity = RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Gray, quantityDisplay)
				currencyDisplayLabels[currency.id]:SetText(strformat("%s %s", nameAndIcon, zeroQuantity))
			else
				currencyDisplayLabels[currency.id]:SetText(strformat("%s %s", nameAndIcon, quantityDisplay))
				-- Currencies that dont have a seasonal cap but do have a maximum cap.
				if (maxQuantity ~= 0) then
					if not useTotalEarnedForMaxQty then
						local isCapped = quantity == maxQuantity
						local quantityRedColorized = RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Red, "%s", quantityDisplay)
						local maxQuantityRedColorized = RT.ColorUtil:WrapTextInColor(RT.ColorUtil.Color.Red, "%s", maxQuantityDisplay)
						currencyDisplayLabels[currency.id]:SetText(strformat("%s %s/%s", nameAndIcon, isCapped and quantityRedColorized or quantityDisplay, isCapped and maxQuantityRedColorized or maxQuantityDisplay))
					end
				end
			end

			-- Both cataclysm classic and retail uses abbreviations or thousands separators when hovering a currency
			local quantityHoverDisplay = RT.AddonUtil.IsRetail() and quantityDisplay or AbbreviateLargeNumbers(quantity)
			local maxQuantityHoverDisplay = RT.AddonUtil.IsRetail() and maxQuantityDisplay or AbbreviateLargeNumbers(maxQuantity)
			local totalEarnedHoverDisplay = RT.AddonUtil.IsRetail() and totalEarnedDisplay or AbbreviateLargeNumbers(totalEarned)

			-- Custom Currency GameTooltip allowing us to inject information about currencies held by any character tracked.
			currencyDisplayLabels[currency.id]:SetCallback("OnEnter", function()
				GameTooltip:ClearLines()
				GameTooltip:SetOwner(currencyDisplayLabels[currency.id].frame, "ANCHOR_CURSOR")
				GameTooltip:AddLine(colorizedName)

				-- On retail add a tooltip line if the currency is account wide or account transferable and a texture icon
				if RT.AddonUtil.IsRetail() then
					local isAccountWide, isAccountTransferable = currencyInfo.isAccountWide, currencyInfo.isAccountTransferable

					local accountWideOrTransferableText = (isAccountWide and ACCOUNT_LEVEL_CURRENCY) or (isAccountTransferable and ACCOUNT_TRANSFERRABLE_CURRENCY) or nil
					if accountWideOrTransferableText ~= nil then
						GameTooltip:AddLine(accountWideOrTransferableText, RT.ColorUtil.Color.Blue:GetRGB())
						local fileDataId, tooltipTextureInfo = self:GetWarbandRelatedTextureInfo(isAccountWide and "warbands-icon" or "warbands-transferable-icon")
						if tooltipTextureInfo then
						---@diagnostic disable-next-line: redundant-parameter
							GameTooltip:AddTexture(fileDataId, tooltipTextureInfo)
						end
					end
				end

				if (description ~= "") then
					GameTooltip:AddLine(description, nil, nil, nil, true)
				end

				GameTooltip_AddBlankLineToTooltip(GameTooltip)

				--- Display the Total of this currency either if its a seasonal one or a regular one without cap
				if (maxQuantity == 0 or useTotalEarnedForMaxQty) then
					GameTooltip:AddLine(strformat(CURRENCY_TOTAL, RT.ColorUtil.Color.Highlight:GenerateHexColorMarkup(), quantityHoverDisplay))
				end

				-- Display the Total Maximum of this currency that has some sort of maximum cap or seasonal cap
				if (maxQuantity ~= 0) then
					local isRegularCapped = quantity == maxQuantity
					local isSeasonCapped = useTotalEarnedForMaxQty and (totalEarned == maxQuantity)
					if RT.AddonUtil.IsRetail() then
						GameTooltip:AddLine(strformat(useTotalEarnedForMaxQty and CURRENCY_SEASON_TOTAL_MAXIMUM or CURRENCY_TOTAL_CAP, (isRegularCapped or isSeasonCapped) and RT.ColorUtil.Color.Red:GenerateHexColorMarkup() or RT.ColorUtil.Color.Highlight:GenerateHexColorMarkup(), useTotalEarnedForMaxQty and totalEarnedHoverDisplay or quantityHoverDisplay, maxQuantityHoverDisplay))
					else
						GameTooltip:AddLine(strformat(CURRENCY_TOTAL_CAP, (isRegularCapped or isSeasonCapped) and RT.ColorUtil.Color.Red:GenerateHexColorMarkup() or RT.ColorUtil.Color.Highlight:GenerateHexColorMarkup(), useTotalEarnedForMaxQty and totalEarnedHoverDisplay or quantityHoverDisplay, maxQuantityHoverDisplay))
					end
				end

				if RT.AddonUtil.IsRetail() then
					-- Render GameTooltip enhancement with warband total of this currency
					if self.db.global.options.enhanceCurrencyTooltips then
						local isAccountTransferable, warbandTotalQuantity = CurrencyModule:GetTrackedTransferableCurrencyQuantity(currency.id)

						if isAccountTransferable then
							GameTooltip:AddLine(string.format(L["warbandCurrencyTotal"], RT.ColorUtil.Color.Highlight:GenerateHexColorMarkup(), AbbreviateLargeNumbers(warbandTotalQuantity)))
						end
					end

					-- On retail currencies can have a percent loss on transfer
					local isAccountTransferable, transferPercentage = currencyInfo.isAccountTransferable, currencyInfo.transferPercentage
					if isAccountTransferable then
						local percentageLost = transferPercentage and (100 - transferPercentage) or 0;
						if percentageLost > 0 then
							GameTooltip:AddLine(CURRENCY_TRANSFER_LOSS:format(math.ceil(percentageLost)));
						end
					end
				end

				GameTooltip:Show()
			end)

			currencyDisplayLabels[currency.id]:SetCallback("OnLeave", function()
				GameTooltip:Hide()
			end)

			currenciesGroup:AddChild(currencyDisplayLabels[currency.id])
		end
	end
end

--- Callback that runs when the user selects a character tab in the main tracker frame
---@param container AceGUIWidget
---@param event string
---@param characterName string
local function SelectCharacterTab(container, event, characterName)
	container:ReleaseChildren()

	container:PauseLayout()
	-- NOTE: Layout pausing is necessary in order for everything to calculate correctly during rendering
	-- this fixes all my current sizing and anchoring problems, without this all hell breaks loose.
	-- Figured out that every AddChild call runs PerformLayout EVERY TIME and this causes major layout shift and visual glitches
	-- Just pause all layout calculations until after we placed all the widgets on screen.
	RackensTracker:DrawCurrentRealmInfo(container)
	RackensTracker:DrawCharacterInfo(container, characterName)
	if RT.AddonUtil.IsRetail() then
		RackensTracker:DrawWarbandInfo(container)
	end
	--RackensTracker:DrawQuests(container, characterName)
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
	self.tracker_frame:SetWidth(750)
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

	local initialCharacterTab = self.currentCharacter.name
	local initialCharacterTabGuid = self.currentCharacter.guid

	local isInitialCharacterEligible = false

	-- Create one tab per level eligible character
	for characterName, character in pairs(self.db.global.realms[self.currentDisplayedRealm].characters) do
		local optionsKey = strformat("%s.%s", character.realm, characterName)
		if (self.db.global.options.shownCharacters[optionsKey]) then
			if (self:IsCharacterEligibleForTracking(character.level)) then
				if (character.guid == initialCharacterTabGuid and self:IsCharacterEligibleForTracking(character.level)) then
					isInitialCharacterEligible = true
				end
				tabIcon = RT.CharacterUtil:GetCharacterIcon(character.class, tabIconSize)
				tabName = RT.ColorUtil:WrapTextInClassColor(character.class, character.name)
				table.insert(tabsData, {text = strformat("%s %s", tabIcon, tabName), value=characterName})
			end
		end
	end

	-- Do we have ANY level eligible characters at all?
	local isAnyCharacterEligible = #tabsData > 0
	if (isAnyCharacterEligible) then
		-- Add the TabGroup to the main frame
		-- REALLY IMPORTANT THIS ISNT PLACED ON ANY OTHER LINE
		self.tracker_frame:AddChild(self.tracker_tabs)

		self.tracker_tabs:SetTabs(tabsData)
		-- Register callbacks on tab selected
		self.tracker_tabs:SetCallback("OnGroupSelected", SelectCharacterTab)

		if (isInitialCharacterEligible) then
			-- Set initial tab to the current character
			self.tracker_tabs:SelectTab(initialCharacterTab)
		else
			-- If the current character is not eligible, set initial tab to the first available eligible character
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