local L = LibStub("AceLocale-3.0"):NewLocale("RackensTracker", "enUS", true);

if L then
    L["level"] = "Level"
    L["itemLevel"] = "Item Level"
    L["money"] = "Gold"
    L["unknown"] = "unknown"
    L["unknownAmount"] = "unknown amount"
    L["bossesAndIcon"] = "Bosses %s"
    L["currentRealmLabel"] = "Viewing Tracking Data For:"
    L["raidLockExpiresIn"] = "Raid Locks Expire In"
    L["dungeonLockExpiresIn"] = "Dungeon Locks Expire In"
    L["currencies"] = "Currencies"
    L["weeklyDailyQuests"] = "Weekly / Daily Quests"
    L["weeklyQuest"] = "Weekly Quest"
    L["questStatusAvailable"] = "Available"
    L["questStatusCompleted"] = "Completed"
    L["questStatusTurnedIn"] = "Turned in"
    L["questStatusInProgress"] = "In progress"
    L["questStatusExpired"] = "(quest accepted from a previous reset)"
    L["lockouts"] = "Lockouts"
    L["noLockouts"] = "No lockouts"
    L["noTrackingAvailable"] = "No tracking information available"
    L["noTrackingAvailableDescription1"] = "RackensTracker can't display tracking information gathered about instance lockout or currency information because"
    L["noTrackingAvailableDescription2"] = "1. You've hidden all eligible characters for this realm using the options menu (adjust the minimum level slider to display characters properly)\n\n2. You haven't logged into any eligible characters on this realm yet."
    L["raids"] = "Raids"
    L["dungeons"] = "Dungeons"
    L["progress"] = "Progress"
    L["minimapLeftClickAction"] = "Left click"
    L["minimapRightClickAction"] = "Right click"
    L["minimapLeftClickDescription"] = "open the tracker window"
    L["minimapRightClickDescription"] = "open the options window"
    L["version"] = "Version"
    L["toggleTrackerPanel"] = "Toggle tracker panel"
    L["openOptionsPanel"] = "Open options panel"
    L["errorCurrencyConflictDatabaseDefaults"] = "A currency with id (%s) was added to RackensTracker, but no default database settings were found for it. This should never happen, please report this by creating an issue on the bugtracker."
    L["optionsTrackedRealmsHeader"] = "Tracked Realms"
    L["optionsCharactersHeader"] = "Tracked Characters"
    L["optionsNoCharactersHeader"] = "No Eligible Characters Found"
    L["optionsMinimumCharacterLevelHeader"] = "Minimum Character Level Tracking"
    L["optionsCharacterDataHeader"] = "Displayed Character Data"
    L["optionsWarbandDataHeader"] = "Displayed Warband Data"
    L["optionsQuestsHeader"] = "Displayed Quests"
    L["optionsCurrenciesHeader"] = "Displayed Currencies"
    L["optionsDropDownDescriptionRealms"] = "Display Tracking Data For"
    L["optionsDropDownTooltipRealms"] = "Selected realm will be used for displaying tracking information in the tracking window"
    L["optionsToggleDescriptionWeeklyQuest"] = "Weekly"
    L["optionsToggleDescriptionDailyQuest"] = "Daily"
    L["optionsSliderDescriptionShowMinimumCharacterLevel"] = "Minimum Level"
    L["optionsSliderShowMinimumCharacterLevelTooltip"] = "Slider changes the minimum character level required for data display in the tracking window"
    L["optionsToggleDescriptionShowWarbandData"] = "Display Warband Data"
    L["optionsToggleDescriptionWarbandBankGoldData"] = "Bank Gold"
    L["optionsToggleShowWarbandDataTooltip"] = "Toggles the visibility of the warband data section in its entirety"
    L["optionsToggleWarbandBankGoldDataTooltip"] = "Toggles the visibility of the warband bank gold"
    L["optionsToggleDescriptionShowCharacterData"] = "Display Character Data"
    L["optionsToggleShowCharacterDataTooltip"] = "Toggles the visibility of the character data section in its entirety"
    L["optionsToggleDescriptionLvlCharacterData"] = "Level"
    L["optionsToggleDescriptioniLvlCharacterData"] = "Item Level"
    L["optionsToggleLvlCharacterDataTooltip"] = "Toggles the visibility of the tracked character's level"
    L["optionsToggleiLvlCharacterDataTooltip"] = "Toggles the visibility of the tracked character's item level"
    L["optionsToggleDescriptionMoneyCharacterData"] = "Gold"
    L["optionsToggleMoneyCharacterDataTooltip"] = "Toggles the visibility of the tracked character's gold"
    L["optionsToggleDescriptionShowCurrencies"] = "Display Currencies"
    L["optionsToggleShowCurrenciesTooltip"] = "Toggles the visibility of the currency section in its entirety"
    L["optionsToggleShowCurrencyTooltip"] = "Toggles the visibility of %s in the currency section of the tracking window"
    L["optionsToggleDescriptionShowQuests"] = "Display Quests"
    L["optionsToggleCurrencyTooltip"] = "If checked this currency will be displayed in the tracker window"
    L["optionsToggleCharacterTooltip"] = "If checked this character will be displayed in the tracker window"
    L["optionsCharactersDeleteHeader"] = "Character Data"
    L["optionsSelectDeleteCharacter"] = "Select Character"
    L["optionsSelectDeleteCharacterTooltip"] = "Selected character will be deleted upon pressing the delete button"
    L["optionsButtonDeleteCharacter"] = "Delete Character"
    L["optionsButtonDeleteCharacterTooltip"] = "Click this button to delete the selected character and all its data from the tracking database"
    L["optionsButtonDeleteCharacterConfirm"] = "Are you sure you want to remove %s from the tracker database?";
end

