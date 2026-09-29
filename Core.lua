local addonName, addonTable = ...

-- Varsayılan Ayarlar
local defaultOptions = {
    MobEnabled = true,
    ZoneEnabled = true,
    Debug = false
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Veritabanı ve ayarların belleğe yüklenmesi
        WowTR_Options = WowTR_Options or defaultOptions
        WowTR_DiscoveredMobs = WowTR_DiscoveredMobs or {}
        WowTR_DiscoveredZones = WowTR_DiscoveredZones or {}
    elseif event == "PLAYER_LOGIN" then
        self:InitializeOptionsPanel()
        self:SetupHooks()
    end
end)

function frame:SetupHooks()
    -- 1. Minimap Bölge İsmi Hook
    local isUpdatingMinimap = false
    hooksecurefunc(MinimapZoneText, "SetText", function(self, text)
        if isUpdatingMinimap or not WowTR_Options.ZoneEnabled or not text or text == "" then return end
        
        local translated = ZoneTranslator_ZoneData[text]
        if translated then
            isUpdatingMinimap = true
            self:SetText(translated)
            isUpdatingMinimap = false
        else
            -- Veritabanında yoksa yeni liste oluşturup içini boş bırakarak kaydet
            if not WowTR_DiscoveredZones[text] then
                WowTR_DiscoveredZones[text] = ""
                if WowTR_Options.Debug then
                    print("|cFF00FFFF[WowTR-Zone]|r Yeni bölge kaydedildi: " .. text)
                end
            end
        end
    end)

    -- 2. Tooltip (Mob/NPC) Hook (Güncel Retail API'si)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(self)
        if not WowTR_Options.MobEnabled then return end
        if self == GameTooltip then
            local _, unit = self:GetUnit()
            if unit then
                local name = UnitName(unit)
                if name then
                    local translated = MobNpcTranslator_Data[name]
                    if translated then
                        local line1 = _G[self:GetName().."TextLeft1"]
                        if line1 then
                            line1:SetText(translated)
                        end
                    else
                        -- Veritabanında yoksa keşfedilenlere ekle
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
                    local translated = MobNpcTranslator_Data[name]
                    if translated then
                        -- Güncel Retail (Dragonflight / The War Within vb.) arayüz yapısı
                        if self.TargetFrameContent and self.TargetFrameContent.TargetFrameContentMain and self.TargetFrameContent.TargetFrameContentMain.Name then
                            self.TargetFrameContent.TargetFrameContentMain.Name:SetText(translated)
                        -- Classic ve eski sürümler için varsayılan yapı
                        elseif self.name then
                            self.name:SetText(translated)
                        end
                    end
                end
            end
        end
    end)
end

-- Arayüz Ayarları (Interface -> AddOns kısmı için)
function frame:InitializeOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "WowTR Çeviri"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("WowTR - Ayarlar")

    -- Mob/NPC Checkbox
    local mobCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    mobCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    mobCheck.Text:SetText("Mob/NPC Çevirilerini Aktifleştir")
    mobCheck:SetChecked(WowTR_Options.MobEnabled)
    mobCheck:SetScript("OnClick", function(self)
        WowTR_Options.MobEnabled = self:GetChecked()
    end)

    -- Zone Checkbox
    local zoneCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    zoneCheck:SetPoint("TOPLEFT", mobCheck, "BOTTOMLEFT", 0, -10)
    zoneCheck.Text:SetText("Bölge (Minimap) Çevirilerini Aktifleştir")
    zoneCheck:SetChecked(WowTR_Options.ZoneEnabled)
    zoneCheck:SetScript("OnClick", function(self)
        WowTR_Options.ZoneEnabled = self:GetChecked()
    end)

    -- Modern WoW için kategori kaydı
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
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
        print("|cFF00FF00[WowTR] Komutlar:|r")
        print("/wowtr-mnz mob - Mob çevirisini aç/kapat")
        print("/wowtr-mnz zone - Bölge çevirisini aç/kapat")
        print("/wowtr-mnz debug - Geliştirici modunu aç/kapat")
    end
end