--[[
    Quest Data Exporter - Core.lua
    Captures quest data with smart objective tracking
    Author: Xurkon
    
    Uses objective progress change detection to accurately link
    creatures/items to specific quest objectives.
]]

local addonName, QDE = ...

-- Initialize SavedVariables
QuestDataExporterDB = QuestDataExporterDB or {
    -- Metadata for database identification
    meta = {
        dbVersion = 1,                  -- Database schema version
        addonVersion = "1.2.0",         -- QDE version that created this
        createdAt = 0,                  -- Unix timestamp when first created
        lastUpdated = 0,                -- Unix timestamp of last update
        realm = "",                     -- Realm/server name
        region = "",                    -- Region if available
        clientVersion = "",             -- Game client version (e.g., "3.3.5a")
        clientBuild = 0,                -- Client build number
        expansion = "",                 -- Expansion name (Classic, TBC, WotLK, etc.)
        serverType = "",                -- "official", "private", "ascension", etc.
        locale = "",                    -- Client locale (enUS, etc.)
    },
    quests = {},
    npcs = {},
    creatures = {},
    items = {},
    settings = {
        -- General
        autoScan = true,
        debugMode = false,
        -- Recording toggles - Primary
        recordQuests = true,
        recordNPCs = true,
        recordCreatures = true,
        recordItems = true,
        recordLocations = true,
        -- Recording toggles - Additional Details
        recordQuestText = true,
        recordRewards = true,
        recordDropSources = true,
        -- Sync settings
        syncEnabled = true,
        autoReceive = true,
        showChannel = false,
        broadcastOnRecord = true,
        -- Server identification
        serverType = "private",         -- User can set: "official", "private", "ascension", etc.
        serverName = "",                -- Custom server name for identification
    }
}

local db = nil
local DEBUG = false
local ADDON_VERSION = "1.2.0"
local DB_VERSION = 1

-- Detect expansion from client build
local function GetExpansionInfo()
    local version, build, date, tocversion = GetBuildInfo()
    local expansion = "Unknown"
    local buildNum = tonumber(build) or 0

    -- Determine expansion based on TOC version or build
    if tocversion then
        if tocversion < 20000 then
            expansion = "Classic"
        elseif tocversion < 30000 then
            expansion = "TBC"
        elseif tocversion < 40000 then
            expansion = "WotLK"
        elseif tocversion < 50000 then
            expansion = "Cataclysm"
        elseif tocversion < 60000 then
            expansion = "MoP"
        elseif tocversion < 70000 then
            expansion = "WoD"
        elseif tocversion < 80000 then
            expansion = "Legion"
        elseif tocversion < 90000 then
            expansion = "BfA"
        elseif tocversion < 100000 then
            expansion = "Shadowlands"
        else
            expansion = "Dragonflight+"
        end
    end

    return version or "unknown", buildNum, expansion, tocversion or 0
end

-- Update database metadata
local function UpdateMetadata()
    if not db then return end

    db.meta = db.meta or {}

    local version, buildNum, expansion, tocversion = GetExpansionInfo()
    local realmName = GetRealmName and GetRealmName() or "Unknown"
    local locale = GetLocale and GetLocale() or "enUS"

    -- Set creation time if not set
    if not db.meta.createdAt or db.meta.createdAt == 0 then
        db.meta.createdAt = time()
    end

    -- Always update these
    db.meta.dbVersion = DB_VERSION
    db.meta.addonVersion = ADDON_VERSION
    db.meta.lastUpdated = time()
    db.meta.realm = realmName
    db.meta.clientVersion = version
    db.meta.clientBuild = buildNum
    db.meta.expansion = expansion
    db.meta.tocVersion = tocversion
    db.meta.locale = locale

    -- Set server type from settings or detect
    if db.settings.serverType and db.settings.serverType ~= "" then
        db.meta.serverType = db.settings.serverType
    else
        -- Try to detect Ascension
        if realmName:lower():find("ascension") or realmName:lower():find("andorhal") or
           realmName:lower():find("doomhowl") or realmName:lower():find("sargeras") then
            db.meta.serverType = "ascension"
            db.settings.serverType = "ascension"
        else
            db.meta.serverType = "private"
        end
    end

    -- Custom server name
    if db.settings.serverName and db.settings.serverName ~= "" then
        db.meta.serverName = db.settings.serverName
    else
        db.meta.serverName = realmName
    end
end

-- Objective snapshot for progress tracking
local objectiveSnapshot = {}
local lastInteractedNPC = nil
local lastLootedItem = nil

-- Utility: Print message
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[QDE]|r " .. tostring(msg))
end

-- Utility: Debug print with categories
local function DebugPrint(msg, category)
    if not DEBUG then return end

    category = category or "general"
    local colors = {
        general = "ff9900",
        quest = "00ff00",
        npc = "00ffff",
        creature = "ff6666",
        item = "ffff00",
        objective = "ff00ff",
        location = "66ccff",
        sync = "cc99ff",
        event = "99ff99",
    }

    local color = colors[category] or colors.general
    local prefix = category:upper()
    DEFAULT_CHAT_FRAME:AddMessage("|cff" .. color .. "[QDE:" .. prefix .. "]|r " .. tostring(msg))
end

-- Verbose debug for recording actions
local function VerboseLog(action, dataType, name, details)
    if not DEBUG then return end

    local detailStr = ""
    if details then
        if type(details) == "table" then
            local parts = {}
            for k, v in pairs(details) do
                table.insert(parts, tostring(k) .. "=" .. tostring(v))
            end
            detailStr = " [" .. table.concat(parts, ", ") .. "]"
        else
            detailStr = " [" .. tostring(details) .. "]"
        end
    end

    DebugPrint(action .. " " .. dataType .. ": " .. tostring(name) .. detailStr, dataType:lower())
end

-- Get current player location
local function GetPlayerLocation()
    local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    local x, y = GetPlayerMapPosition("player")
    local zone = GetRealZoneText() or "Unknown"
    local subZone = GetSubZoneText() or ""
    
    return {
        map = mapID,
        x = math.floor((x or 0) * 10000) / 10000,
        y = math.floor((y or 0) * 10000) / 10000,
        zone = zone,
        subZone = subZone,
    }
end

-- Check if location already exists (within tolerance)
local function LocationExists(locationList, newLoc, tolerance)
    if not locationList then return false end
    tolerance = tolerance or 0.01
    for _, existingLoc in ipairs(locationList) do
        if math.abs((existingLoc.x or 0) - (newLoc.x or 0)) < tolerance and 
           math.abs((existingLoc.y or 0) - (newLoc.y or 0)) < tolerance then
            return true
        end
    end
    return false
end

-- Parse objective text for count (e.g., "Wolves slain: 3/10" -> 3, 10)
local function ParseObjectiveCount(text)
    if not text then return 0, 0 end
    local current, total = text:match("(%d+)/(%d+)")
    return tonumber(current) or 0, tonumber(total) or 0
end

--[[ =====================================
     OBJECTIVE SNAPSHOT SYSTEM
     Tracks before/after state to detect changes
===================================== ]]

-- Take a snapshot of all current quest objectives
local function SnapshotObjectives()
    objectiveSnapshot = {}
    
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID = GetQuestLogTitle(i)
        
        if title and not isHeader then
            local key = questID or title
            objectiveSnapshot[key] = {
                title = title,
                questIndex = i,
                objectives = {}
            }
            
            local numObjectives = GetNumQuestLeaderBoards(i)
            for j = 1, numObjectives do
                local text, objType, finished = GetQuestLogLeaderBoard(j, i)
                local current, total = ParseObjectiveCount(text)
                
                objectiveSnapshot[key].objectives[j] = {
                    text = text,
                    type = objType,
                    finished = finished,
                    current = current,
                    total = total,
                }
            end
        end
    end
    
    DebugPrint("Snapshot taken: " .. #objectiveSnapshot .. " quests")
end

-- Check what objectives changed since snapshot
local function CheckObjectiveChanges(interactionType, interactionData)
    local changes = {}
    
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID = GetQuestLogTitle(i)
        
        if title and not isHeader then
            local key = questID or title
            local snapshot = objectiveSnapshot[key]
            
            if snapshot then
                local numObjectives = GetNumQuestLeaderBoards(i)
                for j = 1, numObjectives do
                    local text, objType, finished = GetQuestLogLeaderBoard(j, i)
                    local current, total = ParseObjectiveCount(text)
                    
                    local oldObj = snapshot.objectives[j]
                    if oldObj then
                        -- Check if objective progressed
                        if current > oldObj.current or (finished and not oldObj.finished) then
                            table.insert(changes, {
                                questKey = key,
                                questTitle = title,
                                objectiveIndex = j,
                                objectiveText = text,
                                objectiveType = objType,
                                oldCount = oldObj.current,
                                newCount = current,
                            })
                            DebugPrint("Objective changed: " .. title .. " - " .. text)
                        end
                    end
                end
            end
        end
    end
    
    return changes
end

-- Record interaction data for objectives that changed
local function RecordObjectiveInteraction(changes, interactionType, interactionData, location)
    for _, change in ipairs(changes) do
        -- Ensure quest exists in database
        if not db.quests[change.questKey] then
            db.quests[change.questKey] = {
                name = change.questTitle,
                objectives = {},
                capturedAt = time(),
            }
        end
        
        local quest = db.quests[change.questKey]
        quest.objectives = quest.objectives or {}
        quest.objectives[change.objectiveIndex] = quest.objectives[change.objectiveIndex] or {
            text = change.objectiveText,
            type = change.objectiveType,
            creatures = {},
            items = {},
            objects = {},
            locations = {},
        }
        
        local obj = quest.objectives[change.objectiveIndex]
        
        -- Record based on interaction type
        if interactionType == "kill" and interactionData then
            obj.creatures[interactionData] = obj.creatures[interactionData] or { locations = {} }
            -- Only record location if enabled
            if not db or not db.settings or db.settings.recordLocations ~= false then
                if not LocationExists(obj.creatures[interactionData].locations, location) then
                    table.insert(obj.creatures[interactionData].locations, location)
                end
            end
            VerboseLog("RECORDED", "Creature", interactionData, {
                quest = change.questTitle,
                objective = change.objectiveText,
                x = location.x,
                y = location.y,
                zone = location.zone
            })

        elseif interactionType == "loot" and interactionData then
            -- Check if item recording is enabled
            if db and db.settings and db.settings.recordItems == false then
                DebugPrint("Item recording disabled, skipping: " .. interactionData, "item")
            else
                obj.items[interactionData] = obj.items[interactionData] or { locations = {}, dropsFrom = {} }

                -- Record location (if enabled)
                if not db or not db.settings or db.settings.recordLocations ~= false then
                    if not LocationExists(obj.items[interactionData].locations, location) then
                        table.insert(obj.items[interactionData].locations, location)
                    end
                end

                -- Record which creature this item drops from (if enabled)
                if (not db or not db.settings or db.settings.recordDropSources ~= false) and lastLootSource and lastLootSource.name then
                    local creatureName = lastLootSource.name
                    obj.items[interactionData].dropsFrom = obj.items[interactionData].dropsFrom or {}
                    if not obj.items[interactionData].dropsFrom[creatureName] then
                        obj.items[interactionData].dropsFrom[creatureName] = {
                            count = 0,
                            locations = {}
                        }
                    end
                    obj.items[interactionData].dropsFrom[creatureName].count =
                        (obj.items[interactionData].dropsFrom[creatureName].count or 0) + 1

                    if not db or not db.settings or db.settings.recordLocations ~= false then
                        if not LocationExists(obj.items[interactionData].dropsFrom[creatureName].locations, location) then
                            table.insert(obj.items[interactionData].dropsFrom[creatureName].locations, location)
                        end
                    end

                    VerboseLog("RECORDED", "Item", interactionData, {
                        quest = change.questTitle,
                        objective = change.objectiveText,
                        dropsFrom = creatureName,
                        dropCount = obj.items[interactionData].dropsFrom[creatureName].count,
                        x = location.x,
                        y = location.y,
                        zone = location.zone
                    })
                else
                    VerboseLog("RECORDED", "Item", interactionData, {
                        quest = change.questTitle,
                        objective = change.objectiveText,
                        dropsFrom = "unknown",
                        x = location.x,
                        y = location.y,
                        zone = location.zone
                    })
                end
            end

        elseif interactionType == "interact" and interactionData then
            obj.objects[interactionData] = obj.objects[interactionData] or { locations = {} }
            if not db or not db.settings or db.settings.recordLocations ~= false then
                if not LocationExists(obj.objects[interactionData].locations, location) then
                    table.insert(obj.objects[interactionData].locations, location)
                end
            end
            VerboseLog("RECORDED", "Object", interactionData, {
                quest = change.questTitle,
                objective = change.objectiveText,
                x = location.x,
                y = location.y,
                zone = location.zone
            })
        end

        -- Also record general location for objective (if enabled)
        if not db or not db.settings or db.settings.recordLocations ~= false then
            if not LocationExists(obj.locations, location) then
                table.insert(obj.locations, location)
            end
        end
    end
end

--[[ =====================================
     NPC TRACKING
===================================== ]]

local function RecordNPCLocation(npcName, locationType)
    if not npcName or npcName == "" then return end
    if not db then return end

    -- Check if recording NPCs is enabled
    if db.settings and db.settings.recordNPCs == false then
        DebugPrint("NPC recording disabled, skipping: " .. npcName, "npc")
        return
    end

    db.npcs[npcName] = db.npcs[npcName] or {
        locations = {},
        questGiver = false,
        questTurnIn = false,
    }

    local loc = GetPlayerLocation()
    local isNewLocation = false

    -- Only record location if enabled
    if not db.settings or db.settings.recordLocations ~= false then
        isNewLocation = not LocationExists(db.npcs[npcName].locations, loc)
        if isNewLocation then
            table.insert(db.npcs[npcName].locations, loc)
        end
    end

    if locationType == "giver" then
        db.npcs[npcName].questGiver = true
    elseif locationType == "turnin" then
        db.npcs[npcName].questTurnIn = true
    end

    VerboseLog("RECORDED", "NPC", npcName, {
        type = locationType or "unknown",
        x = loc.x,
        y = loc.y,
        zone = loc.zone,
        new = isNewLocation and "yes" or "no"
    })

    -- Broadcast to sync channel
    if QDE.BroadcastNPC and db.settings and db.settings.syncEnabled then
        QDE:BroadcastNPC(npcName, loc)
        DebugPrint("Broadcast NPC to sync channel: " .. npcName, "sync")
    end
end

--[[ =====================================
     QUEST SCANNING
===================================== ]]

local function ScanQuest(questIndex)
    local questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID = GetQuestLogTitle(questIndex)
    
    if not questTitle or isHeader then return nil end
    
    SelectQuestLogEntry(questIndex)
    
    local questDescription, questObjectives = GetQuestLogQuestText()
    local requiredMoney = GetQuestLogRequiredMoney()
    local rewardMoney = GetQuestLogRewardMoney()
    local rewardXP = GetQuestLogRewardXP and GetQuestLogRewardXP() or 0
    
    -- Get reward items
    local rewardItems = {}
    local numRewards = GetNumQuestLogRewards()
    for i = 1, numRewards do
        local name, texture, count, quality, isUsable = GetQuestLogRewardInfo(i)
        local itemLink = GetQuestLogItemLink("reward", i)
        local itemID = itemLink and tonumber(itemLink:match("item:(%d+)")) or 0
        
        table.insert(rewardItems, {
            id = itemID,
            name = name,
            count = count,
            quality = quality,
        })
    end
    
    -- Get choice rewards
    local choiceItems = {}
    local numChoices = GetNumQuestLogChoices()
    for i = 1, numChoices do
        local name, texture, count, quality, isUsable = GetQuestLogChoiceInfo(i)
        local itemLink = GetQuestLogItemLink("choice", i)
        local itemID = itemLink and tonumber(itemLink:match("item:(%d+)")) or 0
        
        table.insert(choiceItems, {
            id = itemID,
            name = name,
            count = count,
            quality = quality,
        })
    end
    
    -- Get objectives
    local objectives = {}
    local numObjectives = GetNumQuestLeaderBoards(questIndex)
    for i = 1, numObjectives do
        local text, objType, finished = GetQuestLogLeaderBoard(i, questIndex)
        objectives[i] = {
            text = text,
            type = objType,
            finished = finished,
            creatures = {},
            items = {},
            objects = {},
            locations = {},
        }
    end
    
    local questData = {
        id = questID or 0,
        name = questTitle,
        level = level,
        tag = questTag,
        suggestedGroup = suggestedGroup,
        isDaily = isDaily,
        isComplete = isComplete,
        -- Only include quest text if enabled
        questText = (not db or not db.settings or db.settings.recordQuestText ~= false) and questDescription or nil,
        objectivesText = (not db or not db.settings or db.settings.recordQuestText ~= false) and questObjectives or nil,
        requiredMoney = requiredMoney,
        -- Only include rewards if enabled
        rewards = (not db or not db.settings or db.settings.recordRewards ~= false) and {
            money = rewardMoney,
            xp = rewardXP,
            items = rewardItems,
            choices = choiceItems,
        } or nil,
        objectives = objectives,
        capturedAt = time(),
    }
    
    return questData, questID or questTitle
end

function QDE:ScanQuestLog()
    local count = 0
    local numEntries = GetNumQuestLogEntries()
    
    for i = 1, numEntries do
        local questData, questKey = ScanQuest(i)
        if questData and questKey then
            local existing = db.quests[questKey]
            if existing then
                -- Preserve captured objective data
                questData.giverName = existing.giverName
                questData.giverLocation = existing.giverLocation
                questData.turnInName = existing.turnInName
                questData.turnInLocation = existing.turnInLocation
                
                for j, obj in pairs(questData.objectives) do
                    if existing.objectives and existing.objectives[j] then
                        obj.creatures = existing.objectives[j].creatures or {}
                        obj.items = existing.objectives[j].items or {}
                        obj.objects = existing.objectives[j].objects or {}
                        obj.locations = existing.objectives[j].locations or {}
                    end
                end
            end
            
            db.quests[questKey] = questData
            count = count + 1
        end
    end
    
    -- Update snapshot after scan
    SnapshotObjectives()
    
    DebugPrint("Scanned " .. count .. " quests")
    return count
end

--[[ =====================================
     EVENT HANDLING
===================================== ]]

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("LOOT_CLOSED")
frame:RegisterEvent("UNIT_SPELLCAST_SENT")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")

local pendingKill = nil
local pendingLoot = nil
local lastLootSource = nil  -- Tracks which creature we're looting from

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == addonName then
            db = QuestDataExporterDB
            -- Ensure settings exist with defaults
            db.settings = db.settings or {}
            -- Primary recording settings
            db.settings.recordQuests = db.settings.recordQuests ~= false
            db.settings.recordNPCs = db.settings.recordNPCs ~= false
            db.settings.recordCreatures = db.settings.recordCreatures ~= false
            db.settings.recordItems = db.settings.recordItems ~= false
            db.settings.recordLocations = db.settings.recordLocations ~= false
            -- Additional detail settings (defaults for upgrading users)
            if db.settings.recordQuestText == nil then db.settings.recordQuestText = true end
            if db.settings.recordRewards == nil then db.settings.recordRewards = true end
            if db.settings.recordDropSources == nil then db.settings.recordDropSources = true end

            DEBUG = db.settings.debugMode

            -- Update database metadata for server identification
            UpdateMetadata()
            DebugPrint("Metadata updated - Server: " .. (db.meta.serverName or "unknown") .. ", Expansion: " .. (db.meta.expansion or "unknown"), "event")

            SnapshotObjectives()
            Print("Loaded v1.2.0 - Use /qde options for settings. " .. QDE:GetStats())
            DebugPrint("Addon initialized, debug mode: " .. (DEBUG and "ON" or "OFF"), "event")
        end

    elseif event == "QUEST_DETAIL" then
        DebugPrint("Event: QUEST_DETAIL fired", "event")
        local npcName = UnitName("npc")
        if npcName then
            DebugPrint("Quest giver detected: " .. npcName, "npc")
            RecordNPCLocation(npcName, "giver")
            QDE.pendingGiver = {
                name = npcName,
                location = GetPlayerLocation(),
            }
        end

    elseif event == "QUEST_ACCEPTED" then
        local questIndex = ...
        DebugPrint("Event: QUEST_ACCEPTED (index: " .. tostring(questIndex) .. ")", "event")

        if db.settings.recordQuests == false then
            DebugPrint("Quest recording disabled, skipping", "quest")
        elseif db.settings.autoScan then
            local questData, questKey = ScanQuest(questIndex)
            if questData and questKey then
                if QDE.pendingGiver then
                    questData.giverName = QDE.pendingGiver.name
                    questData.giverLocation = QDE.pendingGiver.location
                    QDE.pendingGiver = nil
                end
                db.quests[questKey] = questData

                VerboseLog("RECORDED", "Quest", questData.name, {
                    key = questKey,
                    level = questData.level,
                    giver = questData.giverName or "unknown",
                    objectives = questData.objectives and #questData.objectives or 0
                })

                if QDE.BroadcastQuest and db.settings.broadcastOnRecord then
                    QDE:BroadcastQuest(questKey, questData)
                    DebugPrint("Broadcast quest to sync channel", "sync")
                end
            end
        end
        SnapshotObjectives()

    elseif event == "QUEST_COMPLETE" then
        DebugPrint("Event: QUEST_COMPLETE fired", "event")
        local npcName = UnitName("npc")
        if npcName then
            DebugPrint("Turn-in NPC detected: " .. npcName, "npc")
            RecordNPCLocation(npcName, "turnin")
            local loc = GetPlayerLocation()
            for key, quest in pairs(db.quests) do
                if quest.isComplete == 1 or quest.isComplete == true then
                    quest.turnInName = npcName
                    quest.turnInLocation = loc
                    VerboseLog("UPDATED", "Quest", quest.name, {
                        turnIn = npcName,
                        x = loc.x,
                        y = loc.y,
                        zone = loc.zone
                    })
                    break
                end
            end
        end

    elseif event == "QUEST_LOG_UPDATE" then
        DebugPrint("Event: QUEST_LOG_UPDATE fired", "event")
        -- Check for objective changes
        if pendingKill then
            local changes = CheckObjectiveChanges("kill", pendingKill.name)
            if #changes > 0 then
                RecordObjectiveInteraction(changes, "kill", pendingKill.name, pendingKill.location)
            end
            pendingKill = nil
        end
        
        if pendingLoot then
            -- Check for any item objective changes
            local changes = CheckObjectiveChanges("loot", pendingLoot.name)
            if #changes > 0 then
                RecordObjectiveInteraction(changes, "loot", pendingLoot.name, pendingLoot.location)
                DebugPrint("Recorded " .. #changes .. " item objective(s) from " .. (pendingLoot.sourceName or "unknown"), "item")
            end
            pendingLoot = nil
            -- Clear loot source after processing
            lastLootSource = nil
        end

        -- Update snapshot
        SnapshotObjectives()
        
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags = ...

        if eventType == "PARTY_KILL" or eventType == "UNIT_DIED" then
            if dstName and dstGUID and dstGUID:find("Creature") then
                -- Check if creature recording is enabled
                if db.settings.recordCreatures == false then
                    DebugPrint("Creature recording disabled, skipping: " .. dstName, "creature")
                else
                    local loc = GetPlayerLocation()
                    pendingKill = {
                        name = dstName,
                        location = loc,
                        guid = dstGUID,
                    }
                    VerboseLog("PENDING", "Creature", dstName, {
                        event = eventType,
                        guid = dstGUID:sub(1, 20),
                        x = loc.x,
                        y = loc.y,
                        zone = loc.zone
                    })
                end
            end
        end

    elseif event == "LOOT_OPENED" then
        DebugPrint("Event: LOOT_OPENED - snapshotting objectives", "event")
        SnapshotObjectives()

        -- Track loot source from last killed creature or current target
        if pendingKill then
            lastLootSource = {
                name = pendingKill.name,
                location = pendingKill.location,
                guid = pendingKill.guid,
            }
            VerboseLog("LOOT_SOURCE", "Creature", pendingKill.name, {
                guid = pendingKill.guid and pendingKill.guid:sub(1, 20) or "unknown"
            })
        else
            -- Fallback: try to get target name
            local targetName = UnitName("target")
            if targetName and UnitIsDead("target") then
                lastLootSource = {
                    name = targetName,
                    location = GetPlayerLocation(),
                }
                VerboseLog("LOOT_SOURCE", "Creature", targetName, { source = "target" })
            end
        end

    elseif event == "LOOT_CLOSED" then
        DebugPrint("Event: LOOT_CLOSED - checking for item objectives", "event")

        -- If we have a loot source, set up pending loot for objective tracking
        if lastLootSource then
            pendingLoot = {
                name = lastLootSource.name,
                location = lastLootSource.location,
                sourceName = lastLootSource.name,
            }
            DebugPrint("Set pending loot from: " .. lastLootSource.name, "item")
        end

        -- Clear loot source after a delay (in case QUEST_LOG_UPDATE fires)
        -- We keep lastLootSource for a bit so objective changes can reference it

    elseif event == "UNIT_SPELLCAST_SENT" then
        local unit, spell, rank, target = ...
        if target and target ~= "" then
            lastInteractedNPC = target
            DebugPrint("Spellcast on target: " .. target .. " (spell: " .. tostring(spell) .. ")", "event")
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        local targetName = UnitName("target")
        if targetName then
            lastInteractedNPC = targetName
            DebugPrint("Target changed to: " .. targetName, "event")
        end
    end
end)

--[[ =====================================
     UTILITY FUNCTIONS
===================================== ]]

function QDE:GetStats()
    local questCount = 0
    local npcCount = 0
    local creatureCount = 0
    local objectiveCount = 0
    
    if db then
        for _, quest in pairs(db.quests) do 
            questCount = questCount + 1
            if quest.objectives then
                for _, obj in pairs(quest.objectives) do
                    objectiveCount = objectiveCount + 1
                    for _ in pairs(obj.creatures or {}) do
                        creatureCount = creatureCount + 1
                    end
                end
            end
        end
        for _ in pairs(db.npcs) do npcCount = npcCount + 1 end
    end
    
    return string.format("Quests: %d, NPCs: %d, Objectives: %d, Creatures: %d", 
        questCount, npcCount, objectiveCount, creatureCount)
end

function QDE:ClearDB()
    db.quests = {}
    db.npcs = {}
    db.creatures = {}
    db.items = {}
    objectiveSnapshot = {}
    Print("Database cleared.")
end

function QDE:ToggleDebug()
    if db and db.settings then
        db.settings.debugMode = not db.settings.debugMode
        DEBUG = db.settings.debugMode
        Print("Debug mode: " .. (DEBUG and "ON (verbose logging)" or "OFF"))
        if DEBUG then
            Print("Debug categories: EVENT, QUEST, NPC, CREATURE, ITEM, OBJECTIVE, LOCATION, SYNC")
        end
    end
end

-- Called when settings change from Options UI
function QDE:ApplySettings()
    if db and db.settings then
        DEBUG = db.settings.debugMode
    end
end

--[[ =====================================
     SLASH COMMANDS
===================================== ]]

SLASH_QDE1 = "/qde"
SLASH_QDE2 = "/questdataexporter"

SlashCmdList["QDE"] = function(msg)
    local cmd = msg:lower():trim()

    if cmd == "" or cmd == "help" then
        Print("Commands:")
        Print("  /qde options - Open settings window")
        Print("  /qde scan - Scan quest log")
        Print("  /qde export - Export data (opens window)")
        Print("  /qde clear - Clear database")
        Print("  /qde stats - Show statistics")
        Print("  /qde debug - Toggle debug mode")
        
    elseif cmd == "scan" then
        local count = QDE:ScanQuestLog()
        Print("Scanned " .. count .. " quests. " .. QDE:GetStats())
        
    elseif cmd == "export" then
        QDE:ShowExportWindow()
        
    elseif cmd == "clear" then
        QDE:ClearDB()
        
    elseif cmd == "stats" then
        Print(QDE:GetStats())
        
    elseif cmd == "debug" then
        QDE:ToggleDebug()

    elseif cmd == "options" or cmd == "config" or cmd == "settings" then
        if QDE.ShowOptions then
            QDE:ShowOptions()
        else
            Print("Options UI not loaded. Check addon installation.")
        end

    else
        Print("Unknown command. Use /qde help")
    end
end

_G.QDE = QDE
