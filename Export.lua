--[[
    Quest Data Exporter - Export.lua
    Handles data export functionality
    Author: Xurkon

    Export formats include server metadata for cross-server database portability.
    Other addon developers can use exported data by checking meta.expansion,
    meta.serverType, and meta.realm to ensure compatibility.
]]

local addonName, QDE = ...

-- Format metadata header for exports
local function FormatMetadataHeader()
    local meta = QuestDataExporterDB.meta or {}
    local lines = {
        "-- ===========================================",
        "-- Quest Data Exporter - Database Export",
        "-- ===========================================",
        "-- Generated: " .. date("%Y-%m-%d %H:%M:%S"),
        "--",
        "-- DATABASE METADATA (for addon developers):",
        "-- Server/Realm: " .. (meta.serverName or meta.realm or "Unknown"),
        "-- Server Type: " .. (meta.serverType or "private"),
        "-- Expansion: " .. (meta.expansion or "Unknown"),
        "-- Client Version: " .. (meta.clientVersion or "Unknown"),
        "-- Client Build: " .. tostring(meta.clientBuild or 0),
        "-- TOC Version: " .. tostring(meta.tocVersion or 0),
        "-- Locale: " .. (meta.locale or "enUS"),
        "-- DB Version: " .. tostring(meta.dbVersion or 1),
        "-- Addon Version: " .. (meta.addonVersion or "Unknown"),
        "-- Created: " .. (meta.createdAt and date("%Y-%m-%d %H:%M:%S", meta.createdAt) or "Unknown"),
        "-- Last Updated: " .. (meta.lastUpdated and date("%Y-%m-%d %H:%M:%S", meta.lastUpdated) or "Unknown"),
        "-- ===========================================",
        "",
    }
    return table.concat(lines, "\n")
end

-- Serialize a Lua table to string
local function SerializeTable(tbl, indent)
    if type(tbl) ~= "table" then
        if type(tbl) == "string" then
            return string.format("%q", tbl)
        else
            return tostring(tbl)
        end
    end
    
    indent = indent or 0
    local spaces = string.rep("    ", indent)
    local nextSpaces = string.rep("    ", indent + 1)
    
    local result = "{\n"
    local isArray = #tbl > 0
    
    if isArray then
        for i, v in ipairs(tbl) do
            result = result .. nextSpaces .. SerializeTable(v, indent + 1) .. ",\n"
        end
    else
        -- Sort keys for consistent output
        local keys = {}
        for k in pairs(tbl) do
            table.insert(keys, k)
        end
        table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
        end)
        
        for _, k in ipairs(keys) do
            local v = tbl[k]
            local keyStr
            if type(k) == "number" then
                keyStr = "[" .. k .. "]"
            elseif type(k) == "string" and k:match("^[%a_][%w_]*$") then
                keyStr = k
            else
                keyStr = "[" .. string.format("%q", tostring(k)) .. "]"
            end
            result = result .. nextSpaces .. keyStr .. " = " .. SerializeTable(v, indent + 1) .. ",\n"
        end
    end
    
    result = result .. spaces .. "}"
    return result
end

-- Export window frame
local exportFrame = nil

function QDE:ShowExportWindow()
    if exportFrame then
        exportFrame:Show()
        QDE:RefreshExport()
        return
    end
    
    -- Create the frame
    exportFrame = CreateFrame("Frame", "QDEExportFrame", UIParent)
    exportFrame:SetWidth(700)
    exportFrame:SetHeight(520)
    exportFrame:SetPoint("CENTER")
    exportFrame:SetMovable(true)
    exportFrame:EnableMouse(true)
    exportFrame:RegisterForDrag("LeftButton")
    exportFrame:SetScript("OnDragStart", exportFrame.StartMoving)
    exportFrame:SetScript("OnDragStop", exportFrame.StopMovingOrSizing)
    exportFrame:SetFrameStrata("DIALOG")
    
    -- Background
    exportFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    exportFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    
    -- Title
    local title = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Quest Data Exporter")
    
    -- Stats
    local stats = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stats:SetPoint("TOP", title, "BOTTOM", 0, -5)
    exportFrame.stats = stats
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    -- Scroll frame for text
    local scrollFrame = CreateFrame("ScrollFrame", "QDEExportScroll", exportFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -55)
    scrollFrame:SetPoint("BOTTOMRIGHT", -35, 80)
    
    -- Edit box
    local editBox = CreateFrame("EditBox", "QDEExportEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)
    exportFrame.editBox = editBox
    
    -- Buttons frame - Row 1 (Data type exports)
    local btnFrame = CreateFrame("Frame", nil, exportFrame)
    btnFrame:SetPoint("BOTTOMLEFT", 15, 40)
    btnFrame:SetPoint("BOTTOMRIGHT", -15, 40)
    btnFrame:SetHeight(25)

    -- Export Quests button
    local exportQuestsBtn = CreateFrame("Button", nil, btnFrame, "UIPanelButtonTemplate")
    exportQuestsBtn:SetWidth(90)
    exportQuestsBtn:SetHeight(25)
    exportQuestsBtn:SetPoint("LEFT", 0, 0)
    exportQuestsBtn:SetText("Quests")
    exportQuestsBtn:SetScript("OnClick", function()
        QDE:ExportQuests()
    end)

    -- Export NPCs button
    local exportNPCsBtn = CreateFrame("Button", nil, btnFrame, "UIPanelButtonTemplate")
    exportNPCsBtn:SetWidth(90)
    exportNPCsBtn:SetHeight(25)
    exportNPCsBtn:SetPoint("LEFT", exportQuestsBtn, "RIGHT", 5, 0)
    exportNPCsBtn:SetText("NPCs")
    exportNPCsBtn:SetScript("OnClick", function()
        QDE:ExportNPCs()
    end)

    -- Export Creatures button
    local exportCreaturesBtn = CreateFrame("Button", nil, btnFrame, "UIPanelButtonTemplate")
    exportCreaturesBtn:SetWidth(90)
    exportCreaturesBtn:SetHeight(25)
    exportCreaturesBtn:SetPoint("LEFT", exportNPCsBtn, "RIGHT", 5, 0)
    exportCreaturesBtn:SetText("Creatures")
    exportCreaturesBtn:SetScript("OnClick", function()
        QDE:ExportCreatures()
    end)

    -- Export All button
    local exportAllBtn = CreateFrame("Button", nil, btnFrame, "UIPanelButtonTemplate")
    exportAllBtn:SetWidth(90)
    exportAllBtn:SetHeight(25)
    exportAllBtn:SetPoint("LEFT", exportCreaturesBtn, "RIGHT", 5, 0)
    exportAllBtn:SetText("All")
    exportAllBtn:SetScript("OnClick", function()
        QDE:ExportAll()
    end)

    -- Select All button
    local selectAllBtn = CreateFrame("Button", nil, btnFrame, "UIPanelButtonTemplate")
    selectAllBtn:SetWidth(80)
    selectAllBtn:SetHeight(25)
    selectAllBtn:SetPoint("RIGHT", 0, 0)
    selectAllBtn:SetText("Select All")
    selectAllBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    -- Buttons frame - Row 2 (Developer exports)
    local btnFrame2 = CreateFrame("Frame", nil, exportFrame)
    btnFrame2:SetPoint("BOTTOMLEFT", 15, 10)
    btnFrame2:SetPoint("BOTTOMRIGHT", -15, 10)
    btnFrame2:SetHeight(25)

    -- Row 2 label
    local devLabel = btnFrame2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    devLabel:SetPoint("LEFT", 0, 0)
    devLabel:SetText("Developer:")
    devLabel:SetTextColor(0.7, 0.7, 0.7)

    -- Dev Export button (with schema + usage guide)
    local devExportBtn = CreateFrame("Button", nil, btnFrame2, "UIPanelButtonTemplate")
    devExportBtn:SetWidth(100)
    devExportBtn:SetHeight(25)
    devExportBtn:SetPoint("LEFT", devLabel, "RIGHT", 5, 0)
    devExportBtn:SetText("Full Guide")
    devExportBtn:SetScript("OnClick", function()
        QDE:ExportForDevelopers()
    end)
    devExportBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Developer Export")
        GameTooltip:AddLine("Full schema documentation, usage guide,", 1, 1, 1)
        GameTooltip:AddLine("and example code for addon developers.", 1, 1, 1)
        GameTooltip:Show()
    end)
    devExportBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Indexed Export button (with lookup tables)
    local indexedBtn = CreateFrame("Button", nil, btnFrame2, "UIPanelButtonTemplate")
    indexedBtn:SetWidth(100)
    indexedBtn:SetHeight(25)
    indexedBtn:SetPoint("LEFT", devExportBtn, "RIGHT", 5, 0)
    indexedBtn:SetText("With Indices")
    indexedBtn:SetScript("OnClick", function()
        QDE:ExportWithIndices()
    end)
    indexedBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Export with Indices")
        GameTooltip:AddLine("Includes pre-built lookup tables:", 1, 1, 1)
        GameTooltip:AddLine("questsByName, questsByZone, npcsByZone", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    indexedBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- JSON Export button (for external tools)
    local jsonBtn = CreateFrame("Button", nil, btnFrame2, "UIPanelButtonTemplate")
    jsonBtn:SetWidth(100)
    jsonBtn:SetHeight(25)
    jsonBtn:SetPoint("LEFT", indexedBtn, "RIGHT", 5, 0)
    jsonBtn:SetText("JSON")
    jsonBtn:SetScript("OnClick", function()
        QDE:ExportJSON()
    end)
    jsonBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("JSON Export")
        GameTooltip:AddLine("Export as JSON for external tools:", 1, 1, 1)
        GameTooltip:AddLine("Web apps, databases, Python scripts", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    jsonBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Instructions
    local instructions = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    instructions:SetPoint("BOTTOM", btnFrame, "TOP", 0, 5)
    instructions:SetText("Click a button to export, then Ctrl+C to copy")
    instructions:SetTextColor(0.7, 0.7, 0.7)
    
    exportFrame:Show()
    QDE:RefreshExport()
end

function QDE:RefreshExport()
    if exportFrame and exportFrame.stats then
        exportFrame.stats:SetText(QDE:GetStats())
    end
end

function QDE:ExportQuests()
    local output = FormatMetadataHeader()
    output = output .. "QuestData = " .. SerializeTable(QuestDataExporterDB.quests, 0) .. "\n"

    exportFrame.editBox:SetText(output)
    exportFrame.editBox:SetFocus()
    exportFrame.editBox:HighlightText()
end

function QDE:ExportNPCs()
    local output = FormatMetadataHeader()
    output = output .. "NPCData = " .. SerializeTable(QuestDataExporterDB.npcs, 0) .. "\n"

    exportFrame.editBox:SetText(output)
    exportFrame.editBox:SetFocus()
    exportFrame.editBox:HighlightText()
end

function QDE:ExportCreatures()
    local output = FormatMetadataHeader()
    output = output .. "CreatureData = " .. SerializeTable(QuestDataExporterDB.creatures, 0) .. "\n"

    exportFrame.editBox:SetText(output)
    exportFrame.editBox:SetFocus()
    exportFrame.editBox:HighlightText()
end

function QDE:ExportAll()
    local output = FormatMetadataHeader()
    output = output .. "-- Statistics: " .. QDE:GetStats() .. "\n\n"

    output = output .. "QuestDataExport = {\n"
    output = output .. "    -- Include metadata table for programmatic access\n"
    output = output .. "    meta = " .. SerializeTable(QuestDataExporterDB.meta, 1) .. ",\n\n"
    output = output .. "    quests = " .. SerializeTable(QuestDataExporterDB.quests, 1) .. ",\n\n"
    output = output .. "    npcs = " .. SerializeTable(QuestDataExporterDB.npcs, 1) .. ",\n\n"
    output = output .. "    creatures = " .. SerializeTable(QuestDataExporterDB.creatures, 1) .. ",\n"
    output = output .. "}\n"

    exportFrame.editBox:SetText(output)
    exportFrame.editBox:SetFocus()
    exportFrame.editBox:HighlightText()
end

-- Developer-friendly export with usage instructions
function QDE:ExportForDevelopers()
    local meta = QuestDataExporterDB.meta or {}

    local output = FormatMetadataHeader()
    output = output .. [[
-- ===========================================
-- USAGE GUIDE FOR ADDON DEVELOPERS
-- ===========================================
--
-- This database can be used in your addon by:
--
-- 1. Save this as "QuestDatabase.lua" in your addon folder
-- 2. Add "QuestDatabase.lua" to your .toc file (before your main lua)
-- 3. Access data via QuestDataExport global table
--
-- CHECKING SERVER COMPATIBILITY:
--   if QuestDataExport.meta.expansion == "WotLK" then
--       -- Use this data for WotLK servers
--   end
--
--   if QuestDataExport.meta.serverType == "ascension" then
--       -- Ascension-specific handling
--   end
--
-- ===========================================
-- DATA SCHEMA REFERENCE
-- ===========================================
--
-- QuestDataExport.meta = {
--     dbVersion     = number,  -- Schema version (for migrations)
--     addonVersion  = string,  -- QDE version that created this
--     expansion     = string,  -- "Classic", "TBC", "WotLK", etc.
--     serverType    = string,  -- "ascension", "private", "official"
--     serverName    = string,  -- Realm/server name
--     clientVersion = string,  -- e.g., "3.3.5a"
--     clientBuild   = number,  -- Build number
--     tocVersion    = number,  -- TOC version (30300 for WotLK)
--     locale        = string,  -- "enUS", "deDE", etc.
--     createdAt     = number,  -- Unix timestamp
--     lastUpdated   = number,  -- Unix timestamp
-- }
--
-- QuestDataExport.quests[questKey] = {
--     id            = number,  -- Quest ID (0 if unavailable)
--     name          = string,  -- Quest title
--     level         = number,  -- Quest level
--     questText     = string,  -- Description text
--     objectivesText= string,  -- Objectives summary
--     giverName     = string,  -- Quest giver NPC name
--     giverLocation = { x, y, zone, subZone, map },
--     turnInName    = string,  -- Turn-in NPC name
--     turnInLocation= { x, y, zone, subZone, map },
--     rewards = {
--         money  = number,
--         xp     = number,
--         items  = { {id, name, count, quality}, ... },
--         choices= { {id, name, count, quality}, ... },
--     },
--     objectives[index] = {
--         text      = string,  -- "Kill 10 Wolves"
--         type      = string,  -- "monster", "item", "object", "event"
--         creatures = { [name] = { locations = {{x,y,zone},...} } },
--         items     = { [name] = { locations = {...}, dropsFrom = {[creature]={count,locations}} } },
--         objects   = { [name] = { locations = {...} } },
--         locations = { {x, y, zone}, ... },
--     },
-- }
--
-- QuestDataExport.npcs[npcName] = {
--     locations   = { {x, y, zone, subZone, map}, ... },
--     questGiver  = boolean,
--     questTurnIn = boolean,
-- }
--
-- QuestDataExport.creatures[creatureName] = {
--     locations = { {x, y, zone}, ... },
-- }
--
-- ===========================================
-- EXAMPLE USAGE CODE
-- ===========================================
--
-- -- Find quest giver location
-- local function GetQuestGiverLocation(questName)
--     for key, quest in pairs(QuestDataExport.quests) do
--         if quest.name == questName and quest.giverLocation then
--             return quest.giverName, quest.giverLocation
--         end
--     end
-- end
--
-- -- Find all NPCs in a zone
-- local function GetNPCsInZone(zoneName)
--     local results = {}
--     for npcName, data in pairs(QuestDataExport.npcs) do
--         for _, loc in ipairs(data.locations) do
--             if loc.zone == zoneName then
--                 table.insert(results, {name = npcName, x = loc.x, y = loc.y})
--             end
--         end
--     end
--     return results
-- end
--
-- -- Check if data is compatible with current server
-- local function IsDataCompatible()
--     local meta = QuestDataExport.meta
--     local _, _, _, tocversion = GetBuildInfo()
--     return meta.tocVersion == tocversion
-- end
--
-- ===========================================

]]

    output = output .. "QuestDataExport = {\n"
    output = output .. "    -- Database metadata for version/server identification\n"
    output = output .. "    meta = " .. SerializeTable(QuestDataExporterDB.meta, 1) .. ",\n\n"
    output = output .. "    -- Quest data including objectives, rewards, and giver/turn-in NPCs\n"
    output = output .. "    quests = " .. SerializeTable(QuestDataExporterDB.quests, 1) .. ",\n\n"
    output = output .. "    -- NPC locations with questGiver/questTurnIn flags\n"
    output = output .. "    npcs = " .. SerializeTable(QuestDataExporterDB.npcs, 1) .. ",\n\n"
    output = output .. "    -- Creature locations linked to quest objectives\n"
    output = output .. "    creatures = " .. SerializeTable(QuestDataExporterDB.creatures, 1) .. ",\n"
    output = output .. "}\n"

    if exportFrame and exportFrame.editBox then
        exportFrame.editBox:SetText(output)
        exportFrame.editBox:SetFocus()
        exportFrame.editBox:HighlightText()
    end
end

-- Generate lookup indices for faster queries
local function GenerateIndices()
    local indices = {
        questsByName = {},      -- quest name -> quest key
        questsByZone = {},      -- zone -> list of quest keys
        npcsByZone = {},        -- zone -> list of NPC names
        creaturesByZone = {},   -- zone -> list of creature names
    }

    -- Index quests
    for key, quest in pairs(QuestDataExporterDB.quests or {}) do
        if quest.name then
            indices.questsByName[quest.name] = key
        end
        if quest.giverLocation and quest.giverLocation.zone then
            local zone = quest.giverLocation.zone
            indices.questsByZone[zone] = indices.questsByZone[zone] or {}
            table.insert(indices.questsByZone[zone], key)
        end
    end

    -- Index NPCs
    for npcName, data in pairs(QuestDataExporterDB.npcs or {}) do
        for _, loc in ipairs(data.locations or {}) do
            if loc.zone then
                indices.npcsByZone[loc.zone] = indices.npcsByZone[loc.zone] or {}
                -- Avoid duplicates
                local found = false
                for _, name in ipairs(indices.npcsByZone[loc.zone]) do
                    if name == npcName then found = true break end
                end
                if not found then
                    table.insert(indices.npcsByZone[loc.zone], npcName)
                end
            end
        end
    end

    -- Index creatures
    for creatureName, data in pairs(QuestDataExporterDB.creatures or {}) do
        for _, loc in ipairs(data.locations or {}) do
            if loc.zone then
                indices.creaturesByZone[loc.zone] = indices.creaturesByZone[loc.zone] or {}
                local found = false
                for _, name in ipairs(indices.creaturesByZone[loc.zone]) do
                    if name == creatureName then found = true break end
                end
                if not found then
                    table.insert(indices.creaturesByZone[loc.zone], creatureName)
                end
            end
        end
    end

    return indices
end

-- Export with lookup indices for faster queries
function QDE:ExportWithIndices()
    local output = FormatMetadataHeader()
    output = output .. "-- This export includes pre-built indices for faster lookups\n\n"

    local indices = GenerateIndices()

    output = output .. "QuestDataExport = {\n"
    output = output .. "    meta = " .. SerializeTable(QuestDataExporterDB.meta, 1) .. ",\n\n"
    output = output .. "    -- Lookup indices for fast queries\n"
    output = output .. "    indices = " .. SerializeTable(indices, 1) .. ",\n\n"
    output = output .. "    quests = " .. SerializeTable(QuestDataExporterDB.quests, 1) .. ",\n\n"
    output = output .. "    npcs = " .. SerializeTable(QuestDataExporterDB.npcs, 1) .. ",\n\n"
    output = output .. "    creatures = " .. SerializeTable(QuestDataExporterDB.creatures, 1) .. ",\n"
    output = output .. "}\n"

    if exportFrame and exportFrame.editBox then
        exportFrame.editBox:SetText(output)
        exportFrame.editBox:SetFocus()
        exportFrame.editBox:HighlightText()
    end
end

-- Export as JSON for external tools (web apps, databases, etc.)
function QDE:ExportJSON()
    local function ToJSON(val, indent)
        indent = indent or 0
        local spaces = string.rep("  ", indent)
        local nextSpaces = string.rep("  ", indent + 1)

        if type(val) == "nil" then
            return "null"
        elseif type(val) == "boolean" then
            return val and "true" or "false"
        elseif type(val) == "number" then
            return tostring(val)
        elseif type(val) == "string" then
            -- Escape special characters
            local escaped = val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
            return '"' .. escaped .. '"'
        elseif type(val) == "table" then
            -- Check if array
            local isArray = #val > 0
            local first = true

            if isArray then
                local result = "[\n"
                for _, v in ipairs(val) do
                    if not first then result = result .. ",\n" end
                    result = result .. nextSpaces .. ToJSON(v, indent + 1)
                    first = false
                end
                return result .. "\n" .. spaces .. "]"
            else
                local result = "{\n"
                local keys = {}
                for k in pairs(val) do table.insert(keys, k) end
                table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

                for _, k in ipairs(keys) do
                    if not first then result = result .. ",\n" end
                    local keyStr = type(k) == "string" and k or tostring(k)
                    result = result .. nextSpaces .. '"' .. keyStr .. '": ' .. ToJSON(val[k], indent + 1)
                    first = false
                end
                return result .. "\n" .. spaces .. "}"
            end
        end
        return "null"
    end

    local exportData = {
        meta = QuestDataExporterDB.meta,
        quests = QuestDataExporterDB.quests,
        npcs = QuestDataExporterDB.npcs,
        creatures = QuestDataExporterDB.creatures,
    }

    local output = ToJSON(exportData, 0)

    if exportFrame and exportFrame.editBox then
        exportFrame.editBox:SetText(output)
        exportFrame.editBox:SetFocus()
        exportFrame.editBox:HighlightText()
    end
end
