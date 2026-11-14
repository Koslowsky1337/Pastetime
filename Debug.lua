-- Pastime: Debug – Messwerte-Fenster (/pastime debug) und Diagnosebericht (/pastime diag)
--
-- Was zum Auslesen in PastimeDB landet (geschrieben bei /reload oder Logout):
--   log     – Protokoll (E/W/I immer, D nur mit Debug),
--             Fehler mit Stacktrace (Feld st)
--   traces  – Reise-Mitschnitte: bei Warten/Abfahrt/Ankunft/Abbruch die
--             Messpunkte seit dem letzten Ereignis (siehe Transport.lua)
--   routes, scores, stats, settings
local ADDON, ns = ...
local L = ns.L

local function yesno(v)
    if v == nil then return "?" end
    return v and "yes" or "no"
end

local function plain(s)
    return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function onTaxi()
    if not UnitOnTaxi then return nil end
    local ok, v = pcall(UnitOnTaxi, "player")
    if not ok or (type(issecretvalue) == "function" and issecretvalue(v)) then return nil end
    return v and true or false
end

-- Aktuelle Messwerte als Zeilen
function ns.DebugLines()
    local lines = {}
    local function add(fmt, ...) table.insert(lines, select("#", ...) > 0 and fmt:format(...) or fmt) end
    local H = "|cffffd100"
    local t = ns.trip
    if t.active then
        local K = ns.KINDS[t.kind] or ns.KINDS.flug
        local since = t.phase == "ride" and t.start or t.waitStart
        add("%sTrip:|r %s · %s · %s → %s · %s%s", H, K.one, t.phase == "wait" and "waiting" or "travelling",
            ns.ShortName(t.from) or "?", ns.ShortName(t.to) or "?", ns.FormatTime(GetTime() - (since or GetTime())),
            t.expected and (" / expected " .. ns.FormatTime(t.expected)) or "")
        add("%sTrip ID:|r %d · played: %s · auto-opened: %s · pending: %d", H, t.id, yesno(t.played),
            yesno(t.autoOpened), #(t.pending or {}))
    else
        add("%sTrip:|r none", H)
    end
    add("%sTaxi (UnitOnTaxi):|r %s", H, yesno(onTaxi()))
    local LV = ns.transportState and ns.transportState.live
    if not LV then
        add("%sDocks:|r no measurement yet", H)
    elseif LV.note then
        add("%sDocks:|r %s", H, LV.note)
    else
        add("%sPosition:|r map %s  %.2f / %.2f  (continent %s)", H, tostring(LV.map), (LV.mx or 0) * 100,
            (LV.my or 0) * 100, tostring(LV.c))
        add("%sMoving:|r %.1f m/s · own speed %s · walking: %s · carried: %s (%d/4)", H, LV.v or 0,
            LV.speed and ("%.1f"):format(LV.speed) or "?", yesno(LV.moving), yesno(LV.carried), LV.nc or 0)
        if LV.dock then
            add("%sDock:|r %s → %s · %d m", H, LV.dock.name, LV.dock.to, math.floor((LV.dd or 0) + 0.5))
        else
            add("%sDock:|r none on this continent", H)
        end
        if (LV.still or 0) > 0 then add("%sStill at destination for:|r %.1f s", H, LV.still) end
        if LV.suppress then add("%sWaiting blocked|r until you leave %s", H, LV.suppress) end
    end
    local run = ns.run
    if run then
        add("%sRound:|r %s%s · %s · trip ID %s%s", H, run.def.name, run.mode and (" (" .. run.mode .. ")") or "",
            run.state, tostring(run.tripId or "-"), run.landed and " · arrival dialog" or "")
    else
        add("%sRound:|r none", H)
    end
    add("%sKeyboard:|r %s · combat: %s · window open: %s", H, yesno(ns.gameView and ns.gameView.kbOn),
        yesno(InCombatLockdown()), yesno(ns.frame and ns.frame:IsShown()))
    add("%sErrors (session):|r %d · traces: %d · routes: %d", H, ns.SessionErrors(),
        #(ns.DB.traces or {}), ns.CountRoutes())
    return lines
end

---------------------------------------------------------------------------
-- Messwerte-Fenster
---------------------------------------------------------------------------
local function SavePos(f)
    local point, _, relPoint, x, y = f:GetPoint(1)
    ns.DB.debugPos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function CreatePanel()
    local f = ns.AutoWrap(CreateFrame("Frame", "PastimeDebugFrame", UIParent, "BackdropTemplate"), "debug")
    f:SetBackdrop(ns.TOOLTIP_BACKDROP)
    f:SetBackdropColor(0, 0, 0, 0.82)
    f:SetBackdropBorderColor(1, 0.82, 0, 0.8)
    f:SetSize(360, 196)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos(self) end)
    local pos = ns.DB.debugPos
    if type(pos) == "table" and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("TOPLEFT", 30, -220)
    end
    local title = ns.FontString(f, "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetText("Pastime Debug")
    local hint = ns.FontString(f, "GameFontDisableSmall", "RIGHT")
    hint:SetPoint("TOPRIGHT", -30, -11)
    hint:SetText("/pastime diag · /pastime log")
    local close = ns.CreateCloseButton(f, function()
        ns.DB.debug = false
        ns.Log("I", "debug", "Debug off (window closed)")
        ns.Print(L["Debug |cffff6060off|r."])
        ns.UpdateDebugPanel()
    end)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -2, -2)
    f.text = ns.FontString(f, "GameFontHighlightSmall")
    f.text:SetPoint("TOPLEFT", 10, -28)
    f.text:SetWidth(340)
    f.text:SetSpacing(2)
    local acc, layoutN = 1, 0
    f:SetScript("OnUpdate", function(self, elapsed)
        acc = acc + elapsed
        if acc < 0.5 then return end
        acc = 0
        local ok, lines = pcall(ns.DebugLines)
        -- Layout-Prüfung läuft mit: alles, was man durchklickt, wird geprüft (neue Funde ins Protokoll)
        local okL, found = pcall(ns.LayoutCheck)
        if okL then layoutN = #found end
        self.text:SetText((ok and table.concat(lines, "\n") or ("Errors: " .. tostring(lines)))
            .. ("\nLayout: %d problem(s) on screen · /pastime log"):format(layoutN))
        local h = self.text:GetStringHeight()
        if h then self:SetHeight(h + 40) end
    end)
    return f
end

function ns.UpdateDebugPanel()
    if not ns.DB then return end
    if ns.DB.debug then
        ns.debugPanel = ns.debugPanel or CreatePanel()
        ns.debugPanel:Show()
    elseif ns.debugPanel then
        ns.debugPanel:Hide()
    end
end

---------------------------------------------------------------------------
-- Diagnosebericht (/pastime diag) – zum Kopieren und Einfügen
---------------------------------------------------------------------------
local OTHER_ADDONS = { "TomTom", "Questie", "QuestieDB", "ForeverDungeonJournal", "Leatrix_Maps" }

local function addonLoaded(name)
    local fn = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not fn then return "?" end
    local ok, v = pcall(fn, name)
    return ok and (v and "yes" or "no") or "?"
end

function ns.DiagReport()
    local out = {}
    local function add(fmt, ...) table.insert(out, select("#", ...) > 0 and fmt:format(...) or fmt) end
    local build, num = "?", "?"
    if GetBuildInfo then build, num = GetBuildInfo() end
    add("Pastime %s · Client %s (%s) · %s · %s · %s", ns.VERSION, tostring(build), tostring(num),
        GetLocale and GetLocale() or "?", tostring(ns.playerName), date("%Y-%m-%d %H:%M:%S"))
    local set = ns.DB.settings
    add("Session %s · debug %s · auto=%s alarm=%s combat=%s sound=%s", tostring(ns.session), yesno(ns.DB.debug),
        tostring(set.autoOpen), tostring(set.landAlarm), tostring(set.hideInCombat), tostring(set.sound))
    local addons = {}
    for _, a in ipairs(OTHER_ADDONS) do table.insert(addons, a .. "=" .. addonLoaded(a)) end
    add("Addons: %s", table.concat(addons, " "))
    add("")
    add("== Now ==")
    for _, l in ipairs(ns.DebugLines()) do add(plain(l)) end
    local have, total = 0, 0
    if ns.DockCount then have, total = ns.DockCount() end
    add("Docks computed: %d of %d", have, total)
    add("")
    add("== Routes (%d) ==", ns.CountRoutes())
    for key, r in pairs(ns.DB.routes) do
        local n = 0
        for _, list in pairs(r.scores or {}) do n = n + #list end
        add("%s · duration %s · %d× · %d entries", key, r.t and ns.FormatTime(r.t) or "?", r.n or 0, n)
    end
    add("")
    local traces = ns.DB.traces or {}
    add("== Trip traces (%d) ==", #traces)
    for i, tr in ipairs(traces) do
        add("[%d] %s %s · %s · %d points", i, tr.d or "?", tr.e or "?", tr.info or "", #(tr.s or {}))
    end
    local last = traces[#traces]
    if last and #(last.s or {}) > 0 then
        add("-- Points of the last trace (max. 40):")
        for i = math.max(1, #last.s - 39), #last.s do add(last.s[i]) end
    end
    if ns.TraceTail then
        local tail = ns.TraceTail(20)
        if #tail > 0 then
            add("-- Current samples:")
            for _, l in ipairs(tail) do add(l) end
        end
    end
    add("")
    add("== Errors and warnings ==")
    add(ns.FormatLog(30, true))
    return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- Layout-Prüfer (/pastime layout, nur mit Debug): meldet abgeschnittene,
-- überstehende und überlappende Texte/Knöpfe als Warnung „layout“ im Protokoll
---------------------------------------------------------------------------
local TOL = 1
local logged, loggedN = {}, 0

local function rect(r)
    local l, rt, t, b = r:GetLeft(), r:GetRight(), r:GetTop(), r:GetBottom()
    if l and rt and t and b then return l, rt, t, b end
end

-- Fläche, die der Text wirklich belegt (bei fester Breite/Höhe kleiner als der Rahmen)
local function textRect(fs)
    local l, r, t, b = rect(fs)
    if not l then return end
    local sw, sh = fs:GetStringWidth() or 0, fs:GetStringHeight() or 0
    if sw < r - l then
        local j = fs:GetJustifyH()
        if j == "LEFT" then r = l + sw
        elseif j == "RIGHT" then l = r - sw
        else local c = (l + r) / 2; l, r = c - sw / 2, c + sw / 2 end
    end
    if sh < t - b then
        local j = fs:GetJustifyV()
        if j == "TOP" then b = t - sh
        elseif j == "BOTTOM" then t = b + sh
        else local c = (t + b) / 2; t, b = c + sh / 2, c - sh / 2 end
    end
    return l, r, t, b
end

local function label(obj)
    local s = obj.GetText and obj:GetText()
    if s and s ~= "" then return '"' .. plain(s):gsub("\n", " / "):sub(1, 50) .. '"' end
    return obj.GetDebugName and obj:GetDebugName() or obj:GetObjectType()
end

function ns.LayoutCheck(roots)
    local found, seen = {}, {}
    local function report(msg)
        if not seen[msg] then seen[msg] = true; found[#found + 1] = msg end
    end
    -- inScroll: in Scrollbereichen darf Text oben/unten aus dem Bild laufen
    local function walk(frame, inScroll)
        local fl, fr, ft, fb = rect(frame)
        local items = {}
        for _, reg in ipairs({ frame:GetRegions() }) do
            if reg:GetObjectType() == "FontString" and reg:IsVisible() and (reg:GetText() or "") ~= "" then
                if reg.IsTruncated and reg:IsTruncated() then report("truncated: " .. label(reg)) end
                local l, r, t, b = textRect(reg)
                if l then
                    items[#items + 1] = { reg, l, r, t, b }
                    -- Häkchen: Beschriftung steht absichtlich neben dem Kästchen
                    if fl and frame:GetObjectType() ~= "CheckButton" and (l < fl - TOL or r > fr + TOL or (not inScroll and (t > ft + TOL or b < fb - TOL))) then
                        report(("sticks out of %s: %s"):format(label(frame), label(reg)))
                    end
                end
            end
        end
        for _, child in ipairs({ frame:GetChildren() }) do
            if child:IsVisible() then
                local ot = child:GetObjectType()
                -- Knöpfe nur mit Beschriftung: Karten, Spalten und Felder ohne Text dürfen sich überlappen
                if (ot == "Button" or ot == "CheckButton") and ((child.GetText and child:GetText()) or "") ~= "" then
                    local l, r, t, b = rect(child)
                    if l then items[#items + 1] = { child, l, r, t, b } end
                end
                walk(child, inScroll or ot == "ScrollFrame")
            end
        end
        for i = 1, #items do
            local a = items[i]
            for j = i + 1, #items do
                local c = items[j]
                if math.min(a[3], c[3]) - math.max(a[2], c[2]) > TOL and math.min(a[4], c[4]) - math.max(a[5], c[5]) > TOL then
                    report(("overlap: %s / %s"):format(label(a[1]), label(c[1])))
                end
            end
        end
    end
    for _, root in ipairs(roots or { ns.frame, ns.alertFrame }) do
        if root and root:IsVisible() then walk(root, false) end
    end
    -- jeder Fund nur einmal pro Sitzung ins Protokoll (die Prüfung läuft im Debug-Modus ständig)
    for _, msg in ipairs(found) do
        if not logged[msg] and loggedN < 100 then
            logged[msg], loggedN = true, loggedN + 1
            ns.Log("W", "layout", "%s", msg)
        end
    end
    return found
end
