--[[
    Yellow-Pages: Init.lua
    Haupt-Initialisierung, Events, Chat-Hyperlinks (Anfrage & Bestätigung),
    WoW-Forever Nachnamen-Unterstützung, Auftragsliste & Auktionshaus-Einkaufsliste
--]]

YellowPages = YellowPages or {}
local L = YellowPages.L
YellowPages.Title = "|cffffd100Yellow-Pages|r"
YellowPages.Version = "1.0.10"
YellowPages.AddonPrefix = "YELLOWPAGES"
YellowPages.IncomingOrders = YellowPages.IncomingOrders or {}
YellowPages.IncomingOffers = YellowPages.IncomingOffers or {}

local DEFAULT_GLOBAL_DB = {
    guildName = nil,
    members = {},
    recipes = {},
    pendingOfflineOrders = {}, -- Gilden-Relais (Store & Forward) für Offline-Handwerker
    settings = {
        minimapPos = 195,
        showMinimap = true,
        autoScan = true,
        announceOrders = true,
        priceSource = "AUTO",
    }
}

local DEFAULT_CHAR_DB = {
    fullName = nil,
    bankCache = {},
    lastBankUpdate = 0,
    myProfessions = {},
    orderQueue = {},           -- Bestätigte Aufträge für den Handwerker
    shoppingList = {},         -- Einkaufsliste für den Auftraggeber (öffnet sich am AH & beim Händler)
    deliveredOfflineIDs = {},  -- Bereits zugestellte Offline-Anfragen (Deduplizierung)
}

local function RegisterAddonPrefixSafe()
    local prefix = YellowPages.AddonPrefix
    if C_ChatInfo and C_ChatInfo.RegisterAddonPrefix then
        pcall(C_ChatInfo.RegisterAddonPrefix, prefix)
    elseif RegisterAddonMessagePrefix then
        pcall(RegisterAddonMessagePrefix, prefix)
    end
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, prefix)
    end
end
RegisterAddonPrefixSafe()

if not C_Timer then C_Timer = {} end
if not C_Timer.After then
    C_Timer.After = function(seconds, func)
        local f = CreateFrame("Frame")
        local elapsed = 0
        f:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed >= seconds then
                self:SetScript("OnUpdate", nil)
                func()
            end
        end)
    end
end

function YellowPages:SafeRegisterEvent(frame, eventName)
    if frame and eventName then
        pcall(frame.RegisterEvent, frame, eventName)
    end
end

function YellowPages:StripRealm(name)
    if not name or name == "" then return nil end
    local base = (name:match("^(.-)%-[^%-]+$") or name):gsub("^%s+", ""):gsub("%s+$", "")
    return base ~= "" and base or nil
end

function YellowPages:LearnOwnFullName(fullName)
    local cleanFull = self:StripRealm(fullName)
    if not cleanFull or cleanFull == "" then return end

    YellowPagesCharDB = YellowPagesCharDB or {}
    local firstOnly = UnitName("player")
    if firstOnly and cleanFull == firstOnly and YellowPagesCharDB.fullName and YellowPagesCharDB.fullName:find(" ") then
        return
    end

    YellowPagesCharDB.fullName = cleanFull

    if self.RepairAndConsolidateSelfData then
        self:RepairAndConsolidateSelfData()
    end
end

function YellowPages:GetPlayerFullName(unit)
    unit = unit or "player"
    if unit == "player" then
        if YellowPagesCharDB and YellowPagesCharDB.fullName and YellowPagesCharDB.fullName ~= "" then
            return YellowPagesCharDB.fullName
        end
        if type(OneForAllCharDB) == "table" and OneForAllCharDB.fullName and OneForAllCharDB.fullName ~= "" then
            local full = self:StripRealm(OneForAllCharDB.fullName)
            if full then
                if YellowPagesCharDB then YellowPagesCharDB.fullName = full end
                return full
            end
        end
    end
    local name = UnitName(unit)
    return self:StripRealm(name) or L["UNKNOWN"]
end

function YellowPages:GetItemInfoSafe(itemIDOrLink)
    if not itemIDOrLink then return nil end
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(itemIDOrLink)
    elseif GetItemInfo then
        return GetItemInfo(itemIDOrLink)
    end
    return nil
end

function YellowPages:GetItemIconSafe(itemID)
    if not itemID or itemID == 0 then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    if C_Item and C_Item.GetItemIconByID then
        local icon = C_Item.GetItemIconByID(itemID)
        if icon then return icon end
    end
    if GetItemIcon then
        local icon = GetItemIcon(itemID)
        if icon then return icon end
    end
    local _, _, _, _, _, _, _, _, _, tex = self:GetItemInfoSafe(itemID)
    return tex or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function YellowPages:GetItemNameSafe(itemID)
    if not itemID or itemID == 0 then return nil end
    if C_Item and C_Item.GetItemNameByID then
        local name = C_Item.GetItemNameByID(itemID)
        if name and name ~= "" then return name end
    end
    local name = self:GetItemInfoSafe(itemID)
    if name and name ~= "" then return name end
    if self.VendorReagents and self.VendorReagents[itemID] and self.VendorReagents[itemID].name then
        return self.VendorReagents[itemID].name
    end
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
    return "Item #" .. tostring(itemID)
end

local YP_CHAT_TAB_NAME = "YP-Chat"

function YellowPages:FindYPChatFrame()
    local maxWin = NUM_CHAT_WINDOWS or 10
    for i = 1, maxWin do
        local name = GetChatWindowInfo and GetChatWindowInfo(i)
        if name == YP_CHAT_TAB_NAME then
            return _G["ChatFrame" .. i]
        end
    end
    return nil
end

function YellowPages:FlashYPChatTab(ypChat)
    ypChat = ypChat or self.ypChatFrame or self:FindYPChatFrame()
    if not ypChat or ypChat == DEFAULT_CHAT_FRAME then return end
    if SELECTED_CHAT_FRAME == ypChat then return end

    if FCF_StartAlertFlash then
        pcall(FCF_StartAlertFlash, ypChat)
    else
        local tab = _G[ypChat:GetName() .. "Tab"]
        local flash = tab and (tab.glow or _G[tab:GetName() .. "Flash"])
        if flash and UIFrameFlash then
            pcall(UIFrameFlash, flash, 0.5, 0.5, 10, false, 0, 0)
        end
    end
end

function YellowPages:EnsureYPChatTab()
    local cf = self:FindYPChatFrame()
    if not cf and FCF_OpenNewWindow then
        local ok, newFrame = pcall(FCF_OpenNewWindow, YP_CHAT_TAB_NAME)
        if ok and newFrame then
            cf = newFrame
        end
    end
    if cf then
        -- Nur Yellow-Pages-Meldungen & gefilterte Auftrags-Whispers (keine normalen Privat-Whispers!)
        if ChatFrame_RemoveAllMessageGroups then pcall(ChatFrame_RemoveAllMessageGroups, cf) end
        if ChatFrame_RemoveAllChannels then pcall(ChatFrame_RemoveAllChannels, cf) end
        self.ypChatFrame = cf
        return cf
    end
    return nil
end

function YellowPages:Print(msg, shouldFlash)
    local formatted = string.format("%s: %s", self.Title, tostring(msg))
    DEFAULT_CHAT_FRAME:AddMessage(formatted)
    local ypChat = self.ypChatFrame or self:FindYPChatFrame()
    if ypChat and ypChat ~= DEFAULT_CHAT_FRAME then
        ypChat:AddMessage(formatted)
        if shouldFlash then
            self:FlashYPChatTab(ypChat)
        end
    end
end

-- Erzeugt einen klickbaren Chat-Link für eine Handwerker-Anfrage ([Yellow-Pages: Anfrage öffnen])
function YellowPages:FormatOrderChatLink(recipeID, count, buyerName)
    recipeID = tonumber(recipeID) or 0
    count = tonumber(count) or 1
    buyerName = self:StripRealm(buyerName) or self:GetPlayerFullName("player")
    local label = string.format(L["CHAT_LINK_OPEN_ORDER"], recipeID)
    return string.format("|cffffd100|Haddon:YP:%d:%d:%s|h%s|h|r", recipeID, count, buyerName, label)
end

-- Erzeugt einen klickbaren Chat-Link zur Auftrags-Bestätigung ([Yellow-Pages: Auftrag bestätigen])
function YellowPages:FormatConfirmChatLink(recipeID, count, mode, crafterName)
    recipeID = tonumber(recipeID) or 0
    count = tonumber(count) or 1
    mode = (mode and mode ~= "") and mode or "BRING"
    crafterName = self:StripRealm(crafterName) or self:GetPlayerFullName("player")
    local label = L["CHAT_LINK_CONFIRM_ORDER"]
    return string.format("|cff00ff00|Haddon:YPC:%d:%d:%s:%s|h%s|h|r", recipeID, count, mode, crafterName, label)
end

local function FormatYPWhisperText(msg, cleanAuthor)
    local out = msg:gsub("%[YP:(%d+):(%d+)%]", function(recIDStr, countStr)
        return YellowPages:FormatOrderChatLink(tonumber(recIDStr), tonumber(countStr), cleanAuthor)
    end)
    out = out:gsub("%[YPC:(%d+):(%d+):([%u]+)%]", function(recIDStr, countStr, modeStr)
        return YellowPages:FormatConfirmChatLink(tonumber(recIDStr), tonumber(countStr), modeStr, cleanAuthor)
    end)
    out = out:gsub("%[YPC:(%d+):(%d+)%]", function(recIDStr, countStr)
        return YellowPages:FormatConfirmChatLink(tonumber(recIDStr), tonumber(countStr), "BRING", cleanAuthor)
    end)
    return out
end

-- Chat-Filter: Wandelt [YP:recipeID:count] und [YPC:recipeID:count:MODE] in klickbare Links um
local function WhisperChatFilter(_, event, msg, author, ...)
    if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then
        return false
    end
    if not msg:find("[YP", 1, true) then
        return false
    end

    local cleanAuthor = YellowPages:StripRealm(author) or "Unknown"
    if event == "CHAT_MSG_WHISPER_INFORM" then
        cleanAuthor = YellowPages:GetPlayerFullName("player")
    end

    local ok, newMsg = pcall(FormatYPWhisperText, msg, cleanAuthor)
    if ok and newMsg and newMsg ~= msg then
        return false, newMsg, author, ...
    end
    return false
end

if ChatFrame_AddMessageEventFilter then
    pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_WHISPER", WhisperChatFilter)
    pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_WHISPER_INFORM", WhisperChatFilter)
end

-- Leitet ausschließlich Yellow-Pages-Whispers in den YP-Chat-Tab um und lässt den Tab bei Eingang blinken
local ypWhisperForwardFrame = CreateFrame("Frame")
pcall(ypWhisperForwardFrame.RegisterEvent, ypWhisperForwardFrame, "CHAT_MSG_WHISPER")
pcall(ypWhisperForwardFrame.RegisterEvent, ypWhisperForwardFrame, "CHAT_MSG_WHISPER_INFORM")
ypWhisperForwardFrame:SetScript("OnEvent", function(_, event, msg, author)
    if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return end
    local isYP = msg:find("[YellowPages]", 1, true) or msg:find("[YP:", 1, true) or msg:find("[YPC:", 1, true)
    if not isYP then return end

    local ypChat = YellowPages.ypChatFrame or YellowPages:FindYPChatFrame()
    if not ypChat or ypChat == DEFAULT_CHAT_FRAME then return end

    local cleanAuthor = YellowPages:StripRealm(author) or author or "?"
    local linkAuthor = (event == "CHAT_MSG_WHISPER_INFORM") and YellowPages:GetPlayerFullName("player") or cleanAuthor
    local ok, formatted = pcall(FormatYPWhisperText, msg, linkAuthor)
    local displayMsg = (ok and formatted) or msg

    local prefix = (event == "CHAT_MSG_WHISPER_INFORM")
        and ("|cffff80ff[An " .. cleanAuthor .. "]:|r ")
        or ("|cffff80ff[" .. cleanAuthor .. "] flüstert:|r ")

    ypChat:AddMessage(prefix .. displayMsg)
    if event == "CHAT_MSG_WHISPER" then
        YellowPages:FlashYPChatTab(ypChat)
    end
end)

function YellowPages:IsInGuild()
    if IsInGuild and IsInGuild() then
        return true
    end
    if GetGuildInfo then
        local gName = GetGuildInfo("player")
        if gName and gName ~= "" then
            return true
        end
    end
    return false
end

function YellowPages:GetGuildName()
    if GetGuildInfo then
        local gName = GetGuildInfo("player")
        if gName and gName ~= "" then
            return gName
        end
    end
    return nil
end

function YellowPages:FormatMoney(copper)
    if not copper or copper <= 0 then
        if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
            return "|cffb7a68b" .. C_CurrencyInfo.GetCoinTextureString(0, 11) .. "|r"
        end
        return "|cff9d9d9d0c|r"
    end
    copper = math.floor(copper + 0.5)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper, 11)
    end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100

    local str = ""
    if g > 0 then
        str = str .. string.format("|cffffd700%d|r|cffffd100g|r ", g)
    end
    if s > 0 or g > 0 then
        str = str .. string.format("|cffc7c7cf%d|r|cffc7c7cfs|r ", s)
    end
    str = str .. string.format("|cffeda55f%d|r|cffeda55fc|r", c)
    return str:gsub("%s+$", "")
end

-- ============================================================================
-- EINKAUFSLISTE & AUKTIONSHAUS-SUCHE (Shopping List for Requester)
-- ============================================================================

function YellowPages:AddMissingMatsToShoppingList(recipeID, count, mode)
    mode = mode or "BRING"
    if mode == "ALL" then
        -- Handwerker hat bereits alle (fehlenden) Materialien zugesagt -> nichts einzukaufen!
        return 0
    end

    local recipe = self:GetRecipeInfo(recipeID)
    if not recipe or not recipe.reagents then return 0 end

    YellowPagesCharDB = YellowPagesCharDB or {}
    YellowPagesCharDB.shoppingList = YellowPagesCharDB.shoppingList or {}

    local offerData = self.IncomingOffers and self.IncomingOffers[recipeID]
    local offerMap = (mode == "REM" and offerData and offerData.stillToBuyMap) or nil

    local addedTypes = 0

    for _, r in ipairs(recipe.reagents) do
        local itemID = r.itemID
        if itemID and itemID > 0 then
            local neededForRecipe = (r.count or 1) * (count or 1)
            local currentlyOwned = self:GetTotalItemCount(itemID)
            local missingCount = 0

            if offerMap and offerMap[itemID] ~= nil then
                missingCount = tonumber(offerMap[itemID]) or 0
            else
                missingCount = math.max(0, neededForRecipe - currentlyOwned)
            end

            if missingCount > 0 then
                local rName = self:GetItemNameSafe(itemID) or r.name or L["REAGENT_FALLBACK"]
                local rIcon = self:GetItemIconSafe(itemID) or r.icon or "Interface\\Icons\\INV_Misc_QuestionMark"

                local found = false
                for _, entry in ipairs(YellowPagesCharDB.shoppingList) do
                    if entry.itemID == itemID then
                        entry.toBuy = missingCount
                        entry.targetOwned = currentlyOwned + missingCount
                        entry.name = rName
                        entry.icon = rIcon
                        found = true
                        break
                    end
                end

                if not found then
                    table.insert(YellowPagesCharDB.shoppingList, {
                        itemID = itemID,
                        name = rName,
                        icon = rIcon,
                        toBuy = missingCount,
                        targetOwned = currentlyOwned + missingCount,
                    })
                end
                addedTypes = addedTypes + 1
            end
        end
    end

    if addedTypes > 0 then
        self:Print(string.format(L["MSG_SHOP_ADDED"], addedTypes))
        if self.RefreshShoppingListUI then self:RefreshShoppingListUI() end
        if self.RefreshUI then self:RefreshUI() end
    end

    return addedTypes
end

function YellowPages:GetShoppingListCount()
    if not YellowPagesCharDB or not YellowPagesCharDB.shoppingList then return 0 end
    local openCount = 0
    for _, item in ipairs(YellowPagesCharDB.shoppingList) do
        local owned = self:GetTotalItemCount(item.itemID)
        local target = item.targetOwned or item.toBuy or 1
        if owned < target then
            openCount = openCount + 1
        end
    end
    return openCount, #YellowPagesCharDB.shoppingList
end

function YellowPages:HasOpenShoppingItems()
    local openCount = self:GetShoppingListCount()
    return openCount > 0
end

-- Überträgt einen Materialnamen per Klick in die AH-Suche ODER kauft das Material direkt beim geöffneten Händler!
function YellowPages:SearchItemInAuctionHouse(itemID, itemName, remainingToBuy)
    local searchName = itemName
    if itemID and itemID > 0 then
        local localizedName = self:GetItemNameSafe(itemID)
        if localizedName and not localizedName:find("^Item #") then
            searchName = localizedName
        end
    end
    if not searchName or searchName == "" then return false end

    -- 1. Falls ein Händler (MerchantFrame) geöffnet ist: Prüfen, ob dieser das Material verkauft und direkt kaufen!
    if MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown() then
        local numMerchantItems = (GetMerchantNumItems and GetMerchantNumItems())
            or (type(C_MerchantFrame) == "table" and C_MerchantFrame.GetNumItems and C_MerchantFrame.GetNumItems()) or 0
        local buyFunc = BuyMerchantItem or (type(C_MerchantFrame) == "table" and C_MerchantFrame.BuyItem)

        if numMerchantItems > 0 and buyFunc then
            for i = 1, numMerchantItems do
                local mID = GetMerchantItemID and GetMerchantItemID(i)
                if not mID and GetMerchantItemLink then
                    local link = GetMerchantItemLink(i)
                    mID = link and tonumber(link:match("item:(%d+)"))
                end

                if mID and itemID and mID == itemID then
                    local qtyNeeded = math.max(1, tonumber(remainingToBuy) or 1)
                    local stackSize = 1
                    if type(C_MerchantFrame) == "table" and C_MerchantFrame.GetItemInfo then
                        local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
                        if ok and type(info) == "table" and info.stackCount then
                            stackSize = math.max(1, info.stackCount)
                        end
                    elseif GetMerchantItemInfo then
                        local _, _, _, per = GetMerchantItemInfo(i)
                        stackSize = math.max(1, per or 1)
                    end

                    local purchases = math.ceil(qtyNeeded / stackSize)
                    local maxStack = (GetMerchantItemMaxStack and GetMerchantItemMaxStack(i)) or 20
                    if stackSize > 1 then
                        for _ = 1, purchases do
                            pcall(buyFunc, i, 1)
                        end
                    else
                        local left = purchases
                        while left > 0 do
                            local batch = math.min(left, math.max(1, maxStack))
                            pcall(buyFunc, i, batch)
                            left = left - batch
                        end
                    end
                    self:Print(string.format(L["SHOP_BOUGHT_VENDOR"], purchases * stackSize, searchName))
                    return true
                end
            end
            self:Print(string.format(L["SHOP_VENDOR_NOT_SOLD"], searchName))
            return false
        end
    end

    -- 2. Modernes WoW Forever / Retail AuctionHouseFrame
    local ah = AuctionHouseFrame
    if type(ah) == "table" and ah.IsShown and ah:IsShown() then
        local bar = ah.SearchBar
        if bar and bar.SearchBox then
            bar.SearchBox:SetText(searchName)
            bar.SearchBox:ClearFocus()
            if bar.StartSearch then
                pcall(bar.StartSearch, bar)
            elseif bar.SearchButton and bar.SearchButton.Click then
                pcall(bar.SearchButton.Click, bar.SearchButton)
            end
            self:Print(string.format(L["SHOP_SEARCHING_AH"], searchName))
            return true
        end
    end

    -- 3. Klassisches AuctionFrame (BrowseName)
    if type(BrowseName) == "table" and BrowseName.IsVisible and BrowseName:IsVisible() then
        BrowseName:SetText(searchName)
        BrowseName:ClearFocus()
        if AuctionFrameBrowse_Search then
            pcall(AuctionFrameBrowse_Search)
        end
        self:Print(string.format(L["SHOP_SEARCHING_AH"], searchName))
        return true
    end

    -- 4. Auctionator API Fallback (falls AH offen)
    if ((ah and ah.IsShown and ah:IsShown()) or (AuctionFrame and AuctionFrame.IsShown and AuctionFrame:IsShown()))
        and Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.MultiSearchExact then
        local ok = pcall(Auctionator.API.v1.MultiSearchExact, "Yellow-Pages", { searchName })
        if ok then
            self:Print(string.format(L["SHOP_SEARCHING_AH"], searchName))
            return true
        end
    end

    self:Print(string.format(L["SHOP_AH_NOT_OPEN"], searchName))
    return false
end

-- ============================================================================
-- AUFTRAGSLISTE DES HANDWERKERS (Order Queue)
-- ============================================================================

function YellowPages:AddConfirmedOrderToQueue(buyerName, recipeID, count)
    YellowPagesCharDB = YellowPagesCharDB or {}
    YellowPagesCharDB.orderQueue = YellowPagesCharDB.orderQueue or {}

    local cleanBuyer = self:StripRealm(buyerName) or L["UNKNOWN"]
    recipeID = tonumber(recipeID) or 0
    count = tonumber(count) or 1

    local recipe = self:GetRecipeInfo(recipeID)
    local recName = (recipe and recipe.name) or (L["RECIPE_FALLBACK"] .. " #" .. tostring(recipeID))
    local recIcon = (recipe and recipe.icon) or "Interface\\Icons\\INV_Misc_QuestionMark"
    local itemID = (recipe and recipe.itemID) or 0

    for _, order in ipairs(YellowPagesCharDB.orderQueue) do
        if not order.done and order.buyer == cleanBuyer and order.recipeID == recipeID then
            order.count = count
            order.timestamp = time()
            self:Print(string.format(L["MSG_ORDER_QUEUED"], recName, count, cleanBuyer))
            if self.RefreshOrderQueueUI then self:RefreshOrderQueueUI() end
            if self.RefreshUI then self:RefreshUI() end
            return
        end
    end

    table.insert(YellowPagesCharDB.orderQueue, 1, {
        id = tostring(time()) .. "_" .. tostring(math.random(100, 999)),
        buyer = cleanBuyer,
        recipeID = recipeID,
        itemID = itemID,
        name = recName,
        icon = recIcon,
        count = count,
        craftedCount = 0,
        done = false,
        timestamp = time()
    })

    self:Print(string.format(L["MSG_ORDER_QUEUED"], recName, count, cleanBuyer))
    if self.RefreshOrderQueueUI then self:RefreshOrderQueueUI() end
    if self.RefreshUI then self:RefreshUI() end
end

function YellowPages:OnItemCrafted(craftedSpellID, craftedItemID, craftedName, quantityMade)
    if not YellowPagesCharDB or not YellowPagesCharDB.orderQueue then return end
    quantityMade = tonumber(quantityMade) or 1

    for _, order in ipairs(YellowPagesCharDB.orderQueue) do
        if not order.done then
            local match = false
            if craftedSpellID and craftedSpellID > 0 and order.recipeID == craftedSpellID then
                match = true
            elseif craftedItemID and craftedItemID > 0 and order.itemID and order.itemID == craftedItemID then
                match = true
            elseif craftedName and craftedName ~= "" and order.name and order.name:lower() == craftedName:lower() then
                match = true
            end

            if match then
                order.craftedCount = math.min(order.count, (order.craftedCount or 0) + quantityMade)
                if order.craftedCount >= order.count then
                    order.done = true
                    self:Print(string.format(L["MSG_ORDER_CRAFTED_DONE"], order.name, order.count, order.buyer))
                end
                if self.RefreshOrderQueueUI then self:RefreshOrderQueueUI() end
                if self.RefreshUI then self:RefreshUI() end
                break
            end
        end
    end
end

-- Event Handler Frame
local eventFrame = CreateFrame("Frame", "YellowPagesEventFrame")
for _, ev in ipairs({
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "GUILD_ROSTER_UPDATE",
    "TRADE_SKILL_ITEM_CRAFTED_RESULT",
    "UNIT_SPELLCAST_SUCCEEDED",
    "AUCTION_HOUSE_SHOW",
    "AUCTION_HOUSE_CLOSED",
    "AUCTION_SHOW",
    "AUCTION_CLOSED",
    "MERCHANT_SHOW",
    "MERCHANT_CLOSED",
    "BAG_UPDATE_DELAYED",
}) do
    YellowPages:SafeRegisterEvent(eventFrame, ev)
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "YellowPages" or addonName == "Yellow-Pages" then
            if not YellowPagesDB then
                YellowPagesDB = CopyTable and CopyTable(DEFAULT_GLOBAL_DB) or DEFAULT_GLOBAL_DB
            else
                for k, v in pairs(DEFAULT_GLOBAL_DB) do
                    if YellowPagesDB[k] == nil then
                        YellowPagesDB[k] = v
                    end
                end
            end

            if not YellowPagesCharDB then
                YellowPagesCharDB = CopyTable and CopyTable(DEFAULT_CHAR_DB) or DEFAULT_CHAR_DB
            else
                for k, v in pairs(DEFAULT_CHAR_DB) do
                    if YellowPagesCharDB[k] == nil then
                        YellowPagesCharDB[k] = v
                    end
                end
            end

            RegisterAddonPrefixSafe()
            YellowPages:InitMinimap()

            -- Chat Hyperlink Hook:
            -- |Haddon:YP:recipeID:count:buyer|h        -> Anfrage beim Handwerker öffnen
            -- |Haddon:YPC:recipeID:count:mode:crafter|h -> Auftrag durch den Anfragenden bestätigen (+ Einkaufsliste füllen)
            if hooksecurefunc then
                pcall(hooksecurefunc, "SetItemRef", function(link)
                    if type(link) ~= "string" then return end
                    local kind, prefix, a1, a2, a3, a4 = strsplit(":", link)
                    if kind == "addon" and prefix == "YP" then
                        local recipeID = tonumber(a1)
                        local count = tonumber(a2) or 1
                        local buyerName = a3
                        if recipeID and YellowPages.OpenOrderFromChatLink then
                            YellowPages:OpenOrderFromChatLink(buyerName, recipeID, count)
                        end
                    elseif kind == "addon" and prefix == "YPC" then
                        local recipeID = tonumber(a1)
                        local count = tonumber(a2) or 1
                        local mode = "BRING"
                        local crafterName = a3
                        if a4 and a4 ~= "" then
                            mode = a3
                            crafterName = a4
                        end
                        if recipeID and YellowPages.ConfirmCraftOrder then
                            YellowPages:ConfirmCraftOrder(crafterName, recipeID, count, mode)
                        end
                    elseif link:sub(1, 3) == "yp:" then
                        local recipeID = tonumber(link:sub(4))
                        if recipeID and YellowPages.OpenOrderForRecipe then
                            YellowPages:OpenOrderForRecipe(recipeID)
                        end
                    end
                end)
            end

            YellowPages:Print(string.format(L["LOADED_MSG"], YellowPages.Version))
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        RegisterAddonPrefixSafe()
        C_Timer.After(2, function()
            if YellowPages.EnsureYPChatTab then
                YellowPages:EnsureYPChatTab()
            end
        end)
        if YellowPages.LoadRecipeCatalog then
            YellowPages:LoadRecipeCatalog()
        end
        if YellowPages.UpdateGuildMembersStatus then
            YellowPages:UpdateGuildMembersStatus()
        end
        C_Timer.After(4, function()
            if YellowPages.UpdateGuildMembersStatus then
                YellowPages:UpdateGuildMembersStatus()
            end
            if YellowPages:IsInGuild() then
                YellowPages:BroadcastHello()
            end
        end)
    elseif event == "GUILD_ROSTER_UPDATE" then
        if YellowPages.UpdateGuildMembersStatus then
            YellowPages:UpdateGuildMembersStatus()
        end
    elseif event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        local resultData = ...
        if type(resultData) == "table" then
            YellowPages:OnItemCrafted(nil, resultData.itemID, nil, resultData.quantity or 1)
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget, _, spellID = ...
        if unitTarget == "player" and spellID and not (issecretvalue and issecretvalue(spellID)) then
            local spellName = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or (GetSpellInfo and GetSpellInfo(spellID))
            YellowPages:OnItemCrafted(spellID, nil, spellName, 1)
        end
    elseif event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_SHOW" or event == "MERCHANT_SHOW" then
        -- Öffnet automatisch das Einkaufslisten-Pop-Up am Auktionshaus UND bei Händlern, falls noch offene Materialien auf der Liste stehen!
        if YellowPages:HasOpenShoppingItems() and YellowPages.ShowShoppingListPopup then
            C_Timer.After(0.2, function()
                YellowPages:ShowShoppingListPopup(true)
            end)
        end
    elseif event == "AUCTION_HOUSE_CLOSED" or event == "AUCTION_CLOSED" or event == "MERCHANT_CLOSED" then
        if YellowPages.HideShoppingListOnAHClose then
            YellowPages:HideShoppingListOnAHClose()
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        if YellowPages.RefreshShoppingListUI then
            YellowPages:RefreshShoppingListUI()
        end
        if YellowPages.RefreshUI then
            YellowPages:RefreshUI()
        end
    end
end)

-- Slash Commands
SLASH_YELLOWPAGES1 = "/yp"
SLASH_YELLOWPAGES2 = "/yellowpages"
SLASH_YELLOWPAGES3 = "/gelbeseiten"

SlashCmdList["YELLOWPAGES"] = function(msg)
    local cmd, arg1 = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "scan" then
        YellowPages:ScanCurrentTradeSkill(true)
    elseif cmd == "order" then
        local recipeID = tonumber(arg1)
        if recipeID then
            YellowPages:OpenOrderForRecipe(recipeID)
        else
            YellowPages:Print("Syntax: /yp order <RecipeID>")
        end
    elseif cmd == "orders" or cmd == "queue" then
        if YellowPages.ToggleOrderQueueUI then
            YellowPages:ToggleOrderQueueUI()
        end
    elseif cmd == "shop" or cmd == "einkauf" then
        if YellowPages.ToggleShoppingListUI then
            YellowPages:ToggleShoppingListUI()
        end
    elseif cmd == "info" or cmd == "help" or cmd == "hilfe" then
        if YellowPages.ToggleInfoPage then
            YellowPages:ToggleInfoPage()
        end
    elseif cmd == "chat" then
        local cf = YellowPages:EnsureYPChatTab()
        if cf and FCF_SelectDockFrame then
            pcall(FCF_SelectDockFrame, cf)
        end
    elseif cmd == "status" then
        if YellowPages.PrintStatus then
            YellowPages:PrintStatus()
        end
    elseif cmd == "reset" then
        YellowPages:ResetDatabase()
    elseif cmd == "sync" then
        if YellowPages.RequestGuildSync then
            YellowPages:RequestGuildSync()
        else
            YellowPages:BroadcastHello()
            YellowPages:BroadcastAllMyProfessions()
            YellowPages:Print(L["MSG_SYNC_SENT"])
        end
    else
        YellowPages:ToggleUI()
    end
end

function YellowPages_ToggleUI()
    YellowPages:ToggleUI()
end
