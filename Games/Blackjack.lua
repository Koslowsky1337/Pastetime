-- Pastime: Goblin-Blackjack – zehn Runden mit Spielgold am Tisch eines Goblins
local ADDON, ns = ...
local L = ns.L
local KEYS = ns.KEYS

local W, H = 420, 440
local CW, CH, STEP = 60, 84, 36
local HANDS, START_GOLD = 10, 100
local BETS = { 10, 25, 50 }
local Cards = ns.Cards

local Game = {}
Game.__index = Game

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

function Game:Start()
    self.deck = Cards.Shuffle(Cards.NewDeck())
    self.gold, self.hand, self.score = START_GOLD, 0, START_GOLD
    self.player, self.dealer = {}, {}
    self.state, self.bet = "bet", 0
    self.msg:SetText(L["Place your bet!"])
    self.sub:SetText((L["Hand 1 of %d"]):format(HANDS))
    self:Render()
end

function Game:PlaceBet(amount)
    if self.state ~= "bet" or amount > self.gold then return end
    self.bet = amount
    self.gold = self.gold - amount
    self.hand = self.hand + 1
    self.player = { self:Draw(), self:Draw() }
    self.dealer = { self:Draw(), self:Draw() }
    self.hole = true
    self.doubled = false
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
    self.doubled = true
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
    self.score = self.gold
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
    if self.hand >= HANDS or self.gold < BETS[1] then
        self.state = "over"
        self:Render()
        if self.gold < BETS[1] then
            return self.host:Over({ submit = false, title = L["Broke!"], text = L["The goblin took your last coin."] })
        end
        return self.host:Over({ score = self.gold, won = self.gold > START_GOLD,
            text = (L["After %d hands: %d goblin gold (start: %d)"]):format(HANDS, self.gold, START_GOLD) })
    end
    self.state = "bet"
    self.player, self.dealer, self.bet = {}, {}, 0
    self.msg:SetText(L["Place your bet!"])
    self.sub:SetText((L["Hand %d of %d"]):format(self.hand + 1, HANDS))
    self:Render()
end

function Game:Key(k, down)
    local act
    if k == "1" or k == "2" or k == "3" then act = function() self:PlaceBet(BETS[tonumber(k)]) end
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
    for i, b in ipairs(self.betButtons) do
        b:SetShown(betting)
        b:SetEnabled((self.gold or 0) >= BETS[i])
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
        { L["Hand"], ("%d/%d"):format(math.max(1, self.hand or 0), HANDS) },
        { L["Gold"], tostring(self.gold or START_GOLD) },
        { L["Bet"], tostring(self.bet or 0) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, dealerCards = {}, playerCards = {}, betButtons = {},
        score = START_GOLD, gold = START_GOLD, hand = 0, player = {}, dealer = {} }, Game)
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
    for i, amount in ipairs(BETS) do
        g.betButtons[i] = btn((L["Bet %d (%d)"]):format(amount, i), 126, 8 + (i - 1) * 136, function() g:PlaceBet(amount) end)
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
    aliases = { "blackjack", "17und4", "goblin", "21" },
    category = "karten",
    length = "kurz",
    icon = "Interface\\Icons\\INV_Misc_Coin_01",
    keyboard = true,
    noLandingScore = true,     -- nur volle zehn Runden zählen
    width = W, height = H,
    desc = L["Get as close to 21 as you can without going bust – the goblin draws to 17. You start with 100 goblin gold and play ten hands. Your gold at the end is your score. Blackjack pays 3 to 2."],
    controls = L["1/2/3: bet (10/25/50) · %s or Space: hit · %s or Enter: stand · %s: double"]:format(KEYS.hit, KEYS.stand, KEYS.double),
    controlsShort = L["1–3: bet · %s: hit\n%s: stand · %s: double"]:format(KEYS.hit, KEYS.stand, KEYS.double),
    Create = Create,
})
