--[[
    Quest Data Exporter - Options.lua
    Configuration UI with tabbed sections
    Author: Xurkon

    Compatible with WoW 3.3.5a (Ascension)
]]

local addonName, QDE = ...

-- UI Constants
local FRAME_WIDTH = 400
local FRAME_HEIGHT = 420
local OPTION_HEIGHT = 26
local PADDING = 12

-- Main options frame
local optionsFrame = nil
local currentTab = "general"
local tabFrames = {}
local tabButtons = {}

-- Utility: Print message
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[QDE]|r " .. tostring(msg))
end

-- Create the main options frame
local function CreateOptionsFrame()
    if optionsFrame then return optionsFrame end

    -- Main frame
    local frame = CreateFrame("Frame", "QDEOptionsFrame", UIParent)
    frame:SetWidth(FRAME_WIDTH)
    frame:SetHeight(FRAME_HEIGHT)
    frame:SetPoint("CENTER", 0, 50)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:Hide()

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("|cff00ff00Quest Data Exporter|r - Options")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    -- Tab buttons container
    local tabY = -45

    -- Create tab buttons
    local function CreateTabButton(text, tabKey, xOffset)
        local btn = CreateFrame("Button", nil, frame)
        btn:SetWidth(90)
        btn:SetHeight(22)
        btn:SetPoint("TOPLEFT", PADDING + xOffset, tabY)

        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
        btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("CENTER")
        label:SetText(text)
        btn.label = label
        btn.tabKey = tabKey

        btn:SetScript("OnClick", function()
            currentTab = tabKey
            QDE:RefreshOptionsUI()
        end)

        tabButtons[tabKey] = btn
        return btn
    end

    CreateTabButton("General", "general", 0)
    CreateTabButton("Recording", "recording", 95)
    CreateTabButton("Sync", "sync", 190)

    -- Content area
    local contentY = tabY - 30

    -- ==========================================
    -- GENERAL TAB
    -- ==========================================
    local generalFrame = CreateFrame("Frame", nil, frame)
    generalFrame:SetWidth(FRAME_WIDTH - 24)
    generalFrame:SetHeight(FRAME_HEIGHT - 100)
    generalFrame:SetPoint("TOPLEFT", PADDING, contentY)
    tabFrames.general = generalFrame

    local y = 0

    -- General Settings Header
    local genHeader = generalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    genHeader:SetPoint("TOPLEFT", 0, y)
    genHeader:SetText("|cff66ff66General Settings|r")
    y = y - 25

    -- Auto-Scan checkbox
    local autoScanCB = CreateFrame("CheckButton", "QDEAutoScanCB", generalFrame, "UICheckButtonTemplate")
    autoScanCB:SetPoint("TOPLEFT", 0, y)
    _G[autoScanCB:GetName() .. "Text"]:SetText("Auto-Scan Quest Log")
    autoScanCB:SetScript("OnClick", function(self)
        QuestDataExporterDB.settings.autoScan = self:GetChecked() and true or false
        Print("Auto-scan: " .. (self:GetChecked() and "ON" or "OFF"))
    end)
    y = y - OPTION_HEIGHT

    -- Debug Mode checkbox
    local debugCB = CreateFrame("CheckButton", "QDEDebugCB", generalFrame, "UICheckButtonTemplate")
    debugCB:SetPoint("TOPLEFT", 0, y)
    _G[debugCB:GetName() .. "Text"]:SetText("Debug Mode (Verbose Logging)")
    debugCB:SetScript("OnClick", function(self)
        QuestDataExporterDB.settings.debugMode = self:GetChecked() and true or false
        if QDE.ApplySettings then QDE:ApplySettings() end
        Print("Debug mode: " .. (self:GetChecked() and "ON" or "OFF"))
    end)
    y = y - OPTION_HEIGHT * 1.5

    -- Server Identification Header
    local serverHeader = generalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    serverHeader:SetPoint("TOPLEFT", 0, y)
    serverHeader:SetText("|cff66ff66Server Identification|r")
    y = y - 20

    local serverDesc = generalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    serverDesc:SetPoint("TOPLEFT", 0, y)
    serverDesc:SetText("Set server info for database exports.")
    serverDesc:SetTextColor(0.7, 0.7, 0.7)
    y = y - 22

    -- Server Type Label
    local serverTypeLabel = generalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    serverTypeLabel:SetPoint("TOPLEFT", 0, y)
    serverTypeLabel:SetText("Server Type:")
    serverTypeLabel:SetWidth(80)
    serverTypeLabel:SetJustifyH("LEFT")

    -- Server Type Dropdown
    local serverTypes = {"ascension", "private", "official", "custom"}
    local serverTypeDropdown = CreateFrame("Frame", "QDEServerTypeDropdown", generalFrame, "UIDropDownMenuTemplate")
    serverTypeDropdown:SetPoint("TOPLEFT", 70, y + 5)
    UIDropDownMenu_SetWidth(serverTypeDropdown, 100)

    local function ServerTypeDropdown_OnClick(self)
        QuestDataExporterDB.settings.serverType = self.value
        UIDropDownMenu_SetText(serverTypeDropdown, self.value)
        Print("Server type set to: " .. self.value)
    end

    local function ServerTypeDropdown_Initialize(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, serverType in ipairs(serverTypes) do
            info.text = serverType
            info.value = serverType
            info.func = ServerTypeDropdown_OnClick
            info.checked = (QuestDataExporterDB.settings.serverType == serverType)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(serverTypeDropdown, ServerTypeDropdown_Initialize)
    generalFrame.serverTypeDropdown = serverTypeDropdown
    y = y - 30

    -- Server Name Label
    local serverNameLabel = generalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    serverNameLabel:SetPoint("TOPLEFT", 0, y)
    serverNameLabel:SetText("Server Name:")
    serverNameLabel:SetWidth(80)
    serverNameLabel:SetJustifyH("LEFT")

    -- Server Name EditBox
    local serverNameBox = CreateFrame("EditBox", "QDEServerNameBox", generalFrame, "InputBoxTemplate")
    serverNameBox:SetWidth(150)
    serverNameBox:SetHeight(20)
    serverNameBox:SetPoint("TOPLEFT", 85, y + 3)
    serverNameBox:SetAutoFocus(false)
    serverNameBox:SetMaxLetters(50)
    serverNameBox:SetScript("OnEnterPressed", function(self)
        QuestDataExporterDB.settings.serverName = self:GetText()
        self:ClearFocus()
        Print("Server name set to: " .. self:GetText())
    end)
    serverNameBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    generalFrame.serverNameBox = serverNameBox
    y = y - OPTION_HEIGHT * 1.2

    -- Statistics Header
    local statsHeader = generalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    statsHeader:SetPoint("TOPLEFT", 0, y)
    statsHeader:SetText("|cff66ff66Statistics|r")
    y = y - 25

    local statsText = generalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsText:SetPoint("TOPLEFT", 0, y)
    statsText:SetJustifyH("LEFT")
    generalFrame.statsText = statsText
    y = y - 40

    -- Buttons
    local refreshBtn = CreateFrame("Button", nil, generalFrame, "UIPanelButtonTemplate")
    refreshBtn:SetWidth(100)
    refreshBtn:SetHeight(22)
    refreshBtn:SetPoint("TOPLEFT", 0, y)
    refreshBtn:SetText("Refresh Stats")
    refreshBtn:SetScript("OnClick", function()
        if QDE.GetStats then
            statsText:SetText(QDE:GetStats())
        end
    end)

    local clearBtn = CreateFrame("Button", nil, generalFrame, "UIPanelButtonTemplate")
    clearBtn:SetWidth(100)
    clearBtn:SetHeight(22)
    clearBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 10, 0)
    clearBtn:SetText("Clear Database")
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("QDE_CONFIRM_CLEAR")
    end)

    -- ==========================================
    -- RECORDING TAB
    -- ==========================================
    local recordingFrame = CreateFrame("Frame", nil, frame)
    recordingFrame:SetWidth(FRAME_WIDTH - 24)
    recordingFrame:SetHeight(FRAME_HEIGHT - 100)
    recordingFrame:SetPoint("TOPLEFT", PADDING, contentY)
    tabFrames.recording = recordingFrame

    y = 0

    -- Recording Header
    local recHeader = recordingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    recHeader:SetPoint("TOPLEFT", 0, y)
    recHeader:SetText("|cff66ff66Data Recording|r")

    -- Select All / Deselect All buttons
    local selectAllBtn = CreateFrame("Button", nil, recordingFrame, "UIPanelButtonTemplate")
    selectAllBtn:SetWidth(70)
    selectAllBtn:SetHeight(20)
    selectAllBtn:SetPoint("TOPRIGHT", -75, y)
    selectAllBtn:SetText("All On")
    selectAllBtn:SetScript("OnClick", function()
        QuestDataExporterDB.settings.recordQuests = true
        QuestDataExporterDB.settings.recordNPCs = true
        QuestDataExporterDB.settings.recordCreatures = true
        QuestDataExporterDB.settings.recordItems = true
        QuestDataExporterDB.settings.recordLocations = true
        QuestDataExporterDB.settings.recordQuestText = true
        QuestDataExporterDB.settings.recordRewards = true
        QuestDataExporterDB.settings.recordDropSources = true
        QDE:RefreshOptionsUI()
        Print("All recording options ENABLED")
    end)

    local deselectAllBtn = CreateFrame("Button", nil, recordingFrame, "UIPanelButtonTemplate")
    deselectAllBtn:SetWidth(70)
    deselectAllBtn:SetHeight(20)
    deselectAllBtn:SetPoint("TOPRIGHT", 0, y)
    deselectAllBtn:SetText("All Off")
    deselectAllBtn:SetScript("OnClick", function()
        QuestDataExporterDB.settings.recordQuests = false
        QuestDataExporterDB.settings.recordNPCs = false
        QuestDataExporterDB.settings.recordCreatures = false
        QuestDataExporterDB.settings.recordItems = false
        QuestDataExporterDB.settings.recordLocations = false
        QuestDataExporterDB.settings.recordQuestText = false
        QuestDataExporterDB.settings.recordRewards = false
        QuestDataExporterDB.settings.recordDropSources = false
        QDE:RefreshOptionsUI()
        Print("All recording options DISABLED")
    end)

    y = y - 20

    local recDesc = recordingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recDesc:SetPoint("TOPLEFT", 0, y)
    recDesc:SetText("Choose what types of data to capture.")
    recDesc:SetTextColor(0.7, 0.7, 0.7)
    y = y - 20

    -- === Primary Data Types ===
    local primaryHeader = recordingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    primaryHeader:SetPoint("TOPLEFT", 0, y)
    primaryHeader:SetText("|cffffcc00Primary Data|r")
    y = y - 18

    -- Record Quests
    local recQuestsCB = CreateFrame("CheckButton", "QDERecQuestsCB", recordingFrame, "UICheckButtonTemplate")
    recQuestsCB:SetPoint("TOPLEFT", 0, y)
    _G[recQuestsCB:GetName() .. "Text"]:SetText("Quests (name, level, objectives)")
    recQuestsCB:SetScript("OnClick", function(self)
        QuestDataExporterDB.settings.recordQuests = self:GetChecked() and true or false
        Print("Quest recording: " .. (self:GetChecked() and "ON" or "OFF"))
    end)
    y = y - OPTION_HEIGHT

    -- Record NPCs
    local recNPCsCB = CreateFrame("CheckButton", "QDERecNPCsCB", recordingFrame, "UICheckButtonTemplate")
    recNPCsCB:SetPoint("TOPLEFT", 0, y)
    _G[recNPCsCB:GetName() .. "Text"]:SetText("NPCs (quest givers, turn-ins)")
    recNPCsCB:SetScript("OnClick", function(self)
        QuestDataExporterDB.settings.recordNPCs = self:GetChecked() and true or false
        Print("NPC recording: " .. (self:GetChecked() and "ON" or "OFF"))
    end)
    y = y - OPTION_HEIGHT

    -- Record Creatures
    local recCreaturesCB = CreateFrame("CheckButton", "QDERecCreaturesCB", recordingFrame, "UICheckButtonTemplate")
    recCreaturesCB:SetPoint("TOPLEFT", 0, y)
    _G[recCreaturesCB:GetName() .. "Text"]:SetText("Creatures (objective kills)")
    recCreaturesCB:SetScript("OnClick", function(self)
        QuestDataExporterDB.settings.recordCreatures = self:GetChecked() and true or false
        Print("Creature recording: " .. (self:GetChecked() and "ON" or "OFF"))
    end)
    y = y - OPTION_HEIGHT

    -- Record Items
    local recItemsCB = CreateFrame("CheckButton", "QDERecItemsCB", recordingFrame, "UICheckButtonTemplate")
    recItemsCB:SetPoint("TOPLEFT", 0, y)
    _G[recItemsCB:GetName() .. "Text"]:SetText("Items (quest item drops)")
    recItemsCB:SetScript("OnClick", function(self)
        QuestDataExporterDB.settings.recordItems = self:GetChecked() and true or false
        Print("Item recording: " .. (self:GetChecked() and "ON" or "OFF"))
    end)
    y = y - OPTION_HEIGHT

    -- Record Locations
    local recLocsCB = CreateFrame("CheckButton", "QDERecLocsCB", recordingFrame, "UICheckButtonTemplate")
    recLocsCB:SetPoint("TOPLEFT", 0, y)
    _G[recLocsCB:GetName() .. "Text"]:SetText("Locations (coordinates for all data)")
    recLocsCB:SetScript("OnClick", function(self)
        QuestDataExporterDB.settings.recordLocations = self:GetChecked() and true or false
        Print("Location recording: " .. (self:GetChecked() and "ON" or "OFF"))
    end)
    y = y - OPTION_HEIGHT + 5

    -- === Additional Details ===
    local detailsHeader = recordingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailsHeader:SetPoint("TOPLEFT", 0, y)
    detailsHeader:SetText("|cffffcc00Additional Details|r")
    y = y - 18

    -- Record Quest Text
    local recQuestTextCB = CreateFrame("CheckButton", "QDERecQuestTextCB", recordingFrame, "UICheckButtonTemplate")
    recQuestTextCB:SetPoint("TOPLEFT", 0, y)
    _G[recQuestTextCB:GetName() .. "Text"]:SetText("Quest Text (descriptions)")
    recQuestTextCB:SetScript("OnClick", function(self)
        QuestDataExporterDB.settings.recordQuestText = self:GetChecked() and true or false
        Print("Quest text recording: " .. (self:GetChecked() and "ON" or "OFF"))
    end)
    y = y - OPTION_HEIGHT

    -- Record Rewards
    local recRewardsCB = CreateFrame("CheckButton", "QDERecRewardsCB", recordingFrame, "UICheckButtonTemplate")
    recRewardsCB:SetPoint("TOPLEFT", 0, y)
    _G[recRewardsCB:GetName() .. "Text"]:SetText("Rewards (items, gold, XP)")
    recRewardsCB:SetScript("OnClick", function(self)
        QuestDataExporterDB.settings.recordRewards = self:GetChecked() and true or false
        Print("Reward recording: " .. (self:GetChecked() and "ON" or "OFF"))
    end)
    y = y - OPTION_HEIGHT

    -- Record Drop Sources
    local recDropSourcesCB = CreateFrame("CheckButton", "QDERecDropSourcesCB", recordingFrame, "UICheckButtonTemplate")
    recDropSourcesCB:SetPoint("TOPLEFT", 0, y)
    _G[recDropSourcesCB:GetName() .. "Text"]:SetText("Drop Sources (which creature drops item)")
    recDropSourcesCB:SetScript("OnClick", function(self)
        QuestDataExporterDB.settings.recordDropSources = self:GetChecked() and true or false
        Print("Drop source recording: " .. (self:GetChecked() and "ON" or "OFF"))
    end)

    -- ==========================================
    -- SYNC TAB
    -- ==========================================
    local syncFrame = CreateFrame("Frame", nil, frame)
    syncFrame:SetWidth(FRAME_WIDTH - 24)
    syncFrame:SetHeight(FRAME_HEIGHT - 100)
    syncFrame:SetPoint("TOPLEFT", PADDING, contentY)
    tabFrames.sync = syncFrame

    y = 0

    -- Sync Header
    local syncHeader = syncFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    syncHeader:SetPoint("TOPLEFT", 0, y)
    syncHeader:SetText("|cff66ff66Community Sync|r")
    y = y - 20

    local syncDesc = syncFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    syncDesc:SetPoint("TOPLEFT", 0, y)
    syncDesc:SetText("Share data with other QDE users.")
    syncDesc:SetTextColor(0.7, 0.7, 0.7)
    y = y - 25

    -- Enable Sync
    local syncEnableCB = CreateFrame("CheckButton", "QDESyncEnableCB", syncFrame, "UICheckButtonTemplate")
    syncEnableCB:SetPoint("TOPLEFT", 0, y)
    _G[syncEnableCB:GetName() .. "Text"]:SetText("Enable Community Sync")
    syncEnableCB:SetScript("OnClick", function(self)
        QuestDataExporterDB.settings.syncEnabled = self:GetChecked() and true or false
        Print("Community sync: " .. (self:GetChecked() and "ON" or "OFF"))
    end)
    y = y - OPTION_HEIGHT

    -- Auto Receive
    local autoReceiveCB = CreateFrame("CheckButton", "QDEAutoReceiveCB", syncFrame, "UICheckButtonTemplate")
    autoReceiveCB:SetPoint("TOPLEFT", 0, y)
    _G[autoReceiveCB:GetName() .. "Text"]:SetText("Auto-Receive Data from Others")
    autoReceiveCB:SetScript("OnClick", function(self)
        QuestDataExporterDB.settings.autoReceive = self:GetChecked() and true or false
        Print("Auto-receive: " .. (self:GetChecked() and "ON" or "OFF"))
    end)
    y = y - OPTION_HEIGHT

    -- Broadcast on Record
    local broadcastCB = CreateFrame("CheckButton", "QDEBroadcastCB", syncFrame, "UICheckButtonTemplate")
    broadcastCB:SetPoint("TOPLEFT", 0, y)
    _G[broadcastCB:GetName() .. "Text"]:SetText("Broadcast When Recording")
    broadcastCB:SetScript("OnClick", function(self)
        QuestDataExporterDB.settings.broadcastOnRecord = self:GetChecked() and true or false
        Print("Broadcast on record: " .. (self:GetChecked() and "ON" or "OFF"))
    end)
    y = y - OPTION_HEIGHT

    -- Show Channel
    local showChannelCB = CreateFrame("CheckButton", "QDEShowChannelCB", syncFrame, "UICheckButtonTemplate")
    showChannelCB:SetPoint("TOPLEFT", 0, y)
    _G[showChannelCB:GetName() .. "Text"]:SetText("Show Sync Channel in Chat")
    showChannelCB:SetScript("OnClick", function(self)
        QuestDataExporterDB.settings.showChannel = self:GetChecked() and true or false
        Print("Sync channel visible: " .. (self:GetChecked() and "YES" or "NO"))
    end)
    y = y - OPTION_HEIGHT * 1.5

    -- Commands info
    local cmdHeader = syncFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cmdHeader:SetPoint("TOPLEFT", 0, y)
    cmdHeader:SetText("|cff66ff66Sync Commands:|r")
    y = y - 18

    local cmdText = syncFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cmdText:SetPoint("TOPLEFT", 0, y)
    cmdText:SetJustifyH("LEFT")
    cmdText:SetText("/qde sync - Request data\n/qde sync on|off - Toggle sync\n/qde sync status - Show status")
    cmdText:SetTextColor(0.8, 0.8, 0.8)

    -- Store reference and return
    optionsFrame = frame

    -- Confirm clear popup
    StaticPopupDialogs["QDE_CONFIRM_CLEAR"] = {
        text = "Clear all recorded quest data?\nThis cannot be undone!",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            if QDE.ClearDB then
                QDE:ClearDB()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    return frame
end

-- Refresh UI state (update checkboxes and tab visuals)
function QDE:RefreshOptionsUI()
    if not optionsFrame then return end

    local db = QuestDataExporterDB
    if not db or not db.settings then return end

    -- Update tab button visuals
    for key, btn in pairs(tabButtons) do
        if key == currentTab then
            btn:SetBackdropColor(0.3, 0.5, 0.3, 1)
            btn:SetBackdropBorderColor(0.4, 0.8, 0.4, 1)
            btn.label:SetTextColor(0.4, 1, 0.4)
        else
            btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
            btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            btn.label:SetTextColor(1, 1, 1)
        end
    end

    -- Show/hide tab content
    for key, tabFrame in pairs(tabFrames) do
        if key == currentTab then
            tabFrame:Show()
        else
            tabFrame:Hide()
        end
    end

    -- Update checkbox states - General
    if QDEAutoScanCB then QDEAutoScanCB:SetChecked(db.settings.autoScan) end
    if QDEDebugCB then QDEDebugCB:SetChecked(db.settings.debugMode) end

    -- Update checkbox states - Recording (Primary)
    if QDERecQuestsCB then QDERecQuestsCB:SetChecked(db.settings.recordQuests ~= false) end
    if QDERecNPCsCB then QDERecNPCsCB:SetChecked(db.settings.recordNPCs ~= false) end
    if QDERecCreaturesCB then QDERecCreaturesCB:SetChecked(db.settings.recordCreatures ~= false) end
    if QDERecItemsCB then QDERecItemsCB:SetChecked(db.settings.recordItems ~= false) end
    if QDERecLocsCB then QDERecLocsCB:SetChecked(db.settings.recordLocations ~= false) end

    -- Update checkbox states - Recording (Additional Details)
    if QDERecQuestTextCB then QDERecQuestTextCB:SetChecked(db.settings.recordQuestText ~= false) end
    if QDERecRewardsCB then QDERecRewardsCB:SetChecked(db.settings.recordRewards ~= false) end
    if QDERecDropSourcesCB then QDERecDropSourcesCB:SetChecked(db.settings.recordDropSources ~= false) end

    -- Update checkbox states - Sync
    if QDESyncEnableCB then QDESyncEnableCB:SetChecked(db.settings.syncEnabled ~= false) end
    if QDEAutoReceiveCB then QDEAutoReceiveCB:SetChecked(db.settings.autoReceive ~= false) end
    if QDEBroadcastCB then QDEBroadcastCB:SetChecked(db.settings.broadcastOnRecord ~= false) end
    if QDEShowChannelCB then QDEShowChannelCB:SetChecked(db.settings.showChannel) end

    -- Update stats
    if tabFrames.general and tabFrames.general.statsText and QDE.GetStats then
        tabFrames.general.statsText:SetText(QDE:GetStats())
    end

    -- Update server identification fields
    if tabFrames.general then
        -- Server type dropdown
        if tabFrames.general.serverTypeDropdown then
            local serverType = db.settings.serverType or "private"
            UIDropDownMenu_SetText(tabFrames.general.serverTypeDropdown, serverType)
        end

        -- Server name editbox
        if tabFrames.general.serverNameBox then
            local serverName = db.settings.serverName or ""
            tabFrames.general.serverNameBox:SetText(serverName)
        end
    end
end

-- Show options window
function QDE:ShowOptions()
    local frame = CreateOptionsFrame()
    frame:Show()
    QDE:RefreshOptionsUI()
end

-- Toggle options window
function QDE:ToggleOptions()
    if optionsFrame and optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        QDE:ShowOptions()
    end
end

Print("Options module loaded. Use /qde options")
