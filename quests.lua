local addOnName, RT = ...

local IsLevelAtEffectiveMaxLevel, select, C_QuestLog = 
      IsLevelAtEffectiveMaxLevel, select, C_QuestLog

local isMaxLevel = function(playerLevel)
    return IsLevelAtEffectiveMaxLevel(playerLevel)
end

local getQuestName = function(questID)
    return select(1, C_QuestLog.GetQuestInfo(questID)) or "Unknown"
end

--[[
    24579, Sartharion Must Die!
    24580 (Only Alliance), Anub'Rekhan Must Die!
    24581, Noth the Plaguebringer Must Die!
    24582, Instructor Razuvious Must Die!
    24583, Patchwerk Must Die!
    24584 (Only Horde), Malygos Must Die!
    24585, Flame Leviathan Must Die!
    24586, Razorscale Must Die!
    24587, Ignis the Furnace Master Must Die!
    24588, XT-002 Deconstructor Must Die!
    24589, Lord Jaraxxus Must Die!
    24590, Lord Marrowgar Must Die!
--]]
-- Daily questID's are
-- 78752, Proof of Demise: Titan Rune Protocol Gamma
-- 78753, Proof of Demise: Threats to Azeroth

RT.Quests = {
    [24579] = {
        id = 24579,
        name = getQuestName,
        isWeekly = true,
        faction = nil,
        prerequesite = isMaxLevel,
    },
    [24580] = {
        id = 24580,
        name = getQuestName,
        isWeekly = true,
        faction = "Alliance", -- no need for AceLocale, this is englishFaction returned from UnitFactionGroup(unit)
        prerequesite = isMaxLevel,
    },
    [24581] = {
        id = 24581,
        name = getQuestName,
        isWeekly = true,
        faction = nil,
        prerequesite = isMaxLevel,
    },
    [24582] = {
        id = 24582,
        name = getQuestName,
        isWeekly = true,
        faction = nil,
        prerequesite = isMaxLevel,
    },
    [24583] = {
        id = 24583,
        name = getQuestName,
        isWeekly = true,
        faction = nil,
        prerequesite = isMaxLevel,
    },
    [24584] = {
        id = 24584,
        name = getQuestName,
        isWeekly = true,
        faction = "Horde", -- no need for AceLocale, this is englishFaction returned from UnitFactionGroup(unit)
        prerequesite = isMaxLevel,
    },
    [24585] = {
        id = 24585,
        name = getQuestName,
        isWeekly = true,
        faction = nil,
        prerequesite = isMaxLevel,
    },
    [24586] = {
        id = 24586,
        name = getQuestName,
        isWeekly = true,
        faction = nil,
        prerequesite = isMaxLevel,
    },
    [24587] = {
        id = 24587,
        name = getQuestName,
        isWeekly = true,
        faction = nil,
        prerequesite = isMaxLevel,
    },
    [24588] = {
        id = 24588,
        name = getQuestName,
        isWeekly = true,
        faction = nil,
        prerequesite = isMaxLevel,
    },
    [24589] = {
        id = 24589,
        name = getQuestName,
        isWeekly = true,
        faction = nil,
        prerequesite = isMaxLevel,
    },
    [24590] = {
        id = 24590,
        name = getQuestName,
        isWeekly = true,
        faction = nil,
        prerequesite = isMaxLevel,
    },
    [78752] = {
        id = 78752,
        name = getQuestName,
        isWeekly = false,
        faction = nil,
        prerequesite = isMaxLevel,
    },
    [78753] = {
        id = 78753,
        name = getQuestName,
        isWeekly = false,
        faction = nil,
        prerequesite = isMaxLevel,
    }
}