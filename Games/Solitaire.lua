-- Pastime: Solitär (Klondike, eine Karte ziehen)
local ADDON, ns = ...
local L = ns.L

local W, H = 426, 440
local CW, CH = 54, 76
local TOPY, TABY = 6, 92
local DOWN_OFF, UP_OFF = 10, 20
local Cards = ns.Cards

local function colX(i) return 6 + (i - 1) * 60 end
local function isRed(c) return Cards.SUITS[c.suit].red end
local function fmtTime(s)
    s = math.floor(s or 0)
    return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

local Game = {}
Game.__index = Game

function Game:Start()
    local deck = Cards.Shuffle(Cards.NewDeck())
    self.tab, self.found, self.stock, self.waste = {}, { {}, {}, {}, {} }, {}, {}
    for i = 1, 7 do
        self.tab[i] = {}
        for k = 1, i do
            local c = table.remove(deck)
            c.up = (k == i)
            table.insert(self.tab[i], c)
        end
    end
    for _, c in ipairs(deck) do c.up = false; table.insert(self.stock, c) end
    self.sel, self.moves, self.time, self.started, self.done = nil, 0, 0, false, false
    self.auto, self.score = nil, 0
    self:Render()
end

-- Karten, die von einer Stelle bewegt würden
function Game:Taking(src)
    if src.where == "tab" then
        local pile = self.tab[src.pile]
        local out = {}
        for k = src.index, #pile do out[#out + 1] = pile[k] end
        return out
    elseif src.where == "waste" then
        return { self.waste[#self.waste] }
    elseif src.where == "found" then
        local f = self.found[src.pile]
        return { f[#f] }
    end
    return {}
end

function Game:CanPlace(cards, dst)
    local c = cards[1]
    if not c then return false end
    if dst.where == "found" then
        if #cards ~= 1 then return false end
        local f = self.found[dst.pile]
        local top = f[#f]
        if not top then return c.rank == 1 end
        return top.suit == c.suit and c.rank == top.rank + 1
    elseif dst.where == "tab" then
        local pile = self.tab[dst.pile]
        local top = pile[#pile]
        if not top then return c.rank == 13 end
        return top.up and isRed(top) ~= isRed(c) and top.rank == c.rank + 1
    end
    return false
end

function Game:Remove(src, n)
    local list = src.where == "tab" and self.tab[src.pile] or (src.where == "waste" and self.waste or self.found[src.pile])
    for _ = 1, n do table.remove(list) end
    if src.where == "tab" then
        local top = list[#list]
        if top and not top.up then top.up = true end
    end
end

function Game:Move(src, dst)
    if src.where == dst.where and src.pile == dst.pile then return false end
    local cards = self:Taking(src)
    if not self:CanPlace(cards, dst) then return false end
    self:Remove(src, #cards)
    local list = dst.where == "tab" and self.tab[dst.pile] or self.found[dst.pile]
    for _, c in ipairs(cards) do table.insert(list, c) end
    self.moves = self.moves + 1
    self.started = true
    self.host:Sound(dst.where == "found" and "point" or "click")
    self:CheckEnd()
    return true
end

function Game:ToFoundation(src)
    local cards = self:Taking(src)
    if #cards ~= 1 then return false end
    for f = 1, 4 do
        if self:CanPlace(cards, { where = "found", pile = f }) then
            return self:Move(src, { where = "found", pile = f })
        end
    end
    return false
end

function Game:DrawStock()
    if self.done or self.auto then return end
    self.started = true
    self.sel = nil
    if #self.stock > 0 then
        local c = table.remove(self.stock)
        c.up = true
        table.insert(self.waste, c)
    elseif #self.waste > 0 then
        for i = #self.waste, 1, -1 do
            local c = self.waste[i]
            c.up = false
            table.insert(self.stock, c)
        end
        self.waste = {}
    end
    self.moves = self.moves + 1
    self.host:Sound("click")
    self:CheckEnd()
    self:Render()
end

function Game:Placed()
    local n = 0
    for f = 1, 4 do n = n + #self.found[f] end
    return n
end

function Game:CheckEnd()
    if self:Placed() == 52 then
        self.done = true
        self.auto = nil
        self.score = math.max(1, math.floor(self.time + 0.5))
        self:Render()
        return self.host:Over({ score = self.score, won = true, text = (L["All cards played – %d moves."]):format(self.moves) })
    end
    -- Alles offen und kein Stapel mehr: automatisch abräumen
    if not self.auto and #self.stock == 0 and #self.waste == 0 then
        for i = 1, 7 do for _, c in ipairs(self.tab[i]) do if not c.up then return end end end
        self.auto = 0.1
    end
end

-- Klick auf eine Stelle (Karte oder leerer Platz)
function Game:Click(loc, button)
    if self.done or self.auto then return end
    if loc.where == "stock" then return self:DrawStock() end
    if button == "RightButton" or button == "double" then
        self.sel = nil
        if loc.card and (loc.where == "waste" or (loc.where == "tab" and loc.index == #self.tab[loc.pile])) then
            self:ToFoundation(loc)
        end
        return self:Render()
    end
    if self.sel then
        local src = self.sel
        self.sel = nil
        if not self:Move(src, loc) and loc.card and loc.card.up and not (src.where == loc.where and src.pile == loc.pile) then
            self:Select(loc)
        end
        return self:Render()
    end
    self:Select(loc)
    self:Render()
end

function Game:Select(loc)
    if not loc.card or not loc.card.up then return end
    if loc.where == "waste" and loc.card ~= self.waste[#self.waste] then return end
    if loc.where == "found" then
        local f = self.found[loc.pile]
        if loc.card ~= f[#f] then return end
    end
    self.sel = { where = loc.where, pile = loc.pile, index = loc.index }
end

function Game:Update(dt)
    if self.started and not self.done then self.time = self.time + dt end
    if self.auto then
        self.auto = self.auto - dt
        if self.auto <= 0 then
            self.auto = 0.08
            -- niedrigste passende Karte ablegen
            local best, bestRank
            for i = 1, 7 do
                local pile = self.tab[i]
                local c = pile[#pile]
                if c and (not bestRank or c.rank < bestRank) then
                    for f = 1, 4 do
                        if self:CanPlace({ c }, { where = "found", pile = f }) then best, bestRank = i, c.rank; break end
                    end
                end
            end
            if best then
                self.auto = 0.08
                local loc = { where = "tab", pile = best, index = #self.tab[best] }
                local ok = self:ToFoundation(loc)
                if not ok then self.auto = nil end
                self:Render()
            else
                self.auto = nil
            end
        end
    end
end

function Game:Key(k, down)
    if k == "SPACE" then
        if down then self:DrawStock() end
        return true
    end
    return false
end

function Game:Render()
    local used = 0
    local sel = self.sel
    local selCards = {}
    if sel then for _, c in ipairs(self:Taking(sel)) do selCards[c] = true end end
    local function place(card, up, x, y, loc, level)
        used = used + 1
        local f = self.pool[used]
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", self.board, "TOPLEFT", x, -y)
        f:SetFrameLevel(self.baseLevel + level)
        f:SetCard(card, up)
        f:SetSelected(selCards[card] or false)
        f.loc = loc
    end
    -- Nachziehstapel
    self.stockSlot.label:SetText(#self.waste > 0 and L["reshuffle"] or "")
    if #self.stock > 0 then
        place(self.stock[#self.stock], false, colX(1), TOPY, { where = "stock" }, 2)
    end
    self.stockCount:SetText(#self.stock > 0 and tostring(#self.stock) or "")
    -- Ablage
    if #self.waste > 0 then
        local c = self.waste[#self.waste]
        place(c, true, colX(2), TOPY, { where = "waste", card = c }, 2)
    end
    -- Zielstapel
    for f = 1, 4 do
        local pile = self.found[f]
        local top = pile[#pile]
        if top then place(top, true, colX(3 + f), TOPY, { where = "found", pile = f, card = top }, 2) end
    end
    -- Spalten
    for i = 1, 7 do
        local pile = self.tab[i]
        local downs, ups = 0, 0
        for _, c in ipairs(pile) do if c.up then ups = ups + 1 else downs = downs + 1 end end
        local need = downs * DOWN_OFF + math.max(0, ups - 1) * UP_OFF
        local avail = H - TABY - CH - 4
        local k = need > avail and avail / need or 1
        local y = TABY
        for idx, c in ipairs(pile) do
            place(c, c.up, colX(i), y, { where = "tab", pile = i, index = idx, card = c }, 2 + idx)
            y = y + (c.up and UP_OFF or DOWN_OFF) * k
        end
    end
    for i = used + 1, #self.pool do self.pool[i]:SetCard(nil) end
end

function Game:Info()
    return {
        { L["Time"], fmtTime(self.time) },
        { L["Moves"], tostring(self.moves or 0) },
        { L["Played"], ("%d/52"):format(self.found and self:Placed() or 0) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, pool = {}, score = 0, tab = {}, found = { {}, {}, {}, {} },
        stock = {}, waste = {} }, Game)
    local felt = ns.NewTexture(board, "BACKGROUND")
    felt:SetAllPoints()
    if CreateColor then felt:SetGradient("VERTICAL", CreateColor(0.03, 0.18, 0.08, 1), CreateColor(0.06, 0.3, 0.13, 1)) end
    g.baseLevel = board:GetFrameLevel() + 2
    local function slot(x, y, loc, label)
        local s = Cards.CreateSlot(board, CW, CH, label)
        s:SetPoint("TOPLEFT", board, "TOPLEFT", x, -y)
        s:SetFrameLevel(g.baseLevel)
        s:SetScript("OnClick", function(_, button)
            if host:IsRunning() then ns.Safe("solitaer", g.Click, g, loc, button) end
        end)
        return s
    end
    g.stockSlot = slot(colX(1), TOPY, { where = "stock" }, "")
    slot(colX(2), TOPY, { where = "waste" })
    for f = 1, 4 do
        local s = slot(colX(3 + f), TOPY, { where = "found", pile = f }, ns.Cards.RANKS[1])
    end
    for i = 1, 7 do slot(colX(i), TABY, { where = "tab", pile = i }, ns.Cards.RANKS[13]) end
    g.stockCount = ns.FontString(board, "GameFontHighlightSmall", "CENTER")
    g.stockCount:SetPoint("TOP", board, "TOPLEFT", colX(1) + CW / 2, -(TOPY + CH + 1))
    for i = 1, 52 do
        local f = Cards.Create(board, CW, CH)
        f:Hide()
        f:SetScript("OnClick", function(self, button)
            if host:IsRunning() and self.loc then ns.Safe("solitaer", g.Click, g, self.loc, button) end
        end)
        f:SetScript("OnDoubleClick", function(self)
            if host:IsRunning() and self.loc then ns.Safe("solitaer", g.Click, g, self.loc, "double") end
        end)
        g.pool[i] = f
    end
    return g
end

ns.RegisterGame({
    id = "solitaer",
    name = L["Solitaire"],
    short = "Klondike",
    aliases = { "solitaer", "solitär", "klondike", "patience", "solitaire" },
    category = "karten",
    length = "lang",
    icon = "Interface\\Icons\\INV_Misc_Ticket_Tarot_Maelstrom_01",
    keyboard = true,
    width = W, height = H,
    lowerIsBetter = true,
    scoreLabel = L["Time"],
    FormatScore = fmtTime,
    desc = L["The classic: build all cards up by suit from ace to king. In the columns, stack downwards in alternating red and black; only kings may fill an empty column. Your time is your score."],
    controls = L["Click a card, then its target · Right- or double-click: send to foundation · Click the stock or press Space: draw"],
    controlsShort = L["Click card, then target\nRight-click: to foundation\nSpace: draw"],
    Create = Create,
})
