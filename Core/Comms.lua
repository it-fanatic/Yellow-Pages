--[[
    Yellow-Pages: Comms.lua
    Gildenweite Synchronisation, Handwerker-Anfragen & Auftragsbestätigungen
--]]

YellowPages = YellowPages or {}
local L = YellowPages.L
YellowPages.IncomingOrders = YellowPages.IncomingOrders or {}

local commFrame = CreateFrame("Frame", "YellowPagesCommsFrame")
pcall(commFrame.RegisterEvent, commFrame, "CHAT_MSG_ADDON")

local sendQueue = {}
local isQueueRunning = false

local function ProcessSendQueue()
    if #sendQueue == 0 then
        isQueueRunning = false
        return
    end
    isQueueRunning = true
    local item = table.remove(sendQueue, 1)
    if item then
        YellowPages:SendAddonMsgDirect(item.msg, item.channel, item.target)
    end
    -- Adaptives Throttling: Erste Pakete (PLISTs) schnell senden, große Hintergrund-Batches (RECs)
    -- schonend drosseln, damit der WoW-Server keine Chat-Nachrichten verwirft!
    local nextDelay = (#sendQueue > 8) and 0.45 or 0.12
    C_Timer.After(nextDelay, ProcessSendQueue)
end

function YellowPages:QueueAddonMsg(msg, targetChannel, targetPlayer)
    local ch = targetChannel or "GUILD"
    for _, existing in ipairs(sendQueue) do
        if existing.msg == msg and existing.channel == ch and existing.target == targetPlayer then
            return
        end
    end
    table.insert(sendQueue, {
        msg = msg,
        channel = ch,
        target = targetPlayer
    })
    if not isQueueRunning then
        ProcessSendQueue()
    end
end

function YellowPages:SendAddonMsgDirect(msg, targetChannel, targetPlayer)
    targetChannel = targetChannel or "GUILD"
    local prefix = self.AddonPrefix

    if targetChannel == "GUILD" and not self:IsInGuild() then
        return false
    end

    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        local ok = pcall(C_ChatInfo.SendAddonMessage, prefix, msg, targetChannel, targetPlayer)
        if ok then return true end
    end

    if SendAddonMessage then
        local ok = pcall(SendAddonMessage, prefix, msg, targetChannel, targetPlayer)
        if ok then return true end
    end

    return false
end

function YellowPages:SendAddonMsg(msg, targetChannel, targetPlayer)
    return self:SendAddonMsgDirect(msg, targetChannel, targetPlayer)
end

-- Sicheres Senden einer Whisper-Nachricht (inkl. Solo-Test-Fallback falls Nachname noch nicht vom Server geladen)
function YellowPages:SendSafeWhisper(msg, targetName)
    if not msg or not targetName then return end
    self:UpdateGuildMembersStatus()

    local cleanTarget = self:StripRealm(targetName) or targetName
    if self:IsSelf(cleanTarget) then
        cleanTarget = self:GetPlayerFullName("player")
        -- Falls der eigene Nachname noch kein Leerzeichen hat (Gilden-Roster noch nicht vom Server da),
        -- geben wir die Whisper-Nachricht mit klickbarem Link direkt lokal im Chat aus, damit kein "Spieler nicht gefunden" kommt!
        if not cleanTarget:find(" ") then
            local formatted = msg
            formatted = formatted:gsub("%[YP:(%d+):(%d+)%]", function(recIDStr, countStr)
                return self:FormatOrderChatLink(tonumber(recIDStr), tonumber(countStr), cleanTarget)
            end)
            formatted = formatted:gsub("%[YPC:(%d+):(%d+):([%u]+)%]", function(recIDStr, countStr, modeStr)
                return self:FormatConfirmChatLink(tonumber(recIDStr), tonumber(countStr), modeStr, cleanTarget)
            end)
            formatted = formatted:gsub("%[YPC:(%d+):(%d+)%]", function(recIDStr, countStr)
                return self:FormatConfirmChatLink(tonumber(recIDStr), tonumber(countStr), "BRING", cleanTarget)
            end)
            DEFAULT_CHAT_FRAME:AddMessage("|cffff80ff[Whisper -> " .. cleanTarget .. "]:|r " .. formatted)
            return
        end
    end

    SendChatMessage(msg, "WHISPER", nil, cleanTarget)
end

-- Meldet der Gilde die eigenen Berufe (trägt GUID mit, um aus dem eigenen Echo den vollen Namen mit Nachnamen zu lernen)
function YellowPages:BroadcastHello()
    if not self:IsInGuild() then return end
    local myData, playerName = self:GetMyMemberData()
    local playerClass = UnitClass and select(2, UnitClass("player")) or "WARRIOR"
    local myGUID = UnitGUID and UnitGUID("player") or ""

    local profSummary = {}
    if myData and myData.professions then
        for profName, pData in pairs(myData.professions) do
            local recCount = pData.recipes and #pData.recipes or 0
            table.insert(profSummary, string.format("%s:%d:%d:%d", profName, pData.rank or 0, pData.maxRank or 300, recCount))
        end
    end

    local payload = string.format("HELLO:%s:%s:%s", myGUID, playerClass, table.concat(profSummary, ";"))
    self:SendAddonMsg(payload, "GUILD")

    -- Prüfen, ob lokal gespeicherte Offline-Anfragen für den eigenen Charakter vorliegen (z.B. von eigenem Twink)
    if self.CheckMyOwnPendingOfflineOrders then
        self:CheckMyOwnPendingOfflineOrders()
    end
end

-- Sendet einen Beruf inklusive aller Rezepte und Reagenzien an die Gilde
-- sendMode: "PLIST" (nur Rezeptliste), "REC" (nur Detaildaten/Namen) oder nil (beides: erst PLIST, dann REC)
function YellowPages:BroadcastProfessionData(profName, sendMode)
    if not self:IsInGuild() or not profName then return end
    local myData, playerName = self:GetMyMemberData()
    local playerClass = UnitClass and select(2, UnitClass("player")) or "WARRIOR"
    if not myData or not myData.professions then return end

    local normTargetProf = self:NormalizeProfessionName(profName) or profName
    local pData = myData.professions[normTargetProf] or myData.professions[profName]
    if not pData or not pData.recipes or #pData.recipes == 0 then return end

    -- 1. SCHRITT: Vollständige Rezept-Liste (PLIST) senden!
    -- Da PLIST extrem kompakt ist (nur 1-3 Chat-Pakete), kommt sie garantiert
    -- und ohne Chat-Drosselung (Throttle) sofort bei allen Gildenmitgliedern an!
    if not sendMode or sendMode == "PLIST" then
        local chunk = {}
        local chunkLen = 0
        local header = string.format("PLIST:%s:%d:%d:%s:", normTargetProf, pData.rank or 0, pData.maxRank or 300, playerClass)

        for _, recipeID in ipairs(pData.recipes) do
            local idStr = tostring(recipeID)
            if #header + chunkLen + #idStr + 1 > 240 then
                self:QueueAddonMsg(header .. table.concat(chunk, ","), "GUILD")
                chunk = {}
                chunkLen = 0
            end
            table.insert(chunk, idStr)
            chunkLen = chunkLen + #idStr + 1
        end

        if #chunk > 0 then
            self:QueueAddonMsg(header .. table.concat(chunk, ","), "GUILD")
        end
    end

    -- 2. SCHRITT: Detaillierte Rezept-Daten (Namen, Output-Items & Reagenzien) im Hintergrund nachsenden.
    -- Rezepte, die bereits im statischen Katalog (Data/RecipeCatalog.lua) stehen, werden übersprungen (0 Chat-Traffic!).
    if not sendMode or sendMode == "REC" then
        for _, recipeID in ipairs(pData.recipes) do
            local inCatalog = self.RecipeCatalog and self.RecipeCatalog[recipeID]
            local r = not inCatalog and self:GetRecipeInfo(recipeID)
            if r then
                local matParts = {}
                if r.reagents then
                    for _, m in ipairs(r.reagents) do
                        if m.itemID and m.itemID > 0 then
                            table.insert(matParts, string.format("%d=%d", m.itemID, m.count or 1))
                        end
                    end
                end
                local safeName = (r.name or L["RECIPE_FALLBACK"]):gsub("[:;|]", " "):sub(1, 48)
                local recMsg = string.format("REC:%d:%s:%d:%s:%s",
                    recipeID,
                    normTargetProf,
                    r.itemID or 0,
                    safeName,
                    table.concat(matParts, ",")
                )
                if #recMsg <= 250 then
                    self:QueueAddonMsg(recMsg, "GUILD")
                end
            end
        end
    end
end

function YellowPages:BroadcastAllMyProfessions()
    if not self:IsInGuild() then return 0, 0 end
    local myData = self:GetMyMemberData()
    if not myData or not myData.professions then return 0, 0 end

    local profNames = {}
    local profCount = 0
    local recCount = 0
    for profName, pData in pairs(myData.professions) do
        local count = pData.recipes and #pData.recipes or 0
        if count > 0 then
            profCount = profCount + 1
            recCount = recCount + count
            table.insert(profNames, profName)
        end
    end

    -- Erst ALLE PLISTs aller Berufe senden, damit sofort jeder Beruf & Handwerker da ist!
    for _, profName in ipairs(profNames) do
        self:BroadcastProfessionData(profName, "PLIST")
    end
    -- Danach ALLE Detail-RECs (Namen & Zutaten) schonend in die Hintergrund-Warteschlange legen
    for _, profName in ipairs(profNames) do
        self:BroadcastProfessionData(profName, "REC")
    end

    return profCount, recCount
end

-- Fordert eine bidirektionale Synchronisation mit der gesamten Gilde an (sendet eigene Daten und bittet alle Online-Mitglieder um ihre Daten)
function YellowPages:RequestGuildSync()
    if not self:IsInGuild() then
        self:Print(L["NO_GUILD"])
        return
    end
    self:BroadcastHello()
    local profCount, recCount = self:BroadcastAllMyProfessions()
    self:SendAddonMsg("REQ_SYNC:ALL", "GUILD")

    if profCount == 0 or recCount == 0 then
        self:Print(L["MSG_SYNC_NO_RECIPES"])
    else
        self:Print(string.format(L["MSG_SYNC_STATS"], profCount, recCount))
    end
end

-- Schritt 1: Anfragender schickt Anfrage + seine vorhandenen/fehlenden Mats an den Handwerker
-- (Unterstützt sowohl Online-Handwerker per Live-Whisper als auch Offline-Handwerker über das Gilden-Relais!)
function YellowPages:SendCraftOrder(crafterName, recipeID, count, isOffline)
    if not crafterName or not recipeID then return end
    count = count or 1

    self:UpdateGuildMembersStatus()
    if self:IsSelf(crafterName) then
        crafterName = self:GetPlayerFullName("player")
        isOffline = false
    else
        crafterName = self:StripRealm(crafterName) or crafterName
    end

    local recipe = self:GetRecipeInfo(recipeID)
    local itemName = recipe and recipe.name or ("#" .. tostring(recipeID))
    local itemLink = (recipe and recipe.itemLink and recipe.itemLink ~= "") and recipe.itemLink or itemName

    -- Eigenen Materialbestand des Anfragenden prüfen
    local buyerHaveParts = {}
    local buyerHaveMap = {}
    local missingList = {}

    if recipe and recipe.reagents then
        for _, r in ipairs(recipe.reagents) do
            local needed = (r.count or 1) * count
            local owned = self:GetTotalItemCount(r.itemID)
            local haveForOrder = math.min(needed, owned)
            local missing = math.max(0, needed - owned)

            if r.itemID and r.itemID > 0 then
                buyerHaveMap[r.itemID] = haveForOrder
                table.insert(buyerHaveParts, string.format("%d=%d", r.itemID, haveForOrder))
            end

            if missing > 0 then
                local rName = (r.itemID and r.itemID > 0 and self:GetItemNameSafe(r.itemID)) or r.name or L["REAGENT_FALLBACK"]
                table.insert(missingList, string.format("%dx %s", missing, rName))
            end
        end
    end

    local buyerName = self:GetPlayerFullName("player")
    local matsStr = table.concat(buyerHaveParts, ",")
    local orderObj = {
        buyer = buyerName,
        recipeID = recipeID,
        count = count,
        buyerHaveMap = buyerHaveMap,
        timestamp = time()
    }
    self.IncomingOrders[buyerName .. "_" .. tostring(recipeID)] = orderObj
    self.IncomingOrders[recipeID] = orderObj

    -- FALL A: Handwerker ist OFFLINE -> Im Gilden-Relais (Store & Forward) speichern und an alle Online-Mitglieder verteilen!
    if isOffline then
        YellowPagesDB = YellowPagesDB or {}
        YellowPagesDB.pendingOfflineOrders = YellowPagesDB.pendingOfflineOrders or {}

        local orderID = string.format("%x_%d", time() % 1000000, math.random(10, 99))
        YellowPagesDB.pendingOfflineOrders[orderID] = {
            id = orderID,
            crafter = crafterName,
            buyer = buyerName,
            recipeID = recipeID,
            count = count,
            matsStr = matsStr,
            timestamp = time()
        }

        -- An alle aktuell eingeloggten Gildenmitglieder verteilen, damit auch diese die Anfrage zustellen können,
        -- falls der Anfragende offline ist, wenn der Handwerker später online kommt!
        local storePayload = string.format("OFFSTORE:%s:%s:%s:%d:%d:%s",
            orderID, crafterName, buyerName, recipeID, count, matsStr
        )
        self:SendAddonMsg(storePayload, "GUILD")

        self:Print(string.format(L["MSG_OFFLINE_ORDER_SAVED"], itemName, count, crafterName))
        return
    end

    -- FALL B: Handwerker ist ONLINE -> Live-Whisper + Addon-Nachricht
    local whisperMsg
    if #missingList == 0 then
        whisperMsg = string.format(L["WHISPER_REQ_ALL_MATS"], itemLink, count, recipeID, count)
    else
        local missingStr = table.concat(missingList, ", ")
        whisperMsg = string.format(L["WHISPER_REQ_MISSING_MATS"], itemLink, count, missingStr, recipeID, count)
    end
    self:SendSafeWhisper(whisperMsg, crafterName)

    if not self:IsSelf(crafterName) then
        local addonPayload = string.format("ORDER:%d:%d:%s:%s",
            recipeID,
            count,
            buyerName,
            matsStr
        )
        self:SendAddonMsg(addonPayload, "WHISPER", crafterName)
    end

    self:Print(string.format(L["MSG_ORDER_SENT"], itemName, crafterName))
end

-- Verarbeitet eine zugestellte Offline-Anfrage beim Handwerker nach dessen Login
function YellowPages:ReceiveOfflineOrderDelivery(orderID, buyerName, recipeID, count, matsHaveStr)
    if not orderID or not recipeID then return end
    YellowPagesCharDB = YellowPagesCharDB or {}
    YellowPagesCharDB.deliveredOfflineIDs = YellowPagesCharDB.deliveredOfflineIDs or {}

    if YellowPagesCharDB.deliveredOfflineIDs[orderID] then
        -- Bereits empfangen -> nur kurz ACK an Gilde senden, damit es überall gelöscht wird
        self:SendAddonMsg("OFFACK:" .. tostring(orderID), "GUILD")
        return
    end

    YellowPagesCharDB.deliveredOfflineIDs[orderID] = time()
    if YellowPagesDB and YellowPagesDB.pendingOfflineOrders then
        YellowPagesDB.pendingOfflineOrders[orderID] = nil
    end

    -- Empfang in der Gilde bestätigen, damit alle Relais-Mitglieder den Auftrag aus dem Zwischenspeicher löschen
    self:SendAddonMsg("OFFACK:" .. tostring(orderID), "GUILD")

    local buyerHaveMap = {}
    for pairStr in (matsHaveStr or ""):gmatch("[^,]+") do
        local idStr, haveStr = pairStr:match("^(%d+)=(%d+)$")
        local itemID = tonumber(idStr)
        local haveCount = tonumber(haveStr)
        if itemID and haveCount then
            buyerHaveMap[itemID] = haveCount
        end
    end

    local cleanBuyer = self:StripRealm(buyerName) or buyerName or L["UNKNOWN"]
    local orderData = {
        buyer = cleanBuyer,
        recipeID = recipeID,
        count = count or 1,
        buyerHaveMap = buyerHaveMap,
        timestamp = time()
    }
    self.IncomingOrders[cleanBuyer .. "_" .. tostring(recipeID)] = orderData
    self.IncomingOrders[recipeID] = orderData

    if PlaySound and SOUNDKIT then
        pcall(PlaySound, SOUNDKIT.TELL_MESSAGE or 5274)
    end

    local recipe = self:GetRecipeInfo(recipeID)
    local itemName = (recipe and recipe.itemLink and recipe.itemLink ~= "" and recipe.itemLink)
        or (recipe and recipe.name) or ("#" .. tostring(recipeID))
    local clickLink = self:FormatOrderChatLink(recipeID, count or 1, cleanBuyer)

    self:Print(string.format(L["MSG_OFFLINE_DELIVERED"], cleanBuyer, itemName, count or 1, clickLink))
end

-- Prüft beim eigenen Login, ob in der lokalen Datenbank Offline-Anfragen für den eigenen Charakter liegen
function YellowPages:CheckMyOwnPendingOfflineOrders()
    if not YellowPagesDB or not YellowPagesDB.pendingOfflineOrders then return end
    for orderID, o in pairs(YellowPagesDB.pendingOfflineOrders) do
        if o and o.crafter and self:IsSelf(o.crafter) then
            self:ReceiveOfflineOrderDelivery(orderID, o.buyer, o.recipeID, o.count, o.matsStr)
        end
    end
end

-- Stellt zwischengespeicherte Offline-Anfragen an ein Gildenmitglied zu, sobald dieses online kommt
function YellowPages:DeliverPendingOfflineOrdersFor(onlineMemberName)
    if not onlineMemberName or not YellowPagesDB or not YellowPagesDB.pendingOfflineOrders then return end
    local targetLower = (self:StripRealm(onlineMemberName) or onlineMemberName):lower()
    local now = time()

    for orderID, o in pairs(YellowPagesDB.pendingOfflineOrders) do
        if type(o) == "table" then
            -- Veraltete Anfragen (> 14 Tage) bereinigen
            if o.timestamp and (now - o.timestamp > 14 * 86400) then
                YellowPagesDB.pendingOfflineOrders[orderID] = nil
            elseif o.crafter and (self:StripRealm(o.crafter) or o.crafter):lower() == targetLower then
                -- Kleine zufällige Verzögerung (0.5 - 2.0s), damit nicht alle Gildenmitglieder gleichzeitig senden
                local delay = 0.5 + math.random() * 1.5
                C_Timer.After(delay, function()
                    if YellowPagesDB and YellowPagesDB.pendingOfflineOrders and YellowPagesDB.pendingOfflineOrders[orderID] then
                        local payload = string.format("OFFDELIV:%s:%s:%s:%d:%d:%s",
                            orderID, o.crafter, o.buyer or "Unknown", o.recipeID or 0, o.count or 1, o.matsStr or ""
                        )
                        YellowPages:SendAddonMsg(payload, "GUILD")
                    end
                end)
            end
        end
    end
end

-- Schritt 2b: Handwerker sendet sein Angebot (inkl. ggf. noch zu besorgender Rest-Materialien)
function YellowPages:SendCrafterOffer(buyerName, recipeID, count, mode, stillToBuyMap)
    if not buyerName or not recipeID then return end
    self.IncomingOffers = self.IncomingOffers or {}

    local parts = {}
    if type(stillToBuyMap) == "table" then
        for itemID, qty in pairs(stillToBuyMap) do
            if itemID and qty and qty > 0 then
                table.insert(parts, string.format("%d=%d", itemID, qty))
            end
        end
    end

    self.IncomingOffers[recipeID] = {
        mode = mode or "BRING",
        stillToBuyMap = stillToBuyMap or {},
        timestamp = time()
    }

    local cleanBuyer = self:StripRealm(buyerName) or buyerName
    if not self:IsSelf(cleanBuyer) then
        local payload = string.format("OFFER:%d:%d:%s:%s", recipeID, count or 1, mode or "BRING", table.concat(parts, ","))
        self:SendAddonMsg(payload, "WHISPER", cleanBuyer)
    end
end

-- Schritt 3: Auftraggeber klickt auf [Yellow-Pages: Auftrag bestätigen] ->
-- 1) Fehlende Materialien wandern automatisch in die Einkaufsliste des Auftraggebers (für das AH-Pop-Up!)
-- 2) Der bestätigte Auftrag landet in der Auftragsliste des Handwerkers!
function YellowPages:ConfirmCraftOrder(crafterName, recipeID, count, mode)
    if not crafterName or not recipeID then return end
    count = tonumber(count) or 1
    mode = mode or "BRING"

    self:UpdateGuildMembersStatus()
    if self:IsSelf(crafterName) then
        crafterName = self:GetPlayerFullName("player")
    else
        crafterName = self:StripRealm(crafterName) or crafterName
    end

    local recipe = self:GetRecipeInfo(recipeID)
    local itemName = recipe and recipe.name or ("#" .. tostring(recipeID))
    local itemLink = (recipe and recipe.itemLink and recipe.itemLink ~= "") and recipe.itemLink or itemName
    local buyerName = self:GetPlayerFullName("player")

    -- 1. Fehlende Materialien automatisch in die Einkaufsliste des Anfragenden übernehmen!
    if self.AddMissingMatsToShoppingList then
        self:AddMissingMatsToShoppingList(recipeID, count, mode)
    end

    -- 2. Bestätigungs-Whisper an den Handwerker
    local confirmWhisper = string.format(L["WHISPER_ORDER_CONFIRMED"], itemLink, count)
    self:SendSafeWhisper(confirmWhisper, crafterName)
    self:Print(string.format(L["MSG_CONFIRM_SENT"], itemName, count, crafterName))

    -- 3. Addon-Signal CONFIRM an den Handwerker (oder lokal beim Solo-Test direkt in die Auftragsliste eintragen)
    if self:IsSelf(crafterName) then
        self:AddConfirmedOrderToQueue(buyerName, recipeID, count)
    else
        local addonPayload = string.format("CONFIRM:%d:%d:%s", recipeID, count, buyerName)
        self:SendAddonMsg(addonPayload, "WHISPER", crafterName)
    end
end

-- Empfang von Addon-Nachrichten
commFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if event ~= "CHAT_MSG_ADDON" or prefix ~= YellowPages.AddonPrefix then return end
    if type(message) ~= "string" or type(sender) ~= "string" then return end

    local cleanSender = YellowPages:StripRealm(sender) or sender
    local msgType, data = message:match("^([%a_]+):?(.*)$")
    if not msgType then return end
    data = data or ""

    -- Eigenes HELLO-Echo prüfen, um unseren vollständigen Namen mit Nachnamen zu lernen!
    if msgType == "HELLO" then
        local senderGUID, senderClass, profListStr = data:match("^([^:]*):([^:]+):(.*)$")
        local myGUID = UnitGUID and UnitGUID("player")
        if senderGUID and myGUID and senderGUID == myGUID then
            YellowPages:LearnOwnFullName(cleanSender)
            return
        end
    end

    if YellowPages:IsSelf(cleanSender) then return end

    YellowPagesDB = YellowPagesDB or {}
    YellowPagesDB.members = YellowPagesDB.members or {}
    YellowPagesDB.recipes = YellowPagesDB.recipes or {}

    if msgType == "HELLO" then
        local _, senderClass, profListStr = data:match("^([^:]*):([^:]+):(.*)$")
        if not senderClass then
            senderClass, profListStr = data:match("^([^:]+):(.*)$")
        end
        senderClass = senderClass or "WARRIOR"

        if not YellowPagesDB.members[cleanSender] then
            YellowPagesDB.members[cleanSender] = {
                class = senderClass,
                online = true,
                lastSeen = time(),
                professions = {}
            }
        end
        local m = YellowPagesDB.members[cleanSender]
        m.class = senderClass
        m.online = true
        m.lastSeen = time()
        m.professions = m.professions or {}

        for profStr in (profListStr or ""):gmatch("[^;]+") do
            local pName, pRank, pMaxRank = profStr:match("^([^:]+):(%d+):(%d+)")
            if pName then
                local normProf = YellowPages:NormalizeProfessionName(pName) or pName
                local rankNum = tonumber(pRank) or 0
                local maxRankNum = tonumber(pMaxRank) or 300
                if YellowPages:GetGatheringCatalogKey(normProf) then
                    YellowPages:RegisterGatheringProfession(cleanSender, senderClass, normProf, rankNum, maxRankNum)
                else
                    m.professions[normProf] = m.professions[normProf] or { recipes = {} }
                    m.professions[normProf].rank = rankNum
                    m.professions[normProf].maxRank = maxRankNum
                end
            end
        end

        -- Prüfen, ob wir gespeicherte Offline-Anfragen für dieses soeben eingeloggte Gildenmitglied haben!
        if YellowPages.DeliverPendingOfflineOrdersFor then
            YellowPages:DeliverPendingOfflineOrdersFor(cleanSender)
        end

        if YellowPages.RefreshUI then
            YellowPages:RefreshUI()
        end

    elseif msgType == "REQ_SYNC" then
        -- Ein Gildenmitglied hat auf 'Sync' geklickt -> mit eigenen Berufsdaten antworten
        local delay = 0.3 + math.random() * 1.2
        C_Timer.After(delay, function()
            YellowPages:BroadcastHello()
            YellowPages:BroadcastAllMyProfessions()
        end)

    elseif msgType == "REC" then
        local recIDStr, profName, itemIDStr, recName, matsStr = data:match("^(%d+):([^:]+):(%d+):([^:]+):(.*)$")
        local recipeID = tonumber(recIDStr)
        if recipeID and profName and recName then
            local normProf = YellowPages:NormalizeProfessionName(profName) or profName
            local outputItemID = tonumber(itemIDStr) or 0
            local reagents = {}
            for matPair in (matsStr or ""):gmatch("[^,]+") do
                local mIDStr, mCountStr = matPair:match("^(%d+)=(%d+)$")
                local mID = tonumber(mIDStr)
                local mCount = tonumber(mCountStr) or 1
                if mID and mID > 0 then
                    table.insert(reagents, {
                        itemID = mID,
                        name = YellowPages:GetItemNameSafe(mID),
                        count = mCount,
                        icon = YellowPages:GetItemIconSafe(mID)
                    })
                end
            end

            local existing = YellowPagesDB.recipes[recipeID]
            local _, itemLink = YellowPages:GetItemInfoSafe(outputItemID)
            YellowPages:RegisterRecipe({
                id = recipeID,
                name = recName,
                prof = normProf,
                icon = (existing and existing.icon) or YellowPages:GetItemIconSafe(outputItemID),
                itemLink = (existing and existing.itemLink) or itemLink,
                itemID = outputItemID,
                reagents = (#reagents > 0) and reagents or (existing and existing.reagents) or {}
            })

            if YellowPages.RefreshUI and not YellowPages._recRefreshPending then
                YellowPages._recRefreshPending = true
                C_Timer.After(0.6, function()
                    YellowPages._recRefreshPending = false
                    if YellowPages.RefreshUI then
                        YellowPages:RefreshUI()
                    end
                end)
            end
        end

    elseif msgType == "PLIST" then
        local profName, rankStr, maxRankStr, classEn, idListStr = data:match("^([^:]+):(%d+):(%d+):([^:]*):?(.*)$")
        if profName and idListStr then
            local normProf = YellowPages:NormalizeProfessionName(profName) or profName
            YellowPagesDB.members[cleanSender] = YellowPagesDB.members[cleanSender] or {
                class = (classEn and classEn ~= "") and classEn or "WARRIOR",
                online = true,
                lastSeen = time(),
                professions = {}
            }
            local m = YellowPagesDB.members[cleanSender]
            if classEn and classEn ~= "" then m.class = classEn end
            m.online = true
            m.lastSeen = time()
            m.professions = m.professions or {}
            m.professions[normProf] = m.professions[normProf] or { recipes = {} }
            local p = m.professions[normProf]
            p.rank = tonumber(rankStr) or p.rank or 0
            p.maxRank = tonumber(maxRankStr) or p.maxRank or 300
            p.recipes = p.recipes or {}

            local knownSet = {}
            for _, id in ipairs(p.recipes) do knownSet[id] = true end

            local addedCount = 0
            for idStr in idListStr:gmatch("(%d+)") do
                local id = tonumber(idStr)
                if id then
                    -- Falls das Rezept noch nicht in der Rezept-DB ist (z.B. REC noch unterwegs oder ausgelassen),
                    -- sofort einen Eintrag anlegen, damit es in der Liste aufgeführt wird!
                    if not YellowPagesDB.recipes[id] then
                        local itemName, itemLink = YellowPages:GetItemInfoSafe(id)
                        YellowPages:RegisterRecipe({
                            id = id,
                            name = itemName or (L["RECIPE_FALLBACK"] .. " #" .. id),
                            prof = normProf,
                            itemLink = itemLink,
                            itemID = id < 900000 and id or 0
                        })
                    end

                    if not knownSet[id] then
                        knownSet[id] = true
                        table.insert(p.recipes, id)
                        addedCount = addedCount + 1
                    end
                end
            end

            if addedCount > 0 or #p.recipes > 0 then
                YellowPages:Print(string.format(L["MSG_RECEIVED_PROF_DATA"], cleanSender, normProf, #p.recipes))
            end

            if YellowPages.RefreshUI then
                YellowPages:RefreshUI()
            end
        end

    elseif msgType == "ORDER" then
        -- Format: ORDER:recipeID:count:buyerName:itemID1=have1,itemID2=have2
        local recIDStr, countStr, buyerName, matsHaveStr = data:match("^(%d+):(%d+):([^:]+):?(.*)$")
        local recipeID = tonumber(recIDStr)
        if recipeID then
            local count = tonumber(countStr) or 1
            buyerName = YellowPages:StripRealm(buyerName) or cleanSender

            local buyerHaveMap = {}
            for pairStr in (matsHaveStr or ""):gmatch("[^,]+") do
                local idStr, haveStr = pairStr:match("^(%d+)=(%d+)$")
                local itemID = tonumber(idStr)
                local haveCount = tonumber(haveStr)
                if itemID and haveCount then
                    buyerHaveMap[itemID] = haveCount
                end
            end

            local orderData = {
                buyer = buyerName,
                recipeID = recipeID,
                count = count,
                buyerHaveMap = buyerHaveMap,
                timestamp = time()
            }
            YellowPages.IncomingOrders[buyerName .. "_" .. tostring(recipeID)] = orderData
            YellowPages.IncomingOrders[recipeID] = orderData

            if PlaySound and SOUNDKIT then
                pcall(PlaySound, SOUNDKIT.TELL_MESSAGE or 5274)
            end
        end

    elseif msgType == "OFFER" then
        -- Format: OFFER:recipeID:count:mode:itemID1=qty1,itemID2=qty2
        local recIDStr, countStr, modeStr, matsStr = data:match("^(%d+):(%d+):([%u]+):?(.*)$")
        local recipeID = tonumber(recIDStr)
        if recipeID then
            local stillMap = {}
            for pairStr in (matsStr or ""):gmatch("[^,]+") do
                local idStr, qtyStr = pairStr:match("^(%d+)=(%d+)$")
                local itemID = tonumber(idStr)
                local qty = tonumber(qtyStr)
                if itemID and qty then
                    stillMap[itemID] = qty
                end
            end
            YellowPages.IncomingOffers = YellowPages.IncomingOffers or {}
            YellowPages.IncomingOffers[recipeID] = {
                mode = modeStr or "BRING",
                count = tonumber(countStr) or 1,
                stillToBuyMap = stillMap,
                timestamp = time()
            }
        end

    elseif msgType == "CONFIRM" then
        -- Format: CONFIRM:recipeID:count:buyerName
        local recIDStr, countStr, buyerName = data:match("^(%d+):(%d+):(.+)$")
        local recipeID = tonumber(recIDStr)
        if recipeID then
            local count = tonumber(countStr) or 1
            buyerName = YellowPages:StripRealm(buyerName) or cleanSender

            if PlaySound and SOUNDKIT then
                pcall(PlaySound, SOUNDKIT.IG_QUEST_LIST_OPEN or 875)
            end

            YellowPages:AddConfirmedOrderToQueue(buyerName, recipeID, count)
        end

    elseif msgType == "OFFSTORE" then
        -- Format: OFFSTORE:orderID:crafterName:buyerName:recipeID:count:matsStr
        local orderID, crafterName, buyerName, recIDStr, countStr, matsStr = data:match("^([^:]+):([^:]+):([^:]+):(%d+):(%d+):?(.*)$")
        local recipeID = tonumber(recIDStr)
        if orderID and crafterName and recipeID then
            local count = tonumber(countStr) or 1
            -- Falls der Ziel-Handwerker zufällig wir selbst sind (gerade eingeloggt), direkt zustellen!
            if YellowPages:IsSelf(crafterName) then
                YellowPages:ReceiveOfflineOrderDelivery(orderID, buyerName, recipeID, count, matsStr)
            else
                -- Im lokalen Gilden-Relais zwischenspeichern
                YellowPagesDB.pendingOfflineOrders = YellowPagesDB.pendingOfflineOrders or {}
                YellowPagesDB.pendingOfflineOrders[orderID] = {
                    id = orderID,
                    crafter = crafterName,
                    buyer = buyerName,
                    recipeID = recipeID,
                    count = count,
                    matsStr = matsStr or "",
                    timestamp = time()
                }
            end
        end

    elseif msgType == "OFFDELIV" then
        -- Format: OFFDELIV:orderID:crafterName:buyerName:recipeID:count:matsStr
        local orderID, crafterName, buyerName, recIDStr, countStr, matsStr = data:match("^([^:]+):([^:]+):([^:]+):(%d+):(%d+):?(.*)$")
        local recipeID = tonumber(recIDStr)
        if orderID and crafterName and recipeID and YellowPages:IsSelf(crafterName) then
            YellowPages:ReceiveOfflineOrderDelivery(orderID, buyerName, recipeID, tonumber(countStr) or 1, matsStr)
        end

    elseif msgType == "OFFACK" then
        -- Format: OFFACK:orderID (Handwerker hat die Offline-Anfrage erhalten -> überall aus dem Zwischenspeicher löschen)
        local orderID = data:match("^([^:]+)$")
        if orderID and YellowPagesDB and YellowPagesDB.pendingOfflineOrders then
            YellowPagesDB.pendingOfflineOrders[orderID] = nil
        end
    end
end)
