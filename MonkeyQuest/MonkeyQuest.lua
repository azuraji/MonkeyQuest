-- script variables not saved
MonkeyQuest = {};
MonkeyQuest.m_bLoaded = false;				-- true when the config variables are loaded
MonkeyQuest.m_bVariablesLoaded = false;
MonkeyQuest.m_iNumQuestButtons = 50;		-- 50 is the max possible entries in the quest log (25 quests and 25 different locations)
MonkeyQuest.m_iMaxTextWidth = 229;			-- wraps the text if it gets too long, mostly needed for objectives
MonkeyQuest.m_strPlayer = "";
MonkeyQuest.m_aQuestList = {};
MonkeyQuest.m_aQuestItemList = {};
MonkeyQuest.m_bGotQuestLogUpdate = false;
MonkeyQuest.m_bNeedRefresh = false;
MonkeyQuest.m_fTimeSinceRefresh = 0.0;
MonkeyQuest.m_bCleanQuestList = true;	-- used to clean up the hidden list on the first questlog update event
MonkeyQuest.m_setCorrectState = 1;
--MQWATCHFRAME_NUM_ITEMS = 0;
--MQWATCHFRAME_ITEM_WIDTH = 33;

MonkeyQuest.m_colourBorder = { r = TOOLTIP_DEFAULT_COLOR.r, g = TOOLTIP_DEFAULT_COLOR.g, b = TOOLTIP_DEFAULT_COLOR.b };

MonkeyQuestObjectiveTable = {};

function MonkeyQuest_OnLoad(self)
    hooksecurefunc("HideUIPanel", MonkeyQuest_Refresh);
    hooksecurefunc(GameTooltip, "SetBagItem", YourSetBagItem);
    
    -- register events
    self:RegisterEvent('VARIABLES_LOADED');
    self:RegisterEvent('QUEST_LOG_UPDATE');			-- used to know when to refresh the MonkeyQuest text
    self:RegisterEvent('UNIT_NAME_UPDATE');			-- this is the event I use to get per character config settings
    self:RegisterEvent('PLAYER_ENTERING_WORLD');	-- this event gives me a good character name in situations where 'UNIT_NAME_UPDATE' doesn't even trigger
    self:RegisterEvent('PLAYER_LEVEL_UP');			-- when you level up the difficulty of some quests may change

	-- events when zone changes to update the zone highlighting quests
    --self:RegisterEvent('ZONE_CHANGED');
	--self:RegisterEvent('ZONE_CHANGED_INDOORS');
	--self:RegisterEvent('ZONE_CHANGED_NEW_AREA');
    
    
    -- initialize the border and backdrop of the main frame
    --this:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b);
	--this:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b, 0);
	
	-- patch 9.0.1

	MonkeyQuestFrame:SetBackdrop({
		bgFile = "Interface\\AddOns\\MonkeyLibrary\\Textures\\BackDrop.tga",
		edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 16,
		tile = true,
		tileSize = 16,
		insets = { 5, 5, 5, 5 }
	})

    
    -- setup the title of the main frame
    MonkeyQuestTitleText:SetText(MONKEYQUEST_TITLE);
    MonkeyQuestTitleText:SetTextColor(MONKEYLIB_TITLE_COLOUR.r, MONKEYLIB_TITLE_COLOUR.g, MONKEYLIB_TITLE_COLOUR.b);
    MonkeyQuestTitleText:Show();
    
    MonkeyQuestSlash_Init();
    MonkeyQuestOptions();

    -- this will catch mobs needed for quests
	self:RegisterEvent('UPDATE_MOUSEOVER_UNIT');
end

function MonkeyQuest_OnUpdate(self, elapsed)
	-- if not loaded yet then get out
	if (MonkeyQuest.m_bLoaded == false) then
		return;
	end
	
	if (MonkeyQuest.m_setCorrectState == 1) then
		MonkeyQuest.m_setCorrectState = 0
		if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bHideHeader == true) then
			HideDetailedControls();
		else
			ShowDetailedControls();
		end
	end

	-- need to make sure we don't read from the quest list before a QUEST_LOG_UPDATE or we'll get the previous character's data
	if (MonkeyQuest.m_bGotQuestLogUpdate == false) then
		return;
	end

	-- update the timer
	MonkeyQuest.m_fTimeSinceRefresh = MonkeyQuest.m_fTimeSinceRefresh + elapsed;
	
	-- if it's been more than MONKEYQUEST_DELAY seconds and we need to process a dropped QUEST_LOG_UPDATE
	if (MonkeyQuest.m_fTimeSinceRefresh > MONKEYQUEST_DELAY and MonkeyQuest.m_bNeedRefresh == true) then
		MonkeyQuest_Refresh();
	end
	
	if (MonkeyQuest.m_bCleanQuestList == true) then
		if (MonkeyQuest.m_fTimeSinceRefresh > 15.0) then
			MonkeyQuestInit_CleanQuestList();
			MonkeyQuest.m_bCleanQuestList = false;
		end
	end
end

function MonkeyQuest_OnQuestLogUpdate()
	
	-- if everything's been loaded, refresh the Quest Monkey Display
	if (MonkeyQuest.m_bLoaded == true) then
		if (MonkeyQuest.m_bNeedRefresh == true) then
			-- don't process, let the OnUpdate catch it, but reset the timer
			MonkeyQuest.m_fTimeSinceRefresh = 0.0;
		else
			MonkeyQuest.m_bNeedRefresh = true;
			MonkeyQuest.m_fTimeSinceRefresh = 0.0;
		end
	end
end

-- OnEvent Function
function MonkeyQuest_OnEvent(self, event, ...)

    if (event == 'VARIABLES_LOADED') then
        -- this event gets called when the variables are loaded
        -- there's a possible situation where the other events might get a valid
        -- player name BEFORE this event, which resets your config settings :(
        
        MonkeyQuest.m_bVariablesLoaded = true;
        
        -- double check that the mod isn't already loaded
        if (not MonkeyQuest.m_bLoaded) then
        
            MonkeyQuest.m_strPlayer = UnitName('player');
            
            -- if MonkeyQuest.m_strPlayer is UNKNOWNOBJECT get out, need a real name
            if (MonkeyQuest.m_strPlayer ~= nil and MonkeyQuest.m_strPlayer ~= UNKNOWNOBJECT) then
                -- should have a valid player name here
                MonkeyQuestInit_LoadConfig();
            end
        end
        
        -- exit this event
        return;
    
    end -- VARIABLES_LOADED

    if (event == 'UNIT_NAME_UPDATE') then
        -- this event gets called whenever a unit's name changes (supposedly)
        -- Note: Sometimes it gets called when unit's name gets set to
        -- UNKNOWNOBJECT
        
        -- double check that the mod isn't already loaded
        if (not MonkeyQuest.m_bLoaded) then
            -- this is the first place I know that reliably gets the player name
            MonkeyQuest.m_strPlayer = UnitName('player');
            
            -- if MonkeyQuest.m_strPlayer is UNKNOWNOBJECT get out, need a real name
            if (MonkeyQuest.m_strPlayer ~= nil and MonkeyQuest.m_strPlayer ~= UNKNOWNOBJECT) then
                -- should have a valid player name here
                MonkeyQuestInit_LoadConfig();
            end
        end
        
        -- exit this event
        return;
    
    end -- UNIT_NAME_UPDATE

    if (event == 'PLAYER_ENTERING_WORLD') then
        -- this event gets called when the player enters the world
        -- Note: on initial login this event will not give a good player name
        
        -- double check that the mod isn't already loaded
        if (not MonkeyQuest.m_bLoaded) then
        
            MonkeyQuest.m_strPlayer = UnitName('player');

            -- if MonkeyQuest.m_strPlayer is UNKNOWNOBJECT get out, need a real name
            if (MonkeyQuest.m_strPlayer ~= nil and MonkeyQuest.m_strPlayer ~= UNKNOWNOBJECT) then
                -- should have a valid player name here
                MonkeyQuestInit_LoadConfig();
            end
        end
        
        -- exit this event
        return;
    
    end -- PLAYER_ENTERING_WORLD

    if (event == 'QUEST_LOG_UPDATE') then
        MonkeyQuest.m_bGotQuestLogUpdate = true;
        MonkeyQuest_OnQuestLogUpdate();
        return;
    end -- QUEST_LOG_UPDATE

	if (event == 'ZONE_CHANGED' or event == 'ZONE_CHANGED_INDOORS' or event == 'ZONE_CHANGED_NEW_AREA') then
		MonkeyQuest_Refresh();
	end -- ZONE_CHANGED
	
	if (event == 'PLAYER_LEVEL_UP') then
		MonkeyQuest_Refresh();
	end -- PLAYER_LEVEL_UP
    
    --if (event == 'TOOLTIP_ANCHOR_DEFAULT') then
    
        --if (MonkeyQuest_SearchTooltip() == true) then
            --GameTooltip:AddLine(MONKEYQUEST_TOOLTIP_QUESTITEM, MONKEYLIB_TITLE_COLOUR.r, MONKEYLIB_TITLE_COLOUR.g, MONKEYLIB_TITLE_COLOUR.b, 1);
            --GameTooltip:SetHeight(GameTooltip:GetHeight() + 14);
        --end
    --end -- TOOLTIP_ANCHOR_DEFAULT

    --if (event == 'UPDATE_MOUSEOVER_UNIT') then
        -- check if this is a quest item
        --MonkeyQuest_SearchTooltip();
    --end -- UPDATE_MOUSEOVER_UNIT
end

-- this function is called when the frame should be dragged around
function MonkeyQuest_OnMouseDown(self, button)
	-- if not loaded yet then get out
	if (MonkeyQuest.m_bLoaded == false) then
		return;
	end
	
	-- left button moves the frame around
	if (button == "LeftButton" and MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bLocked == false) then
		MonkeyQuestFrame:StartMoving();
	end
	
	-- right button on the title or frame opens up the MonkeyBuddy, if it's there
	if (button == "RightButton" and MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bAllowRightClick == true) then
		if (MonkeyBuddyFrame ~= nil) then
			MonkeyBuddy_ToggleDisplay();
		end
	end
end

-- this function is called when the frame is stopped being dragged around
function MonkeyQuest_OnMouseUp(self, button)
	-- if not loaded yet then get out
	if (MonkeyQuest.m_bLoaded == false) then
		return;
	end
	
	if (button == "LeftButton") then
		MonkeyQuestFrame:StopMovingOrSizing();
		
		-- save the position
		MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameLeft = MonkeyQuestFrame:GetLeft();
		MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameTop = MonkeyQuestFrame:GetTop();
		MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameBottom = MonkeyQuestFrame:GetBottom();
	end
end

function MonkeyQuest_OnEnter()

	-- BIB support
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bLockBIB == true) then
		MonkeyQuestFrame:Show();
	end
	ShowDetailedControls();
end

function MonkeyQuest_OnLeave()
	
	-- BIB support
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bLockBIB == true) then
		MonkeyQuest_Hide();
	end
	
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bHideHeader == true) then
		HideDetailedControls();
	end
end

function ShowDetailedControls()
	MonkeyQuestTitleText:Show();
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bHideTitleButtons == false) then
		MonkeyQuestMinimizeButton:Show();
		MonkeyQuestCloseButton:Show();
		MonkeyQuestShowHiddenCheckButton:Show();
	end
end

function HideDetailedControls()
	MonkeyQuestTitleText:Hide();
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bHideTitleButtons == false) then
		MonkeyQuestMinimizeButton:Hide();
		MonkeyQuestCloseButton:Hide();
		MonkeyQuestShowHiddenCheckButton:Hide();
	end
end

function MonkeyQuestCloseButton_OnClick()

	-- if not loaded yet then get out
	if (MonkeyQuest.m_bLoaded == false) then
		return;
	end

	MonkeyQuest_Hide();
end

function MonkeyQuestCloseButton_OnEnter(self, motion)
	-- no noob tip?
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowNoobTips == false) then
		return;
	end

	-- put the tool tip in the default position
	GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT");

	-- set the tool tip text
	GameTooltip:SetText(MONKEYQUEST_NOOBTIP_HEADER, TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b, 1);
	GameTooltip:AddLine(MONKEYQUEST_NOOBTIP_CLOSE, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
	GameTooltip:AddLine(MONKEYQUEST_HELP_OPEN_MSG, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);


	GameTooltip:Show();
end

function MonkeyQuestMinimizeButton_OnClick()

	-- if not loaded yet then get out
	if (MonkeyQuest.m_bLoaded == false) then
		return;
	end

	MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bMinimized = not MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bMinimized;
	
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bMinimized == true) then
		MonkeyQuestMinimizeButton:SetNormalTexture("Interface\\AddOns\\MonkeyLibrary\\Textures\\MinimizeButton-Down");
	else
		MonkeyQuestMinimizeButton:SetNormalTexture("Interface\\AddOns\\MonkeyLibrary\\Textures\\MinimizeButton-Up");
	end
	
	MonkeyQuest_Refresh();
end

function MonkeyQuestMinimizeButton_OnEnter(self, motion)
	-- no noob tip?
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowNoobTips == false) then
		return;
	end

	-- put the tool tip in the default position
	GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT");

	-- set the tool tip text
	GameTooltip:SetText(MONKEYQUEST_NOOBTIP_HEADER, TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b, 1);
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bMinimized) then
		GameTooltip:AddLine(MONKEYQUEST_NOOBTIP_RESTORE, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
	else
		GameTooltip:AddLine(MONKEYQUEST_NOOBTIP_MINIMIZE, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
	end

	GameTooltip:Show();
end

function MonkeyQuestShowHiddenCheckButton_OnClick(self, button, down)

	-- if not loaded yet then get out
	if (MonkeyQuest.m_bLoaded == false) then
		return;
	end

	if (self:GetChecked()) then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF);
		MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowHidden = true;
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowHidden = false;
	end
--XXXX
	if (MonkeyBuddyFrame ~= nil) then
		MonkeyBuddyQuestCheck2:SetChecked(MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowHidden)
	end
	
	MonkeyQuest_Refresh();
end

function MonkeyQuestShowHiddenCheckButton_OnEnter(self, motion)

	-- no noob tip?
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowNoobTips == false) then
		return;
	end

	-- put the tool tip in the default position
	GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT");

	-- set the tool tip text
	GameTooltip:SetText(MONKEYQUEST_NOOBTIP_HEADER, TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b, 1);
	if (self:GetChecked()) then
		GameTooltip:AddLine(MONKEYQUEST_NOOBTIP_HIDEALLHIDDEN, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
	else
		GameTooltip:AddLine(MONKEYQUEST_NOOBTIP_SHOWALLHIDDEN, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
	end

	GameTooltip:Show();
end

function MonkeyQuest_Show()

	MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bDisplay = true;
	MonkeyQuestFrame:Show();
	MonkeyQuest_Refresh();
end

function MonkeyQuest_Hide()

	MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bDisplay = false;
	MonkeyQuestFrame:Hide();
end

function MonkeyQuest_SetAlpha(iAlpha)

	MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iAlpha = iAlpha;

	MonkeyQuestFrame:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b, iAlpha)

	--MonkeyQuestFrame:SetAlpha(0.5);
	
	-- check for MonkeyBuddy
	if (MonkeyBuddyQuestFrame_Refresh ~= nil) then
		MonkeyBuddyQuestFrame_Refresh();
	end
end

function MonkeyQuest_SetFrameAlpha(iAlpha)

	-- wraith:
	--MonkeyQuestFrame:SetAlpha(iAlpha);
	MonkeyQuestFrame:SetAlpha(1.0);
	
	MonkeyQuestTitleButton:SetAlpha( iAlpha );
	MonkeyQuestCloseButton:SetAlpha( iAlpha );
	MonkeyQuestMinimizeButton:SetAlpha( iAlpha );
	MonkeyQuestShowHiddenCheckButton:SetAlpha( iAlpha );
	for i = 1, MonkeyQuest.m_iNumQuestButtons, 1 do
		_G["MonkeyQuestButton" .. i]:SetAlpha( iAlpha );
		_G["MonkeyQuestHideButton" .. i]:SetAlpha( iAlpha );
	end
	-- check for MonkeyBuddy
	if (MonkeyBuddyQuestFrame_Refresh ~= nil) then
		MonkeyBuddyQuestFrame_Refresh();
	end
end

function MonkeyQuest_SetHighlightAlpha(iAlpha)

	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowZoneHighlight) then
		MonkeyQuest_Refresh();
	end
	
	-- check for MonkeyBuddy
	if (MonkeyBuddyQuestFrame_Refresh ~= nil) then
		MonkeyBuddyQuestFrame_Refresh();
	end
end

function MonkeyQuest_Refresh(MBDaily)

	-- if not loaded yet, get outta here
	if (MonkeyQuest.m_bLoaded == false) then
		return;
	end
	
	if (MBDaily ~= nil) then
		if (MBDaily == 1) then
			MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowDailyNumQuests = true
		elseif (MBDaily == 0) then
			MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowDailyNumQuests = false
		end
	end
	
	-- BIB bad options check
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bLockBIB == true) then
		if (BIB_MonkeyQuestButton ~= nil) then
			if (not BIB_MonkeyQuestButton:IsShown()) then
				MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bLockBIB = false;
				MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strAnchor = "ANCHOR_TOPLEFT";
				MonkeyQuest_Show();
			end
		else
			MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bLockBIB = false;
			MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strAnchor = "ANCHOR_TOPLEFT";
			MonkeyQuest_Show();
		end
	end
	
	-- set the check state of the MonkeyQuestShowHiddenCheckButton
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowHidden == true) then
		MonkeyQuestShowHiddenCheckButton:SetChecked(1);
	else
		MonkeyQuestShowHiddenCheckButton:SetChecked(0);
	end
	
	-- make sure the minimize button has the right texture
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bMinimized == true) then
		MonkeyQuestMinimizeButton:SetNormalTexture("Interface\\AddOns\\MonkeyLibrary\\Textures\\MinimizeButton-Down");
	else
		MonkeyQuestMinimizeButton:SetNormalTexture("Interface\\AddOns\\MonkeyLibrary\\Textures\\MinimizeButton-Up");
	end
	
	local strMonkeyQuestBody = "";
	local colour;
	local strTitleColor;
	local iButtonId = 1;
	local bNextHeader = false;
	
	local objectiveDesc, objectiveType, objectiveComplete;
	local j, k, objectiveName, objectiveNumItems, objectiveNumNeeded;
	
	if (MonkeyQuestObjectiveTable == nil) then
		MonkeyQuestObjectiveTable = {};
	end
	
	if (MonkeyQuestTitleTable == nil) then
		MonkeyQuestTitleTable = {};
	end
	
	-- Remember the currently selected quest log entry
	local tmpQuestLogSelection = C_QuestLog.GetSelectedQuest();

	local iNumEntries, iNumQuests = C_QuestLog.GetNumQuestLogEntries();

	local visibleQuestsEffectiveCount = 0

	for i = 1, iNumEntries, 1 do
		local questInfo = C_QuestLog.GetInfo(i)
		
		if (questInfo.isHeader == false) then
			if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bHideHiddenQuests == false or questInfo.isHidden == false) then
				visibleQuestsEffectiveCount = visibleQuestsEffectiveCount + 1
			end
		end
	end

	iNumQuests = visibleQuestsEffectiveCount
	
	-- local DQCompleted = GetDailyQuestsCompleted();
	--local DQMax = GetMaxDailyQuests();

	MonkeyQuestTitleText:SetTextHeight(MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFontHeight + 2);
	-- set the title, with or without the number of quests

		if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowNumQuests == true) then


			if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bHideTitle == false) then
				if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowDailyNumQuests == false) then
					MonkeyQuestTitleText:SetText(MONKEYQUEST_TITLE .. " " .. iNumQuests .. "/" .. MAX_QUESTLOG_QUESTS);
				else
					--MonkeyQuestTitleText:SetText(MONKEYQUEST_TITLE .. " " .. iNumQuests .. "/" .. MAX_QUESTLOG_QUESTS .. " (" .. DQCompleted .. "/" .. DQMax .. ")");
				end
			else
				if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowDailyNumQuests == false) then
					MonkeyQuestTitleText:SetText(iNumQuests .. "/" .. MAX_QUESTLOG_QUESTS);
				else
					--MonkeyQuestTitleText:SetText(iNumQuests .. "/" .. MAX_QUESTLOG_QUESTS .. " (" .. DQCompleted .. "/" .. DQMax .. ")");
				end
			end
		elseif (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bHideTitle == false) then
			if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowDailyNumQuests == false) then
				MonkeyQuestTitleText:SetText(MONKEYQUEST_TITLE);
			else
				--MonkeyQuestTitleText:SetText(MONKEYQUEST_TITLE .. " (" .. DQCompleted .. "/" .. DQMax .. ")");
			end
		else
			if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowDailyNumQuests == false) then
				MonkeyQuestTitleText:SetText("");
			else
				--MonkeyQuestTitleText:SetText("(" .. DQCompleted .. "/" .. DQMax .. ")");
			end
		end


	MonkeyQuest.m_iNumEntries = iNumEntries;

	-- hide all the text buttons
	for i = 1, MonkeyQuest.m_iNumQuestButtons, 1 do
		_G["MonkeyQuestButton" .. i .. "Text"]:SetText("");
		_G["MonkeyQuestButton" .. i .. "Text"]:Hide();
		_G["MonkeyQuestButton" .. i]:Hide();
		_G["MonkeyQuestHideButton" .. i]:Hide();
		_G["MonkeyQuestButton" .. i .. "Text"]:SetWidth(MonkeyQuestFrame:GetWidth() - MONKEYQUEST_PADDING - 8);
		_G["MonkeyQuestButton" .. i .. "Text"]:SetTextHeight(MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFontHeight);
	end


	MonkeyQuest_RefreshQuestItemList();
	
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bMinimized == false) then
		local questInfo, title
		local visibleQuestsCount
		local questHeaders = {}

		for i = 1, iNumEntries, 1 do
			questInfo = C_QuestLog.GetInfo(i)
			
			if (questInfo.isHeader) then
				if (visibleQuestsCount and visibleQuestsCount > 0) then
					questHeaders[title] = visibleQuestsCount
				end
				
				title = questInfo.title
				visibleQuestsCount = 0
			else
				if (questInfo.isHidden == false) then
					visibleQuestsCount = visibleQuestsCount + 1
				end
			end
		end

		-- last header group

		if (visibleQuestsCount and visibleQuestsCount > 0) then
			questHeaders[title] = visibleQuestsCount
		end

		
		for i = 1, iNumEntries, 1 do
			-- questInfo.title			the title text of the quest, may be a header (ex. Wetlands)
			-- questInfo.level			the level of the quest
			-- questTagInfo.tagName		the tag on the quest (ex. COMPLETED)
			--local strQuestLogTitleText, strQuestLevel, strQuestTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = C_QuestLog.GetTitleForLogIndex(i);

			questInfo = C_QuestLog.GetInfo(i)
			--print(questInfo.title, questInfo.isHeader, questInfo.questID)
			local suggestedGroup = questInfo.suggestedGroup
			local isComplete = C_QuestLog.IsComplete(questInfo.questID)
			local questTagInfo = C_QuestLog.GetQuestTagInfo(questInfo.questID);

			-- are we looking for the next header?
			if (bNextHeader == true and questInfo.isHeader) then
				-- no longer skipping quests
				bNextHeader = false;
			end
			
			if (bNextHeader == false) then
				-- no longer looking for the next header
				-- Select the quest log entry for other functions like GetNumQuestLeaderBoards()
				C_QuestLog.SetSelectedQuest(questInfo.questID);
				
				-- double check this quest is in the hidden list, if not, it's a new quest
				if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_aQuestList[questInfo.title] == nil) then
					MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_aQuestList[questInfo.title] = {};
					MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_aQuestList[questInfo.title].m_bChecked = true;
				end

				if (questInfo.isHeader) then
					if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bHideHiddenQuests == false or questHeaders[questInfo.title]) then
						if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_aQuestList[questInfo.title].m_bChecked == true) then
							if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bNoHeaders == false or
								MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowHidden == true or
								MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bAlwaysHeaders == true) then

								strMonkeyQuestBody = strMonkeyQuestBody .. format(MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strHeaderOpenColour .. "%s|r", "- " .. questInfo.title) .. "\n";

								_G["MonkeyQuestButton" .. iButtonId .. "Text"]:SetText(strMonkeyQuestBody);
								_G["MonkeyQuestButton" .. iButtonId .. "Text"]:Show();
								_G["MonkeyQuestButton" .. iButtonId]:Show();

								-- set the bg colour
								_G["MonkeyQuestButton" .. iButtonId .. "Texture"]:SetVertexColor(0.0, 0.0, 0.0, 0.0);
				
								_G["MonkeyQuestButton" .. iButtonId].m_iQuestIndex = i;
								_G["MonkeyQuestButton" .. iButtonId].id = iButtonId;
				
								_G["MonkeyQuestHideButton" .. iButtonId]:Hide();
								_G["MonkeyQuestHideButton" .. iButtonId].m_strQuestLogTitleText = questInfo.title;
								
								iButtonId = iButtonId + 1;
				
								strMonkeyQuestBody = "";
							end
						else
							if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowHidden == true or
								MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bAlwaysHeaders == true) then

								strMonkeyQuestBody = strMonkeyQuestBody .. format(MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strHeaderClosedColour .. "%s|r", "+ " .. questInfo.title) .. "\n";
									
								_G["MonkeyQuestButton" .. iButtonId .. "Text"]:SetText(strMonkeyQuestBody);
								_G["MonkeyQuestButton" .. iButtonId .. "Text"]:Show();
								_G["MonkeyQuestButton" .. iButtonId]:Show();

								-- set the bg colour
								_G["MonkeyQuestButton" .. iButtonId .. "Texture"]:SetVertexColor(0.0, 0.0, 0.0, 0.0);
				
								_G["MonkeyQuestButton" .. iButtonId].m_iQuestIndex = i;
								_G["MonkeyQuestButton" .. iButtonId].id = iButtonId;
								
								_G["MonkeyQuestHideButton" .. iButtonId]:Hide();
								_G["MonkeyQuestHideButton" .. iButtonId].m_strQuestLogTitleText = questInfo.title;
				
								iButtonId = iButtonId + 1;
				
								strMonkeyQuestBody = "";
							end
							-- keep looping through the list until we find the next header
							bNextHeader = true;
						end
					end
				else
					-- check if the user even wants this displayed
					if ((MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_aQuestList[questInfo.title].m_bChecked == true or MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowHidden)
						and (	   MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bHideCompletedQuests == false
								 or (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bHideCompletedQuests == true and not isComplete)
								 or  MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowHidden)
						and (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bHideHiddenQuests == false or questInfo.isHidden == false)) then
						
						-- the user has this quest checked off or he's showing all quests anyways, so we show it (currently on :Hide)
						--getglobal("MonkeyQuestHideButton" .. iButtonId):Hide();
						
						-- if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowHidden) then
						-- 	_G["MonkeyQuestHideButton" .. iButtonId]:Hide();
						-- else
						-- 	_G["MonkeyQuestHideButton" .. iButtonId]:Hide();
						-- end
						
						-- -- update hide quests buttons
						-- if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_aQuestList[questInfo.title].m_bChecked == true) then
						-- 	_G["MonkeyQuestHideButton" .. iButtonId]:SetChecked(1);
						-- else
						-- 	_G["MonkeyQuestHideButton" .. iButtonId]:SetChecked(0);
						-- end
						
						-- _G["MonkeyQuestHideButton" .. iButtonId].m_strQuestLogTitleText = questInfo.title;
						
						local color = GetQuestDifficultyColor(questInfo.level);
						local strQuestLink = GetQuestLink(questInfo.questID);
						local hexColor = strQuestLink and select(3, strfind(strQuestLink, "|cff(.+)|H")) or format("%02X%02X%02X", color.r * 255, color.g * 255, color.b * 255);

						-- adjust bright yellow to golden yellow
						if (color.font == "QuestDifficulty_Difficult") then
							hexColor = "ffd000"
						end

						-- Begin Pkp Changes
						if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bColourTitle) then
							-- strTitleColor = format("|c%02X%02X%02X%02X", 255, colour.r * 255, colour.g * 255, colour.b * 255);

							strTitleColor = format("|cff%s", hexColor);
						else
							strTitleColor = MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strQuestTitleColour;
						end
						
						-- padding
						strMonkeyQuestBody = strMonkeyQuestBody .. "  ";

						-- check if the user wants the quest levels
						if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowQuestLevel == true) then

							if (questTagInfo and questTagInfo.tagID == Enum.QuestTag.Group) then
								if (not suggestedGroup) or suggestedGroup <= 1 then	
									suggestedGroup = "";
								end

								if (questInfo.frequency == Enum.QuestFrequency.Daily) then
									strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "g"..suggestedGroup.."*] ");
								else
									strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "g"..suggestedGroup.."] ");
								end

							elseif (questTagInfo and questTagInfo.tagID == Enum.QuestTag.Dungeon) then
								if (questInfo.frequency == Enum.QuestFrequency.Daily) then
									strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "d*] ");
								elseif (C_QuestLog.IsWorldQuest(questInfo.questID)) then
									strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "WQd] ");
								else
									strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "d] ");
								end

							elseif (questTagInfo and questTagInfo.tagID == Enum.QuestTag.Raid) then
								strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "r] ");

							-- Emissary world quest
							elseif (questTagInfo and questTagInfo.tagID == 128) then
								strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "E] ");

							-- Island quest
							elseif (questTagInfo and questTagInfo.tagID == 254) then
								strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "I] ");

							-- Island weekly quest
							elseif (questTagInfo and questTagInfo.tagID == 261) then
								strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "Iw] ");
								
							elseif (questTagInfo and questTagInfo.tagID == Enum.QuestTag.PvP) then
								if (questInfo.frequency == Enum.QuestFrequency.Daily) then
									strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "p*] ");
								else
									strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "p] ");
								end
								
							elseif (questTagInfo and questTagInfo.tagID == Enum.QuestTag.Heroic) then
								if (questInfo.frequency == Enum.QuestFrequency.Daily) then
									strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "d+] ");
								else
									strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "d+*] ");
								end
								
							elseif (questInfo.frequency == Enum.QuestFrequency.Daily) then
								strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "*] ");
										
							elseif (questInfo.frequency == Enum.QuestFrequency.Weekly) then
								strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "w] ");

							elseif (C_QuestLog.IsWorldQuest(questInfo.questID)) then
								strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "WQ] ");

							-- Covenant Calling Quest
							elseif (questTagInfo and questTagInfo.tagID == 271) then
								strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "C] ");

							else
								strMonkeyQuestBody = strMonkeyQuestBody .. format("%s%s|r", strTitleColor, "[" .. questInfo.level .. "] ");
							end
						end

						-- add the completed tag, if needed
						if (isComplete == -1) then
							strMonkeyQuestBody = strMonkeyQuestBody .. 
								format(strTitleColor .. "%s|r", questInfo.title) ..
								" (" .. MONKEYQUEST_QUEST_FAILED .. ")\n";
						elseif (isComplete == 1) then
							strMonkeyQuestBody = strMonkeyQuestBody ..
								format(strTitleColor .. "%s|r", questInfo.title) ..
								" (" .. MONKEYQUEST_QUEST_DONE .. ")\n";
						else
							strMonkeyQuestBody = strMonkeyQuestBody ..
								format(strTitleColor .. "%s|r", questInfo.title) .. "\n";
						end

						local strQuestDescription, strQuestObjectives = GetQuestLogQuestText(i);

						--[[
						local link, item, charges = GetQuestLogSpecialItemInfo(i);
						if ( item ) then
							--watchItemIndex = watchItemIndex + 1;
							--itemButton = _G["MQWatchFrameItem"..watchItemIndex];
							if ( not itemButton ) then
								MQWATCHFRAME_NUM_ITEMS = watchItemIndex;
								itemButton = CreateFrame("BUTTON", "MQWatchFrameItem" .. watchItemIndex, _G["MonkeyQuestFrame"], "WatchFrameItemButtonTemplate");
							end
							itemButton:SetScale(0.7)
							itemButton:Show();
							itemButton:ClearAllPoints();
							itemButton:SetID(i);
							SetItemButtonTexture(itemButton, item);
							SetItemButtonCount(itemButton, charges);
							WatchFrameItem_UpdateCooldown(itemButton);
							itemButton.rangeTimer = -1;
							if ( MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bItemsOnLeft == true ) then
								if ( MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowHidden == true ) then
									itemButton:SetPoint( "TOPRIGHT", _G["MonkeyQuestHideButton" .. iButtonId], "TOPLEFT", -12, 0);
								else
									itemButton:SetPoint( "TOPRIGHT", _G["MonkeyQuestButton" .. iButtonId], "TOPLEFT" );
								end
							else
								itemButton:SetPoint( "TOPLEFT", _G["MonkeyQuestButton" .. iButtonId], "TOPRIGHT", 12, 0);
							end
						end
						--]]

						local numQuestObjectives = C_QuestLog.GetNumQuestObjectives(questInfo.questID)

						if (numQuestObjectives> 0) then
							for ii = 1, numQuestObjectives, 1 do
								local strLeaderBoardText, strType, iFinished = GetQuestLogLeaderBoard(ii, i);

								MonkeyQuest_AddQuestItemToList(strLeaderBoardText);
								
								if (strLeaderBoardText) then
									if (not iFinished) then
										if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bColourSubObjectivesByProgress == true) then
											strMonkeyQuestBody = strMonkeyQuestBody .. "    " .. MonkeyQuest_GetLeaderboardColorStr(strLeaderBoardText) .. strLeaderBoardText .. "\n";
										else
											strMonkeyQuestBody = strMonkeyQuestBody .. "    " .. MonkeyQuest_GetLeaderboardColorStr(strLeaderBoardText) .. strLeaderBoardText .. "\n";
										end
									elseif (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bHideCompletedObjectives == false
										or MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowHidden) then
										strMonkeyQuestBody = strMonkeyQuestBody .. "    " .. 
											MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strFinishObjectiveColour ..
											strLeaderBoardText .. "\n";
									end
								end
							end

							if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bWorkComplete == true and questInfo.title ~= nil) then
							
								for ii = 1, numQuestObjectives, 1 do

									objectiveDesc, objectiveType, objectiveComplete = GetQuestLogLeaderBoard(ii, i);

									if (objectiveType == "item" or objectiveType == "monster" or objectiveType == "object") then

										j, k, objectiveNumItems, objectiveNumNeeded, objectiveName = string.find(objectiveDesc, "^(%d+)/(%d+)%s(.*)$");

										if (objectiveName ~= nil and objectiveName ~= "  slain" and objectiveName ~= " ") then
										
											currentObjectiveName = questInfo.title .. objectiveName;
										
											if (MonkeyQuestObjectiveTable[currentObjectiveName] == nil) then
												MonkeyQuestObjectiveTable[currentObjectiveName] = {};
											end

											if (isComplete and (MonkeyQuestObjectiveTable[currentObjectiveName].complete == nil or MonkeyQuestObjectiveTable[currentObjectiveName].complete == false)) then
												PlaySoundFile(569169) -- sound/spells/valentines_lookingforloveheart.ogg
											end

											MonkeyQuestObjectiveTable[currentObjectiveName].complete = objectiveComplete;
										end
									elseif (objectiveType == "event") then
										if (objectiveDesc ~= nil) then
										
											currentObjectiveDesc = questInfo.title .. objectiveDesc;
										
											if (MonkeyQuestObjectiveTable[currentObjectiveDesc] == nil) then
												MonkeyQuestObjectiveTable[currentObjectiveDesc] = {};
											end

											if (objectiveComplete == true and MonkeyQuestObjectiveTable[currentObjectiveDesc].complete == nil) then
												-- PlaySoundFile("sound\\spells\\valentines_lookingforloveheart.ogg")
												PlaySoundFile(569169)
											end

											MonkeyQuestObjectiveTable[currentObjectiveDesc].complete = objectiveComplete;
										end
									end
								end
							end

						elseif (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bObjectives) then
							-- this quest has no leaderboard so display the objective instead if the config is set

							strMonkeyQuestBody = strMonkeyQuestBody .. "    " .. 
								format(MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strOverviewColour .. "%s|r",
									strQuestObjectives) .. "\n";
						end

						-- finally set the text
						_G["MonkeyQuestButton" .. iButtonId .. "Text"]:SetText(strMonkeyQuestBody);
						_G["MonkeyQuestButton" .. iButtonId .. "Text"]:Show();
						_G["MonkeyQuestButton" .. iButtonId]:Show();

						-- set the bg colour
						_G["MonkeyQuestButton" .. iButtonId .. "Texture"]:SetVertexColor(0.0, 0.0, 0.0, 0.0);

						if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowZoneHighlight) then
							local strSubZoneText = string.lower(GetSubZoneText());
	
							if (strSubZoneText ~= "") then
								if (string.find(string.lower(strQuestDescription), strSubZoneText, 1, true) or 
									string.find(string.lower(strQuestObjectives), strSubZoneText, 1, true)) then
	
									local a, r, g, b = MonkeyLib_ColourStrToARGB(MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strZoneHighlightColour);
	
									_G["MonkeyQuestButton" .. iButtonId .. "Texture"]:SetVertexColor(r, g, b, MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iHighlightAlpha);
								end
							end
						end

						_G["MonkeyQuestButton" .. iButtonId].m_iQuestIndex = i;
						_G["MonkeyQuestButton" .. iButtonId].m_strQuestObjectives = strQuestObjectives;
			
						iButtonId = iButtonId + 1;
			
						strMonkeyQuestBody = "";
					end
				end
			end
		end
	end

	for i = 1, MonkeyQuest.m_iNumQuestButtons, 1 do
		_G["MonkeyQuestButton" .. i .. "Text"]:SetWidth(MonkeyQuestFrame:GetWidth() - MONKEYQUEST_PADDING - 8);
	end

--[[	
	for i = watchItemIndex + 1, MQWATCHFRAME_NUM_ITEMS do
		_G["MQWatchFrameItem" .. i]:Hide();
	end
	--]]
	
	-- Restore the current quest log selection
	C_QuestLog.SetSelectedQuest(tmpQuestLogSelection);
	
	MonkeyQuest_Resize();
	-- we don't have a dropped QUEST_LOG_UPDATE anymore
	MonkeyQuest.m_bNeedRefresh = false;
	MonkeyQuest.m_fTimeSinceRefresh = 0.0;
end

function MonkeyQuest_RefreshQuestItemList()

	local i;
	local iNumEntries, iNumQuests = C_QuestLog.GetNumQuestLogEntries();


	MonkeyQuest.m_aQuestItemList = nil;
	MonkeyQuest.m_aQuestItemList = {};

	for i = 1, iNumEntries, 1 do
		local questInfo = C_QuestLog.GetInfo(i)
		
		if (not questInfo.isHeader) then
			-- Select the quest log entry for other functions like GetNumQuestLeaderBoards()
			C_QuestLog.SetSelectedQuest(i);

			if (GetNumQuestLeaderBoards() > 0) then
				for ii=1, GetNumQuestLeaderBoards(), 1 do
					--local string = _G["QuestLogObjective"..ii];
					local strLeaderBoardText, strType, iFinished = GetQuestLogLeaderBoard(ii);
					
					MonkeyQuest_AddQuestItemToList(strLeaderBoardText);

				end
			end
		end
	end
end

-- does a decent job of figuring out if the quest objective is an item and if so adds it to the list
function MonkeyQuest_AddQuestItemToList(strLeaderBoardText)
	if (not strLeaderBoardText) then
		return;
	end
	
	--local i, j, strItemName, iNumItems, iNumNeeded = string.find(strLeaderBoardText, "(.*):%s*([-%d]+)%s*/%s*([-%d]+)%s*$");
	local i, j, iNumItems, iNumNeeded, strItemName = string.find(strLeaderBoardText, "^(%d+)/(%d+)%s(.*)$");
	
	if (iNumItems == nil) then
		-- not a quest item
		return;
	end

	i, j = string.find(strItemName, MONKEYQUEST_TOOLTIP_SLAIN);

	if (i ~= nil) then
		strItemName = string.sub(strItemName, 1, i - 2);
	end
	
	if (MonkeyQuest.m_aQuestItemList[strItemName] == nil) then
		MonkeyQuest.m_aQuestItemList[strItemName] = {};
	end
	
	MonkeyQuest.m_aQuestItemList[strItemName].m_iNumItems = iNumItems;
	MonkeyQuest.m_aQuestItemList[strItemName].m_iNumNeeded = iNumNeeded;
end

function MonkeyQuest_Resize()
	
	local iHeight = 0;
	local text;
	local button;
	local iTextWidth = 0;
	local iPadding = MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iQuestPadding;

	
	-- if not loaded yet then get out
	if (MonkeyQuest.m_bLoaded == false) then
		return;
	end

	--iTextWidth = MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameWidth - MONKEYQUEST_PADDING - 8;
	iTextWidth = MonkeyQuestFrame:GetWidth() - MONKEYQUEST_PADDING - 8;

	-- make sure the titlebutton is the right size for the title text
	MonkeyQuestTitleButton:SetWidth(MonkeyQuestTitleText:GetWidth());
	MonkeyQuestTitleButton:SetHeight(MonkeyQuestTitleText:GetHeight());

	for i = 1, MonkeyQuest.m_iNumQuestButtons, 1 do
		text = _G["MonkeyQuestButton" .. i .. "Text"];
		button = _G["MonkeyQuestButton" .. i];
		
		if (text:IsVisible()) then
			text:SetWidth(iTextWidth);

			local textHeight = text:GetHeight() + 4;
			iHeight = iHeight + textHeight + iPadding;

			button:SetWidth(text:GetWidth());
			button:SetHeight(textHeight);
		end
	end

	iHeight = iHeight + MonkeyQuestTitleText:GetHeight() + MONKEYQUEST_PADDING;
	
	--MonkeyQuestFrame:SetWidth(MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameWidth);
	MonkeyQuestFrame:SetHeight(iHeight);
	
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameLeft == nil) then
		MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameLeft = 500;
	end
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameTop == nil) then
		MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameTop = 500;
	end
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameBottom == nil) then
		MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameBottom = 539;
	end
	


	-- Set the grow direction
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bLockBIB == false) then
		-- Added by Diungo
		if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bGrowUp == false) then
			MonkeyQuestFrame:ClearAllPoints();
			-- grow down
			MonkeyQuestFrame:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT",
				MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameLeft,
				MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameTop);
	
			-- check to see if it grew off the screen
			--if (MonkeyQuestFrame:GetBottom() < 0) then
			--	MonkeyQuestFrame:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT",
			--	MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameLeft,
			--	MonkeyQuestFrame:GetHeight() - 2);
			--end
		else
			MonkeyQuestFrame:ClearAllPoints();
			-- grow up
			MonkeyQuestFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT",
				MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameLeft,
				MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameBottom);
	
			-- check to see if it grew off the screen
			--if (MonkeyQuestFrame:GetTop() > 1024) then
			--	MonkeyQuestFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT",
			--	MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameLeft,
			--	1024 - (MonkeyQuestFrame:GetHeight() - 2));
			--end
		end
	end

	-- save the position
	if (MonkeyQuestFrame:GetLeft() ~= nil) then
		MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameLeft = MonkeyQuestFrame:GetLeft();
		MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameTop = MonkeyQuestFrame:GetTop();
		MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameBottom = MonkeyQuestFrame:GetBottom();
	end
end

-- Get a colour for the leaderboard item depending on how "done" it is
function MonkeyQuest_GetLeaderboardColorStr(strText)
	--local i, j, strItemName, iNumItems, iNumNeeded = string.find(strText, "(.*):%s*([-%d]+)%s*/%s*([-%d]+)%s*$");
	local i, j, iNumItems, iNumNeeded, strItemName = string.find(strText, "^(%d+)/(%d+)%s(.*)$");
	
	-- wraith:
	--if ( MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bColourSubObjectivesByProgress == true ) then
	--DEFAULT_CHAT_FRAME:AddMessage("subobjective");
		if (iNumItems ~= nil) then
			local colour = {a = 1.0, r = 1.0, g = 1.0, b = 1.0};
			colour.a, colour.r, colour.g, colour.b = MonkeyQuest_GetCompletenessColorStr(iNumItems, iNumNeeded);
			return MonkeyLib_ARGBToColourStr(colour.a, colour.r, colour.g, colour.b);
		end
	
		-- it's a quest with no numerical objectives
		--local i, j, strItemName, strItems, strNeeded = string.find(strText, "(.*):%s*([-%a]+)%s*/%s*([-%a]+)%s*$");
		local i, j, iNumItems, iNumNeeded, strItemName = string.find(strText, "^(%a+)/(%a+)%s(.*)$");
		-- is it a string/string type?
		if (strItems ~= nil) then
			if (strItems == strNeeded) then
				-- strings are equal, completed objective
				return MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strCompleteObjectiveColour;
			else
				-- strings are not equal, uncompleted objective
				return MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strInitialObjectiveColour;
			end
		else
			-- special objective
			return MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strSpecialObjectiveColour;
		end
	--else
	--	DEFAULT_CHAT_FRAME:AddMessage("finishedobj");
	--	return MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strFinishObjectiveColour;
	--end
end

-- Get a colour for the leaderboard item depending on how "done" it is
function MonkeyQuest_GetCompletenessColorStr(iNumItems, iNumNeeded)
	local colour = {a = 1.0, r = 1.0, g = 1.0, b = 1.0};
	local colourInitial = {a = 1.0, r = 1.0, g = 1.0, b = 1.0};
	local colourMid = {a = 1.0, r = 1.0, g = 1.0, b = 1.0};
	local colourComplete = {a = 1.0, r = 1.0, g = 1.0, b = 1.0};
	local colourFinish = {a = 1.0, r = 1.0, g = 1.0, b = 1.0};

	colourInitial.a, colourInitial.r, colourInitial.g, colourInitial.b = MonkeyLib_ColourStrToARGB(MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strInitialObjectiveColour);
	colourMid.a, colourMid.r, colourMid.g, colourMid.b = MonkeyLib_ColourStrToARGB(MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strMidObjectiveColour);
	colourComplete.a, colourComplete.r, colourComplete.g, colourComplete.b = MonkeyLib_ColourStrToARGB(MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strCompleteObjectiveColour);
	colourFinish.a, colourFinish.r, colourFinish.g, colourFinish.b = MonkeyLib_ColourStrToARGB(MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strFinishObjectiveColour);

	local colourDelta1 = {
		a = (colourMid.a - colourInitial.a),
		r = (colourMid.r - colourInitial.r),
		g = (colourMid.g - colourInitial.g),
		b = (colourMid.b - colourInitial.b)
		};

	local colourDelta2 = {
		a = (colourComplete.a - colourMid.a),
		r = (colourComplete.r - colourMid.r),
		g = (colourComplete.g - colourMid.g),
		b = (colourComplete.b - colourMid.b)
		};

	-- standard x/y type objective
	if (iNumItems + 0 == iNumNeeded + 0) then
		colour.r = colourFinish.r;
		colour.g = colourFinish.g;
		colour.b = colourFinish.b;
	elseif ((iNumItems / iNumNeeded) < 0.5) then
		colour.r = colourInitial.r + ((iNumItems / (iNumNeeded / 2)) * colourDelta1.r);
		colour.g = colourInitial.g + ((iNumItems / (iNumNeeded / 2)) * colourDelta1.g);
		colour.b = colourInitial.b + ((iNumItems / (iNumNeeded / 2)) * colourDelta1.b);
	else
		colour.r = colourMid.r + (((iNumItems - (iNumNeeded / 2)) / (iNumNeeded / 2)) * colourDelta2.r);
		colour.g = colourMid.g + (((iNumItems - (iNumNeeded / 2)) / (iNumNeeded / 2)) * colourDelta2.g);
		colour.b = colourMid.b + (((iNumItems - (iNumNeeded / 2)) / (iNumNeeded / 2)) * colourDelta2.b);
	end

	-- just incase the numbers went slightly out of range
	if (colour.r > 1.0) then
		colour.r = 1.0;
	end
	if (colour.g > 1.0) then
		colour.g = 1.0;
	end
	if (colour.b > 1.0) then
		colour.b = 1.0;
	end
	if (colour.r < 0.0) then
		colour.r = 0.0;
	end
	if (colour.g < 0.0) then
		colour.g = 0.0;
	end
	if (colour.b < 0.0) then
		colour.b = 0.0;
	end

	return colour.a, colour.r, colour.g, colour.b;
end

-- when the mouse goes over the main frame, this gets called
function MonkeyQuestTitle_OnEnter(self, motion)
	-- noob tip?
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowNoobTips == true) then

		-- put the tool tip in the specified position
		if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strAnchor == "DEFAULT") then
			GameTooltip_SetDefaultAnchor(GameTooltip, self);
		else
			GameTooltip:SetOwner(MonkeyQuestFrame, MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strAnchor);
		end
	
		-- set the tool tip text
		GameTooltip:SetText(MONKEYQUEST_NOOBTIP_HEADER, TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b, 1);
		GameTooltip:AddLine(MONKEYQUEST_NOOBTIP_TITLE, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
	
		GameTooltip:Show();

		return;
	end
end

function MonkeyQuestButton_OnLoad(self)
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
end

function MonkeyQuestButton_OnClick(self, button, down)

	--local strQuestLogTitleText, strQuestLevel, strQuestTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = C_QuestLog.GetTitleForLogIndex(self.m_iQuestIndex);
	-- local strQuestLogTitleText, strQuestLevel, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questId = C_QuestLog.GetTitleForLogIndex(self.m_iQuestIndex);
	-- local strQuestLink = GetQuestLink(questId);

	local questInfo = C_QuestLog.GetInfo(self.m_iQuestIndex)
	local isComplete = C_QuestLog.IsComplete(questInfo.questID)
	local questTagInfo = C_QuestLog.GetQuestTagInfo(questInfo.questID);
	local strQuestLink = GetQuestLink(questInfo.questID);
	
	if (questInfo.isHeader) then
		MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_aQuestList[_G["MonkeyQuestHideButton" .. self.id].m_strQuestLogTitleText].m_bChecked = not MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_aQuestList[_G["MonkeyQuestHideButton" .. self.id].m_strQuestLogTitleText].m_bChecked;
		
		MonkeyQuest_Refresh();
		MonkeyQuestFrame:Show();
		MonkeyQuest_Refresh();
		
		return;
	end

	local activeWindow = ChatEdit_GetActiveWindow();

	if (IsShiftKeyDown() and activeWindow) then
		-- what button was it?
		if (button == "LeftButton") then
			if (questTagInfo and questTagInfo.tagID == Enum.QuestTag.Group) then
				local grp = "";
				
				if questInfo.suggestedGroup and questInfo.suggestedGroup > 1 then
					grp = grp .. questInfo.suggestedGroup;
				end

				if (questTagInfo and questTagInfo.frequency == Enum.QuestFrequency.Daily) then
					activeWindow:Insert("[" .. questInfo.level .. "g" .. grp .. "*] " .. strQuestLink .. " ");
				else
					activeWindow:Insert("[" .. questInfo.level .. "g" .. grp .. "] " .. strQuestLink .. " ");
				end
			elseif (questTagInfo and questTagInfo.tagID == Enum.QuestTag.Dungeon) then
				if (questTagInfo.frequency == Enum.QuestFrequency.Daily) then
					activeWindow:Insert("[" .. questInfo.level .. "d*] " .. strQuestLink .. " ");
				else
					activeWindow:Insert("[" .. questInfo.level .. "d] " .. strQuestLink .. " ");
				end
			elseif (questTagInfo and questTagInfo.tagID == Enum.QuestTag.Raid) then
				activeWindow:Insert("[" .. questInfo.level .. "r] " .. strQuestLink .. " ");
			elseif (questTagInfo and questTagInfo.tagID == Enum.QuestTag.PvP) then
				if (questTagInfo.frequency == Enum.QuestFrequency.Daily) then
					activeWindow:Insert("[" .. questInfo.level .. "p*] " .. strQuestLink .. " ");
				else
					activeWindow:Insert("[" .. questInfo.level .. "p] " .. strQuestLink .. " ");
				end
				
			-- elseif (strQuestTag == DUNGEON_DIFFICULTY2) then
			-- 	if (isDaily ~= 1) then
			-- 	activeWindow:Insert("[" .. strQuestLevel .. "d+] " .. strQuestLink .. " ");
			-- 	end
			-- 	if (isDaily == 1) then
			-- 	activeWindow:Insert("[" .. strQuestLevel .. "d+*] " .. strQuestLink .. " ");
			-- 	end
				
			elseif (questTagInfo and questTagInfo.frequency == Enum.QuestFrequency.Daily) then
				activeWindow:Insert("[" .. questInfo.level .. "*] " .. strQuestLink .. " ");
			else
				activeWindow:Insert("[" .. questInfo.level .. "] " .. strQuestLink .. " ");
			end
		else
			local strChatObjectives = "";

			-- Remember the currently selected quest log entry
			local tmpQuestLogSelection = C_QuestLog.GetSelectedQuest();

			-- Select the quest log entry for other functions like GetNumQuestLeaderBoards()
			C_QuestLog.SetSelectedQuest(self.m_iQuestIndex);

			local numQuestObjectives = C_QuestLog.GetNumQuestObjectives(questInfo.questID)

			if (numQuestObjectives > 0) then
				for i = 1, numQuestObjectives(), 1 do
					--local string = _G["QuestLogObjective"..ii];
					local strLeaderBoardText, strType, iFinished = GetQuestLogLeaderBoard(i, self.m_iQuestIndex);
					
					if (strLeaderBoardText) then
						strChatObjectives = strChatObjectives .. "{" .. strLeaderBoardText .. "} ";
					end
				end
			elseif (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bObjectives) then
				-- this quest has no leaderboard so display the objective instead if the config is set
				local strQuestDescription, strQuestObjectives = GetQuestLogQuestText(i);

				strChatObjectives = strChatObjectives .. "{" .. strQuestObjectives .. "} ";
			end

			activeWindow:Insert(strChatObjectives);

			-- Restore the currently selected quest log entry
			C_QuestLog.SetSelectedQuest(tmpQuestLogSelection);

		end

		-- the user isn't trying to actually open the real quest log, so just exit here
		return;
	end

	if (IsControlKeyDown()) then
		-- what button was it?
		if (button == "LeftButton") then
			-- Select the quest log entry for other functions like GetNumQuestLeaderBoards()
			C_QuestLog.SetSelectedQuest(self.m_iQuestIndex);
			
			-- try and share this quest with party members
			if (GetQuestLogPushable() and GetNumPartyMembers() > 0) then
				QuestLogPushQuest();
			end
			
		else
			-- Remember the currently selected quest log entry
			--local tmpQuestLogSelection = C_QuestLog.GetSelectedQuest();

			-- Select the quest log entry for other functions like GetNumQuestLeaderBoards()
			C_QuestLog.SetSelectedQuest(self.m_iQuestIndex);
			
			C_QuestLog.SetAbandonQuest();
			StaticPopup_Show("ABANDON_QUEST", GetAbandonQuestName());
			
			-- Restore the currently selected quest log entry
			--C_QuestLog.SetSelectedQuest(tmpQuestLogSelection);
		end

		-- the user isn't trying to actually open the real quest log, so just exit here
		return;
	end
--[[	
	-- if MonkeyQuestLog is installed, open that instead
	if (MkQL_SetQuest ~= nil) then
		if (MkQL_Main_Frame:IsVisible()) then
			if (MkQL_global_iCurrQuest == self.m_iQuestIndex) then
				MkQL_Main_Frame:Hide();
				return;
			end
		end
		MkQL_SetQuest(self.m_iQuestIndex);
		return;
	end

	-- show the real questlog
	ShowUIPanel(QuestLogFrame);
	
	-- check if there's even a need to mess with the offset
	if (MonkeyQuest.m_iNumEntries > #QuestLogScrollFrame.buttons) then
	
		-- move the real quest log list scrollbar to the correct place
		if (self.m_iQuestIndex < MonkeyQuest.m_iNumEntries - #QuestLogScrollFrame.buttons) then
			FauxScrollFrame_SetOffset(QuestLogListScrollFrame, self.m_iQuestIndex - 1);
			QuestLogListScrollFrameScrollBar:SetValue((self.m_iQuestIndex - 1) * QUESTLOG_QUEST_HEIGHT);
		else
			FauxScrollFrame_SetOffset(QuestLogListScrollFrame, MonkeyQuest.m_iNumEntries - #QuestLogScrollFrame.buttons);
			QuestLogListScrollFrameScrollBar:SetValue((MonkeyQuest.m_iNumEntries - #QuestLogScrollFrame.buttons) * QUESTLOG_QUEST_HEIGHT);
		end
	end

	-- actually select the quest entry
	C_QuestLog.SetSelectedQuest(self.m_iQuestIndex);
	QuestLog_SetSelection(self.m_iQuestIndex);

	-- update the real quest log
	QuestLog_Update();
	
	
	--]]
	
	if (button == "LeftButton") then
		-- if MonkeyQuestLog is installed, open that instead
		if (MkQL_SetQuest ~= nil) then
			if (MkQL_Main_Frame:IsVisible()) then
				if (MkQL_global_iCurrQuest == self.m_iQuestIndex) then
					MkQL_Main_Frame:Hide();
				return;
				end
			end
			MkQL_SetQuest(self.m_iQuestIndex);
			return;
		end

		-- show the real questlog
		ShowUIPanel(QuestLogFrame);

		-- actually select the quest entry
		C_QuestLog.SetSelectedQuest(self.m_iQuestIndex);
		QuestLog_SetSelection(self.m_iQuestIndex);

		-- update the real quest log
		QuestLog_Update();

	elseif (button == "RightButton") then
		-- TODO: hide the quest
	end
end

function MonkeyQuestButton_OnEnter(self, motion)
	
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strAnchor == "NONE") then
		return;
	end

	--local strQuestLogTitleText, strQuestLevel, strQuestTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = C_QuestLog.GetTitleForLogIndex(self.m_iQuestIndex);

	local questInfo = C_QuestLog.GetInfo(self.m_iQuestIndex)
	local isComplete = C_QuestLog.IsComplete(questInfo.questID)
	local questTagInfo = C_QuestLog.GetQuestTagInfo(questInfo.questID);
	local strQuestTag = questTagInfo and questTagInfo.tagName or "";

	if (questInfo.title == nil) then
		return;
	end
	

	if (questInfo.isHeader) then
		-- no noob tip?
		if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowNoobTips == false) then
			return;
		end
		
		-- put the tooltip in the specified position
		if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strAnchor == "DEFAULT") then
			GameTooltip_SetDefaultAnchor(GameTooltip, self);
		else
			GameTooltip:SetOwner(MonkeyQuestFrame, MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strAnchor);
		end
	
		-- set the tooltip text
		GameTooltip:SetText(MONKEYQUEST_NOOBTIP_HEADER, TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b, 1);
		GameTooltip:AddLine(MONKEYQUEST_NOOBTIP_QUESTHEADER, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
	
		GameTooltip:Show();
		
		return;
	end
	
	if questInfo.suggestedGroup and questInfo.suggestedGroup > 1 then
		strQuestTag = questTagInfo.tagName .. " (" .. questInfo.suggestedGroup .. ")";
	end
	
	if (questTagInfo and questTagInfo.tagName == "Heroic") then
		strQuestTag = "Heroic Dungeon";
	end
	
	if (questInfo.frequency == LE_QUEST_FREQUENCY_DAILY or questInfo.frequency == LE_QUEST_FREQUENCY_WEEKLY) then
		strQuestTag = format(questInfo.frequency == LE_QUEST_FREQUENCY_DAILY and DAILY_QUEST_TAG_TEMPLATE or CALENDAR_REPEAT_WEEKLY, strQuestTag or ""):trim();
	end
	

	-- set owner of the tooltip
	GameTooltip:SetOwner(self, "ANCHOR_NONE");
	
	
	-- set the tooltip text
	GameTooltip:SetText(questInfo.title, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
	GameTooltip:AddLine(self.m_strQuestObjectives, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, 1);
	
	if (strQuestTag ~= nil) then
		GameTooltip:AddLine(strQuestTag, TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b, 1);
	end
	
	-- see if any nearby group mates are on this quest
	local iNumPartyMembers = GetNumSubgroupMembers();
	local isOnQuest, i;
	
	for i = 1, iNumPartyMembers do
		isOnQuest = C_QuestLog.IsUnitOnQuest("party" .. i, questInfo.questID);
		
		if (isOnQuest == true) then
			-- this member is on the quest
			GameTooltip:AddLine(MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strCompleteObjectiveColour .. UnitName("party" .. i));
		else
			-- this member isn't on the quest
			GameTooltip:AddLine(MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strInitialObjectiveColour .. UnitName("party" .. i));
		end
	end
	
	if (IsShiftKeyDown()) then
		GameTooltip:AddLine(questInfo.questID, 0, 0.65, 1);
	end

	-- put the tooltip in the specified position
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 3, 3);
	
	GameTooltip:Show();
end

function MonkeyQuestHideButton_OnLoad()

end

function MonkeyQuestHideButton_OnEnter(self, motion)
	-- no noob tip?
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_bShowNoobTips == false) then
		return;
	end
	
	-- put the tool tip in the specified position
	if (MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strAnchor == "DEFAULT") then
		GameTooltip_SetDefaultAnchor(GameTooltip, self);
	else
		GameTooltip:SetOwner(MonkeyQuestFrame, MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_strAnchor);
	end

	-- set the tool tip text
	GameTooltip:SetText(MONKEYQUEST_NOOBTIP_HEADER, TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b, 1);
	GameTooltip:AddLine(MONKEYQUEST_NOOBTIP_HIDEBUTTON, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);

	GameTooltip:Show();

end

function MonkeyQuestHideButton_OnClick(self, button, down)
	-- if not loaded yet then get out
	if (MonkeyQuest.m_bLoaded == false) then
		return;
	end

	if (self:GetChecked()) then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF);
		
		MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_aQuestList[self.m_strQuestLogTitleText].m_bChecked = true;
		
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		
		MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_aQuestList[self.m_strQuestLogTitleText].m_bChecked = false;
	end

	MonkeyQuest_Refresh();
	MonkeyQuestFrame:Show();
	MonkeyQuest_Refresh();
end

function MonkeyQuest_PrintPoints()
	if (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage("Left: "..MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameLeft);
		DEFAULT_CHAT_FRAME:AddMessage("Top: "..MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameTop);
		DEFAULT_CHAT_FRAME:AddMessage("Bottom: "..MonkeyQuestConfig[MonkeyQuest.m_strPlayer].m_iFrameBottom);
	end
end

function MonkeyQuestOptions()

	if (GetAddOnDependencies("MonkeyBuddy") == nil) then
	
	-- Create main frame for information text
	local MonkeyQuestOptions = CreateFrame("FRAME", "MonkeyQuestOptions")
	MonkeyQuestOptions.name = MONKEYQUEST_TITLE
	InterfaceOptions_AddCategory(MonkeyQuestOptions)
	
	function MonkeyQuestOptions.default()
		MonkeyQuestInit_ResetConfig();
	end

	local MonkeyQuestOptionsText1 = MonkeyQuestOptions:CreateFontString(nil, "ARTWORK")
	MonkeyQuestOptionsText1:SetFontObject(GameFontNormalLarge)
	MonkeyQuestOptionsText1:SetJustifyH("LEFT") 
	MonkeyQuestOptionsText1:SetJustifyV("TOP")
	MonkeyQuestOptionsText1:ClearAllPoints()
	MonkeyQuestOptionsText1:SetPoint("TOPLEFT", 16, -16)
	MonkeyQuestOptionsText1:SetText(MONKEYQUEST_TITLE_VERSION)

	local MonkeyQuestOptionsText2 = MonkeyQuestOptions:CreateFontString(nil, "ARTWORK")
	MonkeyQuestOptionsText2:SetFontObject(GameFontNormalSmall)
	MonkeyQuestOptionsText2:SetJustifyH("LEFT") 
	MonkeyQuestOptionsText2:SetJustifyV("TOP")
	MonkeyQuestOptionsText2:SetTextColor(1, 1, 1)
	MonkeyQuestOptionsText2:ClearAllPoints()
	MonkeyQuestOptionsText2:SetPoint("TOPLEFT", MonkeyQuestOptionsText1, "BOTTOMLEFT", 8, -16)
	MonkeyQuestOptionsText2:SetWidth(340)
	MonkeyQuestOptionsText2:SetText(MONKEYQUEST_OPTIONS1)

	local MonkeyQuestOptionsText3 = MonkeyQuestOptions:CreateFontString(nil, "ARTWORK")
	MonkeyQuestOptionsText3:SetFontObject(GameFontNormalLarge)
	MonkeyQuestOptionsText3:SetJustifyH("LEFT") 
	MonkeyQuestOptionsText3:SetJustifyV("TOP")
	MonkeyQuestOptionsText3:SetTextColor(1, 0.65, 0)
	MonkeyQuestOptionsText3:ClearAllPoints()
	MonkeyQuestOptionsText3:SetPoint("TOPLEFT", MonkeyQuestOptionsText2, "BOTTOMLEFT", 0, -16)
	MonkeyQuestOptionsText3:SetWidth(340)
	MonkeyQuestOptionsText3:SetText(MONKEYQUEST_OPTIONS2)
	
	end

end
