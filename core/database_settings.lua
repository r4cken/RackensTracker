---@class RT
local RT = select(2, ...)

---@class DatabaseSettings
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
---@field quality Enum.ItemQuality
---@field iconFileID fileID
---@field discovered boolean
-- Returns 0 if useTotalEarnedForMaxQty is false,
-- prevents earning if equal to maxQuantity
---@field totalEarned number
-- Whether the currency has a moving maximum (e.g seasonal)
---@field useTotalEarnedForMaxQty boolean
---@field isAccountWide boolean?
---@field isAccountTransferable boolean?
---@field isTradeable boolean?
---@field transferPercentage number?

---@class (exact) DbSavedInstanceEncounterInformation
---@field bossName string
---@field isKilled boolean
---@field fileDataID number

---@class (exact) DbSavedInstance
---@field savedInstanceIndex number
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
---@field toggleDifficultyID number?
---@field encountersTotal number
---@field encountersCompleted number
---@field encounterInformation table<number, DbSavedInstanceEncounterInformation>

---@class (exact) DbCharacter
---@field name string|nil
---@field class string|nil
---@field level string|nil
---@field realm string|nil
---@field faction string|nil
---@field guid string|nil
---@field overallIlvl number
---@field equippedIlvl number
---@field savedInstances table<string, DbSavedInstance>
---@field currencies table<currencyID, DbCurrency>
---@field quests table<questID, DbQuest>

---@class DatabaseDefaults : AceDB.Schema

local shownCurrencies = {}
do
	if RT.AddonUtil.IsCataClassic() then
		shownCurrencies = {
			["395"] = true,  -- Justice Points
			["396"] = true,  -- Valor Points
			["614"] = false, -- Mote of Darkness
			["416"] = false, -- Mark Of The World Tree
			["1901"] = true, -- Honor Points
			["1900"] = true, -- Arena Points
			["390"] = true,  -- Conquest Points
			["391"] = true,  -- Tol Barad Commendation
			["402"] = true,  -- Chefs Award
			["81"] = false,	 -- Epicurean's Award
			["361"] = true,  -- Illustrious Jewelcrafter's Token
			["61"] = false,	 -- Dalaran Jewelcrafter's Token
			["515"] = true,  -- Darkmoon Prize Ticket
			["241"] = false, -- Champion's Seal
		}
	end

	if RT.AddonUtil.IsRetail() then
		shownCurrencies = {
			["3008"] = true,  -- Valorstones
			["3107"] = true,  -- Weathered Undermine Crest
			["3108"] = true,  -- Carved Undermine Crest
			["3109"] = true,  -- Runed Undermine Crest
			["3110"] = true,  -- Gilded Undermine Crest
			["3116"] = true,  -- Essence Of Kaja'Mite
			["3218"] = true,  -- Empty Kaja'Cola Can
			["3220"] = true,  -- Vintage Kaja'Cola Can
			["3226"] = true,  -- Market Research
			["3090"] = true,  -- Flame-Blessed Iron
			["2815"] = true,  -- Resonance Crystals
			["2803"] = true,  -- Undercoin
			["3056"] = true,  -- Kej
			["3093"] = true,  -- Nerub-ar Finery
			["3028"] = true,  -- Restored Coffer Key
			["3055"] = true,  -- Mereldar Derby Mark
			["2032"] = true,  -- Trader's Tender
			["3100"] = true,  -- Bronze Celebration Token (30th Anniversary)
			["1166"] = true,  -- Timewarped Badge
			["515"]  = true,  -- Darkmoon Prize Ticket
			["824"]  = false, -- Garrison Resources
			["1792"] = true,  -- Honor
			["1602"] = true,  -- Conquest
			["2123"] = true,  -- Bloody Tokens
		}
	end
end

local database_defaults = {
	global = {
		options = {
			showCurrencies = true,
			shownCurrencies = shownCurrencies,
			enhanceCurrencyTooltips = true,
			showCharactersAtOrBelowLevel = 1,
			shownCharacters = {
				['*'] = true
			},
			showWarbandData = true,
			shownWarbandData = {
				["bankMoney"] = true,
			},
			showCharacterData = true,
			shownCharacterData = {
				["iLvl"] = true,
				["lvl"] = true,
				["money"] = true,
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
						overallIlvl = 0,
						equippedIlvl = 0,
						money = nil,
						savedInstances = {},
						currencies = {},
						quests = {},
					}
				}
			}
		},
		warband = {
			bank = {
				money = nil
			}
		},
	},
	char = {
		minimap = {
			hide = false
		}
	},
}
--- Returns all the default settings for the AceDB
---@return DatabaseDefaults database_defaults
function DatabaseSettings:GetDefaults()
    return database_defaults
end
