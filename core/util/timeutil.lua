local _, RT = ...

local CreateFromMixins, SecondsFormatterMixin, SecondsFormatter =
	  CreateFromMixins, SecondsFormatterMixin, SecondsFormatter

local TimeFormatter = CreateFromMixins(SecondsFormatterMixin)
TimeFormatter:Init(nil, SecondsFormatter.Abbreviation.Truncate, false, true)

local TimeUtil = {
    TimeFormatter = TimeFormatter,
}

RT.TimeUtil = TimeUtil