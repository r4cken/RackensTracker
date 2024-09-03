local addOnName = ...

---@class RT
local RT = select(2, ...)

local UnitName = UnitName
local strtrim = strtrim
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local GetNameAndServerNameFromGUID = GetNameAndServerNameFromGUID

local addon = LibStub("AceAddon-3.0"):GetAddon(addOnName) --[[@as RackensTracker]]

---@class CurrencyModule: AceModule, AceConsole-3.0, AceEvent-3.0, AceHook-3.0, AddonModulePrototype
local CurrencyModule = addon:NewModule("Currencies", "AceEvent-3.0", "AceHook-3.0")

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

	-- Account wide currencies can be updated and stored across all tracked characters at once without needing to login to them.
	if RT.AddonUtil.IsRetail() then
		local accountWideCurrencies = tFilter(currencies, function(currency) return currency.isAccountWide end, false)
		for realmName, realm in pairs(addon.db.global.realms) do
			for characterName, character in pairs(realm.characters) do
				-- Skip the current character as they already have an up to date amount of the account wide currency
				if character.guid ~= addon.currentCharacter.guid then
					for accountWideCurrencyID, accountWideCurrency in pairs(accountWideCurrencies) do
						addon.db.global.realms[realmName].characters[characterName].currencies[accountWideCurrencyID] = accountWideCurrency
					end
				end
			end
		end
	end

end

--- Updates the database whenever a currency transfer has taken place on our tracked characters.
---@param currencyID number
---@param quantityChange number
---@param sourceCharacterGUID WOWGUID
---@param sourceCharacterName string
function CurrencyModule:UpdateSourceCharacterCurrencyAfterTransfer(currencyID, quantityChange, sourceCharacterGUID, sourceCharacterName)
	-- Try and locate the source of the transfer in our database.
	local characterFound = nil
	for _, realm in pairs(addon.db.global.realms) do
		for _, character in pairs(realm.characters) do
			if character.guid == sourceCharacterGUID and character.name == sourceCharacterName then
				characterFound = character
			end
		end
	end

	-- If source character is found then deduct the transfered quantity from this tracked currency as detailed in the transaction
	if characterFound then
		if characterFound.currencies and characterFound.currencies[currencyID] then
			addon.db.global.realms[characterFound.realm].characters[characterFound.name].currencies[currencyID].quantity = addon.db.global.realms[characterFound.realm].characters[characterFound.name].currencies[currencyID].quantity - quantityChange
			Log("Updated character %s on realm %s, currencyID: %d new quantity set to: %d", characterFound.name, characterFound.realm, currencyID, addon.db.global.realms[characterFound.realm].characters[characterFound.name].currencies[currencyID].quantity)
		end
	end
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

---@class TransferData
---@field sourceCharacterGUID WOWGUID
---@field sourceCharacterName string
---@field currencyID number
---@field quantity number

---@return TransferData | nil transferData
--- Returns the last transfer data stored, if any was found
function CurrencyModule:GetLatestTransferData()
	return self.postHookTransferData;
end

---@param transferData TransferData | nil
--- Sets the stored last transfer data object, either from the post hook or when cleared to nil after processing is finished.
function CurrencyModule:SetLatestTransferData(transferData)
	self.postHookTransferData = transferData
end

function CurrencyModule:OnEnable()
    -- Currency related events
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "OnEventCurrencyDisplayUpdate")
	self:RegisterEvent("CHAT_MSG_CURRENCY", "OnEventChatMsgCurrency")

	-- Money related events
	self:RegisterEvent("PLAYER_MONEY", "OnEventPlayerMoney")

    -- Update currency information for the currenct logged in character
	self:UpdateCharacterCurrencies()
	self:UpdateCharacterMoney()

	if RT.AddonUtil.IsRetail() then
		-- Hook C_CurrencyInfo.RequestCurrencyFromAccountCharacter so we can retrieve its parameters to track transfers
		self:SecureHook(C_CurrencyInfo, "RequestCurrencyFromAccountCharacter", "AfterRequestCurrencyFromAccountCharacter")

		self:RegisterEvent("ACCOUNT_MONEY", "OnEventAccountMoney")
		self:UpdateWarbandBankMoney()
	end
end

function CurrencyModule:OnDisable()
	if RT.AddonUtil.IsRetail() then
		self:Unhook(C_CurrencyInfo, "RequestCurrencyFromAccountCharacter")
	end
end

--- Called when currency information is updated from the server, runs self:UpdateCharacterCurrencies()
---@param currencyID number?
---@param quantity number?
---@param quantityChange number?
---@param quantityGainSource Enum.CurrencySource?
---@param destroyReason Enum.CurrencyDestroyReason?
function CurrencyModule:OnEventCurrencyDisplayUpdate(event, currencyID, quantity, quantityChange, quantityGainSource, destroyReason)
	if currencyID ~= nil then
		Log("OnEventCurrencyDisplayUpdate")
		Log("Event Data: %s, %s, %s, %s, %s", currencyID or "nil", quantity or "nil", quantityChange or "nil", quantityGainSource or "nil", destroyReason or "nil")

		if RT.AddonUtil.IsRetail() then
			-- OnEventCurrencyDisplayUpdate was triggered after a manual currency transfer took place
			if quantityGainSource == Enum.CurrencySource.AccountTransfer and destroyReason == 15 then
				local latestTransferData = self:GetLatestTransferData()
				if latestTransferData ~= nil then
					-- Found a currency transfer to our currently logged in character
					if currencyID == latestTransferData.currencyID and quantityChange == latestTransferData.quantity then
						Log("Currency Display Update has matching data for a currency transfer just made!")
						self:UpdateSourceCharacterCurrencyAfterTransfer(currencyID, latestTransferData.quantity, latestTransferData.sourceCharacterGUID, latestTransferData.sourceCharacterName)
					end

					self:SetLatestTransferData(nil)
				end
			end
		end

		self:UpdateCharacterCurrencies()
	end
end

--- Post Hook called when a currency transfer is submitted
---@param sourceCharacterGUID WOWGUID
---@param currencyID number
---@param quantity number
function CurrencyModule:AfterRequestCurrencyFromAccountCharacter(sourceCharacterGUID, currencyID, quantity)
	self:SetLatestTransferData({
		sourceCharacterGUID = sourceCharacterGUID,
		sourceCharacterName = GetNameAndServerNameFromGUID(sourceCharacterGUID),
		currencyID = currencyID,
		quantity = quantity,
	})
	Log("RequestCurrencyFromAccountCharacter called with sourceCharacterGUID: %s, currencyID: %d, quantity: %d", sourceCharacterGUID, currencyID, quantity)
end

--- Called when the player gains currency other than money, such as emblems
function CurrencyModule:OnEventChatMsgCurrency(event, text, playerName)
	--Log("OnEventChatMsgCurrency")
	--Log("Event Data: %s, %s", text, playerName)
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