-- Pastime: Wortraten (Wordle mit WoW-Begriffen auf Deutsch)
local ADDON, ns = ...
local L = ns.L

local W, H = 420, 400
local LEN, TRIES = 5, 6
local CELL, CGAP = 44, 5
local WORDS_DE = {
    "TROLL", "ZWERG", "GNOME", "ELFEN", "HEXER", "MAGIE", "KRIEG", "HORDE", "STEIN", "EISEN", "LEDER", "STOFF",
    "SEIDE", "WOLLE", "KRAUT", "BLUME", "TRANK", "DOLCH", "BOGEN", "PFEIL", "KUGEL", "RUNEN", "TOTEM", "KATZE",
    "GEIST", "FLUCH", "SEGEN", "WAFFE", "BEUTE", "QUEST", "GILDE", "FLUSS", "INSEL", "BERGE", "SUMPF", "HAFEN",
    "KRONE", "THRON", "MAUER", "KISTE", "TRUHE", "KARTE", "REISE", "PFERD", "GREIF", "ADLER", "FALKE", "AFFEN",
    "TIERE", "KLAUE", "FELLE", "FEDER", "SPEER", "KEULE", "FAUST", "NACHT", "LICHT", "FEUER", "FROST", "BLITZ",
    "STURM", "WOLKE", "NEBEL", "REGEN", "SONNE", "STERN", "ASCHE", "FISCH", "SUPPE", "WURST", "APFEL", "BIRNE",
    "PILZE", "SAMEN", "ERNTE", "WACHE", "SCHAF", "STALL", "SCHUH", "HELME", "ROBEN", "KLOTZ", "MOTTE", "KRAKE",
    "RABEN", "EULEN", "GOLEM", "OGERN", "NAGAS", "TITAN", "GRUFT", "ALTAR", "ORDEN", "SCHAR", "TRUPP", "HEERE",
    "LANZE", "RINGE", "SEILE", "ANKER", "SEGEL", "BOOTE", "FLOSS", "STEGE", "KUTTE", "PFAHL", "HONIG", "BEERE",
    "MILCH", "SPECK", "HITZE", "OASEN", "TIGER", "KODOS", "GNOLL", "SATYR", "SEELE", "MACHT", "ARENA", "DUELL",
    "SIEGE", "BEILE", "HAKEN", "ANGEL", "LACHS", "KOHLE", "PERLE", "ACHAT", "HAUER", "ZIELE", "JAGEN", "TATZE",
    "RIESE", "ENGEL", "HEXEN", "FEIND", "BOTEN", "WAGEN", "ZELTE", "FAHNE", "KRAFT", "STAUB", }
local WORDS_EN = {
    "TROLL", "DWARF", "GNOME", "ELVES", "MAGIC", "HORDE", "STONE", "ARMOR", "CLOTH", "SPELL", "CHARM", "BLADE",
    "SWORD", "ARROW", "STAFF", "TOTEM", "RUNES", "GHOST", "CURSE", "BLESS", "QUEST", "GUILD", "RIVER", "HAVEN",
    "CROWN", "CHEST", "CRATE", "ROBES", "BOOTS", "GLOVE", "CLOAK", "RINGS", "FLASK", "HERBS", "BLOOM", "ROOTS",
    "SEEDS", "MOUNT", "HORSE", "RAVEN", "EAGLE", "TIGER", "SNAKE", "SHARK", "WHALE", "KODOS", "GNOLL", "SATYR",
    "OGRES", "NAGAS", "TITAN", "GOLEM", "DEMON", "ANGEL", "BEAST", "DRAKE", "WYRMS", "CRYPT", "ALTAR", "ORDER",
    "TRIBE", "CLANS", "FORCE", "SPEAR", "LANCE", "MACES", "NIGHT", "LIGHT", "FLAME", "FROST", "STORM", "CLOUD",
    "ASHES", "FEAST", "BREAD", "APPLE", "BERRY", "HONEY", "BREWS", "FIELD", "FARMS", "GUARD", "SHEEP", "STALL",
    "TORCH", "WAGON", "TENTS", "FLAGS", "SIGIL", "SHIPS", "SAILS", "DOCKS", "OCEAN", "SHORE", "WAVES", "PEARL",
    "CORAL", "COINS", "JEWEL", "AGATE", "OPALS", "TUSKS", "CLAWS", "FANGS", "HIDES", "SCALE", "PLUME", "QUEEN",
    "KINGS", "LORDS", "DUELS", "ARENA", "SIEGE", "RAIDS", "SPOIL", "PRIZE", "HUNTS", "TRAPS", "SNARE", "SCOUT",
    "TRACK", "WATCH", "TOWER", "WALLS", "GATES", "FORTS", "SKULL", "BONES", "GRAVE", "TOMBS", "SOULS", "POWER",
    "MIGHT", "VALOR", "HONOR", "GLORY", "WINGS", "SKIES", "REINS", "GROVE", "WOODS", "MARSH", "SWAMP", "DUNES",
    "SANDS", "CAVES", "PEAKS", "CLIFF", "GLADE", "GORGE", "SMITH", "FORGE", "ANVIL", "INGOT", "SKILL", "CRAFT",
    "MINES", "WITCH", "MAGES", "MONKS", "DRUID", "ROGUE", "FAIRY", "PIXIE", "NYMPH", "CHAOS", "SHADE", "GLOOM",
}
local WORDS = ns.LOCALE == "deDE" and WORDS_DE or WORDS_EN
local GOOD = {}
for _, w in ipairs(WORDS) do if #w == LEN then GOOD[#GOOD + 1] = w end end
local ROWS_KB = ns.KEYBOARD_ROWS
local STATE_COLOR = {
    [0] = { 0.14, 0.12, 0.1 }, [1] = { 0.28, 0.26, 0.24 }, [2] = { 0.78, 0.62, 0.12 }, [3] = { 0.3, 0.62, 0.22 },
}

local Game = {}
Game.__index = Game
Game.WORDS = GOOD

-- 3 = richtig, 2 = kommt vor, 1 = kommt nicht vor
function Game.Evaluate(guess, word)
    local res, left = {}, {}
    for i = 1, LEN do
        local g, w = guess:sub(i, i), word:sub(i, i)
        if g == w then res[i] = 3 else left[w] = (left[w] or 0) + 1 end
    end
    for i = 1, LEN do
        if not res[i] then
            local g = guess:sub(i, i)
            if (left[g] or 0) > 0 then
                res[i] = 2
                left[g] = left[g] - 1
            else
                res[i] = 1
            end
        end
    end
    return res
end

function Game:Start()
    self.word = GOOD[math.random(#GOOD)]
    self.guesses, self.cur, self.done, self.score = {}, "", false, 0
    self.letters = {}
    self.msg:SetText("")
    self:Render()
end

function Game:Type(ch)
    if self.done or #self.cur >= LEN then return end
    self.cur = self.cur .. ch
    self.host:Sound("click")
    self:Render()
end

function Game:Back()
    if self.done or #self.cur == 0 then return end
    self.cur = self.cur:sub(1, -2)
    self:Render()
end

function Game:Submit()
    if self.done then return end
    if #self.cur < LEN then
        self.msg:SetText(L["Too short – five letters!"])
        self.msgT = 1.2
        return
    end
    local res = Game.Evaluate(self.cur, self.word)
    table.insert(self.guesses, { word = self.cur, res = res })
    for i = 1, LEN do
        local ch = self.cur:sub(i, i)
        self.letters[ch] = math.max(self.letters[ch] or 0, res[i])
    end
    local won = self.cur == self.word
    self.cur = ""
    if won then
        self.done = true
        self.score = (TRIES + 1 - #self.guesses) * 100
        self:Render()
        return self.host:Over({ score = self.score, won = true, text = (L["Guessed “%s” on try %d!"]):format(self.word, #self.guesses) })
    end
    if #self.guesses >= TRIES then
        self.done = true
        self:Render()
        return self.host:Over({ submit = false, title = L["Not guessed"], text = (L["The word was “%s”."]):format(self.word) })
    end
    self.host:Sound("point")
    self:Render()
end

function Game:Key(k, down)
    if type(k) == "string" and #k == 1 and k:match("%a") then
        if down then self:Type(k:upper()) end
        return true
    end
    if k == "BACKSPACE" or k == "DELETE" then
        if down then self:Back() end
        return true
    end
    if k == "ENTER" or k == "NUMPADENTER" then
        if down then self:Submit() end
        return true
    end
    return false
end

function Game:Update(dt)
    if self.msgT then
        self.msgT = self.msgT - dt
        if self.msgT <= 0 then self.msgT = nil; self.msg:SetText("") end
    end
end

function Game:Render()
    for r = 1, TRIES do
        local g = self.guesses[r]
        local text = g and g.word or (r == #self.guesses + 1 and self.cur) or ""
        for i = 1, LEN do
            local cell = self.cells[r][i]
            local st = g and g.res[i] or 0
            local c = STATE_COLOR[st]
            ns.Paint(cell.bg, c[1], c[2], c[3], 1, st > 0 and 0.75 or nil)
            cell.text:SetText(text:sub(i, i))
            cell.border:SetShown(not g and r == #self.guesses + 1 and not self.done)
        end
    end
    for ch, key in pairs(self.keys) do
        local st = self.letters[ch]
        local c = st and STATE_COLOR[st] or { 0.42, 0.38, 0.32 }
        ns.Paint(key.bg, c[1], c[2], c[3], 1, 0.7)
    end
end

function Game:Info()
    return { { L["Try"], ("%d/%d"):format(math.min(#(self.guesses or {}) + 1, TRIES), TRIES) } }
end

local function KeyButton(g, parent, label, w, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, 30)
    b:RegisterForClicks("LeftButtonDown")
    b.bg = ns.NewTexture(b, "BACKGROUND")
    b.bg:SetAllPoints()
    ns.Paint(b.bg, 0.42, 0.38, 0.32, 1, 0.7)
    local fs = ns.FontString(b, "GameFontHighlight", "CENTER")
    fs:SetPoint("CENTER")
    fs:SetText(label)
    b:SetHighlightTexture(ns.TEX.cellHi, "ADD")
    b:SetScript("OnClick", function() if g.host:IsRunning() then ns.Safe("wortraten", onClick) end end)
    return b
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, cells = {}, keys = {}, guesses = {}, cur = "", letters = {}, score = 0 }, Game)
    local bg = ns.NewTexture(board, "BACKGROUND")
    bg:SetAllPoints()
    ns.Paint(bg, 0.08, 0.07, 0.06, 1)
    local gw = LEN * (CELL + CGAP) - CGAP
    local ox = (W - gw) / 2
    for r = 1, TRIES do
        g.cells[r] = {}
        for i = 1, LEN do
            local x, y = ox + (i - 1) * (CELL + CGAP), 4 + (r - 1) * (CELL + CGAP)
            local border = ns.Box(board, "BORDER", 1, 0.82, 0, 0.6)
            border:SetSize(CELL + 2, CELL + 2)
            border:SetPoint("TOPLEFT", board, "TOPLEFT", x - 1, -(y - 1))
            border:Hide()
            local cbg = ns.NewTexture(board, "ARTWORK")
            cbg:SetSize(CELL, CELL)
            cbg:SetPoint("TOPLEFT", board, "TOPLEFT", x, -y)
            local text = ns.FontString(board, "GameFontHighlightHuge", "CENTER")
            text:SetPoint("CENTER", cbg, "CENTER", 0, 0)
            g.cells[r][i] = { bg = cbg, text = text, border = border }
        end
    end
    local ky = 4 + TRIES * (CELL + CGAP) + 4
    for row, letters in ipairs(ROWS_KB) do
        local n = #letters + (row == 3 and 2 or 0)
        local widths = {}
        for i = 1, n do widths[i] = 36 end
        if row == 3 then widths[1], widths[n] = 52, 52 end
        local total = -4
        for _, w in ipairs(widths) do total = total + w + 4 end
        local x = (W - total) / 2
        local y = ky + (row - 1) * 34
        local idx = 1
        if row == 3 then
            local ok = KeyButton(g, board, "OK", 52, function() g:Submit() end)
            ok:SetPoint("TOPLEFT", board, "TOPLEFT", x, -y)
            x = x + 56
        end
        for i = 1, #letters do
            local ch = letters:sub(i, i)
            local b = KeyButton(g, board, ch, 36, function() g:Type(ch) end)
            b:SetPoint("TOPLEFT", board, "TOPLEFT", x, -y)
            g.keys[ch] = b
            x = x + 40
            idx = idx + 1
        end
        if row == 3 then
            local back = KeyButton(g, board, "<-", 52, function() g:Back() end)
            back:SetPoint("TOPLEFT", board, "TOPLEFT", x, -y)
        end
    end
    g.msg = ns.FontString(board, "GameFontNormalLarge", "CENTER")
    g.msg:SetPoint("CENTER", board, "TOP", 0, -150)
    return g
end

ns.RegisterGame({
    id = "wortraten",
    name = L["Word Guess"],
    short = L["Five letters"],
    aliases = { "wort", "wortraten", "wordle", "word", "wordguess" },
    category = "knobeln",
    length = "kurz",
    icon = "Interface\\Icons\\INV_Misc_Note_02",
    keyboard = true,
    textInput = true,          -- P ist hier ein Buchstabe, keine Pause
    width = W, height = H,
    desc = L["Guess the hidden five-letter word – all of them come from Azeroth. Green: right letter in the right place, gold: in the word, but somewhere else. You have six tries."],
    controls = L["Type letters · Enter: check · Backspace: delete (or click the keys below)"],
    controlsShort = L["Type · Enter: check\nBackspace: delete"],
    Create = Create,
})
