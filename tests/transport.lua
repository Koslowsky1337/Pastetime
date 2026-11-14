-- Zeppelin und Schiff: Sonderfälle (Dauergast am Anleger, /reload unterwegs, heruntergefallen,
-- Ruhestein, Tod) und das Löschen einer Strecke
-- Aufruf: python3 tests/run.py . tests/transport.lua
local ns = KW
local L = ns.L
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 else fails = fails + 1; print("FEHLER: " .. msg) end
end
local function fire(event, ...) ns.eventFrame.scripts.OnEvent(ns.eventFrame, event, ...) end

fire("ADDON_LOADED", "Pastime")
fire("PLAYER_LOGIN")
local trip = ns.trip
local ORG, UC = L["Orgrimmar"], L["Undercity"]

-- Fenster-Öffnungen von selbst zählen
local opens = 0
local origOpen = ns.OpenForTrip
ns.OpenForTrip = function(...)
    local was = ns.frame and ns.frame:IsShown()
    origOpen(...)
    if not was and ns.frame and ns.frame:IsShown() then opens = opens + 1 end
end

local function ttick(n) for _ = 1, n or 1 do NOW = NOW + 0.5; ns.TransportTick() end end
-- Meter je Kartenbreite in der Attrappe
local MX = { [1411] = 5000, [1420] = 4500, [1413] = 8000 }
local function carry(dx, ticks)      -- wird bewegt, ohne selbst zu laufen
    MOVING, SPEED = false, 0
    for _ = 1, ticks do PLAYER.x = PLAYER.x + dx / MX[PLAYER.map]; ttick(1) end
end
local function walk(dx, ticks)
    MOVING, SPEED = true, 7
    for _ = 1, ticks do PLAYER.x = PLAYER.x + dx / MX[PLAYER.map]; ttick(1) end
    MOVING, SPEED = false, 0
end
-- Neuer Fall: Reise beenden, weit weg von allen Anlegern, Fenster zu
local function reset()
    if trip.active then ns.EndTrip(false) end
    MOVING, SPEED = true, 7
    PLAYER.map, PLAYER.x, PLAYER.y = 1413, 0.20, 0.20
    ttick(10)
    MOVING, SPEED = false, 0
    if ns.frame then ns.ShowLauncher(); ns.frame:Hide() end
    opens = 0
end
local function atOrgrimmar() PLAYER.map, PLAYER.x, PLAYER.y = 1411, 0.5082, 0.1354 end
local function routeTo(name)
    for key in pairs(PastimeDB.routes) do if key:find("> " .. name, 1, true) then return key end end
end

-- A: 25 Minuten am Turm stehen – das Fenster öffnet sich einmal, nicht alle zehn Minuten
reset(); atOrgrimmar()
ttick(12)
check(trip.active and trip.phase == "wait" and opens == 1, "A: Warten am Turm öffnet das Fenster")
ns.frame:Hide()
ttick(1210)
check(not trip.active, "A: nach zehn Minuten endet das Warten")
ttick(1800)
check(not trip.active and opens == 1, "A: wer am Turm bleibt, bekommt das Fenster nicht erneut (" .. opens .. "×)")
walk(10, 10); walk(-10, 10)
ttick(12)
check(trip.active and trip.phase == "wait" and opens == 2, "A: weggehen und wiederkommen wartet wieder")

-- B: /reload mitten in der Fahrt – beim Anlegen am Ziel startet keine Reise
reset()
PLAYER.map, PLAYER.x, PLAYER.y = 1420, 0.6074 - 400 / 4500, 0.5887
ttick(2)
carry(8, 50)
check(not trip.active and opens == 0, "B: Anlegen ohne laufende Reise startet keine Phantomreise")
walk(8, 25); ttick(20)      -- aussteigen und weggehen (wer am Turm stehen bleibt, wartet wie jeder andere)
check(not trip.active and opens == 0, "B: auch nach dem Aussteigen keine Reise")
-- ... aber wer ohne Warten einsteigt und abfährt, wird erkannt
reset(); atOrgrimmar()
carry(8, 6)
check(trip.active and trip.phase == "ride" and trip.from == ORG, "B: direkt eingestiegen und abgefahren")

-- C: nach der Abfahrt heruntergefallen, zurück zum Turm, nächster Zeppelin
reset(); atOrgrimmar()
ttick(12); carry(8, 8)
check(trip.phase == "ride", "C: abgefahren")
walk(-8, 8); ttick(8)
check(trip.active and trip.phase == "wait" and trip.start == nil, "C: zurück am Startanleger wartet man wieder")
ttick(200)
carry(8, 40)
check(trip.phase == "ride", "C: zweite Abfahrt")
PLAYER.map, PLAYER.x, PLAYER.y = 1420, 0.5900, 0.5887
ttick(1); carry(8, 9); ttick(10)
local zr = PastimeDB.routes[ns.RouteKey("zeppelin", ORG, UC)]
check(not trip.active and zr and zr.t and zr.t < 45, "C: gemerkt wird die Dauer der zweiten Fahrt: " .. tostring(zr and zr.t) .. " s")

-- D: Ruhestein während der Fahrt – keine falsche Strecke
reset(); PastimeDB.routes = {}
atOrgrimmar(); ttick(12); carry(8, 8)
PLAYER.map, PLAYER.x, PLAYER.y = 1413, 0.52, 0.30
ttick(20)
check(not trip.active, "D: wer fernab der Anleger still steht, ist nicht mehr an Bord")
PLAYER.x, PLAYER.y = 0.6374, 0.3850
ttick(4)
check(routeTo(L["Ratchet"]) == nil and next(PastimeDB.routes) == nil, "D: keine Strecke Orgrimmar > Ratchet")

-- E: Tod während der Fahrt
reset(); atOrgrimmar(); ttick(12); carry(8, 8)
check(trip.active and trip.phase == "ride", "E: unterwegs")
fire("PLAYER_DEAD")
check(not trip.active, "E: Tod beendet die Reise")
-- ein Flug bleibt davon unberührt
reset()
ns.BeginTrip({ kind = "flug", from = "A", to = "B" })
fire("PLAYER_DEAD")
check(trip.active, "E: PLAYER_DEAD lässt Flüge in Ruhe")
ns.EndTrip(false)

-- F: Strecke löschen (zweiter Klick bestätigt)
reset(); PastimeDB.routes = {}
ns.Route("zeppelin", ORG, L["Ratchet"]).n = 1
ns.Route("zeppelin", ORG, UC).n = 1
ns.ShowFrame("records")
local d = ns.records.detail
ns.selectedRoute = ns.RouteKey("zeppelin", ORG, L["Ratchet"]); ns.UpdateRecords()
check(d.del:IsShown() and d.del:GetText() == L["Delete route"], "F: Knopf „Strecke löschen“")
d.del:Click()
check(ns.CountRoutes() == 2 and d.del:GetText() == L["Really delete?"], "F: erster Klick fragt nach")
d.del:Click()
check(ns.CountRoutes() == 1 and routeTo(L["Ratchet"]) == nil and d.del:GetText() == L["Delete route"], "F: zweiter Klick löscht")
d.del:Click()
ns.records.list.rows[1]:Click()      -- Kopfzeile anklicken: Auswahl bleibt, Nachfrage auch
check(ns.CountRoutes() == 1, "F: die andere Strecke bleibt, solange nicht bestätigt wird")
ns.frame:Hide()

local errs = {}
for _, e in ipairs(PastimeDB.log) do if e.l == "E" then table.insert(errs, e.c .. ": " .. e.m) end end
check(#errs == 0 and #ERRORS_FORWARDED == 0, "keine Fehler: " .. table.concat(errs, "; "))
print(("Transport-Tests: %d ok, %d Fehler"):format(passes, fails))
