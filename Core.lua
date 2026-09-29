local addonName, addonTable = ...

-- Versiyon bilgisi (.toc dosyasından otomatik alınır)
local addonVersion = C_AddOns.GetAddOnMetadata(addonName, "Version") or "1.0"

-- Varsayılan Ayarlar
local defaultOptions = {
    MobEnabled = true,
    ZoneEnabled = true,
    Debug = false,
    MinimapPos = 225 -- Minimap ikonunun varsayılan açısı
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        WowTR_Options = WowTR_Options or defaultOptions
        WowTR_DiscoveredMobs = WowTR_DiscoveredMobs or {}
        WowTR_DiscoveredZones = WowTR_DiscoveredZones or {}
    elseif event == "PLAYER_LOGIN" then
        self:InitializeOptionsPanel()
        self:CreateMinimapButton()
        self:SetupHooks()
    end
end)

function frame:SetupHooks()
    -- 1. Minimap Bölge İsmi Hook
    local isUpdatingMinimap = false
    hooksecurefunc(MinimapZoneText, "SetText", function(self, text)
        if isUpdatingMinimap or not WowTR_Options.ZoneEnabled or not text or text == "" then return end
        
        local translated = ZoneTranslator_ZoneData and ZoneTranslator_ZoneData[text]
        
        if translated and translated ~= "" then
            isUpdatingMinimap = true
            self:SetText(translated)
            isUpdatingMinimap = false
        else
            if not WowTR_DiscoveredZones[text] then
                WowTR_DiscoveredZones[text] = ""
                if WowTR_Options.Debug then
                    print("|cFF00FFFF[WowTR-Zone]|r Yeni bölge kaydedildi: " .. text)
                end
            end
        end
    end)

    -- 2. Tooltip (Mob/NPC) Hook
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(self)
        if not WowTR_Options.MobEnabled then return end
        if self == GameTooltip then
            local _, unit = self:GetUnit()
            if unit then
                local name = UnitName(unit)
                if name then
                    local translated = MobNpcTranslator_Data and MobNpcTranslator_Data[name]
                    
                    if translated and translated ~= "" then
                        local line1 = _G[self:GetName().."TextLeft1"]
                        if line1 then
                            line1:SetText(translated)
                        end
                    else
                        if not WowTR_DiscoveredMobs[name] then
                            WowTR_DiscoveredMobs[name] = ""
                            if WowTR_Options.Debug then
                                print("|cFFFFFF00[WowTR-Mob]|r Yeni Mob/NPC kaydedildi: " .. name)
                            end
                        end
                    end
                end
            end
        end
    end)

    -- 3. Hedef Çerçevesi (Target Frame) Çevirisi
    TargetFrame:HookScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_TARGET_CHANGED" or event == "UNIT_NAME_UPDATE" or event == "UNIT_FACTION" then
            if WowTR_Options.MobEnabled then
                local name = UnitName("target")
                if name then
                    local translated = MobNpcTranslator_Data and MobNpcTranslator_Data[name]
                    
                    if translated and translated ~= "" then
                        if self.TargetFrameContent and self.TargetFrameContent.TargetFrameContentMain and self.TargetFrameContent.TargetFrameContentMain.Name then
                            self.TargetFrameContent.TargetFrameContentMain.Name:SetText(translated)
                        elseif self.name then
                            self.name:SetText(translated)
                        end
                    end
                end
            end
        end
    end)
end

-- Arayüz / Ayarlar Penceresi
function frame:InitializeOptionsPanel()
    local optionsFrame = CreateFrame("Frame", "WowTR_OptionsFrame", UIParent, "BasicFrameTemplateWithInset")
    optionsFrame:SetSize(320, 240)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
    optionsFrame:Hide() -- Varsayılan olarak kapalı

    optionsFrame.title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    optionsFrame.title:SetPoint("LEFT", optionsFrame.TitleBg, "LEFT", 6, 1)
    optionsFrame.title:SetText("WowTR Çeviri Ayarları")

    -- Mob/NPC Checkbox
    local mobCheck = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
    mobCheck:SetPoint("TOPLEFT", 20, -40)
    mobCheck.text = mobCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mobCheck.text:SetPoint("LEFT", mobCheck, "RIGHT", 5, 0)
    mobCheck.text:SetText("Mob/NPC Çevirilerini Aktifleştir")
    mobCheck:SetChecked(WowTR_Options.MobEnabled)
    mobCheck:SetScript("OnClick", function(self)
        WowTR_Options.MobEnabled = self:GetChecked()
    end)

    -- Zone Checkbox
    local zoneCheck = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
    zoneCheck:SetPoint("TOPLEFT", mobCheck, "BOTTOMLEFT", 0, -10)
    zoneCheck.text = zoneCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoneCheck.text:SetPoint("LEFT", zoneCheck, "RIGHT", 5, 0)
    zoneCheck.text:SetText("Bölge (Minimap) Çevirilerini Aktifleştir")
    zoneCheck:SetChecked(WowTR_Options.ZoneEnabled)
    zoneCheck:SetScript("OnClick", function(self)
        WowTR_Options.ZoneEnabled = self:GetChecked()
    end)

    -- Debug Checkbox
    local debugCheck = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", zoneCheck, "BOTTOMLEFT", 0, -10)
    debugCheck.text = debugCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugCheck.text:SetPoint("LEFT", debugCheck, "RIGHT", 5, 0)
    debugCheck.text:SetText("Geliştirici (Debug) Modu")
    debugCheck:SetChecked(WowTR_Options.Debug)
    debugCheck:SetScript("OnClick", function(self)
        WowTR_Options.Debug = self:GetChecked()
    end)

    -- ESC İle Kapanma Desteği
    table.insert(UISpecialFrames, "WowTR_OptionsFrame")
    
    self.optionsFrame = optionsFrame
end


-- Minimap İkonu
function frame:CreateMinimapButton()
    local btn = CreateFrame("Button", "WowTR_MinimapButton", Minimap)
    btn:SetFrameStrata("MEDIUM")
    btn:SetSize(31, 31)
    btn:SetFrameLevel(8)

    -- İkon Görseli
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\UI_Chat")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    btn.icon = icon

    -- Çerçeve Çemberi
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    -- Minimap Dış Çeper Pozisyon Hesabı (Radius = 102 dış çeper için uygundur)
    local radius = 102
    local function UpdatePosition()
        local angle = math.rad(WowTR_Options.MinimapPos or 225)
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    local isDragging = false

    -- Sol Tık ile Sürükleme ve Tıklama Yönetimi
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp")

    btn:SetScript("OnDragStart", function(self)
        isDragging = true
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            WowTR_Options.MinimapPos = angle
            UpdatePosition()
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        -- Sürükleme bittiğinde tıklama tetiklenmesin diye ufak bir gecikme
        C_Timer.After(0.1, function() isDragging = false end)
    end)

    -- Tıklama Olayı (Sol Tık = Ayarları Aç/Kapat, Sürükleniyorsa Açmaz)
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and not isDragging then
            if frame.optionsFrame:IsShown() then
                frame.optionsFrame:Hide()
            else
                frame.optionsFrame:Show()
            end
        end
    end)

    -- İkon Üzerine Gelince Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("WowTR-Mob-Npc-Zone " .. addonVersion, 1, 0.82, 0)
        GameTooltip:AddLine("|cFF00FF00Sol Tık:|r Ayarlar Sayfasını Aç", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cFFFFFF00Sol Tık & Sürükle:|r İkonu Taşı", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdatePosition()
end

-- Slash Komutları
SLASH_WOWTRMNZ1 = "/wowtr-mnz"
SlashCmdList["WOWTRMNZ"] = function(msg)
    msg = string.lower(msg)
    if msg == "debug" then
        WowTR_Options.Debug = not WowTR_Options.Debug
        print("|cFF00FF00[WowTR]|r Debug Modu: " .. (WowTR_Options.Debug and "AÇIK" or "KAPALI"))
    elseif msg == "mob" then
        WowTR_Options.MobEnabled = not WowTR_Options.MobEnabled
        print("|cFF00FF00[WowTR]|r Mob Çevirisi: " .. (WowTR_Options.MobEnabled and "AÇIK" or "KAPALI"))
    elseif msg == "zone" then
        WowTR_Options.ZoneEnabled = not WowTR_Options.ZoneEnabled
        print("|cFF00FF00[WowTR]|r Bölge Çevirisi: " .. (WowTR_Options.ZoneEnabled and "AÇIK" or "KAPALI"))
    else
        if frame.optionsFrame:IsShown() then
            frame.optionsFrame:Hide()
        else
            frame.optionsFrame:Show()
        end
    end
end