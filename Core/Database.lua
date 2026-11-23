--[[
    Yellow-Pages: Database.lua
    Verwaltung von Gildenmitgliedern, Berufen und Rezepten (inkl. Stufe, Qualität, Mehrsprachigkeit & Forever-Nachnamen)
--]]

YellowPages = YellowPages or {}
local L = YellowPages.L

local PROF_KEY_BY_SKILLLINE = {
    [171] = "PROF_ALCHEMY",
    [164] = "PROF_BLACKSMITHING",
    [333] = "PROF_ENCHANTING",
    [202] = "PROF_ENGINEERING",
    [773] = "PROF_INSCRIPTION",
    [755] = "PROF_JEWELCRAFTING",
    [165] = "PROF_LEATHERWORKING",
    [197] = "PROF_TAILORING",
    [182] = "PROF_HERBALISM",
    [186] = "PROF_MINING",
    [393] = "PROF_SKINNING",
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
    ["herbalism"]        = "PROF_HERBALISM",
    ["kräuterkunde"]     = "PROF_HERBALISM",
    ["mining"]           = "PROF_MINING",
    ["bergbau"]          = "PROF_MINING",
    ["skinning"]         = "PROF_SKINNING",
    ["kürschnerei"]      = "PROF_SKINNING",
    ["cooking"]          = "PROF_COOKING",
    ["kochen"]           = "PROF_COOKING",
    ["kochkunst"]        = "PROF_COOKING",
    ["first aid"]        = "PROF_FIRSTAID",
    ["erste hilfe"]      = "PROF_FIRSTAID",
}

function YellowPages:IsKnownProfession(rawName, skillLineID)
    if skillLineID and PROF_KEY_BY_SKILLLINE[skillLineID] then
        return true
    end
    if rawName and rawName ~= "" then
        if PROF_KEY_BY_NAME[rawName:lower()] then
            return true
        end
        for _, pKey in pairs(PROF_KEY_BY_SKILLLINE) do
            if L[pKey] and L[pKey]:lower() == rawName:lower() then
                return true
            end
        end
    end
    return false
end

function YellowPages:NormalizeProfessionName(rawName, skillLineID)
    if skillLineID and PROF_KEY_BY_SKILLLINE[skillLineID] then
        return L[PROF_KEY_BY_SKILLLINE[skillLineID]]
    end
    if rawName and rawName ~= "" then
        local key = PROF_KEY_BY_NAME[rawName:lower()]
        if key then
            return L[key]
        end
        return rawName
    end
    return nil
end

YellowPages.PROFESSION_ORDER = {
    L["PROF_ALCHEMY"],
    L["PROF_BLACKSMITHING"],
    L["PROF_ENCHANTING"],
    L["PROF_ENGINEERING"],
    L["PROF_INSCRIPTION"],
    L["PROF_JEWELCRAFTING"],
    L["PROF_LEATHERWORKING"],
    L["PROF_TAILORING"],
    L["PROF_HERBALISM"],
    L["PROF_MINING"],
    L["PROF_SKINNING"],
    L["PROF_COOKING"],
    L["PROF_FIRSTAID"],
}

-- Prüft, ob ein Name dem eigenen eingeloggten Charakter entspricht (berücksichtigt Vorname + Nachname in Forever)
function YellowPages:IsSelf(memberName)
    if not memberName then return false end
    local cleanMember = (self:StripRealm(memberName) or memberName):lower()
    local myFull = (self:GetPlayerFullName("player") or ""):lower()
    if cleanMember == myFull then return true end
    local firstOnly = (UnitName("player") or ""):lower()
    if firstOnly ~= "" then
        -- Exakter Treffer auf den eigenen Vornamen (ohne Nachnamen) ist immer der eigene Charakter
        if cleanMember == firstOnly then
            return true
        end
        -- Vorname + Nachname, falls unser eigener Nachname noch nicht geladen war
        if cleanMember:sub(1, #firstOnly + 1) == firstOnly .. " " and not myFull:find(" ") then
            return true
        end
    end
    return false
end

-- Liefert die eigenen Mitglieder-Daten aus der Datenbank (sucht robust über fullName, UnitName und IsSelf)
function YellowPages:GetMyMemberData()
    if not YellowPagesDB or not YellowPagesDB.members then return nil, nil end
    local myFullName = self:GetPlayerFullName("player")
    if myFullName and YellowPagesDB.members[myFullName] then
        return YellowPagesDB.members[myFullName], myFullName
    end
    local firstOnly = UnitName and UnitName("player")
    if firstOnly and YellowPagesDB.members[firstOnly] then
        return YellowPagesDB.members[firstOnly], firstOnly
    end
    for memberName, memberData in pairs(YellowPagesDB.members) do
        if self:IsSelf(memberName) then
            return memberData, memberName
        end
    end
    return nil, myFullName
end

-- Ermittelt und ergänzt dynamisch Qualitätsstufe (Rarity), lokalisierten Namen und Stufe (Level)
function YellowPages:ResolveRecipeMetadata(recipeData)
    if not recipeData then return 1, 0 end

    if recipeData.prof then
        recipeData.prof = self:NormalizeProfessionName(recipeData.prof) or recipeData.prof
    end

    local itemKey = (recipeData.itemID and recipeData.itemID > 0 and recipeData.itemID) or recipeData.itemLink
    if itemKey then
        local itemName, link, quality, itemLevel, reqLevel = self:GetItemInfoSafe(itemKey)
        if itemName and itemName ~= "" and recipeData.itemID and recipeData.itemID > 0 then
            recipeData.name = itemName
        end
        if quality ~= nil then
            recipeData.quality = quality
        end
        if link and (not recipeData.itemLink or recipeData.itemLink == "") then
            recipeData.itemLink = link
        end
        if itemLevel and itemLevel > 0 then
            recipeData.itemLevel = itemLevel
        end
        if reqLevel and reqLevel > 0 then
            recipeData.reqLevel = reqLevel
        end
        local bestLevel = (recipeData.gatherSkill and recipeData.gatherSkill > 0 and recipeData.gatherSkill)
            or (reqLevel and reqLevel > 0 and reqLevel)
            or (itemLevel and itemLevel > 0 and itemLevel)
        if bestLevel and bestLevel > 0 then
            recipeData.level = bestLevel
        end
    end

    if recipeData.gatherSkill and recipeData.gatherSkill > 0 then
        recipeData.level = recipeData.gatherSkill
    end

    if recipeData.quality == nil and recipeData.itemLink then
        local colorHex = recipeData.itemLink:match("|cff(%x%x%x%x%x%x)")
        if colorHex then
            colorHex = colorHex:lower()
            if colorHex == "9d9d9d" then recipeData.quality = 0
            elseif colorHex == "ffffff" then recipeData.quality = 1
            elseif colorHex == "1eff00" then recipeData.quality = 2
            elseif colorHex == "0070dd" then recipeData.quality = 3
            elseif colorHex == "a335ee" then recipeData.quality = 4
            elseif colorHex == "ff8000" then recipeData.quality = 5
            end
        end
    end

    local finalQuality = recipeData.quality
    if finalQuality == nil then finalQuality = 1 end
    local finalLevel = recipeData.level or recipeData.reqLevel or recipeData.itemLevel or 0

    return finalQuality, finalLevel
end

-- Registriert oder aktualisiert ein Gildenmitglied und dessen Beruf (führt bestehende Rezepte zusammen)
function YellowPages:RegisterMemberProfession(memberName, classEn, profName, rank, maxRank, recipeList)
    if not memberName or not profName then return end
    YellowPagesDB = YellowPagesDB or {}
    YellowPagesDB.members = YellowPagesDB.members or {}

    local cleanName = self:StripRealm(memberName) or memberName
    if self:IsSelf(cleanName) then
        cleanName = self:GetPlayerFullName("player")
    end
    local normProf = self:NormalizeProfessionName(profName) or profName

    if not YellowPagesDB.members[cleanName] then
        YellowPagesDB.members[cleanName] = {
            class = classEn or "WARRIOR",
            rank = "Member",
            online = true,
            lastSeen = time(),
            professions = {}
        }
    end

    local member = YellowPagesDB.members[cleanName]
    if classEn then member.class = classEn end
    member.online = true
    member.lastSeen = time()
    member.professions = member.professions or {}

    local existingProf = member.professions[normProf]
    local mergedRecipes = {}
    local seen = {}

    if existingProf and existingProf.recipes then
        for _, rID in ipairs(existingProf.recipes) do
            if rID and not seen[rID] then
                seen[rID] = true
                table.insert(mergedRecipes, rID)
            end
        end
    end

    if type(recipeList) == "table" then
        for _, rID in ipairs(recipeList) do
            if rID and not seen[rID] then
                seen[rID] = true
                table.insert(mergedRecipes, rID)
            end
        end
    end

    local oldRank = existingProf and existingProf.rank or 0
    local oldMax = existingProf and existingProf.maxRank or 0

    member.professions[normProf] = {
        rank = (rank and rank > 0) and rank or oldRank,
        maxRank = (maxRank and maxRank > 0) and maxRank or oldMax,
        lastUpdated = time(),
        recipes = mergedRecipes
    }
end

-- Konsolidiert alle eigenen Einträge (Vorname vs. Vorname + Nachname) und stellt verwaiste Rezepte eigener Berufe wieder her
function YellowPages:RepairAndConsolidateSelfData()
    if not YellowPagesDB then return end
    YellowPagesDB.members = YellowPagesDB.members or {}
    YellowPagesDB.recipes = YellowPagesDB.recipes or {}

    local myFullName = self:GetPlayerFullName("player")
    if not myFullName or myFullName == "" then return end
    local myClass = UnitClass and select(2, UnitClass("player")) or "WARRIOR"

    if not YellowPagesDB.members[myFullName] then
        YellowPagesDB.members[myFullName] = {
            class = myClass,
            rank = "Member",
            online = true,
            lastSeen = time(),
            professions = {}
        }
    end

    local targetMember = YellowPagesDB.members[myFullName]
    targetMember.online = true
    if myClass then targetMember.class = myClass end
    targetMember.professions = targetMember.professions or {}

    -- 1. Alle Self-Einträge (z.B. alter Eintrag ohne Nachnamen) vollständig inkl. Rezeptlisten zusammenführen
    local toRemove = {}
    for memberName, memberData in pairs(YellowPagesDB.members) do
        if memberName ~= myFullName and self:IsSelf(memberName) then
            if memberData and memberData.professions then
                for rawProf, pData in pairs(memberData.professions) do
                    local normProf = self:NormalizeProfessionName(rawProf) or rawProf
                    self:RegisterMemberProfession(myFullName, myClass, normProf, pData.rank, pData.maxRank, pData.recipes)
                end
            end
            table.insert(toRemove, memberName)
        end
    end
    for _, oldKey in ipairs(toRemove) do
        YellowPagesDB.members[oldKey] = nil
    end

    -- 2. Auch innerhalb des eigenen Eintrags Berufs-Schlüssel normalisieren
    local normToMerge = {}
    for rawProf, pData in pairs(targetMember.professions) do
        local normProf = self:NormalizeProfessionName(rawProf) or rawProf
        if normProf ~= rawProf then
            table.insert(normToMerge, { oldKey = rawProf, normKey = normProf, data = pData })
        end
    end
    for _, item in ipairs(normToMerge) do
        targetMember.professions[item.oldKey] = nil
        self:RegisterMemberProfession(myFullName, myClass, item.normKey, item.data.rank, item.data.maxRank, item.data.recipes)
    end
end

-- Registriert ein Rezept in der globalen Rezept-Datenbank
function YellowPages:RegisterRecipe(recipeData)
    if not recipeData or not recipeData.id then return end
    YellowPagesDB = YellowPagesDB or {}
    YellowPagesDB.recipes = YellowPagesDB.recipes or {}

    local normProf = self:NormalizeProfessionName(recipeData.prof) or recipeData.prof or L["GENERAL"]

    local entry = {
        id = recipeData.id,
        name = recipeData.name or L["UNKNOWN"],
        prof = normProf,
        icon = recipeData.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        itemLink = recipeData.itemLink,
        itemID = recipeData.itemID or 0,
        quality = recipeData.quality,
        level = recipeData.level,
        gatherSkill = recipeData.gatherSkill,
        itemLevel = recipeData.itemLevel,
        reqLevel = recipeData.reqLevel,
        minMade = recipeData.minMade or 1,
        maxMade = recipeData.maxMade or 1,
        reagents = recipeData.reagents or {}
    }

    self:ResolveRecipeMetadata(entry)
    YellowPagesDB.recipes[recipeData.id] = entry
end

-- ============================================================================
-- SAMMELBERUFE-KATALOG (Kräuterkunde, Bergbau, Kürschnerei)
-- ============================================================================
local GATHERING_CATALOG = {
    ["PROF_HERBALISM"] = {
        { itemID = 2447,  skill = 1,   name = "Peacebloom / Friedensblume" },
        { itemID = 765,   skill = 1,   name = "Silverleaf / Silberblatt" },
        { itemID = 2449,  skill = 15,  name = "Earthroot / Erdwurzel" },
        { itemID = 785,   skill = 50,  name = "Mageroyal / Maguskönigskraut" },
        { itemID = 2450,  skill = 70,  name = "Briarthorn / Wilddornrose" },
        { itemID = 2452,  skill = 70,  name = "Swiftthistle / Flitzdistel" },
        { itemID = 3820,  skill = 85,  name = "Stranglekelp / Würgetang" },
        { itemID = 2453,  skill = 100, name = "Bruiseweed / Beulengras" },
        { itemID = 3355,  skill = 115, name = "Wild Steelbloom / Wildstahlblume" },
        { itemID = 3369,  skill = 120, name = "Grave Moss / Grabmoos" },
        { itemID = 3356,  skill = 125, name = "Kingsblood / Königsblut" },
        { itemID = 3357,  skill = 150, name = "Liferoot / Lebenswurz" },
        { itemID = 3818,  skill = 160, name = "Fadeleaf / Blassblatt" },
        { itemID = 3821,  skill = 170, name = "Goldthorn / Golddorn" },
        { itemID = 3358,  skill = 185, name = "Khadgar's Whisker / Khadgars Schnurrbart" },
        { itemID = 3819,  skill = 195, name = "Wintersbite / Winterbiss" },
        { itemID = 4625,  skill = 205, name = "Firebloom / Feuerblüte" },
        { itemID = 8831,  skill = 210, name = "Purple Lotus / Lila Lotus" },
        { itemID = 8836,  skill = 220, name = "Arthas' Tears / Arthas' Tränen" },
        { itemID = 8838,  skill = 230, name = "Sungrass / Sonnengras" },
        { itemID = 8839,  skill = 235, name = "Blindweed / Blindkraut" },
        { itemID = 8845,  skill = 245, name = "Ghost Mushroom / Geisterpilz" },
        { itemID = 8846,  skill = 250, name = "Gromsblood / Gromsblut" },
        { itemID = 13464, skill = 260, name = "Golden Sansam / Goldener Sansam" },
        { itemID = 13463, skill = 270, name = "Dreamfoil / Traumblatt" },
        { itemID = 13465, skill = 280, name = "Mountain Silversage / Bergsilberweisling" },
        { itemID = 13466, skill = 285, name = "Plaguebloom / Pestblüte" },
        { itemID = 13467, skill = 290, name = "Icecap / Eiskappe" },
        { itemID = 13468, skill = 300, name = "Black Lotus / Schwarzer Lotus" },
    },
    ["PROF_MINING"] = {
        { itemID = 2770,  skill = 1,   name = "Copper Ore / Kupfererz" },
        { itemID = 2835,  skill = 1,   name = "Rough Stone / Rauer Stein" },
        { itemID = 2771,  skill = 65,  name = "Tin Ore / Zinnerz" },
        { itemID = 2836,  skill = 65,  name = "Coarse Stone / Grober Stein" },
        { itemID = 2775,  skill = 75,  name = "Silver Ore / Silbererz" },
        { itemID = 2772,  skill = 125, name = "Iron Ore / Eisenerz" },
        { itemID = 2838,  skill = 125, name = "Heavy Stone / Schwerer Stein" },
        { itemID = 2776,  skill = 155, name = "Gold Ore / Golderz" },
        { itemID = 3858,  skill = 175, name = "Mithril Ore / Mithrilerz" },
        { itemID = 7912,  skill = 175, name = "Solid Stone / Robuster Stein" },
        { itemID = 7911,  skill = 230, name = "Truesilver Ore / Echtsilbererz" },
        { itemID = 11370, skill = 230, name = "Dark Iron Ore / Dunkeleisenerz" },
        { itemID = 10620, skill = 250, name = "Thorium Ore / Thoriumerz" },
        { itemID = 12365, skill = 250, name = "Dense Stone / Verdichteter Stein" },
    },
    ["PROF_SKINNING"] = {
        { itemID = 2934,  skill = 1,   name = "Ruined Leather Scraps / Verdorbene Lederfetzen" },
        { itemID = 2318,  skill = 1,   name = "Light Leather / Leichtes Leder" },
        { itemID = 783,   skill = 20,  name = "Light Hide / Leichter Balg" },
        { itemID = 2319,  skill = 50,  name = "Medium Leather / Mittleres Leder" },
        { itemID = 4232,  skill = 75,  name = "Medium Hide / Mittlerer Balg" },
        { itemID = 4234,  skill = 125, name = "Heavy Leather / Schweres Leder" },
        { itemID = 4235,  skill = 150, name = "Heavy Hide / Schwerer Balg" },
        { itemID = 4304,  skill = 175, name = "Thick Leather / Dickes Leder" },
        { itemID = 8169,  skill = 200, name = "Thick Hide / Dicker Balg" },
        { itemID = 8170,  skill = 250, name = "Rugged Leather / Unverwüstliches Leder" },
        { itemID = 8171,  skill = 275, name = "Rugged Hide / Unverwüstlicher Balg" },
        { itemID = 15417, skill = 290, name = "Devilsaur Leather / Teufelssaurierleder" },
        { itemID = 17012, skill = 300, name = "Core Leather / Kernleder" },
    },
}

function YellowPages:GetGatheringCatalogKey(profName)
    if not profName then return nil end
    local norm = self:NormalizeProfessionName(profName) or profName
    if norm == L["PROF_HERBALISM"] then return "PROF_HERBALISM" end
    if norm == L["PROF_MINING"] then return "PROF_MINING" end
    if norm == L["PROF_SKINNING"] then return "PROF_SKINNING" end
    return nil
end

-- Registriert für einen Sammler (Kräuterkunde, Bergbau, Kürschnerei) automatisch alle sammelbaren Ressourcen bis zu seiner Fertigkeitsstufe
function YellowPages:RegisterGatheringProfession(memberName, classEn, profName, skillRank, maxRank)
    local catKey = self:GetGatheringCatalogKey(profName)
    if not catKey or not GATHERING_CATALOG[catKey] then return false end

    local normProf = L[catKey]
    skillRank = tonumber(skillRank) or 0
    maxRank = tonumber(maxRank) or 300

    local cleanName = self:StripRealm(memberName) or memberName
    YellowPagesDB = YellowPagesDB or {}
    YellowPagesDB.members = YellowPagesDB.members or {}

    -- Falls für Bergbau bereits Verhüttungs-Rezepte gespeichert sind, diese behalten!
    local existingRecipes = {}
    local knownSet = {}
    local existingMember = YellowPagesDB.members[cleanName]
    local existingProf = existingMember and existingMember.professions and existingMember.professions[normProf]
    if existingProf and existingProf.recipes then
        for _, rID in ipairs(existingProf.recipes) do
            if rID < 900000 then
                local catEntry = self.RecipeCatalog and self.RecipeCatalog[rID]
                local reqSkill = catEntry and catEntry.level or 0
                if skillRank <= 0 or reqSkill <= skillRank then
                    table.insert(existingRecipes, rID)
                    knownSet[rID] = true
                end
            end
        end
    end

    local effectiveRank = (skillRank > 0) and skillRank or 1

    for _, res in ipairs(GATHERING_CATALOG[catKey]) do
        if res.skill <= effectiveRank then
            local recID = 900000 + res.itemID
            local locName = self:GetItemNameSafe(res.itemID)
            if not locName or locName:find("^Item #") then
                locName = res.name
            end
            local icon = self:GetItemIconSafe(res.itemID)
            local _, itemLink = self:GetItemInfoSafe(res.itemID)

            self:RegisterRecipe({
                id = recID,
                name = locName,
                prof = normProf,
                icon = icon,
                itemLink = itemLink,
                itemID = res.itemID,
                level = res.skill,
                gatherSkill = res.skill,
                minMade = 1,
                maxMade = 1,
                reagents = {
                    {
                        itemID = res.itemID,
                        name = locName,
                        count = 1,
                        icon = icon,
                    }
                }
            })

            if not knownSet[recID] then
                knownSet[recID] = true
                table.insert(existingRecipes, recID)
            end
        end
    end

    self:RegisterMemberProfession(cleanName, classEn, normProf, skillRank, maxRank, existingRecipes)
    return true, normProf, #existingRecipes
end

-- Liefert alle Handwerker für ein bestimmtes Rezept
function YellowPages:GetCraftersForRecipe(recipeID)
    local crafters = {}
    if not YellowPagesDB or not YellowPagesDB.members then return crafters end

    local _, myClass = UnitClass("player")

    for memberName, memberData in pairs(YellowPagesDB.members) do
        local isMe = self:IsSelf(memberName)
        if isMe then
            memberData.online = true
            if myClass then memberData.class = myClass end
        end

        if memberData.professions then
            local addedForMember = false
            for profName, profData in pairs(memberData.professions) do
                if not addedForMember and profData.recipes then
                    for _, id in ipairs(profData.recipes) do
                        if id == recipeID then
                            table.insert(crafters, {
                                name = isMe and self:GetPlayerFullName("player") or memberName,
                                class = memberData.class or "WARRIOR",
                                online = (isMe or memberData.online == true),
                                isSelf = isMe,
                                rank = profData.rank or 0,
                                maxRank = profData.maxRank or 0,
                                prof = self:NormalizeProfessionName(profName) or profName
                            })
                            addedForMember = true
                            break
                        end
                    end
                end
            end
        end
    end

    table.sort(crafters, function(a, b)
        if a.online ~= b.online then
            return a.online
        end
        return a.name < b.name
    end)

    return crafters
end

function YellowPages:GetRecipeInfo(recipeID)
    if not YellowPagesDB or not YellowPagesDB.recipes then return nil end
    local rec = YellowPagesDB.recipes[recipeID]
    if rec then
        self:ResolveRecipeMetadata(rec)
    end
    return rec
end

function YellowPages:GetFilteredRecipes(profFilter, searchFilter, onlineOnly, sortBy, qualityFilter, availableOnly)
    local results = {}
    if not YellowPagesDB or not YellowPagesDB.recipes then return results end

    local searchLower = searchFilter and searchFilter:trim():lower() or ""
    sortBy = sortBy or "NAME_ASC"
    local normFilter = (profFilter and profFilter ~= "ALL") and (self:NormalizeProfessionName(profFilter) or profFilter) or "ALL"

    for recipeID, data in pairs(YellowPagesDB.recipes) do
        local quality, level = self:ResolveRecipeMetadata(data)
        local recProf = self:NormalizeProfessionName(data.prof) or data.prof

        local matchProf = (normFilter == "ALL" or recProf == normFilter)
        local matchQuality = (not qualityFilter or qualityFilter == "ALL" or quality == qualityFilter)
        local matchSearch = true

        if searchLower ~= "" then
            local nameMatch = (data.name or ""):lower():find(searchLower, 1, true)
            local matMatch = false
            if not nameMatch and data.reagents then
                for _, r in ipairs(data.reagents) do
                    local rName = (r.itemID and r.itemID > 0 and self:GetItemNameSafe(r.itemID)) or r.name
                    if rName and rName:lower():find(searchLower, 1, true) then
                        matMatch = true
                        break
                    end
                end
            end
            matchSearch = (nameMatch or matMatch)
        end

        if matchProf and matchQuality and matchSearch then
            local crafters = self:GetCraftersForRecipe(recipeID)
            local hasOnline = false
            for _, c in ipairs(crafters) do
                if c.online then
                    hasOnline = true
                    break
                end
            end

            if (not onlineOnly or hasOnline) and (not availableOnly or #crafters > 0) then
                table.insert(results, {
                    recipe = data,
                    quality = quality,
                    level = level,
                    crafters = crafters,
                    crafterCount = #crafters,
                    hasOnlineCrafter = hasOnline
                })
            end
        end
    end

    table.sort(results, function(a, b)
        if sortBy == "LEVEL_ASC" then
            if a.level ~= b.level then return a.level < b.level end
            if a.quality ~= b.quality then return a.quality > b.quality end
        elseif sortBy == "LEVEL_DESC" then
            if a.level ~= b.level then return a.level > b.level end
            if a.quality ~= b.quality then return a.quality > b.quality end
        elseif sortBy == "QUALITY_DESC" then
            if a.quality ~= b.quality then return a.quality > b.quality end
            if a.level ~= b.level then return a.level > b.level end
        elseif sortBy == "QUALITY_ASC" then
            if a.quality ~= b.quality then return a.quality < b.quality end
            if a.level ~= b.level then return a.level < b.level end
        end
        return (a.recipe.name or "") < (b.recipe.name or "")
    end)

    return results
end

-- Aktualisiert den Online-Status aller Gildenmitglieder und lernt den eigenen vollständigen Namen (inkl. Nachname)
function YellowPages:UpdateGuildMembersStatus()
    if not YellowPagesDB or not YellowPagesDB.members then return end

    local myClass = UnitClass and select(2, UnitClass("player"))
    local myGUID = UnitGUID and UnitGUID("player")
    local myFirst = UnitName and UnitName("player")
    local myLevel = UnitLevel and UnitLevel("player")

    if self:IsInGuild() then
        if C_GuildInfo and C_GuildInfo.GuildRoster then
            pcall(C_GuildInfo.GuildRoster)
        elseif GuildRoster then
            pcall(GuildRoster)
        end

        local numMembers = GetNumGuildMembers and GetNumGuildMembers() or 0
        for i = 1, numMembers do
            local name, _, _, level, _, _, _, _, isOnline, _, classFileName, _, _, _, _, _, guid = GetGuildRosterInfo(i)
            if name then
                local cleanName = self:StripRealm(name) or name
                local online = (isOnline == 1 or isOnline == true)

                -- Eigenen vollständigen Namen mit Nachnamen anhand von GUID oder (Vorname + Level + Klasse) erkennen!
                local isMine = (guid and myGUID and guid == myGUID)
                if not isMine and not guid and online and myFirst then
                    isMine = (cleanName == myFirst or cleanName:sub(1, #myFirst + 1) == myFirst .. " ")
                        and level == myLevel and classFileName == myClass
                end
                if isMine then
                    self:LearnOwnFullName(cleanName)
                    online = true
                end

                if YellowPagesDB.members[cleanName] then
                    YellowPagesDB.members[cleanName].online = online
                    if classFileName then
                        YellowPagesDB.members[cleanName].class = classFileName
                    end
                end
            end
        end
    end

    for memberName, memberData in pairs(YellowPagesDB.members) do
        if self:IsSelf(memberName) then
            memberData.online = true
            if myClass then memberData.class = myClass end
        end
    end

    self:RepairAndConsolidateSelfData()
end

function YellowPages:LoadRecipeCatalog()
    if not self.RecipeCatalog then return 0 end
    YellowPagesDB = YellowPagesDB or {}
    YellowPagesDB.recipes = YellowPagesDB.recipes or {}

    local loaded = 0
    for recipeID, cat in pairs(self.RecipeCatalog) do
        local idNum = tonumber(recipeID)
        if idNum and type(cat) == "table" then
            local existing = YellowPagesDB.recipes[idNum]
            local isFallback = existing and existing.name and existing.name:find("^" .. (L["RECIPE_FALLBACK"] or "Rezept"):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") .. " #")
            if not existing or isFallback or not existing.reagents or #existing.reagents == 0 then
                local profName = (cat.prof and L[cat.prof]) or self:NormalizeProfessionName(cat.prof) or cat.prof or L["GENERAL"]
                local itemID = cat.itemID or (existing and existing.itemID) or 0
                local itemName, itemLink = nil, (existing and existing.itemLink)
                if itemID > 0 and (not itemLink or itemLink == "") then
                    itemName, itemLink = self:GetItemInfoSafe(itemID)
                end

                local reagents = {}
                if type(cat.reagents) == "table" then
                    for _, m in ipairs(cat.reagents) do
                        local mID = m.itemID or m[1]
                        local mCount = m.count or m[2] or 1
                        if mID and mID > 0 then
                            table.insert(reagents, {
                                itemID = mID,
                                name = self:GetItemNameSafe(mID),
                                count = mCount,
                                icon = self:GetItemIconSafe(mID)
                            })
                        end
                    end
                end

                local finalName = cat.name or itemName or (existing and not isFallback and existing.name) or (L["RECIPE_FALLBACK"] .. " #" .. idNum)
                local catIcon = cat.icon and (tonumber(cat.icon) or cat.icon) or nil
                self:RegisterRecipe({
                    id = idNum,
                    name = finalName,
                    prof = profName,
                    icon = catIcon or (existing and existing.icon) or (itemID > 0 and self:GetItemIconSafe(itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark",
                    itemLink = itemLink,
                    itemID = itemID,
                    quality = cat.quality or (existing and existing.quality),
                    level = cat.level or (existing and existing.level),
                    minMade = cat.minMade or (existing and existing.minMade) or 1,
                    maxMade = cat.maxMade or (existing and existing.maxMade) or 1,
                    reagents = (#reagents > 0) and reagents or (existing and existing.reagents) or {}
                })
                loaded = loaded + 1
            end
        end
    end

    -- Auch Sammelberufe (Kräuterkunde, Bergbau, Kürschnerei) als Basis-Katalog vorladen,
    -- damit Bergbau & Co. auch ohne aktiven Sammler in der Gilde nicht leer sind!
    for catKey, entries in pairs(GATHERING_CATALOG) do
        local normProf = L[catKey]
        for _, res in ipairs(entries) do
            local recID = 900000 + res.itemID
            if not YellowPagesDB.recipes[recID] then
                local locName = self:GetItemNameSafe(res.itemID)
                if not locName or locName:find("^Item #") then
                    locName = res.name
                end
                local icon = self:GetItemIconSafe(res.itemID)
                local _, itemLink = self:GetItemInfoSafe(res.itemID)

                self:RegisterRecipe({
                    id = recID,
                    name = locName,
                    prof = normProf,
                    icon = icon,
                    itemLink = itemLink,
                    itemID = res.itemID,
                    level = res.skill,
                    gatherSkill = res.skill,
                    minMade = 1,
                    maxMade = 1,
                    reagents = {
                        {
                            itemID = res.itemID,
                            name = locName,
                            count = 1,
                            icon = icon,
                        }
                    }
                })
                loaded = loaded + 1
            end
        end
    end

    return loaded
end

function YellowPages:ResetDatabase()
    YellowPagesDB = YellowPagesDB or {}
    YellowPagesDB.members = {}
    YellowPagesDB.recipes = {}
    self:Print(L["MSG_DB_RESET"])
    self:LoadRecipeCatalog()
    if self.ScanPlayerSkillLines then
        self:ScanPlayerSkillLines(false)
    end
    if self.ScanCurrentTradeSkill then
        self:ScanCurrentTradeSkill(false)
    end
    if self.RefreshUI then
        self:RefreshUI()
    end
end

function YellowPages:PrintStatus()
    local gName = self:GetGuildName() or L["NO_GUILD"]
    local memberCount = 0
    local recipeCount = 0

    if YellowPagesDB and YellowPagesDB.members then
        for _ in pairs(YellowPagesDB.members) do
            memberCount = memberCount + 1
        end
    end
    if YellowPagesDB and YellowPagesDB.recipes then
        for _ in pairs(YellowPagesDB.recipes) do
            recipeCount = recipeCount + 1
        end
    end

    self:Print(string.format("|cffffd100Status:|r Gilde: |cffffffff%s|r | Mitglieder in DB: |cffffffff%d|r | Rezepte in DB: |cffffffff%d|r", gName, memberCount, recipeCount))

    if YellowPagesDB and YellowPagesDB.members then
        for mName, mData in pairs(YellowPagesDB.members) do
            local isMe = self:IsSelf(mName)
            local statusStr = (isMe or mData.online) and "|cff00ff00Online|r" or "|cff888888Offline|r"
            local profsList = {}
            if mData.professions then
                for pName, pData in pairs(mData.professions) do
                    local count = pData.recipes and #pData.recipes or 0
                    table.insert(profsList, string.format("%s (%d/%d, %d Rezepte)", pName, pData.rank or 0, pData.maxRank or 300, count))
                end
            end
            local profsStr = #profsList > 0 and table.concat(profsList, ", ") or "|cffff8080Keine Berufe erfasst|r"
            local tag = isMe and " |cff00ccff(Du)|r" or ""
            self:Print(string.format(" - |cffffd100%s%s|r [%s]: %s", mName, tag, statusStr, profsStr))
        end
    end
end


