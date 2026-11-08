-- WoW-Attrappe für Pastime (Frames mit Eltern, Tastatur, Zeit, Taxi, Kampf)
LOG = {}
local function log(s) LOG[#LOG + 1] = s end
NOW = 1000
GetTime = function() return NOW end

local Methods = {}
local MT = {}
MT.__index = function(t, k)
    local m = Methods[k]
    if m then return m end
    if type(k) == "string" and k:match("^%u") and k ~= "Text" then
        return function() return nil end
    end
    return nil
end
local function Mock(kind, name, parent)
    return setmetatable({ __kind = kind, __name = name, __parent = parent, scripts = {}, shown = true,
        text = "", checked = false, enabled = true, level = 1, kb = false, propagate = false, points = {} }, MT)
end
_G.Mock = Mock
ALLFRAMES = {}
function Methods:SetScript(n, fn) self.scripts[n] = fn end
function Methods:GetScript(n) return self.scripts[n] end
function Methods:HookScript(n, fn) self.scripts[n] = fn end
function Methods:IsVisible()
    if not self.shown then return false end
    if self.__parent then return self.__parent:IsVisible() end
    return true
end
function Methods:Show()
    local was = self:IsVisible(); self.shown = true
    if not was and self:IsVisible() and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Methods:Hide()
    local was = self:IsVisible(); self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Methods:SetShown(v) if v then self:Show() else self:Hide() end end
function Methods:IsShown() return self.shown end
function Methods:SetText(t) self.text = t ~= nil and tostring(t) or "" end
function Methods:GetText() return self.text end
function Methods:SetChecked(v) self.checked = v and true or false end
function Methods:GetChecked() return self.checked end
function Methods:GetWidth() return 300 end
function Methods:GetHeight() return 20 end
function Methods:GetStringHeight() return 14 * select(2, self.text:gsub("\n", "\n")) + 14 end
function Methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function Methods:SetPoint(p, a, b, c, d) self.points[p] = { a, b, c, d } end
function Methods:GetCenter() return 100, 100 end
function Methods:GetEffectiveScale() return 1 end
function Methods:GetFrameLevel() return self.level end
function Methods:SetFrameLevel(l) self.level = l end
function Methods:CreateTexture() return Mock("Texture", nil, self) end
function Methods:CreateFontString() return Mock("FontString", nil, self) end
function Methods:SetTexture(t) self.tex = t; return true end
function Methods:Enable() self.enabled = true end
function Methods:Disable() self.enabled = false end
function Methods:SetEnabled(v) self.enabled = v and true or false end
function Methods:IsEnabled() return self.enabled end
function Methods:Click(button) if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end end
function Methods:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true end
function Methods:UnregisterEvent(e) if self.events then self.events[e] = nil end end
function Methods:EnableKeyboard(v) self.kb = v and true or false; KB_CALLS = (KB_CALLS or 0) + 1 end
function Methods:SetPropagateKeyboardInput(v)
    if COMBAT then error("ADDON_ACTION_BLOCKED SetPropagateKeyboardInput") end
    self.propagate = v
end
function Methods:SetScale(s) self.scale = s end

function CreateFrame(kind, name, parent, template)
    local f = Mock(kind, name, parent)
    f.template = template
    if template == "UICheckButtonTemplate" or template == "PanelTabButtonTemplate" then f.Text = Mock("FontString", nil, f) end
    if name then _G[name] = f end
    table.insert(ALLFRAMES, f)
    return f
end
UIParent = Mock("Frame", "UIParent")
Minimap = Mock("Frame", "Minimap")
GameTooltip = Mock("GameTooltip", "GameTooltip")
DEFAULT_CHAT_FRAME = Mock("Frame")
CHAT = {}
function DEFAULT_CHAT_FRAME:AddMessage(t) table.insert(CHAT, t) end
UISpecialFrames = {}
SlashCmdList = {}
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
date = os.date
time = os.time
GetCursorPosition = function() return 0, 0 end
IsShiftKeyDown = function() return SHIFT or false end
InCombatLockdown = function() return COMBAT or false end
UnitName = function() return "Guenther" end
GetLocale = function() return "deDE" end
function GetBuildInfo() return "1.60.1", "70840", "Nov  5 2026", 16001 end
for _, n in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontNormalSmall", "GameFontHighlightSmall",
    "GameFontDisable", "GameFontDisableSmall", "GameFontNormalLarge", "GameFontNormalHuge", "GameFontHighlightHuge",
    "GameFontHighlightLarge", "ChatFontNormal", "QuestFont", "QuestTitleFont", "QuestFontNormalSmall",
    "ZoneTextFont", "SubZoneTextFont", "Game30Font", "Game24Font", "Game20Font" }) do
    _G[n] = Mock("Font")
end
BACKDROP_DIALOG_32_32 = {}
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
SOUNDKIT = { IG_QUEST_LIST_OPEN = 1, LOOT_WINDOW_COIN_SOUND = 2, U_CHAT_SCROLL_BUTTON = 3, IG_ABILITY_PAGE_TURN = 4,
    IG_QUEST_LIST_COMPLETE = 5, IG_QUEST_LOG_ABANDON_QUEST = 6, READY_CHECK = 7, IG_MAINMENU_OPTION_CHECKBOX_ON = 8,
    IG_SPELLBOOK_OPEN = 9, IG_SPELLBOOK_CLOSE = 10 }
SOUNDS, SOUND_CH = {}, {}
function PlaySound(id, ch) table.insert(SOUNDS, id); table.insert(SOUND_CH, ch) end
-- typische Tastenbelegung
BINDINGS = { W = "MOVEFORWARD", UP = "MOVEFORWARD", S = "MOVEBACKWARD", DOWN = "MOVEBACKWARD", A = "STRAFELEFT",
    D = "STRAFERIGHT", SPACE = "JUMP", Q = "MULTIACTIONBAR1BUTTON3", E = "MULTIACTIONBAR1BUTTON4",
    ["1"] = "ACTIONBUTTON1", TAB = "TARGETNEARESTENEMY", B = "TOGGLEBACKPACK", M = "TOGGLEWORLDMAP",
    ENTER = "OPENCHAT", ["SHIFT-7"] = "OPENCHATSLASH", R = "REPLY", NUMLOCK = "TOGGLEAUTORUN" }
function GetBindingFromInput(key) return BINDINGS[(SHIFT and "SHIFT-" or "") .. key] end
FLASHED = 0
function FlashClientIcon() FLASHED = FLASHED + 1 end
function GetMinimapZoneText() return "Das Wegekreuz" end

-- Timer
TIMERS = {}
C_Timer = {
    After = function(d, fn) table.insert(TIMERS, fn) end,
    NewTicker = function(d, fn)
        local t = { fn = fn, cancelled = false }
        function t:Cancel() self.cancelled = true end
        TICKERS = TICKERS or {}
        table.insert(TICKERS, t)
        return t
    end,
}
function RunTimers()
    for _ = 1, 10 do
        local list = TIMERS; TIMERS = {}
        if #list == 0 then return end
        for _, fn in ipairs(list) do fn() end
    end
end
function RunTickers()
    for _, t in ipairs(TICKERS or {}) do if not t.cancelled then t.fn() end end
end

-- Taxi
ONTAXI = false
UnitOnTaxi = function() return ONTAXI end
TAXINODES = { { "Das Wegekreuz, Brachland", "CURRENT" }, { "Orgrimmar, Durotar", "REACHABLE" }, { "Ratschet, Brachland", "REACHABLE" } }
NumTaxiNodes = function() return #TAXINODES end
TaxiNodeName = function(i) return TAXINODES[i][1] end
TaxiNodeGetType = function(i) return TAXINODES[i][2] end
function TakeTaxiNode(i) TAKEN = i end
function hooksecurefunc(name, fn)
    local orig = _G[name]
    _G[name] = function(...) orig(...); fn(...) end
end

-- Fehler
ERRORS_FORWARDED = {}
function geterrorhandler() return function(e) table.insert(ERRORS_FORWARDED, tostring(e)) end end
function debugstack() return "[mock stack]" end

-- Karten / Position ---------------------------------------------------------
-- Karte -> Kontinent, Ursprung und Größe in Metern
MAPS = {
    [1411] = { c = 1, ox = 10000, oy = 0, w = 5000, h = 3500 },     -- Durotar
    [1413] = { c = 1, ox = 4000, oy = 3000, w = 8000, h = 10000 },  -- Brachland
    [1412] = { c = 1, ox = 0, oy = 3000, w = 5000, h = 3400 },      -- Mulgore
    [1420] = { c = 0, ox = 0, oy = 0, w = 4500, h = 3000 },         -- Tirisfal
    [1434] = { c = 0, ox = 0, oy = 20000, w = 6000, h = 7000 },     -- Schlingendorntal
}
PLAYER = { map = 1413, x = 0.52, y = 0.30 }
SPEED, MOVING, INSTANCE = 0, false, false
function CreateVector2D(x, y) return { x = x, y = y } end
C_Map = {
    GetBestMapForUnit = function() return PLAYER.map end,
    GetPlayerMapPosition = function(map) return { x = PLAYER.x, y = PLAYER.y } end,
    GetWorldPosFromMapPos = function(map, v)
        local m = MAPS[map]; if not m then return nil end
        return m.c, { x = m.ox + v.x * m.w, y = m.oy + v.y * m.h }
    end,
    GetMapInfo = function(m) return { name = "Karte" .. m } end,
}
GetUnitSpeed = function() return SPEED end
IsPlayerMoving = function() return MOVING end
IsInInstance = function() return INSTANCE end
UnitFactionGroup = function() return "Horde" end
PanelTemplates_SelectTab = function(t) t.selectedTab = true end
PanelTemplates_DeselectTab = function(t) t.selectedTab = false end
PanelTemplates_TabResize = function() end

-- Blizzard-Optionsmenü (Settings) – nur so weit, wie Pastime es benutzt
SETTINGS_OPENED = nil
local function newSetting(name, var, typ, def, get, set)
    return { name = name, var = var, GetValue = function() return get() end, SetValue = function(_, v) set(v) end,
        NotifyUpdate = function(s) s.notified = (s.notified or 0) + 1 end }
end
Settings = {
    CATEGORIES = {}, SETTINGS = {},
    RegisterVerticalLayoutCategory = function(name)
        local c = { name = name, GetID = function() return 4711 end, init = {} }
        return c
    end,
    RegisterProxySetting = function(cat, var, typ, name, def, get, set)
        local s = newSetting(name, var, typ, def, get, set)
        Settings.SETTINGS[var] = s
        return s
    end,
    CreateCheckbox = function(cat, s, tip) table.insert(cat.init, { s = s, tip = tip }) end,
    RegisterAddOnCategory = function(cat) table.insert(Settings.CATEGORIES, cat) end,
    OpenToCategory = function(id) SETTINGS_OPENED = id end,
}
SettingsPanel = Mock("Frame", "SettingsPanel")
function SettingsPanel:GetLayout(cat) return { AddInitializer = function(_, i) table.insert(cat.init, i) end } end
function CreateSettingsButtonInitializer(name, text, click, tip, tags) return { name = name, text = text, click = click } end
function HideUIPanel(f) if f then f:Hide() end end
