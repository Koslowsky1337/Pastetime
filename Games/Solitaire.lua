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
        -- feste Plätze: Ablage 1–4 = Herz, Karo, Pik, Kreuz
        if #cards ~= 1 or c.suit ~= dst.pile then return false end
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
    if #cards ~= 1 or src.where == "found" then return false end
    local dst = { where = "found", pile = cards[1].suit }
    return self:CanPlace(cards, dst) and self:Move(src, dst) or false
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
    -- passende oberste Karte wandert per Klick gleich auf ihren Farbstapel
    if loc.card and loc.card.up and (loc.where == "waste" or (loc.where == "tab" and loc.index == #self.tab[loc.pile]))
        and self:ToFoundation(loc) then
        return self:Render()
    end
    self:Select(loc)
    self:Render()
end

-- Ziehen mit der Maus ----------------------------------------------------------
-- Stelle unter einem Punkt des Spielfelds (x nach rechts, y nach unten)
function Game:LocAt(x, y)
    local i = math.floor((x - 3) / 60) + 1           -- 54 px Karte + 6 px Lücke je Spalte
    if i < 1 or i > 7 then return nil end
    if y < TABY - 6 then
        return i >= 4 and { where = "found", pile = i - 3 } or nil
    end
    return { where = "tab", pile = i }
end

function Game:CursorXY()
    local b = self.board
    local cx, cy = GetCursorPosition()
    local s, l, t = b:GetEffectiveScale(), b:GetLeft(), b:GetTop()
    if not (cx and s and l and t) then return nil end
    return cx / s - l, t - cy / s
end

function Game:DragStart(frame)
    local loc = frame.loc
    if self.done or self.auto or not (loc and loc.card and loc.card.up) or loc.where == "stock" then return end
    self.sel = nil
    self:Select(loc)
    local src = self.sel
    self.sel = nil
    if not src then return end
    local cards = {}
    for _, c in ipairs(self:Taking(src)) do cards[c] = true end
    local frames = {}
    for _, f in ipairs(self.pool) do
        if f:IsShown() and f.card and cards[f.card] then frames[#frames + 1] = f end
    end
    table.sort(frames, function(a, b) return a.py < b.py end)
    local x, y = self:CursorXY()
    self.drag = { src = src, frames = frames, dx = (x or frame.px) - frame.px, dy = (y or frame.py) - frame.py, top = frames[1] }
    for k, f in ipairs(frames) do f:SetFrameLevel(self.baseLevel + 80 + k) end
end

function Game:DragMove()
    local d = self.drag
    local x, y = self:CursorXY()
    if not (d and x) then return end
    local x0, y0 = x - d.dx, y - d.dy
    for k, f in ipairs(d.frames) do
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", self.board, "TOPLEFT", x0, -(y0 + (f.py - d.top.py)))
    end
end

function Game:DragStop()
    local d = self.drag
    if not d then return end
    self.drag = nil
    local x, y = self:CursorXY()
    if x and not self.done then
        -- Mitte der gezogenen Karte zählt, nicht die Mausspitze
        local dst = self:LocAt(x - d.dx + CW / 2, y - d.dy + CH / 2)
        if dst then self:Move(d.src, dst) end
    end
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
    if self.drag then self:DragMove() end
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
        f.loc, f.px, f.py = loc, x, y
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
    -- feste Farbplätze: Zeichen + Edelstein der Farbe, solange leer
    for f = 1, 4 do
        local suit = Cards.SUITS[f]
        local s = slot(colX(3 + f), TOPY, { where = "found", pile = f }, suit.glyph)
        if s.label.SetFont then s.label:SetFont("Fonts\\ARIALN.TTF", 26, "") end
        s.label:ClearAllPoints()
        s.label:SetPoint("TOP", 0, -6)
        if suit.red then s.label:SetTextColor(1, 0.4, 0.35) else s.label:SetTextColor(0.85, 0.85, 0.85) end
        ns.SetIcon(s.icon, suit.icon)
        s.icon:ClearAllPoints()
        s.icon:SetPoint("BOTTOM", 0, 8)
        s.icon:Show()
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
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self)
            if host:IsRunning() then ns.Safe("solitaer", g.DragStart, g, self) end
        end)
        f:SetScript("OnDragStop", function()
            if host:IsRunning() then ns.Safe("solitaer", g.DragStop, g)
            elseif g.drag then g.drag = nil; g:Render() end
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
    controls = L["Drag a card onto its target (or click it, then the target) · Click a fitting card: onto its suit pile · Stock or Space: draw"],
    controlsShort = L["Drag card to target\nClick: onto suit pile\nSpace: draw"],
    Create = Create,
})
