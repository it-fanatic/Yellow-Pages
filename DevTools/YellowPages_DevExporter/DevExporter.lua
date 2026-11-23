--[[
    YellowPages_DevExporter: DevExporter.lua
    Entwickler-Addon zum vollständigen Export aller Rezepte (gelernt + ungelernt)
    für Data\RecipeCatalog.lua inkl. Patch-Diff gegen bereits bekannte Katalog-Einträge.
--]]

YellowPagesDev = YellowPagesDev or {}

local PROF_KEY_BY_SKILLLINE = {
    [171] = "PROF_ALCHEMY",
    [164] = "PROF_BLACKSMITHING",
    [333] = "PROF_ENCHANTING",
    [202] = "PROF_ENGINEERING",
    [773] = "PROF_INSCRIPTION",
    [755] = "PROF_JEWELCRAFTING",
    [165] = "PROF_LEATHERWORKING",
    [197] = "PROF_TAILORING",
    [186] = "PROF_MINING",
    [185] = "PROF_COOKING",
    [129] = "PROF_FIRSTAID",
}

local PROF_KEY_BY_NAME = {
    ["alchemy"]          = "PROF_ALCHEMY",
    ["alchemie"]         = "PROF_ALCHEMY",
    ["blacksmithing"]    = "PROF_BLACKSMITHING",
    ["schmiedekunst"]    = "PROF_BLACKSMITHING",
    ["enchanting"]       = "PROF_ENCHANTING",
    ["verzauberkunst"]   = "PROF_ENCHANTING",
    ["engineering"]      = "PROF_ENGINEERING",
    ["ingenieurskunst"]  = "PROF_ENGINEERING",
    ["inscription"]      = "PROF_INSCRIPTION",
    ["inschriftenkunde"] = "PROF_INSCRIPTION",
    ["jewelcrafting"]    = "PROF_JEWELCRAFTING",
    ["juwelenschleifen"] = "PROF_JEWELCRAFTING",
    ["leatherworking"]   = "PROF_LEATHERWORKING",
    ["lederverarbeitung"]= "PROF_LEATHERWORKING",
    ["tailoring"]        = "PROF_TAILORING",
    ["schneiderei"]      = "PROF_TAILORING",
    ["mining"]           = "PROF_MINING",
    ["bergbau"]          = "PROF_MINING",
    ["cooking"]          = "PROF_COOKING",
    ["kochen"]           = "PROF_COOKING",
    ["kochkunst"]        = "PROF_COOKING",
    ["first aid"]        = "PROF_FIRSTAID",
    ["erste hilfe"]      = "PROF_FIRSTAID",
}

local PROF_DISPLAY_DE = {
    PROF_ALCHEMY        = "Alchemie",
    PROF_BLACKSMITHING  = "Schmiedekunst",
    PROF_ENCHANTING     = "Verzauberkunst",
    PROF_ENGINEERING    = "Ingenieurskunst",
    PROF_INSCRIPTION    = "Inschriftenkunde",
    PROF_JEWELCRAFTING  = "Juwelenschleifen",
    PROF_LEATHERWORKING = "Lederverarbeitung",
    PROF_TAILORING      = "Schneiderei",
    PROF_MINING         = "Bergbau",
    PROF_COOKING        = "Kochkunst",
    PROF_FIRSTAID       = "Erste Hilfe",
}

local TRADE_REQUEST_PROFS = {
    "Alchemie", "Schmiedekunst", "Verzauberkunst", "Ingenieurskunst",
    "Lederverarbeitung", "Schneiderei", "Juwelenschleifen", "Inschriftenkunde",
    "Kochkunst", "Erste Hilfe",
}
local selectedTradeProfIdx = 1
local pendingThankYou = nil
local requestedProfs = {} -- [profKey] = timestamp (nur für per Button angefragte Berufe)

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[YP-Dev]|r " .. tostring(msg))
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
    return nil
end

local function ResolveProfKey(rawName, skillLineID)
    if skillLineID and PROF_KEY_BY_SKILLLINE[skillLineID] then
        return PROF_KEY_BY_SKILLLINE[skillLineID]
    end
    if rawName and rawName ~= "" then
        return PROF_KEY_BY_NAME[rawName:lower()] or rawName
    end
    return "GENERAL"
end

local function GetItemInfoSafe(itemID)
    if not itemID or itemID == 0 then return nil end
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(itemID)
    elseif GetItemInfo then
        return GetItemInfo(itemID)
    end
    return nil
end

local function IsInMainCatalog(recipeID)
    return YellowPages and YellowPages.RecipeCatalog and YellowPages.RecipeCatalog[recipeID] ~= nil
end

local function SaveScannedRecipe(entry)
    YellowPagesDevDB = YellowPagesDevDB or { recipes = {} }
    YellowPagesDevDB.recipes = YellowPagesDevDB.recipes or {}

    local isNew = (YellowPagesDevDB.recipes[entry.id] == nil)
    YellowPagesDevDB.recipes[entry.id] = entry
    return isNew, not IsInMainCatalog(entry.id)
end

-- Scannt ALLE Rezepte über C_TradeSkillUI (gelernt + ungelernt!)
local function ScanModernAll()
    local T = C_TradeSkillUI
    if not T or not T.GetAllRecipeIDs then return false end

    local ok, recipeIDs = pcall(T.GetAllRecipeIDs)
    if not ok or type(recipeIDs) ~= "table" or #recipeIDs == 0 then return false end

    local profName, profID
    if T.GetBaseProfessionInfo then
        local info = SafeCall(T.GetBaseProfessionInfo)
        if type(info) == "table" then
            profID = info.professionID or info.parentProfessionID
            profName = info.professionName
        end
    end
    if not profName and T.GetTradeSkillLineInfo then
        local lineInfo = SafeCall(T.GetTradeSkillLineInfo)
        if type(lineInfo) == "table" then
            profID = lineInfo.professionID or lineInfo.parentProfessionID
            profName = lineInfo.tradeSkillDisplayName or lineInfo.professionName
        end
    end
    if not profName and T.GetTradeSkillLine then
        local a, b = SafeCall(T.GetTradeSkillLine)
        if type(a) == "number" then
            profID, profName = a, b
        elseif type(a) == "string" then
            profName = a
        end
    end

    local profKey = ResolveProfKey(profName, profID)
    local total, newInCatalog = 0, 0

    for _, recipeID in ipairs(recipeIDs) do
        local rInfo = T.GetRecipeInfo and SafeCall(T.GetRecipeInfo, recipeID)
        if type(rInfo) == "table" then
            local reagents = {}
            local outputItemID = 0
            local minMade, maxMade = rInfo.minMade or 1, rInfo.maxMade or 1
            local icon = rInfo.icon

            if T.GetRecipeSchematic then
                local sc = SafeCall(T.GetRecipeSchematic, recipeID, false)
                if type(sc) == "table" then
                    outputItemID = sc.outputItemID or outputItemID
                    minMade = sc.quantityMin or minMade
                    maxMade = sc.quantityMax or maxMade
                    icon = icon or sc.icon

                    if type(sc.reagentSlotSchematics) == "table" then
                        for _, slot in ipairs(sc.reagentSlotSchematics) do
                            if (slot.reagentType == nil or slot.reagentType == 1) and slot.reagents and slot.reagents[1] then
                                local rItemID = slot.reagents[1].itemID
                                local rCount = slot.quantityRequired or 1
                                if rItemID and rItemID > 0 then
                                    table.insert(reagents, { itemID = rItemID, count = rCount })
                                end
                            end
                        end
                    end
                end
            end

            if #reagents == 0 and T.GetRecipeNumReagents and T.GetRecipeReagentInfo then
                local numReagents = SafeCall(T.GetRecipeNumReagents, recipeID) or 0
                for rIndex = 1, numReagents do
                    local _, _, rCount = SafeCall(T.GetRecipeReagentInfo, recipeID, rIndex)
                    local rLink = T.GetRecipeReagentItemLink and SafeCall(T.GetRecipeReagentItemLink, recipeID, rIndex)
                    local rItemID = rLink and tonumber(rLink:match("item:(%d+)")) or 0
                    if rItemID and rItemID > 0 then
                        table.insert(reagents, { itemID = rItemID, count = rCount or 1 })
                    end
                end
            end

            if (not outputItemID or outputItemID == 0) and T.GetRecipeItemLink then
                local outLink = SafeCall(T.GetRecipeItemLink, recipeID)
                if outLink then
                    outputItemID = tonumber(outLink:match("item:(%d+)")) or 0
                end
            end

            local quality, level = 1, 0
            if outputItemID and outputItemID > 0 then
                local _, _, q, iLvl, reqLvl = GetItemInfoSafe(outputItemID)
                quality = q or 1
                level = (reqLvl and reqLvl > 0) and reqLvl or (iLvl or 0)
            end

            local _, isNewCat = SaveScannedRecipe({
                id = recipeID,
                name = rInfo.name or ("Rezept #" .. tostring(recipeID)),
                prof = profKey,
                itemID = outputItemID or 0,
                icon = icon,
                quality = quality,
                level = level,
                minMade = minMade,
                maxMade = maxMade,
                reagents = reagents,
            })

            total = total + 1
            if isNewCat then newInCatalog = newInCatalog + 1 end
        end
    end

    return true, profKey, total, newInCatalog
end

-- Fallback: Classic GetTradeSkill*
local function ScanClassicAll()
    if not GetTradeSkillLine or not GetNumTradeSkills then return false end
    local rawProfName = GetTradeSkillLine()
    if not rawProfName or rawProfName == "" or rawProfName == "UNKNOWN" then return false end

    local numSkills = GetNumTradeSkills() or 0
    if numSkills <= 0 then return false end

    local profKey = ResolveProfKey(rawProfName, nil)
    local total, newInCatalog = 0, 0

    for i = 1, numSkills do
        local name, skillType, _, _, _, numMade = GetTradeSkillInfo(i)
        if skillType and skillType ~= "header" and skillType ~= "subheader" and name and name ~= "" then
            local itemLink = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
            local recipeLink = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)
            local recipeID = 0
            if recipeLink then
                recipeID = tonumber(recipeLink:match("enchant:(%d+)") or recipeLink:match("spell:(%d+)")) or 0
            end
            local outputItemID = itemLink and tonumber(itemLink:match("item:(%d+)")) or 0
            if recipeID == 0 and outputItemID > 0 then recipeID = outputItemID end

            if recipeID > 0 then
                local reagents = {}
                local numReagents = GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0
                for r = 1, numReagents do
                    local _, _, rCount = GetTradeSkillReagentInfo(i, r)
                    local rLink = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, r)
                    local rItemID = rLink and tonumber(rLink:match("item:(%d+)")) or 0
                    if rItemID > 0 then
                        table.insert(reagents, { itemID = rItemID, count = rCount or 1 })
                    end
                end

                local quality, level = 1, 0
                if outputItemID > 0 then
                    local _, _, q, iLvl, reqLvl = GetItemInfoSafe(outputItemID)
                    quality = q or 1
                    level = (reqLvl and reqLvl > 0) and reqLvl or (iLvl or 0)
                end

                local _, isNewCat = SaveScannedRecipe({
                    id = recipeID,
                    name = name,
                    prof = profKey,
                    itemID = outputItemID,
                    icon = GetTradeSkillIcon and GetTradeSkillIcon(i),
                    quality = quality,
                    level = level,
                    minMade = numMade or 1,
                    maxMade = numMade or 1,
                    reagents = reagents,
                })

                total = total + 1
                if isNewCat then newInCatalog = newInCatalog + 1 end
            end
        end
    end

    return total > 0, profKey, total, newInCatalog
end

function YellowPagesDev:ScanOpenProfession(verbose)
    local ok, profKey, total, newInCatalog = ScanModernAll()
    if not ok then
        ok, profKey, total, newInCatalog = ScanClassicAll()
    end
    if ok then
        YellowPagesDevDB = YellowPagesDevDB or { recipes = {}, capturedLinks = {}, profTimestamps = {} }
        YellowPagesDevDB.profTimestamps = YellowPagesDevDB.profTimestamps or {}
        if profKey then
            YellowPagesDevDB.profTimestamps[profKey] = time()
        end

        if verbose then
            local label = PROF_DISPLAY_DE[profKey] or tostring(profKey)
            Print(string.format("%s gescannt: |cffffffff%d|r Rezepte gesamt (|cff00ff00%d neu|r gegenüber RecipeCatalog).",
                label, total, newInCatalog))
        end

        if pendingThankYou and pendingThankYou.sender and (time() - (pendingThankYou.time or 0) <= 30) then
            local target = pendingThankYou.sender
            local pLabel = pendingThankYou.profLabel or (PROF_DISPLAY_DE[profKey] or "Beruf")
            local entryRef = pendingThankYou.entry
            local reqKey = pendingThankYou.reqKey
            pendingThankYou = nil
            local thankMsg = string.format("Vielen Dank für deinen %s-Link! :)", pLabel)
            local sentOk = pcall(SendChatMessage, thankMsg, "WHISPER", nil, target)
            if sentOk then
                if entryRef then entryRef.thanked = true end
                if reqKey then requestedProfs[reqKey] = nil end
                Print(string.format("Danke-Flüsternachricht an |cffffd100%s|r gesendet.", target))
            end
        end

        if self.RefreshUI then self:RefreshUI() end
    elseif verbose then
        Print("Kein offenes Berufsfenster gefunden.")
    end
    return ok
end

local function EscapeLuaString(s)
    return tostring(s or ""):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", " ")
end

function YellowPagesDev:BuildExportLua(onlyNew)
    YellowPagesDevDB = YellowPagesDevDB or { recipes = {} }
    local list = {}
    for id, r in pairs(YellowPagesDevDB.recipes or {}) do
        if not onlyNew or not IsInMainCatalog(id) then
            table.insert(list, r)
        end
    end
    table.sort(list, function(a, b)
        if a.prof ~= b.prof then return (a.prof or "") < (b.prof or "") end
        return (a.id or 0) < (b.id or 0)
    end)

    local lines = {}
    table.insert(lines, string.format("-- Exportiert am %s (%d Rezepte)", date("%Y-%m-%d %H:%M:%S"), #list))
    for _, r in ipairs(list) do
        local matParts = {}
        for _, m in ipairs(r.reagents or {}) do
            table.insert(matParts, string.format("{ %d, %d }", m.itemID, m.count or 1))
        end
        local iconStr = r.icon and string.format('"%s"', EscapeLuaString(r.icon)) or "nil"
        table.insert(lines, string.format(
            'YellowPages.RecipeCatalog[%d] = { name = "%s", prof = "%s", itemID = %d, icon = %s, quality = %d, level = %d, minMade = %d, maxMade = %d, reagents = { %s } }',
            r.id,
            EscapeLuaString(r.name),
            EscapeLuaString(r.prof),
            r.itemID or 0,
            iconStr,
            r.quality or 1,
            r.level or 0,
            r.minMade or 1,
            r.maxMade or 1,
            table.concat(matParts, ", ")
        ))
    end

    local result = table.concat(lines, "\n")
    YellowPagesDevDB.lastExportLua = result
    return result, #list
end

-- ============================================================================
-- CHAT-LINK-SAMMLER (Handelschannel, Gilde, Sagen, Flüstern)
-- ============================================================================
local function StripRealm(name)
    if not name or name == "" then return nil end
    return (name:match("^(.-)%-[^%-]+$") or name):gsub("^%s+", ""):gsub("%s+$", "")
end

function YellowPagesDev:CaptureChatLinks(msg, sender)
    if type(msg) ~= "string" or msg == "" then return end
    YellowPagesDevDB = YellowPagesDevDB or { recipes = {}, capturedLinks = {} }
    YellowPagesDevDB.capturedLinks = YellowPagesDevDB.capturedLinks or {}

    local cleanSender = StripRealm(sender) or "Unbekannt"

    -- Unterstützt farbige und unfarbige Trade/Craft-Hyperlinks (reines Lua-Pattern)
    local foundAny = false
    for linkData, bracketName in msg:gmatch("|H([^|]+)|h(%[[^%]]+%])|h") do
        if linkData:sub(1, 6) == "trade:" or linkData:sub(1, 6) == "craft:" then
            local fullLink = "|cffffd000|H" .. linkData .. "|h" .. bracketName .. "|h|r"
            local key = cleanSender:lower() .. "_" .. bracketName:lower()
            local existing = YellowPagesDevDB.capturedLinks[key]
            local isBrandNew = (existing == nil)

            YellowPagesDevDB.capturedLinks[key] = {
                key = key,
                sender = cleanSender,
                profLabel = bracketName:gsub("[%[%]]", ""),
                link = linkData,
                fullLink = fullLink,
                timestamp = time(),
                opened = existing and existing.opened or false,
            }
            foundAny = true
            if isBrandNew then
                Print(string.format("Berufslink gesammelt: %s von |cffffd100%s|r (im Fenster |cffffd100/ypdev|r anklicken)", fullLink, cleanSender))
            end
        end
    end

    if foundAny and self.RefreshLinksUI then
        self:RefreshLinksUI()
    end
end

-- ============================================================================
-- DEV UI (/ypdev)
-- ============================================================================
local devFrame = nil

function YellowPagesDev:RefreshLinksUI()
    if not devFrame or not devFrame.linksScrollChild then return end
    YellowPagesDevDB = YellowPagesDevDB or { recipes = {}, capturedLinks = {} }
    YellowPagesDevDB.capturedLinks = YellowPagesDevDB.capturedLinks or {}

    local list = {}
    for _, entry in pairs(YellowPagesDevDB.capturedLinks) do
        table.insert(list, entry)
    end
    table.sort(list, function(a, b)
        if (a.opened and 1 or 0) ~= (b.opened and 1 or 0) then
            return not a.opened
        end
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)

    if devFrame.linksTitle then
        devFrame.linksTitle:SetText(string.format("|cffffd100Chat-Berufslinks (%d)|r", #list))
    end

    local child = devFrame.linksScrollChild
    child.rows = child.rows or {}
    for _, r in ipairs(child.rows) do r:Hide() end

    local y = 0
    for i, entry in ipairs(list) do
        local row = child.rows[i]
        if not row then
            row = CreateFrame("Button", nil, child)
            row:SetSize(258, 34)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            row.bg = bg

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 0.82, 0.3, 0.15)
            row:SetHighlightTexture(hl)

            local titleTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            titleTxt:SetPoint("TOPLEFT", 6, -4)
            titleTxt:SetPoint("RIGHT", -56, 0)
            titleTxt:SetJustifyH("LEFT")
            row.titleTxt = titleTxt

            local senderTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            senderTxt:SetPoint("BOTTOMLEFT", 6, 4)
            senderTxt:SetPoint("RIGHT", -56, 0)
            senderTxt:SetJustifyH("LEFT")
            row.senderTxt = senderTxt

            local statusTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            statusTxt:SetPoint("RIGHT", -6, 0)
            statusTxt:SetJustifyH("RIGHT")
            row.statusTxt = statusTxt

            row:SetScript("OnClick", function(self)
                local e = self.entryData
                if not e then return end
                e.opened = true

                local reqKey = ResolveProfKey(e.profLabel, nil)
                local reqTime = reqKey and requestedProfs[reqKey]
                if not e.thanked and reqTime and (time() - reqTime <= 600) then
                    pendingThankYou = {
                        sender = e.sender,
                        profLabel = e.profLabel,
                        time = time(),
                        entry = e,
                        reqKey = reqKey,
                    }
                else
                    pendingThankYou = nil
                end

                YellowPagesDev:RefreshLinksUI()
                if SetItemRef then
                    SetItemRef(e.link, e.fullLink, "LeftButton")
                end
            end)

            child.rows[i] = row
        end

        row:SetPoint("TOPLEFT", 0, y)
        row.entryData = entry
        row.bg:SetColorTexture(1, 1, 1, (i % 2 == 1) and 0.04 or 0.01)

        if entry.opened then
            row.titleTxt:SetText("|cff888888[" .. (entry.profLabel or "Beruf") .. "]|r")
            row.senderTxt:SetText("|cff777777" .. (entry.sender or "?") .. "|r")
            row.statusTxt:SetText("|cff66cc66[OK]|r")
        else
            row.titleTxt:SetText("|cffffd100[" .. (entry.profLabel or "Beruf") .. "]|r")
            row.senderTxt:SetText("|cffffffff" .. (entry.sender or "?") .. "|r")
            row.statusTxt:SetText("|cff00ccff[Öffnen]|r")
        end

        row:Show()
        y = y - 35
    end
    child:SetHeight(math.max(10, math.abs(y)))
end

function YellowPagesDev:RefreshUI()
    if not devFrame or not devFrame.statsText then return end
    YellowPagesDevDB = YellowPagesDevDB or { recipes = {}, capturedLinks = {} }

    local byProf = {}
    local totalAll, totalNew = 0, 0
    for id, r in pairs(YellowPagesDevDB.recipes or {}) do
        local p = r.prof or "GENERAL"
        byProf[p] = byProf[p] or { total = 0, newCount = 0 }
        byProf[p].total = byProf[p].total + 1
        totalAll = totalAll + 1
        if not IsInMainCatalog(id) then
            byProf[p].newCount = byProf[p].newCount + 1
            totalNew = totalNew + 1
        end
    end

    local timestamps = YellowPagesDevDB.profTimestamps or {}
    local parts = {}
    for p, st in pairs(byProf) do
        local label = PROF_DISPLAY_DE[p] or p
        local tsStr = timestamps[p] and ("  |cffaaaaaa[" .. date("%d.%m. %H:%M", timestamps[p]) .. "]|r") or ""
        table.insert(parts, string.format("• |cffffd100%s:|r %d (|cff00ff00+%d neu|r)%s", label, st.total, st.newCount, tsStr))
    end
    table.sort(parts)
    devFrame.statsText:SetText(string.format("Gesamt: |cffffffff%d|r Rezepte (|cff00ff00%d neu|r)\n%s",
        totalAll, totalNew, #parts > 0 and table.concat(parts, "\n") or "Noch nichts gescannt — öffne ein Berufsfenster!"))

    self:RefreshLinksUI()
end

function YellowPagesDev:ToggleUI()
    if not devFrame then
        devFrame = CreateFrame("Frame", "YellowPagesDevFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
        devFrame:SetSize(980, 490)
        devFrame:SetPoint("CENTER")
        devFrame:SetFrameStrata("DIALOG")
        devFrame:SetMovable(true)
        devFrame:EnableMouse(true)
        devFrame:RegisterForDrag("LeftButton")
        devFrame:SetScript("OnDragStart", devFrame.StartMoving)
        devFrame:SetScript("OnDragStop", devFrame.StopMovingOrSizing)
        if devFrame.SetBackdrop then
            devFrame:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 24,
                insets = { left = 6, right = 6, top = 6, bottom = 6 }
            })
        end

        local title = devFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 18, -16)
        title:SetText("|cffffd100Yellow-Pages DEV Exporter|r")

        local closeBtn = CreateFrame("Button", nil, devFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -6, -6)

        local statsText = devFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statsText:SetPoint("TOPLEFT", 18, -44)
        statsText:SetWidth(640)
        statsText:SetJustifyH("LEFT")
        devFrame.statsText = statsText

        local scroll = CreateFrame("ScrollFrame", "YellowPagesDevScroll", devFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", statsText, "BOTTOMLEFT", 0, -10)
        scroll:SetPoint("BOTTOMRIGHT", -326, 48)

        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(610)
        editBox:SetAutoFocus(false)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scroll:SetScrollChild(editBox)
        devFrame.editBox = editBox

        local function DoExport(onlyNew)
            local txt, count = YellowPagesDev:BuildExportLua(onlyNew)
            editBox:SetText(txt)
            editBox:HighlightText()
            editBox:SetFocus()
            Print(string.format("Export erstellt (%d Rezepte). Strg+C zum Kopieren — oder direkt aus SavedVariables\\YellowPages_DevExporter.lua lesen!", count))
        end

        local btnScan = CreateFrame("Button", nil, devFrame, "UIPanelButtonTemplate")
        btnScan:SetSize(135, 24)
        btnScan:SetPoint("BOTTOMLEFT", 18, 14)
        btnScan:SetText("Beruf scannen")
        btnScan:SetScript("OnClick", function() YellowPagesDev:ScanOpenProfession(true) end)

        local btnExpNew = CreateFrame("Button", nil, devFrame, "UIPanelButtonTemplate")
        btnExpNew:SetSize(155, 24)
        btnExpNew:SetPoint("LEFT", btnScan, "RIGHT", 8, 0)
        btnExpNew:SetText("Nur NEUE exportieren")
        btnExpNew:SetScript("OnClick", function() DoExport(true) end)

        local btnExpAll = CreateFrame("Button", nil, devFrame, "UIPanelButtonTemplate")
        btnExpAll:SetSize(145, 24)
        btnExpAll:SetPoint("LEFT", btnExpNew, "RIGHT", 8, 0)
        btnExpAll:SetText("ALLE exportieren")
        btnExpAll:SetScript("OnClick", function() DoExport(false) end)

        local btnClear = CreateFrame("Button", nil, devFrame, "UIPanelButtonTemplate")
        btnClear:SetSize(105, 24)
        btnClear:SetPoint("LEFT", btnExpAll, "RIGHT", 8, 0)
        btnClear:SetText("DB leeren")
        btnClear:SetScript("OnClick", function()
            YellowPagesDevDB = YellowPagesDevDB or {}
            YellowPagesDevDB.recipes = {}
            YellowPagesDevDB.lastExportLua = nil
            editBox:SetText("")
            YellowPagesDev:RefreshUI()
            Print("DEV-Rezeptdatenbank geleert.")
        end)

        -- Rechtes Panel: Chat-Berufslinks-Sammler & Handels-Anfrage
        local linksTitle = devFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        linksTitle:SetPoint("TOPLEFT", 682, -44)
        linksTitle:SetText("|cffffd100Chat-Berufslinks (0)|r")
        devFrame.linksTitle = linksTitle

        local linksHint = devFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        linksHint:SetPoint("TOPLEFT", 682, -60)
        linksHint:SetWidth(276)
        linksHint:SetJustifyH("LEFT")
        linksHint:SetText("Klicke auf einen Link (öffnet + bedankt sich nach Scan):")

        local btnPickProf = CreateFrame("Button", nil, devFrame, "UIPanelButtonTemplate")
        btnPickProf:SetSize(134, 22)
        btnPickProf:SetPoint("TOPLEFT", 682, -86)
        btnPickProf:SetText("< " .. TRADE_REQUEST_PROFS[selectedTradeProfIdx] .. " >")
        btnPickProf:SetScript("OnClick", function(self)
            selectedTradeProfIdx = (selectedTradeProfIdx % #TRADE_REQUEST_PROFS) + 1
            self:SetText("< " .. TRADE_REQUEST_PROFS[selectedTradeProfIdx] .. " >")
        end)

        local btnAskTrade = CreateFrame("Button", nil, devFrame, "UIPanelButtonTemplate")
        btnAskTrade:SetSize(138, 22)
        btnAskTrade:SetPoint("LEFT", btnPickProf, "RIGHT", 6, 0)
        btnAskTrade:SetText("Im Handel anfragen")
        btnAskTrade:SetScript("OnClick", function()
            local profLabel = TRADE_REQUEST_PROFS[selectedTradeProfIdx]
            local tradeChanID = nil
            if GetChannelList then
                local list = { GetChannelList() }
                -- In 3.3.5/Classic: id, name, ...; in Retail: id, name, disabled, ...
                local i = 1
                while i <= #list do
                    local id = list[i]
                    local name = list[i + 1]
                    if type(id) == "number" and type(name) == "string" then
                        local low = name:lower()
                        if low:find("handel") or low:find("trade") then
                            tradeChanID = id
                            break
                        end
                    end
                    i = i + 1
                end
            end
            tradeChanID = tradeChanID or 2
            local askMsg = string.format("Hallo! Hätte jemand kurz seinen [%s]-Link für unser Gilden-Verzeichnis? Einmal posten oder flüstern wäre super!", profLabel)
            local ok = pcall(SendChatMessage, askMsg, "CHANNEL", nil, tradeChanID)
            if ok then
                local reqKey = ResolveProfKey(profLabel, nil)
                if reqKey then
                    requestedProfs[reqKey] = time()
                end
                Print(string.format("Handelsanfrage für |cffffd100%s|r in Channel %d gesendet!", profLabel, tradeChanID))
            else
                Print("Konnte Nachricht nicht automatisch senden (Handelschannel nicht beigetreten?).")
            end
        end)

        local linksScroll = CreateFrame("ScrollFrame", "YellowPagesDevLinksScroll", devFrame, "UIPanelScrollFrameTemplate")
        linksScroll:SetPoint("TOPLEFT", 682, -116)
        linksScroll:SetPoint("BOTTOMRIGHT", -34, 48)

        local linksChild = CreateFrame("Frame", nil, linksScroll)
        linksChild:SetSize(258, 10)
        linksScroll:SetScrollChild(linksChild)
        devFrame.linksScrollChild = linksChild

        local btnClearLinks = CreateFrame("Button", nil, devFrame, "UIPanelButtonTemplate")
        btnClearLinks:SetSize(130, 24)
        btnClearLinks:SetPoint("BOTTOMRIGHT", -18, 14)
        btnClearLinks:SetText("Links leeren")
        btnClearLinks:SetScript("OnClick", function()
            if YellowPagesDevDB then YellowPagesDevDB.capturedLinks = {} end
            YellowPagesDev:RefreshLinksUI()
            Print("Gesammelte Chat-Links geleert.")
        end)

        local btnToggleActive = CreateFrame("Button", nil, devFrame, "UIPanelButtonTemplate")
        btnToggleActive:SetSize(135, 24)
        btnToggleActive:SetPoint("RIGHT", btnClearLinks, "LEFT", -8, 0)
        local function UpdateActiveBtnText()
            local active = (YellowPagesDevDB == nil or YellowPagesDevDB.enabled ~= false)
            btnToggleActive:SetText(active and "|cff00ff00Status: AKTIV|r" or "|cffff5555Status: INAKTIV|r")
        end
        btnToggleActive:SetScript("OnClick", function()
            YellowPagesDevDB = YellowPagesDevDB or { recipes = {}, capturedLinks = {} }
            YellowPagesDevDB.enabled = (YellowPagesDevDB.enabled == false)
            UpdateActiveBtnText()
            Print(YellowPagesDevDB.enabled and "DEV-Exporter |cff00ff00AKTIVIERT|r." or "DEV-Exporter |cffff5555INAKTIV|r (Auto-Scan & Chat-Sammler pausiert).")
        end)
        devFrame.UpdateActiveBtnText = UpdateActiveBtnText
        UpdateActiveBtnText()

        devFrame:Hide()
    end

    if devFrame:IsShown() then
        devFrame:Hide()
    else
        if devFrame.UpdateActiveBtnText then devFrame.UpdateActiveBtnText() end
        self:RefreshUI()
        devFrame:Show()
    end
end

-- Auto-Scan beim Öffnen eines Berufsfensters + passiver Chat-Link-Sammler
local evFrame = CreateFrame("Frame")
for _, ev in ipairs({
    "ADDON_LOADED",
    "TRADE_SKILL_SHOW",
    "TRADE_SKILL_LIST_UPDATE",
    "TRADE_SKILL_DATA_SOURCE_CHANGED",
    "CRAFT_SHOW",
    "CRAFT_UPDATE",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_WHISPER",
}) do
    pcall(evFrame.RegisterEvent, evFrame, ev)
end

local pending = false
evFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 == "YellowPages_DevExporter" then
            YellowPagesDevDB = YellowPagesDevDB or { recipes = {}, capturedLinks = {}, enabled = true }
            YellowPagesDevDB.recipes = YellowPagesDevDB.recipes or {}
            YellowPagesDevDB.capturedLinks = YellowPagesDevDB.capturedLinks or {}
            if YellowPagesDevDB.enabled == nil then YellowPagesDevDB.enabled = true end
            if YellowPagesDevDB.enabled then
                Print("Geladen (AKTIV)! Öffne Berufe oder sammle Chat-Links mit |cffffd100/ypdev|r.")
            else
                Print("Geladen (|cffff5555INAKTIV|r). Aktivieren mit |cffffd100/ypdev on|r.")
            end
        end
        return
    end
    if YellowPagesDevDB and YellowPagesDevDB.enabled == false then return end
    if event:sub(1, 9) == "CHAT_MSG_" then
        YellowPagesDev:CaptureChatLinks(arg1, arg2)
        return
    end
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        YellowPagesDev:ScanOpenProfession(true)
    end)
end)

SLASH_YELLOWPAGESDEV1 = "/ypdev"
SlashCmdList["YELLOWPAGESDEV"] = function(msg)
    local cmd = (msg or ""):lower():trim()
    if cmd == "scan" then
        YellowPagesDev:ScanOpenProfession(true)
    elseif cmd == "on" or cmd == "aktiv" then
        YellowPagesDevDB = YellowPagesDevDB or { recipes = {}, capturedLinks = {} }
        YellowPagesDevDB.enabled = true
        if devFrame and devFrame.UpdateActiveBtnText then devFrame.UpdateActiveBtnText() end
        Print("DEV-Exporter |cff00ff00AKTIVIERT|r.")
    elseif cmd == "off" or cmd == "inaktiv" then
        YellowPagesDevDB = YellowPagesDevDB or { recipes = {}, capturedLinks = {} }
        YellowPagesDevDB.enabled = false
        if devFrame and devFrame.UpdateActiveBtnText then devFrame.UpdateActiveBtnText() end
        Print("DEV-Exporter |cffff5555INAKTIV|r (Auto-Scan & Chat-Sammler pausiert).")
    elseif cmd == "reset" then
        YellowPagesDevDB = { recipes = {}, capturedLinks = {}, enabled = (YellowPagesDevDB and YellowPagesDevDB.enabled ~= false) }
        if YellowPagesDev.RefreshUI then YellowPagesDev:RefreshUI() end
        Print("DEV-Datenbank geleert.")
    else
        YellowPagesDev:ToggleUI()
    end
end
