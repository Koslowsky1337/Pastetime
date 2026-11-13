-- Pastime: Steinschlag (Tetris-Klon)
local ADDON, ns = ...
local L = ns.L

local COLS, ROWS, SIZE = 10, 20, 21
local EMPTY = { 0.075, 0.07, 0.065 }

-- Farben angelehnt an die Gegenstandsqualitäten
local SHAPES = {
    I = { n = 4, c = { 0.30, 0.78, 0.88 }, cells = { { 0, 1 }, { 1, 1 }, { 2, 1 }, { 3, 1 } } },
    O = { n = 2, c = { 0.95, 0.80, 0.25 }, cells = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } },
    T = { n = 3, c = { 0.64, 0.21, 0.93 }, cells = { { 1, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } } },
    S = { n = 3, c = { 0.12, 0.78, 0.10 }, cells = { { 1, 0 }, { 2, 0 }, { 0, 1 }, { 1, 1 } } },
    Z = { n = 3, c = { 0.85, 0.20, 0.20 }, cells = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 2, 1 } } },
    J = { n = 3, c = { 0.10, 0.45, 0.90 }, cells = { { 0, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } } },
    L = { n = 3, c = { 1.00, 0.50, 0.00 }, cells = { { 2, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } } },
}
local ORDER = { "I", "O", "T", "S", "Z", "J", "L" }
local LINE_POINTS = { 100, 300, 500, 800 }
local KICKS = { { 0, 0 }, { -1, 0 }, { 1, 0 }, { -2, 0 }, { 2, 0 }, { 0, -1 } }
-- Haltezeit: ein aufliegender Stein rastet erst nach kurzer Zeit ein; Schieben oder
-- Drehen setzt sie zurück (begrenzt, damit man nicht ewig weiterschieben kann)
local LOCK_DELAY, LOCK_RESETS = 0.4, 15

local KEYS = {
    LEFT = "left", A = "left", RIGHT = "right", D = "right", DOWN = "down", S = "down",
    UP = "cw", W = "cw", X = "cw", Q = "ccw", E = "cw", SPACE = "drop",
}

local Game = {}
Game.__index = Game

-- Drehung im n×n-Kasten
local function rotate(cells, n, dir)
    local out = {}
    for i, c in ipairs(cells) do
        if dir > 0 then out[i] = { n - 1 - c[2], c[1] } else out[i] = { c[2], n - 1 - c[1] } end
    end
    return out
end

function Game:Fits(cells, px, py)
    for _, c in ipairs(cells) do
        local x, y = px + c[1], py + c[2]
        if x < 0 or x >= COLS or y >= ROWS then return false end
        if y >= 0 and self.board[y][x] then return false end
    end
    return true
end

function Game:NextFromBag()
    if #self.bag == 0 then
        for _, k in ipairs(ORDER) do table.insert(self.bag, k) end
        for i = #self.bag, 2, -1 do
            local j = math.random(i)
            self.bag[i], self.bag[j] = self.bag[j], self.bag[i]
        end
    end
    return table.remove(self.bag)
end

function Game:Spawn()
    local kind = self.next or self:NextFromBag()
    self.next = self:NextFromBag()
    local s = SHAPES[kind]
    self.cur = { kind = kind, n = s.n, cells = s.cells, x = math.floor((COLS - s.n) / 2), y = 0 }
    self.fall, self.lockT, self.resets = 0, nil, 0
    if not self:Fits(self.cur.cells, self.cur.x, self.cur.y) then
        self.dead = true
        self:Render()
        self.host:Over({ score = self.score,
            text = (L["The blocks are piled up to the sky.\nLines: %d · Level: %d"]):format(self.lines, self:Level()) })
        return false
    end
    self:RenderPreview()
    return true
end

function Game:Level() return 1 + math.floor(self.lines / 10) end
function Game:Interval() return math.max(0.07, 0.75 * 0.84 ^ (self:Level() - 1)) end

function Game:Start()
    self.board = {}
    for y = 0, ROWS - 1 do self.board[y] = {} end
    self.bag, self.next, self.held = {}, nil, {}
    self.score, self.lines, self.pieces = 0, 0, 0
    self.dead, self.clearing = false, nil
    self.grid:Invalidate()
    self.pvGrid:Invalidate()
    self.pv:Show()
    self:Spawn()
    self:Render()
end

function Game:Move(dx, dy)
    local c = self.cur
    if self:Fits(c.cells, c.x + dx, c.y + dy) then
        c.x, c.y = c.x + dx, c.y + dy
        return true
    end
    return false
end

function Game:Rotate(dir)
    local c = self.cur
    if c.kind == "O" then return end
    local cells = rotate(c.cells, c.n, dir)
    for _, k in ipairs(KICKS) do
        if self:Fits(cells, c.x + k[1], c.y + k[2]) then
            c.cells, c.x, c.y = cells, c.x + k[1], c.y + k[2]
            return true
        end
    end
end

function Game:Lock()
    local c = self.cur
    local col = SHAPES[c.kind].c
    for _, cell in ipairs(c.cells) do
        local x, y = c.x + cell[1], c.y + cell[2]
        if y >= 0 then self.board[y][x] = col end
    end
    self.pieces = self.pieces + 1
    self.cur = nil
    local full = {}
    for y = 0, ROWS - 1 do
        local n = 0
        for x = 0, COLS - 1 do if self.board[y][x] then n = n + 1 end end
        if n == COLS then table.insert(full, y) end
    end
    if #full > 0 then
        self.clearing = { rows = full, t = 0.18 }
        self.host:Sound(#full >= 4 and "big" or "line")
    else
        self:Spawn()
    end
end

function Game:FinishClear()
    local rows = self.clearing.rows
    self.clearing = nil
    local remove = {}
    for _, y in ipairs(rows) do remove[y] = true end
    local newBoard, ny = {}, ROWS - 1
    for y = ROWS - 1, 0, -1 do
        if not remove[y] then newBoard[ny] = self.board[y]; ny = ny - 1 end
    end
    for y = ny, 0, -1 do newBoard[y] = {} end
    self.board = newBoard
    local level = self:Level()
    self.score = self.score + LINE_POINTS[math.min(4, #rows)] * level
    self.lines = self.lines + #rows
    self:Spawn()
end

function Game:Do(act)
    if self.dead or self.clearing or not self.cur then return end
    local shifted
    if act == "left" then shifted = self:Move(-1, 0)
    elseif act == "right" then shifted = self:Move(1, 0)
    elseif act == "down" then
        if self:Move(0, 1) then self.score = self.score + 1; self.fall = 0 else self:Lock() end
    elseif act == "cw" then shifted = self:Rotate(1)
    elseif act == "ccw" then shifted = self:Rotate(-1)
    elseif act == "drop" then
        local n = 0
        while self:Move(0, 1) do n = n + 1 end
        self.score = self.score + 2 * n
        self:Lock()
    end
    if shifted and self.lockT and self.resets < LOCK_RESETS then
        self.lockT, self.resets = LOCK_DELAY, self.resets + 1
    end
    self:Render()
end

function Game:Key(k, down)
    local act = KEYS[k]
    if not act then return false end
    if not down then
        self.held[act] = nil
        return true
    end
    if act == "left" or act == "right" or act == "down" then
        if self.held[act] then return true end
        self.held[act] = { t = act == "down" and 0.06 or 0.17 }
        if act == "left" then self.held.right = nil elseif act == "right" then self.held.left = nil end
    end
    self:Do(act)
    return true
end

function Game:ClearKeys() wipe(self.held) end
function Game:OnPause() wipe(self.held) end

function Game:Update(dt)
    if self.dead then return end
    if self.clearing then
        self.clearing.t = self.clearing.t - dt
        if self.clearing.t <= 0 then self:FinishClear() end
        self:Render()
        return
    end
    for act, h in pairs(self.held) do
        h.t = h.t - dt
        while h.t <= 0 and self.held[act] and not self.dead and not self.clearing do
            h.t = h.t + (act == "down" and 0.045 or 0.05)
            self:Do(act)
        end
    end
    if not self.cur or self.dead or self.clearing then return end
    local c = self.cur
    if not self:Fits(c.cells, c.x, c.y + 1) then
        -- liegt auf: Haltezeit läuft, dann einrasten
        self.lockT = (self.lockT or LOCK_DELAY) - dt
        if self.lockT <= 0 then
            self:Lock()
            self:Render()
        end
        return
    end
    self.lockT = nil
    self.fall = self.fall + dt
    if self.fall >= self:Interval() then
        self.fall = 0
        self:Move(0, 1)
        self:Render()
    end
end

local function mix(a, b, t)
    return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

function Game:Render()
    local flash = {}
    if self.clearing then for _, y in ipairs(self.clearing.rows) do flash[y] = true end end
    local active, ghost = {}, {}
    local c = self.cur
    if c and not self.dead then
        local gy = c.y
        while self:Fits(c.cells, c.x, gy + 1) do gy = gy + 1 end
        for _, cell in ipairs(c.cells) do
            active[(c.y + cell[2]) * 100 + c.x + cell[1]] = true
            ghost[(gy + cell[2]) * 100 + c.x + cell[1]] = true
        end
    end
    local col = c and SHAPES[c.kind].c
    for y = 0, ROWS - 1 do
        local row = self.board[y]
        for x = 0, COLS - 1 do
            local k = y * 100 + x
            if flash[y] then
                self.grid:Set(x + 1, y + 1, 1, 1, 0.85, false)
            elseif active[k] then
                self.grid:Set(x + 1, y + 1, col[1], col[2], col[3], true)
            elseif row[x] then
                local b = row[x]
                self.grid:Set(x + 1, y + 1, self.dead and b[1] * 0.45 or b[1], self.dead and b[2] * 0.45 or b[2],
                    self.dead and b[3] * 0.45 or b[3], true)
            elseif ghost[k] then
                local r, g, b = mix(EMPTY, col, 0.28)
                self.grid:Set(x + 1, y + 1, r, g, b, false)
            else
                self.grid:Set(x + 1, y + 1, EMPTY[1], EMPTY[2], EMPTY[3], false)
            end
        end
    end
end

function Game:RenderPreview()
    local s = SHAPES[self.next]
    local filled = {}
    local minx, maxx, miny, maxy = 9, -1, 9, -1
    for _, c in ipairs(s.cells) do
        minx, maxx = math.min(minx, c[1]), math.max(maxx, c[1])
        miny, maxy = math.min(miny, c[2]), math.max(maxy, c[2])
    end
    local ox = math.floor((4 - (maxx - minx + 1)) / 2) - minx
    local oy = math.floor((2 - (maxy - miny + 1)) / 2) - miny
    for _, c in ipairs(s.cells) do filled[(c[2] + oy) * 10 + c[1] + ox] = true end
    for y = 0, 1 do
        for x = 0, 3 do
            if filled[y * 10 + x] then
                self.pvGrid:Set(x + 1, y + 1, s.c[1], s.c[2], s.c[3], true)
            else
                self.pvGrid:Set(x + 1, y + 1, 0, 0, 0, false)
            end
        end
    end
end

function Game:Info()
    return {
        { L["Lines"], tostring(self.lines or 0) },
        { L["Level"], tostring(self.lines and self:Level() or 1) },
        { L["Blocks"], tostring(self.pieces or 0) },
    }
end

function Game:Stop()
    wipe(self.held or {})
end

local function Create(host, board)
    local g = setmetatable({ host = host, held = {}, score = 0, lines = 0, pieces = 0, bag = {} }, Game)
    local bg = board:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.02, 0.02, 0.02, 1)
    g.grid = ns.CreateGrid(board, COLS, ROWS, SIZE, 1)
    -- Vorschau „Nächster Stein“ in der Seitenleiste
    local pv = CreateFrame("Frame", nil, host.preview)
    pv:SetSize(4 * 16, 2 * 16)
    pv:SetPoint("CENTER")
    g.pv = pv
    g.pvGrid = ns.CreateGrid(pv, 4, 2, 16, 1)
    pv:Hide()
    return g
end

ns.RegisterGame({
    id = "tetris",
    name = L["Rockfall"],
    short = L["Falling blocks"],
    aliases = { "tetris", "steine", "stein", "rockfall", "blocks", "steinschlag" },
    category = "geschick",
    length = "lang",
    icon = "Interface\\Icons\\INV_Stone_04",
    keyboard = true,
    resumeDelay = 3,               -- nach einer Pause erst 3-2-1
    width = COLS * SIZE, height = ROWS * SIZE,
    previewLabel = L["Next block"],
    desc = L["Blocks in item-quality colours come tumbling down. Fit them together into full lines – four lines at once score the most points. Every ten lines the pace picks up."],
    controls = L["Arrows/WASD: left, right, faster · Up/W: rotate (Q: the other way) · Space: drop · P/Esc: pause"],
    controlsShort = L["Arrows/WASD: move\nUp/W: rotate · Q: other way\nSpace: drop"],
    Create = Create,
})
