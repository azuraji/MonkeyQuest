MkQL_global_iCurrQuest = 0;
MkQL_global_iCurrQuestId = 0;

local MkQL_local_bResizing = false;

local MkQL_local_iExtraHeight = 0;


function MkQL_OnLoad(self)

    -- register events
	self:RegisterEvent("PLAYER_LOGIN");
	self:RegisterEvent("QUEST_LOG_UPDATE");


    -- Let the user know the mod is loaded
	MonkeyLib_DebugMsg(MONKEYQUESTLOG_LOADED_MSG);
end

-- this event is used to have nice smooth resizing
function MkQL_OnUpdate()
	if (MkQL_local_bResizing) then
		MkQL_UpdateSize();
	end
end

function MkQL_OnEvent(self, event, ...)

	if (event == "PLAYER_LOGIN") then
		-- this event gets called whenever a unit's name changes (supposedly)
		--  Note: Sometimes it gets called when unit's name gets set to
		--  UNKNOWNOBJECT
		
		-- setup the title of the main frame
	    MkQL_Title_Txt:SetText(MONKEYQUESTLOG_TITLE);
	    MkQL_Title_Txt:SetTextColor(MONKEYLIB_TITLE_COLOUR.r, MONKEYLIB_TITLE_COLOUR.g, MONKEYLIB_TITLE_COLOUR.b);
	    --MkQL_Title_Txt:Show();
	    
	    -- temp hack test!
	    --MkQL_SetQuest(4);

	    MonkeyLib_DebugMsg("MonkeyQuestLog PLAYER_LOGIN");

		-- exit this event
		return;
	end -- PLAYER_LOGIN

	if (event == 'QUEST_LOG_UPDATE') then
		if (MkQL_Main_Frame:IsVisible()) then
			MkQL_SetQuest(MkQL_global_iCurrQuest);
		end

        return;
    end -- QUEST_LOG_UPDATE
end

function MkQL_CloseButton_OnClick()
	MkQL_Main_Frame:Hide();
end

function MkQL_RewardItem_OnClick(self, button)
	MonkeyLib_DebugMsg("self.type: "..self.type);
	MonkeyLib_DebugMsg("self:GetID(): "..self:GetID());
	MonkeyLib_DebugMsg("self.rewardType: "..self.rewardType);
	MonkeyLib_DebugMsg("GetQuestItemLink(self.type, self:GetID()): "..GetQuestLogItemLink(self.type, self:GetID()));

	if (IsControlKeyDown()) then

		if (self.rewardType ~= "spell") then
			DressUpItemLink(GetQuestLogItemLink(self.type, self:GetID()));
		end
	elseif (IsShiftKeyDown()) then
		if (ChatFrameEditBox:IsVisible()) then
			ChatFrameEditBox:Insert(GetQuestLogItemLink(self.type, self:GetID()));
		end
	end
end

function MkQL_SetQuest(iQuestNum)
	-- Get the quest title info
	--local strQuestLogTitleText, strQuestLevel, strQuestTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(iQuestNum);
	-- local strQuestLogTitleText, _, _, _, _, isComplete, _, questID = GetQuestLogTitle(iQuestNum);

	local questInfo = C_QuestLog.GetInfo(iQuestNum)
	
	if (questInfo == nil) then
		MkQL_Main_Frame:Hide();
		do return end
	end
	
	-- show the main frame
	MkQL_Main_Frame:Show();

	local isComplete = C_QuestLog.IsComplete(questInfo.questID)
	local isFailed = C_QuestLog.IsFailed(questInfo.questID)
	local questTagInfo = C_QuestLog.GetQuestTagInfo(questInfo.questID);

	-- Select the quest log entry for other functions like GetNumQuestLeaderBoards()
	C_QuestLog.SetSelectedQuest(questInfo.questID);
	
	MkQL_global_iCurrQuest = iQuestNum;
	MkQL_global_iCurrQuestId = questInfo.questID;
	
	local strQuestDescription, strQuestObjectives = GetQuestLogQuestText(iQuestNum);
	
	local strOverview = strQuestObjectives;
	
	-- Set the quest tag
	if ( isFailed ) then
		MkQL_QuestTitle_Txt:SetText(questInfo.title .. " (" .. MONKEYQUEST_QUEST_FAILED .. ")");
	elseif ( isComplete ) then
		MkQL_QuestTitle_Txt:SetText(questInfo.title .. " (" .. MONKEYQUEST_QUEST_DONE .. ")");
	else
		MkQL_QuestTitle_Txt:SetText(questInfo.title);
	end

	if (strOverview ~= nil) then
		strOverview = MkQL_HighlightText(strOverview);
	else
		MkQL_Main_Frame:Hide(); return
	end
	
	if (GetNumQuestLeaderBoards() > 0) then
		
		strOverview = strOverview .. "\n\n";

		for i=1, GetNumQuestLeaderBoards(), 1 do
			local strLeaderBoardText, strType, iFinished = GetQuestLogLeaderBoard(i);

			if (strLeaderBoardText) then
				strOverview = strOverview .. "  " .. MonkeyQuest_GetLeaderboardColorStr(strLeaderBoardText) ..
					strLeaderBoardText .. "\n";
			end
		end
	end

	MkQL_Overview_Txt:SetText(strOverview);
	MkQL_Desc_Txt:SetText(MONKEYQUESTLOG_DESC_HEADER);
	if (strQuestDescription ~= nil) then
		MkQL_DescBody_Txt:SetText(MkQL_HighlightText(strQuestDescription));
	else
		MkQL_Main_Frame:Hide(); return
	end

	MkQL_UpdateSize();

	-- REWARDS
	local numQuestRewards = GetNumQuestLogRewards(questInfo.questID);
	local numQuestChoices = GetNumQuestLogChoices(questInfo.questID);
	local rewardMoney = GetQuestLogRewardMoney(questInfo.questID);
	local name, texture, numItems, quality, isUsable = 1;
	local numTotalRewards = numQuestRewards + numQuestChoices;
	
	local rewardItem = nil;

	if ( numTotalRewards == 0 and rewardMoney == 0 ) then
		MkQL_Rewards_Txt:SetText("");
		MkQL_local_iExtraHeight = 0;
	else
		MkQL_Rewards_Txt:SetText(MONKEYQUESTLOG_REWARDS_HEADER);
		MkQL_local_iExtraHeight = 16;
	end

	-- debug info

	MonkeyLib_DebugMsg("numQuestChoices=" .. numQuestChoices);
	MonkeyLib_DebugMsg("numQuestRewards=" .. numQuestRewards);
	MonkeyLib_DebugMsg("rewardMoney=" .. rewardMoney);
		
	-- first erase the reward items
	for i=numTotalRewards + 1, MkQL_MAX_REWARDS, 1 do
		rewardItem = _G["MkQL_RewardItem"..i.."_Btn"];

		if (rewardItem ~= nil) then
			rewardItem:Hide();
		end
	end
	

	if (numQuestChoices > 0) then
		MkQL_RewardsChoose_Txt:SetText(MkQL_REWARDSCHOOSE_TXT);
		
		-- anchor the reward items
		MkQL_RewardItem1_Btn:SetPoint("TOPLEFT", "MkQL_RewardsChoose_Btn", "BOTTOMLEFT", 0, -4);
		MkQL_local_iExtraHeight = MkQL_local_iExtraHeight + 4;
		
	else
		MkQL_RewardsChoose_Txt:SetText("");
	end

	-- blah blah do the choices
	for i=1, numQuestChoices, 1 do
		
		rewardItem = _G["MkQL_RewardItem"..(i).."_Btn"];
		rewardItem.type = "choice";
		numItems = 1;
		name, texture, numItems, quality, isUsable = GetQuestLogChoiceInfo(i);

		rewardItem:SetID(i)
		rewardItem:Show();
		
		-- For the tooltip
		rewardItem.rewardType = "item";
		SetItemButtonCount(rewardItem, numItems);
		SetItemButtonTexture(rewardItem, texture);
		if ( isUsable ) then
			SetItemButtonTextureVertexColor(rewardItem, 1.0, 1.0, 1.0);
		else
			SetItemButtonTextureVertexColor(rewardItem, 0.5, 0, 0);
		end
		
		rewardItem:ClearAllPoints();
		
		if (i > 1) then
			rewardItem:SetPoint("TOPLEFT", "MkQL_RewardItem"..(i - 1).."_Btn", "TOPRIGHT", 4, 0);
		else
			rewardItem:SetPoint("TOPLEFT", "MkQL_RewardsChoose_Btn", "BOTTOMLEFT", 0, -10);
		end
		
		MonkeyLib_DebugMsg("Quest choices loop!");
	end
	
	
	-- do the rewards
	if (numQuestRewards > 0 or rewardMoney > 0) then
		MkQL_RewardsReceive_Txt:SetText(MkQL_REWARDSRECEIVE_TXT);
		
		if (numQuestChoices > 0) then
			-- re anchor
			MkQL_RewardsReceive_Btn:SetPoint("TOPLEFT", "MkQL_RewardItem1_Btn", "BOTTOMLEFT", 0, -15);
		else
			MkQL_RewardsReceive_Btn:SetPoint("TOPLEFT", "MkQL_Rewards_Btn", "BOTTOMLEFT", 0, -4);
		end

		MkQL_local_iExtraHeight = MkQL_local_iExtraHeight + 8;
	else
		MkQL_RewardsReceive_Txt:SetText("");
	end
	
	

	for i=1, numQuestRewards, 1 do
		rewardItem = _G["MkQL_RewardItem"..(i + numQuestChoices).."_Btn"];
		rewardItem.type = "reward";
		numItems = 1;
		name, texture, numItems, quality, isUsable = GetQuestLogRewardInfo(i, questInfo.questID);

		rewardItem:SetID(i)
		rewardItem:Show();
		
		-- For the tooltip
		rewardItem.rewardType = "item";
		SetItemButtonCount(rewardItem, numItems);
		SetItemButtonTexture(rewardItem, texture);
		if ( isUsable ) then
			SetItemButtonTextureVertexColor(rewardItem, 1.0, 1.0, 1.0);
		else
			SetItemButtonTextureVertexColor(rewardItem, 0.5, 0, 0);
		end
		
		rewardItem:ClearAllPoints();
		
		if (i > 1) then
			rewardItem:SetPoint("TOPLEFT", "MkQL_RewardItem"..(i + numQuestChoices - 1).."_Btn", "TOPRIGHT", 4, 0);
		else
			rewardItem:SetPoint("TOPLEFT", "MkQL_RewardsReceive_Btn", "BOTTOMLEFT", 0, -4);
		end
		
		MonkeyLib_DebugMsg("Quest rewards loop!");
	end

	if (rewardMoney == 0) then
		MkQL_RewardMoney_Frame:Hide();
	else
		-- the money
		MkQL_RewardMoney_Frame:Show();
		MoneyFrame_Update("MkQL_RewardMoney_Frame", rewardMoney);
		
		MkQL_RewardMoney_Frame:ClearAllPoints();
		
		if (numQuestRewards > 0) then
			MkQL_RewardMoney_Frame:SetPoint("TOPLEFT", "MkQL_RewardItem"..(1 + numQuestChoices).."_Btn", "BOTTOMLEFT", 0, -4);
		else
			MkQL_RewardMoney_Frame:SetPoint("TOPLEFT", "MkQL_RewardsReceive_Btn", "BOTTOMLEFT", 0, -3);
		end
		
		MkQL_local_iExtraHeight = MkQL_local_iExtraHeight + 4;
	end
	
	-- share button
	-- Determine whether the selected quest is shareable or not
	if (C_QuestLog.IsPushableQuest(questInfo.questID) and GetNumSubgroupMembers() > 0) then
		MkQL_ShareQuest_Btn:Enable();
	else
		MkQL_ShareQuest_Btn:Disable();
	end
	
	-- abandon button
	-- Determine whether the selected quest is abandonable or not
	if (C_QuestLog.CanAbandonQuest(questInfo.questID)) then
		MkQL_AbandonQuest_Btn:Enable();
	else
		MkQL_AbandonQuest_Btn:Disable();
	end

	MkQL_UpdateSize();
end

function MkQL_Money_Frame_OnLoad(self)
	MoneyFrame_OnLoad(self);
	MoneyFrame_SetType(self, "STATIC");
end

function MkQL_UpdateSize()

	local iWidth = MkQL_Main_Frame:GetWidth() - 48;


	MkQL_Title_Txt:SetWidth(iWidth);

	MkQL_QuestTitle_Txt:SetWidth(iWidth);
	MkQL_Overview_Txt:SetWidth(iWidth);
	
	MkQL_Desc_Txt:SetWidth(iWidth);
	MkQL_DescBody_Txt:SetWidth(iWidth);
	
	MkQL_RewardsChoose_Txt:SetWidth(iWidth);
	MkQL_RewardsReceive_Txt:SetWidth(iWidth);


	MkQL_Title_Btn:SetHeight(MkQL_Title_Txt:GetHeight());

	MkQL_QuestTitle_Btn:SetHeight(MkQL_QuestTitle_Txt:GetHeight());
	MkQL_Overview_Btn:SetHeight(MkQL_Overview_Txt:GetHeight());
	
	MkQL_Desc_Btn:SetHeight(MkQL_Desc_Txt:GetHeight());
	MkQL_DescBody_Btn:SetHeight(MkQL_DescBody_Txt:GetHeight());
	
	MkQL_RewardsChoose_Btn:SetHeight(MkQL_RewardsChoose_Txt:GetHeight());
	MkQL_RewardsReceive_Btn:SetHeight(MkQL_RewardsReceive_Txt:GetHeight());
	
	local iHeight = MkQL_Title_Txt:GetHeight() + MkQL_QuestTitle_Txt:GetHeight() + 
			MkQL_Overview_Txt:GetHeight() + MkQL_Desc_Txt:GetHeight() + MkQL_DescBody_Txt:GetHeight() +
			MkQL_RewardsChoose_Txt:GetHeight() + MkQL_RewardsReceive_Txt:GetHeight() + (MkQL_RewardItem1_Btn:GetHeight() * 2);
	
	iHeight = iHeight + 24 + MkQL_local_iExtraHeight;


	MkQL_ScrollChild:SetHeight(iHeight);
	
	MkQL_ScrollFrame:UpdateScrollChildRect();
end

-- this function is called when the frame should be dragged around
function MkQL_OnMouseDown(self, button)

	-- left button moves the frame around
	if (button == "LeftButton") then
		MkQL_Main_Frame:StartMoving();
	end
end

-- this function is called when the frame is stopped being dragged around
function MkQL_OnMouseUp(self, button)

	if (button == "LeftButton") then
		MkQL_Main_Frame:StopMovingOrSizing();
	end
end

-- this function is called when the frame should be dragged around
function MkQL_Resizer_Btn_OnMouseDown(self, button)
	MonkeyLib_DebugMsg("MkQL_Resizer_Btn_OnMouseDown "..button);
	
	-- left button moves the frame around
	if (button == "LeftButton") then
		
		MonkeyLib_DebugMsg("MkQL_Resizer_Btn_OnMouseDown");

		MkQL_Main_Frame:StartSizing();
		MkQL_local_bResizing = true;
		
	end
end

-- this function is called when the frame is stopped being dragged around
function MkQL_Resizer_Btn_OnMouseUp(self, button)
	MonkeyLib_DebugMsg("MkQL_Resizer_Btn_OnMouseUp "..button);
	if (button == "LeftButton") then
		
		MonkeyLib_DebugMsg("MkQL_Resizer_Btn_OnMouseUp");
		
		MkQL_Main_Frame:StopMovingOrSizing();
		MkQL_local_bResizing = false;
		
	end
end


function MkQL_AbandonQuest_Btn_OnMouseClick(self, button)
	local questInfo = C_QuestLog.GetInfo(MkQL_global_iCurrQuest)
	
	C_QuestLog.SetAbandonQuest();
	StaticPopup_Show("ABANDON_QUEST", questInfo.title);

	MkQL_global_iCurrQuest = 1;
end

function MkQL_ShareQuest_Btn_OnMouseClick(self, button)

	-- Remember the currently selected quest log entry
	local tmpSelectedQuestLogQuestId = C_QuestLog.GetSelectedQuest();
	
	-- Select the quest log entry for other functions like GetNumQuestLeaderBoards()
	C_QuestLog.SetSelectedQuest(MkQL_global_iCurrQuestId);
	
	-- try and share this quest with party members
	if (C_QuestLog.IsPushableQuest(MkQL_global_iCurrQuestId) and GetNumSubgroupMembers() > 0) then
		QuestLogPushQuest(MkQL_global_iCurrQuest);
	end
			
	-- Restore the currently selected quest log entry
	C_QuestLog.SetSelectedQuest(tmpSelectedQuestLogQuestId);
end