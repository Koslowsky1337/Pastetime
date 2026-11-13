-- Pastime: Windreiter (Flappy-Bird-Variante durch Tausend Nadeln)
local ADDON, ns = ...
local L = ns.L

local BW, BH = 420, 420
local GROUND = 30
local PX = 110                 -- x-Mitte des Windreiters
local R = 12                   -- halbe Trefferbox
local GRAVITY, FLAP, MAXFALL = 1250, -365, 540
local SPIRE_W, CAP_W, CAP_H = 54, 64, 14
local SPACING = 225
local ICON = "Interface\\Icons\\Ability_Mount_Wyvern_01"
local ROCK = { 0.56, 0.33, 0.20 }
local ROCK_DARK = { 0.40, 0.23, 0.14 }

local KEYS = { SPACE = true, UP = true, W = true }

local Game = {}
Game.__index = Game

local function rockTex(parent, layer)
    local t = ns.NewTexture(parent, layer or "ARTWORK")
    return t
end

local function paintH(tex, c, k)
    if CreateColor and tex.SetGradient then
        tex:SetGradient("HORIZONTAL", CreateColor(c[1] * k, c[2] * k, c[3] * k, 1),
            CreateColor(math.min(1, c[1] * 1.15), math.min(1, c[2] * 1.15), math.min(1, c[3] * 1.15), 1))
    else
        tex:SetVertexColor(c[1], c[2], c[3], 1)
    end
end

function Game:Speed() return math.min(235, 150 + self.score * 3) end
function Game:GapSize() return math.max(108, 145 - self.score * 2) end

function Game:NewSpire(x)
    local s
    for _, p in ipairs(self.pool) do if not p.active then s = p; break end end
    if not s then return end
    local gap = self:GapSize()
    local minC, maxC = 70 + gap / 2, BH - GROUND - 60 - gap / 2
    s.active, s.passed, s.x = true, false, x
    s.top = math.floor(minC + math.random() * (maxC - minC) - gap / 2)
    s.bottom = s.top + gap
    s.topCol:SetSize(SPIRE_W, math.max(1, s.top - CAP_H))
    s.botCol:SetSize(SPIRE_W, math.max(1, BH - GROUND - s.bottom - CAP_H))
    for _, t in ipairs(s.texs) do t:Show() end
    self:PlaceSpire(s)
end

function Game:PlaceSpire(s)
    local x = math.floor(s.x + 0.5)
    s.topCol:SetPoint("TOPLEFT", self.board, "TOPLEFT", x, 0)
    s.topCap:SetPoint("TOPLEFT", self.board, "TOPLEFT", x - (CAP_W - SPIRE_W) / 2, -(s.top - CAP_H))
    s.botCap:SetPoint("TOPLEFT", self.board, "TOPLEFT", x - (CAP_W - SPIRE_W) / 2, -s.bottom)
    s.botCol:SetPoint("TOPLEFT", self.board, "TOPLEFT", x, -(s.bottom + CAP_H))
end

function Game:HideSpire(s)
    s.active = false
    for _, t in ipairs(s.texs) do t:Hide() end
end

function Game:Start()
    self.y, self.vy = BH / 2 - 30, 0
    self.score, self.waiting, self.dead = 0, true, false
    self.bob = 0
    for _, s in ipairs(self.pool) do self:HideSpire(s) end
    self.lastX = nil
    self.player:SetVertexColor(1, 1, 1)
    self:PlacePlayer()
    self.hint:SetText(L["Space, W, Up arrow or click to take off"])
    self.hint:Show()
end

function Game:PlacePlayer()
    self.player:SetPoint("CENTER", self.board, "TOPLEFT", PX, -self.y)
    if self.player.SetRotation then
        local a = math.max(-0.5, math.min(0.6, -self.vy / 700))
        self.player:SetRotation(a)
    end
end

function Game:Flap()
    if self.dead then return end
    if self.waiting then
        self.waiting = false
        self.hint:Hide()
        self:NewSpire(BW + 20)
        self.lastX = BW + 20
    end
    self.vy = FLAP
end

function Game:Key(k, down)
    if not KEYS[k] then return false end
    if down then self:Flap() end
    return true
end

function Game:Crash(text)
    self.dead = true
    self.player:SetVertexColor(1, 0.35, 0.35)
    self.host:Over({ score = self.score, text = text })
end

function Game:Update(dt)
    if self.dead then return end
    -- Hintergrund-Tafelberge ziehen langsam vorbei
    for _, m in ipairs(self.mesas) do
        m.x = m.x - 18 * dt
        if m.x < -m.w then m.x = m.x + BW + m.w + 40 end
        m.tex:SetPoint("BOTTOMLEFT", self.board, "BOTTOMLEFT", math.floor(m.x), GROUND)
    end
    if self.waiting then
        self.bob = self.bob + dt
        self.y = BH / 2 - 30 + math.sin(self.bob * 3) * 8
        self:PlacePlayer()
        return
    end

    self.vy = math.min(MAXFALL, self.vy + GRAVITY * dt)
    self.y = self.y + self.vy * dt
    if self.y < R then self.y, self.vy = R, 0 end
    self:PlacePlayer()

    local speed = self:Speed()
    local rightmost = -1000
    for _, s in ipairs(self.pool) do
        if s.active then
            s.x = s.x - speed * dt
            if s.x + CAP_W < 0 then
                self:HideSpire(s)
            else
                self:PlaceSpire(s)
                rightmost = math.max(rightmost, s.x)
                -- Treffer?
                if PX + R > s.x - 4 and PX - R < s.x + SPIRE_W + 4 then
                    if self.y - R < s.top or self.y + R > s.bottom then
                        return self:Crash(L["Smashed into a rock spire!"])
                    end
                end
                if not s.passed and s.x + SPIRE_W < PX - R then
                    s.passed = true
                    self.score = self.score + 1
                    self.host:Sound(self.score % 10 == 0 and "point" or "click")
                end
            end
        end
    end
    if rightmost < BW - SPACING then self:NewSpire(BW + 10) end

    if self.y + R >= BH - GROUND then
        self.y = BH - GROUND - R
        self:PlacePlayer()
        return self:Crash(L["Crash landing in the canyon!"])
    end
end

function Game:Info()
    return {
        { L["Spires"], tostring(self.score or 0) },
        { L["Speed"], tostring(math.floor((self:Speed() - 150) / 15) + 1) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, pool = {}, mesas = {}, score = 0 }, Game)

    -- Himmel in Abendfarben
    local sky = ns.NewTexture(board, "BACKGROUND")
    sky:SetAllPoints()
    if CreateColor and sky.SetGradient then
        sky:SetGradient("VERTICAL", CreateColor(0.85, 0.45, 0.25, 1), CreateColor(0.12, 0.13, 0.32, 1))
    else
        sky:SetVertexColor(0.4, 0.3, 0.35)
    end
    -- Tafelberge im Hintergrund
    local x = 0
    for i = 1, 6 do
        local w = 70 + math.random(60)
        local h = 50 + math.random(90)
        local t = ns.NewTexture(board, "BACKGROUND", 2)
        t:SetSize(w, h)
        ns.Paint(t, 0.32, 0.18, 0.16, 1, 0.75)
        table.insert(g.mesas, { tex = t, x = x, w = w })
        x = x + w + 10 + math.random(40)
    end
    -- Felsnadeln (Vorrat)
    for i = 1, 4 do
        local s = { texs = {} }
        s.topCol = rockTex(board); paintH(s.topCol, ROCK, 0.6)
        s.botCol = rockTex(board); paintH(s.botCol, ROCK, 0.6)
        s.topCap = rockTex(board, "ARTWORK"); s.topCap:SetSize(CAP_W, CAP_H); paintH(s.topCap, ROCK_DARK, 0.7)
        s.botCap = rockTex(board, "ARTWORK"); s.botCap:SetSize(CAP_W, CAP_H); paintH(s.botCap, ROCK_DARK, 0.7)
        s.texs = { s.topCol, s.botCol, s.topCap, s.botCap }
        for _, t in ipairs(s.texs) do t:Hide() end
        table.insert(g.pool, s)
    end
    -- Boden
    local ground = ns.NewTexture(board, "ARTWORK", 3)
    ground:SetPoint("BOTTOMLEFT")
    ground:SetPoint("BOTTOMRIGHT")
    ground:SetHeight(GROUND)
    ns.Paint(ground, 0.45, 0.30, 0.16, 1, 0.6)
    local edge = ns.NewTexture(board, "ARTWORK", 4)
    edge:SetPoint("BOTTOMLEFT", 0, GROUND - 2)
    edge:SetPoint("BOTTOMRIGHT", 0, GROUND - 2)
    edge:SetHeight(3)
    ns.Paint(edge, 0.25, 0.15, 0.08, 1)

    g.player = board:CreateTexture(nil, "OVERLAY")
    g.player:SetSize(R * 2 + 12, R * 2 + 12)
    ns.SetIcon(g.player, ICON)
    g.hint = ns.FontString(board, "GameFontNormalLarge", "CENTER")
    g.hint:SetPoint("CENTER", 0, 80)

    board:EnableMouse(true)
    board:SetScript("OnMouseDown", function()
        if host:IsRunning() then ns.Safe("windreiter", g.Flap, g) end
    end)
    return g
end

ns.RegisterGame({
    id = "flappy",
    name = L["Wind Rider"],
    short = L["One-button flyer"],
    aliases = { "flappy", "wyvern", "windreiter", "reiter", "windrider", "rider" },
    category = "geschick",
    length = "kurz",
    icon = ICON,
    keyboard = true,
    resumeDelay = 3,               -- nach einer Pause erst 3-2-1, sonst stürzt man sofort ab
    width = BW, height = BH,
    desc = L["Guide your wind rider through the spires of Thousand Needles. Every wingbeat lifts you up, and gravity pulls you down in between. Each spire makes it faster and tighter."],
    controls = L["Space, Up arrow, W or click: flap · P/Esc: pause"],
    controlsShort = L["Space/W/click:\nflap\nP/Esc: pause"],
    Create = Create,
})
