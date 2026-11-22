--[[
    Yellow-Pages: Pricing.lua
    Preiskalkulation: Auktionshaus (Auctionator, TSM, Auctioneer) & Händlerpreise
--]]

YellowPages = YellowPages or {}

-- Fragt den Einzelpreis eines Items ab (AH oder Händler)
function YellowPages:GetItemPrice(itemID, itemLink)
    if (not itemID or itemID == 0) and not itemLink then
        return 0, "UNKNOWN"
    end

    -- 1. Prüfung auf Händlermaterial
    if itemID and itemID > 0 and self:IsVendorReagent(itemID) then
        local vendorPrice = self:GetVendorReagentPrice(itemID)
        if vendorPrice and vendorPrice > 0 then
            return vendorPrice, "VENDOR"
        end
        -- Falls in VendorReagents ohne festen Preis hinterlegt: 4x Verkaufspreis
        local sellPrice = select(11, self:GetItemInfoSafe(itemID))
        if sellPrice and sellPrice > 0 then
            return sellPrice * 4, "VENDOR"
        end
    end

    -- 2. Auktionshaus-Schnittstellen (AH)
    local ahPrice = nil

    -- 2a. Auctionator API v1
    if Auctionator and Auctionator.API and Auctionator.API.v1 then
        if itemID and itemID > 0 and Auctionator.API.v1.GetAuctionPriceByItemID then
            local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, "YellowPages", itemID)
            if ok and price and price > 0 then
                ahPrice = price
            end
        end
        if not ahPrice and itemLink and Auctionator.API.v1.GetAuctionPriceByItemLink then
            local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemLink, "YellowPages", itemLink)
            if ok and price and price > 0 then
                ahPrice = price
            end
        end
    end

    -- 2b. TradeSkillMaster (TSM) API
    if not ahPrice and TSM_API and TSM_API.GetCustomPriceValue and itemID and itemID > 0 then
        local ok, price = pcall(TSM_API.GetCustomPriceValue, "DBMarket", "i:" .. itemID)
        if ok and price and price > 0 then
            ahPrice = price
        end
    end

    -- 2c. Auctioneer / AucAdvanced
    if not ahPrice and AucAdvanced and AucAdvanced.API and AucAdvanced.API.GetMarketValue and itemLink then
        local ok, price = pcall(AucAdvanced.API.GetMarketValue, itemLink)
        if ok and price and price > 0 then
            ahPrice = price
        end
    end

    -- 2d. Atr_GetAuctionBuyout (Auctionator legacy)
    if not ahPrice and Atr_GetAuctionBuyout and (itemLink or itemID) then
        local ok, price = pcall(Atr_GetAuctionBuyout, itemLink or itemID)
        if ok and price and price > 0 then
            ahPrice = price
        end
    end

    if ahPrice and ahPrice > 0 then
        return ahPrice, "AH"
    end

    -- 3. Fallback: Händler-Verkaufswert * 4 als Schätzwert
    if itemID and itemID > 0 then
        local sellPrice = select(11, self:GetItemInfoSafe(itemID))
        if sellPrice and sellPrice > 0 then
            return sellPrice * 4, "VENDOR_ESTIMATE"
        end
    end

    return 0, "UNKNOWN"
end

-- Berechnet die Gesamtkosten für ein Rezept
-- onlyMissing: wenn true, werden nur Materialien berechnet, die der Spieler noch benötigt
function YellowPages:CalculateRecipeCost(recipeData, multiplier, onlyMissing)
    multiplier = multiplier or 1
    if not recipeData or not recipeData.reagents then
        return { totalVendor = 0, totalAH = 0, grandTotal = 0, reagentsBreakdown = {} }
    end

    local totalVendor = 0
    local totalAH = 0
    local breakdown = {}

    for _, reagent in ipairs(recipeData.reagents) do
        local requiredCount = (reagent.count or 1) * multiplier
        local ownedCount = 0

        if onlyMissing and self.GetTotalItemCount then
            ownedCount = self:GetTotalItemCount(reagent.itemID)
        end

        local countToBuy = onlyMissing and math.max(0, requiredCount - ownedCount) or requiredCount
        local unitPrice, source = self:GetItemPrice(reagent.itemID, nil)
        local lineTotal = countToBuy * unitPrice

        if source == "VENDOR" or source == "VENDOR_ESTIMATE" then
            totalVendor = totalVendor + lineTotal
        else
            totalAH = totalAH + lineTotal
        end

        local rName = reagent.name
        if (not rName or rName == "" or rName:find("^Item #")) and reagent.itemID and reagent.itemID > 0 then
            rName = self:GetItemNameSafe(reagent.itemID)
        end
        local rIcon = reagent.icon
        if (not rIcon or rIcon == "" or tostring(rIcon):find("QuestionMark")) and reagent.itemID and reagent.itemID > 0 then
            rIcon = self:GetItemIconSafe(reagent.itemID)
        end

        table.insert(breakdown, {
            itemID = reagent.itemID,
            name = rName or "Reagenz",
            icon = rIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
            countNeeded = requiredCount,
            countOwned = ownedCount,
            countToBuy = countToBuy,
            unitPrice = unitPrice,
            lineTotal = lineTotal,
            source = source
        })
    end

    return {
        totalVendor = totalVendor,
        totalAH = totalAH,
        grandTotal = totalVendor + totalAH,
        reagentsBreakdown = breakdown
    }
end
