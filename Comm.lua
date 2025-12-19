--[[
    Quest Data Exporter - Comm.lua
    Handles community sync via hidden addon channel
    Author: Xurkon
    
    Uses a dedicated hidden chat channel for sync (like LootCollector).
    Channel is hidden from user by default, toggle with /qde channel show
]]

local addonName, QDE = ...

-- Constants
local ADDON_PREFIX = "QDE_SYNC"
local CHANNEL_NAME = "QDESync25"  -- Hidden sync channel
local MSG_TYPE_QUEST = "Q"
local MSG_TYPE_NPC = "N"
local MSG_TYPE_CREATURE = "C"
local MSG_TYPE_REQUEST = "R"

local SYNC_VERSION = 1
local MAX_MESSAGE_LENGTH = 250
local RATE_LIMIT_INTERVAL = 0.5
local lastSendTime = 0

-- Channel state
local channelJoined = false
local channelID = nil

-- Settings defaults
local function GetSyncSettings()
    local db = QuestDataExporterDB
    db.settings = db.settings or {}
    db.settings.syncEnabled = db.settings.syncEnabled ~= false
    db.settings.showChannel = db.settings.showChannel or false  -- Hidden by default
    db.settings.autoReceive = db.settings.autoReceive ~= false
    return db.settings
end

-- Utility: Print message
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[QDE-Sync]|r " .. tostring(msg))
end

-- Utility: Debug print
local function DebugPrint(msg)
    if QuestDataExporterDB and QuestDataExporterDB.settings and QuestDataExporterDB.settings.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[QDE-Sync]|r " .. tostring(msg))
    end
end

-- Pure alphanumeric encoding - no special characters at all
-- Format: use word delimiters instead of symbols
local function SerializeSimple(data)
    if type(data) == "table" then
        local parts = {}
        for k, v in pairs(data) do
            local key = tostring(k)
            local val = tostring(v or "")
            -- Replace spaces with underscores for transmission
            val = val:gsub(" ", "_")
            table.insert(parts, key .. "X" .. val)
        end
        return "D" .. table.concat(parts, "Y") .. "E"
    else
        local str = tostring(data or "")
        return str:gsub(" ", "_")
    end
end

-- Simple deserialization
local function DeserializeSimple(str)
    if not str or str == "" then return {} end
    if str:sub(1,1) ~= "D" then 
        return str:gsub("_", " ")
    end
    
    local data = {}
    local content = str:sub(2, -2) -- Remove D and E
    
    for pair in content:gmatch("[^Y]+") do
        local k, v = pair:match("([^X]+)X(.*)")
        if k and v then
            v = v:gsub("_", " ")
            local numVal = tonumber(v)
            data[k] = numVal or v
        end
    end
    
    return data
end

-- Join the sync channel
local function JoinSyncChannel()
    if channelJoined then return true end
    
    -- Check if already in channel
    local id = GetChannelName(CHANNEL_NAME)
    if id and id > 0 then
        channelID = id
        channelJoined = true
        DebugPrint("Already in sync channel: " .. CHANNEL_NAME)
        return true
    end
    
    -- Join the channel
    JoinChannelByName(CHANNEL_NAME)
    
    -- Wait a moment then check
    local id = GetChannelName(CHANNEL_NAME)
    if id and id > 0 then
        channelID = id
        channelJoined = true
        
        -- Hide from chat frames by default
        local settings = GetSyncSettings()
        if not settings.showChannel then
            for i = 1, NUM_CHAT_WINDOWS do
                local chatFrame = _G["ChatFrame" .. i]
                if chatFrame then
                    ChatFrame_RemoveChannel(chatFrame, CHANNEL_NAME)
                end
            end
        end
        
        DebugPrint("Joined sync channel: " .. CHANNEL_NAME .. " (ID: " .. id .. ")")
        return true
    end
    
    return false
end

-- Leave the sync channel
local function LeaveSyncChannel()
    if not channelJoined then return end
    
    LeaveChannelByName(CHANNEL_NAME)
    channelJoined = false
    channelID = nil
    DebugPrint("Left sync channel")
end

-- Toggle channel visibility in chat
local function ToggleChannelVisibility(show)
    local settings = GetSyncSettings()
    settings.showChannel = show
    
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then
            if show then
                ChatFrame_AddChannel(chatFrame, CHANNEL_NAME)
            else
                ChatFrame_RemoveChannel(chatFrame, CHANNEL_NAME)
            end
        end
    end
    
    Print("Sync channel " .. (show and "VISIBLE" or "HIDDEN") .. " in chat")
end

-- Check rate limit
local function CanSend()
    local now = GetTime()
    if now - lastSendTime < RATE_LIMIT_INTERVAL then
        return false
    end
    lastSendTime = now
    return true
end

-- Send a sync message to the hidden channel
local function SendSyncMessage(msgType, data)
    local settings = GetSyncSettings()
    if not settings.syncEnabled then return false end
    
    if not channelJoined then
        JoinSyncChannel()
    end
    
    if not channelID or channelID == 0 then
        DebugPrint("No channel available")
        return false
    end
    
    if not CanSend() then
        DebugPrint("Rate limited")
        return false
    end
    
    -- Build message: VERSIONxTYPExDATA (x as delimiter, no special chars)
    local payload = SYNC_VERSION .. "x" .. msgType .. "x" .. SerializeSimple(data)
    
    if #payload > MAX_MESSAGE_LENGTH then
        payload = payload:sub(1, MAX_MESSAGE_LENGTH)
    end
    
    -- Send to channel
    SendChatMessage(payload, "CHANNEL", nil, channelID)
    DebugPrint("Sent to channel: " .. msgType)
    return true
end

-- Broadcast quest data
function QDE:BroadcastQuest(questKey, questData)
    local settings = GetSyncSettings()
    if not settings.syncEnabled then return end
    
    local syncData = {
        k = questKey,
        n = questData.name,
        l = questData.level,
        gn = questData.giverName,
        gx = questData.giverLocation and questData.giverLocation.x,
        gy = questData.giverLocation and questData.giverLocation.y,
        gz = questData.giverLocation and questData.giverLocation.zone,
    }
    
    SendSyncMessage(MSG_TYPE_QUEST, syncData)
end

-- Broadcast NPC location
function QDE:BroadcastNPC(npcName, location)
    local settings = GetSyncSettings()
    if not settings.syncEnabled then return end
    
    local syncData = {
        n = npcName,
        x = location.x,
        y = location.y,
        z = location.zone,
    }
    
    SendSyncMessage(MSG_TYPE_NPC, syncData)
end

-- Broadcast creature location
function QDE:BroadcastCreature(creatureName, location)
    local settings = GetSyncSettings()
    if not settings.syncEnabled then return end
    
    local syncData = {
        n = creatureName,
        x = location.x,
        y = location.y,
        z = location.zone,
    }
    
    SendSyncMessage(MSG_TYPE_CREATURE, syncData)
end

-- Request data from channel
function QDE:RequestSync()
    local settings = GetSyncSettings()
    if not settings.syncEnabled then return end
    
    local syncData = { v = SYNC_VERSION }
    SendSyncMessage(MSG_TYPE_REQUEST, syncData)
    Print("Requested sync from channel")
end

-- Process received quest data
local function ProcessReceivedQuest(data, sender)
    local db = QuestDataExporterDB
    local questKey = data.k
    
    if not questKey then return end
    
    if db.quests[questKey] then
        local existing = db.quests[questKey]
        if not existing.giverName and data.gn then
            existing.giverName = data.gn
            existing.giverLocation = { x = data.gx, y = data.gy, zone = data.gz }
            DebugPrint("Updated quest giver for: " .. questKey)
        end
    else
        db.quests[questKey] = {
            name = data.n,
            level = data.l,
            giverName = data.gn,
            giverLocation = data.gx and { x = data.gx, y = data.gy, zone = data.gz } or nil,
            receivedFrom = sender,
            capturedAt = time(),
        }
        DebugPrint("Received new quest: " .. (data.n or questKey))
    end
end

-- Process received NPC data
local function ProcessReceivedNPC(data, sender)
    local db = QuestDataExporterDB
    local npcName = data.n
    
    if not npcName then return end
    
    db.npcs[npcName] = db.npcs[npcName] or {}
    
    local loc = { x = data.x, y = data.y, zone = data.z }
    for _, existingLoc in ipairs(db.npcs[npcName]) do
        if math.abs((existingLoc.x or 0) - (loc.x or 0)) < 0.01 and 
           math.abs((existingLoc.y or 0) - (loc.y or 0)) < 0.01 then
            return
        end
    end
    
    table.insert(db.npcs[npcName], loc)
    DebugPrint("Received NPC location: " .. npcName .. " from " .. sender)
end

-- Process received creature data
local function ProcessReceivedCreature(data, sender)
    local db = QuestDataExporterDB
    local creatureName = data.n
    
    if not creatureName then return end
    
    db.creatures[creatureName] = db.creatures[creatureName] or {}
    
    local loc = { x = data.x, y = data.y, zone = data.z }
    for _, existingLoc in ipairs(db.creatures[creatureName]) do
        if math.abs((existingLoc.x or 0) - (loc.x or 0)) < 0.02 and 
           math.abs((existingLoc.y or 0) - (loc.y or 0)) < 0.02 then
            return
        end
    end
    
    table.insert(db.creatures[creatureName], loc)
    DebugPrint("Received creature location: " .. creatureName .. " from " .. sender)
end

-- Handle incoming channel message
local function OnChatMessage(message, sender, ...)
    if sender == UnitName("player") then return end
    
    local settings = GetSyncSettings()
    if not settings.autoReceive then return end
    
    -- Parse message: VERSIONxTYPExDATA (x delimiter, no special chars)
    local version, msgType, payload = message:match("^(%d+)x(%w)x(.+)$")
    
    if not version or not msgType then return end
    
    version = tonumber(version)
    if version > SYNC_VERSION then return end
    
    local data = DeserializeSimple(payload)
    
    if msgType == MSG_TYPE_QUEST then
        ProcessReceivedQuest(data, sender)
    elseif msgType == MSG_TYPE_NPC then
        ProcessReceivedNPC(data, sender)
    elseif msgType == MSG_TYPE_CREATURE then
        ProcessReceivedCreature(data, sender)
    elseif msgType == MSG_TYPE_REQUEST then
        DebugPrint("Sync request from: " .. sender)
    end
end

-- Event frame
local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
commFrame:RegisterEvent("CHAT_MSG_CHANNEL")

commFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Delay channel join to avoid issues
        C_Timer = C_Timer or {}
        if C_Timer.After then
            C_Timer.After(5, JoinSyncChannel)
        else
            -- Fallback for 3.3.5a
            local timer = CreateFrame("Frame")
            timer.elapsed = 0
            timer:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = self.elapsed + elapsed
                if self.elapsed > 5 then
                    JoinSyncChannel()
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end
        
    elseif event == "CHAT_MSG_CHANNEL" then
        local message, sender, language, channelString, target, flags, unknown, channelNumber, channelName = ...
        
        -- Check if this is our sync channel
        if channelName and channelName:lower():find(CHANNEL_NAME:lower()) then
            OnChatMessage(message, sender)
        end
    end
end)

-- Slash command extensions
local originalSlashHandler = SlashCmdList["QDE"]
SlashCmdList["QDE"] = function(msg)
    local cmd = msg:lower():trim()
    
    if cmd == "sync" then
        QDE:RequestSync()
        
    elseif cmd == "sync on" then
        QuestDataExporterDB.settings.syncEnabled = true
        JoinSyncChannel()
        Print("Community sync: ON")
        
    elseif cmd == "sync off" then
        QuestDataExporterDB.settings.syncEnabled = false
        LeaveSyncChannel()
        Print("Community sync: OFF")
        
    elseif cmd == "sync status" then
        local settings = GetSyncSettings()
        Print("Sync enabled: " .. (settings.syncEnabled and "Yes" or "No"))
        Print("Channel joined: " .. (channelJoined and "Yes" or "No"))
        Print("Channel visible: " .. (settings.showChannel and "Yes" or "No"))
        Print("Auto-receive: " .. (settings.autoReceive and "Yes" or "No"))
        
    elseif cmd == "channel show" then
        ToggleChannelVisibility(true)
        
    elseif cmd == "channel hide" then
        ToggleChannelVisibility(false)
        
    else
        if originalSlashHandler then
            originalSlashHandler(msg)
        end
        
        if cmd == "" or cmd == "help" then
            Print("  /qde sync - Request data from channel")
            Print("  /qde sync on|off - Toggle sync")
            Print("  /qde sync status - Show sync status")
            Print("  /qde channel show|hide - Toggle channel visibility")
        end
    end
end

Print("Community sync loaded (hidden channel mode)")
