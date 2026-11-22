--[[
    Yellow-Pages: Inventory.lua
    Verwaltung und Abfrage von Spieler-Taschen (inkl. Reagenzientasche) und Bankbestand
--]]

YellowPages = YellowPages or {}

local invFrame = CreateFrame("Frame", "YellowPagesInventoryFrame")
for _, ev in ipairs({
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
    "PLAYERBANKSLOTS_CHANGED",
    "BAG_UPDATE",
    "BAG_UPDATE_DELAYED",
}) do
    pcall(invFrame.RegisterEvent, invFrame, ev)
end

-- Taschen- und Bank-Indizes ermitteln (kompatibel mit WoW Forever ReagentBag = 5 und BankBag_1 = 6)
local BAG_CONTAINERS = { 0, 1, 2, 3, 4 }
local BANK_CONTAINERS = { -1 }
do
    local BI = type(Enum) == "table" and type(Enum.BagIndex) == "table" and Enum.BagIndex or nil
    local reagentBag = BI and BI.ReagentBag
    if reagentBag then
        table.insert(BAG_CONTAINERS, reagentBag)
    end
    local firstBankBag = (BI and BI.BankBag_1) or ((reagentBag or 4) + 1)
    local numBankBags = tonumber(NUM_BANKBAGSLOTS) or 7
    for i = 0, numBankBags - 1 do
        table.insert(BANK_CONTAINERS, firstBankBag + i)
    end
    if BI and BI.Reagentbank then
        table.insert(BANK_CONTAINERS, BI.Reagentbank)
    elseif REAGENTBANK_CONTAINER then
        table.insert(BANK_CONTAINERS, REAGENTBANK_CONTAINER)
    end
end

local function GetContainerNumSlotsSafe(bagID)
    if C_Container and C_Container.GetContainerNumSlots then
        local ok, n = pcall(C_Container.GetContainerNumSlots, bagID)
        return (ok and type(n) == "number") and n or 0
    elseif GetContainerNumSlots then
        local ok, n = pcall(GetContainerNumSlots, bagID)
        return (ok and type(n) == "number") and n or 0
    end
    return 0
end

local function GetContainerSlotItemSafe(bagID, slotID)
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bagID, slotID)
        if ok and type(info) == "table" and info.itemID then
            return info.itemID, info.stackCount or 1
        end
    end
    if C_Container and C_Container.GetContainerItemID then
        local ok, itemID = pcall(C_Container.GetContainerItemID, bagID, slotID)
        if ok and itemID then
            return itemID, 1
        end
    end
    if GetContainerItemID and GetContainerItemInfo then
        local itemID = GetContainerItemID(bagID, slotID)
        if itemID then
            local _, count = GetContainerItemInfo(bagID, slotID)
            return itemID, count or 1
        end
    end
    return nil, 0
end

local bankOpen = false

-- Scannen des Bankinhalts und Speichern im Charakter-Cache
local function ScanBank()
    if not bankOpen then return end
    YellowPagesCharDB = YellowPagesCharDB or {}
    local cache = {}

    for _, bag in ipairs(BANK_CONTAINERS) do
        local numSlots = GetContainerNumSlotsSafe(bag)
        for slot = 1, numSlots do
            local itemID, count = GetContainerSlotItemSafe(bag, slot)
            if itemID and itemID > 0 then
                cache[itemID] = (cache[itemID] or 0) + (count or 1)
            end
        end
    end

    YellowPagesCharDB.bankCache = cache
    YellowPagesCharDB.lastBankUpdate = time()
end

invFrame:SetScript("OnEvent", function(self, event)
    if event == "BANKFRAME_OPENED" then
        bankOpen = true
        ScanBank()
    elseif event == "BANKFRAME_CLOSED" then
        ScanBank()
        bankOpen = false
    elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE" then
        if bankOpen then
            ScanBank()
        end
    end
end)

-- Liefert die Anzahl eines Items in den Taschen (inkl. Reagenzientasche)
function YellowPages:GetBagItemCount(itemID)
    if not itemID or itemID == 0 then return 0 end

    if (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots then
        local count = 0
        for _, bag in ipairs(BAG_CONTAINERS) do
            local numSlots = GetContainerNumSlotsSafe(bag)
            for slot = 1, numSlots do
                local id, stack = GetContainerSlotItemSafe(bag, slot)
                if id == itemID then
                    count = count + (stack or 1)
                end
            end
        end
        return count
    end

    local getCount = GetItemCount or (C_Item and C_Item.GetItemCount)
    if getCount then
        local ok, c = pcall(getCount, itemID, false)
        if ok and type(c) == "number" then return c end
    end
    return 0
end

-- Liefert die Anzahl eines Items auf der Bank
function YellowPages:GetBankItemCount(itemID)
    if not itemID or itemID == 0 then return 0 end

    -- 1. Wenn die Bank gerade offen ist, live aus den Bankfächern zählen
    if bankOpen then
        local count = 0
        for _, bag in ipairs(BANK_CONTAINERS) do
            local numSlots = GetContainerNumSlotsSafe(bag)
            for slot = 1, numSlots do
                local id, stack = GetContainerSlotItemSafe(bag, slot)
                if id == itemID then
                    count = count + (stack or 1)
                end
            end
        end
        return count
    end

    -- 2. Gespeicherter Bank-Cache (zuverlässig auch wenn nicht an der Bank)
    if YellowPagesCharDB and YellowPagesCharDB.bankCache and YellowPagesCharDB.bankCache[itemID] then
        return YellowPagesCharDB.bankCache[itemID]
    end

    -- 3. Syndicator / Baganator API (falls installiert und Bank dort bereits erfasst wurde)
    if Syndicator and Syndicator.API and Syndicator.API.GetInventoryInfoByItemID then
        local ok, info = pcall(Syndicator.API.GetInventoryInfoByItemID, itemID, true, true)
        if ok and type(info) == "table" and type(info.characters) == "table" then
            local myName = self:GetPlayerFullName("player")
            for _, charInfo in ipairs(info.characters) do
                if charInfo.character == myName and charInfo.bank and charInfo.bank > 0 then
                    return charInfo.bank
                end
            end
        end
    end

    -- 4. Fallback: GetItemCount(itemID, true) - Taschen
    local getCount = GetItemCount or (C_Item and C_Item.GetItemCount)
    if getCount then
        local okTotal, total = pcall(getCount, itemID, true)
        if okTotal and type(total) == "number" then
            local bags = self:GetBagItemCount(itemID)
            if total > bags then
                return total - bags
            end
        end
    end

    return 0
end

-- Liefert den Gesamtbestand (Taschen + Bank)
function YellowPages:GetTotalItemCount(itemID)
    if not itemID or itemID == 0 then return 0 end
    return self:GetBagItemCount(itemID) + self:GetBankItemCount(itemID)
end
