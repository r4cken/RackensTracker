local addOnName, RT = ...

local table, math, type, string, strsplit, pairs, ipairs = 
	  table, math, type, string, strsplit, pairs, ipairs

local GetServerTime, SecondsToTime = 
	  GetServerTime, SecondsToTime

local RequestRaidInfo, GetDifficultyInfo, GetNumSavedInstances, GetSavedInstanceInfo = 
	  RequestRaidInfo, GetDifficultyInfo, GetNumSavedInstances, GetSavedInstanceInfo

local C_CurrencyInfo, GetCurrencyInfo = 
	  C_CurrencyInfo, GetCurrencyInfo

local UnitName, UnitClassBase, UnitLevel, GetClassAtlas, CreateAtlasMarkup = 
	  UnitName, UnitClassBase, UnitLevel, GetClassAtlas, CreateAtlasMarkup

local NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE =
	  NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE


local CLASS_ICON_TCOORDS = CLASS_ICON_TCOORDS -- see Blizz UI SharedConstants.lua

local RackensTracker = LibStub("AceAddon-3.0"):NewAddon("RackensTracker", "AceConsole-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local database_defaults = {
	global = { },
	char = {
		minimap = {
			hide = false
		}
	},
	realm = {
		currentlyKnownRaidResetTime = nil,
		currentlyKnownDungeonResetTime = nil,
		characters = {
			--Indexed by characterName
			--[[
				["realmname.character"] = {
					name = "Racken",
					class = "ROGUE",
					realm = Earthshaker
					savedInstances = {
						{
							["instanceName"] = instanceName,
							["instanceID"] = instanceID,
							["lockoutID"] = lockoutID,
							["resetsIn"] = expiresAt,
							["isLocked"] = isLocked,
							["isRaid"] = isRaid,
							["isHeroic"] = isHeroic,
							["maxPlayers"] = maxPlayers,
							["difficultyID"] = difficultyID,
							["difficultyName"] = difficultyName,
							["encountersTotal"] = numEncounters,
							["encounterCompleted"] = encounterProgress,
						}
					},
					currencies = {
						{
							currencyID = currencyID,
							name = name,
							amount = amount,
							quality = currencyData.quality,
							iconFileID = iconFileID,
							earnedThisWeek = earnedThisWeek,
							weeklyMax = weeklyMax,
							totalMax = totalMax,
							isDiscovered = isDiscovered
						}
					}
				}
			--]]
			['*'] = {
				name = nil,
				class = nil,
				realm = nil,
				savedInstances = {},
				currencies = {}
			}
		}
	}
}

local function Log(message, ...)
    RackensTracker:Printf(message, ...)
end


local function GetCharacterLockouts()
	local savedInstances = {}

	local nSavedInstances = GetNumSavedInstances()
	if (nSavedInstances > 0) then
		for i = 1, MAX_RAID_INFOS do -- blizz ui stores max 20 entries per character so why not follow suit
			if ( i <= nSavedInstances) then
				local instanceName, lockoutID, resetsIn, difficultyID, isLocked, _, _, isRaid, maxPlayers, difficultyName, encountersTotal, encountersCompleted, _, instanceID = GetSavedInstanceInfo(i)
				local _, _, isHeroic, _, _, _, _ = GetDifficultyInfo(difficultyID);
	
				-- Only store active lockouts
				if resetsIn > 0 and isLocked then
					table.insert(savedInstances, {
						instanceName = instanceName,
						instanceID = instanceID,
						lockoutID = lockoutID,
						resetsIn = resetsIn, -- Can be printed with SecondsToTime(resetsIn, true, nil, 3)); do comparisons on it with resetsIn + GetServerTime()
						isLocked = isLocked,
						isRaid = isRaid,
						isHeroic = isHeroic,
						maxPlayers = maxPlayers,
						difficultyID = difficultyID,
						difficultyName = difficultyName,
						encountersTotal = encountersTotal,
						encountersCompleted = encountersCompleted
					})
				end
			end
		end
	end

	return savedInstances
end

-- TODO: Might not be needed as we retrive all currency information once we load a tab in the UI for the specified character.
-- Update currency information for the currenct logged in character
local function GetCharacterCurrencies()
	local currencies = {}

	local name, amount, iconFileID, earnedThisWeek, weeklyMax, totalMax, isDiscovered =  nil,nil,nil,nil,nil,nil,nil,nil;
	local currencyData, quality

	-- Iterate over all known currency ID's
	for currencyID = 61, 3000, 1 do
		name, amount, iconFileID, earnedThisWeek, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(currencyID);
		
		if (not RT.ExcludedCurrencyIds[currencyID]) then
			currencyData = C_CurrencyInfo.GetCurrencyInfo(currencyID)
			if name ~= nil and name:trim() ~= "" and currencyData ~= nil then
				table.insert(currencies, {
					currencyID = currencyID,
					name = name,
					amount = amount,
					quality = currencyData.quality,
					iconFileID = iconFileID,
					earnedThisWeek = earnedThisWeek,
					weeklyMax = weeklyMax,
					totalMax = totalMax,
					isDiscovered = isDiscovered
				})
			end
		end
	end

	return currencies
end


function RackensTracker:UpdateCharacterLockouts()
	local savedInstances = GetCharacterLockouts()

	self.charDB.savedInstances = savedInstances
end


function RackensTracker:UpdateCharacterCurrencies()
	local currencies = GetCharacterCurrencies()

	self.charDB.currencies = currencies
end

function RackensTracker:UpdateCharacterLevel(newLevel)
	self.charDB.level = newLevel
end

-- function RackensTracker:RetrieveAllSavedInstanceInformation()
-- 	-- Will contain elements with the keys
-- 	--[[
-- 		id = realmname.charactername, name = "Whacken", class = "ROGUE", colorName = "Whacken" 
-- 	--]]
-- 	local characters = RT.Container:New()
-- 	local raidInstances = RT.Container:New()
-- 	local dungeonInstances = RT.Container:New()
-- 	local lockoutInformation = {}
	
-- 	for characterID, character in pairs(self.db.realm.characters) do
-- 		local characterHasLockouts = false

-- 		for _, savedInstance in pairs(character.savedInstances) do
-- 			if savedInstance.resetsIn + GetServerTime() > GetServerTime() then
-- 				local isRaid = savedInstance.isRaid
-- 				if isRaid == nil then
-- 					isRaid = true
-- 				end

-- 				local instance = RT.Instance:New(
-- 					savedInstance.instanceName,
-- 					savedInstance.instanceID,
-- 					savedInstance.lockoutID,
-- 					savedInstance.resetsIn,
-- 					savedInstance.isRaid,
-- 					savedInstance.isHeroic,
-- 					savedInstance.maxPlayers,
-- 					savedInstance.difficultyID,
-- 					savedInstance.difficultyName,
-- 					savedInstance.encountersTotal,
-- 					savedInstance.encountersCompleted)
-- 					if (isRaid) then
-- 						if (raidInstances:Add(instance)) then
-- 							lockoutInformation[instance.id] = {}
-- 						end
-- 						lockoutInformation[instance.id][characterID]["resetDatetime"] = SecondsToTime(instance.resetsIn, true, nil, 3)
-- 						lockoutInformation[instance.id][characterID]["progress"] = RT.Util:FormatEncounterProgress(instance.encountersCompleted, instance.encountersTotal)

-- 					else
-- 						if (dungeonInstances:Add(instance)) then
-- 							lockoutInformation[instance.id] = {}
-- 						end

-- 						lockoutInformation[instance.id][characterID]["resetDatetime"] = SecondsToTime(instance.resetsIn, true, nil, 3)
-- 						lockoutInformation[instance.id][characterID]["progress"] = RT.Util:FormatEncounterProgress(instance.encountersCompleted, instance.encountersTotal)
-- 					end


-- 				characterHasLockouts = true
-- 			end
-- 		end

-- 		if (characterHasLockouts) then
-- 			characters:Add(RT.Character:New(characterID, character.class))
-- 		end
-- 	end

-- 	return characters, raidInstances, dungeonInstances, lockoutInformation
-- end


-- local classNameAndIcon = AceGUI:Create("Label")
-- local classColorName = RT.Util:FormatColorClass(charDB.class, charDB.name)
-- local iconSize = 32
-- local nameSize = 200
-- classNameAndIcon:SetImage("Interface\\TargetingFrame\\UI-Classes-Circles", unpack(CLASS_ICON_TCOORDS[charDB.class]))
-- classNameAndIcon:SetImageSize(32, 32)
-- classNameAndIcon:SetText(classColorName)
-- classNameAndIcon:SetWidth(nameSize + iconSize)
-- container:AddChild(classNameAndIcon)

function RackensTracker:RetrieveSavedInstanceInformation(characterName)

	local lockoutInformation = {}
	local raidInstances = RT.Container:New()
	local dungeonInstances = RT.Container:New()

	local character = self.db.realm.characters[characterName]
	local characterHasLockouts = false

	for _, savedInstance in pairs(character.savedInstances) do
		if savedInstance.resetsIn + GetServerTime() > GetServerTime() then
			local isRaid = savedInstance.isRaid
			if isRaid == nil then
				isRaid = true
			end

			local instance = RT.Instance:New(
				savedInstance.instanceName,
				savedInstance.instanceID,
				savedInstance.lockoutID,
				savedInstance.resetsIn,
				savedInstance.isRaid,
				savedInstance.isHeroic,
				savedInstance.maxPlayers,
				savedInstance.difficultyID,
				savedInstance.difficultyName,
				savedInstance.encountersTotal,
				savedInstance.encountersCompleted)
				if (isRaid) then
					if (raidInstances:Add(instance)) then
						lockoutInformation[instance.id] = {}
					end
					-- Try to set the lowest known raid reset time so we can display that properly across characters.
					if (self.db.realm.currentlyKnownRaidResetTime == nil or self.db.realm.currentlyKnownRaidResetTime > instance.resetsIn) then
						self.db.realm.currentlyKnownRaidResetTime = instance.resetsIn
					end

					lockoutInformation[instance.id]["resetDatetime"] = SecondsToTime(self.db.realm.currentlyKnownRaidResetTime, true, nil, 3)
					lockoutInformation[instance.id]["progress"] = RT.Util:FormatEncounterProgress(instance.encountersCompleted, instance.encountersTotal)
				else
					if (dungeonInstances:Add(instance)) then
						lockoutInformation[instance.id] = {}
					end
					-- Try to set the lowest known dungeon reset time so we can display that properly across characters.
					if (self.db.realm.currentlyKnownDungeonResetTime == nil or self.db.realm.currentlyKnownDungeonResetTime > instance.resetsIn) then
						self.db.realm.currentlyKnownDungeonResetTime = instance.resetsIn
					end

					lockoutInformation[instance.id]["resetDatetime"] = SecondsToTime(self.db.realm.currentlyKnownDungeonResetTime, true, nil, 3)
					lockoutInformation[instance.id]["progress"] = RT.Util:FormatEncounterProgress(instance.encountersCompleted, instance.encountersTotal)
				end


			characterHasLockouts = true
		end
	end


	return characterHasLockouts, raidInstances, dungeonInstances, lockoutInformation

end


function RackensTracker:OnInitialize()
	-- Called when the addon is Initialized
	self.tracker_frame = nil

	-- Load saved variables
	self.db = LibStub("AceDB-3.0"):New("RackensTrackerDB", database_defaults, true)

	self.libDataBroker = LibStub("LibDataBroker-1.1", true)
	self.libDBIcon = self.libDataBroker and LibStub("LibDBIcon-1.0", true)
	local minimapBtn = self.libDataBroker:NewDataObject(addOnName, {
		type = "launcher",
		text = addOnName,
		icon = "Interface\\Icons\\Achievement_boss_lichking",
		OnClick = function(_, button)
			if (button == "LeftButton") then
				-- If the window is already created
				self:CreateTrackerFrame()
			end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE.. addOnName .. FONT_COLOR_CODE_CLOSE )
			tooltip:AddLine(GRAY_FONT_COLOR_CODE .. "Left click: " .. FONT_COLOR_CODE_CLOSE .. NORMAL_FONT_COLOR_CODE .. "open the lockout tracker window" .. FONT_COLOR_CODE_CLOSE)
		end,
	})

	if self.libDBIcon then
		self.libDBIcon:Register(addOnName, minimapBtn, self.db.char.minimap)
	end


end


local function GetCharacterDatabaseID()
	local name = UnitName("player")
	return name
end


local function GetCharacterClass()
    local classFilename, _ = UnitClassBase("player")
    return classFilename
end

function RackensTracker:GetCharacterIcon(class, iconSize)
	local textureAtlas = GetClassAtlas(class)
	local icon = CreateAtlasMarkup(textureAtlas, size, size)
	return icon
end

function RackensTracker:OnEnable()
	-- Called when the addon is enabled

	local characterName = GetCharacterDatabaseID()

	self.charDB = self.db.realm.characters[characterName]
	self.charDB.name = characterName
	self.charDB.class = GetCharacterClass()
	self.charDB.level = UnitLevel("player")
	self.charDB.realm = GetRealmName()

	-- Reset the known last lockout time, this will be updated once a character that has lockouts logs in anyway
	self.db.realm.currentlyKnownRaidResetTime = nil
	self.db.realm.currentlyKnownDungeonResetTime = nil

	-- Raid and dungeon related events
	self:RegisterEvent("BOSS_KILL", "OnEventBossKill")
    self:RegisterEvent("INSTANCE_LOCK_START", "OnEventInstanceLockStart")
    self:RegisterEvent("INSTANCE_LOCK_STOP", "OnEventInstanceLockStop")
    self:RegisterEvent("INSTANCE_LOCK_WARNING", "OnEventInstanceLockWarning")
    self:RegisterEvent("UPDATE_INSTANCE_INFO", "OnEventUpdateInstanceInfo")

	-- Currency related events
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "OnEventCurrencyDisplayUpdate")
	self:RegisterEvent("CHAT_MSG_CURRENCY", "OnEventChatMsgCurrency")
	
	-- Level up event
	self:RegisterEvent("PLAYER_LEVEL_UP", "OnEventPlayerLevelUp")
	-- Register Slash Commands
	self:RegisterChatCommand("RackensTracker", "SlashCommand")

	-- Request raid lockout information from the server
	self:TriggerUpdateInstanceInfo()

	-- Update currency information for the currenct logged in character
	self:UpdateCharacterCurrencies()
end

function RackensTracker:OnDisable()
	-- Called when the addon is disabled
	self:UnregisterChatCommand("RackensTracker")
end

local function slashCommandUsage()
	DEFAULT_CHAT_FRAME:AddMessage("/RackensTracker" .. " minimap enable, enables the minimap button")
	DEFAULT_CHAT_FRAME:AddMessage("/RackensTracker" .. " minimap disable, disables the minimap button")
end

function RackensTracker:SlashCommand(msg)
	local command, value, _ = self:GetArgs(msg, 2)

	if (command == nil or command:trim() == "") then
		if (value == "open") then
			-- Open window displaying lockouts
			return
		elseif (value == "close") then
			-- Close window displaying lockouts
			return
		else
			-- Print addon usage to chat.
			return slashCommandUsage()
		end
		return slashCommandUsage()
	end

	if (command == "minimap") then
		if (value == "enable") then
			--Log("Enabling the minimap button")
			self.db.char.minimap.hide = false
			print("curr minimap hide state:" .. tostring(self.db.char.minimap.hide))
			self.libDBIcon:Show(addOnName)
		elseif (value == "disable") then
			--Log("Disabling the minimap button")
			self.db.char.minimap.hide = true
			print("curr minimap hide state:" .. tostring(self.db.char.minimap.hide))
			self.libDBIcon:Hide(addOnName)
		else
			return slashCommandUsage()
		end
	end
end


function RackensTracker:TriggerUpdateInstanceInfo()
	RequestRaidInfo()
end

function RackensTracker:OnEventPlayerEnteringWorld()
	Log("OnEventPlayerEnteringWorld")
	self:TriggerUpdateInstanceInfo()
end

function RackensTracker:OnEventBossKill()
    Log("OnEventBossKill")
    self:TriggerUpdateInstanceInfo()
end

function RackensTracker:OnEventInstanceLockStart()
    Log("OnEventInstanceLockStart")
    self:TriggerUpdateInstanceInfo()
end

function RackensTracker:OnEventInstanceLockStop()
    Log("OnEventInstanceLockStop")
    self:TriggerUpdateInstanceInfo()
end

function RackensTracker:OnEventInstanceLockWarning()
    Log("OnEventInstanceLockWarning")
    self:TriggerUpdateInstanceInfo()
end

function RackensTracker:OnEventUpdateInstanceInfo()
    Log("OnEventUpdateInstanceInfo")
	self:UpdateCharacterLockouts()
end

function RackensTracker:OnEventCurrencyDisplayUpdate()
	Log("OnEventCurrencyDisplayUpdate")
	self:UpdateCharacterCurrencies()
end

function RackensTracker:OnEventChatMsgCurrency(text, playerName)
	Log("OnEventChatMsgCurrency")
	if (playerName == UnitName("player")) then
		-- We recieved a currency, update character currencies
		-- TODO: maybe use lua pattern matching and match groups to extract the item name and
		-- find out if the item is one of the currencies we are interested in, no idea if the currency name is localized if it's in enUS
		--local itemLink, count = string.match(text, "(|c.+|r) ?x?(%d*).?")
		--local itemInfo = C_CurrencyInfo.GetCurrencyInfoFromLink(itemLink)
		self:UpdateCharacterCurrencies()
	end
end

function RackensTracker:OnEventPlayerLevelUp(newLevel)
	self:UpdateCharacterLevel(newLevel)
end

-- GUI Code

local function CreateDummyFrame()
	local dummyFiller = AceGUI:Create("Label")
	dummyFiller:SetText(" ")
	dummyFiller:SetFullWidth(true)
	dummyFiller:SetHeight(20)
	return dummyFiller
end


local DUNGEON_LOCK_EXPIRE = string.format("%s %s", "Dungeon", LOCK_EXPIRE) -- TODO: AceLocale
local RAID_LOCK_EXPIRE = string.format("%s %s", "Raid", LOCK_EXPIRE) -- TODO: AceLocale

function RackensTracker:GetLockoutTimeWithIcon(isRaid)

	-- https://www.wowhead.com/wotlk/icon=134247/inv-misc-key-13
	local iconFileID = 134247
	local iconMarkup = CreateTextureMarkup(iconFileID, 64, 64, DEFAULT_ICON_SIZE, DEFAULT_ICON_SIZE, 0, 1, 0, 1)

	local knownRaidResetTime = self.db.realm.currentlyKnownRaidResetTime
	local knownDungeonResetTime = self.db.realm.currentlyKnownDungeonResetTime

	if (isRaid and knownRaidResetTime) then
		return string.format("%s %s: %s", iconMarkup, RAID_LOCK_EXPIRE, SecondsToTime(knownRaidResetTime, true, nil, 3))
	end
	if (isRaid == false and knownDungeonResetTime) then
		return string.format("%s %s: %s", iconMarkup, DUNGEON_LOCK_EXPIRE, SecondsToTime(knownDungeonResetTime, true, nil, 3))
	end

	return nil
end

function RackensTracker:DrawCurrencies(container, characterName)

	local labelHeight = 20

	container:AddChild(CreateDummyFrame())

	-- Heading 
	local currenciesHeading = AceGUI:Create("Heading")
	currenciesHeading:SetText("Currencies") -- TODO: Use AceLocale for things 
	currenciesHeading:SetFullWidth(true)
	container:AddChild(currenciesHeading)

	container:AddChild(CreateDummyFrame())
	
	local currenciesGroup = AceGUI:Create("SimpleGroup")
	currenciesGroup:SetLayout("Flow")
	currenciesGroup:SetFullWidth(true)

	local currencyDisplay
	local colorName, icon, amount

	for _, currency in ipairs(RT.Currencies) do
		currencyDisplay = AceGUI:Create("Label")
		currencyDisplay:SetHeight(labelHeight)
		--currencyDisplay:SetRelativeWidth(1/#RT.Currencies + 0.15) -- Make each currency take up equal space
		currencyDisplay:SetRelativeWidth(1/#RT.Currencies + 0.10) -- Make each currency take up equal space
		colorName, icon, amount = currency:GetFullTextDisplay()

		if (amount == 0) then
			Log("Amount for token: " .. colorName .. " is 0")
			local disabledAmount = RT.Util:FormatColor(GRAY_FONT_COLOR_CODE, amount)
			currencyDisplay:SetText(string.format("%s\n%s %s", colorName, icon, disabledAmount))
		else 
			currencyDisplay:SetText(string.format("%s\n%s %s", colorName, icon, amount))
		end

		currenciesGroup:AddChild(currencyDisplay)
	end

	container:AddChild(currenciesGroup)
end

function RackensTracker:DrawSavedInstances(container, characterName)
	
	local characterHasLockouts, raidInstances, dungeonInstances, lockoutInformation = self:RetrieveSavedInstanceInformation(characterName)
	local nRaids, nDungeons = #raidInstances.sorted, #dungeonInstances.sorted

	-- Heading 
	local lockoutsHeading = AceGUI:Create("Heading")
	-- Return after creation of the heading stating no lockouts were found.
	if (characterHasLockouts == false) then
		lockoutsHeading:SetText("No lockouts") -- TODO: Use AceLocale for things 
		lockoutsHeading:SetFullWidth(true)
		container:AddChild(lockoutsHeading)
		return
	end

	lockoutsHeading:SetText("Lockouts") -- TODO: Use AceLocale for things 
	lockoutsHeading:SetFullWidth(true)
	container:AddChild(lockoutsHeading)

	-- Empty Row
	container:AddChild(CreateDummyFrame())

	-- If we have atleast one raid tracked display the raid lockout
	if (nRaids and nRaids > 0) then
		local raidResetTimeIconLabel = AceGUI:Create("Label")
		local instance = raidInstances.sorted[1]
		local lockoutWithIcon = RackensTracker:GetLockoutTimeWithIcon(instance.isRaid)
		raidResetTimeIconLabel:SetText(lockoutWithIcon)
		raidResetTimeIconLabel:SetFullWidth(true)
		container:AddChild(raidResetTimeIconLabel)
		
		-- Empty Row
		container:AddChild(CreateDummyFrame())

		--Log("Raid Reset: " .. tostring(instance.resetsIn))
		--Log("lowest current reset is: " .. tostring(self.db.realm.currentlyKnownRaidResetTime))
	end

	-- If we have atleast one dungeon tracked display the dungeon lockout
	if (nDungeons and nDungeons > 0) then
		local dungeonResetTimeIconLabel = AceGUI:Create("Label")
		local instance = dungeonInstances.sorted[1]
		local lockoutWithIcon = RackensTracker:GetLockoutTimeWithIcon(instance.isRaid)
		dungeonResetTimeIconLabel:SetText(lockoutWithIcon)
		dungeonResetTimeIconLabel:SetFullWidth(true)
		container:AddChild(dungeonResetTimeIconLabel)

		-- Empty Row
		container:AddChild(CreateDummyFrame())

		--Log("Dungeon Reset: " .. tostring(instance.resetsIn))
		--Log("lowest current dungeon reset is: " .. tostring(self.db.realm.currentlyKnownDungeonResetTime))
	end


	local lockoutsGroup = AceGUI:Create("SimpleGroup")
	lockoutsGroup:SetLayout("Flow")
	lockoutsGroup:SetFullWidth(true)

	container:AddChild(lockoutsGroup)
	
	local raidGroup = AceGUI:Create("InlineGroup")
	raidGroup:SetLayout("List")
	raidGroup:SetTitle("Raids") -- TODO: AceLocale
	raidGroup:SetFullHeight(true)
	raidGroup:SetRelativeWidth(0.50) -- Half of the parent

	local dungeonGroup = AceGUI:Create("InlineGroup")
	dungeonGroup:SetLayout("List")
	dungeonGroup:SetTitle("Dungeons") -- TODO: AceLocale
	dungeonGroup:SetFullHeight(true)
	dungeonGroup:SetRelativeWidth(0.50) -- Half of the parent

	-- Fill in the raids inside raidGroup.
	-- There is a wierd problem where the containers raidGroup and dungeonGroup are not anchored to the top of the parent container.
	-- This makes for an awkard layout where one of raidGroup or dungeonGroup is taller than the other one as they dont fill out the height even with :SetFullHeight(true)
	-- but rather fills its height by content, this is an ugly hack to fill dummy frames into either raidGroup or dungeonGroup to match the number of rows, thus making their heights equal :/
	local nDummyFramesNeeded = math.max(nRaids, nDungeons)
	local hasMoreRaidsThanDungeons = nRaids > nDungeons

	local instanceNameLabel, instanceProgressLabel, instanceColorizedName, instanceResetDatetime, instanceProgress = nil
	local labelHeight = 20
	local lockoutInfo = {}
	for _, instance in ipairs(raidInstances.sorted) do
		lockoutInfo = lockoutInformation[instance.id]
		instanceNameLabel = AceGUI:Create("Label")
		instanceColorizedName = RT.Util:FormatColor(NORMAL_FONT_COLOR_CODE, "%s", instance.id)
		instanceNameLabel:SetText(instanceColorizedName)
		instanceNameLabel:SetFullWidth(true)
		instanceNameLabel:SetHeight(labelHeight)
		raidGroup:AddChild(instanceNameLabel)
		instanceProgressLabel = AceGUI:Create("Label")
		instanceProgressLabel:SetText(string.format("%s: %s", "Cleared", lockoutInfo.progress))
		instanceProgressLabel:SetFullWidth(true)
		instanceProgressLabel:SetHeight(labelHeight)
		raidGroup:AddChild(instanceProgressLabel)
	end

	if (hasMoreRaidsThanDungeons == false) then
		for i = 1, nDummyFramesNeeded * 2 do -- * 2 to account for the instance name row + the lockout progress row
			raidGroup:AddChild(CreateDummyFrame())
		end
	end

	-- Fill in the character for this tab's dungeon lockouts
	for _, instance in ipairs(dungeonInstances.sorted) do
		lockoutInfo = lockoutInformation[instance.id]
		instanceNameLabel = AceGUI:Create("Label")
		instanceColorizedName = RT.Util:FormatColor(NORMAL_FONT_COLOR_CODE, "%s", instance.id)
		instanceNameLabel:SetText(instanceColorizedName)
		instanceNameLabel:SetFullWidth(true)
		instanceNameLabel:SetHeight(labelHeight)
		dungeonGroup:AddChild(instanceNameLabel)
		instanceProgressLabel = AceGUI:Create("Label")
		instanceProgressLabel:SetText(string.format("%s: %s", "Cleared", lockoutInfo.progress))
		instanceProgressLabel:SetFullWidth(true)
		instanceProgressLabel:SetHeight(labelHeight)
		dungeonGroup:AddChild(instanceProgressLabel)
	end

	if (hasMoreRaidsThanDungeons) then
		for i = 1, nDummyFramesNeeded * 2 do
			dungeonGroup:AddChild(CreateDummyFrame())
		end
	end
	-- If these arent added AFTER all the child objects have been added, the anchor points and positioning gets all screwed up : (
	lockoutsGroup:AddChild(raidGroup)
	lockoutsGroup:AddChild(dungeonGroup)
end


local function SelectCharacterTab(container, event, characterName)
	container:ReleaseChildren()
	RackensTracker:DrawSavedInstances(container, characterName)
	RackensTracker:DrawCurrencies(container, characterName)
end

-- The "Flow" Layout will let widgets fill one row, and then flow into the next row if there isn't enough space left. 
-- Its most of the time the best Layout to use.
-- The "List" Layout will simply stack all widgets on top of each other on the left side of the container.
-- The "Fill" Layout will use the first widget in the list, and fill the whole container with it. Its only useful for containers 

function RackensTracker:CreateTrackerFrame()
	-- No need to render and create the user interface again if its already created.
	if (self.tracker_frame and self.tracker_frame:IsVisible()) then
		return
	end

	self.tracker_frame = AceGUI:Create("Window")
	self.tracker_frame:SetTitle(addOnName)
	self.tracker_frame:SetLayout("Fill")
	self.tracker_frame:SetWidth(640)
	self.tracker_frame:SetHeight(500)

	-- Minimum width and height when resizing the window.
	self.tracker_frame.frame:SetResizeBounds(640, 500)

	self.tracker_frame:SetCallback("OnClose", function(widget)
		-- Clear any local tables containing processed instances and currencies
		AceGUI:Release(widget)
		self.tracker_frame = nil
	end)

	-- Create our TabGroup
	self.tracker_tabs = AceGUI:Create("TabGroup")

	-- The frames inside the selected tab are stacked
	self.tracker_tabs:SetLayout("List")

	-- Setup which tabs to show, one tab per character
	local tabsData = {}
	local tabIconSize = 8
	local tabIcon = ""
	local tabName = ""

	-- TODO: Enable configuration option to exclude certain characters or hide if below a level threshold.
	-- Add the current character first
	tabIcon = RackensTracker:GetCharacterIcon(self.charDB.class, tabIconSize)
	tabName = RT.Util:FormatColorClass(self.charDB.class, self.charDB.name)
	table.insert(tabsData, { text=string.format("%s %s", tabIcon, tabName), value=self.charDB.name})

	local initialCharacterTab = self.charDB.name

	-- Rest of the characters after
	for characterName, character in pairs(self.db.realm.characters) do
		if characterName ~= self.charDB.name then
			tabIcon = RackensTracker:GetCharacterIcon(character.class, tabIconSize)
			tabName = RT.Util:FormatColorClass(character.class, character.name)
			table.insert(tabsData, { text=string.format("%s %s", tabIcon, tabName), value=characterName})
		end
	end

	self.tracker_tabs:SetTabs(tabsData)
	-- Register callbacks on tab selected
	self.tracker_tabs:SetCallback("OnGroupSelected", SelectCharacterTab)
	-- Set initial tab to the current character
	self.tracker_tabs:SelectTab(initialCharacterTab)
	-- Add the TabGroup to the main frame
	self.tracker_frame:AddChild(self.tracker_tabs)
end