---@class RT
local RT = select(2, ...)

---@class AddonUtil
local AddonUtil = {}

local IsRetail
do
    local is_retail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

    IsRetail = function()
        return is_retail
    end
end

local IsCataClassic
do
    local is_cata_classic = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC

    IsCataClassic = function()
        return is_cata_classic
    end
end

local function CountTable(tbl)
	local count = 0;
	for k, v in pairs(tbl) do
		count = count + 1;
	end
	return count;
end

AddonUtil.CountTable = CountTable
AddonUtil.IsRetail = IsRetail
AddonUtil.IsCataClassic = IsCataClassic

RT.AddonUtil = AddonUtil