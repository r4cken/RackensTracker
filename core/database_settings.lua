local _, RT = ...
local DatabaseSettings = {}
RT.DatabaseSettings = DatabaseSettings

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

---@class DatabaseDefaults : AceDB.Schema
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

---@return DatabaseDefaults
function DatabaseSettings:GetDefaults()
    return database_defaults
end
