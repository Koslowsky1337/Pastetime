-- Pastime: Goblin-Blackjack – Gold bleibt über Partien erhalten; gewertet wird
-- der höchste Goldstand eines Laufs, sobald der Goblin dir alles abgenommen hat
local ADDON, ns = ...
local L = ns.L
local KEYS = ns.KEYS

local W, H = 420, 440
local CW, CH, STEP = 60, 84, 36
local START_GOLD, MIN_BET = 100, 10
local Cards = ns.Cards

local Game = {}
Game.__index = Game

-- Einsätze: 10 Gold, ¼ und ½ des Golds (auf 5 abgerundet, mindestens 10)
function Game.Bets(gold)
    local function part(f) return math.max(MIN_BET, math.floor(gold * f / 5) * 5) end
    return { MIN_BET, part(0.25), part(0.5) }
end

function Game.Total(hand)
    local t, aces = 0, 0
    for _, c in ipairs(hand) do
        local r = c.rank
        if r == 1 then aces = aces + 1; t = t + 11
        elseif r >= 10 then t = t + 10
        else t = t + r end
    end
    while t > 21 and aces > 0 do t, aces = t - 10, aces - 1 end
    return t, aces > 0
end

local function isBlackjack(hand) return #hand == 2 and Game.Total(hand) == 21 end

function Game:Draw()
    if #self.deck < 15 then self.deck = Cards.Shuffle(Cards.NewDeck()) end
    return table.remove(self.deck)
end

-- Kontostand sofort sichern: wer mitten in der Hand geht, verliert den Einsatz
function Game:Save()
    local b = ns.DB.blackjack
    b.gold, b.peak = self.gold, self.peak
end

function Game:Start()
    local b = ns.DB.blackjack
    if (tonumber(b.gold) or 0) < MIN_BET then b.gold, b.peak = START_GOLD, START_GOLD end
    self.deck = Cards.Shuffle(Cards.NewDeck())
    self.gold = b.gold
    self.peak = math.max(tonumber(b.peak) or 0, self.gold)
    self.score = self.peak
    self.player, self.dealer = {}, {}
    self.state, self.bet = "bet", 0
    self.msg:SetText(L["Place your bet!"])
    self.sub:SetText((L["Best this run: %d gold"]):format(self.peak))
    self:Render()
end

function Game:PlaceBet(i)
    local amount = Game.Bets(self.gold)[i]
    if self.state ~= "bet" or not amount or amount > self.gold then return end
    self.bet = amount
    self.gold = self.gold - amount
    self:Save()
    self.player = { self:Draw(), self:Draw() }
    self.dealer = { self:Draw(), self:Draw() }
    self.hole = true
    self.host:Sound("click")
    if isBlackjack(self.player) or isBlackjack(self.dealer) then
        self.hole = false
        return self:Settle()
    end
    self.state = "play"
    self.msg:SetText(L["Hit or stand?"])
    self.sub:SetText("")
    self:Render()
end

function Game:Hit()
    if self.state ~= "play" then return end
    table.insert(self.player, self:Draw())
    self.host:Sound("click")
    if Game.Total(self.player) > 21 then
        self.hole = false
        return self:Settle()
    end
    if Game.Total(self.player) == 21 then return self:Stand() end
    self:Render()
end

function Game:Double()
    if self.state ~= "play" or #self.player ~= 2 or self.gold < self.bet then return end
    self.gold = self.gold - self.bet
    self.bet = self.bet * 2
    self:Save()
    table.insert(self.player, self:Draw())
    if Game.Total(self.player) > 21 then
        self.hole = false
        return self:Settle()
    end
    self:Stand()
end

function Game:Stand()
    if self.state ~= "play" then return end
    self.state, self.hole, self.t = "dealer", false, 0.5
    self.msg:SetText(L["The goblin reveals his cards …"])
    self:Render()
end

function Game:Settle()
    local p, d = Game.Total(self.player), Game.Total(self.dealer)
    local pb, db = isBlackjack(self.player), isBlackjack(self.dealer)
    local win, text
    if p > 21 then
        win, text = 0, L["Bust – the goblin takes your gold."]
    elseif pb and not db then
        win, text = math.floor(self.bet * 2.5), L["Blackjack! Pays 3 to 2."]
    elseif db and not pb then
        win, text = 0, L["The goblin has blackjack."]
    elseif d > 21 then
        win, text = self.bet * 2, L["The goblin busts!"]
    elseif p > d then
        win, text = self.bet * 2, (L["You win – %d against %d."]):format(p, d)
    elseif p == d then
        win, text = self.bet, (L["Push at %d – bet returned."]):format(p)
    else
        win, text = 0, (L["You lose – %d against %d."]):format(p, d)
    end
    self.gold = self.gold + win
    self.peak = math.max(self.peak, self.gold)
    self.score = self.peak
    self:Save()
    local diff = win - self.bet
    self.msg:SetText(diff > 0 and ("|cff80ff80+%d Gold|r"):format(diff) or (diff < 0 and ("|cffff6060%d Gold|r"):format(diff) or "±0"))
    self.sub:SetText(text)
    self.host:Sound(diff > 0 and "big" or (diff < 0 and "bad" or "click"))
    self.state, self.t = "result", 1.8
    self:Render()
end

function Game:Update(dt)
    if self.state == "dealer" then
        self.t = self.t - dt
        if self.t <= 0 then
            if Game.Total(self.dealer) < 17 then
                table.insert(self.dealer, self:Draw())
                self.host:Sound("click")
                self.t = 0.5
                self:Render()
            else
                self:Settle()
            end
        end
    elseif self.state == "result" then
        self.t = self.t - dt
        if self.t <= 0 then self:NextHand() end
    end
end

function Game:NextHand()
    if self.state ~= "result" then return end
    if self.gold < MIN_BET then
        -- Pleite: der Lauf ist vorbei, gewertet wird der höchste Goldstand
        self.state = "over"
        self:Render()
        local peak = self.peak
        local b = ns.DB.blackjack
        b.gold, b.peak = START_GOLD, START_GOLD
        return self.host:Over({ score = peak, title = L["Broke!"],
            text = L["The goblin took your last coin."] .. "\n" .. (L["You start again with %d gold."]):format(START_GOLD) })
    end
    self.state = "bet"
    self.player, self.dealer, self.bet = {}, {}, 0
    self.msg:SetText(L["Place your bet!"])
    self.sub:SetText((L["Best this run: %d gold"]):format(self.peak))
    self:Render()
end

function Game:Key(k, down)
    local act
    if k == "1" or k == "2" or k == "3" then act = function() self:PlaceBet(tonumber(k)) end
    elseif k == KEYS.hit or k == "SPACE" then act = function() if self.state == "result" then self:NextHand() else self:Hit() end end
    elseif k == KEYS.stand or k == "ENTER" then act = function() self:Stand() end
    elseif k == KEYS.double then act = function() self:Double() end
    end
    if not act then return false end
    if down then act() end
    return true
end

local function layout(board, frames, hand, y, hideSecond)
    for i, f in ipairs(frames) do
        local c = hand[i]
        if c then
            f:SetPoint("TOPLEFT", board, "TOPLEFT", 20 + (i - 1) * STEP, -y)
            f:SetCard(c, not (hideSecond and i == 2))
        else
            f:SetCard(nil)
        end
    end
end

function Game:Render()
    layout(self.board, self.dealerCards, self.dealer, 52, self.hole)
    layout(self.board, self.playerCards, self.player, 252, false)
    local dt = (#self.dealer > 0) and (self.hole and ("%d + ?"):format(Game.Total({ self.dealer[1] })) or tostring(Game.Total(self.dealer))) or ""
    self.dealerTotal:SetText(dt)
    self.playerTotal:SetText(#self.player > 0 and tostring(Game.Total(self.player)) or "")
    self.goldText:SetText((L["Goblin gold: |cffffffff%d|r%s"]):format(self.gold or 0, (self.bet or 0) > 0 and (L["  ·  Bet: %d"]):format(self.bet) or ""))
    local betting = self.state == "bet"
    local amounts = Game.Bets(self.gold or START_GOLD)
    for i, b in ipairs(self.betButtons) do
        b:SetShown(betting)
        b:SetText((L["Bet %d (%d)"]):format(amounts[i], i))
        b:SetEnabled((self.gold or 0) >= amounts[i])
    end
    local playing = self.state == "play"
    self.hitBtn:SetShown(playing)
    self.standBtn:SetShown(playing)
    self.doubleBtn:SetShown(playing)
    self.doubleBtn:SetEnabled(playing and #self.player == 2 and (self.gold or 0) >= (self.bet or 0))
    self.nextBtn:SetShown(self.state == "result")
end

function Game:Info()
    return {
        { L["Gold"], tostring(self.gold or START_GOLD) },
        { L["Bet"], tostring(self.bet or 0) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, dealerCards = {}, playerCards = {}, betButtons = {},
        score = START_GOLD, gold = START_GOLD, peak = START_GOLD, player = {}, dealer = {} }, Game)
    local felt = ns.NewTexture(board, "BACKGROUND")
    felt:SetAllPoints()
    if CreateColor then felt:SetGradient("VERTICAL", CreateColor(0.03, 0.18, 0.08, 1), CreateColor(0.06, 0.3, 0.13, 1)) end
    local function label(text, y)
        local fs = ns.FontString(board, "GameFontNormal")
        fs:SetPoint("TOPLEFT", board, "TOPLEFT", 20, -y)
        fs:SetText(text)
        return fs
    end
    label(L["The goblin"], 32)
    label(L["You"], 232)
    g.dealerTotal = ns.FontString(board, "GameFontHighlightLarge", "LEFT")
    g.dealerTotal:SetPoint("TOPLEFT", board, "TOPLEFT", 100, -30)
    g.playerTotal = ns.FontString(board, "GameFontHighlightLarge", "LEFT")
    g.playerTotal:SetPoint("TOPLEFT", board, "TOPLEFT", 50, -230)
    for i = 1, 11 do
        g.dealerCards[i] = Cards.Create(board, CW, CH)
        g.dealerCards[i]:SetFrameLevel(board:GetFrameLevel() + i)
        g.dealerCards[i]:Hide()
        g.playerCards[i] = Cards.Create(board, CW, CH)
        g.playerCards[i]:SetFrameLevel(board:GetFrameLevel() + i)
        g.playerCards[i]:Hide()
    end
    g.msg = ns.FontString(board, "GameFontNormalHuge", "CENTER")
    g.msg:SetPoint("CENTER", board, "TOP", 0, -168)
    g.sub = ns.FontString(board, "GameFontHighlight", "CENTER")
    g.sub:SetPoint("TOP", g.msg, "BOTTOM", 0, -6)
    g.sub:SetWidth(380)
    g.goldText = ns.FontString(board, "GameFontNormal", "RIGHT")
    g.goldText:SetPoint("TOPRIGHT", -10, -8)
    local function btn(text, w, x, fn)
        local b = ns.CreateButton(board, text, w, function() if host:IsRunning() then ns.Safe("blackjack", fn) end end)
        b:SetHeight(26)
        b:SetPoint("BOTTOMLEFT", board, "BOTTOMLEFT", x, 10)
        return b
    end
    for i = 1, 3 do
        g.betButtons[i] = btn("", 126, 8 + (i - 1) * 136, function() g:PlaceBet(i) end)
    end
    g.hitBtn = btn(L["Hit (%s)"]:format(KEYS.hit), 126, 8, function() g:Hit() end)
    g.standBtn = btn(L["Stand (%s)"]:format(KEYS.stand), 126, 144, function() g:Stand() end)
    g.doubleBtn = btn(L["Double (%s)"]:format(KEYS.double), 126, 280, function() g:Double() end)
    g.nextBtn = btn(L["Next (Space)"], 180, 120, function() g:NextHand() end)
    return g
end

ns.RegisterGame({
    id = "blackjack",
    name = L["Goblin Blackjack"],
    short = L["Twenty-one"],
    aliases = { "blackjack", "17und4", "21" },
    category = "karten",
    length = "kurz",
    icon = "Interface\\Icons\\INV_Misc_Coin_01",
    keyboard = true,
    noLandingScore = true,     -- gewertet wird erst, wenn ein Lauf pleite endet
    scoreLabel = L["Highest gold"],
    width = W, height = H,
    desc = L["Get close to 21 without going bust – the goblin draws to 17. Your goblin gold carries over between games, so you can work your way up. When you go broke, your highest gold counts. Blackjack pays 3 to 2."],
    controls = L["1/2/3: bet 10, ¼ or ½ of your gold · %s or Space: hit · %s or Enter: stand · %s: double"]:format(KEYS.hit, KEYS.stand, KEYS.double),
    controlsShort = L["1–3: bet · %s: hit\n%s: stand · %s: double"]:format(KEYS.hit, KEYS.stand, KEYS.double),
    Create = Create,
})
