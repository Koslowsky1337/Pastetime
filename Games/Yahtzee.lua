-- Pastime: Kniffel – fünf Würfel, drei Würfe, 13 Felder
local ADDON, ns = ...
local L = ns.L

local W, H = 420, 440
local DIE = 58
local PIPS = {   -- Augen-Positionen (x, y in Dritteln)
    TL = { 0.24, 0.24 }, TR = { 0.76, 0.24 }, ML = { 0.24, 0.5 }, MR = { 0.76, 0.5 },
    BL = { 0.24, 0.76 }, BR = { 0.76, 0.76 }, C = { 0.5, 0.5 },
}
local FACES = {
    { "C" }, { "TL", "BR" }, { "TL", "C", "BR" }, { "TL", "TR", "BL", "BR" },
    { "TL", "TR", "BL", "BR", "C" }, { "TL", "TR", "ML", "MR", "BL", "BR" },
}

local function counts(d)
    local c, sum = { 0, 0, 0, 0, 0, 0 }, 0
    for _, v in ipairs(d) do c[v] = c[v] + 1; sum = sum + v end
    return c, sum
end
local function maxCount(c) local m = 0; for _, n in ipairs(c) do m = math.max(m, n) end; return m end
local function straight(c, len)
    local run = 0
    for v = 1, 6 do
        if c[v] > 0 then run = run + 1; if run >= len then return true end else run = 0 end
    end
    return false
end

local CATS = {
    { id = "1", name = L["Ones"], upper = 1 }, { id = "2", name = L["Twos"], upper = 2 },
    { id = "3", name = L["Threes"], upper = 3 }, { id = "4", name = L["Fours"], upper = 4 },
    { id = "5", name = L["Fives"], upper = 5 }, { id = "6", name = L["Sixes"], upper = 6 },
    { id = "dp", name = L["Three of a kind"], f = function(c, s) return maxCount(c) >= 3 and s or 0 end },
    { id = "vp", name = L["Four of a kind"], f = function(c, s) return maxCount(c) >= 4 and s or 0 end },
    { id = "fh", name = "Full House", f = function(c)
        local three, two = false, false
        for _, n in ipairs(c) do if n == 3 then three = true elseif n == 2 then two = true end end
        return (three and two) and 25 or 0
    end },
    { id = "ks", name = L["Small straight"], f = function(c) return straight(c, 4) and 30 or 0 end },
    { id = "gs", name = L["Large straight"], f = function(c) return straight(c, 5) and 40 or 0 end },
    { id = "kn", name = L["Five of a kind"], f = function(c) return maxCount(c) == 5 and 50 or 0 end },
    { id = "ch", name = L["Chance"], f = function(_, s) return s end },
}

local Game = {}
Game.__index = Game
Game.CATS = CATS

function Game.ScoreFor(cat, dice)
    local c, s = counts(dice)
    if cat.upper then return c[cat.upper] * cat.upper end
    return cat.f(c, s)
end

function Game:Totals()
    local upper, lower = 0, 0
    for _, cat in ipairs(CATS) do
        local v = self.card[cat.id]
        if v then if cat.upper then upper = upper + v else lower = lower + v end end
    end
    local bonus = upper >= 63 and 35 or 0
    return upper, bonus, lower, upper + bonus + lower
end

function Game:Start()
    self.card, self.dice, self.held = {}, { 1, 2, 3, 4, 5 }, {}
    self.round, self.rolls, self.rolling, self.done = 1, 3, nil, false
    self.score = 0
    self:Render()
end

function Game:Roll()
    if self.done or self.rolling or self.rolls <= 0 then return end
    self.rolls = self.rolls - 1
    self.rolling = 0.35
    self.flick = 0
    self.host:Sound("click")
end

function Game:Toggle(i)
    if self.done or self.rolling or self.rolls == 3 then return end
    self.held[i] = not self.held[i] or nil
    self:Render()
end

function Game:Choose(idx)
    local cat = CATS[idx]
    if self.done or self.rolling or self.rolls == 3 or not cat or self.card[cat.id] then return end
    self.card[cat.id] = Game.ScoreFor(cat, self.dice)
    self.host:Sound(self.card[cat.id] > 0 and "point" or "click")
    local _, _, _, total = self:Totals()
    self.score = total
    if self.round >= #CATS then
        self.done = true
        self:Render()
        local upper, bonus = self:Totals()
        return self.host:Over({ score = total, won = true, text = (L["Upper %d%s · final score %d"]):format(upper,
            bonus > 0 and L[" + 35 bonus"] or "", total) })
    end
    self.round = self.round + 1
    self.rolls, self.held = 3, {}
    self:Render()
end

function Game:Update(dt)
    if not self.rolling then return end
    self.rolling = self.rolling - dt
    self.flick = self.flick - dt
    if self.flick <= 0 then
        self.flick = 0.05
        for i = 1, 5 do if not self.held[i] then self.dice[i] = math.random(6) end end
        self:RenderDice()
    end
    if self.rolling <= 0 then
        self.rolling = nil
        for i = 1, 5 do if not self.held[i] then self.dice[i] = math.random(6) end end
        self:Render()
    end
end

function Game:Key(k, down)
    if k == "SPACE" or k == "ENTER" then
        if down then self:Roll() end
        return true
    end
    local n = tonumber(k) or tonumber((k or ""):match("^NUMPAD(%d)$") or "")
    if n and n >= 1 and n <= 5 then
        if down then self:Toggle(n) end
        return true
    end
    return false
end

function Game:RenderDice()
    local fresh = self.rolls == 3
    for i, d in ipairs(self.diceFrames) do
        local v = self.dice[i]
        local on = {}
        if not fresh then for _, p in ipairs(FACES[v]) do on[p] = true end end
        for name, pip in pairs(d.pips) do pip:SetShown(on[name] or false) end
        d.q:SetShown(fresh)
        ns.Paint(d.bg, self.held[i] and 1 or 0.95, self.held[i] and 0.86 or 0.93, self.held[i] and 0.5 or 0.88, 1, 0.85)
        d.label:SetText(self.held[i] and L["held"] or (fresh and "" or (L["Key "] .. i)))
        d.label:SetTextColor(self.held[i] and 1 or 0.6, self.held[i] and 0.82 or 0.6, self.held[i] and 0 or 0.6)
    end
end

function Game:Render()
    self:RenderDice()
    self.rollBtn:SetEnabled(not self.done and self.rolls > 0)
    self.rollBtn:SetText(self.rolls == 3 and L["Roll"] or (L["Roll again (%d)"]):format(self.rolls))
    self.rollInfo:SetText(self.rolls == 3 and L["Roll first, then pick a box."]
        or (self.rolls == 0 and L["No rolls left – pick a box."] or L["Click dice to hold them."]))
    local canChoose = not self.done and self.rolls < 3
    for i, cat in ipairs(CATS) do
        local row = self.rows[i]
        local v = self.card[cat.id]
        if v then
            row.value:SetText(v)
            row.value:SetTextColor(1, 1, 1)
            row.name:SetTextColor(0.7, 0.7, 0.7)
        elseif canChoose then
            row.value:SetText(Game.ScoreFor(cat, self.dice))
            row.value:SetTextColor(0.5, 1, 0.5)
            row.name:SetTextColor(1, 0.82, 0)
        else
            row.value:SetText("–")
            row.value:SetTextColor(0.5, 0.5, 0.5)
            row.name:SetTextColor(1, 0.82, 0)
        end
        row.button:SetEnabled(canChoose and not v)
    end
    local upper, bonus, lower, total = self:Totals()
    self.bonusRow:SetText((L["Bonus (63+ upper: %d/63)"]):format(upper))
    self.bonusVal:SetText(bonus > 0 and "35" or "–")
    self.totalVal:SetText(total)
end

function Game:Info()
    local upper = self.card and self:Totals() or 0
    return {
        { L["Round"], ("%d/%d"):format(self.round or 1, #CATS) },
        { L["Rolls left"], tostring(self.rolls or 3) },
        { L["Upper"], ("%d/63"):format(upper) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, diceFrames = {}, rows = {}, card = {}, dice = { 1, 2, 3, 4, 5 },
        held = {}, rolls = 3, score = 0 }, Game)
    local bg = ns.NewTexture(board, "BACKGROUND")
    bg:SetAllPoints()
    if CreateColor then bg:SetGradient("VERTICAL", CreateColor(0.04, 0.16, 0.08, 1), CreateColor(0.08, 0.26, 0.12, 1)) end
    for i = 1, 5 do
        local d = CreateFrame("Button", nil, board)
        d:SetSize(DIE, DIE)
        d:SetPoint("TOPLEFT", board, "TOPLEFT", 10 + (i - 1) * 66, -10)
        d:RegisterForClicks("LeftButtonDown")
        local edge = ns.Box(d, "BACKGROUND", 0.1, 0.08, 0.06)
        edge:SetAllPoints()
        d.bg = ns.NewTexture(d, "BORDER")
        d.bg:SetPoint("TOPLEFT", 2, -2)
        d.bg:SetPoint("BOTTOMRIGHT", -2, 2)
        d.pips = {}
        for name, p in pairs(PIPS) do
            local pip = ns.Box(d, "ARTWORK", 0.12, 0.08, 0.06)
            pip:SetSize(10, 10)
            pip:SetPoint("CENTER", d, "TOPLEFT", p[1] * DIE, -p[2] * DIE)
            d.pips[name] = pip
        end
        d.q = ns.FontString(d, "GameFontNormalHuge", "CENTER")
        d.q:SetPoint("CENTER")
        d.q:SetText("?")
        d.q:SetTextColor(0.5, 0.45, 0.4)
        d.label = ns.FontString(board, "GameFontNormalSmall", "CENTER")
        d.label:SetPoint("TOP", d, "BOTTOM", 0, -3)
        d:SetHighlightTexture(ns.TEX.cellHi, "ADD")
        d:SetScript("OnClick", function() if host:IsRunning() then ns.Safe("kniffel", g.Toggle, g, i) end end)
        g.diceFrames[i] = d
    end
    g.rollBtn = ns.CreateButton(board, L["Roll"], 76, function() if host:IsRunning() then g:Roll() end end)
    g.rollBtn:SetHeight(26)
    g.rollBtn:SetPoint("TOPRIGHT", board, "TOPRIGHT", -4, -20)
    g.rollInfo = ns.FontString(board, "GameFontHighlightSmall", "CENTER")
    g.rollInfo:SetPoint("TOP", board, "TOP", 0, -92)
    local y = 112
    local function line(i, cat)
        local b = CreateFrame("Button", nil, board)
        b:SetSize(400, 19)
        b:SetPoint("TOPLEFT", board, "TOPLEFT", 10, -y)
        b:SetHighlightTexture(ns.TEX.highlight, "ADD")
        local stripe = ns.Box(b, "BACKGROUND", 0, 0, 0, (i % 2 == 0) and 0.25 or 0.12)
        stripe:SetAllPoints()
        local name = ns.FontString(b, "GameFontNormal")
        name:SetPoint("LEFT", 8, 0)
        name:SetText(cat.name)
        local value = ns.FontString(b, "GameFontHighlight", "RIGHT")
        value:SetPoint("RIGHT", -10, 0)
        b:SetScript("OnClick", function() if host:IsRunning() then ns.Safe("kniffel", g.Choose, g, i) end end)
        y = y + 20
        return { button = b, name = name, value = value }
    end
    for i, cat in ipairs(CATS) do
        g.rows[i] = line(i, cat)
        if i == 6 then
            g.bonusRow = ns.FontString(board, "GameFontDisableSmall")
            g.bonusRow:SetPoint("TOPLEFT", board, "TOPLEFT", 18, -(y + 3))
            g.bonusVal = ns.FontString(board, "GameFontHighlightSmall", "RIGHT")
            g.bonusVal:SetPoint("TOPRIGHT", board, "TOPLEFT", 400, -(y + 3))
            y = y + 20
        end
    end
    local tl = ns.FontString(board, "GameFontNormalLarge")
    tl:SetPoint("TOPLEFT", board, "TOPLEFT", 18, -(y + 4))
    tl:SetText(L["Total"])
    g.totalVal = ns.FontString(board, "GameFontHighlightLarge", "RIGHT")
    g.totalVal:SetPoint("TOPRIGHT", board, "TOPLEFT", 400, -(y + 4))
    return g
end

ns.RegisterGame({
    id = "kniffel",
    name = L["Tavern Dice"],
    short = L["Dice game"],
    aliases = { "kniffel", "yahtzee", "wuerfel", "tavern", "dice", "taverndice", "tavernenwuerfel" },
    category = "karten",
    length = "lang",
    icon = "Interface\\Icons\\INV_Misc_Dice_02",
    keyboard = true,
    width = W, height = H,
    desc = L["Roll up to three times, hold the good dice, then fill one of the 13 boxes – from ones to five of a kind. Reach 63 in the upper section for a 35-point bonus. Perfect for long zeppelin rides."],
    controls = L["Space: roll · 1–5 or click a die: hold · Click a box: score it"],
    controlsShort = L["Space: roll\n1–5: hold dice\nClick a box: score"],
    Create = Create,
})
