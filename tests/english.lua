-- Englischer Client: Texte, Befehle, Optionsmenü, sprachabhängige Tasten
-- Aufruf: LOCALE=enUS python3 tests/run.py . tests/english.lua
local ns = KW
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 else fails = fails + 1; print("FAIL: " .. msg) end
end
local function fire(event, ...) ns.eventFrame.scripts.OnEvent(ns.eventFrame, event, ...) end
local function slash(s) SlashCmdList.PASTIME(s) end
local function key(k)
    local gv = ns.gameView
    gv.scripts.OnKeyDown(gv, k)
    gv.scripts.OnKeyUp(gv, k)
end
-- Umlaute als ganze UTF-8-Zeichen suchen (eine Byte-Klasse träfe auch ¼ und ½)
local UMLAUTS = { "ä", "ö", "ü", "Ä", "Ö", "Ü", "ß" }
local function hasGerman(s)
    for _, u in ipairs(UMLAUTS) do if s:find(u, 1, true) then return true end end
    return false
end

fire("ADDON_LOADED", "Pastime")
fire("PLAYER_LOGIN")
check(ns.LOCALE == "enUS", "locale enUS")
check(#ns.games == 19, "19 games")

-- Spielnamen ohne Markennamen
local names = {}
for _, g in ipairs(ns.games) do
    names[g.id] = g.name
    check(not hasGerman(g.name .. (g.short or "") .. (g.desc or "") .. (g.controls or "")), "English texts for " .. g.id)
end
check(names.kniffel == "Tavern Dice" and names.memory == "Rune Pairs" and names.simon == "Totem Echo"
    and names.viergewinnt == "Four in a Row", "renamed games")
for _, g in ipairs(ns.games) do
    for _, bad in ipairs({ "Tetris", "Yahtzee", "Kniffel", "Wordle", "Memory", "Simon", "Space Invaders", "Flappy Bird",
            "Breakout", "Minesweeper", "Mastermind", "Vier gewinnt" }) do
        check(not (g.name .. " " .. (g.short or "")):find(bad, 1, true), g.id .. " shows no trademark " .. bad)
    end
end
check(ns.CATEGORIES[1].name == "Arcade" and ns.CATEGORIES[3].name == "Dice & Cards", "category names")
check(ns.LENGTHS.kurz.label == "short" and ns.LENGTHS.lang.label == "long", "length labels")

-- Fenster: alle sichtbaren Texte englisch
slash("")
check(ns.frame:IsShown(), "/pastime opens the window")
local german = {}
for _, f in ipairs(ALLFRAMES) do
    if type(f.text) == "string" and hasGerman(f.text) then table.insert(german, f.text) end
end
check(#german == 0, "no German text in the UI: " .. table.concat(german, " | "))

-- Befehle (englisch und deutsch)
CHAT = {}
slash("help")
check(#CHAT >= 8 and CHAT[1]:find("/pastime"), "help lists commands")
local helpGerman = false
for _, l in ipairs(CHAT) do if hasGerman(l) then helpGerman = true end end
check(not helpGerman, "help text is English")
local before = PastimeDB.settings.sound
slash("sound")
check(PastimeDB.settings.sound ~= before and CHAT[#CHAT]:find("Game sounds"), "/pastime sound toggles: " .. CHAT[#CHAT])
slash("ton")
check(PastimeDB.settings.sound == before, "German alias ton still works")
slash("records")
check(CHAT[#CHAT]:find("Played"), "records: " .. CHAT[#CHAT])
slash("routes")
check(ns.frame:IsShown(), "routes opens the window")
slash("options")
check(SETTINGS_OPENED == 4711, "options opens the settings panel")

-- Optionsmenü
check(#Settings.CATEGORIES == 1 and Settings.CATEGORIES[1].name == "Pastime", "settings category registered")
local cat = Settings.CATEGORIES[1]
check(#cat.init == 6, "5 checkboxes + button, are " .. #cat.init)
local auto = Settings.SETTINGS.PASTIME_AUTOOPEN
check(auto and auto.name == "Open when travelling" and auto:GetValue() == PastimeDB.settings.autoOpen, "proxy setting autoOpen")
auto:SetValue(false)
check(PastimeDB.settings.autoOpen == false, "setting writes to the DB")
slash("auto")
check(auto:GetValue() == true and (auto.notified or 0) > 0, "command refreshes the settings panel")
local mm = Settings.SETTINGS.PASTIME_MINIMAP
mm:SetValue(false)
check(PastimeDB.minimap.hidden == true and not ns.minimapButton:IsShown(), "minimap setting hides the button")
mm:SetValue(true)
check(ns.minimapButton:IsShown(), "minimap button back")
ns.minimapButton.scripts.OnClick(ns.minimapButton, "RightButton")
check(SETTINGS_OPENED == 4711, "right-click on minimap opens settings")

-- Testflug und Reisetexte
slash("testflight 40")
check(ns.trip.active and ns.trip.from == "Test Range", "test flight from Test Range")
check(ns.TripStatus():find("Test flight to Orgrimmar") and ns.TripStatus():find("landing in about"), ns.TripStatus())
slash("testflight")
check(not ns.trip.active, "second testflight lands")
slash("testflight clear")
check(CHAT[#CHAT]:find("test route"), "clear test routes: " .. CHAT[#CHAT])

-- Spielkarten, Blackjack-Tasten, Wortraten
check(ns.Cards.RANKS[11] == "J" and ns.Cards.RANKS[12] == "Q" and ns.Cards.RANKS[13] == "K", "card ranks J Q K")
check(ns.KEYS.hit == "H" and ns.KEYS.stand == "S" and ns.KEYS.double == "D", "blackjack keys H/S/D")
local bj = ns.gamesById.blackjack
ns.StartGame(bj)
local g = ns.run.game
key("1")
check(g.state == "play" or g.state == "result", "bet placed with 1, state " .. tostring(g.state))
if g.state == "play" then
    local n = #g.player
    key("H")
    check(#g.player == n + 1 or g.state == "result", "H = hit")
    if g.state == "play" then
        key("S")
        check(g.state == "result" or g.state == "over", "S = stand")
    end
end
check(g.hitBtn.text == "Hit (H)" and g.standBtn.text == "Stand (S)" and g.doubleBtn.text == "Double (D)", "button labels")
check(bj.controls:find("H or Space: hit"), "controls text: " .. bj.controls)

local wordle = ns.gamesById.wortraten
ns.StartGame(wordle)
local w = ns.run.game
local english = {}
for _, word in ipairs(ns.gamesById.wortraten.game and {} or {}) do english[word] = true end
local W = getmetatable(w).__index.WORDS
check(#W > 150, "English word list, " .. #W .. " words")
local hasMagic = false
for _, word in ipairs(W) do
    if word == "MAGIC" then hasMagic = true end
    if #word ~= 5 or word:find("[^A-Z]") then check(false, "bad word " .. word) end
end
check(hasMagic, "list contains MAGIC")
check(ns.KEYBOARD_ROWS[1] == "QWERTYUIOP" and ns.KEYBOARD_ROWS[3] == "ZXCVBNM", "QWERTY keyboard")

-- Alle Spiele starten ohne Fehler
for _, def in ipairs(ns.games) do
    ns.StartGame(def, ns.DefaultMode(def))
    check(ns.run and ns.run.def == def, "starts " .. def.id)
end
ns.ShowLauncher()

-- Kein Text mit deutschen Umlauten nach allen Spielstarts
german = {}
for _, f in ipairs(ALLFRAMES) do
    if type(f.text) == "string" and hasGerman(f.text) then table.insert(german, f.text) end
end
check(#german == 0, "no German text after starting every game: " .. table.concat(german, " | "))

local errs = {}
for _, e in ipairs(PastimeDB.log) do if e.l == "E" then table.insert(errs, e.c .. ": " .. e.m) end end
check(#errs == 0 and #ERRORS_FORWARDED == 0, "no errors: " .. table.concat(errs, "; "))
print(("English tests: %d ok, %d failed"):format(passes, fails))
