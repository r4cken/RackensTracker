local addOnName, RT = ... --[[@type string, table]]

local LOGGING_ENABLED = false

---@class RackensTracker : AceModule, AceConsole-3.0, AceEvent-3.0
---@field db AceDBObject-3.0
---@field LOGGING_ENABLED boolean
local addon = LibStub("AceAddon-3.0"):NewAddon(RT, addOnName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
addon.LOGGING_ENABLED = LOGGING_ENABLED

---@class AddonModulePrototype
---@field DebugLog function
local modulePrototype = {
    ---@param format string same syntax as standard Lua format()
    ---@param ...? any Arguments to the format string
    DebugLog = function(self, format, ...)
        self:Printf(format, ...)
    end,
}

addon:SetDefaultModuleLibraries("AceConsole-3.0")
addon:SetDefaultModulePrototype(modulePrototype)