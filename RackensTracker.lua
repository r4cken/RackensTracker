local addonName = ...
local addonVersion = "0.0.1"

local table, type, string, strsplit, pairs, ipairs = 
	  table, type, string, strsplit, pairs, ipairs

local GetServerTime, GetGameTime, SecondsToTime = 
	  GetServerTime, GetGameTime, SecondsToTime

local GetClassColor = GetClassColor

local RequestRaidInfo, GetNumSavedInstances, GetSavedInstanceInfo, GetDungeonNameWithDifficulty = 
	  RequestRaidInfo, GetNumSavedInstances, GetSavedInstanceInfo, GetDungeonNameWithDifficulty

local C_CurrencyInfo, GetCurrencyInfo = 
	  C_CurrencyInfo, GetCurrencyInfo

local FormattingUtil, CreateTextureMarkup, AbbreviateNumbers, BreakUpLargeNumbers = 
	  FormattingUtil, CreateTextureMarkup, AbbreviateNumbers, BreakUpLargeNumbers

local NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, ORANGE_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE =
	  NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, ORANGE_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE

RackensTracker = LibStub("AceAddon-3.0"):NewAddon("RackensTracker", "AceConsole-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local database_defaults = {
	global = {
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
	},
	char = {
		minimap = {
			hide = false
		}
	}
}


local function Log(message, ...)
    RackensTracker:Printf(message, ...)
end


-- FormattingUtil.GetCostString(icon, quantity, colorCode, abbreviate)
-- Reimplementation of the function above to be able to adjust the texture coords for the special case
-- of the Honor points icon
local function _GetCostString(icon, quantity, colorCode, abbreviate)
	colorCode = colorCode or HIGHLIGHT_FONT_COLOR_CODE

	local markup = CreateTextureMarkup(icon, 64, 64, 16, 16, 0.03125, 0.59375, 0.03125, 0.59375);
	local amountString;
	if abbreviate then
		amountString = AbbreviateNumbers(quantity);
	else
		amountString = BreakUpLargeNumbers(quantity);
	end
	return ("%s%s %s|r"):format(colorCode, amountString, markup);
end

-- GetCurrencyString(currencyID, overrideAmount, colorCode, abbreviate) from Blizz found in FormattingUtil
-- Faster reimplementation of the function above, skipping the calls to C_CurrencyInfo.GetCurrencyInfo and handling the special case
-- of the Honor points icon

local function _GetCurrencyString(currency, overrideAmount, colorCode, abbreviate)
	colorCode = colorCode or HIGHLIGHT_FONT_COLOR_CODE

	if (currency) then
		local amount = overrideAmount or currency.amount
		-- If we are handling the special case of honor points 
		if (currency.currencyID == Constants.CurrencyConsts.CLASSIC_HONOR_CURRENCY_ID) then
			return _GetCostString(currency.iconFileID, amount, colorCode, abbreviate)
		else
			return _GetCostString(currency.iconFileID, amount, colorCode, abbreviate);
		end
	end

	return ""
end


local function FormatColor(color, message, ...)
    return color .. string.format(message, ...) .. FONT_COLOR_CODE_CLOSE
end


local function FormatColorClass(class, message, ...)
    local _, _, _, color = GetClassColor(class)
    return FormatColor("|c" .. color, message, ...)
end


local function FormatEncounterProgress(progress, numEncounters)
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
	
	local progressColorized = FormatColor(color, "%i", progress)
	local numEncountersColorized = FormatColor(GREEN_FONT_COLOR_CODE, "%i", numEncounters)

	return progressColorized .. "/" .. numEncountersColorized
	
 end

-- local GetIconFromCurrencyID = function(value)
-- 	return select(3, GetCurrencyInfo(value))
-- end

local function GetColorizedCurrencyName(currencyName, currencyQuality)
	local message = ""
	if currencyName then
		local color = currencyQuality and ITEM_QUALITY_COLORS[currencyQuality].hex or ""
		message = color .. currencyName .. "|r"
	end
	return message
end


local function GetCharacterDatabaseID()
	local realm = GetNormalizedRealmName()
	local name = UnitName("player")
	return format("%s.%s", realm, name)
end


local function GetCharacterClass()
    local classFilename, _ = UnitClassBase("player")
    return classFilename
end


function RackensTracker:GetCharacterLockouts()
	local savedInstances = {}

	local nSavedInstances = GetNumSavedInstances()
	if (nSavedInstances > 0) then
		for i = 1, MAX_RAID_INFOS do -- blizz ui stores max 20 entries per character so why not follow suit
			if ( i <= nSavedInstances) then
				local instanceName, lockoutID, resetsIn, difficultyID, isLocked, _, _, isRaid, maxPlayers, difficultyName, encountersTotal, encountersCompleted = GetSavedInstanceInfo(i)
				local _, _, isHeroic, _, _, _, _ = GetDifficultyInfo(difficultyID);
	
				-- Only store active lockouts
				if resetsIn > 0 and isLocked then
					table.insert(savedInstances, {
						instanceName = instanceName,
						lockoutID = lockoutID,
						resetsIn = resetsIn, -- Can be printed with SecondsToTime(resetsIn, true, nil, 3)); do comparisons on it with resetsIn + GetGameTime()
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


-- A Set containing currencyID's that will be skipped when getting all currencies
-- Probably add these under addon config options to enable PvP currencies apart from arena points and honor points
local EXCLUDED_CURRENCY = {
	[121] = true, -- Alterac Valley Mark of Honor
	[122] = true, -- Arathi Basin Mark of Honor
	[123] = true, -- Eye of the Storm Mark of Honor
	[124] = true, -- Strand of the Ancients Mark of Honor
	[125] = true, -- Warsong Gulch Mark of Honor
	[126] = true, -- Wintergrasp Mark of Honor
	[181] = true, -- Honor Points DEPRECATED2,
	[321] = true  -- Isle of Conquest Mark of Honor
 }

-- Update currency information for the currenct logged in character
function RackensTracker:GetCharacterCurrencies()
	local currencies = {}

	local name, amount, iconFileID, earnedThisWeek, weeklyMax, totalMax, isDiscovered =  nil,nil,nil,nil,nil,nil,nil,nil;
	local currencyData, quality

	-- Iterate over all known currency ID's
	for currencyID = 61, 3000, 1 do
		name, amount, iconFileID, earnedThisWeek, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(currencyID);
		
		if (not EXCLUDED_CURRENCY[currencyID]) then
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
				--Log(string.format("(%s) (%s): %s", name, currencyID, _GetCurrencyString(currencies[#currencies], amount)))
			end
		end
	end

	return currencies
end

function RackensTracker:TriggerUpdateInstanceInfo()
	RequestRaidInfo()
end


function RackensTracker:UpdateCharacterLockouts()
	local savedInstances = self:GetCharacterLockouts()

	self.charDB.savedInstances = savedInstances
end


function RackensTracker:UpdateCharacterCurrencies()
	local currencies = self:GetCharacterCurrencies()

	self.charDB.currencies = currencies
end



local DisplayCharacter = {}
function DisplayCharacter:New(characterID, characterClass)
	local character = {}
	setmetatable(character, self)
	self.__index = self
	character.id = characterID
	_, character.name = strsplit('.', character.id)
	character.class = characterClass
	character.colorName = FormatColorClass(character.class, character.name)
	return character
end

function DisplayCharacter:Less(otherCharacter)
	return self.name < otherCharacter.name
end

local StorageContainer = {}
function StorageContainer:New()
	local data = {}
	setmetatable(data, self)
	self.__index = self
	data.byId = {}
	data.sorted = {}
	return data
end

-- NOTE: the storageItem type must have a Less function attached for sorting
-- Any object stored in StorageContainer must have a key "id" which can be a number or a string
function StorageContainer:Add(storageItem)
	if self.byId[storageItem.id] ~= nil then
		-- No need to track an already registered item in the container
		return false
	end

	self.byId[storageItem.id] = storageItem
	table.insert(self.sorted, storageItem)
	table.sort(self.sorted, function (a, b) return a:Less(b) end)
	return true
end

local DisplayInstance = {}
-- TODO: change the signature of the method to accept a table instead
function DisplayInstance:New(instanceName, lockoutID, resetsIn, isRaid, isHeroic, maxPlayers, difficultyID, difficultyName, encountersTotal, encountersCompleted)
	local instance = {}
	setmetatable(instance, self)
	self.__index = self
	instance.instanceName = instanceName
	instance.lockoutID = lockoutID
	instance.resetsIn = resetsIn
	instance.isRaid = isRaid
	instance.isHeroic = isHeroic
	instance.maxPlayers = maxPlayers
	instance.difficultyID = difficultyID
	instance.difficultyName = difficultyName
	instance.encountersTotal = encountersTotal
	instance.encountersCompleted = encountersCompleted

	instance.id = string.format("%s %s", instance.instanceName, instance.difficultyName)

	return instance
end

function DisplayInstance:Equal(other)
	return self.instanceName == other.instanceName
		and self.maxPlayers == other.maxPlayers
		and self.isHeroic == other.isHeroic
end

function DisplayInstance:Less(other)
	return self.instanceName < other.instanceName
		or (self.instanceName == other.instanceName
			and self.maxPlayers > other.maxPlayers)
		or (self.instanceName == other.instanceName
			and self.maxPlayers == other.maxPlayers
			and not self.isHeroic and other.isHeroic)
end

function RackensTracker:RetrieveAllSavedInstanceInformation()
	-- Will contain elements with the keys
	--[[
		id = realmname.charactername, name = "Whacken", class = "ROGUE", colorName = "Whacken" 
	--]]
	local characters = StorageContainer:New()
	local raidInstances = StorageContainer:New()
	local dungeonInstances = StorageContainer:New()
	local lockoutInformation = {}
	
	for characterID, character in pairs(self.db.global.characters) do
		local characterHasLockouts = false

		for _, savedInstance in pairs(character.savedInstances) do
			if savedInstance.resetsIn + GetServerTime() > GetServerTime() then
				local isRaid = savedInstance.isRaid
				if isRaid == nil then
					isRaid = true
				end

				local instance = DisplayInstance:New(
					savedInstance.instanceName,
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

						lockoutInformation[instance.id][characterID] = FormatEncounterProgress(instance.encountersCompleted, instance.encountersTotal)
					else
						if (dungeonInstances:Add(instance)) then
							lockoutInformation[instance.id] = {}
						end

						lockoutInformation[instance.id][characterID] = FormatEncounterProgress(instance.encountersCompleted, instance.encountersTotal)
					end


				characterHasLockouts = true
			end
		end

		if (characterHasLockouts) then
			characters:Add(DisplayCharacter:New(characterID, character.class))
		end
	end

	return characters, raidInstances, dungeonInstances, lockoutInformation
end


-- container is our TabGroup frame, has layout type "List"
function RackensTracker:DrawInstancesGroup(container)

	local characters, raidInstances, dungeonInstances, lockoutInformation = self:RetrieveAllSavedInstanceInformation()

	local nCharacters = #characters.sorted
	local nRaids = #raidInstances.sorted
	local nDungeons = #dungeonInstances.sorted
	local nColumns = 1 + nCharacters

	-- create a label stating no lockout information found
	if (nCharacters == 0 or (nRaids == 0 and nDungeons == 0)) then
		local noLockoutInformation = AceGUI:Create("Heading")
		noLockoutInformation:SetText("No lockout information available")
		noLockoutInformation:SetFullWidth(true)
		container:AddChild(noLockoutInformation)
		return
	end

	-- Heading 
	local description = AceGUI:Create("Heading")
	description:SetText("Saved instances")
	description:SetFullWidth(true)
	container:AddChild(description)

	local dummyFiller = AceGUI:Create("Label")
	dummyFiller:SetText(" ")
	dummyFiller:SetFullWidth(true)
	container:AddChild(dummyFiller)

	-- Store the table headers in a SimpleGroup
	local headerGroup = AceGUI:Create("SimpleGroup")
	headerGroup:SetLayout("Table")

	local layoutColumns = {
		{ weight = 75 },
		{ width  = 150 }, -- Instance Name
	}

	-- And one column per character name
	for i = 1, nCharacters do
		table.insert(layoutColumns, { width = 75} )
	end

	headerGroup:SetUserData("table", {
		columns = layoutColumns,
		space = 1,
		align = "LEFT"
	})

	headerGroup:SetFullWidth(true)

	-- Create the labels for the table
	local instanceName = AceGUI:Create("Label")
	instanceName:SetText("Instance Name")
	instanceName:SetWidth(150)
	headerGroup:AddChild(instanceName)

	-- 
	local characterNameLabel
	for characterNum, character in ipairs(characters.sorted) do
		characterNameLabel = AceGUI:Create("Label")
		characterNameLabel:SetText(character.colorName)
		characterNameLabel:SetWidth(75)
		headerGroup:AddChild(characterNameLabel)
	end

	container:AddChild(headerGroup)

	dummyFiller = AceGUI:Create("Label")
	dummyFiller:SetText(" ")
	dummyFiller:SetFullWidth(true)
	container:AddChild(dummyFiller)

	-- Create the Scroll frame and add all instance entries
	local scrollContainer = AceGUI:Create("SimpleGroup")
	scrollContainer:SetFullWidth(true)
	scrollContainer:SetHeight(300)
	scrollContainer:SetFullHeight(true) -- Does not work, it refuses to fill
	scrollContainer:SetLayout("Fill") -- Important!

	local scrollFrameLayoutColumns = {
		{ width  = 300 }, -- space for the instance Name
	}

	-- And one column per character name
	for i = 1, nCharacters do
		table.insert(scrollFrameLayoutColumns, { width = 75} )
	end

	local scrollFrame = AceGUI:Create("ScrollFrame")

	-- TODO: Look into the AceGUI table layout and its parameters to make this fucking thing work...

	scrollFrame:SetLayout("Table") -- Might wanna change this later
	scrollFrame:SetUserData("table", {
		columns = scrollFrameLayoutColumns,
		space = 10,
		align = "LEFT"
	})

	scrollFrame:SetFullWidth(true)
	scrollFrame:SetHeight(0)
	scrollFrame:SetAutoAdjustHeight(false)
	scrollContainer:AddChild(scrollFrame)
	
	-- Add all data row entries to scrollFrame
	local instanceNameLabel, instanceProgress = nil
	for _, instance in ipairs(raidInstances.sorted) do
		instanceNameLabel = AceGUI:Create("Label")
		local timeToResetText = SecondsToTime(instance.resetsIn, true, nil, 3)
		local instanceColorizedName = FormatColor(NORMAL_FONT_COLOR_CODE, "%s", instance.id)
		instanceNameLabel:SetText(instanceColorizedName .. "\n" .. timeToResetText)
		instanceNameLabel:SetWidth(300)
		scrollFrame:AddChild(instanceNameLabel)

		local instanceProgressLabel = nil
		for characterNum, character in ipairs(characters.sorted) do
			local progress = lockoutInformation[instance.id][character.id]
			if (progress == nil) then
				instanceProgressLabel = AceGUI:Create("Label")
				instanceProgressLabel:SetText("Not saved")
				instanceProgressLabel:SetWidth(75)
				scrollFrame:AddChild(instanceProgressLabel)
			else
				DEFAULT_CHAT_FRAME:AddMessage("lockout progress: " .. progress)
				instanceProgressLabel = AceGUI:Create("Label")
				instanceProgressLabel:SetText(progress)
				instanceProgressLabel:SetWidth(75)
				scrollFrame:AddChild(instanceProgressLabel)
			end
		end
	end

	container:AddChild(scrollContainer)
end


function RackensTracker:DrawCurrenciesGroup(container)
	-- Heading 
	local description = AceGUI:Create("Heading")
	description:SetText("Currencies")
	description:SetFullWidth(true)
	container:AddChild(description)
end


local function SelectTabGroup(container, event, group)
	container:ReleaseChildren()
	if (group == "instances") then
		RackensTracker:DrawInstancesGroup(container)
	elseif (group == "currencies") then
		RackensTracker:DrawCurrenciesGroup(container)
	end
end

-- The "Flow" Layout will let widgets fill one row, and then flow into the next row if there isn't enough space left. 
-- Its most of the time the best Layout to use.

-- The "List" Layout will simply stack all widgets on top of each other on the left side of the container.

-- The "Fill" Layout will use the first widget in the list, and fill the whole container with it. Its only useful for containers 

function RackensTracker:CreateTrackerFrame()
	-- if (self.main_frame) then
	-- 	DEFAULT_CHAT_FRAME:AddMessage("Closing and releasing all the widgets!")
	-- 	RackensTracker:CloseTrackerFrame()
	-- end

	self.main_frame = AceGUI:Create("Window")
	self.main_frame:SetTitle(addonName)
	self.main_frame:SetLayout("Fill")
	self.main_frame:SetWidth(600)
	self.main_frame:SetHeight(450)
	-- Minimum width and height when resizing the window.
	self.main_frame.frame:SetResizeBounds(600, 450)

	self.main_frame:SetCallback("OnClose", function(widget)
		-- Clear any local tables containing processed instances and currencies
		AceGUI:Release(widget)
		self.main_frame = nil
	end)

	-- Create our TabGroup
	local tabs = AceGUI:Create("TabGroup")
	-- The frames inside the selected tab are stacked
	tabs:SetLayout("List")
	-- Setup which tabs to show
	tabs:SetTabs({{text="Instances", value="instances"}, {text="Currencies", value="currencies"}})
	-- Register callbacks on tab selected
	tabs:SetCallback("OnGroupSelected", SelectTabGroup)
	-- Set initial tab to instances
	tabs:SelectTab("instances")
	-- Add the TabGroup to the main frame
	self.main_frame:AddChild(tabs)

end


function RackensTracker:OnInitialize()
	-- Called when the addon is Initialized
	self.main_frame = nil

	self.db = LibStub("AceDB-3.0"):New("RackensTrackerDB", database_defaults, true)
	self.libDataBroker = LibStub("LibDataBroker-1.1", true)
	self.libDBIcon = self.libDataBroker and LibStub("LibDBIcon-1.0", true)
	local minimapBtn = self.libDataBroker:NewDataObject(addonName, {
		type = "launcher",
		text = addonName,
		icon = "Interface\\Icons\\Achievement_dungeon_ulduarraid_titan_01",
		OnClick = function(_, button)
			if (button == "LeftButton") then
				-- If the window is already created
				if (self.main_frame == nil or not self.main_frame:IsVisible()) then
					self:CreateTrackerFrame()
				end
			end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE.. addonName .. FONT_COLOR_CODE_CLOSE )
			tooltip:AddLine(GRAY_FONT_COLOR_CODE .. "Left click: " .. FONT_COLOR_CODE_CLOSE .. NORMAL_FONT_COLOR_CODE .. "open the lockout tracker window" .. FONT_COLOR_CODE_CLOSE)
		end,
	})

	if self.libDBIcon then
		self.libDBIcon:Register(addonName, minimapBtn, self.db.char)
	end
end

function RackensTracker:OnEnable()
	-- Called when the addon is enabled
	
	-- Load saved variables

	local characterID = GetCharacterDatabaseID()
	local characterRealm, characterName = strsplit('.', characterID)
	local characterClass = GetCharacterClass()

	self.charDB = self.db.global.characters[characterID]
	self.charDB.name = characterName
	self.charDB.class = characterClass
	self.charDB.realm = characterRealm

	-- Raid and dungeon related events
	self:RegisterEvent("BOSS_KILL", "OnEventBossKill")
    self:RegisterEvent("INSTANCE_LOCK_START", "OnEventInstanceLockStart")
    self:RegisterEvent("INSTANCE_LOCK_STOP", "OnEventInstanceLockStop")
    self:RegisterEvent("INSTANCE_LOCK_WARNING", "OnEventInstanceLockWarning")
    self:RegisterEvent("UPDATE_INSTANCE_INFO", "OnEventUpdateInstanceInfo")

	-- Currency related events
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "OnEventCurrencyDisplayUpdate")
	self:RegisterEvent("CHAT_MSG_CURRENCY", "OnEventChatMsgCurrency")
	
	-- TODO: Add code for minimap icon

	-- Register Slash Commands
	self:RegisterChatCommand("RLT", "SlashCommand")
	self:RegisterChatCommand("RackensTracker", "SlashCommand")

	-- Request raid lockout information from the server
	self:TriggerUpdateInstanceInfo()

	-- Update currency information for the currenct logged in character
	self:UpdateCharacterCurrencies()
end

function RackensTracker:OnDisable()
	-- Called when the addon is disabled

	self:UnregisterChatCommand("RLT")
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
			Log("Enabling the minimap button")
			self.db.char.minimap.hide = false
			print("curr minimap hide state:" .. tostring(self.db.char.minimap.hide))
			self.libDBIcon:Show(addonName)
		elseif (value == "disable") then
			Log("Disabling the minimap button")
			self.db.char.minimap.hide = true
			print("curr minimap hide state:" .. tostring(self.db.char.minimap.hide))
			self.libDBIcon:Hide(addonName)
		else
			return slashCommandUsage()
		end
	end
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


