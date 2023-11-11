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

local addOnName, RT = ...

local Currency = RT.Currency

RT.EmblemOfFrost = Currency:New(341)
RT.EmblemOfTriumph = Currency:New(301)
RT.DefilersScourgeStone = Currency:New(2711)
RT.SiderealEssence = Currency:New(2589)
RT.EmblemOfConquest = Currency:New(221)
RT.EmblemOfValor = Currency:New(102)
RT.EmblemOfHeroism = Currency:New(101)
RT.ChampionsSeal = Currency:New(241)
RT.EpicureansAward = Currency:New(81)
RT.JewelcraftersToken = Currency:New(61)
RT.StoneKeepersShards = Currency:New(161)
RT.HonorPoints = Currency:New(1901)
RT.ArenaPoints = Currency:New(1900)
-- RT.AlteracValleyMarks = Currency:New(121)
-- RT.ArathiBasinMarks = Currency:New(122)
-- RT.EyeOfTheStormMarks = Currency:New(123)
-- RT.StrandOfTheAncientsMarks = Currency:New(124)
-- RT.WarsongGulchMarks = Currency:New(125)
-- RT.WintergraspMarks = Currency:New(126)
-- RT.IsleOfConquestMarks = Currency:New(321)


RT.Currencies = {
    RT.EmblemOfFrost,
    RT.EmblemOfTriumph,
    RT.EmblemOfConquest,
    RT.EmblemOfValor,
    RT.EmblemOfHeroism,
    RT.DefilersScourgeStone,
    RT.SiderealEssence,
    RT.ChampionsSeal,
    RT.HonorPoints,
    RT.ArenaPoints,
    RT.StoneKeepersShards,
    RT.EpicureansAward,
    RT.JewelcraftersToken,
    -- TODO: Maybe add the Wintergrasp Mark of Honor currency, but make sure to handle it properly with the hide/show options
    --RT.WintergraspMarks,
}

RT.ExcludedCurrencyIds = {  
    [121] = true, -- Alterac Valley Mark of Honor
    [122] = true, -- Arathi Basin Mark of Honor
    [123] = true, -- Eye of the Storm Mark of Honor
    [124] = true, -- Strand of the Ancients Mark of Honor
    [125] = true, -- Warsong Gulch Mark of Honor
    [126] = true, -- Wintergrasp Mark of Honor
    [181] = true, -- Honor Points DEPRECATED2,
    [321] = true  -- Isle of Conquest Mark of Honor
}

for k, v in ipairs(RT.Currencies) do
    v.order = k
end
