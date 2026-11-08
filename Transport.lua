-- Pastime: Zeppeline und Schiffe – Haltestellen, Abfahrt, Ankunft
--
-- Haltestellen: ForeverDungeonJournal (Systems/MapMarkers.lua, RIDES – dort,
-- wo Zeppelin- und Dockmeister stehen) und Leatrix Maps (Leatrix_Maps_Icons.lua)
-- für Unterstadt <-> Grom'gol und Mulgore -> Insel Zephras.
--
-- Ablauf: Wer ein paar Sekunden an einem Turm/Anleger steht, „wartet“
-- (Fenster öffnet sich). Wird man danach bewegt, ohne selbst zu laufen, hat
-- das Schiff abgelegt. Angekommen ist man, wenn man an einem anderen Anleger
-- steht oder dort selbst losläuft.
local ADDON, ns = ...
local L = ns.L

local WAIT_R = 35          -- Meter: am Turm/Anleger
local BOARD_R = 90         -- Meter: Abfahrt noch dem Anleger zuordnen
local ARRIVE_R = 70        -- Meter: am Ziel
local LEAVE_R = 70         -- Meter: zu Fuß so weit weg -> doch nicht eingestiegen
local AWAY = 300           -- Meter: erst so weit vom Start zählt ein Anleger als Ziel
local WAIT_OPEN = 5        -- Sekunden stillstehen, bis die Wartezeit beginnt
local STEP = 0.5
local MAX_WAIT, MAX_RIDE = 10 * 60, 15 * 60

-- { Karte, x, y, Name, Art, Fraktion (nil = alle), fährt nach }
local DOCKS = {
    -- Horde: Zeppeline
    { 1411, 0.5082, 0.1354, L["Orgrimmar"], "zeppelin", "Horde", L["Undercity"] },
    { 1411, 0.5069, 0.1289, L["Orgrimmar"], "zeppelin", "Horde", "Grom'gol" },
    { 1420, 0.6074, 0.5887, L["Undercity"], "zeppelin", "Horde", L["Orgrimmar"] },
    { 1420, 0.6190, 0.5890, L["Undercity"], "zeppelin", "Horde", "Grom'gol" },        -- Leatrix Maps
    { 1434, 0.3143, 0.2991, "Grom'gol", "zeppelin", "Horde", L["Orgrimmar"] },
    { 1434, 0.3150, 0.2910, "Grom'gol", "zeppelin", "Horde", L["Undercity"] },        -- Leatrix Maps
    { 2521, 0.5798, 0.8057, L["Zephras Isle"], "zeppelin", "Horde", L["Thunder Bluff"] },
    { 1412, 0.3340, 0.2250, L["Thunder Bluff"], "zeppelin", "Horde", L["Zephras Isle"] },
    { 1412, 0.3430, 0.2610, L["Thunder Bluff"], "zeppelin", "Horde", L["Zephras Isle"] },   -- Leatrix Maps
    -- Für alle: Schiffe
    { 1434, 0.2608, 0.7335, L["Booty Bay"], "schiff", nil, L["Ratchet"] },
    { 1413, 0.6374, 0.3850, L["Ratchet"], "schiff", nil, L["Booty Bay"] },
    { 1446, 0.6757, 0.2310, "Tanaris", "schiff", nil, L["Riverglades"] },
    { 2548, 0.7938, 0.5341, L["Riverglades"], "schiff", nil, "Tanaris" },
    { 1438, 0.5560, 0.9650, "Rut'theran", "schiff", nil, "Auberdine" },
    { 1439, 0.3240, 0.3980, "Auberdine", "schiff", nil, "Rut'theran" },
    -- Allianz
    { 1453, 0.2322, 0.5505, L["Stormwind"], "schiff", "Alliance", "Auberdine" },
    { 1439, 0.3079, 0.4082, "Auberdine", "schiff", "Alliance", L["Stormwind"] },
    { 1439, 0.3230, 0.4376, "Auberdine", "schiff", "Alliance", L["Menethil Harbor"] },
    { 1424, 0.5068, 0.6935, L["Southshore"], "schiff", "Alliance", "Auberdine" },
    { 1437, 0.0483, 0.5704, L["Menethil Harbor"], "schiff", "Alliance", L["Southshore"] },
    { 1437, 0.0521, 0.6371, L["Menethil Harbor"], "schiff", "Alliance", "Theramore" },
    { 1445, 0.7128, 0.5629, "Theramore", "schiff", "Alliance", L["Menethil Harbor"] },
    { 2521, 0.6569, 0.8322, L["Zephras Isle"], "zeppelin", "Alliance", "Dalaran" },
    { 1416, 0.1230, 0.5649, "Dalaran", "zeppelin", "Alliance", L["Zephras Isle"] },
}
ns.DOCKS = DOCKS

---------------------------------------------------------------------------
-- Welt-Koordinaten (Meter) über die Karten-API
---------------------------------------------------------------------------
local function World(map, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos) then return nil end
    local v = CreateVector2D and CreateVector2D(x, y) or { x = x, y = y }
    local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, map, v)
    if not ok or type(pos) ~= "table" then return nil end
    local wx, wy = pos.x, pos.y
    if (wx == nil or wy == nil) and pos.GetXY then wx, wy = pos:GetXY() end
    wx, wy, cont = ns.Num(wx), ns.Num(wy), ns.Num(cont)
    if not (wx and wy and cont) then return nil end
    return wx, wy, cont
end

local function PlayerWorld()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
    map = ok and ns.Num(map) or nil
    if not map then return nil end
    local ok2, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
    if not ok2 or type(pos) ~= "table" then return nil end
    local x, y = pos.x, pos.y
    if (x == nil or y == nil) and pos.GetXY then x, y = pos:GetXY() end
    x, y = ns.Num(x), ns.Num(y)
    if not (x and y) then return nil end
    local wx, wy, c = World(map, x, y)
    return wx, wy, c, map, x, y
end

local function flag(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or (type(issecretvalue) == "function" and issecretvalue(v)) then return nil end
    return v and true or false
end

local function OwnSpeed()
    if not GetUnitSpeed then return nil end
    local ok, v = pcall(GetUnitSpeed, "player")
    return ok and ns.Num(v) or nil
end

local function dist(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local S = { samples = {}, n = 0, seq = 0, ring = {}, snapSeq = 0 }
ns.transportState = S

local resolved
local function Docks()
    if resolved then return resolved end
    local list = {}
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    for _, d in ipairs(DOCKS) do
        if not d[6] or d[6] == faction then
            local wx, wy, c = World(d[1], d[2], d[3])
            if wx then
                table.insert(list, { x = wx, y = wy, c = c, map = d[1], name = d[4], kind = d[5], to = d[7] })
            end
        end
    end
    if #list > 0 then
        resolved = list
        ns.Log("I", "hafen", "Docks computed: %d (faction %s, %d in the list)", #list, tostring(faction), #DOCKS)
    elseif not S.warnedDocks then
        S.warnedDocks = true
        ns.Log("W", "hafen", "No dock could be converted to world coordinates (faction %s) – will keep trying.", tostring(faction))
    end
    return list
end

local function Nearest(x, y, c)
    local best, bd
    for _, d in ipairs(Docks()) do
        if d.c == c then
            local dd = dist(x, y, d.x, d.y)
            if not bd or dd < bd then best, bd = d, dd end
        end
    end
    return best, bd
end

---------------------------------------------------------------------------
-- Reise-Mitschnitt: Messpunkte rund um Haltestellen und während jeder Fahrt
-- (immer, auch ohne /pastime debug). Bei Warten/Abfahrt/Ankunft/Abbruch werden
-- die neuen Punkte in PastimeDB.traces gespeichert (die letzten TRACE_KEEP).
-- Ein Punkt: Uhrzeit Phase Karte x,y Kontinent v=bewegt sp=eigenes Tempo
--            mv=läuft selbst Haltestelle Entfernung getragen(C)/still(-)
---------------------------------------------------------------------------
local TRACE_MAX, TRACE_KEEP, TRACE_NEAR = 240, 8, 400

local function Record(line)
    S.seq = S.seq + 1
    table.insert(S.ring, { S.seq, line })
    if #S.ring > TRACE_MAX then table.remove(S.ring, 1) end
end

function ns.TraceSnapshot(event, info)
    if not ns.DB then return end
    ns.DB.traces = type(ns.DB.traces) == "table" and ns.DB.traces or {}
    local entry = { e = event, d = date("%Y-%m-%d %H:%M:%S"), info = info, s = {} }
    for _, p in ipairs(S.ring) do
        if p[1] > S.snapSeq then table.insert(entry.s, p[2]) end
    end
    S.snapSeq = S.seq
    table.insert(ns.DB.traces, entry)
    while #ns.DB.traces > TRACE_KEEP do table.remove(ns.DB.traces, 1) end
end

-- Letzte n Messpunkte als Text (für /pastime diag)
function ns.TraceTail(n)
    local out = {}
    for i = math.max(1, #S.ring - n + 1), #S.ring do table.insert(out, S.ring[i][2]) end
    return out
end

function ns.DockCount() return #Docks(), #DOCKS end

---------------------------------------------------------------------------
-- Überwachung
---------------------------------------------------------------------------
local function carriedCount(n)
    local c = 0
    for i = math.max(1, #S.samples - n + 1), #S.samples do if S.samples[i] then c = c + 1 end end
    return c
end

local function Tick()
    local t = ns.trip
    S.n = S.n + 1
    if (t.active and (t.kind == "flug" or t.kind == "test")) or flag(UnitOnTaxi, "player") or flag(IsInInstance) then
        S.last = nil
        S.live = { note = "Flight, test flight or instance – dock watch paused" }
        return
    end
    local x, y, c, map, mx, my = PlayerWorld()
    local now = GetTime()
    if not x then
        S.last = nil
        S.live = { note = "Position unknown" }
        return
    end

    local speed = OwnSpeed()
    local moving = flag(IsPlayerMoving)
    local v, carried = 0, false
    local LV = S.last
    if LV and LV.c == c then
        local dt = now - LV.t
        if dt > 0.2 and dt < 3 then
            v = dist(x, y, LV.x, LV.y) / dt
            -- bewegt, ohne selbst zu laufen: das Schiff fährt
            carried = v > 4 and v < 80 and not moving and (speed == nil or speed < 0.1 or v > 9)
        end
    end
    S.last = { x = x, y = y, c = c, t = now }
    table.insert(S.samples, carried)
    if #S.samples > 8 then table.remove(S.samples, 1) end
    local walking = moving or (speed and speed > 0.1 and not carried)

    local dock, dd = Nearest(x, y, c)
    S.live = { map = map, mx = mx, my = my, c = c, v = v, speed = speed, moving = moving, carried = carried,
        nc = carriedCount(4), dock = dock, dd = dd, still = S.still, suppress = S.suppress and S.suppress.name }
    if t.active or (dd and dd <= TRACE_NEAR) or ns.DebugOn() then
        Record(("%s %s m%d %.4f,%.4f c%d v=%.1f sp=%s mv=%s %s %.0fm %s"):format(date("%H:%M:%S"),
            t.active and t.phase or "-", map or 0, mx or 0, my or 0, c or -1, v, speed and ("%.1f"):format(speed) or "?",
            moving == nil and "?" or (moving and "j" or "n"), dock and (dock.name .. ">" .. dock.to) or "-", dd or -1,
            carried and "C" or "-"))
    end
    -- Nach einer Ankunft nicht gleich wieder „warten“, erst den Anleger verlassen
    if S.suppress and (S.suppress.c ~= c or dist(x, y, S.suppress.x, S.suppress.y) > WAIT_R + 25) then
        S.suppress = nil
    end

    if not t.active then
        if dock and dd <= BOARD_R and carriedCount(4) >= 3 and dock ~= S.suppress then
            -- direkt eingestiegen und schon unterwegs
            ns.BeginTrip({ kind = dock.kind, phase = "wait", from = dock.name, to = dock.to, dock = dock })
            ns.DepartTrip()
            S.still = 0
        elseif dock and dd <= WAIT_R and dock ~= S.suppress and not walking and v < 1 then
            if S.waitDock ~= dock then S.waitDock, S.waitSince = dock, now end
            if now - S.waitSince >= WAIT_OPEN then
                S.waitDock = nil
                ns.BeginTrip({ kind = dock.kind, phase = "wait", from = dock.name, to = dock.to, dock = dock })
            end
        elseif not (dock and dd <= WAIT_R) or walking then
            S.waitDock = nil
        end
        return
    end

    if t.phase == "wait" then
        local origin = t.dock
        if dock and dd <= WAIT_R and dock.name == origin.name then
            t.dock, t.to = dock, dock.to       -- welche Seite des Turms?
            origin = dock
        end
        if S.n % 8 == 0 then
            ns.Log("D", "hafen", "wait: v=%.1f speed=%s moving=%s %s %.0f m", v, tostring(speed), tostring(moving),
                dock and dock.name or "-", dd or -1)
        end
        if carriedCount(4) >= 3 then
            ns.Log("I", "hafen", "Departure detected: v=%.1f m/s, own speed=%s, moving=%s", v, tostring(speed), tostring(moving))
            ns.DepartTrip()
            S.still = 0
        elseif c ~= origin.c or (walking and dist(x, y, origin.x, origin.y) > LEAVE_R) then
            -- doch nicht eingestiegen (Werte fürs Protokoll, falls die Abfahrt nicht erkannt wurde)
            ns.Log("I", "hafen", "Waiting ended without departure: v=%.1f m/s, own speed=%s, moving=%s, %.0f m from the dock",
                v, tostring(speed), tostring(moving), c == origin.c and dist(x, y, origin.x, origin.y) or -1)
            ns.EndTrip(false)
        elseif now - (t.waitStart or now) > MAX_WAIT then
            ns.EndTrip(false)
        end
        return
    end

    -- unterwegs
    if S.n % 8 == 0 then
        ns.Log("D", "hafen", "ride: v=%.1f speed=%s moving=%s %s %.0f m", v, tostring(speed), tostring(moving),
            dock and dock.name or "-", dd or -1)
    end
    local origin = t.dock
    local away = (not origin) or c ~= origin.c or dist(x, y, origin.x, origin.y) > AWAY
    if away and dock and dd <= ARRIVE_R and dock.name ~= (origin and origin.name) then
        if carried then S.still = 0 else S.still = (S.still or 0) + STEP end
        if S.still >= 3 or walking then
            S.still = 0
            S.suppress = dock
            ns.EndTrip(true, dock.name)
            return
        end
    else
        S.still = 0
    end
    if now - (t.start or now) > MAX_RIDE then ns.EndTrip(false) end
end
ns.TransportTick = Tick

function ns.StartTransportWatch()
    if S.ticker then return end
    S.ticker = C_Timer.NewTicker(STEP, ns.Wrap("hafen", Tick))
end

function ns.PrintNearestDock()
    local list = Docks()
    if #list == 0 then
        ns.Print(L["Dock positions could not be computed (yet)."])
        return
    end
    local x, y, c = PlayerWorld()
    if not x then ns.Print(L["Position unknown (instance?)."]); return end
    local d, dd = Nearest(x, y, c)
    if not d then ns.Print(L["Pastime knows no dock on this continent."]); return end
    local K = ns.KINDS[d.kind]
    ns.Print((L["Nearest dock: |cffffffff%s|r (%s to %s), %d m away%s."]):format(d.name, K.one, d.to,
        math.floor(dd + 0.5), dd <= WAIT_R and L[" – you are standing there"] or ""))
    local t = ns.trip
    if t.active then ns.Print(ns.TripStatus() or "") end
end
