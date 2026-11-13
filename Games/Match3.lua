-- Pastime: Edelsteine (Match-3) – drei gleiche Juwelen in einer Reihe
local ADDON, ns = ...
local L = ns.L

local N, CELL = 8, 52
local SIZE = N * CELL
local MOVES = 30
local GEMS = {
    "Interface\\Icons\\INV_Misc_Gem_Ruby_01", "Interface\\Icons\\INV_Misc_Gem_Emerald_01",
    "Interface\\Icons\\INV_Misc_Gem_Sapphire_01", "Interface\\Icons\\INV_Misc_Gem_Topaz_01",
    "Interface\\Icons\\INV_Misc_Gem_Amethyst_01", "Interface\\Icons\\INV_Misc_Gem_Diamond_01",
}

local Game = {}
Game.__index = Game

-- Alle Läufe von 3+ gleichen Steinen: { {x,y,dx,dy,len}, ... } und die betroffenen Felder
function Game.FindRuns(grid)
    local runs, cells = {}, {}
    for y = 1, N do
        local x = 1
        while x <= N do
            local v, len = grid[y][x], 1
            while x + len <= N and v ~= 0 and grid[y][x + len] == v do len = len + 1 end
            if v ~= 0 and len >= 3 then
                runs[#runs + 1] = len
                for k = 0, len - 1 do cells[y * 10 + x + k] = true end
            end
            x = x + len
        end
    end
    for x = 1, N do
        local y = 1
        while y <= N do
            local v, len = grid[y][x], 1
            while y + len <= N and v ~= 0 and grid[y + len][x] == v do len = len + 1 end
            if v ~= 0 and len >= 3 then
                runs[#runs + 1] = len
                for k = 0, len - 1 do cells[(y + k) * 10 + x] = true end
            end
            y = y + len
        end
    end
    return runs, cells
end

function Game.HasMove(grid)
    for y = 1, N do
        for x = 1, N do
            for _, d in ipairs({ { 1, 0 }, { 0, 1 } }) do
                local nx, ny = x + d[1], y + d[2]
                if nx <= N and ny <= N then
                    grid[y][x], grid[ny][nx] = grid[ny][nx], grid[y][x]
                    local runs = Game.FindRuns(grid)
                    grid[y][x], grid[ny][nx] = grid[ny][nx], grid[y][x]
                    if #runs > 0 then return true end
                end
            end
        end
    end
    return false
end

function Game:Fill()
    repeat
        for y = 1, N do
            self.grid[y] = self.grid[y] or {}
            for x = 1, N do
                local v
                repeat
                    v = math.random(#GEMS)
                until not ((x > 2 and self.grid[y][x - 1] == v and self.grid[y][x - 2] == v)
                    or (y > 2 and self.grid[y - 1][x] == v and self.grid[y - 2][x] == v))
                self.grid[y][x] = v
            end
        end
    until Game.HasMove(self.grid)
end

function Game:Start()
    self.grid = {}
    self:Fill()
    self.moves, self.score, self.chain, self.bestChain = MOVES, 0, 0, 0
    self.sel, self.cursor, self.phase, self.flash = nil, { 4, 4 }, "idle", {}
    self.done = false
    self.msg:SetText("")
    self:Render()
end

function Game:Select(x, y)
    if self.done or self.phase ~= "idle" then return end
    local s = self.sel
    if s and math.abs(s[1] - x) + math.abs(s[2] - y) == 1 then
        self.sel = nil
        self:Swap(s[1], s[2], x, y)
    elseif s and s[1] == x and s[2] == y then
        self.sel = nil
    else
        self.sel = { x, y }
        self.host:Sound("click")
    end
    self.cursor = { x, y }
    self:Render()
end

function Game:Swap(x1, y1, x2, y2)
    local g = self.grid
    g[y1][x1], g[y2][x2] = g[y2][x2], g[y1][x1]
    local runs = Game.FindRuns(g)
    if #runs == 0 then
        g[y1][x1], g[y2][x2] = g[y2][x2], g[y1][x1]
        self.host:Sound("bad")
        self.msg:SetText(L["|cffff8080No match – move undone|r"])
        self.msgT = 1
        return
    end
    self.moves = self.moves - 1
    self.chain = 0
    self:Resolve()
end

function Game:Resolve()
    local runs, cells = Game.FindRuns(self.grid)
    if #runs == 0 then
        self.phase = "idle"
        if self.moves <= 0 then
            self.done = true
            self:Render()
            return self.host:Over({ score = self.score, text = (L["Out of moves. Longest chain: %d"]):format(self.bestChain) })
        end
        if not Game.HasMove(self.grid) then
            self:Fill()
            self.msg:SetText(L["No moves possible – reshuffled!"])
            self.msgT = 1.5
        end
        self:Render()
        return
    end
    self.chain = self.chain + 1
    self.bestChain = math.max(self.bestChain, self.chain)
    local gained = 0
    for _, len in ipairs(runs) do
        gained = gained + 10 * len + (len == 4 and 20 or 0) + (len >= 5 and 50 or 0)
    end
    self.score = self.score + gained * self.chain
    if self.chain > 1 then
        self.msg:SetText((L["Chain ×%d!"]):format(self.chain))
        self.msgT = 1
    end
    self.host:Sound(self.chain > 1 and "big" or "point")
    self.flash = cells
    self.phase, self.t = "flash", 0.2
    self:Render()
end

function Game:Collapse()
    for x = 1, N do
        local write = N
        for y = N, 1, -1 do
            if not self.flash[y * 10 + x] then
                self.grid[write][x] = self.grid[y][x]
                write = write - 1
            end
        end
        for y = write, 1, -1 do self.grid[y][x] = math.random(#GEMS) end
    end
    self.flash = {}
end

function Game:Update(dt)
    if self.msgT then
        self.msgT = self.msgT - dt
        if self.msgT <= 0 then self.msgT = nil; self.msg:SetText("") end
    end
    if self.phase == "flash" then
        self.t = self.t - dt
        if self.t <= 0 then
            self:Collapse()
            self:Resolve()
        end
    end
end

function Game:Key(k, down)
    local d = ({ LEFT = { -1, 0 }, A = { -1, 0 }, RIGHT = { 1, 0 }, D = { 1, 0 }, UP = { 0, -1 }, W = { 0, -1 },
        DOWN = { 0, 1 }, S = { 0, 1 } })[k]
    if d then
        if down then
            self.cursor = { math.max(1, math.min(N, self.cursor[1] + d[1])), math.max(1, math.min(N, self.cursor[2] + d[2])) }
            self:Render()
        end
        return true
    end
    if k == "SPACE" or k == "ENTER" then
        if down then self:Select(self.cursor[1], self.cursor[2]) end
        return true
    end
    return false
end

function Game:Render()
    for y = 1, N do
        for x = 1, N do
            local c = self.cells[y][x]
            local v = self.grid[y][x]
            ns.SetIcon(c.icon, GEMS[v] or ns.TEX.question)
            c.flash:SetShown(self.flash[y * 10 + x] or false)
            c.sel:SetShown(self.sel ~= nil and self.sel[1] == x and self.sel[2] == y)
            c.cur:SetShown(self.cursor[1] == x and self.cursor[2] == y)
        end
    end
end

function Game:Info()
    return {
        { L["Moves left"], tostring(self.moves or MOVES) },
        { L["Longest chain"], tostring(self.bestChain or 0) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, cells = {}, grid = {}, flash = {}, cursor = { 4, 4 }, score = 0 }, Game)
    local bg = ns.NewTexture(board, "BACKGROUND")
    bg:SetAllPoints()
    ns.Paint(bg, 0.08, 0.06, 0.1, 1)
    for y = 1, N do
        g.cells[y] = {}
        for x = 1, N do
            local b = CreateFrame("Button", nil, board)
            b:SetSize(CELL - 4, CELL - 4)
            b:SetPoint("TOPLEFT", board, "TOPLEFT", (x - 1) * CELL + 2, -((y - 1) * CELL + 2))
            b:RegisterForClicks("LeftButtonDown")
            local tile = ns.Box(b, "BACKGROUND", ((x + y) % 2 == 0) and 0.16 or 0.13, 0.12, 0.18)
            tile:SetAllPoints()
            local icon = b:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("TOPLEFT", 4, -4)
            icon:SetPoint("BOTTOMRIGHT", -4, 4)
            local sel = b:CreateTexture(nil, "OVERLAY")
            sel:SetTexture(ns.TEX.cellHi)
            sel:SetBlendMode("ADD")
            sel:SetVertexColor(1, 0.82, 0)
            sel:SetAllPoints()
            sel:Hide()
            local cur = ns.Box(b, "BORDER", 1, 1, 1, 0.18)
            cur:SetAllPoints()
            cur:Hide()
            local flash = ns.Box(b, "OVERLAY", 1, 1, 1, 0.6)
            flash:SetAllPoints()
            flash:Hide()
            b:SetHighlightTexture(ns.TEX.cellHi, "ADD")
            b:SetScript("OnClick", function()
                if host:IsRunning() then ns.Safe("edelsteine", g.Select, g, x, y) end
            end)
            g.cells[y][x] = { icon = icon, sel = sel, cur = cur, flash = flash }
        end
    end
    g.msg = ns.BoardText(board, "GameFontNormalLarge", "CENTER")
    g.msg:SetPoint("CENTER")
    return g
end

ns.RegisterGame({
    id = "edelsteine",
    name = L["Gems"],
    short = "Match-3",
    aliases = { "edelsteine", "match3", "juwelen", "bejeweled", "gems" },
    category = "knobeln",
    length = "lang",
    icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_01",
    keyboard = true,
    width = SIZE, height = SIZE,
    desc = L["Swap neighbouring gems to line up three or more of a kind. Falling gems set off chains that count double and triple. You have 30 moves."],
    controls = L["Click two neighbouring gems one after the other · or arrows/WASD + Space"],
    controlsShort = L["Click two neighbours\nArrows + Space"],
    Create = Create,
})
