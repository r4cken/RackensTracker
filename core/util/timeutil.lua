local _, RT = ...

local CreateFromMixins, SecondsFormatterMixin, SecondsFormatter =
	  CreateFromMixins, SecondsFormatterMixin, SecondsFormatter

local SecondsFormatterConstants = SecondsFormatterConstants

local TimeFormatter = CreateFromMixins(SecondsFormatterMixin)
TimeFormatter:Init(nil, SecondsFormatter.Abbreviation.Truncate, SecondsFormatterConstants.DontRoundUpLastUnit, SecondsFormatterConstants.DontConvertToLower)
TimeFormatter:SetDesiredUnitCount(3)

local TimeUtil = {
    TimeFormatter = TimeFormatter,
}

RT.TimeUtil = TimeUtil