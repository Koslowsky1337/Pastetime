-- Pastime: Mauerbrecher (Breakout) – Steine in den Farben der Gegenstandsqualitäten
local ADDON, ns = ...
local L = ns.L

local W, H = 420, 440
local COLS, ROWS, BW, BH, GAP, TOP = 10, 6, 40, 16, 2, 50
local PW, PH, PY = 72, 10, 410
local BALL = 8
local ROWDEF = {   -- von oben: Farbe, Treffer, Punkte
    { { 1.00, 0.50, 0.00 }, 2, 60 }, { { 0.64, 0.21, 0.93 }, 2, 50 }, { { 0.10, 0.45, 0.90 }, 1, 40 },
    { { 0.12, 0.78, 0.10 }, 1, 30 }, { { 0.92, 0.92, 0.92 }, 1, 20 }, { { 0.55, 0.55, 0.55 }, 1, 10 },
}

local Game = {}
Game.__index = Game

function Game:BuildLevel()
    self.left = 0
    for i, b in ipairs(self.bricks) do
        local row = math.floor((i - 1) / COLS) + 1
        b.hp, b.max, b.pts, b.color = ROWDEF[row][2], ROWDEF[row][2], ROWDEF[row][3], ROWDEF[row][1]
        self.left = self.left + 1
        self:PaintBrick(b)
        b.tex:Show()
    end
end

function Game:PaintBrick(b)
    local k = (b.hp < b.max) and 0.55 or 1
    ns.Paint(b.tex, b.color[1] * k, b.color[2] * k, b.color[3] * k, 1, 0.6)
end

function Game:ResetBall()
    self.stuck = true
    self.bx, self.by = self.px + PW / 2 - BALL / 2, PY - BALL - 1
    self.vx, self.vy = 0, 0
end

function Game:Start()
    self.score, self.lives, self.level = 0, 3, 1
    self.px = (W - PW) / 2
    self.held = {}
    self.dead = false
    self.baseSpeed = 280
    self.speed = self.baseSpeed
    self:BuildLevel()
    self:ResetBall()
    self:Render()
    self.hint:SetText(L["Space or click: launch the ball"])
    self.hint:Show()
end

function Game:Launch()
    if not self.stuck or self.dead then return end
    self.stuck = false
    self.hint:Hide()
    local a = math.rad(math.random(-30, 30))
    self.vx, self.vy = self.speed * math.sin(a), -self.speed * math.cos(a)
end

function Game:Key(k, down)
    if k == "LEFT" or k == "A" then self.held.left = down or nil; return true end
    if k == "RIGHT" or k == "D" then self.held.right = down or nil; return true end
    if k == "SPACE" or k == "UP" or k == "W" then
        if down then self:Launch() end
        return true
    end
    return false
end

function Game:ClearKeys() wipe(self.held) end
Game.OnPause = Game.ClearKeys

local function overlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

function Game:HitBrick(x, y)
    for _, b in ipairs(self.bricks) do
        if b.hp > 0 and overlap(x, y, BALL, BALL, b.x, b.y, BW, BH) then
            b.hp = b.hp - 1
            if b.hp <= 0 then
                b.tex:Hide()
                self.left = self.left - 1
                self.score = self.score + b.pts * self.level
                self.host:Sound("point")
            else
                self:PaintBrick(b)
                self.host:Sound("click")
            end
            return true
        end
    end
    return false
end

function Game:Step(dt)
    -- x-Achse
    local nx = self.bx + self.vx * dt
    if nx < 0 then nx, self.vx = 0, math.abs(self.vx)
    elseif nx > W - BALL then nx, self.vx = W - BALL, -math.abs(self.vx) end
    if self:HitBrick(nx, self.by) then self.vx = -self.vx else self.bx = nx end
    -- y-Achse
    local ny = self.by + self.vy * dt
    if ny < 0 then ny, self.vy = 0, math.abs(self.vy) end
    if self:HitBrick(self.bx, ny) then
        self.vy = -self.vy
    else
        self.by = ny
    end
    -- Schläger
    if self.vy > 0 and overlap(self.bx, self.by, BALL, BALL, self.px, PY, PW, PH) then
        local rel = ((self.bx + BALL / 2) - (self.px + PW / 2)) / (PW / 2)
        rel = math.max(-1, math.min(1, rel))
        self.speed = math.min(520, self.speed + 4)
        local a = math.rad(60 * rel)
        self.vx, self.vy = self.speed * math.sin(a), -self.speed * math.cos(a)
        self.by = PY - BALL - 0.5
        self.host:Sound("click")
    end
end

function Game:Update(dt)
    if self.dead then return end
    -- Schläger: Maus über dem Feld oder Tasten
    local b = self.board
    if b.IsMouseOver and b:IsMouseOver() and GetCursorPosition and b:GetLeft() then
        local cx = GetCursorPosition() / b:GetEffectiveScale() - b:GetLeft()
        if self.lastCursor and math.abs(cx - self.lastCursor) > 0.5 then self.px = cx - PW / 2 end
        self.lastCursor = cx
    end
    local dir = (self.held.right and 1 or 0) - (self.held.left and 1 or 0)
    self.px = math.max(0, math.min(W - PW, self.px + dir * 430 * dt))
    if self.stuck then
        self.bx, self.by = self.px + PW / 2 - BALL / 2, PY - BALL - 1
    else
        local steps = math.max(1, math.ceil(dt * 240))
        for _ = 1, steps do
            self:Step(dt / steps)
            if self.left == 0 then break end
        end
        if self.by > H then
            self.lives = self.lives - 1
            self.host:Sound("bad")
            if self.lives <= 0 then
                self.dead = true
                self:Render()
                return self.host:Over({ score = self.score, text = (L["Out of balls. Reached level %d"]):format(self.level) })
            end
            self.speed = self.baseSpeed
            self:ResetBall()
            self.hint:SetText((L["%d ball(s) left – Space or click"]):format(self.lives))
            self.hint:Show()
        elseif self.left == 0 then
            self.score = self.score + 100 * self.level
            self.level = self.level + 1
            self.baseSpeed = math.min(440, 280 + 30 * (self.level - 1))
            self.speed = self.baseSpeed
            self.host:Sound("big")
            self:BuildLevel()
            self:ResetBall()
            self.hint:SetText((L["Level %d! Space or click"]):format(self.level))
            self.hint:Show()
        end
    end
    self:Render()
end

function Game:Render()
    self.paddle:SetPoint("TOPLEFT", self.board, "TOPLEFT", math.floor(self.px + 0.5), -PY)
    self.ball:SetPoint("TOPLEFT", self.board, "TOPLEFT", math.floor(self.bx + 0.5), -math.floor(self.by + 0.5))
end

function Game:Info()
    return {
        { L["Balls"], tostring(self.lives or 3) },
        { L["Level"], tostring(self.level or 1) },
        { L["Bricks left"], tostring(self.left or 0) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, bricks = {}, held = {}, score = 0, px = 0, bx = 0, by = 0 }, Game)
    local bg = ns.NewTexture(board, "BACKGROUND")
    bg:SetAllPoints()
    if CreateColor then bg:SetGradient("VERTICAL", CreateColor(0.03, 0.03, 0.05, 1), CreateColor(0.12, 0.1, 0.16, 1)) end
    for i = 1, COLS * ROWS do
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        local b = { x = col * (BW + GAP) + 1, y = TOP + row * (BH + GAP) }
        b.tex = ns.NewTexture(board, "ARTWORK")
        b.tex:SetSize(BW, BH)
        b.tex:SetPoint("TOPLEFT", board, "TOPLEFT", b.x, -b.y)
        g.bricks[i] = b
    end
    g.paddle = ns.NewTexture(board, "OVERLAY")
    g.paddle:SetSize(PW, PH)
    ns.Paint(g.paddle, 1, 0.78, 0.2, 1, 0.55)
    g.ball = ns.Box(board, "OVERLAY", 1, 1, 0.9)
    g.ball:SetSize(BALL, BALL)
    g.hint = ns.FontString(board, "GameFontNormalLarge", "CENTER")
    g.hint:SetPoint("CENTER", 0, -40)
    board:EnableMouse(true)
    board:SetScript("OnMouseDown", function()
        if host:IsRunning() then ns.Safe("mauerbrecher", g.Launch, g) end
    end)
    return g
end

ns.RegisterGame({
    id = "breakout",
    name = L["Wallbreaker"],
    short = L["Paddle and ball"],
    aliases = { "breakout", "mauer", "arkanoid", "wallbreaker", "bricks" },
    category = "geschick",
    length = "lang",
    icon = "Interface\\Icons\\INV_Crate_01",
    keyboard = true,
    resumeDelay = 3,               -- nach einer Pause erst 3-2-1
    width = W, height = H,
    desc = L["Keep the ball in play with your paddle and smash the wall. Legendary and epic bricks need two hits. Every level gets faster – you have three balls."],
    controls = L["Mouse over the board, A/D or arrow keys: paddle · Space or click: launch the ball"],
    controlsShort = L["Mouse or A/D: paddle\nSpace/click: launch"],
    Create = Create,
})
