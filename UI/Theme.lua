--[[
    Yellow-Pages: Theme.lua
    Farbpalette, Backdrops, Inset-Panels & Seiten-Tabs im Stil von "Forever Profession Trainer"
--]]

YellowPages = YellowPages or {}
YellowPages.Theme = {}

local L = YellowPages.L
local Theme = YellowPages.Theme

-- Authentische "Forever Profession Trainer" Farbpalette (warmes Braun & Gold)
Theme.FPT = {
    text           = { 0.97, 0.92, 0.82 },
    gold           = { 1.00, 0.82, 0.30 },
    muted          = { 0.76, 0.69, 0.57 },
    tabNeutral     = { 1.00, 1.00, 1.00 },
    current        = { 0.95, 0.79, 0.47 },
    red            = { 1.00, 0.45, 0.42 },
    green          = { 0.56, 0.86, 0.68 },
    complete       = { 0.57, 0.77, 0.59 },
    window         = { 0.105, 0.079, 0.054, 1 },
    windowBorder   = { 0.94, 0.73, 0.43, 1 },
    panelBg        = { 0.085, 0.061, 0.041, 1 },
    panelBorder    = { 0.72, 0.54, 0.31, 1 },
    gradBottom     = { 0.16, 0.115, 0.078, 1 },
    gradTop        = { 0.085, 0.061, 0.041, 1 },
    divider        = { 0.38, 0.28, 0.15, 0.85 },
}

Theme.Colors = {
    GoldPrimary    = { r = 1.00, g = 0.82, b = 0.30, hex = "ffd14c" },
    GoldDark       = { r = 0.78, g = 0.61, b = 0.00, hex = "c79c00" },
    BackgroundDark = { r = 0.105, g = 0.079, b = 0.054, a = 0.98 },
    ContentBg      = { r = 0.085, g = 0.061, b = 0.041, a = 1.00 },
    BorderGold     = { r = 0.94, g = 0.73, b = 0.43, a = 1.00 },
    BorderDim      = { r = 0.72, g = 0.54, b = 0.31, a = 1.00 },
    TextWhite      = { r = 0.97, g = 0.92, b = 0.82, hex = "f7ead1" },
    TextYellow     = { r = 1.00, g = 0.82, b = 0.30, hex = "ffd14c" },
    TextMuted      = { r = 0.76, g = 0.69, b = 0.57, hex = "c2b091" },
    GreenOnline    = { r = 0.56, g = 0.86, b = 0.68, hex = "8fdcad" },
    RedOffline     = { r = 1.00, g = 0.45, b = 0.42, hex = "ff736b" },
}

Theme.CLASS_COLORS = {
    WARRIOR     = "C79C6E",
    PALADIN     = "F58CBA",
    HUNTER      = "ABD473",
    ROGUE       = "FFF569",
    PRIEST      = "FFFFFF",
    DEATHKNIGHT = "C41F3B",
    SHAMAN      = "0070DE",
    MAGE        = "69CCF0",
    WARLOCK     = "9482C9",
    DRUID       = "FF7D0A",
    MONK        = "00FF96",
    DEMONHUNTER = "A330C9",
    EVOKER      = "33937F",
}

Theme.QUALITY_INFO = {
    [0] = { hex = "9d9d9d", localeKey = "QUALITY_0" },
    [1] = { hex = "f7ead1", localeKey = "QUALITY_1" },
    [2] = { hex = "1eff00", localeKey = "QUALITY_2" },
    [3] = { hex = "0070dd", localeKey = "QUALITY_3" },
    [4] = { hex = "a335ee", localeKey = "QUALITY_4" },
    [5] = { hex = "ff8000", localeKey = "QUALITY_5" },
}

-- Berufs-Icons für Portrait und rechte Seiten-Tabs
-- Hammer & Pickel aus dem Berufe-Fenster (Alle Berufe + Minimap) & Buch-Icon für die Info-Seite
Theme.ALL_PROF_ICON = "Interface\\Icons\\UI_Profession_Icon"
Theme.BOOK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
Theme.ORDERS_ICON = "Interface\\Icons\\INV_Scroll_03"
Theme.SHOPPING_ICON = "Interface\\Icons\\INV_Misc_Coin_01"

local registeredHammerTextures = {}
local cachedHammerAtlas = nil
local cachedHammerTex = nil
local cachedHammerCoords = nil

local function DiscoverProfessionsOverviewIcon()
    if cachedHammerAtlas or cachedHammerTex then return true end
    if not ProfessionsFrame then
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
        elseif LoadAddOn then
            pcall(LoadAddOn, "Blizzard_Professions")
        end
    end
    local src = ProfessionsFrame and ProfessionsFrame.ProfessionsOverviewTab and ProfessionsFrame.ProfessionsOverviewTab.Icon
    if not src and ProfessionsFrame and ProfessionsFrame.PortraitContainer then
        src = ProfessionsFrame.PortraitContainer.portrait
    end
    if src then
        local okA, atlas = pcall(src.GetAtlas, src)
        if okA and atlas and atlas ~= "" then
            cachedHammerAtlas = atlas
            return true
        end
        local okT, tex = pcall(src.GetTexture, src)
        if okT and tex and tex ~= "" then
            cachedHammerTex = tex
            local okC, ulx, uly, llx, lly, urx, ury, lrx, lry = pcall(src.GetTexCoord, src)
            if okC and ulx then
                cachedHammerCoords = { ulx, uly, llx, lly, urx, ury, lrx, lry }
            end
            return true
        end
    end
    return false
end

function Theme:ApplyHammerPickaxeIcon(texObj)
    if not texObj then return end
    registeredHammerTextures[texObj] = true
    DiscoverProfessionsOverviewIcon()

    if cachedHammerAtlas and texObj.SetAtlas then
        texObj:SetTexCoord(0, 1, 0, 1)
        pcall(texObj.SetAtlas, texObj, cachedHammerAtlas)
    elseif cachedHammerTex then
        texObj:SetTexture(cachedHammerTex)
        if cachedHammerCoords then
            texObj:SetTexCoord(unpack(cachedHammerCoords))
        else
            texObj:SetTexCoord(0, 1, 0, 1)
        end
    else
        texObj:SetTexCoord(0, 1, 0, 1)
        texObj:SetTexture(self.ALL_PROF_ICON)
    end
end

function Theme:ApplyTextureOrProfessionIcon(texObj, profKey)
    if not texObj then return end
    if not profKey or profKey == "ALL" then
        self:ApplyHammerPickaxeIcon(texObj)
        return
    end
    registeredHammerTextures[texObj] = nil
    texObj:SetTexCoord(0, 1, 0, 1)
    if profKey == "INFO" then
        texObj:SetTexture(self.BOOK_ICON)
    else
        texObj:SetTexture(self:GetProfessionIcon(profKey))
    end
end

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
    pcall(EventUtil.ContinueOnAddOnLoaded, "Blizzard_Professions", function()
        if DiscoverProfessionsOverviewIcon() then
            for texObj in pairs(registeredHammerTextures) do
                Theme:ApplyHammerPickaxeIcon(texObj)
            end
        end
    end)
end

function Theme:GetProfessionTabsList()
    return {
        -- Alle Berufe (Hammer & Pickel Icon wie im Berufe-Fenster links)
        { key = "ALL",                       label = L["ALL_PROFESSIONS"],       icon = self.ALL_PROF_ICON, isHammer = true },
        -- Herstellungsberufe
        { key = L["PROF_ALCHEMY"],           label = L["PROF_ALCHEMY"],          icon = "Interface\\Icons\\Trade_Alchemy" },
        { key = L["PROF_BLACKSMITHING"],     label = L["PROF_BLACKSMITHING"],    icon = "Interface\\Icons\\Trade_BlackSmithing" },
        { key = L["PROF_ENCHANTING"],        label = L["PROF_ENCHANTING"],       icon = "Interface\\Icons\\Trade_Engraving" },
        { key = L["PROF_ENGINEERING"],       label = L["PROF_ENGINEERING"],      icon = "Interface\\Icons\\Trade_Engineering" },
        { key = L["PROF_LEATHERWORKING"],    label = L["PROF_LEATHERWORKING"],   icon = "Interface\\Icons\\Trade_LeatherWorking" },
        { key = L["PROF_TAILORING"],         label = L["PROF_TAILORING"],        icon = "Interface\\Icons\\Trade_Tailoring" },
        -- Sammelberufe (Kräuterkunde, Bergbau, Kürschnerei)
        { key = L["PROF_HERBALISM"],         label = L["PROF_HERBALISM"],        icon = "Interface\\Icons\\Spell_Nature_NatureTouchGrow" },
        { key = L["PROF_MINING"],            label = L["PROF_MINING"],           icon = "Interface\\Icons\\Trade_Mining" },
        { key = L["PROF_SKINNING"],          label = L["PROF_SKINNING"],         icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
        -- Nebenberufe
        { key = L["PROF_COOKING"],           label = L["PROF_COOKING"],          icon = "Interface\\Icons\\INV_Misc_Food_15" },
        { key = L["PROF_FIRSTAID"],          label = L["PROF_FIRSTAID"],         icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
    }
end

function Theme:GetProfessionIcon(profKey)
    if not profKey or profKey == "ALL" then return self.ALL_PROF_ICON end
    if profKey == "INFO" then return self.BOOK_ICON end
    for _, p in ipairs(self:GetProfessionTabsList()) do
        if p.key == profKey then return p.icon end
    end
    if profKey == L["PROF_JEWELCRAFTING"] then return "Interface\\Icons\\INV_Misc_Gem_01" end
    if profKey == L["PROF_INSCRIPTION"] then return "Interface\\Icons\\INV_Inscription_Tradeskill01" end
    if profKey == L["PROF_HERBALISM"] then return "Interface\\Icons\\Trade_Herbalism" end
    if profKey == L["PROF_SKINNING"] then return "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" end
    return self.ALL_PROF_ICON
end

function Theme:TintGradient(texture, bottom, top)
    if texture and texture.SetGradient and CreateColor then
        texture:SetColorTexture(1, 1, 1, 1)
        texture:SetGradient("VERTICAL", CreateColor(unpack(bottom)), CreateColor(unpack(top)))
    end
end

-- Erstellt ein Inset-Panel im warmen Braun-Gold-Stil von Forever Profession Trainer
function Theme:CreateInsetPanel(parent)
    local panel = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
    self:ApplyBackdrop(panel,
        self.FPT.panelBg[1], self.FPT.panelBg[2], self.FPT.panelBg[3], 1.0,
        self.FPT.panelBorder[1], self.FPT.panelBorder[2], self.FPT.panelBorder[3], 1.0
    )
    local shading = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    shading:SetPoint("TOPLEFT", 4, -4)
    shading:SetPoint("BOTTOMRIGHT", -4, 4)
    shading:SetColorTexture(0.10, 0.074, 0.051, 1)
    self:TintGradient(shading, self.FPT.gradBottom, self.FPT.gradTop)
    panel.shading = shading
    return panel
end

-- Erstellt einen Seiten-Tab am rechten Fensterrand (nutzt LargeSideTabButtonTemplate aus Forever)
function Theme:CreateSideTab(parent, iconPath, onClick)
    local ok, tab = pcall(CreateFrame, "Frame", nil, parent, "LargeSideTabButtonTemplate")
    if ok and tab and tab.Icon then
        tab:EnableMouse(true)
        if tab.SetFillToInterior then tab:SetFillToInterior(true) end
        if tab.SetChecked then tab:SetChecked(false) end
        tab.Icon:SetTexture(iconPath)
        if tab.Background then
            tab.Background:SetDesaturated(true)
        end
        if tab.SetCustomOnMouseUpHandler then
            tab:SetCustomOnMouseUpHandler(function(self, button, upInside)
                if button == "LeftButton" and upInside then onClick(self) end
            end)
        else
            tab:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" then onClick(self) end
            end)
        end
        tab:HookScript("OnHide", function(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
    else
        -- Fallback falls LargeSideTabButtonTemplate nicht vorhanden ist
        tab = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
        tab:SetSize(42, 42)
        self:ApplyBackdrop(tab, 0.12, 0.09, 0.06, 0.98, 0.85, 0.68, 0.32, 1.0)
        local ic = tab:CreateTexture(nil, "ARTWORK")
        ic:SetSize(28, 28)
        ic:SetPoint("CENTER")
        ic:SetTexture(iconPath)
        tab.Icon = ic
        tab:SetScript("OnClick", onClick)
        tab.SetChecked = function(self, checked)
            if checked then
                self:SetBackdropBorderColor(1.0, 0.82, 0.30, 1.0)
            else
                self:SetBackdropBorderColor(0.55, 0.42, 0.25, 1.0)
            end
        end
    end

    -- Kleines Badge für Zähler (z.B. offene Aufträge oder Einkaufsliste)
    local badgeBg = tab:CreateTexture(nil, "OVERLAY", nil, 6)
    badgeBg:SetSize(18, 16)
    badgeBg:SetPoint("BOTTOMRIGHT", -2, 2)
    badgeBg:SetColorTexture(0.15, 0.08, 0.04, 0.92)
    badgeBg:Hide()
    tab.badgeBg = badgeBg

    local badgeText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badgeText:SetPoint("CENTER", badgeBg, "CENTER", 0, 0)
    badgeText:SetTextColor(1.0, 0.85, 0.25)
    badgeText:Hide()
    tab.badgeText = badgeText

    function tab:SetBadgeCount(count)
        if count and count > 0 then
            self.badgeText:SetText(tostring(count))
            self.badgeBg:Show()
            self.badgeText:Show()
        else
            self.badgeBg:Hide()
            self.badgeText:Hide()
        end
    end

    return tab
end

function Theme:GetQualityColoredText(text, quality)
    if not text then return "" end
    local qInfo = self.QUALITY_INFO[quality or 1] or self.QUALITY_INFO[1]
    return string.format("|cff%s%s|r", qInfo.hex, text)
end

function Theme:GetQualityLabel(quality)
    local qInfo = self.QUALITY_INFO[quality or 1] or self.QUALITY_INFO[1]
    local qName = L[qInfo.localeKey] or qInfo.localeKey
    return string.format("|cff%s%s|r", qInfo.hex, qName)
end

-- Erstellt einen abwärtskompatiblen Backdrop-Rahmen im warmen Braun-Gold-Look
function Theme:ApplyBackdrop(frame, bgR, bgG, bgB, bgA, edgeR, edgeG, edgeB, edgeA, isMainWindow)
    if not frame then return end
    if not frame.SetBackdrop and BackdropTemplateMixin and Mixin then
        pcall(Mixin, frame, BackdropTemplateMixin)
    end

    local backdropInfo = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = isMainWindow and "Interface\\DialogFrame\\UI-DialogBox-Border" or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = isMainWindow and 24 or 12,
        insets = isMainWindow and { left = 5, right = 5, top = 5, bottom = 5 } or { left = 3, right = 3, top = 3, bottom = 3 }
    }

    local defBg = self.FPT.window
    local defEdge = isMainWindow and self.FPT.windowBorder or self.FPT.panelBorder

    if frame.SetBackdrop then
        frame:SetBackdrop(backdropInfo)
        frame:SetBackdropColor(bgR or defBg[1], bgG or defBg[2], bgB or defBg[3], bgA or 1.0)
        frame:SetBackdropBorderColor(edgeR or defEdge[1], edgeG or defEdge[2], edgeB or defEdge[3], edgeA or 1.0)
    else
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(bgR or defBg[1], bgG or defBg[2], bgB or defBg[3], bgA or 1.0)
    end
end

function Theme:CreateButton(parent, width, height, text)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, height)
    btn:SetText(text or "")

    local fs = btn:GetFontString()
    if fs then
        fs:SetTextColor(0.97, 0.92, 0.82)
    end

    return btn
end

function Theme:GetClassColoredName(name, classEn)
    if not name then return L["UNKNOWN"] end
    local colorHex = self.CLASS_COLORS[classEn] or "ffd100"
    return string.format("|cff%s%s|r", colorHex, name)
end
