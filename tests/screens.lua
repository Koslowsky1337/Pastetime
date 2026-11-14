-- Alle Bildschirme durch den Layout-Prüfer (mit dem Layout-Rechner aus layoutsim.lua)
-- Aufruf: python3 tests/run.py . tests/screens.lua
--         LOCALE=enUS und/oder FACTION=Alliance für die anderen Varianten
local ns = KW
local L = ns.L
local fire = function(event, ...) ns.eventFrame.scripts.OnEvent(ns.eventFrame, event, ...) end
local function slash(s) SlashCmdList.PASTIME(s) end

fire("ADDON_LOADED", "Pastime")
fire("PLAYER_LOGIN")
slash("")

local found, seen = {}, {}
local function scan(where)
    for _, m in ipairs(ns.LayoutCheck({ ns.frame })) do
        local key = where:gsub(" %b()", "") .. m
        if not seen[m] then
            seen[m] = true
            found[#found + 1] = where .. ": " .. m
        end
    end
end

-- Bestenlisten füllen: lange Namen und große Zahlen
for _, def in ipairs(ns.games) do
    for _, m in ipairs(def.modes or { { id = nil } }) do
        local list = ns.GetScores(def, m.id)
        for i = 1, 5 do table.insert(list, { s = def.lowerIsBetter and (61 + i) or (1054000 - i), p = "Thokk", d = date(ns.DATE_FORMAT) }) end
    end
end

-- 1. Auswahl: jedes Spiel, jede Schwierigkeit
ns.ShowLauncher()
for _, def in ipairs(ns.games) do
    for _, m in ipairs(def.modes or { { id = nil } }) do
        ns.selected = def
        if m.id then ns.DB.modes[def.id] = m.id end
        ns.UpdateUI()
        scan("Auswahl " .. def.id .. (m.id and (" " .. m.id) or ""))
    end
end

-- 2. Auswahl während einer Reise (Streckenzeile) und Reiserekorde
slash("testflug 600")
for _, def in ipairs(ns.games) do
    ns.ShowLauncher()
    ns.selected = def
    ns.UpdateUI()
    scan("Auswahl mit Reise " .. def.id)
end

-- 3. Jedes Spiel: laufend, Pause, Spielende
for _, def in ipairs(ns.games) do
    for _, m in ipairs(def.modes or { { id = nil } }) do
        ns.StartGame(def, m.id)
        ns.UpdateSidePanel()
        scan("Spiel " .. def.id)
        ns.Pause()
        scan("Pause " .. def.id)
        ns.Resume()
        ns.SetCountdown(nil)
        ns.GameOver({ score = def.lowerIsBetter and 754 or 1054000, won = true,
            text = def.name .. " – " .. L["Game over"] })
        ns.UpdateSidePanel()
        scan("Spielende " .. def.id)
    end
end

-- 4. Ankunft mitten im Spiel
ns.StartGame(ns.gamesById.tetris)
ns.run.game.score = 1054000
slash("testflug")
scan("Ankunft")

-- 5. Reiserekorde
ns.ShowFrame("records")
scan("Reiserekorde")

for _, f in ipairs(found) do print("FEHLER: " .. f) end

-- Gegenprobe: ein zu langer Knopftext muss auffallen, sonst ist der Prüfer blind
ns.StartGame(ns.gamesById.snake)
ns.Pause()
local old = ns.overlay.btn1:GetText()
ns.overlay.btn1:SetText(("W"):rep(30))
local hits = 0
for _, m in ipairs(ns.LayoutCheck({ ns.frame })) do if m:find("WWWW", 1, true) then hits = hits + 1 end end
ns.overlay.btn1:SetText(old)
if hits == 0 then print("FEHLER: Gegenprobe – zu langer Knopftext wurde nicht erkannt") end

print(("Bildschirm-Tests (%s, %s): %d ok, %d Fehler"):format(ns.LOCALE, ns.IsAlliance() and "Allianz" or "Horde",
    hits > 0 and 1 or 0, #found + (hits > 0 and 0 or 1)))
