local addOnName, RT = ...

local string = string

local GetClassColor = GetClassColor
local NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, ORANGE_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE =
	  NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, ORANGE_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE

local Util = {}
local Color = {
	NORMAL_FONT_COLOR_CODE = NORMAL_FONT_COLOR_CODE,
	HIGHLIGHT_FONT_COLOR_CODE = HIGHLIGHT_FONT_COLOR_CODE,
	GRAY_FONT_COLOR_CODE = GRAY_FONT_COLOR_CODE,
	GREEN_FONT_COLOR_CODE = GREEN_FONT_COLOR_CODE,
	YELLOW_FONT_COLOR_CODE = YELLOW_FONT_COLOR_CODE,
	ORANGE_FONT_COLOR_CODE = ORANGE_FONT_COLOR_CODE,
	RED_FONT_COLOR_CODE = RED_FONT_COLOR_CODE,
}

RT.Util = Util
RT.Util.Color = Color

function Util:FormatColor(color, message, ...)
    return color .. string.format(message, ...) .. FONT_COLOR_CODE_CLOSE
end

function Util:FormatColorClass(class, message, ...)
    local _, _, _, color = GetClassColor(class)
    return Util:FormatColor("|c" .. color, message, ...)
end

function Util:FormatEncounterProgress(progress, numEncounters)
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

	local progressColorized = Util:FormatColor(color, "%i", progress)
	local numEncountersColorized = Util:FormatColor(GREEN_FONT_COLOR_CODE, "%i", numEncounters)

	return progressColorized .. "/" .. numEncountersColorized
end

---@param level number
function Util:IsCharacterAtEffectiveMaxLevel(level)
	return level >= GetMaxPlayerLevel();
end