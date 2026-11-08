-- Pastime: Murloc-Invasion (Space Invaders) – „Mrgllglll!“
local ADDON, ns = ...
local L = ns.L

local W, H = 420, 440
local COLS, ROWS = 8, 4
local MW, MS_X, MS_Y = 30, 44, 38          -- Murloc-Größe und Abstand
local PY, PW = 400, 32                     -- Jäger
local ICON_MURLOC = "Interface\\Icons\\INV_Misc_Head_Murloc_01"
local ICON_PLAYER = "Interface\\Icons\\INV_Weapon_Bow_02"
local ICON_CRATE = "Interface\\Icons\\INV_Crate_02"
local ROWINFO = {   -- Färbung und Punkte je Reihe (oben: Orakel)
    { { 0.75, 0.45, 1 }, 30 }, { { 0.45, 0.75, 1 }, 20 }, { { 0.45, 0.75, 1 }, 20 }, { { 1, 1, 1 }, 10 },
}

local Game = {}
Game.__index = Game

local function overlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

function Game:NewWave()
    self.alive = 0
    local startY = 50 + math.min(60, (self.wave - 1) * 10)
    for i, m in ipairs(self.murlocs) do
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        m.alive, m.ox, m.oy, m.row = true, col * MS_X, row * MS_Y, row + 1
        local c = ROWINFO[row + 1][1]
        m.tex:SetVertexColor(c[1], c[2], c[3])
        m.tex:Show()
        self.alive = self.alive + 1
    end
    self.gx, self.gy, self.dir = 20, startY, 1
    self.shotT = 1.2
    for _, s in ipairs(self.shots) do s.active = false; s.tex:Hide() end
end

function Game:Start()
    self.score, self.lives, self.wave = 0, 3, 1
    self.px = (W - PW) / 2
    self.held, self.dead, self.inv = {}, false, 0
    self.arrow = { active = false }
    self.arrowTex:Hide()
    self.king = { active = false, t = 20 + math.random() * 10 }
    self.kingTex:Hide()
    for _, c in ipairs(self.crates) do c.hp = 5; c.tex:SetAlpha(1); c.tex:Show() end
    self:NewWave()
    self:Render()
end

function Game:Key(k, down)
    if k == "LEFT" or k == "A" then self.held.left = down or nil; return true end
    if k == "RIGHT" or k == "D" then self.held.right = down or nil; return true end
    if k == "SPACE" or k == "UP" or k == "W" then
        if down then self:Fire() end
        return true
    end
    return false
end

function Game:ClearKeys() wipe(self.held) end
Game.OnPause = Game.ClearKeys

function Game:Fire()
    if self.dead or self.arrow.active then return end
    self.arrow.active, self.arrow.x, self.arrow.y = true, self.px + PW / 2 - 1, PY - 10
    self.arrowTex:Show()
    self.host:Sound("click")
end

function Game:Speed()
    return 18 + (COLS * ROWS - self.alive) * 2.6 + (self.wave - 1) * 6
end

function Game:HitCrate(x, y, w, h)
    for _, c in ipairs(self.crates) do
        if c.hp > 0 and overlap(x, y, w, h, c.x, c.y, 34, 34) then
            c.hp = c.hp - 1
            c.tex:SetAlpha(0.25 + c.hp * 0.15)
            if c.hp <= 0 then c.tex:Hide() end
            return true
        end
    end
end

function Game:Update(dt)
    if self.dead then return end
    local dir = (self.held.right and 1 or 0) - (self.held.left and 1 or 0)
    self.px = math.max(0, math.min(W - PW, self.px + dir * 260 * dt))
    if self.inv > 0 then self.inv = self.inv - dt end

    -- Murlocs wandern
    local minX, maxX, maxY = 1e9, -1e9, -1e9
    for _, m in ipairs(self.murlocs) do
        if m.alive then
            minX, maxX = math.min(minX, m.ox), math.max(maxX, m.ox + MW)
            maxY = math.max(maxY, m.oy + MW)
        end
    end
    self.gx = self.gx + self.dir * self:Speed() * dt
    if self.gx + maxX > W - 4 and self.dir > 0 then
        self.dir, self.gy = -1, self.gy + 14
    elseif self.gx + minX < 4 and self.dir < 0 then
        self.dir, self.gy = 1, self.gy + 14
    end
    if self.gy + maxY >= PY - 6 then
        self.dead = true
        self:Render()
        return self.host:Over({ score = self.score, text = (L["The murlocs reached the shore!\nWave %d"]):format(self.wave) })
    end

    -- Pfeil
    local a = self.arrow
    if a.active then
        a.y = a.y - 540 * dt
        if a.y < -12 then
            a.active = false
        elseif self:HitCrate(a.x, a.y, 2, 12) then
            a.active = false
        else
            for _, m in ipairs(self.murlocs) do
                if m.alive and overlap(a.x, a.y, 2, 12, self.gx + m.ox, self.gy + m.oy, MW, MW) then
                    m.alive = false
                    m.tex:Hide()
                    a.active = false
                    self.alive = self.alive - 1
                    self.score = self.score + ROWINFO[m.row][2] * self.wave
                    self.host:Sound("point")
                    break
                end
            end
            if a.active and self.king.active and overlap(a.x, a.y, 2, 12, self.king.x, 14, 34, 34) then
                a.active = false
                self.king.active = false
                self.kingTex:Hide()
                self.score = self.score + 100 * self.wave
                self.host:Sound("big")
            end
        end
        if not a.active then self.arrowTex:Hide() end
    end

    -- Königsmurloc quert oben
    local k = self.king
    if k.active then
        k.x = k.x + k.dir * 110 * dt
        if k.x < -40 or k.x > W + 40 then k.active = false; self.kingTex:Hide() end
    else
        k.t = k.t - dt
        if k.t <= 0 then
            k.active, k.dir, k.t = true, math.random() < 0.5 and 1 or -1, 20 + math.random() * 12
            k.x = k.dir > 0 and -34 or W
            self.kingTex:Show()
        end
    end

    -- Blubberblasen der Murlocs
    self.shotT = self.shotT - dt
    if self.shotT <= 0 then
        self.shotT = math.max(0.45, 1.4 - self.wave * 0.1) * (0.6 + math.random() * 0.8)
        local bottom = {}
        for _, m in ipairs(self.murlocs) do
            if m.alive then
                local col = (m.ox / MS_X)
                if not bottom[col] or m.oy > bottom[col].oy then bottom[col] = m end
            end
        end
        local list = {}
        for _, m in pairs(bottom) do list[#list + 1] = m end
        if #list > 0 then
            local m = list[math.random(#list)]
            for _, s in ipairs(self.shots) do
                if not s.active then
                    s.active, s.x, s.y = true, self.gx + m.ox + MW / 2 - 3, self.gy + m.oy + MW
                    s.tex:Show()
                    break
                end
            end
        end
    end
    for _, s in ipairs(self.shots) do
        if s.active then
            s.y = s.y + (170 + self.wave * 12) * dt
            if s.y > H then
                s.active = false
            elseif self:HitCrate(s.x, s.y, 6, 6) then
                s.active = false
            elseif self.inv <= 0 and overlap(s.x, s.y, 6, 6, self.px + 3, PY, PW - 6, PW) then
                s.active = false
                self.lives = self.lives - 1
                self.inv = 1.2
                self.host:Sound("bad")
                if self.lives <= 0 then
                    self.dead = true
                    self:Render()
                    return self.host:Over({ score = self.score, text = (L["Overwhelmed by bubbles!\nWave %d"]):format(self.wave) })
                end
            end
            if not s.active then s.tex:Hide() end
        end
    end

    if self.alive == 0 then
        self.wave = self.wave + 1
        self.score = self.score + 200
        self.host:Sound("big")
        self:NewWave()
    end
    self:Render()
end

function Game:Render()
    local b = self.board
    self.player:SetPoint("TOPLEFT", b, "TOPLEFT", math.floor(self.px), -PY)
    self.player:SetAlpha((self.inv > 0 and math.floor(self.inv * 10) % 2 == 0) and 0.35 or 1)
    for _, m in ipairs(self.murlocs) do
        if m.alive then m.tex:SetPoint("TOPLEFT", b, "TOPLEFT", math.floor(self.gx + m.ox), -math.floor(self.gy + m.oy)) end
    end
    if self.arrow.active then self.arrowTex:SetPoint("TOPLEFT", b, "TOPLEFT", math.floor(self.arrow.x), -math.floor(self.arrow.y)) end
    for _, s in ipairs(self.shots) do
        if s.active then s.tex:SetPoint("TOPLEFT", b, "TOPLEFT", math.floor(s.x), -math.floor(s.y)) end
    end
    if self.king.active then self.kingTex:SetPoint("TOPLEFT", b, "TOPLEFT", math.floor(self.king.x), -14) end
end

function Game:Info()
    return {
        { L["Lives"], tostring(self.lives or 3) },
        { L["Wave"], tostring(self.wave or 1) },
        { L["Murlocs left"], tostring(self.alive or 0) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, murlocs = {}, shots = {}, crates = {}, held = {},
        score = 0, px = 0, gx = 0, gy = 0, inv = 0, wave = 1, arrow = { active = false }, king = { active = false } }, Game)
    local bg = ns.NewTexture(board, "BACKGROUND")
    bg:SetAllPoints()
    if CreateColor then bg:SetGradient("VERTICAL", CreateColor(0.02, 0.08, 0.14, 1), CreateColor(0.02, 0.02, 0.06, 1)) end
    local sand = ns.NewTexture(board, "BORDER")
    sand:SetPoint("BOTTOMLEFT"); sand:SetPoint("BOTTOMRIGHT"); sand:SetHeight(H - PY - 30)
    ns.Paint(sand, 0.55, 0.45, 0.28, 1, 0.7)
    for i = 1, COLS * ROWS do
        local t = board:CreateTexture(nil, "ARTWORK")
        t:SetSize(MW, MW)
        ns.SetIcon(t, ICON_MURLOC)
        g.murlocs[i] = { tex = t, alive = false, ox = 0, oy = 0, row = 1 }
    end
    for i = 1, 3 do
        local c = { x = 50 + (i - 1) * 140, y = 330, hp = 5 }
        c.tex = board:CreateTexture(nil, "ARTWORK")
        c.tex:SetSize(34, 34)
        c.tex:SetPoint("TOPLEFT", board, "TOPLEFT", c.x, -c.y)
        ns.SetIcon(c.tex, ICON_CRATE)
        g.crates[i] = c
    end
    for i = 1, 6 do
        local t = ns.Box(board, "OVERLAY", 0.5, 0.85, 1)
        t:SetSize(6, 6)
        t:Hide()
        g.shots[i] = { tex = t, active = false }
    end
    g.player = board:CreateTexture(nil, "OVERLAY")
    g.player:SetSize(PW, PW)
    ns.SetIcon(g.player, ICON_PLAYER)
    g.arrowTex = ns.Box(board, "OVERLAY", 1, 0.85, 0.3)
    g.arrowTex:SetSize(2, 12)
    g.arrowTex:Hide()
    g.kingTex = board:CreateTexture(nil, "ARTWORK")
    g.kingTex:SetSize(34, 34)
    ns.SetIcon(g.kingTex, ICON_MURLOC)
    g.kingTex:SetVertexColor(1, 0.82, 0.2)
    g.kingTex:Hide()
    return g
end

ns.RegisterGame({
    id = "murlocs",
    name = L["Murloc Invasion"],
    short = L["Retro shooter"],
    aliases = { "murloc", "murlocs", "invaders", "invasion" },
    category = "geschick",
    length = "lang",
    icon = ICON_MURLOC,
    keyboard = true,
    width = W, height = H,
    desc = L["Mrgllglll! Whole swarms of murlocs march on the shore. Stop them with bow and arrow, take cover behind the crates and hit the golden murloc king. Every wave is faster."],
    controls = L["A/D or arrow keys: move · Space or W: shoot"],
    controlsShort = L["A/D: move\nSpace/W: shoot"],
    Create = Create,
})
