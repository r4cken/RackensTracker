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

local setmetatable, string =
      setmetatable, string

local CreateTextureMarkup, C_CurrencyInfo =
      CreateTextureMarkup, C_CurrencyInfo

local DEFAULT_ICON_SIZE = 16

local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS
local Constants = Constants

local Currency = {}
RT.Currency = Currency

function Currency:New(id)
    local currency = { id = id }
    setmetatable(currency, self)
    self.__index = self
    return currency
end

-- Returns the localized name of the currency provided.
function Currency:GetName()
    self.name = self.name or C_CurrencyInfo.GetCurrencyInfo(self.id)["name"]
    return self.name
end

function Currency:GetColorizedName()
    local currency = C_CurrencyInfo.GetCurrencyInfo(self.id)
    local name, quality = currency["name"], currency["quality"]
    local colorizedName = string.format("%s%s|r", ITEM_QUALITY_COLORS[quality].hex, name)
    self.colorizedName = self.colorizedName or colorizedName
    return self.colorizedName
end

function Currency:GetIcon(iconSize)
    iconSize = iconSize or DEFAULT_ICON_SIZE

    local fileID = C_CurrencyInfo.GetCurrencyInfo(self.id)["iconFileID"]
    local iconTexture = ""

    -- The honor icon needs adjustment for its texture coordinates
    if self.id == Constants.CurrencyConsts.CLASSIC_HONOR_CURRENCY_ID then
        iconTexture = CreateTextureMarkup(fileID, 64, 64, iconSize, iconSize, 0.03125, 0.59375, 0.03125, 0.59375)
    else
        iconTexture = CreateTextureMarkup(fileID, 64, 64, iconSize, iconSize, 0, 1, 0, 1)
    end

    self.icon = self.icon or iconTexture
    return self.icon
end

-- Returns the current amount of a currency the player has, or a provided overrideAmount is used
function Currency:GetAmount(overrideAmount)
    if (overrideAmount) then
        return overrideAmount
    else
        self.quantity = self.quantity or C_CurrencyInfo.GetCurrencyInfo(self.id)["quantity"]
    end
end

function Currency:__eq(other)
    return self.order == other.order
end

function Currency:__lt(other)
    return self.order < other.order
end