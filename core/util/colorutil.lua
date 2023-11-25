local _, RT = ...

local strformat = string.format
local GetClassColor = GetClassColor
local ADDON_FONT_COLOR_CODE = "|cff9c5ac4"
local NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, ORANGE_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE =
	  NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, ORANGE_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE

local Color = {
    ADDON_FONT_COLOR_CODE = ADDON_FONT_COLOR_CODE,
	NORMAL_FONT_COLOR_CODE = NORMAL_FONT_COLOR_CODE,
	HIGHLIGHT_FONT_COLOR_CODE = HIGHLIGHT_FONT_COLOR_CODE,
	GRAY_FONT_COLOR_CODE = GRAY_FONT_COLOR_CODE,
	GREEN_FONT_COLOR_CODE = GREEN_FONT_COLOR_CODE,
	YELLOW_FONT_COLOR_CODE = YELLOW_FONT_COLOR_CODE,
	ORANGE_FONT_COLOR_CODE = ORANGE_FONT_COLOR_CODE,
	RED_FONT_COLOR_CODE = RED_FONT_COLOR_CODE,
}

local ColorUtil = {
    Color = Color
}

function ColorUtil:FormatColor(color, format, ...)
    return color .. strformat(format, ...) .. FONT_COLOR_CODE_CLOSE
end

function ColorUtil:FormatColorClass(class, format, ...)
    local _, _, _, color = GetClassColor(class)
    return self:FormatColor("|c" .. color, format, ...)
end

function ColorUtil:FormatEncounterProgress(progress, numEncounters)
    if progress == nil then
        return nil
     end
     local color
     if (progress == 0) then
        color = RED_FONT_COLOR_CODE
     elseif (progress == numEncounters) then
        color = GREEN_FONT_COLOR_CODE
     else
        color = ORANGE_FONT_COLOR_CODE
     end

     local progressColorized = self:FormatColor(color, "%i", progress)
     local numEncountersColorized = self:FormatColor(GREEN_FONT_COLOR_CODE, "%i", numEncounters)
     local colorizedTest = strformat("%s/%s", progressColorized, numEncountersColorized)
     return colorizedTest
end

RT.ColorUtil = ColorUtil