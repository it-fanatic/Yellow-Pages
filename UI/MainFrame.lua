--[[
    Yellow-Pages: MainFrame.lua
    Hauptfenster im authentischen "Forever Profession Trainer"-Design:
    - PortraitFrameTemplate mit dynamischem Berufs-Portrait oben links & zentriertem Titel
    - Rechte Seiten-Tabs (LargeSideTabButtonTemplate) für Alle Berufe, sämtliche Handwerksberufe,
      sowie unten rechts für die Auftragsliste und die Einkaufsliste
    - Warme Braun-Gold Inset-Panels mit Farbverlauf, Spaltenköpfen und Münz-Icons
--]]

YellowPages = YellowPages or {}

local L = YellowPages.L
local Theme = YellowPages.Theme
local mainFrame = nil
local selectedRecipeID = nil
local currentQuantity = 1
local selectedProfession = "ALL"
local currentSearchQuery = ""
local onlyOnlineCrafters = false
local onlyAvailableCrafters = false
local currentSortBy = "NAME_ASC"
local selectedQualityFilter = "ALL"
local showingInfoPage = false

local SORT_OPTIONS = {
    { key = "NAME_ASC",     label = L["SORT_NAME_ASC"],     short = L["SORT_SHORT_NAME"] },
    { key = "LEVEL_ASC",    label = L["SORT_LEVEL_ASC"],    short = L["SORT_SHORT_LVL_ASC"] },
    { key = "LEVEL_DESC",   label = L["SORT_LEVEL_DESC"],   short = L["SORT_SHORT_LVL_DESC"] },
    { key = "QUALITY_DESC", label = L["SORT_QUALITY_DESC"], short = L["SORT_SHORT_QUAL_DESC"] },
    { key = "QUALITY_ASC",  label = L["SORT_QUALITY_ASC"],  short = L["SORT_SHORT_QUAL_ASC"] },
}

local QUALITY_FILTERS = {
    { key = "ALL", label = L["QUALITY_ALL"] },
    { key = 1,     label = "|cfff7ead1" .. L["QUALITY_1"] .. "|r" },
    { key = 2,     label = "|cff1eff00" .. L["QUALITY_2"] .. "|r" },
    { key = 3,     label = "|cff0070dd" .. L["QUALITY_3"] .. "|r" },
    { key = 4,     label = "|cffa335ee" .. L["QUALITY_4"] .. "|r" },
    { key = 5,     label = "|cffff8000" .. L["QUALITY_5"] .. "|r" },
}

local function GetSortShortLabel()
    local base = L["SORT_SHORT_NAME"]
    for _, opt in ipairs(SORT_OPTIONS) do
        if opt.key == currentSortBy then
            base = opt.short
            break
        end
    end
    if selectedQualityFilter ~= "ALL" then
        local qInfo = Theme.QUALITY_INFO[selectedQualityFilter]
        if qInfo then
            return string.format("|cff%s%s|r", qInfo.hex, base)
        end
    end
    return base
end

-- Zählt bekannte Rezepte pro Beruf für die Seiten-Tab-Tooltips & Goldrahmen
local function GetRecipeCountForProfession(profKey)
    if not YellowPagesDB or not YellowPagesDB.recipes then return 0 end
    local count = 0
    for _, r in pairs(YellowPagesDB.recipes) do
        local norm = YellowPages:NormalizeProfessionName(r.prof) or r.prof
        if profKey == "ALL" or norm == profKey then
            count = count + 1
        end
    end
    return count
end

-- Sortier- & Qualitäts-Menü
local sortPopup = nil
local function ShowSortAndQualityMenu(anchorBtn, onUpdate)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchorBtn, function(_, rootDescription)
            rootDescription:CreateTitle(L["SORT_MENU_TITLE"])
            for _, opt in ipairs(SORT_OPTIONS) do
                rootDescription:CreateRadio(opt.label, function() return currentSortBy == opt.key end, function()
                    currentSortBy = opt.key
                    onUpdate()
                end)
            end

            rootDescription:CreateDivider()
            rootDescription:CreateTitle(L["FILTER_QUALITY_TITLE"])
            for _, qOpt in ipairs(QUALITY_FILTERS) do
                rootDescription:CreateRadio(qOpt.label, function() return selectedQualityFilter == qOpt.key end, function()
                    selectedQualityFilter = qOpt.key
                    onUpdate()
                end)
            end
        end)
        return
    end

    if not sortPopup then
        local totalRows = #SORT_OPTIONS + #QUALITY_FILTERS + 2
        sortPopup = CreateFrame("Frame", "YellowPagesSortPopup", mainFrame, BackdropTemplateMixin and "BackdropTemplate")
        sortPopup:SetSize(210, totalRows * 22 + 14)
        sortPopup:SetFrameStrata("TOOLTIP")
        sortPopup:EnableMouse(true)
        Theme:ApplyBackdrop(sortPopup, 0.105, 0.079, 0.054, 0.98, 0.94, 0.73, 0.43, 1.0)

        local y = -8
        local hdr1 = sortPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdr1:SetPoint("TOPLEFT", 10, y)
        hdr1:SetText("|cffffd14c" .. L["SORT_MENU_TITLE"] .. ":|r")
        y = y - 20

        for _, opt in ipairs(SORT_OPTIONS) do
            local row = CreateFrame("Button", nil, sortPopup)
            row:SetSize(194, 20)
            row:SetPoint("TOPLEFT", 8, y)
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 0.82, 0.52, 0.15)
            local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", 6, 0)
            txt:SetText(opt.label)
            row:SetScript("OnClick", function()
                currentSortBy = opt.key
                sortPopup:Hide()
                if sortPopup.onUpdate then sortPopup.onUpdate() end
            end)
            y = y - 22
        end

        y = y - 4
        local hdr2 = sortPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdr2:SetPoint("TOPLEFT", 10, y)
        hdr2:SetText("|cffffd14c" .. L["FILTER_QUALITY_TITLE"] .. ":|r")
        y = y - 20

        for _, qOpt in ipairs(QUALITY_FILTERS) do
            local row = CreateFrame("Button", nil, sortPopup)
            row:SetSize(194, 20)
            row:SetPoint("TOPLEFT", 8, y)
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 0.82, 0.52, 0.15)
            local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", 6, 0)
            txt:SetText(qOpt.label)
            row:SetScript("OnClick", function()
                selectedQualityFilter = qOpt.key
                sortPopup:Hide()
                if sortPopup.onUpdate then sortPopup.onUpdate() end
            end)
            y = y - 22
        end
    end

    sortPopup.onUpdate = onUpdate
    sortPopup:ClearAllPoints()
    sortPopup:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
    sortPopup:SetShown(not sortPopup:IsShown())
end

-- Schaltet zwischen der Rezept-/Berufs-Ansicht und der Info-Seite (Buch-Button unten rechts) um
function YellowPages:SetInfoPageShown(show)
    showingInfoPage = (show == true)
    if not mainFrame then return end

    local showMain = not showingInfoPage
    if mainFrame.topPanel then mainFrame.topPanel:SetShown(showMain) end
    if mainFrame.statusText then mainFrame.statusText:SetShown(showMain) end
    if mainFrame.ordersTabBtn then mainFrame.ordersTabBtn:SetShown(showMain) end
    if mainFrame.shoppingTabBtn then mainFrame.shoppingTabBtn:SetShown(showMain) end
    if mainFrame.leftContainer then mainFrame.leftContainer:SetShown(showMain) end
    if mainFrame.rightContainer then mainFrame.rightContainer:SetShown(showMain) end
    if mainFrame.infoContainer then mainFrame.infoContainer:SetShown(showingInfoPage) end

    self:UpdateSideTabsAndHeader()
end

function YellowPages:ToggleInfoPage()
    if not mainFrame then
        self:CreateMainFrame()
    end
    if not mainFrame:IsShown() then
        mainFrame:Show()
        self:SetInfoPageShown(true)
    else
        self:SetInfoPageShown(not showingInfoPage)
    end
end

-- Aktualisiert Portrait, Fenstertitel und die rechten Seiten-Tabs (inkl. Goldrahmen & Zähler-Badges)
function YellowPages:UpdateSideTabsAndHeader()
    if not mainFrame then return end

    -- 1. Portrait oben links & Zentrierter Titel aktualisieren
    local activeLabel = L["ALL_PROFESSIONS"]
    if showingInfoPage then
        activeLabel = L["INFO_PAGE_HEADER"]
    elseif selectedProfession ~= "ALL" then
        activeLabel = selectedProfession
    end

    local portraitTex = (mainFrame.PortraitContainer and mainFrame.PortraitContainer.portrait) or mainFrame.fallbackPortrait
    if portraitTex then
        Theme:ApplyTextureOrProfessionIcon(portraitTex, showingInfoPage and "INFO" or selectedProfession)
    end

    local titleStr = "Yellow-Pages  ·  " .. activeLabel
    if mainFrame.TitleContainer and mainFrame.TitleContainer.TitleText then
        mainFrame.TitleContainer.TitleText:SetText(titleStr)
    elseif mainFrame.fallbackTitle then
        mainFrame.fallbackTitle:SetText(titleStr)
    end

    -- 2. Berufs-Tabs am rechten Rand aktualisieren (weiter nach unten versetzt auf Höhe der Innen-Panels)
    if mainFrame.profTabs then
        local prevTab = nil
        for i, tab in ipairs(mainFrame.profTabs) do
            local isSelected = (not showingInfoPage) and (tab.profKey == selectedProfession)
            local recCount = GetRecipeCountForProfession(tab.profKey)
            local hasRecipes = (recCount > 0)

            if tab.SetChecked then
                tab:SetChecked(isSelected)
            end
            if tab.Background then
                if isSelected or hasRecipes then
                    tab.Background:SetVertexColor(unpack(Theme.FPT.gold))
                else
                    tab.Background:SetVertexColor(unpack(Theme.FPT.tabNeutral))
                end
            end

            local scale = isSelected and 0.74 or 0.62
            if math.abs((tab:GetScale() or 1) - scale) > 0.01 then
                tab:SetScale(scale)
            end

            tab:ClearAllPoints()
            if not prevTab then
                tab:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 0, -58)
            else
                -- Kleiner Abstand vor Sammelberufen (Index 8) und Nebenberufen (Index 11)
                local gap = (i == 8 or i == 11) and 7 or 1
                tab:SetPoint("TOPLEFT", prevTab, "BOTTOMLEFT", 0, -gap)
            end
            prevTab = tab
        end
    end

    -- 3. Untere Aktions-Tabs am rechten Rand (Einkaufsliste, Auftragsliste & Info-Buch ganz unten)
    if mainFrame.infoSideTab then
        if mainFrame.infoSideTab.SetChecked then
            mainFrame.infoSideTab:SetChecked(showingInfoPage)
        end
        if mainFrame.infoSideTab.Background then
            mainFrame.infoSideTab.Background:SetVertexColor(unpack(showingInfoPage and Theme.FPT.gold or Theme.FPT.tabNeutral))
        end
    end

    if mainFrame.ordersSideTab then
        local openOrders = self.GetActiveOrderCount and self:GetActiveOrderCount() or 0
        mainFrame.ordersSideTab:SetBadgeCount(openOrders)
        if mainFrame.ordersSideTab.Background then
            mainFrame.ordersSideTab.Background:SetVertexColor(unpack(openOrders > 0 and Theme.FPT.gold or Theme.FPT.tabNeutral))
        end
    end

    if mainFrame.shoppingSideTab then
        local openShop = self.GetShoppingListCount and self:GetShoppingListCount() or 0
        mainFrame.shoppingSideTab:SetBadgeCount(openShop)
        if mainFrame.shoppingSideTab.Background then
            mainFrame.shoppingSideTab.Background:SetVertexColor(unpack(openShop > 0 and Theme.FPT.gold or Theme.FPT.tabNeutral))
        end
    end
end

-- Erstellung des Hauptfensters im "Forever Profession Trainer"-Stil
function YellowPages:CreateMainFrame()
    if mainFrame then return mainFrame end

    local ok, f = pcall(CreateFrame, "Frame", "YellowPagesMainFrame", UIParent, "PortraitFrameTemplate")
    if ok and f then
        mainFrame = f
        if mainFrame.Bg then
            mainFrame.Bg:SetColorTexture(unpack(Theme.FPT.window))
        end
    else
        mainFrame = CreateFrame("Frame", "YellowPagesMainFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
        Theme:ApplyBackdrop(mainFrame, nil, nil, nil, nil, nil, nil, nil, nil, true)
    end

    mainFrame:SetSize(820, 660)
    mainFrame:SetPoint("CENTER", 0, 0)
    mainFrame:SetToplevel(true)
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:EnableMouse(true)
    mainFrame:SetMovable(true)
    mainFrame:SetClampedToScreen(true)
    table.insert(UISpecialFrames, "YellowPagesMainFrame")

    -- Ziehen über Titelleiste oder ganzes Fenster
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)

    if mainFrame.TitleContainer then
        mainFrame.TitleContainer:EnableMouse(true)
        mainFrame.TitleContainer:RegisterForDrag("LeftButton")
        mainFrame.TitleContainer:SetScript("OnDragStart", function() mainFrame:StartMoving() end)
        mainFrame.TitleContainer:SetScript("OnDragStop", function() mainFrame:StopMovingOrSizing() end)

        local title = mainFrame.TitleContainer.TitleText
        if title then
            title:ClearAllPoints()
            title:SetPoint("CENTER", mainFrame, "TOP", 0, -12)
            title:SetJustifyH("CENTER")
            title:SetTextColor(unpack(Theme.FPT.gold))
        end
    else
        local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetTextColor(unpack(Theme.FPT.gold))
        mainFrame.fallbackTitle = title
    end

    if mainFrame.CloseButton then
        mainFrame.CloseButton:SetScript("OnClick", function() mainFrame:Hide() end)
    else
        local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)
    end

    -- ========================================================================
    -- RECHTE SEITEN-TABS (Berufe + Auftragsliste + Einkaufsliste)
    -- ========================================================================
    mainFrame.profTabs = {}
    local profList = Theme:GetProfessionTabsList()

    for i, pInfo in ipairs(profList) do
        local tab = Theme:CreateSideTab(mainFrame, pInfo.icon, function()
            selectedProfession = pInfo.key
            selectedRecipeID = nil
            YellowPages:SetInfoPageShown(false)
            YellowPages:RefreshRecipeList()
            YellowPages:UpdateDetailPane()
        end)
        if pInfo.isHammer and tab.Icon then
            Theme:ApplyHammerPickaxeIcon(tab.Icon)
        end
        tab.profKey = pInfo.key
        tab.profLabel = pInfo.label

        tab:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(self.profLabel, unpack(Theme.FPT.gold))
            local rCount = GetRecipeCountForProfession(self.profKey)
            GameTooltip:AddLine(string.format("%d %s", rCount, L["COL_RECIPE"]), unpack(Theme.FPT.text))
            GameTooltip:Show()
        end)
        tab:SetScript("OnLeave", function() GameTooltip:Hide() end)

        mainFrame.profTabs[i] = tab
    end

    -- Unterer rechter Tab 3 (ganz unten unter der Schriftrolle): Info-Seite (Buch-Icon)
    local infoSideTab = Theme:CreateSideTab(mainFrame, Theme.BOOK_ICON, function()
        YellowPages:SetInfoPageShown(not showingInfoPage)
    end)
    infoSideTab:SetScale(0.68)
    infoSideTab:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMRIGHT", 0, 10)
    infoSideTab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["BTN_INFO_TAB"], unpack(Theme.FPT.gold))
        GameTooltip:AddLine(L["INFO_TAB_SUBTITLE"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    infoSideTab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    mainFrame.infoSideTab = infoSideTab

    -- Unterer rechter Tab 2 (über dem Buch-Icon): Auftragsliste (Schriftrolle)
    local ordersSideTab = Theme:CreateSideTab(mainFrame, Theme.ORDERS_ICON, function()
        if YellowPages.ToggleOrderQueueUI then
            YellowPages:ToggleOrderQueueUI()
        end
    end)
    ordersSideTab:SetScale(0.68)
    ordersSideTab:SetPoint("BOTTOMLEFT", infoSideTab, "TOPLEFT", 0, 3)
    ordersSideTab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local openOrders = YellowPages.GetActiveOrderCount and YellowPages:GetActiveOrderCount() or 0
        GameTooltip:SetText(string.format(L["BTN_ORDERS_TAB"], openOrders), unpack(Theme.FPT.gold))
        GameTooltip:AddLine(L["QUEUE_SUBTITLE"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    ordersSideTab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    mainFrame.ordersSideTab = ordersSideTab

    -- Unterer rechter Tab 1 (über der Schriftrolle): Einkaufsliste (Münzen)
    local shoppingSideTab = Theme:CreateSideTab(mainFrame, Theme.SHOPPING_ICON, function()
        if YellowPages.ToggleShoppingListUI then
            YellowPages:ToggleShoppingListUI()
        end
    end)
    shoppingSideTab:SetScale(0.68)
    shoppingSideTab:SetPoint("BOTTOMLEFT", ordersSideTab, "TOPLEFT", 0, 3)
    shoppingSideTab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local openShop = YellowPages.GetShoppingListCount and YellowPages:GetShoppingListCount() or 0
        GameTooltip:SetText(string.format(L["BTN_SHOPPING_TAB"], openShop), unpack(Theme.FPT.gold))
        GameTooltip:AddLine(L["SHOP_SUBTITLE"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    shoppingSideTab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    mainFrame.shoppingSideTab = shoppingSideTab

    -- ========================================================================
    -- OBERES FILTER- & SUCH-PANEL (Inset Panel im FPT-Look)
    -- ========================================================================
    local topPanel = Theme:CreateInsetPanel(mainFrame)
    topPanel:SetPoint("TOPLEFT", 18, -56)
    topPanel:SetPoint("TOPRIGHT", -18, -56)
    topPanel:SetHeight(42)
    mainFrame.topPanel = topPanel

    -- Suchfeld
    local searchBox = CreateFrame("EditBox", "YellowPagesSearchBox", topPanel, "InputBoxTemplate")
    searchBox:SetSize(140, 22)
    searchBox:SetPoint("LEFT", 14, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetText("")

    local searchLabel = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchLabel:SetPoint("LEFT", 6, 0)
    searchLabel:SetText(L["SEARCH_PLACEHOLDER"])
    searchLabel:SetTextColor(unpack(Theme.FPT.muted))
    searchBox.label = searchLabel

    searchBox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText()
        if txt == "" then
            searchLabel:Show()
        else
            searchLabel:Hide()
        end
        currentSearchQuery = txt
        YellowPages:RefreshRecipeList()
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Sortier- & Qualitäts-Button
    local sortBtn = Theme:CreateButton(topPanel, 106, 22, GetSortShortLabel())
    sortBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    mainFrame.sortBtn = sortBtn

    sortBtn:SetScript("OnClick", function(self)
        ShowSortAndQualityMenu(self, function()
            sortBtn:SetText(GetSortShortLabel())
            YellowPages:RefreshRecipeList()
        end)
    end)

    -- Checkbox: Nur Online-Crafter
    local onlineCheck = CreateFrame("CheckButton", "YellowPagesOnlineCheck", topPanel, "UICheckButtonTemplate")
    onlineCheck:SetPoint("LEFT", sortBtn, "RIGHT", 6, 0)
    onlineCheck:SetSize(22, 22)
    local checkText = onlineCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    checkText:SetPoint("LEFT", onlineCheck, "RIGHT", 2, 0)
    checkText:SetText(L["ONLINE_ONLY"])
    checkText:SetTextColor(unpack(Theme.FPT.text))
    onlineCheck:SetScript("OnClick", function(self)
        onlyOnlineCrafters = not not self:GetChecked()
        YellowPages:RefreshRecipeList()
    end)

    -- Checkbox: Nur verfügbare (gelernte) Rezepte (blendet 0-Handwerker-Rezepte aus)
    local availableCheck = CreateFrame("CheckButton", "YellowPagesAvailableCheck", topPanel, "UICheckButtonTemplate")
    availableCheck:SetPoint("LEFT", checkText, "RIGHT", 8, 0)
    availableCheck:SetSize(22, 22)
    local availText = availableCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    availText:SetPoint("LEFT", availableCheck, "RIGHT", 2, 0)
    availText:SetText(L["AVAILABLE_ONLY"])
    availText:SetTextColor(unpack(Theme.FPT.text))
    availableCheck:SetScript("OnClick", function(self)
        onlyAvailableCrafters = not not self:GetChecked()
        YellowPages:RefreshRecipeList()
    end)

    -- Rechts im Top-Panel: Beruf scannen & Sync
    local syncBtn = Theme:CreateButton(topPanel, 64, 22, L["BTN_SYNC"])
    syncBtn:SetPoint("RIGHT", -10, 0)
    syncBtn:SetScript("OnClick", function()
        if YellowPages.RequestGuildSync then
            YellowPages:RequestGuildSync()
        else
            YellowPages:BroadcastHello()
            YellowPages:BroadcastAllMyProfessions()
            YellowPages:Print(L["MSG_SYNC_SENT"])
        end
    end)

    local scanBtn = Theme:CreateButton(topPanel, 104, 22, L["BTN_SCAN_PROF"])
    scanBtn:SetPoint("RIGHT", syncBtn, "LEFT", -6, 0)
    scanBtn:SetScript("OnClick", function()
        YellowPages:ScanCurrentTradeSkill(true)
    end)

    -- Status-Zeile unter dem Top-Panel (wie "Learn Alchemy" in FPT)
    local statusText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOPLEFT", 22, -106)
    statusText:SetTextColor(unpack(Theme.FPT.gold))
    mainFrame.statusText = statusText

    -- Quick-Buttons für Aufträge & Einkauf oben rechts über dem rechten Panel
    local ordersTabBtn = Theme:CreateButton(mainFrame, 115, 22, string.format(L["BTN_ORDERS_TAB"], 0))
    ordersTabBtn:SetPoint("TOPRIGHT", -18, -103)
    ordersTabBtn:SetScript("OnClick", function()
        if YellowPages.ToggleOrderQueueUI then
            YellowPages:ToggleOrderQueueUI()
        end
    end)
    mainFrame.ordersTabBtn = ordersTabBtn

    local shoppingTabBtn = Theme:CreateButton(mainFrame, 115, 22, string.format(L["BTN_SHOPPING_TAB"], 0))
    shoppingTabBtn:SetPoint("RIGHT", ordersTabBtn, "LEFT", -6, 0)
    shoppingTabBtn:SetScript("OnClick", function()
        if YellowPages.ToggleShoppingListUI then
            YellowPages:ToggleShoppingListUI()
        end
    end)
    mainFrame.shoppingTabBtn = shoppingTabBtn

    -- ========================================================================
    -- LINKES PANEL: REZEPTLISTE (mit Spaltenköpfen Stufe | Rezept | Handwerker)
    -- ========================================================================
    local leftContainer = Theme:CreateInsetPanel(mainFrame)
    leftContainer:SetPoint("TOPLEFT", 18, -130)
    leftContainer:SetPoint("BOTTOMLEFT", 18, 18)
    leftContainer:SetWidth(370)
    mainFrame.leftContainer = leftContainer

    -- Spalten-Überschriften (identisch zu Skill | Recipe | Crafts in FPT)
    local colLevel = leftContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colLevel:SetPoint("TOPLEFT", 14, -12)
    colLevel:SetText(L["COL_LEVEL"])
    colLevel:SetTextColor(unpack(Theme.FPT.gold))

    local colRecipe = leftContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colRecipe:SetPoint("TOPLEFT", 68, -12)
    colRecipe:SetText(L["COL_RECIPE"])
    colRecipe:SetTextColor(unpack(Theme.FPT.gold))

    local colCrafters = leftContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colCrafters:SetPoint("TOPRIGHT", -28, -12)
    colCrafters:SetText(L["COL_CRAFTERS"])
    colCrafters:SetTextColor(unpack(Theme.FPT.gold))

    local leftRule = leftContainer:CreateTexture(nil, "ARTWORK")
    leftRule:SetPoint("TOPLEFT", 10, -32)
    leftRule:SetPoint("TOPRIGHT", -12, -32)
    leftRule:SetHeight(1)
    leftRule:SetColorTexture(unpack(Theme.FPT.divider))

    local scrollFrame = CreateFrame("ScrollFrame", "YellowPagesRecipeScrollFrame", leftContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -36)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(334, 10)
    scrollFrame:SetScrollChild(scrollChild)
    mainFrame.scrollChild = scrollChild

    -- ========================================================================
    -- RECHTES PANEL: DETAILANSICHT, KOSTENÜBERSICHT & HANDWERKER
    -- ========================================================================
    local rightContainer = Theme:CreateInsetPanel(mainFrame)
    rightContainer:SetPoint("TOPLEFT", leftContainer, "TOPRIGHT", 10, 0)
    rightContainer:SetPoint("BOTTOMRIGHT", -18, 18)
    mainFrame.rightContainer = rightContainer

    YellowPages:BuildDetailPane(rightContainer)

    -- ========================================================================
    -- INFO-SEITE (wird über das Buch-Icon unten rechts geöffnet)
    -- ========================================================================
    local infoContainer = Theme:CreateInsetPanel(mainFrame)
    infoContainer:SetPoint("TOPLEFT", 18, -56)
    infoContainer:SetPoint("BOTTOMRIGHT", -18, 18)
    infoContainer:Hide()
    mainFrame.infoContainer = infoContainer

    YellowPages:BuildInfoPane(infoContainer)
    YellowPages:UpdateSideTabsAndHeader()

    mainFrame:Hide()
    return mainFrame
end

StaticPopupDialogs["YELLOWPAGES_CONFIRM_RESET_DB"] = {
    text = L["CONFIRM_RESET_DB"],
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function()
        YellowPages:ResetDatabase()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Baut die Info- & Anleitungs-Seite im "Forever Profession Trainer"-Look auf
function YellowPages:BuildInfoPane(parent)
    local bookIcon = parent:CreateTexture(nil, "ARTWORK")
    bookIcon:SetSize(38, 38)
    bookIcon:SetPoint("TOPLEFT", 22, -18)
    bookIcon:SetTexture(Theme.BOOK_ICON)

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", bookIcon, "TOPRIGHT", 14, -2)
    title:SetPoint("RIGHT", -24, 0)
    title:SetJustifyH("LEFT")
    title:SetText(L["INFO_TITLE"])
    title:SetTextColor(unpack(Theme.FPT.gold))

    local intro = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    intro:SetPoint("RIGHT", -24, 0)
    intro:SetJustifyH("LEFT")
    intro:SetText(L["INFO_INTRO"])
    intro:SetTextColor(unpack(Theme.FPT.text))

    local topRule = parent:CreateTexture(nil, "ARTWORK")
    topRule:SetPoint("TOPLEFT", 18, -78)
    topRule:SetPoint("TOPRIGHT", -18, -78)
    topRule:SetHeight(1)
    topRule:SetColorTexture(unpack(Theme.FPT.divider))

    local sections = {
        { icon = Theme.ALL_PROF_ICON,                       isHammer = true, title = L["INFO_SEC1_TITLE"], text = L["INFO_SEC1_TEXT"] },
        { icon = "Interface\\Icons\\INV_Misc_Coin_02",      isHammer = false, title = L["INFO_SEC2_TITLE"], text = L["INFO_SEC2_TEXT"] },
        { icon = "Interface\\Icons\\INV_Letter_15",         isHammer = false, title = L["INFO_SEC3_TITLE"], text = L["INFO_SEC3_TEXT"] },
        { icon = Theme.ORDERS_ICON,                         isHammer = false, title = L["INFO_SEC4_TITLE"], text = L["INFO_SEC4_TEXT"] },
        { icon = "Interface\\Icons\\INV_Misc_Note_01",      isHammer = false, title = L["INFO_SEC5_TITLE"], text = L["INFO_SEC5_TEXT"] },
    }

    local prevAnchor = topRule
    for idx, sec in ipairs(sections) do
        local secIcon = parent:CreateTexture(nil, "ARTWORK")
        secIcon:SetSize(24, 24)
        if idx == 1 then
            secIcon:SetPoint("TOPLEFT", 24, -92)
        else
            secIcon:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", -34, -14)
        end
        if sec.isHammer then
            Theme:ApplyHammerPickaxeIcon(secIcon)
        else
            secIcon:SetTexture(sec.icon)
        end

        local secTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        secTitle:SetPoint("TOPLEFT", secIcon, "TOPRIGHT", 10, -1)
        secTitle:SetPoint("RIGHT", -24, 0)
        secTitle:SetJustifyH("LEFT")
        secTitle:SetText(sec.title)
        secTitle:SetTextColor(unpack(Theme.FPT.current))

        local secBody = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        secBody:SetPoint("TOPLEFT", secTitle, "BOTTOMLEFT", 0, -5)
        secBody:SetPoint("RIGHT", -24, 0)
        secBody:SetJustifyH("LEFT")
        secBody:SetSpacing(3)
        secBody:SetText(sec.text)
        secBody:SetTextColor(unpack(Theme.FPT.text))

        prevAnchor = secBody
    end

    local backBtn = Theme:CreateButton(parent, 170, 26, L["BTN_BACK_TO_RECIPES"])
    backBtn:SetPoint("BOTTOM", -95, 16)
    backBtn:SetScript("OnClick", function()
        YellowPages:SetInfoPageShown(false)
    end)

    local resetBtn = Theme:CreateButton(parent, 170, 26, L["BTN_RESET_DB"])
    resetBtn:SetPoint("BOTTOM", 95, 16)
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("YELLOWPAGES_CONFIRM_RESET_DB")
    end)
end

-- Baut die rechte Detailansicht im "Forever Profession Trainer"-Stil auf
function YellowPages:BuildDetailPane(parent)
    local iconBtn = CreateFrame("Button", nil, parent)
    iconBtn:SetSize(38, 38)
    iconBtn:SetPoint("TOPLEFT", 14, -12)
    parent.iconBtn = iconBtn

    local recipeIcon = iconBtn:CreateTexture(nil, "ARTWORK")
    recipeIcon:SetAllPoints()
    recipeIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    parent.recipeIcon = recipeIcon

    iconBtn:SetScript("OnEnter", function(self)
        if not selectedRecipeID then return end
        local rec = YellowPages:GetRecipeInfo(selectedRecipeID)
        if not rec then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if rec.itemLink and rec.itemLink ~= "" then
            GameTooltip:SetHyperlink(rec.itemLink)
            GameTooltip:Show()
        elseif rec.itemID and rec.itemID > 0 then
            GameTooltip:SetItemByID(rec.itemID)
            GameTooltip:Show()
        end
    end)
    iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local recipeTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    recipeTitle:SetPoint("TOPLEFT", iconBtn, "TOPRIGHT", 10, -1)
    recipeTitle:SetPoint("RIGHT", -115, 0)
    recipeTitle:SetJustifyH("LEFT")
    recipeTitle:SetWordWrap(false)
    recipeTitle:SetText(L["SELECT_RECIPE"])
    parent.recipeTitle = recipeTitle

    local recipeProf = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    recipeProf:SetPoint("TOPLEFT", recipeTitle, "BOTTOMLEFT", 0, -4)
    recipeProf:SetTextColor(unpack(Theme.FPT.muted))
    parent.recipeProf = recipeProf

    -- Mengenauswahl: [ - ] 1 [ + ]
    local qtyLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qtyLabel:SetPoint("TOPRIGHT", -94, -18)
    qtyLabel:SetText(L["QTY_LABEL"])
    qtyLabel:SetTextColor(unpack(Theme.FPT.muted))

    local minusBtn = Theme:CreateButton(parent, 22, 20, "-")
    minusBtn:SetPoint("LEFT", qtyLabel, "RIGHT", 4, 0)

    local qtyText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qtyText:SetPoint("LEFT", minusBtn, "RIGHT", 6, 0)
    qtyText:SetText(tostring(currentQuantity))
    qtyText:SetTextColor(unpack(Theme.FPT.gold))
    parent.qtyText = qtyText

    local plusBtn = Theme:CreateButton(parent, 22, 20, "+")
    plusBtn:SetPoint("LEFT", qtyText, "RIGHT", 6, 0)

    minusBtn:SetScript("OnClick", function()
        if currentQuantity > 1 then
            currentQuantity = currentQuantity - 1
            qtyText:SetText(tostring(currentQuantity))
            YellowPages:UpdateDetailPane()
        end
    end)

    plusBtn:SetScript("OnClick", function()
        if currentQuantity < 100 then
            currentQuantity = currentQuantity + 1
            qtyText:SetText(tostring(currentQuantity))
            YellowPages:UpdateDetailPane()
        end
    end)

    -- Trennlinie 1 (warmes Braun-Gold)
    local dLine1 = parent:CreateTexture(nil, "ARTWORK")
    dLine1:SetPoint("TOPLEFT", 12, -56)
    dLine1:SetPoint("TOPRIGHT", -12, -56)
    dLine1:SetHeight(1)
    dLine1:SetColorTexture(unpack(Theme.FPT.divider))

    -- Kosten-Block im Stil der "Shopping List" aus Forever Profession Trainer (Screenshot 2)
    local vendorLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    vendorLabel:SetPoint("TOPLEFT", 14, -64)
    vendorLabel:SetText(L["VENDOR_COST_FMT"])
    vendorLabel:SetTextColor(unpack(Theme.FPT.muted))

    local vendorCostText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    vendorCostText:SetPoint("TOPRIGHT", -14, -64)
    vendorCostText:SetJustifyH("RIGHT")
    parent.vendorCostText = vendorCostText

    local ahLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ahLabel:SetPoint("TOPLEFT", 14, -82)
    ahLabel:SetText(L["AH_COST_FMT"])
    ahLabel:SetTextColor(unpack(Theme.FPT.muted))

    local ahCostText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ahCostText:SetPoint("TOPRIGHT", -14, -82)
    ahCostText:SetJustifyH("RIGHT")
    parent.ahCostText = ahCostText

    local costRule = parent:CreateTexture(nil, "ARTWORK")
    costRule:SetPoint("TOPLEFT", 14, -100)
    costRule:SetPoint("TOPRIGHT", -14, -100)
    costRule:SetHeight(1)
    costRule:SetColorTexture(0.36, 0.26, 0.15, 0.7)

    local totalLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalLabel:SetPoint("TOPLEFT", 14, -106)
    totalLabel:SetText(L["TOTAL_COST_FMT"])
    totalLabel:SetTextColor(unpack(Theme.FPT.text))

    local grandTotalText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    grandTotalText:SetPoint("TOPRIGHT", -14, -106)
    grandTotalText:SetJustifyH("RIGHT")
    parent.grandTotalText = grandTotalText

    local dLine2 = parent:CreateTexture(nil, "ARTWORK")
    dLine2:SetPoint("TOPLEFT", 12, -128)
    dLine2:SetPoint("TOPRIGHT", -12, -128)
    dLine2:SetHeight(1)
    dLine2:SetColorTexture(unpack(Theme.FPT.divider))

    -- Reagenzien-Kopfzeile (Required Materials | Have / Need)
    local matsHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    matsHeader:SetPoint("TOPLEFT", 14, -136)
    matsHeader:SetText(L["REAGENTS_HEADER"])
    matsHeader:SetTextColor(unpack(Theme.FPT.current))

    local haveNeedHdr = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    haveNeedHdr:SetPoint("TOPRIGHT", -115, -138)
    haveNeedHdr:SetText(L["COL_HAVE_NEED"])
    haveNeedHdr:SetTextColor(unpack(Theme.FPT.muted))

    -- ScrollFrame für Reagenzien
    local matsScrollFrame = CreateFrame("ScrollFrame", "YellowPagesMatsScroll", parent, "UIPanelScrollFrameTemplate")
    matsScrollFrame:SetPoint("TOPLEFT", 12, -156)
    matsScrollFrame:SetPoint("TOPRIGHT", -26, -156)
    matsScrollFrame:SetHeight(135)
    local matsChild = CreateFrame("Frame", nil, matsScrollFrame)
    matsChild:SetSize(360, 10)
    matsScrollFrame:SetScrollChild(matsChild)
    parent.matsChild = matsChild

    -- Trennlinie 3
    local dLine3 = parent:CreateTexture(nil, "ARTWORK")
    dLine3:SetPoint("TOPLEFT", 12, -298)
    dLine3:SetPoint("TOPRIGHT", -12, -298)
    dLine3:SetHeight(1)
    dLine3:SetColorTexture(unpack(Theme.FPT.divider))

    -- Handwerker-Titel
    local craftersHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    craftersHeader:SetPoint("TOPLEFT", 14, -306)
    craftersHeader:SetText(L["CRAFTERS_HEADER"])
    craftersHeader:SetTextColor(unpack(Theme.FPT.current))

    -- ScrollFrame für Handwerker
    local crafterScroll = CreateFrame("ScrollFrame", "YellowPagesCrafterScroll", parent, "UIPanelScrollFrameTemplate")
    crafterScroll:SetPoint("TOPLEFT", 12, -326)
    crafterScroll:SetPoint("BOTTOMRIGHT", -26, 10)
    local crafterChild = CreateFrame("Frame", nil, crafterScroll)
    crafterChild:SetSize(360, 10)
    crafterScroll:SetScrollChild(crafterChild)
    parent.crafterChild = crafterChild
end

-- Aktualisiert die Rezeptliste links (im Stil der Skill/Recipe/Crafts-Zeilen von FPT)
function YellowPages:RefreshRecipeList()
    if not mainFrame or not mainFrame.scrollChild then return end

    local scrollChild = mainFrame.scrollChild
    scrollChild.rows = scrollChild.rows or {}

    for _, row in ipairs(scrollChild.rows) do
        row:Hide()
    end

    local recipes = self:GetFilteredRecipes(
        selectedProfession,
        currentSearchQuery,
        onlyOnlineCrafters,
        currentSortBy,
        selectedQualityFilter,
        onlyAvailableCrafters
    )

    if mainFrame.statusText then
        local gName = self:GetGuildName() or L["NO_GUILD"]
        mainFrame.statusText:SetText(string.format(L["STATUS_BAR_TEXT"], gName, #recipes))
    end

    local yOffset = 0
    for i, item in ipairs(recipes) do
        local rData = item.recipe
        local row = scrollChild.rows[i]
        if not row then
            row = CreateFrame("Button", nil, scrollChild)
            row:SetSize(332, 34)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            row.bg = bg

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 0.82, 0.52, 0.09)
            row:SetHighlightTexture(hl)

            -- Linker goldener Auswahl-Balken (wie in Forever Profession Trainer Screenshot 2!)
            local marker = row:CreateTexture(nil, "ARTWORK")
            marker:SetPoint("TOPLEFT", 2, -5)
            marker:SetSize(2, 24)
            marker:SetColorTexture(0.84, 0.65, 0.34, 1)
            marker:Hide()
            row.marker = marker

            -- Spalte 1: Stufe (Level)
            local lvlText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lvlText:SetPoint("LEFT", 10, 0)
            lvlText:SetWidth(40)
            lvlText:SetJustifyH("LEFT")
            row.lvlText = lvlText

            -- Icon
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(24, 24)
            icon:SetPoint("LEFT", 52, 0)
            row.icon = icon

            -- Spalte 2: Rezeptname (+ Beruf falls "Alle Berufe" aktiv)
            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameText:SetPoint("LEFT", icon, "RIGHT", 8, 5)
            nameText:SetPoint("RIGHT", -92, 5)
            nameText:SetJustifyH("LEFT")
            nameText:SetWordWrap(false)
            row.nameText = nameText

            local profText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            profText:SetPoint("LEFT", icon, "RIGHT", 8, -8)
            profText:SetPoint("RIGHT", -92, -8)
            profText:SetJustifyH("LEFT")
            profText:SetWordWrap(false)
            profText:SetTextColor(unpack(Theme.FPT.muted))
            row.profText = profText

            -- Spalte 3: Handwerker-Anzahl
            local badge = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            badge:SetPoint("RIGHT", -6, 0)
            badge:SetJustifyH("RIGHT")
            row.badge = badge

            row:SetScript("OnEnter", function(self)
                local rec = self.recipeData
                if rec then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if rec.itemLink and rec.itemLink ~= "" then
                        GameTooltip:SetHyperlink(rec.itemLink)
                        GameTooltip:Show()
                    elseif rec.itemID and rec.itemID > 0 then
                        GameTooltip:SetItemByID(rec.itemID)
                        GameTooltip:Show()
                    end
                end
            end)

            row:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            row:SetScript("OnClick", function(self)
                selectedRecipeID = self.recipeID
                YellowPages:RefreshRecipeList()
                YellowPages:UpdateDetailPane()
            end)

            scrollChild.rows[i] = row
        end

        row:SetPoint("TOPLEFT", 2, yOffset)
        row.recipeID = rData.id
        row.recipeData = rData
        row.icon:SetTexture(rData.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        local isSelected = (selectedRecipeID == rData.id)
        row.marker:SetShown(isSelected)

        if isSelected then
            row.bg:SetColorTexture(0.78, 0.52, 0.20, 0.18)
        else
            row.bg:SetColorTexture(0.94, 0.76, 0.54, (i % 2 == 1) and 0.035 or 0)
        end

        local isUnlearned = (item.crafterCount == 0)
        if row.icon.SetDesaturated then
            row.icon:SetDesaturated(isUnlearned)
        end
        if isUnlearned then
            row.icon:SetVertexColor(0.45, 0.45, 0.45)
        else
            row.icon:SetVertexColor(1, 1, 1)
        end

        if item.level and item.level > 0 then
            row.lvlText:SetText(tostring(item.level))
            if isUnlearned and not isSelected then
                row.lvlText:SetTextColor(0.45, 0.45, 0.45)
            else
                row.lvlText:SetTextColor(unpack(isSelected and Theme.FPT.current or Theme.FPT.muted))
            end
        else
            row.lvlText:SetText("—")
            if isUnlearned and not isSelected then
                row.lvlText:SetTextColor(0.45, 0.45, 0.45)
            else
                row.lvlText:SetTextColor(unpack(Theme.FPT.muted))
            end
        end

        if isUnlearned then
            row.nameText:SetText("|cff7a7a7a" .. (rData.name or L["UNKNOWN"]) .. "|r")
            row.profText:SetText("|cff666666" .. (rData.prof or L["PROFESSION_FALLBACK"]) .. "|r")
            row.badge:SetText("|cff6e6e6e" .. string.format(L["CRAFTER_COUNT_FMT"], 0) .. "|r")
        else
            row.nameText:SetText(Theme:GetQualityColoredText(rData.name, item.quality))
            row.profText:SetText(rData.prof or L["PROFESSION_FALLBACK"])
            if item.hasOnlineCrafter then
                row.badge:SetText("|cff8fdcad" .. string.format(L["CRAFTER_COUNT_FMT"], item.crafterCount) .. "|r")
            else
                row.badge:SetText("|cffc2b091" .. string.format(L["CRAFTER_COUNT_FMT"], item.crafterCount) .. "|r")
            end
        end

        row:Show()
        yOffset = yOffset - 35
    end

    scrollChild:SetHeight(math.max(10, math.abs(yOffset)))

    if not selectedRecipeID and #recipes > 0 then
        selectedRecipeID = recipes[1].recipe.id
        YellowPages:UpdateDetailPane()
    end
end

-- Aktualisiert die Detailansicht rechts
function YellowPages:UpdateDetailPane()
    if not mainFrame or not mainFrame.rightContainer then return end
    local pane = mainFrame.rightContainer

    if not selectedRecipeID then
        pane.recipeTitle:SetText(L["SELECT_RECIPE"])
        pane.recipeProf:SetText("")
        return
    end

    local recipe = self:GetRecipeInfo(selectedRecipeID)
    if not recipe then return end

    local quality, level = self:ResolveRecipeMetadata(recipe)

    pane.recipeIcon:SetTexture(recipe.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    pane.recipeTitle:SetText(Theme:GetQualityColoredText(recipe.name, quality))

    local metaParts = { recipe.prof or L["GENERAL"] }
    if level and level > 0 then
        table.insert(metaParts, string.format(L["LEVEL_FMT"], level))
    end
    table.insert(metaParts, Theme:GetQualityLabel(quality))
    pane.recipeProf:SetText(table.concat(metaParts, "  ·  "))

    -- 1. Reagenzien und Kosten berechnen
    local costCalc = self:CalculateRecipeCost(recipe, currentQuantity, false)
    local matsChild = pane.matsChild
    matsChild.rows = matsChild.rows or {}
    for _, r in ipairs(matsChild.rows) do r:Hide() end

    local matY = 0
    for idx, mat in ipairs(costCalc.reagentsBreakdown) do
        local row = matsChild.rows[idx]
        if not row then
            row = CreateFrame("Frame", nil, matsChild)
            row:SetSize(355, 24)
            row:EnableMouse(true)

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(18, 18)
            icon:SetPoint("LEFT", 0, 0)
            row.icon = icon

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
            nameText:SetPoint("RIGHT", -155, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetWordWrap(false)
            row.nameText = nameText

            local invText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            invText:SetPoint("RIGHT", -95, 0)
            invText:SetJustifyH("RIGHT")
            row.invText = invText

            local priceText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            priceText:SetPoint("RIGHT", -2, 0)
            priceText:SetJustifyH("RIGHT")
            row.priceText = priceText

            row:SetScript("OnEnter", function(self)
                if self.itemID and self.itemID > 0 then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetItemByID(self.itemID)
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)

            matsChild.rows[idx] = row
        end

        row:SetPoint("TOPLEFT", 0, matY)
        row.itemID = mat.itemID
        row.icon:SetTexture(mat.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        local isVendor = (mat.source == "VENDOR" or mat.source == "VENDOR_ESTIMATE")
        local srcTag = isVendor and L["TAG_VENDOR"] or ""
        row.nameText:SetText(string.format("|cfff7ead1%s|r %s", mat.name, srcTag))

        local bagCount = self:GetBagItemCount(mat.itemID)
        local bankCount = self:GetBankItemCount(mat.itemID)
        local totalOwned = bagCount + bankCount

        if totalOwned >= mat.countNeeded then
            row.invText:SetText(string.format("|TInterface\\RaidFrame\\ReadyCheck-Ready:13:13:0:0|t |cff91c497%d/%d|r", totalOwned, mat.countNeeded))
        else
            row.invText:SetText(string.format("|TInterface\\RaidFrame\\ReadyCheck-NotReady:13:13:0:0|t |cffff736b%d/%d|r", totalOwned, mat.countNeeded))
        end

        row.priceText:SetText(self:FormatMoney(mat.lineTotal))

        row:Show()
        matY = matY - 24
    end
    matsChild:SetHeight(math.max(10, math.abs(matY)))

    pane.vendorCostText:SetText(self:FormatMoney(costCalc.totalVendor))
    pane.ahCostText:SetText(self:FormatMoney(costCalc.totalAH))
    pane.grandTotalText:SetText(self:FormatMoney(costCalc.grandTotal))

    -- 2. Handwerker-Liste
    local crafters = self:GetCraftersForRecipe(selectedRecipeID)
    local crafterChild = pane.crafterChild
    crafterChild.rows = crafterChild.rows or {}
    for _, r in ipairs(crafterChild.rows) do r:Hide() end

    local cY = 0
    for idx, c in ipairs(crafters) do
        local row = crafterChild.rows[idx]
        if not row then
            row = CreateFrame("Frame", nil, crafterChild)
            row:SetSize(355, 28)

            local statusDot = row:CreateTexture(nil, "ARTWORK")
            statusDot:SetSize(14, 14)
            statusDot:SetPoint("LEFT", 4, 0)
            row.statusDot = statusDot

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameText:SetPoint("LEFT", statusDot, "RIGHT", 6, 0)
            nameText:SetPoint("RIGHT", -125, 0)
            nameText:SetJustifyH("LEFT")
            row.nameText = nameText

            local skillText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            skillText:SetPoint("RIGHT", -96, 0)
            skillText:SetTextColor(unpack(Theme.FPT.muted))
            row.skillText = skillText

            local whisperBtn = Theme:CreateButton(row, 86, 22, L["BTN_REQUEST"])
            whisperBtn:SetPoint("RIGHT", -2, 0)
            row.whisperBtn = whisperBtn

            crafterChild.rows[idx] = row
        end

        row:SetPoint("TOPLEFT", 0, cY)

        if c.online then
            row.statusDot:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
            local displayName = Theme:GetClassColoredName(c.name, c.class)
            if c.isSelf then
                displayName = displayName .. " |cff91c497" .. L["YOU_TAG"] .. "|r"
            end
            row.whisperBtn:SetText(L["BTN_REQUEST"])
            row.nameText:SetText(displayName)
            row.whisperBtn:Enable()
            row.whisperBtn:SetScript("OnEnter", nil)
            row.whisperBtn:SetScript("OnLeave", nil)
        else
            row.statusDot:SetTexture("Interface\\FriendsFrame\\StatusIcon-Offline")
            row.nameText:SetText(string.format("|cffc2b091%s %s|r", c.name, L["OFFLINE_TAG"]))
            row.whisperBtn:SetText(L["BTN_REQUEST"])
            row.whisperBtn:Enable()
            row.whisperBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L["BTN_REQUEST"], unpack(Theme.FPT.gold))
                GameTooltip:AddLine(L["TT_REQUEST_OFFLINE"], 1, 1, 1, true)
                GameTooltip:Show()
            end)
            row.whisperBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        if c.rank and c.rank > 0 then
            row.skillText:SetText(string.format("(%d)", c.rank))
        else
            row.skillText:SetText("")
        end

        local crafterName = c.name
        local isOffline = (not c.online)
        row.whisperBtn:SetScript("OnClick", function()
            YellowPages:SendCraftOrder(crafterName, selectedRecipeID, currentQuantity, isOffline)
        end)

        row:Show()
        cY = cY - 30
    end
    crafterChild:SetHeight(math.max(10, math.abs(cY)))
end

-- Aktualisiert das gesamte UI
function YellowPages:RefreshUI()
    if mainFrame then
        if mainFrame.ordersTabBtn and self.GetActiveOrderCount then
            local openCount = self:GetActiveOrderCount()
            mainFrame.ordersTabBtn:SetText(string.format(L["BTN_ORDERS_TAB"], openCount))
        end
        if mainFrame.shoppingTabBtn and self.GetShoppingListCount then
            local shopCount = self:GetShoppingListCount()
            mainFrame.shoppingTabBtn:SetText(string.format(L["BTN_SHOPPING_TAB"], shopCount))
        end
        self:UpdateSideTabsAndHeader()
        if mainFrame:IsShown() then
            self:RefreshRecipeList()
            self:UpdateDetailPane()
        end
    end
end

-- Schaltet das Hauptfenster ein/aus
function YellowPages:ToggleUI()
    local f = self:CreateMainFrame()
    if f:IsShown() then
        f:Hide()
    else
        self:UpdateGuildMembersStatus()
        if f.ordersTabBtn and self.GetActiveOrderCount then
            local openCount = self:GetActiveOrderCount()
            f.ordersTabBtn:SetText(string.format(L["BTN_ORDERS_TAB"], openCount))
        end
        if f.shoppingTabBtn and self.GetShoppingListCount then
            local shopCount = self:GetShoppingListCount()
            f.shoppingTabBtn:SetText(string.format(L["BTN_SHOPPING_TAB"], shopCount))
        end
        self:UpdateSideTabsAndHeader()
        self:RefreshRecipeList()
        self:UpdateDetailPane()
        f:Show()
    end
end
