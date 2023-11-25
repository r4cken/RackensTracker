local addOnName, RT = ... --[[@type string, table]]

local UnitName = UnitName
local strtrim = strtrim
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo

local addon = LibStub("AceAddon-3.0"):GetAddon(addOnName) --[[@as RackensTracker]]

---@class CurrencyModule: AceModule, AceConsole-3.0, AceEvent-3.0, AddonModulePrototype
local CurrencyModule = addon:NewModule("Currencies", "AceEvent-3.0")

local function Log(message, ...)
	if (addon.LOGGING_ENABLED) then
    	CurrencyModule:DebugLog(message, ...)
	end
end

--- Retrieves all the current players currencies
---@return { [string]: DbCurrency } currencies A table of currencies keyed by currencyID
local function GetCharacterCurrencies()
	local currencies = {}
	-- Iterate over all known currency ID's
	for currencyID = 61, 3000, 1 do
		-- Exclude some currencies which arent useful or those that are deprecated
		if (not RT.ExcludedCurrencyIds[currencyID]) then
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
					discovered = currency.discovered
				}
		   end
		end
	 end

	return currencies
end

--- Updates the database with the latest currency information for the current character
function CurrencyModule:UpdateCharacterCurrencies()
	local currencies = GetCharacterCurrencies()
	addon.currentCharacter.currencies = currencies
end

function CurrencyModule:OnEnable()
    -- Currency related events
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "OnEventCurrencyDisplayUpdate")
	self:RegisterEvent("CHAT_MSG_CURRENCY", "OnEventChatMsgCurrency")
    -- Update currency information for the currenct logged in character
	self:UpdateCharacterCurrencies()
end

--- Called when currency information is updated from the server, runs self:UpdateCharacterCurrencies()
function CurrencyModule:OnEventCurrencyDisplayUpdate()
	Log("OnEventCurrencyDisplayUpdate")
	self:UpdateCharacterCurrencies()
end

--- Called when the player gains currency other than money, such as emblems
function CurrencyModule:OnEventChatMsgCurrency(event, text, playerName)
	Log("OnEventChatMsgCurrency")
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