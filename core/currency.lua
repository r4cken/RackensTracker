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

---@class RT
local RT = select(2, ...)

local setmetatable, strformat =
      setmetatable, string.format

local CreateTextureMarkup, GetCurrencyInfo =
      CreateTextureMarkup, C_CurrencyInfo.GetCurrencyInfo

local DEFAULT_ICON_SIZE = 16
local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS

---@class Currency
---@field id currencyID
---@field order number
---@field colorizedName string
---@field currencyInfoCache CurrencyInfo

local Currency = {}
RT.Currency = Currency

--- Initializes a Currency object.
function Currency:New(id)
    local currency = { id = id }
    setmetatable(currency, self)
    self.__index = self
    return currency
end

--- Initializes the Currency objects currency info cache.
function Currency:InitializeCurrencyInfoCache()
    ---@type CurrencyInfo
    self.currencyInfoCache = GetCurrencyInfo(self.id)
    --DEFAULT_CHAT_FRAME:AddMessage("Initializing full currency info cache for: " .. self.currencyInfoCache.name)
end

--- Returns a cached CurrencyInfo
---@return CurrencyInfo currency
function Currency:GetCachedCurrencyInfo()
    if not self.currencyInfoCache then self:InitializeCurrencyInfoCache() end
    return self.currencyInfoCache
end

--- Returns the localized name of the currency provided.
---@return string
function Currency:GetName()
    if not self.currencyInfoCache then self:InitializeCurrencyInfoCache() end
    return self.currencyInfoCache.name
end

--- Returns the localized name of the currency colored by its rarity
---@return string
function Currency:GetColorizedName()
    if not self.currencyInfoCache then self:InitializeCurrencyInfoCache() end
    local name, quality = self.currencyInfoCache["name"], self.currencyInfoCache["quality"]
    local colorizedName = strformat("%s%s|r", ITEM_QUALITY_COLORS[quality].hex, name)
    self.colorizedName = self.colorizedName or colorizedName
    return self.colorizedName
end

--- Returns a currencies description, if available
---@return string
function Currency:GetDescription()
    if not self.currencyInfoCache then self:InitializeCurrencyInfoCache() end
    return self.currencyInfoCache.description or ""
end

--- Returns whether the currency has a moving maximum (e.g. seasonal)
function Currency:GetMaxQuantity()
    if not self.currencyInfoCache then self:InitializeCurrencyInfoCache() end
    return self.currencyInfoCache.maxQuantity
end

--- Returns whether the currency has a moving maximum (e.g. seasonal)
function Currency:GetUseTotalEarnedForMaxQty()
    if not self.currencyInfoCache then self:InitializeCurrencyInfoCache() end
    return self.currencyInfoCache.useTotalEarnedForMaxQty
end

--- Returns the icon for the currency as textual markup
---@param iconSize number icon size in UI pixels
---@return string
function Currency:GetIconTexture(iconSize)
    if not self.currencyInfoCache then self:InitializeCurrencyInfoCache() end

    iconSize = iconSize or DEFAULT_ICON_SIZE

    local fileID = self.currencyInfoCache.iconFileID
    local iconTexture = ""

    -- The honor icon needs adjustment for its texture coordinates
    --if self.id == Constants.CurrencyConsts.CLASSIC_HONOR_CURRENCY_ID then
    --    iconTexture = CreateTextureMarkup(fileID, 64, 64, iconSize, iconSize, 0.03125, 0.59375, 0.03125, 0.59375)
    --else
        iconTexture = CreateTextureMarkup(fileID, 64, 64, iconSize, iconSize, 0, 1, 0, 1)
    --end

    return iconTexture
end

--- Returns whether the currency is account wide
---@return boolean isAccountWide
function Currency:IsAccountWide()
    if not self.currencyInfoCache then self:InitializeCurrencyInfoCache() end
    return self.currencyInfoCache.isAccountWide
end

--- Returns whether the currency is account transferable
---@return boolean isAccountWide
function Currency:IsAccountTransferable()
    if not self.currencyInfoCache then self:InitializeCurrencyInfoCache() end
    return self.currencyInfoCache.isAccountTransferable
end

function Currency:__eq(other)
    return self.order == other.order
end

function Currency:__lt(other)
    return self.order < other.order
end