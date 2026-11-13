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
local ICON_RAM = "Interface\\Icons\\Ability_Mount_MountainRam"
local ICON_OWL = "Interface\\Icons\\Ability_Hunter_Pet_Owl"
-- Horde: Kodo durchs Brachland (Kakteen, Geier) · Allianz: Widder durch Dun Morogh (Eisblöcke, Eulen)
local LOOK = {
    Horde = { icon = ICON, bird = ICON_VULTURE, skyLow = { 0.95, 0.7, 0.4 }, skyHigh = { 0.35, 0.55, 0.8 },
        mesa = { 0.62, 0.42, 0.28 }, ground = { 0.62, 0.48, 0.28 }, edge = { 0.35, 0.25, 0.12 }, dots = { 0.42, 0.31, 0.16 },
        plant = { 0.22, 0.55, 0.2 }, arms = true, rock = { 0.5, 0.48, 0.45 }, ledge = { 0.56, 0.36, 0.22 }, lip = { 0.40, 0.25, 0.15 },
        plantText = L["Ran into a cactus!"], birdText = L["Caught by a vulture!"] },
    Alliance = { icon = ICON_RAM, bird = ICON_OWL, skyLow = { 0.8, 0.86, 0.95 }, skyHigh = { 0.3, 0.42, 0.7 },
        mesa = { 0.6, 0.64, 0.74 }, ground = { 0.86, 0.88, 0.93 }, edge = { 0.55, 0.6, 0.7 }, dots = { 0.7, 0.74, 0.82 },
        plant = { 0.62, 0.82, 0.95 }, arms = false, rock = { 0.5, 0.5, 0.55 }, ledge = { 0.55, 0.6, 0.7 }, lip = { 0.4, 0.45, 0.55 },
        plantText = L["Ran into an ice block!"], birdText = L["Caught by an owl!"] },
}

local Game = {}
Game.__index = Game

local function rect(parent, layer, r, g, b, shade)
    local t = ns.NewTexture(parent, layer or "ARTWORK")
    ns.Paint(t, r, g, b, 1, shade)
    t:Hide()
    return t
end

-- Aussehen je Fraktion (bei jedem Start; Spielfelder entstehen erst nach dem Login)
function Game:ApplyLook()
    local T = LOOK[ns.IsAlliance() and "Alliance" or "Horde"]
    self.look = T
    if CreateColor and self.sky.SetGradient then
        self.sky:SetGradient("VERTICAL", CreateColor(T.skyLow[1], T.skyLow[2], T.skyLow[3], 1),
            CreateColor(T.skyHigh[1], T.skyHigh[2], T.skyHigh[3], 1))
    end
    for _, m in ipairs(self.mesas) do ns.Paint(m.tex, T.mesa[1], T.mesa[2], T.mesa[3], 1, 0.8) end
    ns.Paint(self.ground, T.ground[1], T.ground[2], T.ground[3], 1, 0.75)
    self.edge:SetColorTexture(T.edge[1], T.edge[2], T.edge[3], 1)
    for _, d in ipairs(self.dots) do d.tex:SetColorTexture(T.dots[1], T.dots[2], T.dots[3], 1) end
    for _, o in ipairs(self.pool) do
        for _, t in ipairs({ o.stem, o.armL, o.armR }) do ns.Paint(t, T.plant[1], T.plant[2], T.plant[3], 1, 0.7) end
        ns.Paint(o.rock, T.rock[1], T.rock[2], T.rock[3], 1, 0.6)
        ns.Paint(o.ledge, T.ledge[1], T.ledge[2], T.ledge[3], 1, 0.6)
        ns.Paint(o.lip, T.lip[1], T.lip[2], T.lip[3], 1, 0.7)
        ns.SetIcon(o.bird, T.bird)
    end
    ns.SetIcon(self.kodo, T.icon)
end

function Game:Start()
    self:ApplyLook()
    self.h, self.vh, self.duck = 0, 0, false
    self.speed, self.dist, self.score, self.elapsed = 300, 0, 0, 0
    self.waiting, self.dead = true, false
    self.nextGap = 300
    for _, o in ipairs(self.pool) do self:HideObstacle(o) end
    self.kodo:SetVertexColor(1, 1, 1)
    self:PlaceKodo()
    self.hint:SetText(L["Space, W, Up arrow or click to start running"])
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
    if self.score > 120 and r < 0.2 then
        o.kind, o.w, o.top, o.bottom = "geier", 30, GY - 74, GY - 38
    elseif self.score > 60 and r > 0.82 then
        -- Felsüberhang: reicht bis ganz nach oben, nur geduckt passierbar
        o.kind, o.w, o.top, o.bottom = "ueberhang", 44 + math.random(0, 16), 0, GY - 38
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
        o.stem:Show()
        if self.look.arms then o.armL:Show(); o.armR:Show() end   -- Eisblöcke haben keine Arme
    elseif o.kind == "fels" then
        o.rock:SetSize(o.w, o.bottom - o.top)
        o.rock:Show()
    elseif o.kind == "ueberhang" then
        o.ledge:SetSize(o.w, o.bottom - 8)
        o.lip:SetSize(o.w + 8, 10)
        o.ledge:Show(); o.lip:Show()
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
    elseif o.kind == "ueberhang" then
        o.ledge:SetPoint("TOPLEFT", b, "TOPLEFT", x, 0)
        o.lip:SetPoint("TOPLEFT", b, "TOPLEFT", x - 4, -(o.bottom - 10))
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
                    local why = (o.kind == "geier" and self.look.birdText)
                        or (o.kind == "fels" and L["Tripped over a rock!"])
                        or (o.kind == "ueberhang" and L["Ran into a rock overhang!"])
                        or self.look.plantText
                    return self.host:Over({ score = self.score, text = why })
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
    g.sky = sky
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
    g.ground = ground
    local edge = ns.Box(board, "BORDER", 0.35, 0.25, 0.12)
    g.edge = edge
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
        o.ledge = rect(board, "ARTWORK", 0.56, 0.36, 0.22, 0.6)     -- rötlicher Fels wie die Tafelberge
        o.lip = rect(board, "ARTWORK", 0.40, 0.25, 0.15, 0.7)
        o.bird = board:CreateTexture(nil, "ARTWORK")
        o.bird:SetSize(34, 34)
        o.bird:Hide()
        o.texs = { o.stem, o.armL, o.armR, o.rock, o.ledge, o.lip, o.bird }
        table.insert(g.pool, o)
    end
    g.kodo = board:CreateTexture(nil, "OVERLAY")
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
    aliases = { "kodo", "runner", "sprint", "dino", "dash", "kododash", "ram", "widder", "widdersprint", "ramdash" },
    category = "geschick",
    length = "kurz",
    icon = ICON,
    keyboard = true,
    resumeDelay = 3,               -- nach einer Pause erst 3-2-1
    scoreLabel = L["Metres"],
    width = W, height = H,
    desc = L["Your kodo runs across the Barrens and keeps getting faster. Jump over cacti and rocks, duck under low-flying vultures and rock overhangs. Your score is the distance in metres."],
    controls = L["Space, W, Up arrow or click: jump · S or Down arrow: duck (in the air: land faster)"],
    controlsShort = L["Space/W/click: jump\nS/Down: duck"],
    alliance = {
        name = L["Ram Dash"],
        icon = ICON_RAM,
        desc = L["Your ram races through Dun Morogh and keeps getting faster. Jump over ice blocks and rocks, duck under low-flying owls and rock overhangs. Your score is the distance in metres."],
    },
    Create = Create,
})
