---@class RT
local RT = select(2, ...)

local strformat = string.format
local GetClassColor = GetClassColor
local ADDON_FONT_COLOR_CODE = "|cff9c5ac4"

local Constants = Constants

local a = Constants.NORMAL_FONT_COLOR_CODE
local NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, ORANGE_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE =
	  NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, ORANGE_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE

---@class Color
local Color = {
    Addon = ADDON_FONT_COLOR_CODE,
	Normal = NORMAL_FONT_COLOR_CODE,
	Highlight = HIGHLIGHT_FONT_COLOR_CODE,
	Gray = GRAY_FONT_COLOR_CODE,
	Green = GREEN_FONT_COLOR_CODE,
	Yellow = YELLOW_FONT_COLOR_CODE,
	Orange = ORANGE_FONT_COLOR_CODE,
	Red = RED_FONT_COLOR_CODE,
}

---@class ColorUtil
local ColorUtil = {
    Color = Color
}

---@param color string A wow color code (including '|c')
---@param format string Same syntax as standard Lua format()
---@param ... any Arguments to the format string
---@return string
--- Formats input text and returns it colorized by given color
function ColorUtil:FormatColor(color, format, ...)
    return color .. strformat(format, ...) .. FONT_COLOR_CODE_CLOSE
end

---@param class ClassBaseName
---@param format string Same syntax as standard Lua format()
---@param ... any Arguments to the format string
---@return string
--- Formats input text and returns it colorized by given player class
function ColorUtil:FormatColorClass(class, format, ...)
    local _, _, _, color = GetClassColor(class)
    return self:FormatColor("|c" .. color, format, ...)
end

---@param progress number
---@param numEncounters number
---@return string?
--- Formats a raid/dungeon encounter progress, returning a specific colorized depending on progress, in the format "progress/numEncounters"
function ColorUtil:FormatEncounterProgress(progress, numEncounters)
    if progress == nil then
        return nil
    end

    local progressColor
    local completionColor
    if (progress == 0) then
        progressColor = GREEN_FONT_COLOR_CODE
        completionColor = GREEN_FONT_COLOR_CODE
    elseif (progress == numEncounters) then
        progressColor = RED_FONT_COLOR_CODE
        completionColor = RED_FONT_COLOR_CODE
    else
        progressColor = ORANGE_FONT_COLOR_CODE
        completionColor = RED_FONT_COLOR_CODE
    end

    local numEncountersColorized = self:FormatColor(completionColor, "%i", numEncounters)
    local progressColorized = self:FormatColor(progressColor, "%i", progress)
    local colorizedText = strformat("%s/%s", progressColorized, numEncountersColorized)
    return colorizedText
end

RT.ColorUtil = ColorUtil