local _, RT = ...
local DatabaseSettings = {}
RT.DatabaseSettings = DatabaseSettings

---@alias questID number
---@alias currencyID number

---@class (exact) DbQuest
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
---@field craftedFromHeuristicGuess boolean?

---@class (exact) DbCurrency
---@field currencyID currencyID
---@field name string
---@field description string
---@field quantity number
---@field maxQuantity number
---@field quality number
---@field iconFileID string	
---@field discovered boolean

---@class (exact) DbSavedInstance
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
---@field toggleDifficultyID number
---@field encountersTotal number
---@field encountersCompleted number

---@class (exact) DbCharacter
---@field name string|nil
---@field class string|nil
---@field level string|nil
---@field realm string|nil
---@field faction string|nil
---@field guid string|nil
---@field savedInstances table<string, DbSavedInstance>
---@field currencies table<currencyID, DbCurrency>
---@field quests table<questID, DbQuest>

---@class DatabaseDefaults : AceDB.Schema
local database_defaults = {
	global = {
		options = {
			showCurrencies = true,
			shownCurrencies = {
				["395"] = true,  -- Justice Points
				["396"] = true,  -- Valor Points
				["341"] = false, -- Emblem of Frost
				["301"] = false, -- Emblem of Triumph
				["221"] = false, -- Emblem of Conquest
				["102"] = false, -- Emblem of Valor
				["101"] = false, -- Emblem of Heroism
				["2711"] = false,-- Defiler's Scourgestone
				["2589"] = false,-- Sidreal Essence
				["241"] = false, -- Champion's Seal
				["1901"] = true, -- Honor Points
				["1900"] = true, -- Arena Points
				["390"] = true,  -- Conquest Points
				["161"] = true,  -- Stone Keeper's Shard
				["391"] = true,  -- Tol Barad Commendation
				["402"] = true,  -- Chefs Award
				["81"] = false,	 -- Epicurean's Award
				["361"] = true,  -- Illustrious Jewelcrafter's Token
				["61"] = false,	 -- Dalaran Jewelcrafter's Token
				["515"] = true,  -- Darkmoon Prize Ticket
			},
			shownCharacters = {
				['*'] = true
			},
			showQuests = false,
			shownQuests = {
				["Weekly"] = true,
				["Daily"] = true,
			},
			shownRealm = nil,
		},
		realms = {
			['*'] = {
				weeklyResetTime = nil,
				secondsToWeeklyReset = nil,
				dailyResetTime = nil,
				secondsToDailyReset = nil,
				selectedCharacterForDeletion = nil,
				---@type table<string, DbCharacter>
				characters = {
					['*'] = {
						name = nil,
						class = nil,
						level = nil,
						realm = nil,
						faction = nil,
						guid = nil,
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
