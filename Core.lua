-- Pastime: Kern (Speicher, Protokoll, Bestenlisten, Reisen, Befehle)
local ADDON, ns = ...
local L = ns.L
_G.Pastime = ns

ns.VERSION = "1.0.0"

---------------------------------------------------------------------------
-- Protokoll (PastimeDB.log)
-- Stufen: E = Fehler, W = Warnung, I = Info, D = Debug (nur mit /pastime debug)
---------------------------------------------------------------------------
local MAX_ENTRIES = 300
local LEVEL_NAME = { E = "ERROR", W = "WARNING", I = "INFO", D = "DEBUG" }
local LEVEL_COLOR = { E = "ff6060", W = "ffb040", I = "a0c0ff", D = "909090" }
local pending, echoed = {}, {}

local function trim(log)
    local extra = #log - MAX_ENTRIES
    for _ = 1, math.max(0, extra) do table.remove(log, 1) end
end

function ns.Print(text)
    local frame = DEFAULT_CHAT_FRAME or ChatFrame1
    if frame then frame:AddMessage("|cffffd100Pastime:|r " .. tostring(text)) end
end

function ns.DebugOn() return ns.DB and ns.DB.debug and true or false end

function ns.Log(level, cat, fmt, ...)
    if level == "D" and not ns.DebugOn() then return end
    local msg
    if select("#", ...) > 0 then
        local ok, res = pcall(string.format, fmt, ...)
        msg = ok and res or (tostring(fmt) .. " [format error]")
    else
        msg = tostring(fmt)
    end
    local entry = { d = date("%Y-%m-%d %H:%M:%S"), l = level, c = cat, m = msg, p = ns.playerName, s = ns.session }
    if ns.DB and ns.DB.log then
        table.insert(ns.DB.log, entry)
        trim(ns.DB.log)
    else
        table.insert(pending, entry)
    end
    if (level == "E" and not echoed[msg]) or (ns.DebugOn() and level ~= "I") then
        if level == "E" then echoed[msg] = true end
        ns.Print(("|cff%s[%s]|r %s: %s"):format(LEVEL_COLOR[level], LEVEL_NAME[level], cat, msg))
    end
    return entry
end

local function handler(err)
    return { err = err, stack = debugstack and debugstack(2, 12, 0) or "" }
end
local function collect(ok, ...) return ok, select("#", ...), { ... } end

function ns.Safe(cat, fn, ...)
    local n, args = select("#", ...), { ... }
    local ok, rn, r = collect(xpcall(function() return fn(unpack(args, 1, n)) end, handler))
    if ok then return unpack(r, 1, rn) end
    local info = type(r[1]) == "table" and r[1] or { err = r[1] }
    local entry = ns.Log("E", cat, "%s", tostring(info.err))
    if entry then entry.st = info.stack end
    local eh = geterrorhandler and geterrorhandler()
    if eh then pcall(eh, info.err) end
    return nil
end

function ns.Wrap(cat, fn)
    return function(...) return ns.Safe(cat, fn, ...) end
end

-- Alle per SetScript gesetzten Skripte eines Frames absichern (OnUpdate sichert sich selbst)
function ns.AutoWrap(frame, cat)
    local orig = frame.SetScript
    frame.SetScript = function(self, script, fn)
        if type(fn) == "function" and script ~= "OnUpdate" then fn = ns.Wrap(cat .. ":" .. script, fn) end
        return orig(self, script, fn)
    end
    return frame
end

function ns.SessionErrors()
    local n = 0
    for _, e in ipairs(ns.DB and ns.DB.log or {}) do
        if e.s == ns.session and e.l == "E" then n = n + 1 end
    end
    return n
end

function ns.FormatLog(maxLines, onlyProblems)
    local log = ns.DB and ns.DB.log or {}
    local list = {}
    for _, e in ipairs(log) do
        if not onlyProblems or e.l == "E" or e.l == "W" then table.insert(list, e) end
    end
    local lines, last = {}, nil
    for i = math.max(1, #list - (maxLines or 200) + 1), #list do
        local e = list[i]
        if e.s ~= last then
            table.insert(lines, ("---- Session %s%s ----"):format(tostring(e.s), e.s == ns.session and " (current)" or ""))
            last = e.s
        end
        table.insert(lines, ("%s [%s] %s: %s"):format(e.d or "?", LEVEL_NAME[e.l] or e.l, e.c or "?", e.m or ""))
        if e.st and e.st ~= "" then table.insert(lines, "    " .. e.st:gsub("\n", "\n    ")) end
    end
    if #lines == 0 then return onlyProblems and L["No errors or warnings in the log."] or L["The log is empty."] end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
function ns.Trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

function ns.FormatTime(sec)
    sec = math.max(0, math.floor((sec or 0) + 0.5))
    if sec >= 3600 then
        return ("%d:%02d:%02d"):format(math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60)
    end
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

function ns.FormatNumber(n)
    n = math.floor((n or 0) + 0.5)
    local s = tostring(math.abs(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    return (n < 0 and "-" or "") .. out
end

-- „Das Wegekreuz, Brachland“ -> „Das Wegekreuz“
function ns.ShortName(n)
    if not n then return nil end
    return (n:match("^([^,]+)") or n)
end

-- Werte, die der Client im Kampf/in Instanzen geheim hält, ignorieren
function ns.Num(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return type(v) == "number" and v or nil
end

-- Spielgeräusche laufen über den Effekte-Kanal (folgt dem Effekte-Regler)
-- und sind bewusst leise; nur der Landealarm nutzt die Hauptlautstärke.
local SOUND = {
    start = "IG_SPELLBOOK_OPEN", point = "IG_MAINMENU_OPTION_CHECKBOX_ON", click = "U_CHAT_SCROLL_BUTTON",
    line = "IG_ABILITY_PAGE_TURN", big = "LOOT_WINDOW_COIN_SOUND", over = "IG_SPELLBOOK_CLOSE",
    record = "IG_QUEST_LIST_COMPLETE", flag = "U_CHAT_SCROLL_BUTTON", alarm = "READY_CHECK",
    t1 = "U_CHAT_SCROLL_BUTTON", t2 = "IG_ABILITY_PAGE_TURN", t3 = "IG_SPELLBOOK_CLOSE", t4 = "IG_MAINMENU_OPTION_CHECKBOX_ON",
    bad = "IG_QUEST_LOG_ABANDON_QUEST",
}
local lastSound = {}

function ns.PlaySound(kind)
    if kind ~= "alarm" and not (ns.DB and ns.DB.settings.sound) then return end
    local now = GetTime()
    if lastSound[kind] and now - lastSound[kind] < 0.12 then return end   -- kein Dauerfeuer
    lastSound[kind] = now
    local id = SOUNDKIT and SOUNDKIT[SOUND[kind] or ""]
    if id and PlaySound then pcall(PlaySound, id, kind == "alarm" and "Master" or "SFX") end
end

---------------------------------------------------------------------------
-- Speicher (PastimeDB, für alle Charaktere)
---------------------------------------------------------------------------
local DEFAULTS = {
    settings = { autoOpen = true, landAlarm = true, hideInCombat = true, sound = true },
    scores = {}, stats = {}, routes = {}, minimap = {}, collapsed = {}, modes = {},
    frame = false, lastGame = false, debug = false, log = {}, logSession = 0,
    blackjack = { gold = 100, peak = 100 },   -- Goblin-Gold bleibt zwischen Partien erhalten
}

local function fill(t, defaults)
    for k, v in pairs(defaults) do
        if t[k] == nil then
            if type(v) == "table" then t[k] = fill({}, v) else t[k] = v end
        elseif type(v) == "table" and type(t[k]) == "table" then
            fill(t[k], v)
        end
    end
    return t
end

local function InitDB()
    PastimeDB = fill(type(PastimeDB) == "table" and PastimeDB or {}, DEFAULTS)
    ns.DB = PastimeDB
    local st = ns.DB.stats
    st.total, st.flight, st.games = st.total or 0, st.flight or 0, st.games or {}
    -- 0.1.0 merkte nur Flugzeiten (flights["A > B"] = { t, d })
    if type(ns.DB.flights) == "table" then
        for key, v in pairs(ns.DB.flights) do
            local from, to = key:match("^(.-) > (.+)$")
            if from and type(v) == "table" then
                local r = ns.Route("flug", from, to)
                r.t, r.last = r.t or v.t, r.last or v.d
            end
        end
        ns.DB.flights = nil
    end
    ns.DB.logSession = (tonumber(ns.DB.logSession) or 0) + 1
    ns.session = ns.DB.logSession
    for _, e in ipairs(pending) do e.s = ns.session; table.insert(ns.DB.log, e) end
    wipe(pending)
    trim(ns.DB.log)
end

---------------------------------------------------------------------------
-- Spiele-Verzeichnis
---------------------------------------------------------------------------
ns.CATEGORIES = {
    { id = "geschick", name = L["Arcade"] },
    { id = "knobeln", name = L["Puzzles"] },
    { id = "karten", name = L["Dice & Cards"] },
}
-- Wie lange eine Partie ungefähr dauert
ns.LENGTHS = {
    kurz = { label = L["short"], color = "80ff80", short = L["For short flights (1–2 min)"],
        desc = L["for short flights – a round takes 1–2 minutes"] },
    lang = { label = L["long"], color = "80c0ff", short = L["For long journeys (several minutes)"],
        desc = L["for long journeys – rounds last several minutes, ideal for zeppelins and boats"] },
}
ns.games, ns.gamesById = {}, {}

-- def: id, name, category, icon, short, desc, controls, keyboard, width, height,
--      Create(host, board) -> Spielobjekt; optional modes, lowerIsBetter, FormatScore, aliases
function ns.RegisterGame(def)
    def.order = #ns.games + 1
    def.length = def.length or "kurz"
    table.insert(ns.games, def)
    ns.gamesById[def.id] = def
    return def
end

-- Beim Login: Farbschema der Fraktion wählen und für die Allianz die Varianten der
-- Spiele übernehmen (def.alliance = { name, desc, icon, ... }). Id und Bestenliste bleiben.
function ns.ApplyFaction()
    local ally = ns.IsAlliance()
    ns.THEME = ns.THEMES[ally and "Alliance" or "Horde"]
    if not ally then return end
    for _, def in ipairs(ns.games) do
        for k, v in pairs(def.alliance or {}) do def[k] = v end
    end
end

function ns.FindGame(query)
    query = (query or ""):lower()
    if query == "" then return nil end
    for _, g in ipairs(ns.games) do
        if g.id == query or g.name:lower() == query then return g end
        for _, a in ipairs(g.aliases or {}) do if a == query then return g end end
    end
    for _, g in ipairs(ns.games) do
        if g.name:lower():find(query, 1, true) then return g end
    end
end

function ns.DefaultMode(def)
    if not def.modes then return nil end
    local saved = ns.DB.modes[def.id]
    for _, m in ipairs(def.modes) do if m.id == saved then return saved end end
    return def.modes[1].id
end

function ns.ModeName(def, mode)
    for _, m in ipairs(def.modes or {}) do if m.id == mode then return m.name end end
end

---------------------------------------------------------------------------
-- Bestenlisten: PastimeDB.scores["spiel" oder "spiel:modus"] = { {s, p, d}, ... }
-- Es zählen nur beendete Partien (Spielende oder „Beenden & werten“ bei der
-- Ankunft) – abgebrochene nie.
---------------------------------------------------------------------------
local MAX_SCORES = 10
local MAX_ROUTE_SCORES = 5

function ns.ScoreKey(def, mode) return mode and (def.id .. ":" .. mode) or def.id end

function ns.GetScores(def, mode)
    local key = ns.ScoreKey(def, mode)
    ns.DB.scores[key] = ns.DB.scores[key] or {}
    return ns.DB.scores[key]
end

function ns.BestScore(def, mode)
    return ns.GetScores(def, mode)[1]
end

function ns.FormatScore(def, score)
    if def.FormatScore then return def.FormatScore(score) end
    return ns.FormatNumber(score)
end

local function better(def, a, b)
    if def.lowerIsBetter then return a < b end
    return a > b
end

-- In eine sortierte Liste einfügen; gibt Platz und „persönlich bestes“ zurück
local function insertScore(def, list, score, max)
    local personal = true
    for _, e in ipairs(list) do
        if e.p == ns.playerName and not better(def, score, e.s) then personal = false; break end
    end
    local rank = #list + 1
    for i, e in ipairs(list) do
        if better(def, score, e.s) then rank = i; break end
    end
    if rank > max then return nil, false end
    table.insert(list, rank, { s = score, p = ns.playerName or "?", d = date("%d.%m.%y") })
    while #list > max do table.remove(list) end
    return rank, personal
end

local function validScore(def, score)
    if type(score) ~= "number" then return nil end
    if def.lowerIsBetter then return score > 0 and score or nil end
    return score > 0 and score or nil
end

function ns.SubmitScore(def, mode, score)
    score = validScore(def, score)
    if not score then return nil end
    local rank, personal = insertScore(def, ns.GetScores(def, mode), score, MAX_SCORES)
    ns.Log("I", "rekord", "%s%s: %s (rank %s)", def.name, mode and (" " .. mode) or "", tostring(score), tostring(rank))
    return rank, personal
end

-- Punktestand einer laufenden Partie, der bei der Ankunft gewertet werden kann
-- (Zeit-Spiele wie das Minenfeld zählen nur gelöst)
function ns.CurrentScore(run)
    if not run or run.def.lowerIsBetter or run.def.noLandingScore then return nil end
    local s = run.game.score
    return (type(s) == "number" and s > 0) and s or nil
end

---------------------------------------------------------------------------
-- Strecken: PastimeDB.routes["art:Von > Nach"] =
--   { kind, from, to, t = Reisedauer, n = Anzahl, last, lastT, scores = { [scoreKey] = {...} } }
---------------------------------------------------------------------------
ns.KINDS = {
    flug = { name = L["Flights"], one = L["Flight"], the = L["the flight"], arrive = L["Landed"], verb = L["Flying to"] },
    zeppelin = { name = L["Zeppelins"], one = "Zeppelin", the = L["the zeppelin"], arrive = L["Arrived"], verb = L["Zeppelin to"] },
    schiff = { name = L["Boats"], one = L["Boat"], the = L["the boat"], arrive = L["Arrived"], verb = L["Boat to"] },
    test = { name = L["Test flights"], one = L["Test flight"], the = L["the test flight"], arrive = L["Landed"], verb = L["Test flight to"] },
}
ns.KIND_ORDER = { "flug", "zeppelin", "schiff", "test" }

function ns.RouteKey(kind, from, to) return ("%s:%s > %s"):format(kind, from or "?", to or "?") end

function ns.Route(kind, from, to, noCreate)
    local key = ns.RouteKey(kind, from, to)
    local r = ns.DB.routes[key]
    if not r and not noCreate then
        r = { kind = kind, from = from, to = to, n = 0, scores = {} }
        ns.DB.routes[key] = r
    end
    return r, key
end

function ns.CountRoutes()
    local n = 0
    for _ in pairs(ns.DB.routes) do n = n + 1 end
    return n
end

function ns.RouteLabel(r)
    return ("%s → %s"):format(ns.ShortName(r.from) or "?", ns.ShortName(r.to) or "?")
end

function ns.RouteScores(r, def, mode)
    local key = ns.ScoreKey(def, mode)
    r.scores[key] = r.scores[key] or {}
    return r.scores[key]
end

function ns.SubmitRouteScore(r, def, mode, score)
    score = validScore(def, score)
    if not (r and score) then return nil end
    local rank = insertScore(def, ns.RouteScores(r, def, mode), score, MAX_ROUTE_SCORES)
    ns.Log("I", "strecke", "%s · %s: %s (rank %s)", ns.RouteLabel(r), def.name, tostring(score), tostring(rank))
    return rank
end

---------------------------------------------------------------------------
-- Statistik
---------------------------------------------------------------------------
local function gameStats(id)
    local g = ns.DB.stats.games[id]
    if not g then g = { n = 0, t = 0 }; ns.DB.stats.games[id] = g end
    return g
end

function ns.AddPlayTime(id, dt)
    local st = ns.DB.stats
    st.total = st.total + dt
    if ns.trip.active then st.flight = st.flight + dt end
    local g = gameStats(id)
    g.t = g.t + dt
end

function ns.CountGame(id)
    local g = gameStats(id)
    g.n = g.n + 1
end

---------------------------------------------------------------------------
-- Reisen (ns.trip): Flugmeister, Zeppeline, Schiffe
--   phase "wait": wartet am Turm/Anleger (nur Zeppelin/Schiff)
--   phase "ride": unterwegs
-- Partien bekommen beim Start die Reise-ID. Ergebnisse zählen für die Strecke,
-- sobald sie feststeht (Flug: sofort; Zeppelin/Schiff: bei der Ankunft).
---------------------------------------------------------------------------
ns.trip = { active = false, id = 0 }

local function tripInfo(t, extra)
    return ("%s/%s: %s > %s%s"):format(tostring(t.kind), tostring(t.phase), tostring(t.from), tostring(t.to), extra or "")
end
local function snapshot(event, t, extra)
    if ns.TraceSnapshot then ns.Safe("mitschnitt", ns.TraceSnapshot, event, tripInfo(t, extra)) end
end

function ns.BeginTrip(info)
    local t = ns.trip
    if t.active then return end
    t.id = t.id + 1
    t.active = true
    t.kind, t.phase = info.kind, info.phase or "ride"
    t.from, t.to, t.dock = info.from, info.to, info.dock
    t.simulated, t.simEnd = info.sim and true or false, info.sim and (GetTime() + info.sim) or nil
    t.played, t.autoOpened = false, false
    t.pending = {}
    t.confirmed = (t.kind == "flug" or t.kind == "test") and t.from ~= nil and t.to ~= nil
    t.waitStart = GetTime()
    if t.phase == "ride" then ns.DepartTrip(true) end
    ns.Log("I", "reise", "%s: %s -> %s (%s)%s", t.kind, tostring(t.from), tostring(t.to), t.phase,
        t.simulated and " [Test]" or "")
    snapshot("start", t)
    if ns.DB.settings.autoOpen and not InCombatLockdown() and ns.OpenForTrip then ns.OpenForTrip() end
    if ns.UpdateUI then ns.UpdateUI() end
end

-- Abfahrt (Zeppelin/Schiff legt ab) bzw. Abflug
function ns.DepartTrip(silent)
    local t = ns.trip
    if not t.active then return end
    t.phase = "ride"
    t.start = GetTime()
    local r = (t.from and t.to) and ns.Route(t.kind, t.from, t.to, true)
    t.expected = t.simEnd and (t.simEnd - t.start) or (r and r.t) or nil
    if not silent then
        ns.Log("I", "reise", "Departure %s -> %s (expected: %s s)", tostring(t.from), tostring(t.to), tostring(t.expected))
        snapshot("abfahrt", t)
        if ns.UpdateUI then ns.UpdateUI() end
    end
end

-- Ergebnis einer beendeten Partie für die Strecke vormerken/eintragen.
-- Rückgabe: Platz (oder "vorgemerkt"), Strecke
function ns.TripResult(run, score)
    local t = ns.trip
    if not (run and run.tripId and t.active and run.tripId == t.id) then return nil end
    if not validScore(run.def, score) then return nil end
    if t.confirmed then
        local r = ns.Route(t.kind, t.from, t.to)
        return ns.SubmitRouteScore(r, run.def, run.mode, score), r
    end
    table.insert(t.pending, { def = run.def, mode = run.mode, score = score })
    return "vorgemerkt", nil
end

-- Reise endet. arrived = am Ziel angekommen (sonst abgebrochen/verworfen)
function ns.EndTrip(arrived, dest)
    local t = ns.trip
    if not t.active then return end
    if dest then t.to = dest end
    local r
    if arrived and t.phase == "ride" and t.from and t.to then
        r = ns.Route(t.kind, t.from, t.to)
        local dur = GetTime() - (t.start or GetTime())
        if dur > 10 then r.t = math.floor(dur + 0.5) end
        r.n = (r.n or 0) + 1
        r.last, r.lastT = date("%d.%m.%y"), time()
        if not t.confirmed then
            t.confirmed = true
            for _, p in ipairs(t.pending) do ns.SubmitRouteScore(r, p.def, p.mode, p.score) end
        end
        ns.Log("I", "reise", "%s: arrived at %s after %s", tostring(t.kind), tostring(t.to), ns.FormatTime(dur))
    else
        ns.Log("I", "reise", "Trip discarded (%s, %s)", tostring(t.kind), tostring(t.phase))
    end
    snapshot(arrived and t.phase == "ride" and "ankunft" or "abbruch", t,
        t.start and (" after " .. ns.FormatTime(GetTime() - t.start)) or "")
    if ns.OnTripEnded then ns.OnTripEnded(t, arrived and t.phase == "ride", r) end
    t.active = false
    t.pending = {}
    if ns.UpdateUI then ns.UpdateUI() end
end

-- Kurzer Text für Fenster/Seitenleiste, nil wenn nicht unterwegs
function ns.TripStatus()
    local t = ns.trip
    if not t.active then return nil end
    local K = ns.KINDS[t.kind] or ns.KINDS.flug
    local dest = ns.ShortName(t.to)
    if t.phase == "wait" then
        return (L["Waiting for %s%s"]):format(K.the, dest and (L[" to "] .. dest) or "")
    end
    local head = dest and (K.verb .. " " .. dest) or (L["Travelling ("] .. K.one .. ")")
    local elapsed = GetTime() - (t.start or GetTime())
    local word = (t.kind == "flug" or t.kind == "test") and L["landing"] or L["arrival"]
    if t.expected then
        local left = t.expected - elapsed
        if left > 0 then return (L["%s · %s in about %s"]):format(head, word, ns.FormatTime(left)), left end
        return (L["%s · %s any moment"]):format(head, word), 0
    end
    return (L["%s · %s (measuring duration)"]):format(head, ns.FormatTime(elapsed))
end

-- Restzeit der Reise in Sekunden (nil, wenn unbekannt)
function ns.TripRemaining()
    local t = ns.trip
    if not (t.active and t.phase == "ride" and t.expected and t.start) then return nil end
    return math.max(0, t.expected - (GetTime() - t.start))
end

-- Bester Streckeneintrag für die aktuelle Reise
function ns.TripBest(def, mode)
    local t = ns.trip
    if not (t.active and t.from and t.to) then return nil end
    local r = ns.Route(t.kind, t.from, t.to, true)
    if not r then return nil end
    return (r.scores[ns.ScoreKey(def, mode)] or {})[1], r
end

---------------------------------------------------------------------------
-- Flugmeister: UnitOnTaxi + PLAYER_CONTROL_LOST/GAINED; Ziel über
-- TakeTaxiNode-Hook.
---------------------------------------------------------------------------
local pendingRoute
local flightTicker

local function currentNodeName()
    if not (NumTaxiNodes and TaxiNodeGetType and TaxiNodeName) then return nil end
    for i = 1, NumTaxiNodes() do
        if TaxiNodeGetType(i) == "CURRENT" then return TaxiNodeName(i) end
    end
end

local function OnTakeTaxiNode(slot)
    local to = TaxiNodeName and TaxiNodeName(slot)
    local from = currentNodeName() or (GetMinimapZoneText and GetMinimapZoneText())
    pendingRoute = { from = from, to = to, t = GetTime() }
    ns.Log("D", "flug", "Flight selected: %s -> %s", tostring(from), tostring(to))
end

local function onTaxi()
    if not UnitOnTaxi then return false end
    local ok, v = pcall(UnitOnTaxi, "player")
    if not ok or (type(issecretvalue) == "function" and issecretvalue(v)) then return false end
    return v and true or false
end

function ns.CheckTaxi()
    local t = ns.trip
    if t.active and t.simulated then
        if GetTime() >= t.simEnd then ns.EndTrip(true) end
        if ns.OnTripTick then ns.OnTripTick() end
        return
    end
    local on = onTaxi()
    if on and not (t.active and t.kind == "flug") then
        if t.active then ns.EndTrip(false) end   -- z. B. vom Anleger direkt zum Flugmeister
        local r = pendingRoute
        pendingRoute = nil
        local known = r and GetTime() - r.t < 90
        -- ohne gewähltes Ziel (z. B. /reload mitten im Flug) gibt es keine Strecke
        ns.BeginTrip({ kind = "flug", from = known and r.from or nil, to = known and r.to or nil })
    elseif not on and t.active and t.kind == "flug" then
        ns.EndTrip(true)
    elseif t.active and ns.OnTripTick then
        ns.OnTripTick()
    end
end

local function EnsureTicker()
    if flightTicker then return end
    flightTicker = C_Timer.NewTicker(1, ns.Wrap("reise-ticker", ns.CheckTaxi))
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ns.eventFrame = ev
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")

local function later(sec, cat, fn) C_Timer.After(sec, ns.Wrap(cat, fn)) end

ev:SetScript("OnEvent", ns.Wrap("event", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then
            InitDB()
            ev:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_LOGIN" then
        ns.playerName = UnitName("player")
        ns.ApplyFaction()          -- vor allen Fenstern, die Farben und Namen lesen
        local build, buildNum = "?", "?"
        if GetBuildInfo then build, buildNum = GetBuildInfo() end
        ns.Log("I", "start", "Pastime %s · Client %s (%s) · %s · %s", ns.VERSION, tostring(build),
            tostring(buildNum), GetLocale and GetLocale() or "?", tostring(ns.playerName))
        local set = ns.DB.settings
        ns.Log("I", "start", "Settings: auto=%s alarm=%s combat=%s sound=%s debug=%s · routes: %d",
            tostring(set.autoOpen), tostring(set.landAlarm), tostring(set.hideInCombat), tostring(set.sound),
            tostring(ns.DB.debug), ns.CountRoutes())
        if TakeTaxiNode and hooksecurefunc then
            hooksecurefunc("TakeTaxiNode", ns.Wrap("flug-hook", OnTakeTaxiNode))
        else
            ns.Log("W", "flug", "TakeTaxiNode missing – flight destination and duration cannot be detected.")
        end
        if ns.CreateMinimapButton then ns.CreateMinimapButton() end
        if ns.CreateSettings then ns.Safe("options", ns.CreateSettings) end
        if ns.StartTransportWatch then ns.StartTransportWatch() end
        if ns.UpdateDebugPanel then ns.UpdateDebugPanel() end
        EnsureTicker()
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
                              "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
            ev:RegisterEvent(e)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        later(1, "flug-login", ns.CheckTaxi)

    elseif event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" then
        later(0.3, "flug-check", ns.CheckTaxi)

    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.inCombat = true      -- InCombatLockdown() meldet den Kampf erst nach diesem Ereignis
        if ns.OnCombat then ns.OnCombat() end

    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.inCombat = false
        if ns.UpdateUI then ns.UpdateUI() end
    end
end))

---------------------------------------------------------------------------
-- Befehle (/pastime) – englische Namen, deutsche Namen gehen ebenfalls
---------------------------------------------------------------------------
local function HelpLines()
    return {
        L["|cffffffff/pastime|r – open or close the game collection"],
        L["|cffffffff/pastime <game>|r – start a game directly (e.g. snake, 2048, solitaire)"],
        L["|cffffffff/pastime records|r – best scores in chat · |cffffffff/pastime routes|r – open the route records"],
        L["|cffffffff/pastime options|r – open the settings"],
        L["|cffffffff/pastime testflight [sec]|r – simulate a trip · |cffffffff/pastime testflight clear|r – remove test routes"],
        L["|cffffffff/pastime dock|r – show the nearest zeppelin tower or boat dock"],
        L["|cffffffff/pastime auto|r · |cffffffff/pastime alarm|r · |cffffffff/pastime combat|r · |cffffffff/pastime sound|r – toggle settings"],
        L["|cffffffff/pastime minimap|r – show or hide the minimap button"],
        L["|cffffffff/pastime log|r – log · |cffffffff/pastime log errors|r – errors and warnings only · |cffffffff/pastime log clear|r"],
        L["|cffffffff/pastime debug|r – live debug window + detailed log · |cffffffff/pastime diag|r – diagnostic report to copy"],
    }
end

-- Einstellungen: Befehl -> { Schlüssel, Bezeichnung }
local SETTING_CMDS = {
    auto = "autoOpen", alarm = "landAlarm", combat = "hideInCombat", kampf = "hideInCombat",
    sound = "sound", ton = "sound",
}
ns.SETTING_LABELS = {
    autoOpen = L["Open when travelling"],
    landAlarm = L["Landing alarm"],
    hideInCombat = L["Hide in combat"],
    sound = L["Game sounds"],
}

local ALIASES = {
    rekorde = "records", rekord = "records", record = "records",
    strecken = "routes", reisen = "routes", reiserekorde = "routes", route = "routes",
    testflug = "testflight", test = "testflight",
    hafen = "dock", haltestelle = "dock", docks = "dock",
    optionen = "options", einstellungen = "options", config = "options", settings = "options",
    bericht = "diag", hilfe = "help", ["?"] = "help",
}

function ns.ToggleSetting(key)
    ns.DB.settings[key] = not ns.DB.settings[key]
    ns.Print(("%s: %s"):format(ns.SETTING_LABELS[key] or key,
        ns.DB.settings[key] and L["|cff80ff80on|r"] or L["|cffff6060off|r"]))
    if ns.UpdateUI then ns.UpdateUI() end
    if ns.RefreshSettings then ns.RefreshSettings() end
end

local function PrintRecords()
    local any = false
    for _, def in ipairs(ns.games) do
        local modes = def.modes or { { id = nil } }
        for _, m in ipairs(modes) do
            local best = ns.BestScore(def, m.id)
            if best then
                any = true
                ns.Print(("%s%s: |cffffffff%s|r (%s, %s)"):format(def.name, m.name and (" – " .. m.name) or "",
                    ns.FormatScore(def, best.s), best.p or "?", best.d or "?"))
            end
        end
    end
    if not any then ns.Print(L["No records yet – time for a flight!"]) end
    local st = ns.DB.stats
    ns.Print(L["Played: %s, %s of it while travelling."]:format(ns.FormatTime(st.total), ns.FormatTime(st.flight)))
end

local function PrintHelp()
    for _, line in ipairs(HelpLines()) do ns.Print(line) end
end

function ns.HandleSlash(msg)
    msg = ns.Trim(msg)
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = (cmd or ""):lower()
    cmd = ALIASES[cmd] or cmd
    local arg = (rest or ""):lower()

    if cmd == "" then
        ns.ToggleFrame()
    elseif SETTING_CMDS[cmd] then
        ns.ToggleSetting(SETTING_CMDS[cmd])
    elseif cmd == "options" then
        if ns.OpenSettings then ns.OpenSettings() end
    elseif cmd == "records" then
        PrintRecords()
    elseif cmd == "routes" then
        ns.ShowFrame("records")
    elseif cmd == "testflight" then
        if arg == "clear" or arg == "löschen" or arg == "loeschen" then
            local n = 0
            for key, r in pairs(ns.DB.routes) do
                if r.kind == "test" then ns.DB.routes[key] = nil; n = n + 1 end
            end
            ns.Print(L["%d test route(s) removed."]:format(n))
            if ns.UpdateUI then ns.UpdateUI() end
            return
        end
        local t = ns.trip
        if t.active then
            if t.simulated then ns.EndTrip(true) else ns.Print(L["You are really travelling right now."]) end
            return
        end
        local sec = math.max(5, math.min(600, tonumber(rest) or 30))
        ns.Print(L["Test flight: %d seconds. |cffffffff/pastime testflight|r again lands immediately."]:format(sec))
        ns.BeginTrip({ kind = "test", from = L["Test Range"], to = L["Orgrimmar"], sim = sec })
    elseif cmd == "dock" then
        if ns.PrintNearestDock then ns.PrintNearestDock() end
    elseif cmd == "minimap" then
        ns.DB.minimap.hidden = not ns.DB.minimap.hidden
        if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
        if ns.RefreshSettings then ns.RefreshSettings() end
    elseif cmd == "log" then
        if arg == "clear" or arg == "leeren" then
            wipe(ns.DB.log); ns.Print(L["Log cleared."])
        elseif arg == "errors" or arg == "fehler" then
            ns.ShowCopy(L["Pastime log: errors and warnings"], ns.FormatLog(200, true))
        else
            ns.ShowCopy(L["Pastime log"], ns.FormatLog(200))
        end
    elseif cmd == "layout" then
        if not ns.DebugOn() then return ns.Print("Layout check needs |cffffffff/pastime debug|r.") end
        ns.Print(("Layout check: %d problem(s) – see |cffffffff/pastime log|r"):format(#ns.LayoutCheck()))
    elseif cmd == "diag" then
        ns.ShowCopy(L["Pastime diagnostics"], ns.DiagReport())
    elseif cmd == "debug" then
        ns.DB.debug = not ns.DB.debug
        ns.Print(ns.DB.debug and L["Debug |cff80ff80on|r – live window open, detailed log running."]
            or L["Debug |cffff6060off|r."])
        ns.Log("I", "debug", "Debug %s", ns.DB.debug and "on" or "off")
        if ns.UpdateDebugPanel then ns.UpdateDebugPanel() end
    elseif cmd == "help" then
        PrintHelp()
    else
        local def = ns.FindGame(cmd)
        if def then
            ns.ShowFrame()
            ns.StartGame(def, ns.DefaultMode(def))
        else
            PrintHelp()
        end
    end
end

SLASH_PASTIME1 = "/pastime"
SlashCmdList["PASTIME"] = function(msg) ns.Safe("slash", ns.HandleSlash, msg) end

BINDING_HEADER_PASTIME = "Pastime"
BINDING_NAME_PASTIME_TOGGLE = L["Open/close the game collection"]
function Pastime_Toggle() ns.Safe("taste", ns.ToggleFrame) end

-- Addon-Fach an der Minimap (Retail-Oberfläche): ## AddonCompartmentFunc in der TOC
function Pastime_OnAddonCompartmentClick() ns.Safe("fach", ns.ToggleFrame) end
