-- Pastime: Goblin-Minenfeld (Minesweeper)
local ADDON, ns = ...
local L = ns.L

local MODES = {
    { id = "leicht", name = L["Easy (9×9)"], cols = 9, rows = 9, mines = 10, size = 44, font = "GameFontNormalHuge" },
    { id = "mittel", name = L["Medium (16×16)"], cols = 16, rows = 16, mines = 40, size = 26, font = "GameFontNormalLarge" },
}
local MODE_BY_ID = {}
for _, m in ipairs(MODES) do MODE_BY_ID[m.id] = m end

local ICON_MINE = "Interface\\Icons\\INV_Misc_Bomb_04"
local TEX_FLAG = "Interface\\WorldStateFrame\\HordeFlag"
local TEX_WRONG = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7"
local NUM_COLORS = {
    { 0.45, 0.65, 1.00 }, { 0.35, 0.90, 0.35 }, { 1.00, 0.35, 0.35 }, { 0.75, 0.45, 1.00 },
    { 1.00, 0.65, 0.20 }, { 0.30, 0.90, 0.90 }, { 1.00, 1.00, 1.00 }, { 0.65, 0.65, 0.65 },
}
local STONE = { 0.50, 0.46, 0.40 }
local OPEN = { 0.15, 0.13, 0.10 }

local Game = {}
Game.__index = Game

local function fmtTime(s)
    s = s or 0
    local m = math.floor(s / 60)
    return ("%d:%04.1f"):format(m, s - m * 60)
end

function Game:Neighbors(i)
    local m = self.m
    local x, y = (i - 1) % m.cols, math.floor((i - 1) / m.cols)
    local out = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local nx, ny = x + dx, y + dy
                if nx >= 0 and nx < m.cols and ny >= 0 and ny < m.rows then out[#out + 1] = ny * m.cols + nx + 1 end
            end
        end
    end
    return out
end

-- Zellen pro Modus einmal anlegen
function Game:BuildSet(m)
    local set = { cells = {} }
    local f = CreateFrame("Frame", nil, self.board)
    f:SetSize(m.cols * m.size, m.rows * m.size)
    f:SetPoint("CENTER")
    set.frame = f
    for i = 1, m.cols * m.rows do
        local x, y = (i - 1) % m.cols, math.floor((i - 1) / m.cols)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(m.size - 1, m.size - 1)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", x * m.size, -y * m.size)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
        b.bg = ns.NewTexture(b, "BACKGROUND")
        b.bg:SetAllPoints()
        b:SetHighlightTexture(ns.TEX.cellHi, "ADD")
        b.num = b:CreateFontString(nil, "OVERLAY", m.font)
        b.num:SetPoint("CENTER", 0, 0)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("CENTER")
        b.icon:SetSize(m.size * 0.72, m.size * 0.72)
        b.mark = b:CreateTexture(nil, "OVERLAY")
        b.mark:SetPoint("CENTER")
        b.mark:SetSize(m.size * 0.6, m.size * 0.6)
        b.mark:SetTexture(TEX_WRONG)
        b.index = i
        b:SetScript("OnClick", function(btn, button)
            ns.Safe("minenfeld", self.Click, self, btn.index, button)
        end)
        set.cells[i] = b
    end
    return set
end

function Game:Start(mode)
    local m = MODE_BY_ID[mode or ""] or MODES[1]
    self.m = m
    self.board:SetSize(math.max(m.cols * m.size, 200), math.max(m.rows * m.size, 200))
    for id, s in pairs(self.sets) do s.frame:Hide() end
    self.sets[m.id] = self.sets[m.id] or self:BuildSet(m)
    self.set = self.sets[m.id]
    self.set.frame:Show()
    local n = m.cols * m.rows
    self.mine, self.open, self.flag, self.count = {}, {}, {}, {}
    self.placed, self.dead, self.won = false, false, false
    self.opened, self.flags, self.time, self.score = 0, 0, 0, 0
    self.exploded = nil
    for i = 1, n do self:Draw(i) end
end

function Game:PlaceMines(safe)
    local m = self.m
    local n = m.cols * m.rows
    local forbidden = { [safe] = true }
    for _, j in ipairs(self:Neighbors(safe)) do forbidden[j] = true end
    local pool = {}
    for i = 1, n do if not forbidden[i] then pool[#pool + 1] = i end end
    for k = 1, m.mines do
        local j = math.random(k, #pool)
        pool[k], pool[j] = pool[j], pool[k]
        self.mine[pool[k]] = true
    end
    for i = 1, n do
        local c = 0
        for _, j in ipairs(self:Neighbors(i)) do if self.mine[j] then c = c + 1 end end
        self.count[i] = c
    end
    self.placed = true
end

function Game:Draw(i)
    local b = self.set.cells[i]
    b.mark:Hide()
    b.num:SetText("")
    b.icon:Hide()
    if self.open[i] then
        if self.mine[i] then
            if self.exploded == i then ns.Paint(b.bg, 0.75, 0.12, 0.08, 1) else ns.Paint(b.bg, OPEN[1], OPEN[2], OPEN[3], 1) end
            ns.SetIcon(b.icon, ICON_MINE)
            b.icon:Show()
        else
            ns.Paint(b.bg, OPEN[1], OPEN[2], OPEN[3], 1)
            local c = self.count[i] or 0
            if c > 0 then
                b.num:SetText(c)
                local col = NUM_COLORS[c]
                b.num:SetTextColor(col[1], col[2], col[3])
            end
        end
    else
        ns.Paint(b.bg, STONE[1], STONE[2], STONE[3], 1, 0.62)
        if self.flag[i] then
            b.icon:SetTexture(TEX_FLAG)
            b.icon:SetTexCoord(0, 1, 0, 1)
            b.icon:Show()
            if self.dead and not self.mine[i] then b.mark:Show() end
        elseif self.dead and self.mine[i] then
            ns.SetIcon(b.icon, ICON_MINE)
            b.icon:Show()
        end
    end
end

function Game:Reveal(i)
    if self.open[i] or self.flag[i] then return end
    if self.mine[i] then
        self.open[i] = true
        self.exploded = i
        return self:Lose()
    end
    local queue, head = { i }, 1
    self.open[i] = true
    self.opened = self.opened + 1
    while head <= #queue do
        local cur = queue[head]
        head = head + 1
        self:Draw(cur)
        if self.count[cur] == 0 then
            for _, j in ipairs(self:Neighbors(cur)) do
                if not self.open[j] and not self.flag[j] and not self.mine[j] then
                    self.open[j] = true
                    self.opened = self.opened + 1
                    queue[#queue + 1] = j
                end
            end
        end
    end
    self:CheckWin()
end

function Game:Chord(i)
    if not self.open[i] or (self.count[i] or 0) == 0 then return end
    local flags = 0
    for _, j in ipairs(self:Neighbors(i)) do if self.flag[j] then flags = flags + 1 end end
    if flags ~= self.count[i] then return end
    for _, j in ipairs(self:Neighbors(i)) do
        if not self.dead and not self.won then self:Reveal(j) end
    end
end

function Game:Click(i, button)
    if self.dead or self.won or not self.host:IsRunning() then return end
    if button == "RightButton" then
        if self.open[i] then return end
        self.flag[i] = not self.flag[i] or nil
        self.flags = self.flags + (self.flag[i] and 1 or -1)
        self.host:Sound("flag")
        self:Draw(i)
        self.host:Refresh()
        return
    end
    if button == "MiddleButton" or (IsShiftKeyDown and IsShiftKeyDown()) or self.open[i] then
        self:Chord(i)
    else
        if not self.placed then self:PlaceMines(i) end
        self:Reveal(i)
    end
    self.host:Refresh()
end

function Game:CheckWin()
    local m = self.m
    if self.opened < m.cols * m.rows - m.mines then return end
    self.won = true
    for i = 1, m.cols * m.rows do
        if self.mine[i] and not self.flag[i] then self.flag[i] = true; self:Draw(i) end
    end
    self.flags = m.mines
    self.score = math.floor(self.time * 10 + 0.5) / 10
    self.host:Over({ score = self.score, won = true, text = L["All goblin mines found!"] })
end

function Game:Lose()
    self.dead = true
    for i = 1, self.m.cols * self.m.rows do
        if self.mine[i] then self.open[i] = self.open[i] or (self.exploded == i) end
        self:Draw(i)
    end
    self.host:Over({ title = L["BOOM!"], submit = false, text = L["A goblin mine went off.\nTime: "] .. fmtTime(self.time) })
end

function Game:Update(dt)
    if self.placed and not self.dead and not self.won then
        self.time = self.time + dt
        self.score = self.time
    end
end

function Game:Info()
    local m = self.m or MODES[1]
    return {
        { L["Mines left"], tostring(m.mines - (self.flags or 0)) },
        { L["Uncovered"], ("%d/%d"):format(self.opened or 0, m.cols * m.rows - m.mines) },
    }
end

local function Create(host, board)
    return setmetatable({ host = host, board = board, sets = {}, score = 0 }, Game)
end

ns.RegisterGame({
    id = "minen",
    name = L["Goblin Minefield"],
    short = L["Mine finder"],
    aliases = { "minen", "minesweeper", "minenfeld", "goblin", "minefield", "mines" },
    category = "knobeln",
    length = "kurz",
    icon = ICON_MINE,
    keyboard = false,
    width = 416, height = 416,
    modes = { { id = "leicht", name = L["Easy (9×9)"] }, { id = "mittel", name = L["Medium (16×16)"] } },
    lowerIsBetter = true,
    scoreLabel = L["Time"],
    FormatScore = fmtTime,
    desc = L["A goblin engineer has mined the field. The numbers tell you how many mines lie in the neighbouring squares. Uncover every safe square – the first click is always safe. Your time is your score."],
    controls = L["Left-click: uncover · Right-click: flag · Click a number (or Shift/middle-click): uncover its neighbours"],
    controlsShort = L["Left: uncover\nRight: place flag\nClick a number: neighbours"],
    Create = Create,
})
