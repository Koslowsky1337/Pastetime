-- Pastime: Kodo-Sprint – Endlos-Läufer durchs Brachland
local ADDON, ns = ...
local L = ns.L

local W, H = 420, 420
local GY = 330                         -- Bodenlinie (von oben)
local KX, KW = 56, 40                  -- Trefferbox des Kodos (x, Breite)
local STAND_H, DUCK_H = 44, 26
local GRAVITY, JUMP = 2600, 860
local ICON = "Interface\\Icons\\Ability_Mount_Kodo_01"
local ICON_VULTURE = "Interface\\Icons\\Ability_Hunter_Pet_Vulture"

local Game = {}
Game.__index = Game

local function rect(parent, layer, r, g, b, shade)
    local t = ns.NewTexture(parent, layer or "ARTWORK")
    ns.Paint(t, r, g, b, 1, shade)
    t:Hide()
    return t
end

function Game:Start()
    self.h, self.vh, self.duck = 0, 0, false
    self.speed, self.dist, self.score, self.elapsed = 300, 0, 0, 0
    self.waiting, self.dead = true, false
    self.nextGap = 300
    for _, o in ipairs(self.pool) do self:HideObstacle(o) end
    self.kodo:SetVertexColor(1, 1, 1)
    self:PlaceKodo()
    self.hint:SetText(L["Space, W or click to start running"])
    self.hint:Show()
end

function Game:HideObstacle(o)
    o.active = false
    for _, t in ipairs(o.texs) do t:Hide() end
end

function Game:NewObstacle()
    local o
    for _, p in ipairs(self.pool) do if not p.active then o = p; break end end
    if not o then return end
    o.active, o.x = true, W + 20
    local r = math.random()
    if self.score > 120 and r < 0.25 then
        o.kind, o.w, o.top, o.bottom = "geier", 30, GY - 74, GY - 38
    elseif r < 0.55 then
        o.kind, o.w = "fels", 30 + math.random(0, 12)
        o.top, o.bottom = GY - 18 - math.random(0, 6), GY
    else
        o.kind, o.w = "kaktus", 16
        o.top, o.bottom = GY - 34 - math.random(0, 22), GY
    end
    for _, t in ipairs(o.texs) do t:Hide() end
    if o.kind == "kaktus" then
        o.stem:SetSize(o.w, o.bottom - o.top)
        o.armL:SetSize(8, 14); o.armR:SetSize(8, 18)
        o.stem:Show(); o.armL:Show(); o.armR:Show()
    elseif o.kind == "fels" then
        o.rock:SetSize(o.w, o.bottom - o.top)
        o.rock:Show()
    else
        o.bird:Show()
    end
    self:PlaceObstacle(o)
end

function Game:PlaceObstacle(o)
    local x = math.floor(o.x + 0.5)
    local b = self.board
    if o.kind == "kaktus" then
        o.stem:SetPoint("TOPLEFT", b, "TOPLEFT", x, -o.top)
        o.armL:SetPoint("TOPLEFT", b, "TOPLEFT", x - 8, -(o.top + 10))
        o.armR:SetPoint("TOPLEFT", b, "TOPLEFT", x + o.w, -(o.top + 6))
    elseif o.kind == "fels" then
        o.rock:SetPoint("TOPLEFT", b, "TOPLEFT", x, -o.top)
    else
        o.bird:SetPoint("TOPLEFT", b, "TOPLEFT", x - 2, -(o.top - 2))
    end
end

function Game:PlaceKodo()
    local hgt = self.duck and DUCK_H or STAND_H
    self.kodo:SetSize(KW + 16, hgt + 12)
    self.kodo:SetPoint("BOTTOMLEFT", self.board, "TOPLEFT", KX - 8, -(GY - self.h) - 2)
end

function Game:Jump()
    if self.dead then return end
    if self.waiting then
        self.waiting = false
        self.hint:Hide()
    end
    if self.h <= 0 then
        self.vh = JUMP
        self.host:Sound("click")
    end
end

function Game:Key(k, down)
    if k == "SPACE" or k == "UP" or k == "W" then
        if down then self:Jump() end
        return true
    elseif k == "DOWN" or k == "S" then
        self.duck = down and true or false
        return true
    end
    return false
end

function Game:ClearKeys() self.duck = false end
Game.OnPause = Game.ClearKeys

function Game:Update(dt)
    if self.dead then return end
    -- Boden und Tafelberge ziehen vorbei (auch beim Warten, langsam)
    local scroll = self.waiting and 40 or self.speed
    for _, d in ipairs(self.dots) do
        d.x = d.x - scroll * dt
        if d.x < -4 then d.x = d.x + W + 8 end
        d.tex:SetPoint("TOPLEFT", self.board, "TOPLEFT", math.floor(d.x), -d.y)
    end
    for _, m in ipairs(self.mesas) do
        m.x = m.x - scroll * 0.08 * dt
        if m.x < -m.w then m.x = m.x + W + m.w + 30 end
        m.tex:SetPoint("BOTTOMLEFT", self.board, "TOPLEFT", math.floor(m.x), -GY)
    end
    if self.waiting then return end

    self.elapsed = self.elapsed + dt
    self.speed = math.min(680, 300 + self.elapsed * 8)
    self.dist = self.dist + self.speed * dt
    self.score = math.floor(self.dist / 25)

    -- Sprung
    if self.h > 0 or self.vh > 0 then
        self.vh = self.vh - GRAVITY * (self.duck and 2.5 or 1) * dt
        self.h = self.h + self.vh * dt
        if self.h <= 0 then self.h, self.vh = 0, 0 end
    end
    self:PlaceKodo()

    -- Hindernisse
    local hgt = self.duck and DUCK_H or STAND_H
    local kTop, kBottom = GY - self.h - hgt, GY - self.h
    local rightmost = -1000
    for _, o in ipairs(self.pool) do
        if o.active then
            o.x = o.x - self.speed * dt
            if o.x + o.w < -20 then
                self:HideObstacle(o)
            else
                self:PlaceObstacle(o)
                rightmost = math.max(rightmost, o.x + o.w)
                if KX + KW - 4 > o.x and KX + 4 < o.x + o.w and kBottom - 3 > o.top and kTop + 3 < o.bottom then
                    self.dead = true
                    self.kodo:SetVertexColor(1, 0.35, 0.35)
                    local why = o.kind == "geier" and L["Caught by a vulture!"] or
                        (o.kind == "fels" and L["Tripped over a rock!"] or L["Ran into a cactus!"])
                    return self.host:Over({ score = self.score, text = why .. (L["\n%d metres across the Barrens"]):format(self.score) })
                end
            end
        end
    end
    if rightmost < W - self.nextGap then
        self:NewObstacle()
        self.nextGap = self.speed * (0.75 + math.random() * 0.75) + 80
    end
end

function Game:Info()
    return {
        { L["Metres"], tostring(self.score or 0) },
        { L["Speed"], ("%d"):format(math.floor(((self.speed or 300) - 300) / 38) + 1) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, pool = {}, dots = {}, mesas = {}, score = 0, speed = 300 }, Game)
    local sky = ns.NewTexture(board, "BACKGROUND")
    sky:SetPoint("TOPLEFT")
    sky:SetPoint("TOPRIGHT")
    sky:SetHeight(GY)
    if CreateColor then sky:SetGradient("VERTICAL", CreateColor(0.95, 0.7, 0.4, 1), CreateColor(0.35, 0.55, 0.8, 1)) end
    local x = 0
    for i = 1, 5 do
        local w, h = 80 + math.random(70), 30 + math.random(60)
        local t = ns.NewTexture(board, "BACKGROUND", 2)
        t:SetSize(w, h)
        ns.Paint(t, 0.62, 0.42, 0.28, 1, 0.8)
        table.insert(g.mesas, { tex = t, x = x, w = w })
        x = x + w + 20 + math.random(50)
    end
    local ground = ns.NewTexture(board, "BORDER")
    ground:SetPoint("TOPLEFT", 0, -GY)
    ground:SetPoint("BOTTOMRIGHT")
    ns.Paint(ground, 0.62, 0.48, 0.28, 1, 0.75)
    local edge = ns.Box(board, "BORDER", 0.35, 0.25, 0.12)
    edge:SetPoint("TOPLEFT", 0, -GY)
    edge:SetPoint("TOPRIGHT", 0, -GY)
    edge:SetHeight(2)
    for i = 1, 14 do
        local t = ns.Box(board, "ARTWORK", 0.42, 0.31, 0.16)
        t:SetSize(3 + math.random(4), 2)
        table.insert(g.dots, { tex = t, x = math.random(0, W), y = GY + 8 + math.random(0, H - GY - 16) })
    end
    for i = 1, 6 do
        local o = { texs = {} }
        o.stem = rect(board, "ARTWORK", 0.22, 0.55, 0.2, 0.7)
        o.armL = rect(board, "ARTWORK", 0.22, 0.55, 0.2, 0.7)
        o.armR = rect(board, "ARTWORK", 0.22, 0.55, 0.2, 0.7)
        o.rock = rect(board, "ARTWORK", 0.5, 0.48, 0.45, 0.6)
        o.bird = board:CreateTexture(nil, "ARTWORK")
        o.bird:SetSize(34, 34)
        ns.SetIcon(o.bird, ICON_VULTURE)
        o.bird:Hide()
        o.texs = { o.stem, o.armL, o.armR, o.rock, o.bird }
        table.insert(g.pool, o)
    end
    g.kodo = board:CreateTexture(nil, "OVERLAY")
    ns.SetIcon(g.kodo, ICON)
    g.hint = ns.FontString(board, "GameFontNormalLarge", "CENTER")
    g.hint:SetPoint("CENTER", 0, 40)
    board:EnableMouse(true)
    board:SetScript("OnMouseDown", function()
        if host:IsRunning() then ns.Safe("kodo", g.Jump, g) end
    end)
    return g
end

ns.RegisterGame({
    id = "kodo",
    name = L["Kodo Dash"],
    short = L["Endless runner"],
    aliases = { "kodo", "runner", "sprint", "dino", "dash", "kododash" },
    category = "geschick",
    length = "kurz",
    icon = ICON,
    keyboard = true,
    width = W, height = H,
    desc = L["Your kodo runs across the Barrens and keeps getting faster. Jump over cacti and rocks and duck under low-flying vultures. Your score is the distance in metres."],
    controls = L["Space, W, Up arrow or click: jump · S or Down arrow: duck (in the air: land faster)"],
    controlsShort = L["Space/W/click: jump\nS/Down: duck"],
    Create = Create,
})
