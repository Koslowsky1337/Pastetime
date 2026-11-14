-- Allianz-Charakter: Spiel-Varianten, Fensterfarben, Texte
-- Aufruf: python3 tests/run.py . tests/alliance.lua   (LOCALE=enUS für Englisch)
local ns = KW
local L = ns.L
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 else fails = fails + 1; print("FEHLER: " .. msg) end
end
local function fire(event, ...) ns.eventFrame.scripts.OnEvent(ns.eventFrame, event, ...) end
local function key(k)
    local gv = ns.gameView
    gv.scripts.OnKeyDown(gv, k)
    gv.scripts.OnKeyUp(gv, k)
end
local function start(id)
    ns.StartGame(ns.gamesById[id])
    return ns.run.game
end

UnitFactionGroup = function() return "Alliance", "Alliance" end
fire("ADDON_LOADED", "Pastime")
fire("PLAYER_LOGIN")
SlashCmdList.PASTIME("")

-- Fenster in Allianz-Blau
check(ns.THEME == ns.THEMES.Alliance and ns.THEME.border[3] > ns.THEME.border[1], "Fenster: blaue Akzente")

-- Namen, Icons und Texte der Varianten
local G = ns.gamesById
check(G.flappy.name == L["Gryphon Flight"] and G.flappy.icon:find("Gryphon"), "Greifenflug statt Windreiter")
check(G.kodo.name == L["Ram Dash"] and G.kodo.icon:find("MountainRam"), "Widder-Sprint statt Kodo-Sprint")
check(G.simon.name == L["Bell Echo"] and G.simon.icon:find("Bell"), "Glocken-Echo statt Totem-Echo")
check(G.viergewinnt.icon:find("PVP_02"), "Vier in einer Reihe: Allianz-Banner in der Liste")
check(G.snake.name == L["Wind Serpent"] and G.snake.desc:find("Elwynn", 1, true), "Windnatter bleibt, Beschreibung Elwynn")
check(ns.FindGame("greif") == G.flappy and ns.FindGame("widder") == G.kodo and ns.FindGame("glocken") == G.simon, "Befehle für die Allianz-Namen")

-- Übersetzt (deDE) bzw. ohne Deutsch (enUS)
local texts = {}
for _, id in ipairs({ "flappy", "kodo", "simon", "snake" }) do
    for k, v in pairs(G[id].alliance or {}) do if k ~= "icon" then texts[#texts + 1] = v end end
end
for _, t in ipairs({ L["Crash landing in the snow!"], L["Ran into an ice block!"], L["Caught by an owl!"], L["Elwynn Trout"],
    L["Gold bell"], L["Wrong bell – it should have been %s.\nCompleted: %d rounds"] }) do texts[#texts + 1] = t end
local german = 0
for _, t in ipairs(texts) do
    for _, u in ipairs({ "ä", "ö", "ü", "ß", " der ", " die ", "Glocke", "Greif", "Widder" }) do
        if t:find(u, 1, true) then german = german + 1; break end
    end
end
if ns.LOCALE == "enUS" then
    check(german == 0, "keine deutschen Texte im englischen Client")
else
    check(G.flappy.name == "Greifenflug" and G.kodo.name == "Widder-Sprint" and G.simon.name == "Glocken-Echo", "deutsche Namen")
    check(german >= 6, "Allianz-Texte übersetzt (" .. german .. "/" .. #texts .. ")")
end

-- Greifenflug: Greif, Schnee
local g = start("flappy")
check(g.player.tex:find("Gryphon") and g.look.crash == L["Crash landing in the snow!"], "Greifenflug: Greif und Schnee")

-- Widder-Sprint: Widder, Eule, Eisblock ohne Arme
g = start("kodo")
check(g.kodo.tex:find("MountainRam") and g.pool[1].bird.tex:find("Owl"), "Widder-Sprint: Widder und Eule")
key("SPACE"); g.vh, g.h = 0, 0
for _, o in ipairs(g.pool) do g:HideObstacle(o) end
g.score = 0
g:NewObstacle()
local o
for _, p in ipairs(g.pool) do if p.active then o = p end end
check(o and (o.kind ~= "kaktus" or not o.armL:IsShown()), "Widder-Sprint: Eisblöcke ohne Kaktusarme")
o.kind, o.x, o.w, o.top, o.bottom = "kaktus", 60, 16, 290, 330
g:Update(0.001)
check(ns.overlay.text.text:find(L["Ran into an ice block!"], 1, true), "Widder-Sprint: „Gegen einen Eisblock gerannt!“")

-- Windnatter: grüne Wiese
g = start("snake")
check(g.bgA[2] > g.bgA[1], "Windnatter: Wiese statt Wüste")

-- Angeln: Elwynn-Fische
g = start("angeln")
check(g.fish[1][1][1] == L["Elwynn Trout"] and g.fish[5][1][1] == L["Ancient Turtle"], "Angeln: Elwynn-Fische")

-- Glocken-Echo: Glocken mit Farben, Meldung bei Fehler
g = start("simon")
check(g.buttons[1].label.text == L["Gold bell"] and g.buttons[4].label.text == L["Ruby bell"], "Glocken-Echo: Beschriftung")
g.state, g.seq, g.pos = "input", { 1 }, 1
g:Press(2)
check(ns.overlay.text.text:find(L["Gold bell"], 1, true), "Glocken-Echo: Fehlermeldung nennt die Glocke")

-- Vier in einer Reihe, Kartenrücken, Runenpaare, Minenfeld
g = start("viergewinnt")
check(g.ally, "Vier in einer Reihe: Allianz")
g = start("memory")
check(g.set.cards[1].emblem.tex:find("Alliance"), "Runenpaare: Allianz-Wappen")
g = start("blackjack")
check(g.dealerCards[1].emblem.tex:find("PVP_02"), "Kartenrücken: Allianz-Banner")

-- Testflug: Ziel der eigenen Fraktion
SlashCmdList.PASTIME("testflug 20")
check(ns.trip.active and ns.trip.to == L["Stormwind"], "Testflug der Allianz geht nach Stormwind: " .. tostring(ns.trip.to))
SlashCmdList.PASTIME("testflug")
SlashCmdList.PASTIME("testflug löschen")

print(("Allianz-Tests: %d ok, %d Fehler"):format(passes, fails))
