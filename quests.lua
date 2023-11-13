local addOnName, RT = ...

local isMaxLevel = function(playerLevel)
    return IsLevelAtEffectiveMaxLevel(playerLevel)
end

local getQuestName = function(questID)
    return select(1, C_QuestLog.GetQuestInfo(questID)) or "Unknown"
end

RT.Quests = {
    Weekly = {
        [24579] = {
            id = 24579,
            name = getQuestName,
            weekly = true,
            faction = nil,
            prerequesite = isMaxLevel,
        },
        [24580] = {
            id = 24580,
            name = getQuestName,
            weekly = true,
            faction = "Alliance", -- checked with UnitFactionGroup(unit)
            prerequesite = isMaxLevel,
        },
        [24581] = {
            id = 24581,
            name = getQuestName,
            weekly = true,
            faction = nil,
            prerequesite = isMaxLevel,
        },
        [24582] = {
            id = 24582,
            name = getQuestName,
            weekly = true,
            faction = nil,
            prerequesite = isMaxLevel,
        },
        [24583] = {
            id = 24583,
            name = getQuestName,
            weekly = true,
            faction = nil,
            prerequesite = isMaxLevel,
        },
        [24584] = {
            id = 24584,
            name = getQuestName,
            weekly = true,
            faction = "Horde",
            prerequesite = isMaxLevel,
        },
        [24585] = {
            id = 24585,
            name = getQuestName,
            weekly = true,
            faction = nil,
            prerequesite = isMaxLevel,
        },
        [24586] = {
            id = 24586,
            name = getQuestName,
            weekly = true,
            faction = nil,
            prerequesite = isMaxLevel,
        },
        [24587] = {
            id = 24587,
            name = getQuestName,
            weekly = true,
            faction = nil,
            prerequesite = isMaxLevel,
        },
        [24588] = {
            id = 24588,
            name = getQuestName,
            weekly = true,
            faction = nil,
            prerequesite = isMaxLevel,
        },
        [24589] = {
            id = 24589,
            name = getQuestName,
            weekly = true,
            faction = nil,
            prerequesite = isMaxLevel,
        },
        [24590] = {
            id = 24590,
            name = getQuestName,
            weekly = true,
            faction = nil,
            prerequesite = isMaxLevel,
        },
        
    },
    Daily = {
        [78752] = {
            id = 78752,
            name = getQuestName,
            weekly = false,
            faction = nil,
            prerequesite = isMaxLevel,
        },
        [78753] = {
            id = 78753,
            name = getQuestName,
            weekly = false,
            faction = nil,
            prerequesite = isMaxLevel,
        }
    }
}