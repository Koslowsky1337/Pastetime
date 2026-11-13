-- Pastime: Windnatter (Snake)
local ADDON, ns = ...
local L = ns.L

local COLS, ROWS, SIZE = 21, 21, 20
local BG_A, BG_B = { 0.17, 0.13, 0.08 }, { 0.20, 0.155, 0.095 }    -- Brachland-Erde im Schachbrett
local BODY_A, BODY_B = { 0.22, 0.70, 0.78 }, { 0.17, 0.58, 0.68 }  -- türkise Schuppen
local ICON_HEAD = "Interface\\Icons\\Ability_Hunter_Pet_WindSerpent"
local ICON_EGG = "Interface\\Icons\\INV_Pet_BlueMurlocEgg"
local ICON_PEARL = "Interface\\Icons\\INV_Misc_Gem_Pearl_01"
local PEARL_TIME = 7

local DIRS = {
    UP = { 0, -1 }, W = { 0, -1 }, DOWN = { 0, 1 }, S = { 0, 1 },
    LEFT = { -1, 0 }, A = { -1, 0 }, RIGHT = { 1, 0 }, D = { 1, 0 },
}

local function key(x, y) return x * 100 + y end

local Game = {}
Game.__index = Game

local function place(tex, board, x, y, pad)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", board, "TOPLEFT", (x - 1) * SIZE - pad, -(y - 1) * SIZE + pad)
end

function Game:PaintCell(x, y, body)
    local c
    if body then c = ((x + y) % 2 == 0) and BODY_A or BODY_B
    else c = ((x + y) % 2 == 0) and BG_A or BG_B end
    self.grid:Set(x, y, c[1], c[2], c[3], body)
end

function Game:Level() return 1 + math.floor(self.eaten / 8) end

function Game:Start()
    self.snake = { { x = 11, y = 11 }, { x = 10, y = 11 }, { x = 9, y = 11 } }
    self.occ = {}
    self.dir, self.queue = { 1, 0 }, {}
    self.waiting, self.dead = true, false
    self.step, self.acc = 0.15, 0
    self.score, self.eaten, self.pearls = 0, 0, 0
    self.pearl = nil
    self.grid:Invalidate()
    for y = 1, ROWS do for x = 1, COLS do self:PaintCell(x, y, false) end end
    for _, s in ipairs(self.snake) do
        self.occ[key(s.x, s.y)] = true
        self:PaintCell(s.x, s.y, true)
    end
    self.head:SetVertexColor(1, 1, 1)
    self.pearlTex:Hide()
    self:PlaceFood()
    self:PlaceHead()
    self.hint:SetText(L["Press an arrow key or WASD"])
    self.hint:Show()
end

function Game:FreeCell()
    local free = {}
    for y = 1, ROWS do
        for x = 1, COLS do
            local k = key(x, y)
            if not self.occ[k] and not (self.fx == x and self.fy == y)
                and not (self.pearl and self.pearl.x == x and self.pearl.y == y) then
                free[#free + 1] = k
            end
        end
    end
    if #free == 0 then return nil end
    local k = free[math.random(#free)]
    return math.floor(k / 100), k % 100
end

function Game:PlaceFood()
    self.fx, self.fy = nil, nil
    local x, y = self:FreeCell()
    if not x then self.food:Hide(); return false end
    self.fx, self.fy = x, y
    place(self.food, self.board, x, y, 0)
    self.food:Show()
    return true
end

function Game:PlaceHead()
    local h = self.snake[1]
    place(self.head, self.board, h.x, h.y, 2)
end

function Game:Key(k, down)
    local d = DIRS[k]
    if not d then return false end
    if not down or self.dead then return true end
    local last = self.queue[#self.queue] or self.dir
    if (d[1] == -last[1] and d[2] == -last[2]) or (d[1] == last[1] and d[2] == last[2]) then
        if self.waiting and d[1] == last[1] then self.waiting = false; self.hint:Hide() end
        return true
    end
    if #self.queue < 3 then table.insert(self.queue, d) end
    if self.waiting then self.waiting = false; self.hint:Hide() end
    return true
end

function Game:Die(text)
    self.dead = true
    self.head:SetVertexColor(1, 0.3, 0.3)
    self.host:Over({ score = self.score, text = text .. (L["\nLength: %d · Murloc eggs: %d"]):format(#self.snake, self.eaten) })
end

function Game:Tick()
    if #self.queue > 0 then self.dir = table.remove(self.queue, 1) end
    local h = self.snake[1]
    local nx, ny = h.x + self.dir[1], h.y + self.dir[2]
    if nx < 1 or nx > COLS or ny < 1 or ny > ROWS then return self:Die(L["Into the rock wall!"]) end
    local grow = (nx == self.fx and ny == self.fy)
    local tail = self.snake[#self.snake]
    if not grow then self.occ[key(tail.x, tail.y)] = nil end
    if self.occ[key(nx, ny)] then return self:Die(L["Bit your own tail!"]) end
    -- Schwanz zuerst übermalen: folgt der Kopf direkt dem Schwanz, gehört das Feld danach dem Kopf
    if not grow then
        table.remove(self.snake)
        self:PaintCell(tail.x, tail.y, false)
    end

    table.insert(self.snake, 1, { x = nx, y = ny })
    self.occ[key(nx, ny)] = true
    self:PaintCell(nx, ny, true)

    if grow then
        self.eaten = self.eaten + 1
        self.score = self.score + 10 * self:Level()
        -- schneller nur mit jeder neuen Stufe (alle 8 Eier), Höchsttempo ab Stufe 6
        self.step = math.max(0.075, 0.15 - (self:Level() - 1) * 0.015)
        self.host:Sound("point")
        if self.eaten % 5 == 0 and not self.pearl then
            local px, py = self:FreeCell()
            if px then
                self.pearl = { x = px, y = py, t = PEARL_TIME }
                place(self.pearlTex, self.board, px, py, 0)
                self.pearlTex:SetAlpha(1)
                self.pearlTex:Show()
            end
        end
        if not self:PlaceFood() then
            self.dead = true
            return self.host:Over({ score = self.score, won = true, text = L["The whole field belongs to the wind serpent!"] })
        end
    end

    if self.pearl and self.pearl.x == nx and self.pearl.y == ny then
        self.pearls = self.pearls + 1
        self.score = self.score + 30 + 10 * self:Level()
        self.pearl = nil
        self.pearlTex:Hide()
        self.host:Sound("big")
    end
    self:PlaceHead()
end

function Game:Update(dt)
    if self.waiting or self.dead then return end
    if self.pearl then
        self.pearl.t = self.pearl.t - dt
        if self.pearl.t <= 0 then
            self.pearl = nil
            self.pearlTex:Hide()
        elseif self.pearl.t < 2 then
            self.pearlTex:SetAlpha((math.floor(self.pearl.t * 6) % 2 == 0) and 1 or 0.25)
        end
    end
    self.acc = self.acc + dt
    while self.acc >= self.step and not self.dead do
        self.acc = self.acc - self.step
        self:Tick()
    end
end

function Game:Info()
    return {
        { L["Length"], tostring(#self.snake) },
        { L["Murloc eggs"], tostring(self.eaten) },
        { L["Pearls"], tostring(self.pearls) },
        { L["Level"], tostring(self:Level()) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, score = 0, eaten = 0, pearls = 0, snake = {} }, Game)
    local bg = board:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.045, 0.025, 1)
    g.grid = ns.CreateGrid(board, COLS, ROWS, SIZE, 1)
    g.food = board:CreateTexture(nil, "OVERLAY")
    g.food:SetSize(SIZE - 1, SIZE - 1)
    ns.SetIcon(g.food, ICON_EGG)
    g.pearlTex = board:CreateTexture(nil, "OVERLAY")
    g.pearlTex:SetSize(SIZE - 1, SIZE - 1)
    ns.SetIcon(g.pearlTex, ICON_PEARL)
    g.pearlTex:Hide()
    g.head = board:CreateTexture(nil, "OVERLAY", nil, 2)
    g.head:SetSize(SIZE + 3, SIZE + 3)
    ns.SetIcon(g.head, ICON_HEAD)
    g.hint = ns.FontString(board, "GameFontNormalLarge", "CENTER")
    g.hint:SetPoint("CENTER", 0, 70)
    return g
end

ns.RegisterGame({
    id = "snake",
    name = L["Wind Serpent"],
    short = "Snake",
    aliases = { "schlange", "snake", "natter", "serpent", "windserpent" },
    category = "geschick",
    length = "kurz",
    icon = ICON_HEAD,
    keyboard = true,
    width = COLS * SIZE, height = ROWS * SIZE,
    desc = L["The classic: steer the wind serpent across the Barrens, eat murloc eggs and grow longer and longer. Now and then a pearl glitters – grab it before it disappears. Don't hit the rocks or your own tail!"],
    controls = L["Arrow keys or WASD to steer · P or Esc pauses"],
    controlsShort = L["Arrows/WASD: steer\nP/Esc: pause"],
    Create = Create,
})
