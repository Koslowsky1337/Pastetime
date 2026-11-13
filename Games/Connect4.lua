-- Pastime: Vier gewinnt – Horde gegen die Allianz (Computer)
local ADDON, ns = ...
local L = ns.L

local COLS, ROWS, CELL = 7, 6, 56
local TOPM = 66
local W, H = COLS * CELL + 16, ROWS * CELL + TOPM + 10
local ICON_HORDE = "Interface\\Icons\\INV_BannerPVP_01"
local ICON_ALLY = "Interface\\Icons\\INV_BannerPVP_02"
local ORDER = { 4, 3, 5, 2, 6, 1, 7 }
local MODES = {
    { id = "leicht", name = L["Easy"], depth = 2, rnd = 0.35, base = 100 },
    { id = "mittel", name = L["Medium"], depth = 4, rnd = 0, base = 250 },
    { id = "schwer", name = L["Hard"], depth = 5, rnd = 0, base = 500 },
}
local MODE_BY_ID = {}
for _, m in ipairs(MODES) do MODE_BY_ID[m.id] = m end

-- Alle Viererlinien einmal vorberechnen
local LINES = {}
for c = 1, COLS do
    for r = 1, ROWS do
        for _, d in ipairs({ { 1, 0 }, { 0, 1 }, { 1, 1 }, { 1, -1 } }) do
            local ec, er = c + 3 * d[1], r + 3 * d[2]
            if ec >= 1 and ec <= COLS and er >= 1 and er <= ROWS then
                local line = {}
                for k = 0, 3 do line[#line + 1] = { c + k * d[1], r + k * d[2] } end
                LINES[#LINES + 1] = line
            end
        end
    end
end

local AI = {}

function AI.Drop(b, c, who)
    for r = 1, ROWS do
        if b[c][r] == 0 then b[c][r] = who; return r end
    end
end

function AI.Wins(b, c, r, who)
    for _, d in ipairs({ { 1, 0 }, { 0, 1 }, { 1, 1 }, { 1, -1 } }) do
        local n = 1
        for s = -1, 1, 2 do
            local x, y = c + d[1] * s, r + d[2] * s
            while x >= 1 and x <= COLS and y >= 1 and y <= ROWS and b[x][y] == who do
                n = n + 1
                x, y = x + d[1] * s, y + d[2] * s
            end
        end
        if n >= 4 then return true end
    end
    return false
end

function AI.Eval(b)
    local s = 0
    for r = 1, ROWS do
        if b[4][r] == 2 then s = s + 3 elseif b[4][r] == 1 then s = s - 3 end
    end
    for _, line in ipairs(LINES) do
        local a, p = 0, 0
        for _, cell in ipairs(line) do
            local v = b[cell[1]][cell[2]]
            if v == 2 then a = a + 1 elseif v == 1 then p = p + 1 end
        end
        if p == 0 then
            if a == 3 then s = s + 5 elseif a == 2 then s = s + 2 end
        elseif a == 0 then
            if p == 3 then s = s - 6 elseif p == 2 then s = s - 2 end
        end
    end
    return s
end

function AI.Search(b, depth, alpha, beta, maxi)
    if depth == 0 then return AI.Eval(b) end
    local who = maxi and 2 or 1
    local best = maxi and -1e9 or 1e9
    local any = false
    for _, c in ipairs(ORDER) do
        local r = AI.Drop(b, c, who)
        if r then
            any = true
            local v
            if AI.Wins(b, c, r, who) then
                v = maxi and (100000 + depth) or (-100000 - depth)
            else
                v = AI.Search(b, depth - 1, alpha, beta, not maxi)
            end
            b[c][r] = 0
            if maxi then
                if v > best then best = v end
                if best > alpha then alpha = best end
            else
                if v < best then best = v end
                if best < beta then beta = best end
            end
            if alpha >= beta then break end
        end
    end
    if not any then return 0 end
    return best
end

function AI.Best(b, mode)
    local valid = {}
    for _, c in ipairs(ORDER) do if b[c][ROWS] == 0 then valid[#valid + 1] = c end end
    if #valid == 0 then return nil end
    if mode.rnd > 0 and math.random() < mode.rnd then return valid[math.random(#valid)] end
    local bestC, bestV = valid[1], -1e9
    for _, c in ipairs(valid) do
        local r = AI.Drop(b, c, 2)
        local v
        if AI.Wins(b, c, r, 2) then v = 1e8 else v = AI.Search(b, mode.depth - 1, -1e9, 1e9, false) end
        b[c][r] = 0
        if v > bestV then bestC, bestV = c, v end
    end
    return bestC
end

local Game = {}
Game.__index = Game
Game.AI = AI

function Game:Start(mode)
    self.mode = MODE_BY_ID[mode or ""] or MODES[1]
    self.b = {}
    for c = 1, COLS do self.b[c] = {}; for r = 1, ROWS do self.b[c][r] = 0 end end
    self.sel, self.state, self.moves, self.score = 4, "player", 0, 0
    self.last, self.winLine = nil, nil
    -- du spielst deine Fraktion, der Computer die andere
    self.ally = ns.IsAlliance()
    self.myIcon, self.foeIcon = self.ally and ICON_ALLY or ICON_HORDE, self.ally and ICON_HORDE or ICON_ALLY
    ns.SetIcon(self.indicator, self.myIcon)
    self.status:SetText(self.ally and L["You play the Alliance – drop your piece!"] or L["You play the Horde – drop your piece!"])
    self:Render()
end

function Game:Play(c)
    if self.state ~= "player" or not c or self.b[c][ROWS] ~= 0 then return end
    local r = AI.Drop(self.b, c, 1)
    self.moves = self.moves + 1
    self.last = { c, r }
    self.host:Sound("click")
    if AI.Wins(self.b, c, r, 1) then return self:Finish(1, c, r) end
    if self:Full() then return self:Finish(0) end
    self.state, self.t = "ai", 0.35
    self.status:SetText(self.ally and L["The Horde is thinking …"] or L["The Alliance is thinking …"])
    self:Render()
end

function Game:Full()
    for c = 1, COLS do if self.b[c][ROWS] == 0 then return false end end
    return true
end

function Game:FindLine(who)
    for _, line in ipairs(LINES) do
        local ok = true
        for _, cell in ipairs(line) do if self.b[cell[1]][cell[2]] ~= who then ok = false; break end end
        if ok then return line end
    end
end

function Game:Finish(who)
    self.state = "over"
    self.winLine = who ~= 0 and self:FindLine(who) or nil
    self:Render()
    if who == 1 then
        self.score = self.mode.base + math.max(0, 21 - self.moves) * 10
        self.status:SetText(self.ally and L["|cff80ff80For the Alliance!|r"] or L["|cff80ff80For the Horde!|r"])
        self.host:Over({ score = self.score, won = true, text = (L["Four in a row after %d moves – %s defeated."])
            :format(self.moves, self.mode.name) })
    elseif who == 2 then
        self.status:SetText(self.ally and L["|cffff6060The Horde wins.|r"] or L["|cffff6060The Alliance wins.|r"])
        self.host:Over({ submit = false, title = L["Defeat"],
            text = self.ally and L["The Horde has four in a row."] or L["The Alliance has four in a row."] })
    else
        self.status:SetText(L["Draw."])
        self.host:Over({ submit = false, title = L["Draw"], text = L["The board is full – nobody won."] })
    end
end

function Game:Update(dt)
    if self.state == "ai" then
        self.t = self.t - dt
        if self.t <= 0 then
            local c = AI.Best(self.b, self.mode)
            if not c then return self:Finish(0) end
            local r = AI.Drop(self.b, c, 2)
            self.last = { c, r }
            self.host:Sound("click")
            if AI.Wins(self.b, c, r, 2) then return self:Finish(2) end
            if self:Full() then return self:Finish(0) end
            self.state = "player"
            self.status:SetText(L["Your turn."])
            self:Render()
        end
    end
end

function Game:Key(k, down)
    local col = tonumber(k) or tonumber((k or ""):match("^NUMPAD(%d)$") or "")
    if col and col >= 1 and col <= COLS then
        if down then self.sel = col; self:Play(col) end
        return true
    end
    if k == "LEFT" or k == "A" then
        if down then self.sel = math.max(1, self.sel - 1); self:Render() end
        return true
    elseif k == "RIGHT" or k == "D" then
        if down then self.sel = math.min(COLS, self.sel + 1); self:Render() end
        return true
    elseif k == "SPACE" or k == "DOWN" or k == "S" or k == "ENTER" then
        if down then self:Play(self.sel) end
        return true
    end
    return false
end

function Game:Render()
    local onLine = {}
    for _, cell in ipairs(self.winLine or {}) do onLine[cell[1] * 10 + cell[2]] = true end
    for c = 1, COLS do
        for r = 1, ROWS do
            local cell = self.cells[c][r]
            local v = self.b[c][r]
            cell.disc:SetShown(v ~= 0)
            if v ~= 0 then ns.SetIcon(cell.disc, v == 1 and self.myIcon or self.foeIcon) end
            cell.glow:SetShown(onLine[c * 10 + r] or (self.last and self.last[1] == c and self.last[2] == r) or false)
        end
    end
    local show = self.state == "player"
    self.indicator:SetShown(show)
    if show then self.indicator:SetPoint("TOP", self.board, "TOPLEFT", 8 + (self.sel - 0.5) * CELL, -26) end
end

function Game:Info()
    return {
        { L["Opponent"], self.mode and self.mode.name or "–" },
        { L["Your moves"], tostring(self.moves or 0) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, cells = {}, score = 0, sel = 4, b = {} }, Game)
    local panel = ns.NewTexture(board, "BACKGROUND")
    panel:SetPoint("TOPLEFT", 0, -TOPM + 6)
    panel:SetPoint("BOTTOMRIGHT")
    ns.Paint(panel, 0.12, 0.2, 0.45, 1, 0.55)
    for c = 1, COLS do
        g.cells[c] = {}
        for r = 1, ROWS do
            local x, y = 8 + (c - 1) * CELL, TOPM + (ROWS - r) * CELL
            local hole = ns.Box(board, "BORDER", 0.03, 0.04, 0.08)
            hole:SetSize(CELL - 8, CELL - 8)
            hole:SetPoint("TOPLEFT", board, "TOPLEFT", x + 4, -(y + 4))
            local disc = board:CreateTexture(nil, "ARTWORK")
            disc:SetSize(CELL - 12, CELL - 12)
            disc:SetPoint("CENTER", hole, "CENTER")
            disc:Hide()
            local glow = board:CreateTexture(nil, "OVERLAY")
            glow:SetTexture(ns.TEX.cellHi)
            glow:SetBlendMode("ADD")
            glow:SetAllPoints(hole)
            glow:Hide()
            g.cells[c][r] = { disc = disc, glow = glow }
        end
        local col = CreateFrame("Button", nil, board)
        col:SetSize(CELL, H)
        col:SetPoint("TOPLEFT", board, "TOPLEFT", 8 + (c - 1) * CELL, 0)
        col:RegisterForClicks("LeftButtonDown")
        col:SetScript("OnEnter", function() g.sel = c; if g.state == "player" then g:Render() end end)
        col:SetScript("OnClick", function()
            if host:IsRunning() then ns.Safe("viergewinnt", g.Play, g, c) end
        end)
    end
    g.indicator = board:CreateTexture(nil, "OVERLAY")
    g.indicator:SetSize(CELL - 16, CELL - 16)
    ns.SetIcon(g.indicator, ICON_HORDE)
    g.indicator:SetAlpha(0.75)
    g.status = ns.FontString(board, "GameFontNormal", "CENTER")
    g.status:SetPoint("TOP", 0, -4)
    return g
end

ns.RegisterGame({
    id = "viergewinnt",
    name = L["Four in a Row"],
    short = L["Horde vs. Alliance"],
    aliases = { "vier", "viergewinnt", "connect4", "fourinarow", "four" },
    category = "knobeln",
    length = "kurz",
    icon = ICON_HORDE,
    keyboard = true,
    width = W, height = H,
    modes = { { id = "leicht", name = L["Easy"] }, { id = "mittel", name = L["Medium"] }, { id = "schwer", name = L["Hard"] } },
    desc = L["Take turns with the opposing faction dropping banners into the board. The first to get four in a row – horizontally, vertically or diagonally – wins. Quick wins against stronger opponents score more points."],
    controls = L["Click a column · or choose with A/D or arrows, Space drops · keys 1–7 drop directly"],
    controlsShort = L["Click a column\nA/D + Space · 1–7"],
    Create = Create,
})
