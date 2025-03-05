-- Code for the currencies.lua file from the WoW AddOn "InstanceCurrencyTracker" have been taken as and or modified by r4cken
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

---@class RT
local RT = select(2, ...)

local Currency = RT.Currency

if RT.AddonUtil.IsCataClassic() then
    local JusticePoints = Currency:New(395)
    local ValorPoints = Currency:New(396)
    local MoteOfDarkness = Currency:New(614)
    local MarkOfTheWorldTree = Currency:New(416)
    local HonorPoints = Currency:New(1901)
    local ArenaPoints = Currency:New(1900)
    local ConquestPoints = Currency:New(390)
    local TolBaradCommendation = Currency:New(391)
    local ChefsAward = Currency:New(402)
    local EpicureansAward = Currency:New(81)
    local IllustriousJewelcraftersToken = Currency:New(361)
    local JewelcraftersToken = Currency:New(61)
    local DarkmoonPrizeTicket = Currency:New(515)
    local ChampionsSeal = Currency:New(241)
    --local EmblemOfFrost = Currency:New(341)
    --local EmblemOfTriumph = Currency:New(301)
    --local EmblemOfConquest = Currency:New(221)
    --local EmblemOfValor = Currency:New(102)
    --local EmblemOfHeroism = Currency:New(101)
    --local DefilersScourgeStone = Currency:New(2711)
    --local SiderealEssence = Currency:New(2589)
    --local StoneKeepersShards = Currency:New(161)
    --local WintergraspMarks = Currency:New(126)
    --local AlteracValleyMarks = Currency:New(121)
    --local ArathiBasinMarks = Currency:New(122)
    --local EyeOfTheStormMarks = Currency:New(123)
    --local StrandOfTheAncientsMarks = Currency:New(124)
    --local WarsongGulchMarks = Currency:New(125)
    --local IsleOfConquestMarks = Currency:New(321)


    ---@class Currencies
    RT.Currencies = {
        JusticePoints,
        ValorPoints,
        MoteOfDarkness,
        MarkOfTheWorldTree,
        HonorPoints,
        ArenaPoints,
        ConquestPoints,
        TolBaradCommendation,
        ChefsAward,
        EpicureansAward,
        IllustriousJewelcraftersToken,
        JewelcraftersToken,
        DarkmoonPrizeTicket,
        ChampionsSeal,
    }

    ---@class IncludedCurrencyIds
    RT.IncludedCurrencyIds = {
        [395]  = true,  -- Justice Points
        [396]  = true,  -- Valor Points
        [614]  = true,  -- Mote of Darkness
        [416]  = true,  -- Mark Of The World Tree
        [1901] = true,  -- Honor Points
        [1900] = true,  -- Arena Points
        [390]  = true,  -- Conquest Points
        [391]  = true,  -- Tol Barad Commendation
        [402]  = true,  -- Chefs Award
        [81]   = true,	-- Epicurean's Award
        [361]  = true,  -- Illustrious Jewelcrafter's Token
        [61]   = true,	-- Dalaran Jewelcrafter's Token
        [515]  = true,  -- Darkmoon Prize Ticket
        [241]  = true,  -- Champion's Seal
    }
end

if RT.AddonUtil.IsRetail() then
    local Valorstones = Currency:New(3008)
    -- TWW Season 1 Currencies
    -- local WeatheredHarbingerCrest = Currency:New(2914)
    -- local CarvedHarbingerCrest = Currency:New(2915)
    -- local RunedHarbingerCrest = Currency:New(2916)
    -- local GildedHarbingerCrest = Currency:New(2917)

    -- TWW Season 2 Currencies
    local WeatheredUndermineCrest = Currency:New(3107)
    local CarvedUndermineCrest = Currency:New(3108)
    local RunedUndermineCrest = Currency:New(3109)
    local GildedUndermineCrest = Currency:New(3110)

    -- Undermine related Currencies
    local EmptyKajaColaCan = Currency:New(3218)
    local VintageKajaColaCan = Currency:New(3220)
    local MarketResearch = Currency:New(3226)

    local ResonanceCrystals = Currency:New(2815)

    -- TWW Pre patch currency?
    -- local ResidualMemories = Currency:New(3089)

    local Undercoin = Currency:New(2803)
    local Kej = Currency:New(3056)
    local NerubArFinery = Currency:New(3093)
    local RestoredCofferKey = Currency:New(3028)

    -- Timewarping stuff
    local TimewarpedBadge = Currency:New(1166)

    -- PVP currency
    local Honor = Currency:New(1792)
    local Conquest = Currency:New(1602)
    local BloodyTokens = Currency:New(2123)

    -- Fishing derby currency
    local MereldarDerbyMark = Currency:New(3055)

    -- Darkmoon Prize Ticket
    local DarkmoonPrizeTicket = Currency:New(515)

    -- Garrison Resources
    local GarrisonResources = Currency:New(824)

    local TradersTender = Currency:New(2032)

    -- WoW 30th Anniversary currency
    local BronzeCelebrationToken = Currency:New(3100)

    -- 10.0.7 Currencies
    local FlameBlessedIron = Currency:New(3090)

    ---@class Currencies
    RT.Currencies = {
        Valorstones,
        WeatheredUndermineCrest,
        CarvedUndermineCrest,
        RunedUndermineCrest,
        GildedUndermineCrest,
        EmptyKajaColaCan,
        VintageKajaColaCan,
        MarketResearch,
        FlameBlessedIron,
        ResonanceCrystals,
        Undercoin,
        Kej,
        NerubArFinery,
        RestoredCofferKey,
        MereldarDerbyMark,
        TradersTender,
        BronzeCelebrationToken,
        TimewarpedBadge,
        DarkmoonPrizeTicket,
        GarrisonResources,
        Honor,
        Conquest,
        BloodyTokens,
     }

    ---@class IncludedCurrencyIds
    RT.IncludedCurrencyIds = {
        [3008] = true,  -- Valorstones
        [3107] = true,  -- Weathered Undermine Crest
        [3108] = true,  -- Carved Undermine Crest
        [3109] = true,  -- Runed Undermine Crest
        [3110] = true,  -- Gilded Undermine Crest
        [3218] = true,  -- Empty Kaja'Cola Can
        [3220] = true,  -- Vintage Kaja'Cola Can
        [3226] = true,  -- Market Research
        [3090] = true,  -- Flame-Blessed Iron
        [2815] = true,  -- Resonance Crystals
        [2803] = true,  -- Undercoin
        [3056] = true,  -- Kej
        [3093] = true,  -- Nerub-ar Finery
        [3028] = true,  -- Restored Coffer Key
        [3055] = true,  -- Mereldar Derby Mark
        [2032] = true,  -- Trader's Tender
        [3100] = true,  -- Bronze Celebration Token (WoW 30th Anniversary)
        [1166] = true,  -- Timewarped Badge
        [515]  = true,  -- Darkmoon Prize Ticket
        [824]  = true,  -- Garrison Resources
        [1792] = true,  -- Honor
        [1602] = true,  -- Conquest
        [2123] = true,  -- Bloody Tokens
     }
end

for k, v in ipairs(RT.Currencies) do
    v.order = k
end
