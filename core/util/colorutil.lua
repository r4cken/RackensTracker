---@class RT
local RT = select(2, ...)

local strformat = string.format
local CreateColorFromHexString = CreateColorFromHexString

local ADDON_FONT_COLOR = CreateColorFromHexString("ff9c5ac4")
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR, GRAY_FONT_COLOR, GREEN_FONT_COLOR, BLUE_FONT_COLOR, YELLOW_FONT_COLOR, ORANGE_FONT_COLOR, RED_FONT_COLOR, ERROR_COLOR =
	  NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR, GRAY_FONT_COLOR, GREEN_FONT_COLOR, BLUE_FONT_COLOR, YELLOW_FONT_COLOR, ORANGE_FONT_COLOR, RED_FONT_COLOR, ERROR_COLOR

---@class Color
local Color = {
    Addon = ADDON_FONT_COLOR,
	Normal = NORMAL_FONT_COLOR,
	Highlight = HIGHLIGHT_FONT_COLOR,
	Gray = GRAY_FONT_COLOR,
	Green = GREEN_FONT_COLOR,
    Blue = BLUE_FONT_COLOR,
	Yellow = YELLOW_FONT_COLOR,
	Orange = ORANGE_FONT_COLOR,
	Red = RED_FONT_COLOR,
    Error = ERROR_COLOR,
}

---@class ColorUtil
local ColorUtil = {
    Color = Color
}

---@param color ColorMixin Any color thats been created by CreateColor
---@param format string | number
---@param ... any Arguments to the format string
---@return string colorizedText
--- Wraps input text and returns it colorized by given color
function ColorUtil:WrapTextInColor(color, format, ...)
    local text = strformat(format, ...)
    return ("|c%s%s|r"):format(color:GenerateHexColor(), text)
end

---@param class ClassFile
---@param text string
---@return string
--- Formats input text and returns it colorized by given player class
function ColorUtil:WrapTextInClassColor(class, text)
    local classColor
    if C_ClassColor and C_ClassColor.GetClassColor then
        classColor = C_ClassColor.GetClassColor(class)
    else
        classColor = RAID_CLASS_COLORS[class]
    end
    return self:WrapTextInColor(classColor, text)
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
        progressColor = GREEN_FONT_COLOR
        completionColor = GREEN_FONT_COLOR
    elseif (progress == numEncounters) then
        progressColor = RED_FONT_COLOR
        completionColor = RED_FONT_COLOR
    else
        progressColor = ORANGE_FONT_COLOR
        completionColor = RED_FONT_COLOR
    end

    local numEncountersColorized = self:WrapTextInColor(completionColor, "%i", numEncounters)
    local progressColorized = self:WrapTextInColor(progressColor, "%i", progress)
    local colorizedText = strformat("%s/%s", progressColorized, numEncountersColorized)
    return colorizedText
end

RT.ColorUtil = ColorUtil