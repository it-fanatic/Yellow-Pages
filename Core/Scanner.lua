--[[
    Yellow-Pages: Scanner.lua
    Scannt Berufe und Rezepte bei geöffnetem Handwerksfenster
    Kompatibel mit WoW Forever (C_TradeSkillUI.GetRecipeSchematic) & Classic (GetTradeSkill*)
--]]

YellowPages = YellowPages or {}
local L = YellowPages.L

local scanFrame = CreateFrame("Frame", "YellowPagesScannerFrame")
for _, ev in ipairs({
    "TRADE_SKILL_SHOW",
    "TRADE_SKILL_UPDATE",
    "TRADE_SKILL_LIST_UPDATE",
    "TRADE_SKILL_DATA_SOURCE_CHANGED",
    "TRADE_SKILL_DETAILS_UPDATE",
    "NEW_RECIPE_LEARNED",
    "CRAFT_SHOW",
    "CRAFT_UPDATE",
    "SKILL_LINES_CHANGED",
    "PLAYER_ENTERING_WORLD",
}) do
    pcall(scanFrame.RegisterEvent, scanFrame, ev)
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
    return nil
end

-- Prüft, ob das geöffnete Berufsfenster ein fremder Link (aus dem Chat/Gilde) ist
local function IsForeignTradeSkill()
    local T = C_TradeSkillUI
    if T then
        if SafeCall(T.IsTradeSkillLinked) or SafeCall(T.IsTradeSkillGuild)
            or SafeCall(T.IsTradeSkillGuildMember) or SafeCall(T.IsNPCCrafting) then
            return true
        end
    end
    if SafeCall(IsTradeSkillLinked) or SafeCall(IsTradeSkillGuild) then
        return true
    end
    return false
end

local isScanning = false
local lastScanTime = 0
local lastAnnouncedProf = nil
local lastAnnouncedCount = 0

-- Scannt über die moderne C_TradeSkillUI API (WoW Forever / Retail)
local function ScanModernTradeSkill()
    local T = C_TradeSkillUI
    if not T or not T.GetAllRecipeIDs then return false end
    if IsForeignTradeSkill() then return false end

    local ok, recipeIDs = pcall(T.GetAllRecipeIDs)
    if not ok or type(recipeIDs) ~= "table" or #recipeIDs == 0 then return false end

    local profName, skillRank, skillMaxRank, profID
    if T.GetBaseProfessionInfo then
        local info = SafeCall(T.GetBaseProfessionInfo)
        if type(info) == "table" then
            profID = info.professionID or info.parentProfessionID
            profName = YellowPages:NormalizeProfessionName(info.professionName, profID)
            skillRank = info.skillLevel or 0
            skillMaxRank = info.maxSkillLevel or 0
            if (not skillRank or skillRank == 0) and T.GetProfessionInfoBySkillLineID and profID then
                local i2 = SafeCall(T.GetProfessionInfoBySkillLineID, profID)
                if type(i2) == "table" then
                    skillRank = i2.skillLevel or skillRank
                    skillMaxRank = i2.maxSkillLevel or skillMaxRank
                end
            end
        end
    end

    if not profName and T.GetTradeSkillLineInfo then
        local lineInfo = SafeCall(T.GetTradeSkillLineInfo)
        if type(lineInfo) == "table" then
            profID = lineInfo.professionID or lineInfo.parentProfessionID
            profName = YellowPages:NormalizeProfessionName(lineInfo.tradeSkillDisplayName or lineInfo.professionName, profID)
            skillRank = lineInfo.skillLevel or skillRank or 0
            skillMaxRank = lineInfo.maxSkillLevel or skillMaxRank or 0
        end
    end

    if not profName and T.GetTradeSkillLine then
        local a, b, c, d = SafeCall(T.GetTradeSkillLine)
        if type(a) == "number" then
            profName = YellowPages:NormalizeProfessionName(b, a)
            skillRank, skillMaxRank = skillRank or c or 0, skillMaxRank or d or 0
        elseif type(a) == "string" then
            profName = YellowPages:NormalizeProfessionName(a)
            skillRank, skillMaxRank = skillRank or b or 0, skillMaxRank or c or 0
        end
    end

    if not profName or profName == "" then return false end

    local playerName = YellowPages:GetPlayerFullName("player")
    local _, playerClass = UnitClass("player")
    local savedRecipes = {}

    for _, recipeID in ipairs(recipeIDs) do
        local rInfo = T.GetRecipeInfo and SafeCall(T.GetRecipeInfo, recipeID)
        if type(rInfo) == "table" and rInfo.learned == true then
            local reagents = {}
            local outputItemID = 0
            local minMade, maxMade = rInfo.minMade or 1, rInfo.maxMade or 1
            local icon = rInfo.icon

            -- 1. Moderne GetRecipeSchematic API (WoW Forever / 10.0+)
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
                                    local rName = YellowPages:GetItemNameSafe(rItemID)
                                    local rIcon = YellowPages:GetItemIconSafe(rItemID)
                                    table.insert(reagents, {
                                        itemID = rItemID,
                                        name = rName,
                                        count = rCount,
                                        icon = rIcon
                                    })
                                end
                            end
                        end
                    end
                end
            end

            -- 2. Fallback: GetRecipeNumReagents / GetRecipeReagentInfo
            if #reagents == 0 and T.GetRecipeNumReagents and T.GetRecipeReagentInfo then
                local numReagents = SafeCall(T.GetRecipeNumReagents, recipeID) or 0
                for rIndex = 1, numReagents do
                    local rName, rIcon, rCount = SafeCall(T.GetRecipeReagentInfo, recipeID, rIndex)
                    if type(rName) == "table" then
                        local tbl = rName
                        rName = tbl.reagentName
                        rIcon = tbl.reagentIcon
                        rCount = tbl.reagentCount
                    end
                    local rLink = T.GetRecipeReagentItemLink and SafeCall(T.GetRecipeReagentItemLink, recipeID, rIndex)
                    local rItemID = rLink and tonumber(rLink:match("item:(%d+)")) or 0
                    if rName then
                        table.insert(reagents, {
                            itemID = rItemID,
                            name = rName,
                            count = rCount or 1,
                            icon = rIcon or YellowPages:GetItemIconSafe(rItemID)
                        })
                    end
                end
            end

            local outputItemLink = T.GetRecipeItemLink and SafeCall(T.GetRecipeItemLink, recipeID)
            if (not outputItemID or outputItemID == 0) and outputItemLink then
                outputItemID = tonumber(outputItemLink:match("item:(%d+)")) or 0
            end
            if (not outputItemLink or outputItemLink == "") and outputItemID and outputItemID > 0 then
                local _, link = YellowPages:GetItemInfoSafe(outputItemID)
                outputItemLink = link
            end

            local recipeData = {
                id = recipeID,
                name = rInfo.name or ("Rezept #" .. tostring(recipeID)),
                prof = profName,
                icon = icon or YellowPages:GetItemIconSafe(outputItemID),
                itemLink = outputItemLink,
                itemID = outputItemID,
                minMade = minMade,
                maxMade = maxMade,
                reagents = reagents
            }

            YellowPages:RegisterRecipe(recipeData)
            table.insert(savedRecipes, recipeID)
        end
    end

    if #savedRecipes == 0 then return false end

    YellowPages:RegisterMemberProfession(playerName, playerClass, profName, skillRank, skillMaxRank, savedRecipes)
    return true, profName, #savedRecipes
end

-- Scannt über die klassische GetTradeSkill* API
local function ScanClassicTradeSkill()
    if not GetTradeSkillLine or not GetNumTradeSkills then return false end
    if IsForeignTradeSkill() then return false end

    local rawProfName, skillRank, skillMaxRank = GetTradeSkillLine()
    if not rawProfName or rawProfName == "" or rawProfName == "UNKNOWN" then return false end
    local profName = YellowPages:NormalizeProfessionName(rawProfName)

    local numSkills = GetNumTradeSkills()
    if not numSkills or numSkills <= 0 then return false end

    local playerName = YellowPages:GetPlayerFullName("player")
    local _, playerClass = UnitClass("player")
    local savedRecipes = {}

    for i = 1, numSkills do
        local name, skillType, _, _, _, numMade = GetTradeSkillInfo(i)
        if skillType and skillType ~= "header" and skillType ~= "subheader" and name and name ~= "" then
            local itemLink = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
            local recipeLink = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)

            local recipeID = 0
            if recipeLink then
                recipeID = tonumber(recipeLink:match("enchant:(%d+)") or recipeLink:match("spell:(%d+)")) or 0
            end
            if (not recipeID or recipeID == 0) and itemLink then
                recipeID = tonumber(itemLink:match("item:(%d+)")) or 0
            end
            if not recipeID or recipeID == 0 then
                local hashStr = profName .. "_" .. name
                local hash = 5381
                for ch = 1, #hashStr do
                    hash = ((hash * 33) + string.byte(hashStr, ch)) % 2147483647
                end
                recipeID = hash
            end

            local reagents = {}
            local numReagents = GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0

            for r = 1, numReagents do
                local rName, rTexture, rCount = GetTradeSkillReagentInfo(i, r)
                local rLink = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, r)
                local rItemID = rLink and tonumber(rLink:match("item:(%d+)")) or 0

                table.insert(reagents, {
                    itemID = rItemID,
                    name = rName or YellowPages:GetItemNameSafe(rItemID) or "Reagenz",
                    count = rCount or 1,
                    icon = rTexture or YellowPages:GetItemIconSafe(rItemID)
                })
            end

            local outputItemID = itemLink and tonumber(itemLink:match("item:(%d+)")) or 0
            local icon = GetTradeSkillIcon and GetTradeSkillIcon(i) or YellowPages:GetItemIconSafe(outputItemID)

            local recipeData = {
                id = recipeID,
                name = name,
                prof = profName,
                icon = icon,
                itemLink = itemLink,
                itemID = outputItemID,
                minMade = numMade or 1,
                maxMade = numMade or 1,
                reagents = reagents
            }

            YellowPages:RegisterRecipe(recipeData)
            table.insert(savedRecipes, recipeID)
        end
    end

    if #savedRecipes == 0 then return false end

    YellowPages:RegisterMemberProfession(playerName, playerClass, profName, skillRank, skillMaxRank, savedRecipes)
    return true, profName, #savedRecipes
end

-- Scannt Verzauberkunst (über klassisches GetCraft*)
local function ScanClassicCraft()
    if not GetCraftSkillLine or not GetNumCrafts then return false end

    local rawProfName, skillRank, skillMaxRank = GetCraftSkillLine(0)
    if not rawProfName or rawProfName == "" then return false end
    local profName = YellowPages:NormalizeProfessionName(rawProfName)

    local numCrafts = GetNumCrafts()
    if not numCrafts or numCrafts <= 0 then return false end

    local playerName = YellowPages:GetPlayerFullName("player")
    local _, playerClass = UnitClass("player")
    local savedRecipes = {}

    for i = 1, numCrafts do
        local craftName, _, craftType = GetCraftInfo(i)
        if craftType and craftType ~= "header" and craftName and craftName ~= "" then
            local craftItemLink = GetCraftItemLink and GetCraftItemLink(i)
            local recipeID = 0
            if craftItemLink then
                recipeID = tonumber(craftItemLink:match("enchant:(%d+)") or craftItemLink:match("spell:(%d+)")) or 0
            end
            if not recipeID or recipeID == 0 then
                local hashStr = profName .. "_" .. craftName
                local hash = 5381
                for ch = 1, #hashStr do
                    hash = ((hash * 33) + string.byte(hashStr, ch)) % 2147483647
                end
                recipeID = hash
            end

            local reagents = {}
            local numReagents = GetCraftNumReagents and GetCraftNumReagents(i) or 0
            for r = 1, numReagents do
                local rName, rTexture, rCount = GetCraftReagentInfo(i, r)
                local rLink = GetCraftReagentItemLink and GetCraftReagentItemLink(i, r)
                local rItemID = rLink and tonumber(rLink:match("item:(%d+)")) or 0

                table.insert(reagents, {
                    itemID = rItemID,
                    name = rName or YellowPages:GetItemNameSafe(rItemID) or "Reagenz",
                    count = rCount or 1,
                    icon = rTexture or YellowPages:GetItemIconSafe(rItemID)
                })
            end

            local icon = GetCraftIcon and GetCraftIcon(i) or "Interface\\Icons\\Spell_Holy_GreaterHeal"

            local recipeData = {
                id = recipeID,
                name = craftName,
                prof = profName,
                icon = icon,
                itemLink = craftItemLink,
                itemID = 0,
                minMade = 1,
                maxMade = 1,
                reagents = reagents
            }

            YellowPages:RegisterRecipe(recipeData)
            table.insert(savedRecipes, recipeID)
        end
    end

    if #savedRecipes == 0 then return false end

    YellowPages:RegisterMemberProfession(playerName, playerClass, profName, skillRank, skillMaxRank, savedRecipes)
    return true, profName, #savedRecipes
end

-- Scannt alle gelernten Berufe des Spielers (insbesondere Sammelberufe wie Kräuterkunde, Bergbau, Kürschnerei)
function YellowPages:ScanPlayerSkillLines(isManual)
    local playerName = self:GetPlayerFullName("player")
    local playerClass = UnitClass and select(2, UnitClass("player")) or "WARRIOR"
    local foundGathering = 0

    local function ProcessSkillLine(rawName, rank, maxRank, skillLineID)
        if not self:IsKnownProfession(rawName, skillLineID) then return end
        local normProf = self:NormalizeProfessionName(rawName, skillLineID)
        if not normProf or not rank or rank <= 0 then return end

        if self:GetGatheringCatalogKey(normProf) then
            local ok, pName, recCount = self:RegisterGatheringProfession(playerName, playerClass, normProf, rank, maxRank)
            if ok and recCount and recCount > 0 then
                foundGathering = foundGathering + 1
                if isManual then
                    self:Print(string.format(L["MSG_SCAN_SUCCESS"], pName, recCount))
                end
            end
        else
            -- Gelernten Herstellungs-/Nebenberuf samt aktueller Skill-Stufe registrieren (bestehende Rezepte bleiben erhalten)
            self:RegisterMemberProfession(playerName, playerClass, normProf, rank, maxRank, nil)
        end
    end

    -- 1. Moderne GetProfessions / GetProfessionInfo API
    if GetProfessions and GetProfessionInfo then
        local slots = { GetProfessions() }
        for slot = 1, 7 do
            local idx = slots[slot]
            if idx then
                local ok, name, _, rank, maxRank, _, _, skillLine = pcall(GetProfessionInfo, idx)
                if ok and name and type(rank) == "number" and rank > 0 then
                    ProcessSkillLine(name, rank, maxRank, skillLine)
                end
            end
        end
    end

    -- 2. Klassische GetNumSkillLines / GetSkillLineInfo API (Fallback)
    if GetNumSkillLines and GetSkillLineInfo then
        local numLines = GetNumSkillLines() or 0
        for i = 1, numLines do
            local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
            if not isHeader and name and type(rank) == "number" and rank > 0 then
                ProcessSkillLine(name, rank, maxRank, nil)
            end
        end
    end

    if self.RepairAndConsolidateSelfData then
        self:RepairAndConsolidateSelfData()
    end

    return foundGathering > 0
end

-- Zentrale Scan-Funktion
function YellowPages:ScanCurrentTradeSkill(isManual)
    local now = GetTime and GetTime() or time()
    if isScanning or (now - lastScanTime < 1.5 and not isManual) then
        return
    end

    isScanning = true
    lastScanTime = now

    -- Immer auch Sammelberufe (Kräuterkunde, Bergbau, Kürschnerei) über die Skill-Lines erfassen
    local gatheredScanned = self:ScanPlayerSkillLines(isManual)

    local success, profName, count = ScanModernTradeSkill()

    if not success then
        success, profName, count = ScanClassicTradeSkill()
    end

    if not success then
        success, profName, count = ScanClassicCraft()
    end

    -- Falls gerade Bergbau (Verhüttung) offen war, Sammel-Erze wieder ergänzen
    if success and profName and self:GetGatheringCatalogKey(profName) then
        self:ScanPlayerSkillLines(false)
    end

    isScanning = false

    if success and profName and count > 0 then
        if isManual or lastAnnouncedProf ~= profName or lastAnnouncedCount ~= count then
            lastAnnouncedProf = profName
            lastAnnouncedCount = count
            self:Print(string.format(L["MSG_SCAN_SUCCESS"], profName, count))

            if self:IsInGuild() and self.BroadcastProfessionData then
                self:BroadcastProfessionData(profName)
            end
        end

        if self.RefreshUI then
            self:RefreshUI()
        end
    elseif gatheredScanned then
        if self:IsInGuild() and self.BroadcastHello then
            self:BroadcastHello()
        end
        if self.RefreshUI then
            self:RefreshUI()
        end
    elseif isManual then
        self:Print(L["MSG_SCAN_NO_WINDOW"])
    end
end

local scanPending = false
scanFrame:SetScript("OnEvent", function(_, event)
    if event == "SKILL_LINES_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.5, function()
            YellowPages:ScanPlayerSkillLines(false)
            if YellowPages.RefreshUI then YellowPages:RefreshUI() end
        end)
        return
    end
    if scanPending then return end
    scanPending = true
    C_Timer.After(0.6, function()
        scanPending = false
        YellowPages:ScanCurrentTradeSkill(false)
    end)
end)
