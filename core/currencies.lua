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

local _, RT = ...

local Currency = RT.Currency

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

RT.ExcludedCurrencyIds = {
    [104] = true,  -- Honor Points DEPRECATED
    [121] = true,  -- Alterac Valley Mark of Honor
    [122] = true,  -- Arathi Basin Mark of Honor
    [123] = true,  -- Eye of the Storm Mark of Honor
    [124] = true,  -- Strand of the Ancients Mark of Honor
    [125] = true,  -- Warsong Gulch Mark of Honor
    [126] = true,  -- Wintergrasp Mark of Honor
    [321] = true,  -- Isle of Conquest Mark of Honor
    [392] = true,  -- Honor Deprecated 3
    [181] = true,  -- Honor Points DEPRECATED2,
    [221] = true,  -- Emblem of Conquest
    [341] = true,  -- Emblem of Frost
    [101] = true,  -- Emblem of Heroism
    [301] = true,  -- Emblem of Triumph
    [102] = true,  -- Emblem of Valor
    [2589] = true, -- Sidereal Essence
    [161] = true,  -- Stone Keeper's Shard
    [2711] = true, -- Defiler's Scourgestone
}

for k, v in ipairs(RT.Currencies) do
    v.order = k
end
