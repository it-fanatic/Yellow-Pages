--[[
    Yellow-Pages: OrderFrame.lua
    1) Handwerker-Anfrage-Fenster (Materialabgleich + 4 Direkt-Antworten mit Bestätigungs-Link)
    2) Auftragsliste (Todo-Liste des Handwerkers mit automatischem Abhaken beim Herstellen)
--]]

YellowPages = YellowPages or {}

local L = YellowPages.L
local Theme = YellowPages.Theme
local orderFrame = nil
local queueFrame = nil
local activeOrder = nil

local function AttachButtonTooltip(btn, titleText, descText)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(titleText, 1, 0.82, 0)
        if descText and descText ~= "" then
            GameTooltip:AddLine(descText, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ============================================================================
-- 1. HANDWERKER-ANFRAGE-FENSTER (Incoming Request View)
-- ============================================================================

function YellowPages:CreateOrderFrame()
    if orderFrame then return orderFrame end

    orderFrame = CreateFrame("Frame", "YellowPagesOrderFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    orderFrame:SetSize(560, 465)
    orderFrame:SetPoint("CENTER", 0, 40)
    orderFrame:SetFrameStrata("DIALOG")
    orderFrame:EnableMouse(true)
    orderFrame:SetMovable(true)
    orderFrame:RegisterForDrag("LeftButton")
    orderFrame:SetScript("OnDragStart", orderFrame.StartMoving)
    orderFrame:SetScript("OnDragStop", orderFrame.StopMovingOrSizing)
    orderFrame:SetClampedToScreen(true)

    Theme:ApplyBackdrop(orderFrame, nil, nil, nil, nil, nil, nil, nil, nil, true)

    local title = orderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText(L["ORDER_WINDOW_TITLE"])
    orderFrame.title = title

    local closeBtn = CreateFrame("Button", nil, orderFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function() orderFrame:Hide() end)

    local buyerText = orderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    buyerText:SetPoint("TOPLEFT", 18, -40)
    orderFrame.buyerText = buyerText

    local line1 = orderFrame:CreateTexture(nil, "ARTWORK")
    line1:SetPoint("TOPLEFT", 14, -62)
    line1:SetPoint("TOPRIGHT", -14, -62)
    line1:SetHeight(1)
    line1:SetColorTexture(0.8, 0.65, 0.2, 0.4)

    local itemIcon = orderFrame:CreateTexture(nil, "ARTWORK")
    itemIcon:SetSize(38, 38)
    itemIcon:SetPoint("TOPLEFT", 18, -72)
    orderFrame.itemIcon = itemIcon

    local itemNameText = orderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    itemNameText:SetPoint("TOPLEFT", itemIcon, "TOPRIGHT", 12, -2)
    orderFrame.itemNameText = itemNameText

    local qtyText = orderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qtyText:SetPoint("TOPLEFT", itemNameText, "BOTTOMLEFT", 0, -4)
    qtyText:SetTextColor(0.85, 0.85, 0.85)
    orderFrame.qtyText = qtyText

    local buyerStatusText = orderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    buyerStatusText:SetPoint("TOPLEFT", 18, -118)
    buyerStatusText:SetPoint("TOPRIGHT", -18, -118)
    buyerStatusText:SetJustifyH("LEFT")
    buyerStatusText:SetWordWrap(false)
    orderFrame.buyerStatusText = buyerStatusText

    local line2 = orderFrame:CreateTexture(nil, "ARTWORK")
    line2:SetPoint("TOPLEFT", 14, -138)
    line2:SetPoint("TOPRIGHT", -14, -138)
    line2:SetHeight(1)
    line2:SetColorTexture(0.5, 0.5, 0.5, 0.3)

    local matsHeader = orderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    matsHeader:SetPoint("TOPLEFT", 18, -146)
    matsHeader:SetText(L["ORDER_MATS_HEADER"])
    orderFrame.matsHeader = matsHeader

    local scrollFrame = CreateFrame("ScrollFrame", "YellowPagesOrderMatsScroll", orderFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 14, -168)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 54)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(500, 10)
    scrollFrame:SetScrollChild(scrollChild)
    orderFrame.scrollChild = scrollChild

    -- Untere Button-Leiste: 4 Direkt-Antwort-Buttons
    local btnAll = Theme:CreateButton(orderFrame, 122, 26, L["BTN_REPLY_HAVE_ALL"])
    btnAll:SetPoint("BOTTOMLEFT", 14, 14)
    AttachButtonTooltip(btnAll, L["BTN_REPLY_HAVE_ALL"], L["TT_REPLY_HAVE_ALL"])
    orderFrame.btnAll = btnAll

    local btnMissing = Theme:CreateButton(orderFrame, 134, 26, L["BTN_REPLY_MISSING"])
    btnMissing:SetPoint("LEFT", btnAll, "RIGHT", 6, 0)
    AttachButtonTooltip(btnMissing, L["BTN_REPLY_MISSING"], L["TT_REPLY_MISSING"])
    orderFrame.btnMissing = btnMissing

    local btnBringAll = Theme:CreateButton(orderFrame, 136, 26, L["BTN_REPLY_BRING_ALL"])
    btnBringAll:SetPoint("LEFT", btnMissing, "RIGHT", 6, 0)
    AttachButtonTooltip(btnBringAll, L["BTN_REPLY_BRING_ALL"], L["TT_REPLY_BRING_ALL"])
    orderFrame.btnBringAll = btnBringAll

    local btnBusy = Theme:CreateButton(orderFrame, 122, 26, L["BTN_REPLY_BUSY"])
    btnBusy:SetPoint("LEFT", btnBringAll, "RIGHT", 6, 0)
    AttachButtonTooltip(btnBusy, L["BTN_REPLY_BUSY"], L["TT_REPLY_BUSY"])
    orderFrame.btnBusy = btnBusy

    return orderFrame
end

function YellowPages:ShowCraftOrder(buyerName, recipeID, count, buyerHaveMap, isSelfView)
    local f = self:CreateOrderFrame()
    count = count or 1

    local recipe = self:GetRecipeInfo(recipeID)
    if not recipe then
        self:Print(string.format(L["MSG_RECIPE_NOT_FOUND"], tostring(recipeID)))
        return
    end

    local cleanBuyer = self:StripRealm(buyerName) or buyerName or self:GetPlayerFullName("player")

    if not buyerHaveMap and not isSelfView and self.IncomingOrders then
        local cached = self.IncomingOrders[cleanBuyer .. "_" .. tostring(recipeID)] or self.IncomingOrders[recipeID]
        if cached and cached.buyerHaveMap then
            buyerHaveMap = cached.buyerHaveMap
        end
    end

    local quality = self:ResolveRecipeMetadata(recipe)

    activeOrder = {
        buyer = cleanBuyer,
        recipeID = recipeID,
        recipe = recipe,
        count = count,
    }

    f.buyerText:SetText(string.format(L["ORDER_REQUESTER_FMT"], activeOrder.buyer))
    f.itemIcon:SetTexture(recipe.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    f.itemNameText:SetText(Theme:GetQualityColoredText(recipe.name, quality))
    f.qtyText:SetText(string.format(L["ORDER_QTY_FMT"], count))

    local scrollChild = f.scrollChild
    scrollChild.rows = scrollChild.rows or {}
    for _, r in ipairs(scrollChild.rows) do r:Hide() end

    local yOffset = 0
    local fullMatsList = {}
    local buyerMissingList = {}
    local stillToBuyList = {}
    local stillToBuyMap = {}
    local anyBuyerMissing = false

    if recipe.reagents then
        for idx, r in ipairs(recipe.reagents) do
            local needed = (r.count or 1) * count
            local inBags = self:GetBagItemCount(r.itemID)
            local inBank = self:GetBankItemCount(r.itemID)
            local crafterTotal = inBags + inBank

            local row = scrollChild.rows[idx]
            if not row then
                row = CreateFrame("Frame", nil, scrollChild)
                row:SetSize(495, 26)
                row:EnableMouse(true)

                local icon = row:CreateTexture(nil, "ARTWORK")
                icon:SetSize(20, 20)
                icon:SetPoint("LEFT", 0, 0)
                row.icon = icon

                local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
                nameText:SetPoint("RIGHT", -280, 0)
                nameText:SetJustifyH("LEFT")
                nameText:SetWordWrap(false)
                row.nameText = nameText

                local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                statusText:SetPoint("RIGHT", -4, 0)
                statusText:SetJustifyH("RIGHT")
                row.statusText = statusText

                row:SetScript("OnEnter", function(self)
                    if self.itemID and self.itemID > 0 then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetItemByID(self.itemID)
                        GameTooltip:Show()
                    end
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)

                scrollChild.rows[idx] = row
            end

            local rName = r.name
            if (not rName or rName == "" or rName:find("^Item #")) and r.itemID and r.itemID > 0 then
                rName = self:GetItemNameSafe(r.itemID)
            end
            local rIcon = r.icon
            if (not rIcon or rIcon == "" or tostring(rIcon):find("QuestionMark")) and r.itemID and r.itemID > 0 then
                rIcon = self:GetItemIconSafe(r.itemID)
            end

            local cleanMatName = rName or L["REAGENT_FALLBACK"]
            table.insert(fullMatsList, string.format("%dx %s", needed, cleanMatName))

            row:SetPoint("TOPLEFT", 0, yOffset)
            row.itemID = r.itemID
            row.icon:SetTexture(rIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.nameText:SetText(string.format("%s |cffffd100x%d|r", cleanMatName, needed))

            if isSelfView or not buyerHaveMap then
                if crafterTotal >= needed then
                    row.statusText:SetText(
                        "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t " ..
                        string.format(L["ORDER_ROW_SELF_OK"], crafterTotal, needed, inBags, inBank)
                    )
                else
                    local miss = needed - crafterTotal
                    anyBuyerMissing = true
                    if r.itemID and r.itemID > 0 then stillToBuyMap[r.itemID] = miss end
                    table.insert(buyerMissingList, string.format("%dx %s", miss, cleanMatName))
                    table.insert(stillToBuyList, string.format("%dx %s", miss, cleanMatName))
                    row.statusText:SetText(
                        "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14:0:0|t " ..
                        string.format(L["ORDER_ROW_SELF_MISS"], miss, inBags, inBank)
                    )
                end
            else
                local buyerHave = buyerHaveMap[r.itemID] or 0
                local buyerMiss = math.max(0, needed - buyerHave)

                if buyerMiss == 0 then
                    row.statusText:SetText(
                        "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t " ..
                        string.format(L["ORDER_ROW_BUYER_OK"], buyerHave, needed, inBags, inBank)
                    )
                else
                    anyBuyerMissing = true
                    table.insert(buyerMissingList, string.format("%dx %s", buyerMiss, cleanMatName))

                    if crafterTotal >= buyerMiss then
                        row.statusText:SetText(
                            "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t " ..
                            string.format(L["ORDER_ROW_CRAFTER_COVERS"], buyerMiss, crafterTotal, inBags, inBank)
                        )
                    else
                        local stillToBuy = buyerMiss - crafterTotal
                        if r.itemID and r.itemID > 0 then stillToBuyMap[r.itemID] = stillToBuy end
                        table.insert(stillToBuyList, string.format("%dx %s", stillToBuy, cleanMatName))
                        row.statusText:SetText(
                            "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14:0:0|t " ..
                            string.format(L["ORDER_ROW_STILL_MISSING"], buyerMiss, crafterTotal, inBags, inBank, stillToBuy)
                        )
                    end
                end
            end

            row:Show()
            yOffset = yOffset - 28
        end
    end

    if not anyBuyerMissing then
        f.buyerStatusText:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t " .. L["ORDER_BUYER_ALL_MATS"])
    else
        f.buyerStatusText:SetText("|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14:0:0|t " .. L["ORDER_BUYER_MISSING_HDR"] .. " " .. table.concat(buyerMissingList, ", "))
    end

    scrollChild:SetHeight(math.max(10, math.abs(yOffset)))

    local itemLinkOrName = (recipe.itemLink and recipe.itemLink ~= "") and recipe.itemLink or recipe.name

    -- 1. Antwort: "Alle Mats da!" (enthält [YPC:recipeID:count:ALL] Link zum Bestätigen)
    f.btnAll:SetScript("OnClick", function()
        if YellowPages.SendCrafterOffer then
            YellowPages:SendCrafterOffer(activeOrder.buyer, activeOrder.recipeID, activeOrder.count, "ALL", {})
        end
        local reply = string.format(L["WHISPER_REPLY_ALL_READY"], activeOrder.buyer, itemLinkOrName, activeOrder.count, activeOrder.recipeID, activeOrder.count)
        YellowPages:SendSafeWhisper(reply, activeOrder.buyer)
        YellowPages:Print(string.format(L["MSG_REPLY_SENT_ALL"], activeOrder.buyer))
        f:Hide()
    end)

    -- 2. Antwort: "Rest-Mats anfordern" (enthält [YPC:recipeID:count:REM] Link zum Bestätigen)
    f.btnMissing:SetScript("OnClick", function()
        if YellowPages.SendCrafterOffer then
            YellowPages:SendCrafterOffer(activeOrder.buyer, activeOrder.recipeID, activeOrder.count, "REM", stillToBuyMap)
        end
        local listToUse = (#stillToBuyList > 0) and stillToBuyList or (#buyerMissingList > 0 and buyerMissingList) or fullMatsList
        local missingStr = (#listToUse > 0) and table.concat(listToUse, ", ") or L["UNKNOWN"]
        local reply = string.format(L["WHISPER_REPLY_NEED_MATS"], activeOrder.buyer, itemLinkOrName, activeOrder.count, missingStr, activeOrder.recipeID, activeOrder.count)
        YellowPages:SendSafeWhisper(reply, activeOrder.buyer)
        YellowPages:Print(string.format(L["MSG_REPLY_SENT_MISSING"], activeOrder.buyer, missingStr))
        f:Hide()
    end)

    -- 3. Antwort: "Alle Mats anfordern" (enthält [YPC:recipeID:count:BRING] Link zum Bestätigen)
    f.btnBringAll:SetScript("OnClick", function()
        if YellowPages.SendCrafterOffer then
            YellowPages:SendCrafterOffer(activeOrder.buyer, activeOrder.recipeID, activeOrder.count, "BRING", {})
        end
        local reply
        local infoStr
        if #buyerMissingList > 0 then
            infoStr = table.concat(buyerMissingList, ", ")
            reply = string.format(L["WHISPER_REPLY_BRING_ALL"], activeOrder.buyer, itemLinkOrName, activeOrder.count, infoStr, activeOrder.recipeID, activeOrder.count)
        else
            infoStr = (#fullMatsList > 0) and table.concat(fullMatsList, ", ") or L["UNKNOWN"]
            reply = string.format(L["WHISPER_REPLY_BRING_FULL"], activeOrder.buyer, itemLinkOrName, activeOrder.count, infoStr, activeOrder.recipeID, activeOrder.count)
        end
        YellowPages:SendSafeWhisper(reply, activeOrder.buyer)
        YellowPages:Print(string.format(L["MSG_REPLY_SENT_BRING_ALL"], activeOrder.buyer, infoStr))
        f:Hide()
    end)

    -- 4. Antwort: "Gerade keine Zeit"
    f.btnBusy:SetScript("OnClick", function()
        local reply = string.format(L["WHISPER_REPLY_BUSY"], activeOrder.buyer)
        YellowPages:SendSafeWhisper(reply, activeOrder.buyer)
        YellowPages:Print(string.format(L["MSG_REPLY_SENT_BUSY"], activeOrder.buyer))
        f:Hide()
    end)

    f:Show()
end

function YellowPages:OpenOrderFromChatLink(buyerName, recipeID, count)
    local cleanBuyer = self:StripRealm(buyerName) or buyerName or self:GetPlayerFullName("player")
    local cached = self.IncomingOrders and (self.IncomingOrders[cleanBuyer .. "_" .. tostring(recipeID)] or self.IncomingOrders[recipeID])
    local buyerHaveMap = cached and cached.buyerHaveMap or nil
    self:ShowCraftOrder(cleanBuyer, recipeID, count or (cached and cached.count) or 1, buyerHaveMap, false)
end

function YellowPages:OpenOrderForRecipe(recipeID)
    local cached = self.IncomingOrders and self.IncomingOrders[recipeID]
    if cached then
        self:ShowCraftOrder(cached.buyer, recipeID, cached.count or 1, cached.buyerHaveMap, false)
    else
        local playerName = self:GetPlayerFullName("player")
        self:ShowCraftOrder(playerName, recipeID, 1, nil, true)
    end
end

-- ============================================================================
-- 2. AUFTRAGSLISTE DES HANDWERKERS (Confirmed Crafting Order Queue)
-- ============================================================================

function YellowPages:GetActiveOrderCount()
    if not YellowPagesCharDB or not YellowPagesCharDB.orderQueue then return 0 end
    local openCount = 0
    for _, o in ipairs(YellowPagesCharDB.orderQueue) do
        if not o.done then
            openCount = openCount + 1
        end
    end
    return openCount, #YellowPagesCharDB.orderQueue
end

function YellowPages:CreateOrderQueueFrame()
    if queueFrame then return queueFrame end

    queueFrame = CreateFrame("Frame", "YellowPagesOrderQueueFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    queueFrame:SetSize(480, 380)
    queueFrame:SetPoint("CENTER", 0, 20)
    queueFrame:SetFrameStrata("DIALOG")
    queueFrame:EnableMouse(true)
    queueFrame:SetMovable(true)
    queueFrame:RegisterForDrag("LeftButton")
    queueFrame:SetScript("OnDragStart", queueFrame.StartMoving)
    queueFrame:SetScript("OnDragStop", queueFrame.StopMovingOrSizing)
    queueFrame:SetClampedToScreen(true)

    Theme:ApplyBackdrop(queueFrame, nil, nil, nil, nil, nil, nil, nil, nil, true)

    local title = queueFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -14)
    title:SetText(L["QUEUE_WINDOW_TITLE"])

    local sub = queueFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", 18, -34)
    sub:SetText(L["QUEUE_SUBTITLE"])

    local closeBtn = CreateFrame("Button", nil, queueFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function() queueFrame:Hide() end)

    local line = queueFrame:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 14, -52)
    line:SetPoint("TOPRIGHT", -14, -52)
    line:SetHeight(1)
    line:SetColorTexture(0.8, 0.65, 0.2, 0.4)

    local scrollFrame = CreateFrame("ScrollFrame", "YellowPagesQueueScroll", queueFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 14, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 48)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(430, 10)
    scrollFrame:SetScrollChild(scrollChild)
    queueFrame.scrollChild = scrollChild

    local emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", 0, -40)
    emptyText:SetText(L["QUEUE_EMPTY"])
    queueFrame.emptyText = emptyText

    local btnClearDone = Theme:CreateButton(queueFrame, 160, 26, L["BTN_CLEAR_DONE"])
    btnClearDone:SetPoint("BOTTOMLEFT", 14, 12)
    btnClearDone:SetScript("OnClick", function()
        if not YellowPagesCharDB or not YellowPagesCharDB.orderQueue then return end
        local kept = {}
        for _, o in ipairs(YellowPagesCharDB.orderQueue) do
            if not o.done then
                table.insert(kept, o)
            end
        end
        YellowPagesCharDB.orderQueue = kept
        YellowPages:RefreshOrderQueueUI()
        if YellowPages.RefreshUI then YellowPages:RefreshUI() end
    end)

    local btnClose = Theme:CreateButton(queueFrame, 110, 26, L["BTN_CLOSE"])
    btnClose:SetPoint("BOTTOMRIGHT", -14, 12)
    btnClose:SetScript("OnClick", function() queueFrame:Hide() end)

    queueFrame:Hide()
    return queueFrame
end

function YellowPages:RefreshOrderQueueUI()
    if not queueFrame then return end
    local scrollChild = queueFrame.scrollChild
    scrollChild.rows = scrollChild.rows or {}
    for _, r in ipairs(scrollChild.rows) do r:Hide() end

    local list = (YellowPagesCharDB and YellowPagesCharDB.orderQueue) or {}
    queueFrame.emptyText:SetShown(#list == 0)

    local yOffset = 0
    for idx, order in ipairs(list) do
        local row = scrollChild.rows[idx]
        if not row then
            row = CreateFrame("Frame", nil, scrollChild, BackdropTemplateMixin and "BackdropTemplate")
            row:SetSize(430, 42)
            Theme:ApplyBackdrop(row, 0.14, 0.10, 0.068, 0.9, 0.55, 0.42, 0.25, 0.7)

            -- Checkbox zum Abhaken / Umschalten
            local checkBtn = CreateFrame("Button", nil, row)
            checkBtn:SetSize(22, 22)
            checkBtn:SetPoint("LEFT", 8, 0)
            local checkTex = checkBtn:CreateTexture(nil, "ARTWORK")
            checkTex:SetAllPoints()
            row.checkBtn = checkBtn
            row.checkTex = checkTex
            AttachButtonTooltip(checkBtn, L["TT_TOGGLE_DONE"])

            -- Rezept-Icon
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(28, 28)
            icon:SetPoint("LEFT", checkBtn, "RIGHT", 6, 0)
            row.icon = icon

            -- Name & Menge
            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
            nameText:SetPoint("RIGHT", -135, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetWordWrap(false)
            row.nameText = nameText

            -- Auftraggeber
            local buyerText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            buyerText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 1)
            row.buyerText = buyerText

            -- Status (Offen 0/1 vs. Erledigt 1/1)
            local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            statusText:SetPoint("RIGHT", -38, 0)
            row.statusText = statusText

            -- Löschen-Button [X]
            local delBtn = Theme:CreateButton(row, 24, 22, "X")
            delBtn:SetPoint("RIGHT", -8, 0)
            AttachButtonTooltip(delBtn, L["TT_DELETE_ORDER"])
            row.delBtn = delBtn

            scrollChild.rows[idx] = row
        end

        row:SetPoint("TOPLEFT", 0, yOffset)
        row.icon:SetTexture(order.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        local rec = self:GetRecipeInfo(order.recipeID)
        local quality = rec and self:ResolveRecipeMetadata(rec) or 1
        local coloredName = Theme:GetQualityColoredText(order.name or L["RECIPE_FALLBACK"], quality)

        if order.done then
            row.checkTex:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            row.nameText:SetText(string.format("|cff888888%s x%d|r", order.name or "", order.count or 1))
            row.statusText:SetText(string.format(L["QUEUE_STATUS_DONE"], order.count or 1, order.count or 1))
        else
            row.checkTex:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
            row.nameText:SetText(string.format("%s |cffffd100x%d|r", coloredName, order.count or 1))
            row.statusText:SetText(string.format(L["QUEUE_STATUS_OPEN"], order.craftedCount or 0, order.count or 1))
        end

        row.buyerText:SetText(string.format(L["QUEUE_FOR_BUYER"], order.buyer or L["UNKNOWN"]))

        row.checkBtn:SetScript("OnClick", function()
            order.done = not order.done
            if order.done then
                order.craftedCount = order.count or 1
            else
                order.craftedCount = 0
            end
            YellowPages:RefreshOrderQueueUI()
            if YellowPages.RefreshUI then YellowPages:RefreshUI() end
        end)

        row.delBtn:SetScript("OnClick", function()
            table.remove(YellowPagesCharDB.orderQueue, idx)
            YellowPages:RefreshOrderQueueUI()
            if YellowPages.RefreshUI then YellowPages:RefreshUI() end
        end)

        row:Show()
        yOffset = yOffset - 46
    end

    scrollChild:SetHeight(math.max(10, math.abs(yOffset)))
end

function YellowPages:ToggleOrderQueueUI()
    local f = self:CreateOrderQueueFrame()
    if f:IsShown() then
        f:Hide()
    else
        self:RefreshOrderQueueUI()
        f:Show()
    end
end

-- ============================================================================
-- 3. EINKAUFSLISTE & AUKTIONSHAUS-POP-UP (Requester's AH Shopping List)
-- ============================================================================

local shoppingFrame = nil

function YellowPages:CreateShoppingListFrame()
    if shoppingFrame then return shoppingFrame end

    shoppingFrame = CreateFrame("Frame", "YellowPagesShoppingFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    shoppingFrame:SetSize(350, 320)
    shoppingFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -140)
    shoppingFrame:SetFrameStrata("DIALOG")
    shoppingFrame:EnableMouse(true)
    shoppingFrame:SetMovable(true)
    shoppingFrame:RegisterForDrag("LeftButton")
    shoppingFrame:SetScript("OnDragStart", function(self)
        self.userMoved = true
        self:StartMoving()
    end)
    shoppingFrame:SetScript("OnDragStop", shoppingFrame.StopMovingOrSizing)
    shoppingFrame:SetClampedToScreen(true)

    Theme:ApplyBackdrop(shoppingFrame, nil, nil, nil, nil, nil, nil, nil, nil, true)

    local title = shoppingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText(L["SHOP_WINDOW_TITLE"])

    local sub = shoppingFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", 14, -30)
    sub:SetPoint("TOPRIGHT", -32, -30)
    sub:SetJustifyH("LEFT")
    sub:SetText(L["SHOP_SUBTITLE"])

    local closeBtn = CreateFrame("Button", nil, shoppingFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() shoppingFrame:Hide() end)

    local line = shoppingFrame:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 10, -48)
    line:SetPoint("TOPRIGHT", -10, -48)
    line:SetHeight(1)
    line:SetColorTexture(0.8, 0.65, 0.2, 0.4)

    local scrollFrame = CreateFrame("ScrollFrame", "YellowPagesShoppingScroll", shoppingFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -54)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 44)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(305, 10)
    scrollFrame:SetScrollChild(scrollChild)
    shoppingFrame.scrollChild = scrollChild

    local emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOP", 0, -35)
    emptyText:SetText(L["SHOP_EMPTY"])
    shoppingFrame.emptyText = emptyText

    local btnClearBought = Theme:CreateButton(shoppingFrame, 155, 24, L["BTN_SHOP_CLEAR_BOUGHT"])
    btnClearBought:SetPoint("BOTTOMLEFT", 12, 10)
    btnClearBought:SetScript("OnClick", function()
        if not YellowPagesCharDB or not YellowPagesCharDB.shoppingList then return end
        local kept = {}
        for _, item in ipairs(YellowPagesCharDB.shoppingList) do
            local owned = YellowPages:GetTotalItemCount(item.itemID)
            local target = item.targetOwned or item.toBuy or 1
            if owned < target then
                table.insert(kept, item)
            end
        end
        YellowPagesCharDB.shoppingList = kept
        YellowPages:RefreshShoppingListUI()
        if YellowPages.RefreshUI then YellowPages:RefreshUI() end
    end)

    local btnClearAll = Theme:CreateButton(shoppingFrame, 155, 24, L["BTN_SHOP_CLEAR_ALL"])
    btnClearAll:SetPoint("BOTTOMRIGHT", -12, 10)
    btnClearAll:SetScript("OnClick", function()
        if YellowPagesCharDB then
            YellowPagesCharDB.shoppingList = {}
        end
        YellowPages:RefreshShoppingListUI()
        if YellowPages.RefreshUI then YellowPages:RefreshUI() end
    end)

    shoppingFrame:Hide()
    return shoppingFrame
end

function YellowPages:RefreshShoppingListUI()
    if not shoppingFrame then return end
    local scrollChild = shoppingFrame.scrollChild
    scrollChild.rows = scrollChild.rows or {}
    for _, r in ipairs(scrollChild.rows) do r:Hide() end

    local list = (YellowPagesCharDB and YellowPagesCharDB.shoppingList) or {}
    shoppingFrame.emptyText:SetShown(#list == 0)

    local yOffset = 0
    for idx, entry in ipairs(list) do
        local row = scrollChild.rows[idx]
        if not row then
            row = CreateFrame("Button", nil, scrollChild, BackdropTemplateMixin and "BackdropTemplate")
            row:SetSize(304, 34)
            Theme:ApplyBackdrop(row, 0.14, 0.10, 0.068, 0.9, 0.55, 0.42, 0.25, 0.7)

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 0.82, 0.2, 0.18)

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(24, 24)
            icon:SetPoint("LEFT", 6, 0)
            row.icon = icon

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
            nameText:SetPoint("RIGHT", -90, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetWordWrap(false)
            row.nameText = nameText

            local countText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            countText:SetPoint("RIGHT", -32, 0)
            countText:SetJustifyH("RIGHT")
            row.countText = countText

            local delBtn = Theme:CreateButton(row, 22, 20, "X")
            delBtn:SetPoint("RIGHT", -5, 0)
            row.delBtn = delBtn

            scrollChild.rows[idx] = row
        end

        local itemID = entry.itemID
        local itemName = (itemID and itemID > 0 and self:GetItemNameSafe(itemID)) or entry.name or L["REAGENT_FALLBACK"]
        local itemIcon = (itemID and itemID > 0 and self:GetItemIconSafe(itemID)) or entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"

        local ownedNow = self:GetTotalItemCount(itemID)
        local targetOwned = entry.targetOwned or entry.toBuy or 1
        local remainingToBuy = math.max(0, targetOwned - ownedNow)

        local isVendor = self:IsVendorReagent(itemID)
        local srcTag = isVendor and L["TAG_VENDOR"] or L["TAG_AH"]

        row:SetPoint("TOPLEFT", 0, yOffset)
        row.icon:SetTexture(itemIcon)
        row.nameText:SetText(itemName .. " " .. srcTag)

        if remainingToBuy == 0 then
            row.countText:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t |cff33e633OK|r")
        else
            row.countText:SetText(string.format("|cffffd100x%d|r", remainingToBuy))
        end

        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if itemID and itemID > 0 then
                GameTooltip:SetItemByID(itemID)
                GameTooltip:AddLine(" ")
            end
            GameTooltip:AddLine(string.format(L["SHOP_CLICK_TO_SEARCH"], itemName), 0.2, 1.0, 0.2, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Klick auf das Material überträgt den Namen in die AH-Suche ODER kauft direkt beim geöffneten Händler!
        row:SetScript("OnClick", function()
            YellowPages:SearchItemInAuctionHouse(itemID, itemName, remainingToBuy)
        end)

        row.delBtn:SetScript("OnClick", function()
            table.remove(YellowPagesCharDB.shoppingList, idx)
            YellowPages:RefreshShoppingListUI()
            if YellowPages.RefreshUI then YellowPages:RefreshUI() end
        end)

        row:Show()
        yOffset = yOffset - 36
    end

    scrollChild:SetHeight(math.max(10, math.abs(yOffset)))
end

function YellowPages:ShowShoppingListPopup(isAutoOpen)
    local f = self:CreateShoppingListFrame()
    self:RefreshShoppingListUI()

    -- Wenn automatisch am Auktionshaus oder beim Händler geöffnet: direkt rechts daneben andocken!
    if isAutoOpen and not f.userMoved then
        local ah = AuctionHouseFrame or AuctionFrame
        if ah and ah.IsShown and ah:IsShown() then
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", ah, "TOPRIGHT", 8, 0)
        elseif MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown() then
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 8, -12)
        end
    end

    f.openedByAH = isAutoOpen or false
    f:Show()
    f:Raise()
end

function YellowPages:HideShoppingListOnAHClose()
    if shoppingFrame and shoppingFrame:IsShown() and shoppingFrame.openedByAH then
        shoppingFrame:Hide()
    end
end

function YellowPages:ToggleShoppingListUI()
    local f = self:CreateShoppingListFrame()
    if f:IsShown() then
        f:Hide()
    else
        self:RefreshShoppingListUI()
        f.openedByAH = false
        f:Show()
        f:Raise()
    end
end
