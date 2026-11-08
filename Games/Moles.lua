-- Pastime: Kobold-Hauen („Du kriegst keine Kerze!“)
local ADDON, ns = ...
local L = ns.L

local SIZE, CELL = 420, 140
local DURATION = 60
local ICON_KOBOLD = "Interface\\Icons\\INV_Misc_Head_Kobold_01"
local ICON_DYNAMITE = "Interface\\Icons\\INV_Misc_Bomb_02"
local TEX_HIT = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"

-- Was aus dem Schacht schaut
local KINDS = {
    kobold = { icon = ICON_KOBOLD, points = 10, up = 1.0 },
    gold = { icon = ICON_KOBOLD, points = 30, up = 0.75, tint = { 1, 0.85, 0.25 } },   -- Kobold-Vorarbeiter
    dynamit = { icon = ICON_DYNAMITE, points = -20, up = 1.2 },
}

-- Tasten wie auf dem Ziffernblock: 7 8 9 oben, 1 2 3 unten
local KEYMAP = {}
for i, k in ipairs({ "7", "8", "9", "4", "5", "6", "1", "2", "3" }) do
    KEYMAP[k] = i
    KEYMAP["NUMPAD" .. k] = i
end

local Game = {}
Game.__index = Game

function Game:Start()
    self.time, self.score, self.hits, self.escaped, self.bombs = DURATION, 0, 0, 0, 0
    self.elapsed, self.nextSpawn, self.over = 0, 0.6, false
    for _, h in ipairs(self.holes) do
        h.kind, h.t, h.hitT = nil, 0, 0
        h.creature:Hide()
        h.star:Hide()
    end
    self.floaters:Clear()
end

function Game:Spawn()
    local free = {}
    for i, h in ipairs(self.holes) do if not h.kind and h.hitT <= 0 then free[#free + 1] = i end end
    if #free == 0 then return end
    local h = self.holes[free[math.random(#free)]]
    local r = math.random()
    local kind = r < 0.13 and "gold" or (r < 0.28 and "dynamit" or "kobold")
    local K = KINDS[kind]
    h.kind = kind
    h.t = K.up * math.max(0.55, 1 - self.elapsed * 0.006)
    ns.SetIcon(h.creature, K.icon)
    local tint = K.tint or { 1, 1, 1 }
    h.creature:SetVertexColor(tint[1], tint[2], tint[3])
    h.creature:Show()
end

function Game:Whack(i)
    if self.over then return end
    local h = self.holes[i]
    if not h or not h.kind then return end
    local K = KINDS[h.kind]
    self.score = math.max(0, self.score + K.points)
    if K.points > 0 then
        self.hits = self.hits + 1
        self.host:Sound("point")
        self.floaters:Spawn("+" .. K.points, h.cx, h.cy - 40, 1, 0.82, 0)
    else
        self.bombs = self.bombs + 1
        self.host:Sound("bad")
        self.floaters:Spawn(tostring(K.points), h.cx, h.cy - 40, 1, 0.3, 0.3)
    end
    h.kind = nil
    h.creature:Hide()
    h.hitT = 0.25
    h.star:Show()
end

function Game:Update(dt)
    if self.over then return end
    self.floaters:Update(dt)
    self.time = self.time - dt
    self.elapsed = self.elapsed + dt
    for _, h in ipairs(self.holes) do
        if h.hitT > 0 then
            h.hitT = h.hitT - dt
            if h.hitT <= 0 then h.star:Hide() end
        end
        if h.kind then
            h.t = h.t - dt
            if h.t <= 0 then
                if h.kind ~= "dynamit" then self.escaped = self.escaped + 1 end
                h.kind = nil
                h.creature:Hide()
            end
        end
    end
    self.nextSpawn = self.nextSpawn - dt
    if self.nextSpawn <= 0 then
        self:Spawn()
        self.nextSpawn = math.max(0.35, 0.9 - self.elapsed * 0.009) * (0.7 + math.random() * 0.6)
    end
    if self.time <= 0 then
        self.time = 0
        self.over = true
        self.host:Over({ score = self.score, text = (L["Time's up! Hits: %d · Escaped: %d · Dynamite: %d"])
            :format(self.hits, self.escaped, self.bombs) })
    end
end

function Game:Key(k, down)
    local i = KEYMAP[k]
    if not i then return false end
    if down then self:Whack(i) end
    return true
end

function Game:Info()
    return {
        { L["Time"], ("%d s"):format(math.ceil(self.time or DURATION)) },
        { L["Hits"], tostring(self.hits or 0) },
        { L["Escaped"], tostring(self.escaped or 0) },
        { L["Dynamite hit"], tostring(self.bombs or 0) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, holes = {}, score = 0, time = DURATION }, Game)
    local bg = board:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.13, 0.09, 0.05, 1)
    for i = 1, 9 do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local x, y = col * CELL, row * CELL
        local b = CreateFrame("Button", nil, board)
        b:SetSize(CELL - 10, CELL - 10)
        b:SetPoint("TOPLEFT", board, "TOPLEFT", x + 5, -y - 5)
        b:RegisterForClicks("LeftButtonDown")
        -- Erde, Schachtöffnung, Holzrahmen
        local earth = ns.NewTexture(b, "BACKGROUND")
        earth:SetAllPoints()
        ns.Paint(earth, 0.30, 0.20, 0.11, 1, 0.7)
        local shaft = ns.Box(b, "BORDER", 0.03, 0.02, 0.01)
        shaft:SetPoint("BOTTOMLEFT", 22, 14)
        shaft:SetPoint("BOTTOMRIGHT", -22, 14)
        shaft:SetHeight(70)
        local postL = ns.NewTexture(b, "ARTWORK", 1)
        postL:SetSize(10, 82)
        postL:SetPoint("BOTTOMLEFT", 14, 10)
        ns.Paint(postL, 0.45, 0.28, 0.12, 1, 0.7)
        local postR = ns.NewTexture(b, "ARTWORK", 1)
        postR:SetSize(10, 82)
        postR:SetPoint("BOTTOMRIGHT", -14, 10)
        ns.Paint(postR, 0.45, 0.28, 0.12, 1, 0.7)
        local beam = ns.NewTexture(b, "ARTWORK", 2)
        beam:SetHeight(12)
        beam:SetPoint("BOTTOMLEFT", 8, 90)
        beam:SetPoint("BOTTOMRIGHT", -8, 90)
        ns.Paint(beam, 0.50, 0.32, 0.14, 1, 0.7)
        local creature = b:CreateTexture(nil, "ARTWORK", nil, 3)
        creature:SetSize(66, 66)
        creature:SetPoint("BOTTOM", 0, 18)
        creature:Hide()
        local star = b:CreateTexture(nil, "OVERLAY")
        star:SetTexture(TEX_HIT)
        star:SetSize(40, 40)
        star:SetPoint("CENTER", 0, 4)
        star:Hide()
        b:SetHighlightTexture(ns.TEX.cellHi, "ADD")
        b:SetScript("OnClick", function()
            if host:IsRunning() then ns.Safe("kobold", g.Whack, g, i) end
        end)
        g.holes[i] = { button = b, creature = creature, star = star, kind = nil, t = 0, hitT = 0,
            cx = x + CELL / 2, cy = y + CELL / 2 }
    end
    g.floaters = ns.CreateFloaters(board, 8)
    return g
end

ns.RegisterGame({
    id = "kobold",
    name = L["Kobold Bash"],
    short = L["Reflex game"],
    aliases = { "kobold", "kobolde", "maulwurf", "bash", "koboldbash" },
    category = "geschick",
    length = "kurz",
    icon = ICON_KOBOLD,
    keyboard = true,
    width = SIZE, height = SIZE,
    desc = L["Kobolds pop their heads out of the mine shafts – bonk them before they vanish! Golden foremen are worth 30 points, dynamite costs you 20. A round lasts 60 seconds and keeps getting more hectic."],
    controls = L["Click a shaft · or keys 1–9 laid out like the number pad (7 8 9 on top)"],
    controlsShort = L["Click or 1–9\n(7 8 9 = top row)"],
    Create = Create,
})
