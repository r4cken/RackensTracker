---@class RT
local RT = select(2, ...)

local CreateFromMixins, SecondsFormatterMixin, SecondsFormatter =
	  CreateFromMixins, SecondsFormatterMixin, SecondsFormatter

local SecondsFormatterConstants = SecondsFormatterConstants

local TimeFormatter = CreateFromMixins(SecondsFormatterMixin)
TimeFormatter:Init(nil, SecondsFormatter.Abbreviation.Truncate, SecondsFormatterConstants.DontRoundUpLastUnit, SecondsFormatterConstants.DontConvertToLower)
TimeFormatter:SetDesiredUnitCount(3)

---@class TimeUtil
local TimeUtil = {
    TimeFormatter = TimeFormatter,
}

RT.TimeUtil = TimeUtil