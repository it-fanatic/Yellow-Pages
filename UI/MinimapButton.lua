--[[
    Yellow-Pages: MinimapButton.lua
    Frei ziehbarer Minimap-Button für schnellen Zugriff
--]]

YellowPages = YellowPages or {}
local L = YellowPages.L

function YellowPages:InitMinimap()
    if self.MinimapBtn then return end

    local btn = CreateFrame("Button", "YellowPagesMinimapButton", Minimap)
    self.MinimapBtn = btn

    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 0)
    if YellowPages.Theme and YellowPages.Theme.ApplyHammerPickaxeIcon then
        YellowPages.Theme:ApplyHammerPickaxeIcon(icon)
    else
        icon:SetTexture("Interface\\Icons\\UI_Profession_Icon")
    end
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local function UpdatePosition(angle)
        local rad = math.rad(angle or 195)
        local cos, sin = math.cos(rad), math.sin(rad)
        local w = (Minimap and Minimap:GetWidth() and Minimap:GetWidth() > 0) and Minimap:GetWidth() or 190
        local radius = (w / 2) + 10
        if radius < 80 then radius = 80 end
        local x = cos * radius
        local y = sin * radius
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            local angle = math.deg(math.atan2(py - my, px - mx))
            if angle < 0 then angle = angle + 360 end

            YellowPagesDB.settings.minimapPos = angle
            UpdatePosition(angle)
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if IsShiftKeyDown() then
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
        elseif button == "RightButton" then
            YellowPages:ScanCurrentTradeSkill(true)
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["MINIMAP_TITLE"])
        GameTooltip:AddLine(L["MINIMAP_SUBTITLE"], 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["MINIMAP_LEFT_CLICK"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["MINIMAP_RIGHT_CLICK"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["MINIMAP_SHIFT_CLICK"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local savedAngle = YellowPagesDB and YellowPagesDB.settings and YellowPagesDB.settings.minimapPos or 195
    UpdatePosition(savedAngle)
end
