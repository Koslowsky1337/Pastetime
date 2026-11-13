-- Logiktests der neuen Spiele (nach mock.lua + Addon geladen)
local ns = KW
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 else fails = fails + 1; print("FEHLER: " .. msg) end
end
local function fire(event, ...) ns.eventFrame.scripts.OnEvent(ns.eventFrame, event, ...) end
local function tick(sec, step)
    step = step or 0.05
    local t = 0
    while t < sec do
        NOW = NOW + step
        local gv = ns.gameView
        if gv and gv.scripts.OnUpdate then gv.scripts.OnUpdate(gv, step) end
        t = t + step
    end
end
local function key(k)
    local gv = ns.gameView
    gv.scripts.OnKeyDown(gv, k)
    local consumed = not gv.propagate
    gv.scripts.OnKeyUp(gv, k)
    return consumed
end
local function start(id, mode)
    ns.StartGame(ns.gamesById[id], mode)
    return ns.run.game
end
local function over() return ns.run and ns.run.state == "over" end
local function best(key) local l = PastimeDB.scores[key]; return l and l[1] and l[1].s end

fire("ADDON_LOADED", "Pastime")
fire("PLAYER_LOGIN")
SlashCmdList.PASTIME("")

-- Windnatter: Kopf folgt direkt dem Schwanz -------------------------------------
local g = start("snake")
for _, s in ipairs(g.snake) do g.occ[s.x * 100 + s.y] = nil; g:PaintCell(s.x, s.y, false) end
g.snake = { { x = 5, y = 5 }, { x = 6, y = 5 }, { x = 6, y = 6 }, { x = 5, y = 6 } }
for _, s in ipairs(g.snake) do g.occ[s.x * 100 + s.y] = true; g:PaintCell(s.x, s.y, true) end
g.fx, g.fy, g.dir, g.queue, g.waiting = 1, 1, { 0, 1 }, {}, false
g:Tick()
local function isBody(x, y) return (g.grid.cache[(y - 1) * 21 + x] or 0) % 1 == 0.5 end
check(not g.dead and g.snake[1].x == 5 and g.snake[1].y == 6, "Windnatter: in die frei werdende Schwanzspitze")
check(isBody(5, 6) and isBody(5, 5) and isBody(6, 5) and isBody(6, 6), "Windnatter: Körper ohne Lücke")
check(#g.snake == 4 and g.occ[506] and g.occ[505], "Windnatter: Länge und Belegung stimmen")

-- Windnatter: Ablauf (Start, Fressen, Perle, Stufe, Umkehr, Wand, Neustart)
g = start("snake")
check(g.waiting and g.hint:IsShown(), "Windnatter wartet mit Hinweis")
key("LEFT")
check(g.waiting, "Windnatter: Gegenrichtung startet nicht")
key("RIGHT")
check(not g.waiting and not g.hint:IsShown(), "Windnatter startet mit Pfeiltaste")
key("LEFT")
check(#g.queue == 0, "Windnatter: Umkehr wird ignoriert")
g.fx, g.fy = 12, 11
g:Tick()
check(g.eaten == 1 and g.score == 10 and #g.snake == 4, "Windnatter frisst Ei: 10 Punkte, wächst")
check(g.step == 0.15, "Windnatter: ein Ei macht noch nicht schneller")
g.eaten = 4
local h = g.snake[1]
g.fx, g.fy = h.x + 1, h.y
g:Tick()
check(g.pearl and g.pearlTex:IsShown() and g.score == 20, "Windnatter: Perle nach 5 Eiern")
h = g.snake[1]
g.pearl.x, g.pearl.y = h.x + 1, h.y
g:Tick()
check(g.pearls == 1 and g.pearl == nil and g.score == 60, "Windnatter: Perle gibt 30 + 10 × Stufe")
g.eaten = 7
h = g.snake[1]
g.fx, g.fy = h.x + 1, h.y
g:Tick()
check(g:Level() == 2 and g.score == 80, "Windnatter: ab 8 Eiern Stufe 2, Ei 20 Punkte")
check(math.abs(g.step - 0.135) < 1e-9, "Windnatter: Stufe 2 ist schneller (0,135 s)")
check(g:Info()[4][1] == (ns.LOCALE == "deDE" and "Stufe" or "Level"), "Windnatter: Seitenleiste zeigt Stufe")
g.eaten = 40; h = g.snake[1]; g.fx, g.fy = h.x, h.y + 1; g.dir = { 0, 1 }; g:Tick()
check(math.abs(g.step - 0.075) < 1e-9, "Windnatter: Höchsttempo 0,075 s ab Stufe 6")
g.eaten = 5; g.pearl = { x = 1, y = 1, t = 0.1 }; g.pearlTex:Show()
g.fx, g.fy = 1, 21
tick(0.06)
check(g.pearl == nil and not g.pearlTex:IsShown(), "Windnatter: Perle verschwindet nach Ablauf")
local score = g.score
tick(3)
check(over() and g.dead and best("snake") == score, "Windnatter: Wand beendet die Partie, Wertung " .. score)
check(ns.overlay:IsShown() and ns.overlay.kind == "over", "Spielende-Overlay sichtbar")
key("SPACE")
check(ns.run.state == "running" and ns.run.game.waiting, "Windnatter: Leertaste startet neu")
g = ns.run.game
key("RIGHT"); tick(3)
check(over() and #PastimeDB.scores.snake == 1, "Windnatter: 0 Punkte kommen nicht in die Bestenliste")

-- Windreiter -------------------------------------------------------------------
g = start("flappy")
check(g.waiting and g.hint:IsShown(), "Windreiter wartet mit Hinweis")
check(key("UP") and not g.waiting and g.vy < 0, "Windreiter startet mit Hoch/Leertaste/W")
local sp
for _, s in ipairs(g.pool) do if s.active then sp = s end end
check(sp ~= nil and sp.x > 420, "erste Felsnadel kommt von rechts")
-- Nadel durchfliegen: Lücke um den Reiter, Nadel knapp hinter ihm
g.y, g.vy = 200, 0
sp.top, sp.bottom, sp.x = 150, 260, 110 - 12 - 54 - 1
g:Update(0.01)
check(g.score == 1 and sp.passed, "Windreiter: Nadel durchflogen = 1 Punkt")
-- Countdown nach der Pause
key("P")
check(ns.run.state == "paused", "Windreiter pausiert mit P")
ns.Resume()
check(ns.run.countdown == 3 and ns.gameView.countdown:IsShown() and ns.gameView.countdown.text == "3", "Countdown 3 nach Weiter")
check(not ns.host:IsRunning(), "Countdown: Maus fliegt nicht")
local y0, vy0 = g.y, g.vy
key("SPACE")
tick(1.1)
check(g.y == y0 and g.vy == vy0 and ns.gameView.countdown.text == "2", ("Countdown: Spiel steht, Taste geschluckt (y %s/%s vy %s/%s Text %s)"):format(g.y, y0, g.vy, vy0, ns.gameView.countdown.text))
key("P")
check(ns.run.state == "paused" and not ns.gameView.countdown:IsShown(), "Pause während des Countdowns")
ns.Resume()
tick(3.1)
check(ns.run.countdown == nil and not ns.gameView.countdown:IsShown(), "Countdown abgelaufen")
tick(0.2)
check(g.y ~= y0 or g.dead, "Windreiter fliegt nach dem Countdown weiter")
-- Absturz: Wertung
for _, s in ipairs(g.pool) do g:HideSpire(s) end
g.vy = 0
tick(3)
check(over() and best("flappy") == 1, "Windreiter: Absturz beendet die Partie, 1 Punkt gewertet")
check(#g:Info() == 2, "Windreiter: Seitenleiste ohne Lückenhöhe")
-- Leertaste direkt nach dem Absturz startet nicht neu
ns.run.overAt = NOW
check(key("SPACE") and over(), "Leertaste-Sperre direkt nach Spielende")
NOW = NOW + 1
check(key("SPACE") and over(), "nach 1 s noch gesperrt")
NOW = NOW + 0.6
key("SPACE")
check(ns.run.state == "running" and ns.run.game.waiting, "nach 1,5 s startet die Leertaste neu")
check(ns.run.game.hint.text:find("W") and #ns.run.game.hint.text > 0, "Windreiter: Starthinweis gesetzt")
-- Windnatter hat den Countdown auch, Spiele ohne resumeDelay nicht
g = start("snake")
key("RIGHT"); key("P"); ns.Resume()
check(ns.run.countdown == 3, "Windnatter: Countdown nach Pause")
g = start("2048")
key("P"); ns.Resume()
check(ns.run.state == "running" and ns.run.countdown == nil, "2048: kein Countdown")
ns.ShowLauncher()

-- Kobold-Hauen ----------------------------------------------------------------
g = start("kobold")
tick(1.2)
local up
for i, h in ipairs(g.holes) do if h.kind and h.kind ~= "dynamit" then up = i end end
if not up then for _ = 1, 40 do tick(0.1); for i, h in ipairs(g.holes) do if h.kind and h.kind ~= "dynamit" then up = i end end; if up then break end end end
check(up ~= nil, "Kobold taucht auf")
local keys = { "7", "8", "9", "4", "5", "6", "1", "2", "3" }
key(keys[up])
check(g.score >= 10 and g.hits == 1, "Kobold per Ziffer getroffen: " .. g.score)
tick(61)
check(over() and best("kobold") == g.score, "Kobold-Runde endet nach 60 s mit Wertung")

-- Angeln ----------------------------------------------------------------------
g = start("angeln")
key("SPACE")
check(g.state == "wait", "ausgeworfen")
key("SPACE")
check(g.state == "result" and g.streak == 0, "zu früh angeschlagen")
tick(1.3)
check(g.state == "ready", "bereit für nächsten Wurf")
for _ = 1, 9 do
    key("SPACE")
    g.t = 0.2
    tick(0.3)
    check(g.state == "bite", "Biss")
    key("SPACE")
    tick(1.3)
end
tick(1)
check(over() and g.caught == 9 and g.score > 0, "Angeln: 10 Würfe, 9 Fische, Punkte " .. tostring(g.score))
local lo, hi = 0, 0
for _ = 1, 3000 do
    if g.RollQuality(0) >= 3 then lo = lo + 1 end
    if g.RollQuality(1) >= 3 then hi = hi + 1 end
end
check(hi > lo * 1.5, ("schnelle Reaktion bringt öfter Seltenes (%d vs %d)"):format(hi, lo))

-- Kodo-Sprint ------------------------------------------------------------------
g = start("kodo")
tick(1)
check(g.waiting and g.score == 0, "Kodo wartet")
key("SPACE")
check(not g.waiting and g.vh > 0, "Sprung startet Lauf")
local gv = ns.gameView
gv.scripts.OnKeyDown(gv, "S")
check(g.duck, "ducken")
gv.scripts.OnKeyUp(gv, "S")
check(not g.duck, "aufstehen")
tick(60)
check(over() and g.score > 10, "Kodo rennt irgendwann in ein Hindernis: " .. g.score .. " m")
-- Hindernis direkt am Kodo: wer trifft, wer nicht?
local function kodoWith(kind, duck, h)
    g = start("kodo")
    key("SPACE"); g.vh, g.h = 0, h or 0
    for _, o in ipairs(g.pool) do g:HideObstacle(o) end
    g.duck = duck
    local o = g.pool[1]
    o.active, o.kind, o.x, o.w = true, kind, 60, 30
    if kind == "geier" then o.top, o.bottom = 330 - 74, 330 - 38
    elseif kind == "ueberhang" then o.top, o.bottom = 0, 330 - 38
    else o.top, o.bottom = 330 - 40, 330 end
    g:Update(0.001)
    return g.dead
end
check(kodoWith("geier", false), "Kodo: Geier trifft stehend")
check(not kodoWith("geier", true), "Kodo: unter dem Geier weggeduckt")
check(kodoWith("kaktus", false), "Kodo: Kaktus trifft")
check(not kodoWith("kaktus", false, 60), "Kodo: über den Kaktus gesprungen")
check(kodoWith("ueberhang", false), "Kodo: Felsüberhang trifft stehend")
check(not kodoWith("ueberhang", true), "Kodo: unter dem Felsüberhang durchgerutscht")
check(kodoWith("ueberhang", false, 100), "Kodo: Felsüberhang kann man nicht überspringen")
check(ns.overlay.text.text:find(ns.gamesById.kodo.scoreLabel .. ": ", 1, true) and not ns.overlay.text.text:find(ns.L["Points"], 1, true),
    "Kodo: Spielende zeigt Meter statt Punkte: " .. ns.overlay.text.text)
-- Überhänge erst ab 60 m, dann regelmäßig
g = start("kodo"); key("SPACE")
local kinds = {}
for _, sc in ipairs({ 0, 100 }) do
    kinds[sc] = {}
    for _ = 1, 400 do
        for _, o in ipairs(g.pool) do g:HideObstacle(o) end
        g.score = sc; g:NewObstacle()
        kinds[sc][g.pool[1].kind] = (kinds[sc][g.pool[1].kind] or 0) + 1
    end
end
check(not kinds[0].ueberhang and not kinds[0].geier, "Kodo: unter 60 m nur Kakteen und Felsen")
check((kinds[100].ueberhang or 0) > 40 and not kinds[100].geier, "Kodo: ab 60 m Überhänge (" .. (kinds[100].ueberhang or 0) .. "/400)")
-- Countdown nach der Pause
key("P"); ns.Resume()
check(ns.run.countdown == 3, "Kodo: Countdown nach Pause")
-- Sprunghöhe und Luftzeit
g = start("kodo"); key("SPACE")
for _, o in ipairs(g.pool) do g:HideObstacle(o) end
g.nextGap = 1e9
local peak, air = 0, 0
repeat g:Update(0.01); air = air + 0.01; peak = math.max(peak, g.h) until g.h <= 0 or air > 2
check(peak > 120 and peak < 160 and air > 0.55 and air < 0.75, ("Kodo: Sprung %.0f px hoch, %.2f s in der Luft"):format(peak, air))

-- Mauerbrecher -----------------------------------------------------------------
g = start("breakout")
check(g.stuck and g.left == 60, "Ball liegt auf dem Schläger, 60 Steine")
key("SPACE")
check(not g.stuck, "Ball abgeschossen")
g.bx, g.by, g.vx, g.vy = 200, 200, 0, -300
tick(1)
check(g.left < 60 and g.score > 0, "Steine getroffen: " .. g.left .. " übrig, " .. g.score .. " Punkte")
g.lives = 1
g.bx, g.by, g.vx, g.vy, g.px = 10, 420, 0, 300, 300
tick(0.2)
check(over(), "letzter Ball verloren -> Ende")
g = start("breakout")
for _, b in ipairs(g.bricks) do b.hp = 0; b.tex:Hide() end
g.left = 1
g.bricks[1].hp = 1
key("SPACE")
g.bx, g.by, g.vx, g.vy = g.bricks[1].x + 10, 120, 0, -300
tick(1)
check(g.level == 2 and g.left == 60, "Level geschafft -> Level 2")

-- Murloc-Invasion -----------------------------------------------------------------
g = start("murlocs")
check(g.alive == 32, "32 Murlocs")
key("SPACE")
check(g.arrow.active, "Pfeil fliegt")
for _, m in ipairs(g.murlocs) do if m.row == 4 and m.ox == 3 * 44 then g.px = g.gx + m.ox - 1 end end
g.arrow.active = false
key("SPACE")
tick(1)
check(g.alive < 32 and g.score > 0, "Murloc erwischt: " .. g.alive)
for _, m in ipairs(g.murlocs) do m.alive = false end
g.alive = 0
tick(0.1)
check(g.wave == 2 and g.alive == 32, "neue Welle")
g.gy = 380
tick(0.1)
check(over(), "Murlocs am Ufer -> Ende")

-- Totem-Simon ---------------------------------------------------------------------
g = start("simon")
local SK = { "UP", "RIGHT", "DOWN", "LEFT" }
for round = 1, 4 do
    for _ = 1, 100 do tick(0.1); if g.state == "input" then break end end
    check(g.state == "input", "Runde " .. round .. ": Eingabe")
    for _, t in ipairs(g.seq) do key(SK[t]) end
end
check(g.score == 4 and #g.seq == 5, "4 Runden geschafft")
for _ = 1, 100 do tick(0.1); if g.state == "input" then break end end
local wrong = (g.seq[1] % 4) + 1
key(SK[wrong])
check(over() and best("simon") == 4, "falsches Totem -> Ende mit 4 Runden")

-- Memory --------------------------------------------------------------------------
g = start("memory", "leicht")
check(#g.cards == 16, "16 Karten")
local byIcon = {}
for i, c in ipairs(g.cards) do byIcon[c.icon] = byIcon[c.icon] or {}; table.insert(byIcon[c.icon], i) end
-- erst ein Fehlversuch
local ids = {}
for icon, list in pairs(byIcon) do ids[#ids + 1] = list end
g.set.cards[ids[1][1]].scripts.OnClick(g.set.cards[ids[1][1]])
g.set.cards[ids[2][1]].scripts.OnClick(g.set.cards[ids[2][1]])
check(g.lockT ~= nil and g.moves == 1, "Fehlversuch sperrt kurz")
tick(1)
check(not g.cards[ids[1][1]].up, "Karten wieder zu")
for _, list in ipairs(ids) do
    g.set.cards[list[1]].scripts.OnClick(g.set.cards[list[1]])
    g.set.cards[list[2]].scripts.OnClick(g.set.cards[list[2]])
end
check(over() and g.moves == 9 and best("memory:leicht") == 9, "Memory gelöst in 9 Zügen")
g = start("memory", "mittel")
check(#g.cards == 30, "Memory mittel: 30 Karten")

-- Vier gewinnt --------------------------------------------------------------------
local AI = ns.gamesById.viergewinnt._game and ns.gamesById.viergewinnt._game.AI
g = start("viergewinnt", "mittel")
AI = g.AI
local b = g.b
for c = 1, 7 do for r = 1, 6 do b[c][r] = 0 end end
b[1][1], b[1][2], b[1][3] = 2, 2, 2
check(AI.Best(b, { depth = 4, rnd = 0 }) == 1, "KI gewinnt sofort")
for c = 1, 7 do for r = 1, 6 do b[c][r] = 0 end end
b[1][1], b[2][1], b[3][1] = 1, 1, 1
local blk = AI.Best(b, { depth = 4, rnd = 0 })
check(blk == 4, "KI blockt Dreierreihe: " .. tostring(blk))
for c = 1, 7 do for r = 1, 6 do b[c][r] = 0 end end
local t0 = os.clock()
AI.Best(b, { depth = 5, rnd = 0 })
local ms = (os.clock() - t0) * 1000
check(ms < 400, ("KI schwer rechnet %.0f ms"):format(ms))
print(("  (Vier gewinnt, Stärke schwer, leeres Brett: %.0f ms)"):format(ms))
g = start("viergewinnt", "leicht")
key("4")
check(g.state == "ai" and g.b[4][1] == 1, "Spieler wirft in Spalte 4")
tick(0.5)
check(g.state == "player", "KI hat gezogen")
-- Spieler gewinnt (KI auf Zufall stellen)
g.mode = { id = "leicht", name = "Leicht", depth = 1, rnd = 1, base = 100 }
for c = 1, 7 do for r = 1, 6 do g.b[c][r] = 0 end end
g.b[1][1], g.b[2][1], g.b[3][1] = 1, 1, 1
g.state = "player"
key("4")
check(over() and ns.run.game.score >= 100, "vier in einer Reihe -> gewonnen")

-- Edelstein-Code ------------------------------------------------------------------
g = start("code")
local FB = g.Feedback
local e, p = FB({ 1, 2, 3, 4 }, { 1, 2, 3, 4 }); check(e == 4 and p == 0, "Code: alles richtig")
e, p = FB({ 1, 2, 3, 4 }, { 4, 3, 2, 1 }); check(e == 0 and p == 4, "Code: alles vertauscht")
e, p = FB({ 1, 1, 2, 2 }, { 1, 2, 1, 3 }); check(e == 1 and p == 2, "Code: Doppelte")
e, p = FB({ 1, 1, 1, 2 }, { 1, 1, 2, 2 }); check(e == 3 and p == 0, "Code: Doppelte 2 (" .. e .. "/" .. p .. ")")
g = start("code")
g.code = { 1, 2, 3, 4 }
key("6"); key("6"); key("6"); key("BACKSPACE"); key("5")
check(#g.cur == 3, "Rücktaste löscht")
key("5"); key("ENTER")
check(g.try == 2 and g.rows[1].exact == 0, "erster Versuch geprüft")
key("1"); key("2"); key("3"); key("4"); key("ENTER")
check(over() and g.score == 900, "Code geknackt im 2. Versuch: " .. g.score)

-- Edelsteine ----------------------------------------------------------------------
local M3 = ns.gamesById.edelsteine
g = start("edelsteine")
local runs = M3._game.FindRuns(g.grid)
check(#runs == 0, "Startbrett ohne fertige Reihen")
check(M3._game.HasMove(g.grid), "Startbrett hat Züge")
local function doMove()
    for y = 1, 8 do for x = 1, 8 do
        for _, d in ipairs({ { 1, 0 }, { 0, 1 } }) do
            local nx, ny = x + d[1], y + d[2]
            if nx <= 8 and ny <= 8 then
                g.grid[y][x], g.grid[ny][nx] = g.grid[ny][nx], g.grid[y][x]
                local r = M3._game.FindRuns(g.grid)
                g.grid[y][x], g.grid[ny][nx] = g.grid[ny][nx], g.grid[y][x]
                if #r > 0 then g:Select(x, y); g:Select(nx, ny); return true end
            end
        end
    end end
end
check(doMove() and g.moves == 29 and g.score > 0, "Zug mit Treffer: " .. g.score)
tick(2)
check(#M3._game.FindRuns(g.grid) == 0 and g.phase == "idle", "Brett beruhigt sich")
local before = g.moves
g:Select(1, 1); g:Select(3, 3)
check(g.sel and g.sel[1] == 3, "Nicht-Nachbar wählt neu")
for _ = 1, 40 do if over() then break end; doMove(); tick(2) end
check(over() and g.moves == 0, "30 Züge verbraucht -> Ende, Punkte " .. g.score)

-- Wortraten -------------------------------------------------------------------------
g = start("wortraten")
local EV = g.Evaluate
local r = EV("SEELE", "SEGEN"); check(table.concat(r, "") == "33211", "Wort: Doppel-E (" .. table.concat(r, "") .. ")")
r = EV("NEBEL", "SEGEN"); check(table.concat(r, "") == "23131", "Wort: N vorhanden (" .. table.concat(r, "") .. ")")
r = EV("EEEEE", "SEGEN"); check(table.concat(r, "") == "13131", "Wort: fünf E (" .. table.concat(r, "") .. ")")
r = EV("HORDE", "HORDE"); check(table.concat(r, "") == "33333", "Wort: alles grün")
for _, w in ipairs(g.WORDS) do
    if #w ~= 5 or w:find("[^A-Z]") then check(false, "ungültiges Wort " .. w) end
end
g = start("wortraten")
g.word = "HORDE"
key("P")
check(ns.run.state == "running" and g.cur == "P", "P tippt einen Buchstaben statt zu pausieren")
key("BACKSPACE")
for ch in ("TROLL"):gmatch(".") do key(ch) end
key("ENTER")
check(#g.guesses == 1 and g.letters.O == 2 and g.letters.T == 1, "Rateversuch ausgewertet")
for ch in ("HORDE"):gmatch(".") do key(ch) end
key("ENTER")
check(over() and g.score == 500, "erraten im 2. Versuch: " .. g.score)

-- Kniffel ---------------------------------------------------------------------------
local Y = start("kniffel")
local function cat(id) for _, c in ipairs(Y.CATS) do if c.id == id then return c end end end
check(Y.ScoreFor(cat("fh"), { 2, 2, 3, 3, 3 }) == 25, "Full House")
check(Y.ScoreFor(cat("fh"), { 3, 3, 3, 3, 3 }) == 0, "Kniffel ist kein Full House")
check(Y.ScoreFor(cat("ks"), { 1, 2, 3, 4, 6 }) == 30, "Kleine Straße")
check(Y.ScoreFor(cat("ks"), { 1, 2, 4, 5, 6 }) == 0, "keine Kleine Straße")
check(Y.ScoreFor(cat("gs"), { 2, 3, 4, 5, 6 }) == 40, "Große Straße")
check(Y.ScoreFor(cat("kn"), { 5, 5, 5, 5, 5 }) == 50, "Kniffel")
check(Y.ScoreFor(cat("dp"), { 4, 4, 4, 1, 2 }) == 15, "Dreierpasch")
check(Y.ScoreFor(cat("vp"), { 4, 4, 4, 1, 2 }) == 0, "kein Viererpasch")
check(Y.ScoreFor(cat("6"), { 6, 6, 1, 6, 2 }) == 18, "Sechser")
g = start("kniffel")
g:Choose(1)
check(g.round == 1, "Eintragen erst nach dem Würfeln")
key("SPACE"); tick(0.5)
check(g.rolls == 2, "gewürfelt")
key("1")
check(g.held[1], "Würfel 1 gehalten")
local d1 = g.dice[1]
key("SPACE"); tick(0.5)
check(g.dice[1] == d1, "gehaltener Würfel bleibt")
for round = 1, 13 do
    if over() then break end
    if g.rolls == 3 then key("SPACE"); tick(0.5) end
    for i = 1, 13 do if not g.card[Y.CATS[i].id] then g.rows[i].button.scripts.OnClick(g.rows[i].button); break end end
end
check(over() and g.round == 13, "Kniffel nach 13 Runden fertig: " .. g.score)
local u, bo, lo2, tot = g:Totals()
check(tot == g.score and best("kniffel") == tot, "Summe stimmt und ist gewertet")

-- Blackjack -------------------------------------------------------------------------
local BJ = start("blackjack")
check(BJ.Total({ { rank = 1 }, { rank = 13 } }) == 21, "A+K = 21")
check(BJ.Total({ { rank = 1 }, { rank = 1 }, { rank = 9 } }) == 21, "A+A+9 = 21")
check(BJ.Total({ { rank = 10 }, { rank = 5 }, { rank = 9 } }) == 24, "überkauft = 24")
g = start("blackjack")
for hand = 1, 12 do
    if over() then break end
    key("1")
    if g.state == "play" then key(ns.KEYS.stand) end
    for _ = 1, 60 do tick(0.1); if g.state == "bet" or over() then break end end
end
check(over(), "Blackjack endet nach zehn Runden oder pleite (Gold " .. g.gold .. ", Runde " .. g.hand .. ")")
-- Landung: Blackjack wird nur nach vollen Runden gewertet
ns.StartGame(ns.gamesById.blackjack)
check(ns.CurrentScore(ns.run) == nil, "Blackjack ohne Wertung bei Ankunft mitten in der Sitzung")

-- Solitär ---------------------------------------------------------------------------
g = start("solitaer")
local down, up = 0, 0
for i = 1, 7 do for _, c in ipairs(g.tab[i]) do if c.up then up = up + 1 else down = down + 1 end end end
check(up == 7 and down == 21 and #g.stock == 24, "Auslage: 7 offen, 21 verdeckt, 24 im Stapel")
key("SPACE")
check(#g.waste == 1 and #g.stock == 23, "Karte gezogen")
for _ = 1, 23 do key("SPACE") end
key("SPACE")
check(#g.stock == 24 and #g.waste == 0, "Stapel neu gemischt")
-- Regeln
g.tab[1] = { { rank = 8, suit = 3, up = true } }       -- Pik 8
check(g:CanPlace({ { rank = 7, suit = 1 } }, { where = "tab", pile = 1 }), "rote 7 auf schwarze 8")
check(not g:CanPlace({ { rank = 7, suit = 4 } }, { where = "tab", pile = 1 }), "schwarze 7 nicht auf schwarze 8")
g.tab[2] = {}
check(g:CanPlace({ { rank = 13, suit = 2 } }, { where = "tab", pile = 2 }) and not g:CanPlace({ { rank = 12, suit = 2 } }, { where = "tab", pile = 2 }), "leere Spalte nur König")
check(g:CanPlace({ { rank = 1, suit = 2 } }, { where = "found", pile = 1 }), "Ass auf leeres Ziel")
-- Fast gewonnen: alles bis auf die Könige liegt ab -> automatisch abräumen
g = start("solitaer")
g.stock, g.waste = {}, {}
for s = 1, 4 do
    g.found[s] = {}
    for rk = 1, 12 do table.insert(g.found[s], { rank = rk, suit = s, up = true }) end
end
for i = 1, 7 do g.tab[i] = {} end
for s = 1, 4 do g.tab[s] = { { rank = 13, suit = s, up = true } } end
g.started = true
g:CheckEnd()
check(g.auto ~= nil, "Abräumen startet")
tick(1)
check(over() and g:Placed() == 52, "Solitär gewonnen")
-- Klick-Steuerung: Karte wählen, Ziel klicken
g = start("solitaer")
g.stock, g.waste = {}, {}
for i = 1, 7 do g.tab[i] = { { rank = 2, suit = 3, up = false }, { rank = 5, suit = 3, up = true } } end
g.tab[1] = { { rank = 9, suit = 2, up = false }, { rank = 4, suit = 1, up = true } }   -- Herz 4
g:Render()
g:Click({ where = "tab", pile = 1, index = 2, card = g.tab[1][2] }, "LeftButton")
check(g.sel and g.sel.pile == 1, "Herz 4 gewählt")
g:Click({ where = "tab", pile = 2, index = 2, card = g.tab[2][2] }, "LeftButton")
check(#g.tab[2] == 3 and #g.tab[1] == 1 and g.tab[1][1].up, "Herz 4 auf Pik 5 gelegt, darunter aufgedeckt")

-- Zufallstest: alle Spiele mit wilden Tasten ---------------------------------------
local KEYS = { "UP", "DOWN", "LEFT", "RIGHT", "W", "A", "S", "D", "SPACE", "ENTER", "1", "2", "3", "4", "5", "6", "7",
    "8", "9", "Q", "E", "X", "Z", "H", "V", "BACKSPACE", "P", "ESCAPE", "B", "M" }
math.randomseed(7)
for _, def in ipairs(ns.games) do
    for _, mode in ipairs(def.modes or { { id = nil } }) do
        ns.StartGame(def, mode.id)
        for _ = 1, 250 do
            if ns.run.state == "paused" then ns.Resume() end
            if ns.run.state == "over" then ns.Restart() end
            if ns.run.state == "running" then
                local k = KEYS[math.random(#KEYS)]
                local gv2 = ns.gameView
                gv2.scripts.OnKeyDown(gv2, k)
                if math.random() < 0.7 then gv2.scripts.OnKeyUp(gv2, k) end
            end
            tick(0.1)
        end
        ns.ShowLauncher()
    end
end
local errs = {}
for _, e2 in ipairs(PastimeDB.log) do if e2.l == "E" then table.insert(errs, e2.c .. ": " .. e2.m) end end
check(#errs == 0, "keine Fehler im Protokoll:\n  " .. table.concat(errs, "\n  "))
check(#ERRORS_FORWARDED == 0, "keine Fehler an BugSack: " .. table.concat(ERRORS_FORWARDED, " | "))
print(("Spieltests: %d ok, %d Fehler"):format(passes, fails))
