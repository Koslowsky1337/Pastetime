-- Pastime: Einstellungen im Blizzard-Menü (Optionen → AddOns → Pastime)
-- Alle Werte laufen über Proxy-Einstellungen direkt auf PastimeDB, damit
-- Fenster, Befehle und Optionsmenü immer denselben Stand zeigen.
local ADDON, ns = ...
local L = ns.L

local category
local settings = {}

local OPTIONS = {
    { key = "autoOpen", tip = L["Opens the game collection when you take off from a flight master and while you wait at a zeppelin tower or boat dock. If you didn't play, it closes again when you arrive."] },
    { key = "landAlarm", tip = L["On landing or arrival: pause the game, play a sound and show a large notice – then keep playing or finish and score."] },
    { key = "hideInCombat", tip = L["The window hides as soon as you enter combat (the game always pauses)."] },
    { key = "sound", tip = L["Sounds for points, lines and game over."] },
}

local function Changed()
    if ns.UpdateUI then ns.UpdateUI() end
end

function ns.CreateSettings()
    if category then return category end
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting) then
        ns.Log("W", "options", "Settings API missing – no options panel")
        return nil
    end
    category = Settings.RegisterVerticalLayoutCategory("Pastime")

    for _, o in ipairs(OPTIONS) do
        local key = o.key
        local s = Settings.RegisterProxySetting(category, "PASTIME_" .. key:upper(), "boolean",
            ns.SETTING_LABELS[key] or key, true,
            function() return ns.DB.settings[key] and true or false end,
            function(value) ns.DB.settings[key] = value and true or false; Changed() end)
        Settings.CreateCheckbox(category, s, o.tip)
        settings[key] = s
    end

    local mm = Settings.RegisterProxySetting(category, "PASTIME_MINIMAP", "boolean", L["Minimap button"], true,
        function() return not ns.DB.minimap.hidden end,
        function(value)
            ns.DB.minimap.hidden = not value
            if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
        end)
    Settings.CreateCheckbox(category, mm, L["Shows the dice button at the minimap. Left-click opens the game collection, right-click these settings."])
    settings.minimap = mm

    if CreateSettingsButtonInitializer and SettingsPanel and SettingsPanel.GetLayout then
        local layout = SettingsPanel:GetLayout(category)
        if layout and layout.AddInitializer then
            layout:AddInitializer(CreateSettingsButtonInitializer(L["Game collection"], L["Open Pastime"],
                function()
                    if HideUIPanel and SettingsPanel then HideUIPanel(SettingsPanel) end
                    ns.ShowFrame()
                end, L["Opens the game collection. You can also use /pastime or the key binding."], true))
        end
    end

    Settings.RegisterAddOnCategory(category)
    return category
end

function ns.OpenSettings()
    if InCombatLockdown and InCombatLockdown() then
        ns.Print(L["Not possible in combat."])
        return
    end
    local cat = ns.CreateSettings()
    if cat and Settings.OpenToCategory then
        Settings.OpenToCategory(cat:GetID())
    end
end

-- Nach Änderungen über Befehle oder das Spielefenster das Optionsmenü nachziehen
function ns.RefreshSettings()
    for _, s in pairs(settings) do
        if s.NotifyUpdate then pcall(s.NotifyUpdate, s) end
    end
end
