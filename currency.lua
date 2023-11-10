-- Code for the Currency class and some methods in the WoW AddOn "InstanceCurrencyTracker" have been taken as and or modified by r4cken
-- The "InstanceCurrencyTracker" copyright notice is as follows

-- BSD 2-Clause License

-- Copyright (c) 2023, spags

-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:

-- 1. Redistributions of source code must retain the above copyright notice, this
--    list of conditions and the following disclaimer.

-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.

-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
-- SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
-- CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
-- OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


local addOnName, RT = ...
local DEFAULT_ICON_SIZE = 16

local Currency = {}
RT.Currency = Currency

function Currency:New(id, unlimited)
    local currency = { id = id, unlimited = unlimited }
    setmetatable(currency, self)
    self.__index = self
    return currency
end

function Currency:__eq(other)
    return self.order == other.order
end

function Currency:__lt(other)
    return self.order < other.order
end

-- GetCurrencyString(currencyID, overrideAmount, colorCode, abbreviate)
local GetAmountWithIcon = GetCurrencyString

local function GetNameWithIconSize(currencyID, iconSize)
   local currency = C_CurrencyInfo.GetCurrencyInfo(currencyID)
   local iconMarkup = ""
   -- The honor icon needs adjustment for its texture coordinates
   if currencyID == Constants.CurrencyConsts.CLASSIC_HONOR_CURRENCY_ID then
      iconMarkup = CreateTextureMarkup(currency["iconFileID"], 64, 64, iconSize, iconSize, 0.03125, 0.59375, 0.03125, 0.59375)
   else
      iconMarkup = CreateTextureMarkup(currency["iconFileID"], 64, 64, iconSize, iconSize, 0, 1, 0, 1)
   end
   return string.format("%s%s", iconMarkup, currency["name"])
end

-- Returns the localized name of the currency provided.
function Currency:GetName()
    return C_CurrencyInfo.GetCurrencyInfo(self.id)["name"]
end

function Currency:GetColorizedName()
    local currency = C_CurrencyInfo.GetCurrencyInfo(self.id)
    local name, quality = currency["name"], currency["quality"]
    return string.format("%s%s|r", ITEM_QUALITY_COLORS[quality].hex, name)
end

-- Creates a string with the icon and name of the provided currency.
function Currency:GetNameWithIcon()
    self.nameWithIcon = self.nameWithIcon or GetNameWithIconSize(self.id, DEFAULT_ICON_SIZE)
    return self.nameWithIcon
end

 -- Creates a string with the icon and amount of the provided currency.
function Currency:GetAmountWithIcon()
    local amount = C_CurrencyInfo.GetCurrencyInfo(self.id)["quantity"]
    self.amountWithIcon = self.amountWithIcon or GetAmountWithIcon(self.id, amount)
    return self.amountWithIcon
end

-- Returns the amount of currency the player has for the currency provided.
function Currency:GetAmount()
    local amount = C_CurrencyInfo.GetCurrencyInfo(self.id)["quantity"]
end

