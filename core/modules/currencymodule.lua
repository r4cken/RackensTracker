local addOnName = ...

---@class RT
local RT = select(2, ...)

local UnitName = UnitName
local strtrim = strtrim
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo

local addon = LibStub("AceAddon-3.0"):GetAddon(addOnName) --[[@as RackensTracker]]

---@class CurrencyModule: AceModule, AceConsole-3.0, AceEvent-3.0, AddonModulePrototype
local CurrencyModule = addon:NewModule("Currencies", "AceEvent-3.0")

--- Logs message to the chat frame
---@param message string
---@param ... any
local function Log(message, ...)
	if (addon.LOGGING_ENABLED) then
    	CurrencyModule:DebugLog(message, ...)
	end
end

--- Retrieves all the current players currencies
---@return table<number, DbCurrency> currencies A table of currencies keyed by currencyID
local function GetCharacterCurrencies()
	---@type table<number, DbCurrency>
	local currencies = {}
	-- Iterate over all known currency ID's
	for currencyID = 61, 5000, 1 do
		-- Exclude all currencies that arent useful, deprecated or that we don't want to track
		if (RT.IncludedCurrencyIds[currencyID]) then
		   local currency = GetCurrencyInfo(currencyID)
		   if currency and currency.name ~= nil and strtrim(currency.name) ~= "" then
			currencies[currencyID] =
				{
					currencyID = currencyID,
					name = currency.name,
					description = currency.description or "",
					quantity = currency.quantity,
					maxQuantity = currency.maxQuantity,
					quality = currency.quality,
					iconFileID = currency.iconFileID,
					discovered = currency.discovered,
					totalEarned = currency.totalEarned,
					useTotalEarnedForMaxQty = currency.useTotalEarnedForMaxQty,
					-- Retail Specific additions
					isAccountWide = currency.isAccountWide,
					isAccountTransferable = currency.isAccountTransferable,
					isTradeable = currency.isTradeable,
					transferPercentage = currency.transferPercentage,
				}
		   end
		end
	 end

	return currencies
end

--- Retrieves the current player's money 
---@return number money total amount of money in copper
local function GetCharacterMoney()
	local money = GetMoney()
	return money
end


--- Updates the database with the latest currency information for the current character
function CurrencyModule:UpdateCharacterCurrencies()
	local currencies = GetCharacterCurrencies()
	addon.currentCharacter.currencies = currencies
end

--- Updates the database with the latest money information for the current character
function CurrencyModule:UpdateCharacterMoney()
	local money = GetCharacterMoney()
	addon.currentCharacter.money = money
end

--- Updates the database with the latest money information for the warband bank
function CurrencyModule:UpdateWarbandBankMoney()
	local warbandBankMoney = C_Bank.FetchDepositedMoney(Enum.BankType.Account)
	addon.db.global.warband.bank.money = warbandBankMoney
end

function CurrencyModule:OnEnable()
    -- Currency related events
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "OnEventCurrencyDisplayUpdate")
	self:RegisterEvent("CHAT_MSG_CURRENCY", "OnEventChatMsgCurrency")

	-- Money related events
	self:RegisterEvent("PLAYER_MONEY", "OnEventPlayerMoney")

	if RT.AddonUtil.IsRetail() then
		self:RegisterEvent("ACCOUNT_MONEY", "OnEventAccountMoney")
	end
    -- Update currency information for the currenct logged in character
	self:UpdateCharacterCurrencies()
	self:UpdateCharacterMoney()
end

--- Called when currency information is updated from the server, runs self:UpdateCharacterCurrencies()
---@param currencyType number?
---@param quantity number?
---@param quantityChange number?
---@param quantityGainSource Enum.CurrencySource?
---@param destroyReason Enum.CurrencyDestroyReason?
function CurrencyModule:OnEventCurrencyDisplayUpdate(event, currencyType, quantity, quantityChange, quantityGainSource, destroyReason)
	-- TODO: Investigate if we can skip events with all nil parameters or if we must run UpdateCharacterCurrencies for every triggered event
	if currencyType ~= nil then
		Log("OnEventCurrencyDisplayUpdate")
		Log("Event Data: %s, %s, %s, %s, %s", currencyType or "nil", quantity or "nil", quantityChange or "nil", quantityGainSource or "nil", destroyReason or "nil")
		self:UpdateCharacterCurrencies()
	end
end

--- Called when the player gains currency other than money, such as emblems
function CurrencyModule:OnEventChatMsgCurrency(event, text, playerName)
	Log("OnEventChatMsgCurrency")
	Log("Event Data: %s, %s", text, playerName)
	-- TODO: Maybe we dont need CHAT_MSG_CURRENCY event as it seems that CURRENCY_DISPLAY_UPDATE triggers on both boss kills and quest turn ins.
	-- Also playerName seems to be nil or "" :/
	if (playerName == UnitName("player")) then
		-- We recieved a currency, update character currencies
		-- TODO: maybe use lua pattern matching and match groups to extract the item name and
		-- find out if the item is one of the currencies we are interested in, no idea if the currency name is localized if it's in enUS
		--local itemLink, count = string.match(text, "(|c.+|r) ?x?(%d*).?")
		--local itemInfo = C_CurrencyInfo.GetCurrencyInfoFromLink(itemLink)
		Log("Recieved: " .. text)
		self:UpdateCharacterCurrencies()
	end
end

--- Called whenever the player gains or loses money.
function CurrencyModule:OnEventPlayerMoney()
	Log("OnEventPlayerMoney")
	self:UpdateCharacterMoney()
end

--- Called whenever the warband gains or loses money?
function CurrencyModule:OnEventAccountMoney()
	Log("OnEventAccountMoney")
	self:UpdateWarbandBankMoney()
end