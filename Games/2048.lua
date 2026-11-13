-- Pastime: 2048 – von Grau bis Legendär
local ADDON, ns = ...
local L = ns.L

local N, TILE, GAP = 4, 96, 8
local SIZE = N * TILE + (N + 1) * GAP

-- Steinfarben = Gegenstandsqualitäten
local QUALITY = {
    [2] = { L["Poor"], 0.62, 0.62, 0.62 },
    [4] = { L["Common"], 0.92, 0.92, 0.92 },
    [8] = { L["Uncommon"], 0.12, 0.75, 0.00 },
    [16] = { L["Rare"], 0.00, 0.44, 0.87 },
    [32] = { L["Epic"], 0.64, 0.21, 0.93 },
    [64] = { L["Legendary"], 1.00, 0.50, 0.00 },
    [128] = { L["Artifact"], 0.90, 0.80, 0.50 },
    [256] = { L["Heirloom"], 0.00, 0.80, 1.00 },
    [512] = { L["Mythic"], 1.00, 0.82, 0.00 },
    [1024] = { L["Ancient"], 0.85, 0.15, 0.15 },
    [2048] = { L["Titanic"], 0.95, 0.95, 0.55 },
}
local BEYOND = { L["Beyond"], 0.18, 0.18, 0.24 }
local FONTS = { "Game30Font", "Game30Font", "Game24Font", "Game20Font", "GameFontHighlightLarge" }

local DIRS = {
    LEFT = { -1, 0 }, A = { -1, 0 }, RIGHT = { 1, 0 }, D = { 1, 0 },
    UP = { 0, -1 }, W = { 0, -1 }, DOWN = { 0, 1 }, S = { 0, 1 },
}

local Game = {}
Game.__index = Game

function Game:Empty()
    local list = {}
    for y = 1, N do for x = 1, N do if self.cells[y][x] == 0 then list[#list + 1] = { x, y } end end end
    return list
end

function Game:AddTile()
    local e = self:Empty()
    if #e == 0 then return end
    local p = e[math.random(#e)]
    self.cells[p[2]][p[1]] = (math.random() < 0.9) and 2 or 4
    self.pop[p[2] * 10 + p[1]] = { t = 0.14, from = 0.5 }
end

function Game:Start()
    self.cells = {}
    for y = 1, N do self.cells[y] = { 0, 0, 0, 0 } end
    self.score, self.moves, self.best, self.dead, self.reached = 0, 0, 0, false, false
    self.pop = {}
    self:AddTile()
    self:AddTile()
    self.banner:Hide()
    self:Render()
end

-- Eine Reihe zusammenschieben (Richtung: Index 1 ist das Ziel)
local function slide(line)
    local vals = {}
    for _, v in ipairs(line) do if v ~= 0 then vals[#vals + 1] = v end end
    local out, merged, gained, i = {}, {}, 0, 1
    while i <= #vals do
        if vals[i + 1] and vals[i] == vals[i + 1] then
            local v = vals[i] * 2
            out[#out + 1] = v
            merged[#out] = true
            gained = gained + v
            i = i + 2
        else
            out[#out + 1] = vals[i]
            i = i + 1
        end
    end
    for k = #out + 1, N do out[k] = 0 end
    return out, merged, gained
end
Game.slide = slide

function Game:Move(dx, dy)
    local moved, gained = false, 0
    for a = 1, N do
        -- Koordinaten der Reihe in Schieberichtung (Index 1 = Ziel)
        local coords = {}
        for b = 1, N do
            local x, y
            if dx ~= 0 then
                y = a
                x = dx < 0 and b or (N + 1 - b)
            else
                x = a
                y = dy < 0 and b or (N + 1 - b)
            end
            coords[b] = { x, y }
        end
        local line = {}
        for b, c in ipairs(coords) do line[b] = self.cells[c[2]][c[1]] end
        local out, merged, g = slide(line)
        gained = gained + g
        for b, c in ipairs(coords) do
            if self.cells[c[2]][c[1]] ~= out[b] then moved = true end
            self.cells[c[2]][c[1]] = out[b]
            if merged[b] then self.pop[c[2] * 10 + c[1]] = { t = 0.12, from = 1.15 } end
        end
    end
    return moved, gained
end

function Game:CanMove()
    for y = 1, N do
        for x = 1, N do
            local v = self.cells[y][x]
            if v == 0 then return true end
            if x < N and self.cells[y][x + 1] == v then return true end
            if y < N and self.cells[y + 1][x] == v then return true end
        end
    end
    return false
end

function Game:Highest()
    local h = 0
    for y = 1, N do for x = 1, N do h = math.max(h, self.cells[y][x]) end end
    return h
end

function Game:Key(k, down)
    local d = DIRS[k]
    if not d then return false end
    if not down or self.dead then return true end
    local moved, gained = self:Move(d[1], d[2])
    if moved then
        self.moves = self.moves + 1
        self.score = self.score + gained
        if gained > 0 then self.host:Sound("click") end
        self:AddTile()
        local high = self:Highest()
        if high >= 2048 and not self.reached then
            self.reached = true
            self.banner:SetText(L["2048 – Titanic! Feel free to keep going."])
            self.banner:Show()
            self.bannerT = 4
            self.host:Sound("big")
        end
        self:Render()
        if not self:CanMove() then
            self.dead = true
            self.host:Over({ score = self.score, won = self.reached,
                text = (L["No moves left.\nHighest tile: %d (%s)"]):format(high, (QUALITY[high] or BEYOND)[1]) })
        end
    end
    return true
end

function Game:Update(dt)
    local any = false
    for k, p in pairs(self.pop) do
        p.t = p.t - dt
        if p.t <= 0 then self.pop[k] = nil end
        any = true
    end
    if any then self:Render() end
    if self.bannerT then
        self.bannerT = self.bannerT - dt
        if self.bannerT <= 0 then self.bannerT = nil; self.banner:Hide() end
    end
end

function Game:Render()
    for y = 1, N do
        for x = 1, N do
            local t = self.tiles[y][x]
            local v = self.cells[y][x]
            if v == 0 then
                t:Hide()
            else
                local q = QUALITY[v] or BEYOND
                ns.Paint(t.bg, q[2], q[3], q[4], 1, 0.7)
                t.num:SetText(v)
                local digits = #tostring(v)
                local font = FONTS[math.min(digits, #FONTS)]
                if t.font ~= font then
                    t.num:SetFontObject(_G[font] and font or "GameFontHighlightHuge")
                    t.num:SetTextColor(1, 1, 1)
                    t.font = font
                end
                t.name:SetText(q[1])
                local p = self.pop[y * 10 + x]
                if p then
                    local k = math.max(0, p.t) / 0.14
                    t:SetScale(1 + (p.from - 1) * k)
                else
                    t:SetScale(1)
                end
                t:Show()
            end
        end
    end
end

function Game:Info()
    local h = self.cells and self:Highest() or 0
    return {
        { L["Highest tile"], h > 0 and tostring(h) or "–" },
        { L["Quality"], h > 0 and (QUALITY[h] or BEYOND)[1] or "–" },
        { L["Moves"], tostring(self.moves or 0) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, tiles = {}, pop = {}, score = 0, moves = 0 }, Game)
    local bg = ns.NewTexture(board, "BACKGROUND")
    bg:SetAllPoints()
    ns.Paint(bg, 0.13, 0.11, 0.08, 1)
    for y = 1, N do
        g.tiles[y] = {}
        for x = 1, N do
            local ox, oy = GAP + (x - 1) * (TILE + GAP), GAP + (y - 1) * (TILE + GAP)
            local slot = ns.NewTexture(board, "BORDER")
            slot:SetSize(TILE, TILE)
            slot:SetPoint("TOPLEFT", board, "TOPLEFT", ox, -oy)
            ns.Paint(slot, 0.22, 0.19, 0.15, 1)
            -- Halter bleibt fest, die Kachel darin kann „aufploppen“
            local holder = CreateFrame("Frame", nil, board)
            holder:SetSize(TILE, TILE)
            holder:SetPoint("TOPLEFT", board, "TOPLEFT", ox, -oy)
            local t = CreateFrame("Frame", nil, holder)
            t:SetSize(TILE, TILE)
            t:SetPoint("CENTER")
            t.bg = ns.NewTexture(t, "BACKGROUND")
            t.bg:SetAllPoints()
            t.num = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
            t.num:SetPoint("CENTER", 0, 6)
            t.num:SetShadowOffset(2, -2)
            t.num:SetShadowColor(0, 0, 0, 1)
            t.name = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t.name:SetPoint("BOTTOM", 0, 8)
            t.name:SetShadowOffset(1, -1)
            t.name:SetShadowColor(0, 0, 0, 1)
            t:Hide()
            g.tiles[y][x] = t
        end
    end
    g.banner = ns.BoardText(board, "GameFontNormalLarge", "CENTER")
    g.banner:SetPoint("TOP", 0, -6)
    g.banner:Hide()
    return g
end

ns.RegisterGame({
    id = "2048",
    name = "2048",
    short = L["From grey to legendary"],
    aliases = { "zahlen", "2048" },
    category = "knobeln",
    length = "lang",
    icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_01",
    keyboard = true,
    width = SIZE, height = SIZE,
    desc = L["Slide all tiles in one direction – equal tiles merge and rise one quality level: Poor, Common, Uncommon, Rare, Epic, Legendary … Can you reach the titanic 2048?"],
    controls = L["Arrow keys or WASD slide all tiles · P/Esc: pause"],
    controlsShort = L["Arrows/WASD: slide"],
    Create = Create,
})
