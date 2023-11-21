-- Code for the ContainsAnyValue function from the WoW AddOn "InstanceCurrencyTracker" have been taken as and or modified by r4cken
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

local string = string

local GetClassColor = GetClassColor
local GREEN_FONT_COLOR_CODE, ORANGE_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE = 
      GREEN_FONT_COLOR_CODE, ORANGE_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE

local Util = {}
RT.Util = Util

function Util:Tablelen(table)
	local count = 0
	for _ in pairs(table) do count = count + 1 end
	return count
end

function Util:ContainsAnyValue(table, predicate)
	for _, value in pairs(table or {}) do
		if predicate and predicate(value) or not predicate and value then
			return true
		end
	end
	return false
end

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

